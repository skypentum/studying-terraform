provider "aws" {
  profile="studying_terraform"
  region = var.aws_use_region
}

# 아래 명령어를 사용하여 ssh 공개 키 생성
# ssh-keygen -t rsa -b 2048 -f ssh-key/id_rsa 
resource "aws_key_pair" "ssh-key" {
  key_name   = "default-key-pair"
  public_key = file("../ssh-key/id_rsa.pub") # 로컬 공개키 경로 설정
}

resource "aws_vpc" "vpc-ec2-public" {
  cidr_block = "10.1.30.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-ec2-public"
  }
}

resource "aws_subnet" "vpc-ec2-public-subnet" {
  vpc_id            = aws_vpc.vpc-ec2-public.id
  cidr_block        = "10.1.30.0/24"
  availability_zone = "ap-northeast-2a" # ec2 생성 시, 해당 대역대와 동일한 AZ 구성 필요
  map_public_ip_on_launch = true
  tags = {
    Name = "vpc-ec2-public-subnet"
  }
}

resource "aws_security_group" "vpc-ec2-public-ec2-sg" {
  vpc_id = aws_vpc.vpc-ec2-public.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["211.60.209.194/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpc-ec2-public-ec2-security-group"
  }
}

resource "aws_internet_gateway" "vpc-ec2-public-igw" {
  vpc_id = aws_vpc.vpc-ec2-public.id
  tags = {
    Name = "vpc-ec2-public-igw"
  }
}

resource "aws_instance" "vpc-ec2-public-os-amazon-linux" {
  ami           = "ami-0a998385ed9f45655" # Amazon Linux AMI ID (defult)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.vpc-ec2-public-subnet.id
  availability_zone = "ap-northeast-2a" # 변경 가능
  key_name      = aws_key_pair.ssh-key.key_name
  security_groups = [aws_security_group.vpc-ec2-public-ec2-sg.id]
  tags = {
    Name = "vpc-ec2-public-os-amazon-linux-Instance"
  }
}