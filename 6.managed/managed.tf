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

data "aws_subnets" "existing_private_subnets" {
  filter {
    name   = "tag:Name"
    values = ["vpc-common-private-subnet-a", "vpc-common-private-subnet-c"]
  }
}

output "vpc-common-private-subnet-a" {
  value = values(data.aws_subnets.existing_private_subnets)[2][0]
}

output "vpc-common-private-subnet-c" {
  value = values(data.aws_subnets.existing_private_subnets)[2][1]
}

resource "aws_security_group" "redis_sg" {
  vpc_id = data.aws_vpc.vpc-common.id
  ingress {
    from_port   = 6379 # Redis 기본 포트
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "redis-sg"
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = [values(data.aws_subnets.existing_private_subnets)[2][0], values(data.aws_subnets.existing_private_subnets)[2][1]]
}

# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id          = "redis-cluster"
  engine              = "redis"
  node_type           = "cache.t3.micro"
  num_cache_nodes     = 1
  port                = 6379
  security_group_ids  = [aws_security_group.redis_sg.id]
  subnet_group_name   = aws_elasticache_subnet_group.redis_subnet_group.name
}

resource "aws_security_group" "msk_sg" {
  vpc_id = data.aws_vpc.vpc-common.id
  name   = "msk-sg"

  ingress {
    from_port   = 9092 # Kafka 기본 포트
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "msk-sg"
  }
}

resource "aws_kms_key" "msk_key" {
  description = "KMS key for MSK cluster"
}

resource "aws_msk_configuration" "msk_config" {
  kafka_versions = ["3.6.0"]
  name           = "msk-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable=true
delete.topic.enable=true
PROPERTIES
}

# MSK Cluster
resource "aws_msk_cluster" "msk" {
  cluster_name           = "kafka-cluster"
  kafka_version         = "3.6.0"
  number_of_broker_nodes = 2     #운영은 3개로

  broker_node_group_info {
    instance_type  = "kafka.t3.small"
    client_subnets = [values(data.aws_subnets.existing_private_subnets)[2][0], values(data.aws_subnets.existing_private_subnets)[2][1]]
    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
    security_groups = [aws_security_group.msk_sg.id]
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk_key.arn
  }

  configuration_info {
    arn      = aws_msk_configuration.msk_config.arn
    revision = 1
  }
}

resource "aws_security_group" "rabbit_mq_sg" {
  vpc_id = data.aws_vpc.vpc-common.id
  name   = "mq-sg"

  ingress {
    from_port   = 5672 # RabbitMQ 기본 포트 (AMQP)
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.0/16"]
  }

  ingress {
    from_port   = 15672 # RabbitMQ 관리 콘솔 포트
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mq-sg"
  }
}

resource "aws_mq_configuration" "mq_config" {
  name           = "mq-config"
  engine_type    = "ActiveMQ"
  engine_version = "5.16.5"

  data = <<DATA
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<broker xmlns="http://activemq.apache.org/schema/core">
  <plugins>
    <forcePersistencyModeBrokerPlugin persistenceFlag="true"/>
    <statisticsBrokerPlugin/>
    <timeStampingBrokerPlugin ttlCeiling="86400000"/>
  </plugins>
</broker>
DATA
}

# Amazon MQ Broker
resource "aws_mq_broker" "rabbit_mq" {
  broker_name        = "my-rabbitmq-broker"
  engine_type        = "RabbitMQ"
  engine_version     = "5.18" # 지원되는 RabbitMQ 버전으로 변경 가능
  host_instance_type = "mq.t3.micro"
  deployment_mode    = "SINGLE_INSTANCE"

  user {
    username = "admin"
    password = "Kyowon2017!@#" # 보안을 위해 변수로 관리 권장
  }

  publicly_accessible = false
  subnet_ids          = [values(data.aws_subnets.existing_private_subnets)[2][0],values(data.aws_subnets.existing_private_subnets)[2][1]]
  security_groups     = [aws_security_group.rabbit_mq_sg.id]

  tags = {
    Name = "my-rabbitmq-broker"
  }
}

# # 출력값
# output "elasticache_endpoint" {
#   value = aws_elasticache_cluster.redis.cache_nodes[0].address
# }

# output "msk_bootstrap_brokers" {
#   value = aws_msk_cluster.msk.bootstrap_brokers_tls
# }

# output "mq_broker_endpoint" {
#   value = aws_mq_broker.rabbit_mq.instances[0].endpoints
# }