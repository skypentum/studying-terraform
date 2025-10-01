variable "aws_use_region" {
  description = "AWS Secret Access Key"
  type        = string
  default = "ap-northeast-2"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default = "vpc-0fb545f1df8ff8773"
}

variable "key_pair_name" {
  description = "기존에 생성된 AWS Key Pair 이름"
  type        = string
  default = "test-common-key"
}