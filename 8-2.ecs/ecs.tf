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

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

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

resource "aws_iam_policy_attachment" "ecs_task_role_policy" {
  name       = "ecsTaskRolePolicyAttachment"
  roles      = [aws_iam_role.ecs_task_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"  # 필요한 정책을 할당
}

data "aws_vpc" "vpc-common" {
  id = var.vpc_id
}

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

data "aws_subnets" "existing_private_subnets" {
  filter {
    name   = "tag:Name"
    values = ["vpc-common-private-subnet-a", "vpc-common-private-subnet-c"]
  }
}

data "aws_subnets" "existing_public_subnets" {
  filter {
    name   = "tag:Name"
    values = ["vpc-common-public-subnet-a", "vpc-common-public-subnet-c"]
  }
}

output "vpc-common-private-subnet-a" {
  value = values(data.aws_subnets.existing_private_subnets)[2][0]
}

output "vpc-common-private-subnet-c" {
  value = values(data.aws_subnets.existing_private_subnets)[2][1]
}

# output "common-subnet-cidr-blocks-first" {
#   value = values(data.aws_subnet.common-subnet-list)[0].id
# }

data "aws_ecr_repository" "ecr-aws-nginx" {
  name="aws-nginx"
}

# data "aws_ecr_repository" "ecr-aws-httpd" {
#   name="aws-httpd"
# }

output "ecr-url1" {
  value = data.aws_ecr_repository.ecr-aws-nginx.repository_url
}

resource "aws_security_group" "alb-sg" {
  vpc_id = data.aws_vpc.vpc-common.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "ecs-alb" {
  name               = "ecs-alb"
  internal          = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets           = [values(data.aws_subnets.existing_public_subnets)[2][0],values(data.aws_subnets.existing_public_subnets)[2][1]]
}

resource "aws_alb_target_group" "ecs-tg1" {
  name     = "ecs-tg1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc-common.id
  target_type = "ip"
}

# resource "aws_alb_target_group" "ecs-tg2" {
#   name     = "ecs-tg2"
#   port     = 8080
#   protocol = "HTTP"
#   vpc_id   = data.aws_vpc.vpc-common.id
#   target_type = "ip"
# }

resource "aws_alb_listener" "http1" {
  load_balancer_arn = aws_alb.ecs-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs-tg1.arn
  }
}

# resource "aws_alb_listener" "http2" {
#   load_balancer_arn = aws_alb.ecs-alb.arn
#   port              = 8080
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_alb_target_group.ecs-tg2.arn
#   }
# }

resource "aws_ecs_cluster" "test-ecs-cluster" {
  name = "test-ecs-cluster"
}

resource "aws_ecs_task_definition" "ecr-aws-nginx-task" {
  family                   = "ecs-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"  
  execution_role_arn = aws_iam_role.ecs-task-exec.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn
  cpu       = "256"
  memory    = "512"

  container_definitions = jsonencode([
    {
      name      = "ecr-aws-nginx-container"
      image     = "${data.aws_ecr_repository.ecr-aws-nginx.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# resource "aws_ecs_task_definition" "ecr-aws-httpd-task" {
#   family                   = "ecs-task"
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   execution_role_arn = aws_iam_role.ecs-task-exec.arn
#   task_role_arn      = aws_iam_role.ecs_task_role.arn
#   cpu       = "256"
#   memory    = "512"

#   container_definitions = jsonencode([
#     {
#       name      = "ecr-aws-httpd-container"
#       image     = "${data.aws_ecr_repository.ecr-aws-httpd.repository_url}:latest"      
#       essential = true
#       cpu       = 256
#       memory    = 512
#       portMappings = [
#         {
#           containerPort = 8080
#           hostPort      = 8080
#         }
#       ]
#     }
#   ])
# }

resource "aws_ecs_service" "test-ecs-service1" {
  name            = "ecs-service"
  cluster         = aws_ecs_cluster.test-ecs-cluster.id
  task_definition = aws_ecs_task_definition.ecr-aws-nginx-task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    security_groups    = [aws_security_group.ecs-sg.id]
    subnets           = [values(data.aws_subnets.existing_private_subnets)[2][0], values(data.aws_subnets.existing_private_subnets)[2][1]]    
    # assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs-tg1.arn
    container_name   = "ecr-aws-nginx-container"
    container_port   = 80
  }
}

# resource "aws_ecs_service" "test-ecs-service2" {
#   name            = "ecs-service2"
#   cluster         = aws_ecs_cluster.test-ecs-cluster.id
#   task_definition = aws_ecs_task_definition.ecr-aws-httpd-task.arn
#   launch_type     = "FARGATE"
#   desired_count   = 1

#   network_configuration {
#     security_groups    = [aws_security_group.ecs-sg.id]
#     subnets           = [values(data.aws_subnets.existing_private_subnets)[2][0], values(data.aws_subnets.existing_private_subnets)[2][1]]    
#     # assign_public_ip = true
#   }

#   load_balancer {
#     target_group_arn = aws_alb_target_group.ecs-tg2.arn
#     container_name   = "ecr-aws-httpd-container"
#     container_port   = 8080
#   }
# }

# output "alb_url" {
#   value = aws_alb.ecs-alb.dns_name
# }
