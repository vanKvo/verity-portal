# AWS Route 53 Hosted Zone Data Retrieval
data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
}

# --- ACM SSL Certificate Provisioning ---
# Create custom SSL certificates for verityportal
# Must target the alias provider in us-east-1 for CloudFront compatibility.
resource "aws_acm_certificate" "cert" {
  provider                  = aws.us_east_1
  domain_name               = "verityportal.${var.domain_name}"
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS Validation Records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

# Wait for validation completion
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# --- AWS SSM Parameter Store Setup ---
# Encrypt and store sensitive database and JWT credentials in SSM.
resource "aws_ssm_parameter" "db_url" {
  name        = "/verity-portal/${var.environment}/database_url"
  description = "Connection URI for database instance"
  type        = "SecureString"
  value       = var.database_url
}

resource "aws_ssm_parameter" "secret_key" {
  name        = "/verity-portal/${var.environment}/secret_key"
  description = "Secret key for JWT generation"
  type        = "SecureString"
  value       = var.backend_secret_key
}

# --- Database Migration Runner ---
# Run Alembic upgrade head against database endpoint directly from the deployment runner.
resource "null_resource" "run_migrations" {
  triggers = {
    db_url = var.database_url
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/../../../backend
      DATABASE_URL="${var.database_url}" poetry run alembic upgrade head
    EOT
  }
}

# --- ECR Registry & Backend Docker Image Build ---
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-${var.environment}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "null_resource" "build_push_backend" {
  triggers = {
    dockerfile_hash = filemd5("${path.module}/../../../backend/Dockerfile")
    handler_hash    = filemd5("${path.module}/../../../backend/src/verity_portal/lambda_handler.py")
    config_hash     = filemd5("${path.module}/../../../backend/src/verity_portal/core/config.py")
    platform        = "linux/arm64-v4" # Forces rebuild with correct build settings
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.backend.repository_url}
      DOCKER_BUILDKIT=0 docker build --platform linux/arm64 -t ${aws_ecr_repository.backend.repository_url}:latest -f ${path.module}/../../../backend/Dockerfile ${path.module}/../../../backend
      docker push ${aws_ecr_repository.backend.repository_url}:latest
    EOT
  }
}

