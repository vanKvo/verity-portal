# ADR-012: Lambda Cold-Start and Initialization Timeout Remediation

## Status
Accepted

## Date
2026-06-06

## Context
During the deployment of the containerized backend (FastAPI, SQLAlchemy, boto3) to AWS Lambda, we encountered severe initialization timeouts and connection failures:
1. **Lambda Init Timeout**: The Lambda function failed with `Init Duration: 9999.28 ms Phase: init Status: timeout` and `HTTP 503 Service Unavailable`. Under the default `512` MB memory configuration, the allocated CPU capacity (~30% of a vCPU) was insufficient to complete Python module imports (specifically FastAPI, SQLAlchemy, Pydantic, and boto3) and configuration instantiation within the AWS Lambda 10-second initialization limit.
2. **Environment Variable Configuration Crash**: Instantiating the Pydantic Settings class raised a `ValidationError` because `AWS_DEFAULT_REGION` was declared as a required field but was absent from the Lambda environment. Adding `AWS_DEFAULT_REGION` directly to the Lambda function's environment block is forbidden by AWS because it is a reserved environment variable.

## Decision
We decided to resolve these performance and configuration constraints with the following changes:

1. **Increase Lambda Memory to 1536MB**: We increased the Lambda memory setting from `512` MB to `1536` MB in [main.tf](file:///Users/gabong/Documents/Programming/verity-portal/terraform/main.tf). Since AWS Lambda allocates CPU capacity proportionally to memory, a `1536` MB configuration assigns approximately 1 full vCPU, cutting module import and cold start initialization time to ~3 seconds.
2. **Align with Standard AWS_REGION**: We modified [config.py](file:///Users/gabong/Documents/Programming/verity-portal/backend/src/verity_portal/core/config.py) and other AWS clients to use the standard, non-reserved `AWS_REGION` variable with a default fallback of `us-east-1` instead of `AWS_DEFAULT_REGION`. Pydantic automatically reads `AWS_REGION` which is injected by the Lambda runtime.
3. **Automated Container Redeployment Trigger**: Because the backend uses a mutable ECR tag (`latest`), Terraform does not automatically update the Lambda function when the container is rebuilt. We added a `REBUILD_TRIGGER = null_resource.build_push_backend.id` environment variable to the Lambda configuration. This forces a Lambda configuration update and image pull on every successful ECR push.

## Alternatives Considered

### Retaining 512MB Memory and Optimizing Imports
* **Pros**: Slightly lower cost per execution second.
* **Cons**: Import overhead of SQLAlchemy, Pydantic, and boto3 is structurally heavy and cannot easily be optimized below 10 seconds on a resource-constrained CPU.
* **Rejected**: Does not solve the initialization timeout constraint reliably.

### Using Provisioned Concurrency
* **Pros**: Pre-warms containers and eliminates cold start latency entirely.
* **Cons**: Charges for active execution time regardless of traffic.
* **Rejected**: Violates our "scale-to-zero" and "zero-idle-cost" requirements.

## Consequences
* **Rapid Cold Starts**: Cold start duration dropped from >10s (causing timeouts) to under ~3s, guaranteeing smooth operation without HTTP gateway errors.
* **Compliant Region Resolution**: By reading the runtime-injected `AWS_REGION` instead of trying to pass `AWS_DEFAULT_REGION`, we avoid conflicts with reserved AWS environment variables.
* **Continuous Integration Integration**: Every successful `terraform apply` that modifies backend files now triggers an automatic ECR build, push, and Lambda function code update.
