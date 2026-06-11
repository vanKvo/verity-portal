terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.13.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# The ACM certificate for CloudFront custom domains must be created in us-east-1.
# We define a separate provider alias for ACM if the primary region is not us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "neon" {
  api_key = var.neon_api_key
}
