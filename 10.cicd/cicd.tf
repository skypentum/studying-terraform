#destination : terraform_program_access
provider "aws" {
  profile = "studying_terraform"
  region  = var.aws_use_region
}

data "aws_vpc" "test-VPC" {
  id = var.vpc_id
}

data "aws_subnets" "existing_private_subnets" {
  filter {
    name   = "tag:Name"
    values = ["test-Private-subnet-A"]
  }
}

###
# Common
###
resource "aws_iam_policy" "test-Codebuild-Image-Repository-Policy" {
  name        = "test-CodebuildBase-Image-Repository-Policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
            ],
            "Resource": "arn:aws:ecr:ap-northeast-2:xxxxxxxxxx:repository/test-codebuild-ecr"
        }
    ]
  })
}

resource "aws_iam_policy" "test-Codebuild-Vpc-Policy" {
  name        = "test-Codebuild-Vpc-Policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeVpcs"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterfacePermission"
            ],
            "Resource": "arn:aws:ec2:ap-northeast-2:xxxxxxxxxx:network-interface/*",
            "Condition": {
                "StringEquals": {
                    "ec2:Subnet": [
                        "arn:aws:ec2:ap-northeast-2:xxxxxxxxxx:subnet/subnet-081766857afb3344f"
                    ],
                    "ec2:AuthorizedService": "codebuild.amazonaws.com"
                }
            }
        }
    ]
  })
}

resource "aws_security_group" "codebuild-security-group" {
  vpc_id = data.aws_vpc.test-VPC.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###
# extra Codebuild & Codepipeline
###
resource "aws_iam_policy" "test-Codebuild-Policy" {
  name        = "test-Codebuild-Policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:logs:ap-northeast-2:xxxxxxxxxx:log-group:/aws/codebuild/test-build",
                "arn:aws:logs:ap-northeast-2:xxxxxxxxxx:log-group:/aws/codebuild/test-build:*"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::codepipeline-ap-northeast-2-*"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:CreateReportGroup",
                "codebuild:CreateReport",
                "codebuild:UpdateReport",
                "codebuild:BatchPutTestCases",
                "codebuild:BatchPutCodeCoverages"
            ],
            "Resource": [
                "arn:aws:codebuild:ap-northeast-2:xxxxxxxxxx:report-group/test-build-*"
            ]
        }
    ]
  })
}

resource "aws_iam_policy" "test-eventrule-Policy" {
  name        = "test-eventrule-Policy"
  description = "integrating codepipeline with kyowonsmart codecommit for member."

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codepipeline:StartPipelineExecution"
            ],
            "Resource": [
                "arn:aws:codepipeline:ap-northeast-2:xxxxxxxxxx:test-codepipeline"
            ]
        }
    ]
  })
}

resource "aws_iam_role" "test-eventrule-Role" {
  name = "test-eventrule-Role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "events.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })

  tags = {
    Name = "test-eventrule-Role"
  }
}

resource "aws_iam_role_policy_attachment" "test-eventrule-Role-attachment" {
  role       = aws_iam_role.test-eventrule-Role.name
  policy_arn = aws_iam_policy.test-eventrule-Policy.arn
}

###
# CodeBuild & CodePipeline
### 
resource "aws_iam_role" "test-build-Role" {
  name = "test-build-Role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })

  tags = {
    Name = "test-build-Role"
  }
}

resource "aws_iam_role_policy_attachment" "test-Codebuild-Role-attachment1" {
  role       = aws_iam_role.test-build-Role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "test-Codebuild-Role-attachment2" {
  role       = aws_iam_role.test-build-Role.name
  policy_arn = aws_iam_policy.test-Codebuild-Image-Repository-Policy.arn
}

resource "aws_iam_role_policy_attachment" "test-Codebuild-Role-attachment3" {
  role       = aws_iam_role.test-build-Role.name
  policy_arn = aws_iam_policy.test-Codebuild-Vpc-Policy.arn
}

resource "aws_iam_role_policy_attachment" "test-Codebuild-Role-attachment4" {
  role       = aws_iam_role.test-build-Role.name
  policy_arn = aws_iam_policy.test-Codebuild-Policy.arn
}

# CodeBuild 생성
resource "aws_codebuild_project" "test-Codebuild" {
  name          = "test-Codebuild"
  description   = "Build for admin at dev"
  service_role  = aws_iam_role.test-build-Role.arn
  
  artifacts {
    type = "CODEPIPELINE"
  }

  # VPC 설정
  vpc_config {
    vpc_id = data.aws_vpc.test-VPC.id
    subnets = [values(data.aws_subnets.existing_private_subnets)[2][0]]
    security_group_ids = [aws_security_group.codebuild-security-group.id]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"  # 최소사양
    image                       = "xxxxxxxxxx.dkr.ecr.ap-northeast-2.amazonaws.com/test-codebuild-ecr:latest"
    type                       = "ARM_CONTAINER"  # ARM 컨테이너
    image_pull_credentials_type = "SERVICE_ROLE"  # 프로젝트 서비스 역할 사용
    privileged_mode            = true  # 도커 이미지 빌드 권한 승격
  }

  # CloudWatch 로그 설정
  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
      group_name = "/aws/codebuild/test-Codebuild"
      stream_name = "build-log"
    }
  }
  
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-dev.yaml"
  }
}

# CodePipeline
resource "aws_codepipeline" "test-Codepipeline" {
  name     = "test-Codepipeline"
  role_arn = "arn:aws:iam::xxxxxxxxxx:role/test-codepipeline-Role"
  pipeline_type = "V2"

  artifact_store {
    location = "codepipeline-ap-northeast-2-xxxxxxxxxx"
    type     = "S3"
    encryption_key {
      type = "KMS"
      id = "arn:aws:kms:ap-northeast-2:xxxxxxxxxx:key/0d2b26d9-8b04-474d-87a2-da21c6fe7356"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        RepositoryName = "test-EXTRA"
        BranchName     = "dev"
        PollForSourceChanges = false
      }

      role_arn = "arn:aws:iam::651800891045:role/test-crossaccount-Role"
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      namespace        = "BuildVariables"
      input_artifacts = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      version         = "1"
      
      configuration = {
        ProjectName = aws_codebuild_project.test-Codebuild.name
        EnvironmentVariables = jsonencode([
          {
            name = "AWS_DEFAULT_REGION"
            value = "ap-northeast-2"
            type = "PLAINTEXT"
          },
          {
            name = "AWS_ACCOUNT_ID"
            value = "xxxxxxxxxx"
            type = "PLAINTEXT"
          },
          {
            name = "IMAGE_TAG"
            value = "latest"
            type = "PLAINTEXT"
          },
          {
            name = "TARGET_IMAGE_TAG"
            value = "dev-graviton"
            type = "PLAINTEXT"
          },
          {
            name = "IMAGE_REPO_NAME"
            value = "test-ecr"
            type = "PLAINTEXT"
          },
          {
            name = "CONTAINER_NAME"
            value = "test-EcsContainer"
            type = "PLAINTEXT"
          },
          {
            name = "BUILD_NAME"
            value = "test-extra"
            type = "PLAINTEXT"
          }
        ])
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      namespace       = "DeployVariables"
      input_artifacts = ["BuildArtifact"]
      version         = "1"

      configuration = {
        ClusterName = "test-EcsCluster"
        ServiceName = "test-EcsService"
      }
    }
  }
}