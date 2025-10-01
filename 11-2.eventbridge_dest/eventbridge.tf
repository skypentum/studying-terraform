resource "aws_iam_policy" "dest-eventrule-Policy" {
  name        = "dest-eventrule-Policy"
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
                "arn:aws:codepipeline:ap-northeast-2:xxxxxxxxx:dest-codepipeline"
            ]
        }
    ]
  })
}

resource "aws_iam_role" "dest-eventrule-Role" {
  name = "dest-eventrule-Role"

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
    Name = "dest-eventrule-Role"
  }
}

resource "aws_iam_role_policy_attachment" "dest-eventrule-Role-attachment" {
  role       = aws_iam_role.dest-eventrule-Role.name
  policy_arn = aws_iam_policy.dest-eventrule-Policy.arn
}


###
#eventbridge
###
# EventBus 생성
resource "aws_cloudwatch_event_bus" "dest-EventBus" {
  name = "dest-EventBus"
}


# EventBridge Rule for Cross-Account
resource "aws_cloudwatch_event_rule" "dest-EventRule" {
  name           = "dest-EventRule"
  event_bus_name = aws_cloudwatch_event_bus.dest-EventBus.arn
  description    = "Rule to capture custom application events"

  event_pattern = jsonencode({
    detail-type = ["CodeCommit Repository State Change"],
    resources   = ["arn:aws:codecommit:ap-northeast-2:xxxxxxxxxx:repo-name"],
    source      = ["aws.codecommit"],
    detail = {
      "referenceType" = ["branch"],
      "event" = ["referenceUpdated"],
      "referenceName" = ["master"]
    }
  })
}
# 이벤트 규칙에 LTRC-stg-codecommit-EventBus 이벤트브릿지로 타겟 추가
resource "aws_cloudwatch_event_target" "dest-EventRule-target" {
  rule           = aws_cloudwatch_event_rule.dest-EventRule.name
  event_bus_name = aws_cloudwatch_event_bus.dest-EventBus.arn
  arn            = "arn:aws:codepipeline:ap-northeast-2:xxxxxxxxxx:action"
  role_arn       = aws_iam_role.dest-eventrule-Role.arn
}