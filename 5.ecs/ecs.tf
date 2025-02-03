#destination : terraform_program_access
provider "aws" {
  profile="studying_terraform"
  region = var.aws_use_region
}

data "aws_vpc" "vpc-common" {
  default = true
}

data "aws_subnets" "subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.vpc-common.id]
  }
} 

output "subnets" {
  value = data.aws_subnets.subnets.id
}

# resource "aws_security_group" "alb-sg" {
#   vpc_id = data.aws_vpc.vpc-common.id
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_alb" "ecs-alb" {
#   name               = "ecs-alb"
#   internal          = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb-sg.id]
#   subnets           = [data.aws_subnets.subnets.id]
# }

# resource "aws_alb_target_group" "ecs_tg" {
#   name     = "ecs-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id
#   target_type = "ip"
# }

# resource "aws_alb_listener" "http" {
#   load_balancer_arn = aws_alb.ecs_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_alb_target_group.ecs_tg.arn
#   }
# }

# resource "aws_ecs_cluster" "ecs_cluster" {
#   name = "my-ecs-cluster"
# }

# resource "aws_ecs_task_definition" "ecs_task" {
#   family                   = "ecs-task"
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = "256"
#   memory                   = "512"

#   execution_role_arn = aws_iam_role.ecs_task_exec.arn

#   container_definitions = jsonencode([
#     {
#       name      = "my-container"
#       image     = "nginx"
#       essential = true
#       portMappings = [
#         {
#           containerPort = 80
#           hostPort      = 80
#         }
#       ]
#     }
#   ])
# }

# resource "aws_ecs_service" "ecs_service" {
#   name            = "ecs-service"
#   cluster         = aws_ecs_cluster.ecs_cluster.id
#   task_definition = aws_ecs_task_definition.ecs_task.arn
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets         = [aws_subnet.private_subnet.id]
#     security_groups = [aws_security_group.ecs_sg.id]
#   }

#   load_balancer {
#     target_group_arn = aws_alb_target_group.ecs_tg.arn
#     container_name   = "my-container"
#     container_port   = 80
#   }
# }



# resource "aws_security_group" "ecs_sg" {
#   vpc_id = aws_vpc.main.id
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_iam_role" "ecs_task_exec" {
#   name = "ecsTaskExecutionRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
#   role       = aws_iam_role.ecs_task_exec.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# output "alb_url" {
#   value = aws_alb.ecs_alb.dns_name
# }
