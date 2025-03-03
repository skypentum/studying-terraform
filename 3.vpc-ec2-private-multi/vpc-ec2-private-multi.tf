#destination : terraform_program_access
provider "aws" {
  profile="studying_terraform"
  region = var.aws_use_region
}

data "aws_key_pair" "existing_key" {
  key_name           = var.key_pair_name
  include_public_key = true # 공개 키도 조회 (선택 사항)
}

resource "aws_vpc" "vpc-ec2-private" {
  cidr_block = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-ec2-private-vpc"
  }
}

resource "aws_internet_gateway" "vpc-public-igw" {
  vpc_id = aws_vpc.vpc-ec2-private.id
  tags = {
    Name = "vpc-public-igw"
  }
}

# Public Subnet Route Table (Public 서브넷은 IGW를 통해 인터넷 연결)
resource "aws_route_table" "vpc-public-rt" {
  vpc_id = aws_vpc.vpc-ec2-private.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc-public-igw.id # ✅ IGW를 통해 인터넷 연결
  }
  tags = {
    Name = "vpc-public-route-table"
  }
}

resource "aws_subnet" "vpc-ec2-public-subnet" {
  vpc_id            = aws_vpc.vpc-ec2-private.id
  cidr_block        = "10.20.30.0/24"
  availability_zone = "ap-northeast-2a" # ec2 생성 시, 해당 대역대와 동일한 AZ 구성 필요
  map_public_ip_on_launch = true
  tags = {
    Name = "vpc-ec2-public-subnet"
  }
}

resource "aws_security_group" "vpc-ec2-public-ec2-sg" {
  vpc_id = aws_vpc.vpc-ec2-private.id

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

resource "aws_subnet" "vpc-ec2-private-subnet" {
  vpc_id            = aws_vpc.vpc-ec2-private.id
  cidr_block        = "10.20.130.0/24"
  availability_zone = "ap-northeast-2a" # ec2 생성 시, 해당 대역대와 동일한 AZ 구성 필요
  map_public_ip_on_launch = false
  tags = {
    Name = "vpc-ec2-private-subnet"
  }
}

resource "aws_security_group" "vpc-ec2-private-ec2-sg" {
  vpc_id = aws_vpc.vpc-ec2-private.id

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
    Name = "vpc-ec2-private-ec2-security-group"
  }
}

resource "aws_network_interface" "ec2-private-os-amazon-linux" {
  subnet_id = aws_subnet.vpc-ec2-private-subnet.id
  private_ips = ["10.20.130.10"]
  security_groups = [aws_security_group.vpc-ec2-private-ec2-sg.id]
  tags = {
    Name = "ec2-private-os-amazon-linux-private-network"
  }
}

resource "aws_instance" "vpc-ec2-private-os-amazon-linux" {
  ami           = "ami-0a998385ed9f45655" # Amazon Linux AMI ID (defult)
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-2a" # 변경 가능
  key_name      = data.aws_key_pair.existing_key.key_name
  network_interface {
    network_interface_id = aws_network_interface.ec2-private-os-amazon-linux.id
    device_index         = 0
  }
  tags = {
    Name = "vpc-ec2-private-os-amazon-linux-Instance"
  }
}

resource "aws_network_interface" "ec2-private-os-ubuntu" {
  subnet_id = aws_subnet.vpc-ec2-private-subnet.id
  private_ips = ["10.20.130.11"]
  security_groups = [aws_security_group.vpc-ec2-private-ec2-sg.id]
  tags = {
    Name = "ec2-private-os-ubuntu-private-network"
  }
}

resource "aws_instance" "vpc-ec2-private-os-ubuntu" {
  ami           = "ami-024ea438ab0376a47" # Ubuntu AMI ID (defult)
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-2a" # 변경 가능
  key_name      = data.aws_key_pair.existing_key.key_name
  network_interface {
    network_interface_id = aws_network_interface.ec2-private-os-ubuntu.id
    device_index         = 0
  }
  tags = {
    Name = "vpc-ec2-private-os-ubuntu-Instance"
  }
}

# resource "aws_instance" "vpc-ec2-private-os-redhat" {
#   ami           = "ami-004ab59b73fc" # redhat AMI ID (defult)
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.vpc-ec2-private-subnet.id
#   availability_zone = "ap-northeast-2a" # 변경 가능
#   key_name      = aws_key_pair.ssh-key.key_name
#   security_groups = [aws_security_group.vpc-ec2-private-ec2-sg.id]
#   tags = {
#     Name = "vpc-ec2-private-os-redhat-Instance"
#   }
# }

resource "aws_eip" "vpc-ec2-private-nat-eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "vpc-ec2-private-nat" {
  allocation_id = aws_eip.vpc-ec2-private-nat-eip.id
  subnet_id     = aws_subnet.vpc-ec2-public-subnet.id
  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "vpc-ec2-private-rt" {
  vpc_id = aws_vpc.vpc-ec2-private.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.vpc-ec2-private-nat.id
  }
  tags = {
    Name = "vpc-ec2-private-route-table"
  }
}

resource "aws_route_table_association" "vpc-ec2-private-rt-association" {
  subnet_id      = aws_subnet.vpc-ec2-private-subnet.id
  route_table_id = aws_route_table.vpc-ec2-private-rt.id
}