# --- Backend IAM Execution Role ---
resource "aws_iam_role" "backend_lambda_role" {
  name = "${var.project_name}-${var.environment}-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Standard basic execution for CloudWatch Logging
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.backend_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for SSM and Ingestion S3 Bucket
resource "aws_iam_policy" "backend_lambda_policy" {
  name        = "${var.project_name}-${var.environment}-backend-policy"
  description = "Provides Lambda access to decrypt SSM parameters and process S3 uploads"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          aws_ssm_parameter.db_url.arn,
          aws_ssm_parameter.secret_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.ingest_bucket.arn,
          "${aws_s3_bucket.ingest_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_lambda_custom" {
  role       = aws_iam_role.backend_lambda_role.name
  policy_arn = aws_iam_policy.backend_lambda_policy.arn
}

# --- Backend Lambda Function ---
resource "aws_lambda_function" "backend" {
  function_name = "${var.project_name}-${var.environment}-backend"
  role          = aws_iam_role.backend_lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.backend.repository_url}:latest"
  timeout       = 30
  memory_size   = 1536
  architectures = ["arm64"]

  environment {
    variables = {
      ENVIRONMENT       = var.environment
      ALLOWED_ORIGINS   = "https://verityportal.${var.domain_name}"
      S3_HR_BUCKET_NAME = aws_s3_bucket.ingest_bucket.id
      REBUILD_TRIGGER   = null_resource.build_push_backend.id
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  depends_on = [
    null_resource.build_push_backend,
    aws_iam_role_policy_attachment.lambda_logs
  ]
}

# VPC execution policy for Lambda inside VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.backend_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Log Retention
resource "aws_cloudwatch_log_group" "backend_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.backend.function_name}"
  retention_in_days = 7
}

# --- HTTP API Gateway Routing ---
resource "aws_apigatewayv2_api" "backend_gateway" {
  name          = "${var.project_name}-${var.environment}-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "backend_integration" {
  api_id           = aws_apigatewayv2_api.backend_gateway.id
  integration_type = "AWS_PROXY"

  connection_type        = "INTERNET"
  description            = "Verity Portal FastAPI integration"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "backend_route" {
  api_id    = aws_apigatewayv2_api.backend_gateway.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.backend_integration.id}"
}

resource "aws_apigatewayv2_stage" "backend_stage" {
  api_id      = aws_apigatewayv2_api.backend_gateway.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backend_gateway.execution_arn}/*/*"
}

# --- Frontend Hosting (S3 + CloudFront) ---
resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-${var.environment}-frontend"
  force_destroy = true
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for frontend S3 static website hosting"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront SPA Routing Rewrite Function
resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${var.project_name}-${var.environment}-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "SPA path rewrite function for Angular routing"
  publish = true
  code    = <<EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // If request has no file extension (no '.'), rewrite to index.html for Angular routing
    if (uri.indexOf('.') === -1) {
        request.uri = '/index.html';
    }
    
    return request;
}
EOT
}

# CloudFront CDN Distribution
resource "aws_cloudfront_distribution" "frontend_cf" {
  # Origin 1: S3 Frontend static files
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  # Origin 2: API Gateway FastAPI Backend
  origin {
    domain_name = replace(aws_apigatewayv2_api.backend_gateway.api_endpoint, "/^https:\\/\\//", "")
    origin_id   = "API-Gateway"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["verityportal.${var.domain_name}"]

  # Default cache behavior handles static assets from S3
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    # SPA URL rewriting CloudFront function
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  # Dynamic behaviors to route API endpoints to API Gateway backend
  dynamic "ordered_cache_behavior" {
    for_each = ["/auth/*", "/intake/*", "/leaver-audit/*", "/itar/*", "/data-hub/*", "/asset-audit/*", "/health"]
    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "API-Gateway"

      forwarded_values {
        query_string = true
        headers      = ["Authorization", "Accept", "Content-Type", "Origin", "Referer", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
        cookies {
          forward = "all"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# S3 Policy restricting access to CloudFront only
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend_cf.arn
          }
        }
      }
    ]
  })
}

# Route 53 DNS mapping for Frontend subdomain
resource "aws_route53_record" "frontend_dns" {
  name    = "verityportal.${var.domain_name}"
  type    = "A"
  zone_id = data.aws_route53_zone.primary.zone_id

  alias {
    name                   = aws_cloudfront_distribution.frontend_cf.domain_name
    zone_id                = aws_cloudfront_distribution.frontend_cf.hosted_zone_id
    evaluate_target_health = false
  }
}

# --- Frontend Compilation & Sync Pipeline ---
resource "null_resource" "build_push_frontend" {
  depends_on = [
    aws_apigatewayv2_stage.backend_stage,
    aws_cloudfront_distribution.frontend_cf
  ]

  triggers = {
    api_url = "https://verityportal.${var.domain_name}"
  }

  provisioner "local-exec" {
    command = <<EOT
      # Set API production endpoints in Angular environment configs
      echo "export const environment = { production: true, apiUrl: 'https://verityportal.${var.domain_name}' };" > ${path.module}/../../../frontend/src/environments/environment.prod.ts
      
      # Build the frontend
      cd ${path.module}/../../../frontend
      npm install
      npm run build
      
      # Sync assets to S3 hosting bucket
      aws s3 sync dist/frontend/browser s3://${aws_s3_bucket.frontend.id} --delete
      
      # Invalidate CloudFront CDN
      aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend_cf.id} --paths "/*"
    EOT
  }
}

# --- S3 Ingestion Bucket ---
resource "aws_s3_bucket" "ingest_bucket" {
  bucket        = "${var.project_name}-${var.environment}-ingest-bucket"
  force_destroy = true
}

# Prefix Folders
resource "aws_s3_object" "folder_procurement" {
  bucket = aws_s3_bucket.ingest_bucket.id
  key    = "procurement/"
}

resource "aws_s3_object" "folder_projects" {
  bucket = aws_s3_bucket.ingest_bucket.id
  key    = "projects/"
}

resource "aws_s3_object" "folder_hr" {
  bucket = aws_s3_bucket.ingest_bucket.id
  key    = "hr/"
}

resource "aws_s3_object" "folder_inventory" {
  bucket = aws_s3_bucket.ingest_bucket.id
  key    = "inventory/"
}

resource "aws_s3_object" "folder_it_activity" {
  bucket = aws_s3_bucket.ingest_bucket.id
  key    = "it_activity/"
}

# --- S3 Ingestion Notification trigger Lambda ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/s3_ingest_lambda_function.py"
  output_path = "${path.module}/s3_ingest_lambda_function.zip"
}

resource "aws_iam_role" "ingest_lambda_role" {
  name = "${var.project_name}-${var.environment}-ingest-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ingest_lambda_logs" {
  role       = aws_iam_role.ingest_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "s3_ingest" {
  function_name    = "${var.project_name}-${var.environment}-s3-ingest-router"
  role             = aws_iam_role.ingest_lambda_role.arn
  handler          = "s3_ingest_lambda_function.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 30

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 

  environment {
    variables = {
      WEBHOOK_URL = "https://verityportal.${var.domain_name}/data-hub/webhooks/s3-ingest"
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.ingest_lambda_logs
  ]
}

resource "aws_cloudwatch_log_group" "s3_ingest_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.s3_ingest.function_name}"
  retention_in_days = 7
}

# Permissions authorizing S3 triggers
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket-${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_ingest.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ingest_bucket.arn
}

# Ingestion S3 Bucket Notification Rules
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.ingest_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "procurement/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "projects/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "hr/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "inventory/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "it_activity/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}
