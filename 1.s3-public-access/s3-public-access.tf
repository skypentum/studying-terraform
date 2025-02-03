#destination : terraform_program_access
provider "aws" {
  # access_key = var.aws_access_key
  # secret_key = var.aws_secret_key
  profile="studying_terraform"
  region = var.aws_use_region
}

resource "aws_s3_bucket" "kdi0913-mywebpage" {
  bucket = "kdi0913-mywebpage"
}

resource "aws_s3_object" "root_path_file_upload" {
  for_each = fileset("./homepage/", "**")
  bucket   = aws_s3_bucket.kdi0913-mywebpage.id
  key      = each.value
  source   = "./homepage/${each.value}"
  etag     = filemd5("./homepage/${each.value}")
  content_type = "text/html"  
}

resource "aws_s3_bucket_website_configuration" "kdi0913-mywebpage" {
  bucket = aws_s3_bucket.kdi0913-mywebpage.id
 
  index_document {
    suffix = "index.html"
  }
}

data "aws_iam_policy_document" "kdi0913-mywebpage-bucket-policy" {
  version = "2012-10-17"
  statement {
    sid = "S3GetObjectAllow"
    actions = [
      "s3:GetObject"
    ]
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.kdi0913-mywebpage.arn}/*",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "kdi0913-mywebpage-bucket-policy" {
  bucket = aws_s3_bucket.kdi0913-mywebpage.id
  policy = data.aws_iam_policy_document.kdi0913-mywebpage-bucket-policy.json
}
 
# resource "aws_s3_bucket_public_access_block" "kdi0913-mywebpage" {
#   bucket = aws_s3_bucket.kdi0913-mywebpage.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }