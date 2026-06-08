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

# Subnet A (us-east-1a)
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-a"
  }
}

# Subnet B (us-east-1b)
resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-b"
  }
}

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

resource "aws_route_table_association" "assoc_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "assoc_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# --- Security Groups ---
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for production RDS PostgreSQL"
  vpc_id      = aws_vpc.vpc.id

  # Public ingress for migrations from local-exec runner
  ingress {
    description = "Allow Postgres traffic from anywhere for migrations"
    from_port   = 5432
    to_port     = 5432
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
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for production backend Lambda"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

resource "aws_security_group" "proxy_sg" {
  name        = "${var.project_name}-${var.environment}-proxy-sg"
  description = "Security group for RDS Proxy"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow port 5432 from Lambda security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-proxy-sg"
  }
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

# --- AWS RDS PostgreSQL Database Instance (Multi-AZ) ---
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
  publicly_accessible    = true
  skip_final_snapshot    = true
}

# --- AWS RDS Proxy ---
resource "aws_db_proxy" "rds_proxy" {
  name                   = "${var.project_name}-${var.environment}-proxy"
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.proxy_role.arn
  vpc_subnet_ids         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
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

# --- VPC Endpoints for S3 (Gateway) and SSM (Interface) ---
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public_rt.id]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true
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
  vpc_subnet_ids         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  vpc_security_group_ids = [aws_security_group.lambda_sg.id]
}
