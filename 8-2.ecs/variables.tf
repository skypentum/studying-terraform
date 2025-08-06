variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
}

variable "aws_use_region" {
  description = "AWS Secret Access Key"
  type        = string
  default = "ap-northeast-2"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default = "vpc-05ed10e149981d706"
}