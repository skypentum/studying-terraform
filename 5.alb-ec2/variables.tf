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
  default = "vpc-068858c91f80633f1"
}

variable "key_pair_name" {
  description = "기존에 생성된 AWS Key Pair 이름"
  type        = string
  default = "test-common-key"
}