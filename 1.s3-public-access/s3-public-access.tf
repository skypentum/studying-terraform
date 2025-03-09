provider "aws" {
  profile = "studying_terraform"
  region  = var.aws_use_region
}

resource "aws_s3_bucket" "kdi0913-mywebpage" {
  bucket = "kdi0913-mywebpage"
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.kdi0913-mywebpage.id

  rule {
    object_ownership = "BucketOwnerEnforced"  # ACL 사용 안 함
  }
}

resource "aws_s3_bucket_public_access_block" "kdi0913-mywebpage" {
  bucket = aws_s3_bucket.kdi0913-mywebpage.id

  block_public_acls       = false  # ✅ 개별 객체의 퍼블릭 ACL 허용
  block_public_policy     = false  # ✅ 퍼블릭 정책 적용 가능
  ignore_public_acls      = false  # ✅ 개별 객체 ACL 반영
  restrict_public_buckets = false  # ✅ 버킷 퍼블릭 허용
}

resource "aws_s3_bucket_website_configuration" "kdi0913-mywebpage" {
  bucket = aws_s3_bucket.kdi0913-mywebpage.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "website_files" {
  for_each = fileset("./homepage/", "**")
  bucket   = aws_s3_bucket.kdi0913-mywebpage.id
  key      = each.value
  source   = "./homepage/${each.value}"
  etag     = filemd5("./homepage/${each.value}")
  content_type = "text/html"
}

#--- 위의 내용 한번 실행 후, 밑의 내용 주석 제거 후 한번 더 실행
# 무슨 이유인지는 모르겠지만, 한번에 실행하면 아래 에러가 발생한다.
# Error: putting S3 Bucket (kdi0913-mywebpage) Policy: operation error S3: PutBucketPolicy, https response error StatusCode: 403, RequestID: 8ZE5P6HK8GHZYMXR, 
# HostID: FlverK8wKF/Dlfx2i5Gi/41B5R6Jvolsp/XiEEGdATAmTfmmHZVpXlfPvLqJ6p3EhSfGx5F5Q1I=, api error AccessDenied: User: arn:aws:iam::998620940391:user/terraform_program_access is not authorized to perform: s3:PutBucketPolicy on resource: "arn:aws:s3:::kdi0913-mywebpage"
# because public policies are blocked by the BlockPublicPolicy block public access setting.

data "aws_iam_policy_document" "kdi0913-mywebpage-bucket-policy" {
  version = "2012-10-17"
  statement {
    sid = "PublicReadGetObject"
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.kdi0913-mywebpage.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]  # ✅ 모든 사용자 접근 허용
    }
  }
}

resource "aws_s3_bucket_policy" "kdi0913-mywebpage-bucket-policy" {
  bucket = aws_s3_bucket.kdi0913-mywebpage.id
  policy = data.aws_iam_policy_document.kdi0913-mywebpage-bucket-policy.json
}
