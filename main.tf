terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  profile = "studying_terraform"
  region  = "ap-northeast-2"
}

variable "target_module" {
  description = "Target module to run"
  type        = string
  default     = ""
}

# 조건부 모듈 실행
# S3 Public Access Module
module "s3_public_access" {
  count  = var.target_module == "s3-public-access" ? 1 : 0
  source = "./1.s3-public-access"
}

# VPC EC2 Public Module
module "vpc_ec2_public" {
  count  = var.target_module == "vpc-ec2-public" ? 1 : 0
  source = "./2.vpc-ec2-public"
}

# VPC EC2 Private Multi Module
module "vpc_ec2_private_multi" {
  count  = var.target_module == "vpc-ec2-private-multi" ? 1 : 0
  source = "./3.vpc-ec2-private-multi"
}

# VPC Common Module
module "vpc_common" {
  count  = var.target_module == "vpc-common" ? 1 : 0
  source = "./4.vpc-common"
}

# ALB EC2 Module
module "alb_ec2" {
  count  = var.target_module == "alb-ec2" ? 1 : 0
  source = "./5.alb-ec2"
}

# Managed Services Module
module "managed" {
  count  = var.target_module == "managed" ? 1 : 0
  source = "./6.managed"
}

# Serverless Module
module "serverless" {
  count  = var.target_module == "serverless" ? 1 : 0
  source = "./7.serverless"
}

# ECR Module
module "ecr" {
  count  = var.target_module == "ecr" ? 1 : 0
  source = "./8-1.ecr"
}

# ECS Module
module "ecs" {
  count  = var.target_module == "ecs" ? 1 : 0
  source = "./8-2.ecs"
}

# CloudFront Module
module "cloudfront" {
  count  = var.target_module == "cloudfront" ? 1 : 0
  source = "./9.cloudfront"
}

# # CICD Module
# module "cicd" {
#   count  = var.target_module == "cicd" ? 1 : 0
#   source = "./10.cicd"
# }

# # EventBridge Source Module
# module "eventbridge_source" {
#   count  = var.target_module == "eventbridge-source" ? 1 : 0
#   source = "./11-1.eventbridge_source"
# }

# # EventBridge Dest Module
# module "eventbridge_dest" {
#   count  = var.target_module == "eventbridge-dest" ? 1 : 0
#   source = "./11-2.eventbridge_dest"
# }

# # EC2 RabbitMQ Module
# module "ec2_rabbitmq" {
#   count  = var.target_module == "ec2-rabbitmq" ? 1 : 0
#   source = "./12.ec2-rabbitmq"
# }