#destination : terraform_program_access
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


resource "aws_vpc" "vpc-common" {
  cidr_block = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-common"
  }
}

resource "aws_subnet" "vpc-common-public_subnet-a" {
  vpc_id                  = aws_vpc.vpc-common.id
  cidr_block              = "10.2.20.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "vpc-common-public-subnet-a"
  }
}

resource "aws_subnet" "vpc-common-public_subnet-c" {
  vpc_id                  = aws_vpc.vpc-common.id
  cidr_block              = "10.2.50.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "vpc-common-public-subnet-c"
  }
}


resource "aws_subnet" "vpc-common-private-subnet-a" {
  vpc_id            = aws_vpc.vpc-common.id
  cidr_block        = "10.2.120.0/24"
  availability_zone = "ap-northeast-2a" # 해당 대역대와 동일한 AZ 구성 필요
  map_public_ip_on_launch = false
  tags = {
    Name = "vpc-common-private-subnet-a"
  }
}

resource "aws_subnet" "vpc-common-private-subnet-c" {
  vpc_id            = aws_vpc.vpc-common.id
  cidr_block        = "10.2.150.0/24"
  availability_zone = "ap-northeast-2c" # 해당 대역대와 동일한 AZ 구성 필요
  map_public_ip_on_launch = false
  tags = {
    Name = "vpc-common-private-subnet-c"
  }
}

resource "aws_security_group" "vpc-common-sg" {
  vpc_id = aws_vpc.vpc-common.id

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
    Name = "vpc-ec2-security-group"
  }
}

resource "aws_internet_gateway" "vpc-common-igw" {
  vpc_id = aws_vpc.vpc-common.id
  tags = {
    Name = "vpc-common-igw"
  }
}

# Public Subnet Route Table (Public 서브넷은 IGW를 통해 인터넷 연결)
resource "aws_route_table" "vpc-common-public-rt" {
  vpc_id = aws_vpc.vpc-common.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc-common-igw.id # ✅ IGW를 통해 인터넷 연결
  }
  tags = {
    Name = "vpc-common-public-route-table"
  }
}

# resource "aws_eip" "vpc-common-nat-eip-a" {
#   domain = "vpc"
# }

# resource "aws_nat_gateway" "vpc-common-nat-a" {
#   allocation_id = aws_eip.vpc-common-nat-eip-a.id
#   subnet_id     = aws_subnet.vpc-common-private-subnet-a.id
#   tags = {
#     Name = "nat-gateway"
#   }
# }

# resource "aws_route_table" "vpc-common-rt" {
#   vpc_id = aws_vpc.vpc-common.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_nat_gateway.vpc-common-nat-a.id
#   }
#   tags = {
#     Name = "vpc-common-route-table"
#   }
# }

# resource "aws_route_table_association" "vpc-common-rt-a-association" {
#   subnet_id      = aws_subnet.vpc-common-private-subnet-a.id
#   route_table_id = aws_route_table.vpc-common-rt.id
# }

# resource "aws_eip" "vpc-common-nat-eip-c" {
#   domain = "vpc"
# }

# resource "aws_nat_gateway" "vpc-common-nat-c" {
#   allocation_id = aws_eip.vpc-common-nat-eip-c.id
#   subnet_id     = aws_subnet.vpc-common-private-subnet-c.id
#   tags = {
#     Name = "nat-gateway"
#   }
# }

# resource "aws_eip" "vpc-common-nat-eip-c" {
#   domain = "vpc"
# }

# resource "aws_route_table" "vpc-common-rt-c" {
#   vpc_id = aws_vpc.vpc-common.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_nat_gateway.vpc-common-nat-a.id
#   }
#   tags = {
#     Name = "vpc-common-route-table"
#   }
# }

# resource "aws_route_table_association" "vpc-common-rt-c-association" {
#   subnet_id      = aws_subnet.vpc-common-private-subnet-c.id
#   route_table_id = aws_route_table.vpc-common-rt.id
# }



