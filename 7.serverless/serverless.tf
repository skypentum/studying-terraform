# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "100.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "serverless-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "100.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "100.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "main-nat"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# API Gateway
resource "aws_api_gateway_rest_api" "serverless" {
  name = "serverless-api"
}

resource "aws_api_gateway_resource" "lambda-test" {
  rest_api_id = aws_api_gateway_rest_api.serverless.id
  parent_id   = aws_api_gateway_rest_api.serverless.root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "lambda-test" {
  rest_api_id   = aws_api_gateway_rest_api.serverless.id
  resource_id   = aws_api_gateway_resource.lambda-test.id
  http_method   = "GET"
  authorization = "NONE"
}

# Lambda Function
resource "aws_lambda_function" "example" {
  filename         = "test-lambda.zip"
  function_name    = "test_lambda"
  role            = aws_iam_role.lambda_role.arn
  handler         = "hello_world.app.lambda_handler"
  runtime         = "python3.11"

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda IAM Role에 VPC 정책 추가
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.serverless.id
  resource_id = aws_api_gateway_resource.lambda-test.id
  http_method = aws_api_gateway_method.lambda-test.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.example.invoke_arn
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.serverless.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "serverless" {
  rest_api_id = aws_api_gateway_rest_api.serverless.id
  
  depends_on = [
    aws_api_gateway_integration.lambda
  ]
}

resource "aws_api_gateway_stage" "serverless" {
  deployment_id = aws_api_gateway_deployment.serverless.id
  rest_api_id   = aws_api_gateway_rest_api.serverless.id
  stage_name    = "test"
}

# Data source for AZs
data "aws_availability_zones" "available" {
  state = "available"
}