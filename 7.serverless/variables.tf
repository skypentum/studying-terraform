variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
}

variable "aws_use_region" {
  description = "AWS using region"
  type        = string
  default = "ap-northeast-2"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default = "vpc-010d2817f00516a61"
}

# https://{api-id}.execute-api.{regions}.amazonaws.com/{stage}/*