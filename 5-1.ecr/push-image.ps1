$ECR_URL = "998620940391.dkr.ecr.ap-northeast-2.amazonaws.com"
$PASSWORD = aws ecr get-login-password --region ap-northeast-2 --profile studying_terraform
$PASSWORD | docker login --username AWS --password-stdin $ECR_URL

docker tag nginx:latest "$ECR_URL/aws-nginx:latest"
docker tag httpd:latest "$ECR_URL/aws-httpd:latest"

Start-Sleep -Seconds 2

docker push "$ECR_URL/aws-nginx:latest"
docker push "$ECR_URL/aws-httpd:latest"