###
# Policy(교차 계정으로 이벤트 전송)
###
# 개발 환경
resource "aws_iam_policy" "source-eventrule-Policy" {
  name        = "source-eventrule-Policy"
  description = "source-eventrule-Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "events:PutEvents"          
        ],
        Resource = [
          "arn:aws:events:ap-northeast-2:dest_xxxxxxxxx:event-bus/dest-codecommit-EventBus"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "source-crossaccount-Policy" {
  name        = "source-crossaccount-Policy"
  description = "source-crossaccount-Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject*",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "codecommit:ListBranches",
          "codecommit:ListRepositories"          
        ],
        Resource = [
          "arn:aws:s3:::codepipeline-ap-northeast-2-dest/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:Decrypt"      
        ],
        Resource = [
          "arn:aws:kms:ap-northeast-2:dest_xxxxxxxxx:key/your-kms-key-id"
        ]
      }
    ]
  })
}


###
# Role
###
# 개발환경
resource "aws_iam_role" "source-crossaccount-Role" {
  name               = "source-crossaccount-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        AWS = "arn:aws:iam::765541704252:root"
      }
      Action = "sts:AssumeRole"
      Condition = {}
    }]
  })
}

resource "aws_iam_role_policy_attachment" "source-crossaccount-Role-att1" {
  role       = aws_iam_role.source-crossaccount-Role.name
  policy_arn = aws_iam_policy.source-crossaccount-Policy.arn
}

resource "aws_iam_role_policy_attachment" "source-crossaccount-Role-att2" {
  role       = aws_iam_role.source-crossaccount-Role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess"
}

resource "aws_iam_role" "source-eventrule-Role" {
  name               = "source-eventrule-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceArn" = [
            "arn:aws:events:ap-northeast-2:source_xxxxxxxxx:rule/source-lms-codecommit-EventRule"
          ],
          "aws:SourceAccount" = "source_xxxxxxxxx"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "source-eventrule-Role-att1" {
  role       = aws_iam_role.source-eventrule-Role.name
  policy_arn = aws_iam_policy.source-eventrule-Policy.arn
}

# 이벤트 규칙 생성
resource "aws_cloudwatch_event_rule" "source-EventRule" {
  name           = "source-EventRule"
  description    = "Rule to capture custom application events"

  event_pattern = jsonencode({
    detail-type = ["CodeCommit Repository State Change"],
    resources   = ["arn:aws:codecommit:ap-northeast-2:source_xxxxxxxxx:repo-name"],
    source      = ["aws.codecommit"],
    detail = {
      "referenceType" = ["branch"],
      "event" = ["referenceUpdated"],
      "referenceName" = ["master"]
    }
  })
}

# 이벤트 규칙에 교차 계정 이벤트브릿지로 타겟 추가(default에 추가)
resource "aws_cloudwatch_event_target" "source-codecommit-EventRule-target" {
  rule           = aws_cloudwatch_event_rule.source-EventRule.name
  arn            = "arn:aws:events:ap-northeast-2:dest_xxxxxxxx:event-bus/source-EventBus"
  role_arn       = aws_iam_role.source-eventrule-Role.arn
}