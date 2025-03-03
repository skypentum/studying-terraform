provider "aws" {
  profile="studying_terraform"
  region = var.aws_use_region
}

data "aws_key_pair" "existing_key" {
  key_name           = var.key_pair_name
  include_public_key = true # 공개 키도 조회 (선택 사항)
}

resource "aws_vpc" "vpc-ec2-public" {
  cidr_block = "10.10.30.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-ec2-public"
  }
}

resource "aws_internet_gateway" "vpc-public-igw" {
  vpc_id = aws_vpc.vpc-ec2-public.id
  tags = {
    Name = "vpc-public-igw"
  }
}

# Public Subnet Route Table (Public 서브넷은 IGW를 통해 인터넷 연결)
resource "aws_route_table" "vpc-public-rt" {
  vpc_id = aws_vpc.vpc-ec2-public.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc-public-igw.id # ✅ IGW를 통해 인터넷 연결
  }
  tags = {
    Name = "vpc-public-route-table"
  }
}

resource "aws_subnet" "vpc-ec2-public-subnet" {
  vpc_id            = aws_vpc.vpc-ec2-public.id
  cidr_block        = "10.10.30.0/24"
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
    cidr_blocks = ["0.0.0.0/0"]
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

# 서브넷과 라우팅 테이블 연결 (서브넷 1)
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.vpc-ec2-public-subnet.id
  route_table_id = aws_route_table.vpc-public-rt.id
}

resource "aws_instance" "vpc-ec2-public-os-amazon-linux" {
  ami           = "ami-0a998385ed9f45655" # Amazon Linux AMI ID (defult)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.vpc-ec2-public-subnet.id
  availability_zone = "ap-northeast-2a" # 변경 가능
  key_name      = data.aws_key_pair.existing_key.key_name
  security_groups = [aws_security_group.vpc-ec2-public-ec2-sg.id]
  tags = {
    Name = "vpc-ec2-public-os-amazon-linux-Instance"
  }
}