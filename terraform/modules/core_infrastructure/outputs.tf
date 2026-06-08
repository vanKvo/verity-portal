output "frontend_url" {
  description = "The URL of the Angular frontend static website."
  value       = "https://verityportal.${var.domain_name}"
}

output "backend_url" {
  description = "The URL of the API endpoints (routed through CloudFront)."
  value       = "https://verityportal.${var.domain_name}"
}

output "ingest_bucket_name" {
  description = "The name of the S3 bucket created for ingestion uploads."
  value       = aws_s3_bucket.ingest_bucket.id
}


