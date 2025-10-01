# 서비스 Docker 이미지 빌드
# resource "docker_image" "docker-image" {
#   name = "docker_ecr_test:latest"
#   build {
#     context    = "./test"
#     dockerfile = "./Dockerfile"
#   }
# }

# Create ECR repository
resource "aws_ecr_repository" "aws-nginx" {
  name                 = "aws-nginx"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

# resource "aws_ecr_repository" "aws-httpd" {
#   name                 = "aws-httpd"
#   image_tag_mutability = "MUTABLE"
#   image_scanning_configuration {
#     scan_on_push = false
#   }
# }

# ECR lifecycle 정책 생성
resource "aws_ecr_lifecycle_policy" "ecr-lilfecycle-policy" {
  repository = aws_ecr_repository.aws-nginx.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 30 days"
        selection    = {
          tagStatus = "untagged"
          countType = "sinceImagePushed"
          countUnit = "days"
          countNumber = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "aws-nginx-policy" {
  repository = aws_ecr_repository.aws-nginx.name
  policy     = <<EOF
  {
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "Set the permission for ECR",
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      }
    ]
  }
  EOF
}

resource "null_resource" "push-image" {
  depends_on = [
    aws_ecr_repository.aws-nginx
  ]
 
  provisioner "local-exec" {
    #heredoc 스타일로 작성 (EOT=end of text)
    # command = <<-EOT
    #   $AWS_NGINX_URL = "${aws_ecr_repository.aws-nginx.repository_url}"
    #   $AWS_HTTPD_URL = "${aws_ecr_repository.aws-httpd.repository_url}"
    #   $PASSWORD = aws ecr get-login-password --region ${var.aws_use_region} --profile studying_terraform
    #   echo $PASSWORD | docker login --username AWS --password-stdin $AWS_NGINX_URL      
      
    #   docker tag nginx:latest "$AWS_NGINX_URL:latest"
    #   docker tag httpd:latest "$AWS_HTTPD_URL:latest"
    #   docker push "$AWS_NGINX_URL:latest"
    #   docker push "$AWS_HTTPD_URL:latest"
    # EOT   
    command = "PowerShell -ExecutionPolicy Bypass -File ./push-image.ps1" 
    interpreter = ["PowerShell", "-Command"]
  }
}