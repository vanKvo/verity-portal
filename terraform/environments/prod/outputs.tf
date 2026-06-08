output "frontend_url" {
  description = "The URL of the Angular frontend static website."
  value       = module.core_infrastructure.frontend_url
}

output "backend_url" {
  description = "The URL of the API endpoints (routed through CloudFront)."
  value       = module.core_infrastructure.backend_url
}

output "ingest_bucket_name" {
  description = "The name of the S3 bucket created for ingestion uploads."
  value       = module.core_infrastructure.ingest_bucket_name
}

output "rds_proxy_endpoint" {
  description = "The database connection hostname (RDS Proxy endpoint)."
  value       = aws_db_proxy.rds_proxy.endpoint
}
