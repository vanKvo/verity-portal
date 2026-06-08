# --- Neon Serverless PostgreSQL Database ---
resource "neon_project" "db_project" {
  name                      = "${var.project_name}-${var.environment}"
  org_id                    = var.neon_org_id
  history_retention_seconds = 21600 # Enables 6 hours of PITR
}

resource "neon_role" "db_role" {
  project_id = neon_project.db_project.id
  branch_id  = neon_project.db_project.default_branch_id
  name       = "verity_user"
}

resource "neon_database" "db" {
  project_id = neon_project.db_project.id
  branch_id  = neon_project.db_project.default_branch_id
  name       = "verity_db"
  owner_name = neon_role.db_role.name
}

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

  database_url           = "postgresql://${neon_role.db_role.name}:${neon_role.db_role.password}@${neon_project.db_project.database_host}/${neon_database.db.name}?sslmode=require"
  vpc_subnet_ids         = []
  vpc_security_group_ids = []
}
