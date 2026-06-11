# --- Production VPC Network ---
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# --- 1. Public Subnets (For Routing / Internet Access) ---
resource "aws_subnet" "subnet_public_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-public-a"
  }
}

resource "aws_subnet" "subnet_public_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-public-b"
  }
}

# --- 2. Private Application Subnets (For Lambda & SSM Tunnel Host) ---
resource "aws_subnet" "subnet_private_app_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-private-app-a"
  }
}

resource "aws_subnet" "subnet_private_app_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-private-app-b"
  }
}

# --- 3. Isolated Database Subnets (For RDS Instance) ---
resource "aws_subnet" "subnet_private_db_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-private-db-a"
  }
}

resource "aws_subnet" "subnet_private_db_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-private-db-b"
  }
}

# --- Route Tables & Associations ---

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.subnet_public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.subnet_public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table for Private Application Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.subnet_private_app_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.subnet_private_app_b.id
  route_table_id = aws_route_table.private_rt.id
}

# Route Table for Isolated Database Subnets
resource "aws_route_table" "private_db_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-db-rt"
  }
}

resource "aws_route_table_association" "db_assoc_a" {
  subnet_id      = aws_subnet.subnet_private_db_a.id
  route_table_id = aws_route_table.private_db_rt.id
}

resource "aws_route_table_association" "db_assoc_b" {
  subnet_id      = aws_subnet.subnet_private_db_b.id
  route_table_id = aws_route_table.private_db_rt.id
}

# DB Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = [aws_subnet.subnet_private_db_a.id, aws_subnet.subnet_private_db_b.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# --- Security Groups (Empty Containers to Break Cycles) ---

resource "aws_security_group" "endpoints_sg" {
  name        = "${var.project_name}-${var.environment}-endpoints-sg"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-endpoints-sg"
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for production backend Lambda"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

resource "aws_security_group" "proxy_sg" {
  name        = "${var.project_name}-${var.environment}-proxy-sg"
  description = "Security group for RDS Proxy"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-proxy-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for production RDS PostgreSQL"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for SSM Bastion Host"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

# --- Security Group Rules ---

# 1. Endpoints SG Rules
resource "aws_security_group_rule" "endpoints_ingress_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
  description              = "Allow HTTPS from private Lambda"
}

resource "aws_security_group_rule" "endpoints_ingress_bastion" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
  description              = "Allow HTTPS from SSM Bastion host"
}

resource "aws_security_group_rule" "endpoints_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.endpoints_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound egress from endpoints"
}

# 2. Lambda SG Rules
resource "aws_security_group_rule" "lambda_egress_proxy" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_sg.id
  source_security_group_id = aws_security_group.proxy_sg.id
  description              = "Allow database connection to RDS Proxy SG"
}

resource "aws_security_group_rule" "lambda_egress_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_sg.id
  source_security_group_id = aws_security_group.endpoints_sg.id
  description              = "Allow HTTPS egress to VPC Endpoints"
}

resource "aws_security_group_rule" "lambda_egress_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lambda_sg.id
  prefix_list_ids   = [aws_vpc_endpoint.s3.prefix_list_id]
  description       = "Allow HTTPS egress to S3 Gateway Endpoint"
}

# 3. RDS Proxy SG Rules
resource "aws_security_group_rule" "proxy_ingress_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.proxy_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
  description              = "Allow port 5432 from Lambda security group"
}

resource "aws_security_group_rule" "proxy_ingress_bastion" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.proxy_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
  description              = "Allow port 5432 from Bastion security group"
}

resource "aws_security_group_rule" "proxy_egress_db" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.proxy_sg.id
  source_security_group_id = aws_security_group.rds_sg.id
  description              = "Allow database connection to RDS SG"
}

# 4. RDS Database SG Rules
resource "aws_security_group_rule" "rds_ingress_proxy" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.proxy_sg.id
  description              = "Allow database traffic from RDS Proxy SG only"
}

resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound egress from database"
}

