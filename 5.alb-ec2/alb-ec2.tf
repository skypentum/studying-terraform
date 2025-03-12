#destination : terraform_program_access
provider "aws" {
  profile="studying_terraform"
  region = var.aws_use_region
}

data "aws_vpc" "vpc-common" {
  id = var.vpc_id
}

data "aws_subnets" "common-subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.vpc-common.id]
  }
}

data "aws_subnet" "common-subnet-list" {
  for_each = toset(data.aws_subnets.common-subnets.ids)
  id       = each.value
}

output "common-subnet-id" {
  value = [for s in data.aws_subnet.common-subnet-list : s.id]
}

data "aws_key_pair" "existing_key" {
  key_name           = var.key_pair_name
  include_public_key = true # 공개 키도 조회 (선택 사항)
}

# 보안 그룹 생성 (SSH 허용)
resource "aws_security_group" "bastion_sg" {
  vpc_id = data.aws_vpc.vpc-common.id
  name   = "bastion-sg"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실제로는 자신의 IP로 제한 추천
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc-ec2-private-ec2-sg" {
  vpc_id = data.aws_vpc.vpc-common.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Bastion에서만 접근 허용
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "public-bastion" {
  ami                    = "ami-0a998385ed9f45655" # Amazon Linux 2 AMI (리전별로 확인 필요)
  instance_type          = "t2.micro"
  subnet_id              = values(data.aws_subnet.common-subnet-list)[1].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = data.aws_key_pair.existing_key.key_name # 미리 생성한 키 페어 이름
  associate_public_ip_address = true
  
  tags = {
    Name = "bastion-host"
  }
}

# resource "aws_network_interface" "ec2-private-os-amazon-linux-azone" {
#   subnet_id = values(data.aws_subnet.common-subnet-list)[1].id
#   private_ips = ["10.2.120.10"]
#   security_groups = [aws_security_group.vpc-ec2-private-ec2-sg.id]
#   tags = {
#     Name = "ec2-private-os-amazon-linux-private-network"
#   }
# }

# resource "aws_instance" "vpc-ec2-private-os-amazon-linux-instance-azone" {
#   ami           = "ami-0a998385ed9f45655" # Amazon Linux AMI ID (defult)
#   instance_type = "t2.micro"
#   availability_zone = "ap-northeast-2a" # 변경 가능
#   key_name      = data.aws_key_pair.existing_key.key_name
#   network_interface {
#     network_interface_id = aws_network_interface.ec2-private-os-amazon-linux-azone.id
#     device_index         = 0
#   }
#   tags = {
#     Name = "vpc-ec2-private-os-amazon-linux-instance"
#   }
# }

# resource "aws_network_interface" "ec2-private-os-amazon-linux-czone" {
#   subnet_id = values(data.aws_subnet.common-subnet-list)[0].id
#   private_ips = ["10.2.150.10"]
#   security_groups = [aws_security_group.vpc-ec2-private-ec2-sg.id]
#   tags = {
#     Name = "ec2-private-os-amazon-linux-private-network"
#   }
# }

# resource "aws_instance" "vpc-ec2-private-os-amazon-linux-instance-czone" {
#   ami           = "ami-0a998385ed9f45655" # Amazon Linux AMI ID (defult)
#   instance_type = "t2.micro"
#   availability_zone = "ap-northeast-2c" # 변경 가능
#   key_name      = data.aws_key_pair.existing_key.key_name
#   network_interface {
#     network_interface_id = aws_network_interface.ec2-private-os-amazon-linux-czone.id
#     device_index         = 0
#   }
#   tags = {
#     Name = "vpc-ec2-private-os-amazon-linux-instance-czone"
#   }
# }

# resource "aws_security_group" "alb-sg" {
#   vpc_id = data.aws_vpc.vpc-common.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_lb" "ec2-alb" {
#   name               = "ec2-lb"
#   internal          = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb-sg.id]
#   subnets           = [values(data.aws_subnet.common-subnet-list)[0].id, values(data.aws_subnet.common-subnet-list)[1].id]
# }

# resource "aws_lb_target_group" "ec2-tg1" {
#   name     = "ec2-tg1"
#   target_type = "ip"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = data.aws_vpc.vpc-common.id

#   target_group_health {
#     dns_failover {
#       minimum_healthy_targets_count      = "1"
#       minimum_healthy_targets_percentage = "off"
#     }

#     unhealthy_state_routing {
#       minimum_healthy_targets_count      = "1"
#       minimum_healthy_targets_percentage = "off"
#     }
#   }  
# }

# resource "aws_eip" "vpc-ec2-private-nat-eip" {
#   domain = "vpc"
# }

# resource "aws_nat_gateway" "vpc-ec2-private-nat" {
#   allocation_id = aws_eip.vpc-ec2-private-nat-eip.id
#   subnet_id     = values(data.aws_subnet.common-subnet-list)[0].id
#   tags = {
#     Name = "nat-gateway"
#   }
# }

# resource "aws_route_table" "vpc-ec2-private-rt" {
#   vpc_id = data.aws_vpc.vpc-common.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_nat_gateway.vpc-ec2-private-nat.id
#   }
#   tags = {
#     Name = "vpc-ec2-private-route-table"
#   }
# }

# resource "aws_route_table_association" "vpc-ec2-private-rt-association" {
#   subnet_id      = values(data.aws_subnet.common-subnet-list)[0].id
#   route_table_id = aws_route_table.vpc-ec2-private-rt.id
# }

# output "alb_url" {
#   value = aws_lb.ec2-alb.dns_name
# }

# output "bastion_public_ip" {
#   value = aws_instance.public-bastion.public_ip
# }
