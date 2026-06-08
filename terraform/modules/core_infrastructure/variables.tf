variable "project_name" {
  description = "The name of the project, used to build resource naming prefix."
  type        = string
  default     = "verity-portal"
}

variable "environment" {
  description = "The target deployment environment (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "The target AWS region for deployment (must be us-east-1 to coordinate ACM and CloudFront)."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "The root domain name hosted in Route 53 (e.g. vanmuses.com)."
  type        = string
  default     = "vanmuses.com"
}

variable "backend_secret_key" {
  description = "The secret key used for signing backend JWT access tokens."
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "The database administrator password for the RDS instance."
  type        = string
  sensitive   = true
  default     = ""
}

variable "database_url" {
  description = "The connection URL for the database."
  type        = string
  sensitive   = true
}

variable "vpc_subnet_ids" {
  description = "A list of subnet IDs to associate with the Lambda function for VPC access."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "A list of security group IDs to associate with the Lambda function for VPC access."
  type        = list(string)
  default     = []
}