# 5. Bastion SG Rules
resource "aws_security_group_rule" "bastion_egress_proxy" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.proxy_sg.id
  description              = "Allow database connection to RDS Proxy SG"
}

resource "aws_security_group_rule" "bastion_egress_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.endpoints_sg.id
  description              = "Allow HTTPS egress to VPC Endpoints"
}

# --- AWS Secrets Manager for DB Credentials (RDS Proxy requirement) ---
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-db-creds"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "verity_user"
    password = var.database_password
  })
}

# --- IAM Role for RDS Proxy ---
resource "aws_iam_role" "proxy_role" {
  name = "${var.project_name}-${var.environment}-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "proxy_policy" {
  name = "${var.project_name}-${var.environment}-proxy-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "proxy_policy_attach" {
  role       = aws_iam_role.proxy_role.name
  policy_arn = aws_iam_policy.proxy_policy.arn
}

# --- AWS RDS PostgreSQL Database Instance (Multi-AZ & Private) ---
resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-${var.environment}-db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t4g.micro"
  db_name                = "verity_db"
  username               = "verity_user"
  password               = var.database_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# --- AWS RDS Proxy ---
resource "aws_db_proxy" "rds_proxy" {
  name                   = "${var.project_name}-${var.environment}-proxy"
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.proxy_role.arn
  vpc_subnet_ids         = [aws_subnet.subnet_private_app_a.id, aws_subnet.subnet_private_app_b.id]
  vpc_security_group_ids = [aws_security_group.proxy_sg.id]

  auth {
    auth_scheme = "SECRETS"
    description = "RDS Proxy authentication via Secrets Manager"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }

  depends_on = [
    aws_secretsmanager_secret_version.db_credentials_val
  ]
}

resource "aws_db_proxy_default_target_group" "proxy_tg" {
  db_proxy_name = aws_db_proxy.rds_proxy.name

  connection_pool_config {
    max_connections_percent      = 90
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "proxy_target" {
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.proxy_tg.name
  db_instance_identifier = aws_db_instance.postgres.id
}

# --- VPC Endpoints for S3 (Gateway) and AWS Services (Interface) ---

# S3 Gateway Endpoint (Assigned to Private App Route Table)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]
}

# SSM Endpoint (Interface)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_private_app_a.id, aws_subnet.subnet_private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true
}

# SSM Messages Endpoint (Interface - Required for Session Manager)
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_private_app_a.id, aws_subnet.subnet_private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true
}

# EC2 Messages Endpoint (Interface - Required for Session Manager)
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_private_app_a.id, aws_subnet.subnet_private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true
}

# KMS Endpoint (Interface - Required to decrypt parameter store values)
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_private_app_a.id, aws_subnet.subnet_private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true
}

# CloudWatch Logs Endpoint (Interface - Required for Lambda Logging)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_private_app_a.id, aws_subnet.subnet_private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true
}

# --- AWS SSM Bastion Host Setup (Session Manager Port-Forwarding Tunnel) ---

# Bastion Instance IAM Role
resource "aws_iam_role" "bastion_role" {
  name = "${var.project_name}-${var.environment}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Session Manager permissions
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.project_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# Locate Amazon Linux 2023 ARM64 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-arm64"]
  }
}

# Provision Bastion Instance
resource "aws_instance" "bastion" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t4g.nano"
  subnet_id            = aws_subnet.subnet_private_app_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }
}

# --- Core Infrastructure Module Instantiation ---
module "core_infrastructure" {
  source = "../../modules/core_infrastructure"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  domain_name        = var.domain_name
  backend_secret_key = var.backend_secret_key
  database_password  = var.database_password

  database_url           = "postgresql://verity_user:${var.database_password}@${aws_db_proxy.rds_proxy.endpoint}/verity_db?sslmode=require"
  vpc_subnet_ids         = [aws_subnet.subnet_private_app_a.id, aws_subnet.subnet_private_app_b.id]
  vpc_security_group_ids = [aws_security_group.lambda_sg.id]
}
