# --- Imports for Existing S3 Ingest Infrastructure ---
# Using Terraform 1.5+ declarative import blocks to sync existing AWS resources into the state.

import {
  to = module.core_infrastructure.aws_s3_bucket.ingest_bucket
  id = "${var.project_name}-${var.environment}-ingest-bucket"
}

import {
  to = module.core_infrastructure.aws_s3_object.folder_procurement
  id = "${var.project_name}-${var.environment}-ingest-bucket/procurement/"
}

import {
  to = module.core_infrastructure.aws_s3_object.folder_projects
  id = "${var.project_name}-${var.environment}-ingest-bucket/projects/"
}

import {
  to = module.core_infrastructure.aws_s3_object.folder_hr
  id = "${var.project_name}-${var.environment}-ingest-bucket/hr/"
}

import {
  to = module.core_infrastructure.aws_s3_object.folder_inventory
  id = "${var.project_name}-${var.environment}-ingest-bucket/inventory/"
}

import {
  to = module.core_infrastructure.aws_s3_object.folder_it_activity
  id = "${var.project_name}-${var.environment}-ingest-bucket/it_activity/"
}

import {
  to = module.core_infrastructure.aws_iam_role.ingest_lambda_role
  id = "${var.project_name}-${var.environment}-ingest-lambda-role"
}

import {
  to = module.core_infrastructure.aws_iam_role_policy_attachment.ingest_lambda_logs
  id = "${var.project_name}-${var.environment}-ingest-lambda-role/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

import {
  to = module.core_infrastructure.aws_lambda_function.s3_ingest
  id = "${var.project_name}-${var.environment}-s3-ingest-router"
}

import {
  to = module.core_infrastructure.aws_cloudwatch_log_group.s3_ingest_log_group
  id = "/aws/lambda/${var.project_name}-${var.environment}-s3-ingest-router"
}

import {
  to = module.core_infrastructure.aws_lambda_permission.allow_s3
  id = "${var.project_name}-${var.environment}-s3-ingest-router/AllowExecutionFromS3Bucket-${var.environment}"
}

import {
  to = module.core_infrastructure.aws_s3_bucket_notification.bucket_notification
  id = "${var.project_name}-${var.environment}-ingest-bucket"
}
