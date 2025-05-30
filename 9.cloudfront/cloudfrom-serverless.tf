#destination : terraform_program_access
provider "aws" {
  profile="studying_terraform"
  region = var.aws_use_region
}


# VPC and Subnet configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
  
  map_public_ip_on_launch = true

  tags = {
    Name = "public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.main.id 
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"
  
  map_public_ip_on_launch = true

  tags = {
    Name = "public-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda Function
resource "aws_iam_role" "lambda_exec" {
    name = "lambda_exec_role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "lambda.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "example" {
    function_name = "example_lambda"
    role          = aws_iam_role.lambda_exec.arn
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.11"
    filename      = "test-lambda.zip"
}

# ALB
resource "aws_lb" "example" {
    name               = "example-alb"
    internal           = false
    load_balancer_type = "application"
    subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups    = [aws_security_group.alb.id]
}

# ALB Target Group for Lambda
resource "aws_lb_target_group" "lambda" {
    name        = "alb-lambda-tg"
    target_type = "lambda"
}

# Attach Lambda to Target Group
resource "aws_lb_target_group_attachment" "lambda" {
    target_group_arn = aws_lb_target_group.lambda.arn
    target_id        = aws_lambda_function.example.arn
    depends_on       = [aws_lambda_permission.alb]
}

# ALB Listener
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.lambda.arn
    }
}

# Lambda Permission for ALB
resource "aws_lambda_permission" "alb" {
    statement_id  = "AllowExecutionFromALB"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.example.function_name
    principal     = "elasticloadbalancing.amazonaws.com"
    source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_cloudfront_cache_policy" "dynamic_caching" {
  name        = "DynamicContentCaching"
  comment     = "Policy for caching dynamic content"
  default_ttl = 3600
  max_ttl     = 86400
  min_ttl     = 1
  
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Host", "Origin", "Referer"]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "alb" {
    origin {
        domain_name = aws_lb.example.dns_name
        origin_id   = "alb-origin"

        custom_origin_config {
            http_port              = 80
            https_port             = 443
            origin_protocol_policy = "http-only"
            origin_ssl_protocols   = ["TLSv1.2"]
        }
    }

    enabled             = true
    default_root_object = ""
    default_cache_behavior {
        allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = "alb-origin"

        cache_policy_id = aws_cloudfront_cache_policy.dynamic_caching.id
       
        viewer_protocol_policy = "redirect-to-https"
        compress              = true
    }

    price_class = "PriceClass_100"

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}

####
#이 구성에서는 다음과 같은 특징이 있습니다:
#Lambda 대신 ECS Fargate를 사용하여 컨테이너를 실행합니다.
#ALB는 ECS 서비스의 컨테이너를 대상으로 합니다.
#CloudFront는 GET, HEAD, OPTIONS 메서드만 캐싱하도록 설정되어 있습니다.
#Lambda@Edge 없이 POST 요청을 캐싱하는 것에 대한 제한사항:
#POST 요청 본문을 기반으로 캐싱할 수 없습니다. 이는 Lambda@Edge가 없으면 요청 본문을 해시하여 캐시 키로 사용할 방법이 없기 때문입니다.
#동일한 URL에 대한 POST 요청은 항상 오리진으로 전달됩니다.
#쿼리 파라미터와 헤더를 기반으로 한 캐싱은 가능하지만, 요청 본문은 캐시 키에 포함되지 않습니다.

#만약 POST 요청을 캐싱해야 한다면, 애플리케이션 레벨에서 다음과 같은 대안을 고려할 수 있습니다:
#POST 요청 대신 GET 요청을 사용하도록 API를 설계합니다.
#POST 요청의 중요한 파라미터를 URL 쿼리 파라미터로 이동시킵니다.
#서버 측에서 자체 캐싱 메커니즘을 구현합니다.
####