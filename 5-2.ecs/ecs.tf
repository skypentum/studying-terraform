#destination : terraform_program_access
provider "aws" {
  profile="studying_terraform"
  region = var.aws_use_region
}

resource "aws_iam_role" "ecs-task-exec" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-task-exec-policy" {
  role       = aws_iam_role.ecs-task-exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_vpc" "vpc-common" {
  id = var.vpc_id
}

# output "output-vpc-common" {
#   value = data.aws_vpc.vpc-common.id
# }

data "aws_subnets" "common-subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.vpc-common.id]
  }
}

data "aws_subnet" "common-subnet-list" {
  for_each = toset(data.aws_subnets.common-subnets.ids)
  id       = each.value
}

# output "common-subnet-id" {
#   value = [for s in data.aws_subnet.common-subnet-list : s.id]
# }

# output "common-subnet-cidr-blocks-first" {
#   value = values(data.aws_subnet.common-subnet-list)[0].id
# }

resource "aws_eip" "vpc-common-nat-eip-a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "vpc-common-nat-a" {
  allocation_id = aws_eip.vpc-common-nat-eip-a.id
  subnet_id     = values(data.aws_subnet.common-subnet-list)[1].id
  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_security_group" "alb-sg" {
  vpc_id = data.aws_vpc.vpc-common.id
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

resource "aws_security_group" "ecs-sg" {
  vpc_id = data.aws_vpc.vpc-common.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "ecs-alb" {
  name               = "ecs-alb"
  internal          = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets           = [values(data.aws_subnet.common-subnet-list)[0].id, values(data.aws_subnet.common-subnet-list)[2].id]
}

resource "aws_alb_target_group" "ecs-tg1" {
  name     = "ecs-tg1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc-common.id
  target_type = "ip"
}

resource "aws_alb_target_group" "ecs-tg2" {
  name     = "ecs-tg2"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc-common.id
  target_type = "ip"
}

resource "aws_alb_listener" "http1" {
  load_balancer_arn = aws_alb.ecs-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs-tg1.arn
  }
}

resource "aws_alb_listener" "http2" {
  load_balancer_arn = aws_alb.ecs-alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs-tg2.arn
  }
}

resource "aws_ecs_cluster" "test-ecs-cluster" {
  name = "test-ecs-cluster"
}

resource "aws_ecs_task_definition" "test-ecs-task" {
  family                   = "ecs-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn = aws_iam_role.ecs-task-exec.arn

  container_definitions = jsonencode([
    {
      name      = "test-container1"
      image     = "nginx:stable"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    },
    {
      name      = "test-container2"
      image     = "httpd:2.4"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "test-ecs-service" {
  name            = "ecs-service"
  cluster         = aws_ecs_cluster.test-ecs-cluster.id
  task_definition = aws_ecs_task_definition.test-ecs-task.arn
  launch_type     = "FARGATE"
  desired_count   = 2 

  network_configuration {
    security_groups    = [aws_security_group.ecs-sg.id]
    subnets           = [values(data.aws_subnet.common-subnet-list)[1].id, values(data.aws_subnet.common-subnet-list)[3].id]    
    # assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs-tg1.arn
    container_name   = "test-container1"
    container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs-tg2.arn
    container_name   = "test-container2"
    container_port   = 8080
  }
}

output "alb_url" {
  value = aws_alb.ecs-alb.dns_name
}
