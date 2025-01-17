#destination : terraform_program_access
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.aws_use_region
}

resource "aws_s3_bucket" "kdi0913-mywebpage" {
  bucket = "kdi0913-mywebpage"
}

# resource "aws_s3_bucket_public_access_block" "kdi0913-mywebpage" {
#   bucket = aws_s3_bucket.kdi0913-mywebpage.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# import {
#   to = aws_s3_bucket_public_access_block.kdi0913-mywebpage
#   id = aws_s3_bucket.kdi0913-mywebpage.id
# }