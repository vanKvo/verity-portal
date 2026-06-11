# ADR-014: AWS Production Deployment Architecture Alignment

## Status
Accepted

## Date
2026-06-11

## Context
To prepare the Verity Portal for secure production deployment, we audited the existing AWS production Terraform configurations (`terraform/environments/prod/main.tf` and related modules) against the AWS Well-Architected Framework and the AWS Deployment diagram. The audit identified several critical design gaps:
1. **Network Exposure:** The RDS database was exposed to the public internet in public subnets with `publicly_accessible = true` and a security group permitting unrestricted `0.0.0.0/0` ingress to run migrations.
2. **Security Group Cycles:** Defining security group rules inline inside security group resource blocks caused circular dependencies (`Cycle: aws_security_group.lambda_sg -> proxy_sg -> rds_sg -> endpoints_sg -> lambda_sg`) that blocked Terraform from initializing or planning.
3. **Lambda Execution Risks:** In a NAT-less private subnet environment, the FastAPI Lambda backend would timeout on cold starts because it could not communicate with KMS (to decrypt SSM parameters) or CloudWatch Logs (to stream stdout/stderr logs) without direct VPC routing.
4. **Declarative Import Failures:** The production environment included a copy-pasted `imports.tf` block from the development environment that attempted to import existing S3 and IAM resources from the active account. Since those resources do not exist in the production environment yet, Terraform plan execution consistently failed.

## Decision
We aligned the production Terraform configurations with the target Well-Architected blueprint using the following design choices:

1. **3-Tier Subnet Topology:** Structured the VPC across two Availability Zones (`us-east-1a` and `us-east-1b`) into three distinct tiers:
   * **Public Subnets:** Mapped public IPs on launch and route to the Internet Gateway.
   * **Private Application Subnets:** Mapped private IPs only, hosting the Lambda backend, VPC Interface Endpoints, and the Bastion Host.
   * **Isolated Database Subnets:** Host the PostgreSQL database instances with no route to the internet.
2. **Security Group Decoupling:** Re-declared all security groups (`endpoints_sg`, `lambda_sg`, `proxy_sg`, `rds_sg`, and `bastion_sg`) as empty containers, then defined all rules using separate `aws_security_group_rule` resources. This resolved the circular dependency cycle.
3. **Strict SG Access Chain:** Enforced a zero-trust network ingress chain: Lambda Security Group $\rightarrow$ RDS Proxy Security Group $\rightarrow$ RDS DB Security Group. Ingress to the database is strictly limited to the RDS Proxy.
4. **VPC Endpoints (NAT-less Routing):** Associated the S3 Gateway Endpoint with the private route table for cost-free private S3 reads/writes. Provisioned Interface Endpoints for SSM, SSM Messages, EC2 Messages, KMS, and CloudWatch Logs in the Private Application subnets, associated with the endpoints security group.
5. **SSM Port-Forwarding Bastion Host:** Provisioned a lightweight `t4g.nano` ARM64 Amazon Linux 2023 EC2 instance in Private Application Subnet A with an IAM instance profile carrying the `AmazonSSMManagedInstanceCore` policy. The instance runs with zero open inbound ports. Developers connect using SSM port-forwarding to tunnel SQL client traffic. Set `publicly_accessible = false` on the RDS DB instance.
6. **Clean Slate Deployment:** Renamed `prod/imports.tf` to `prod/imports.tf.backup`. This bypasses non-existent import failures and lets Terraform build the production pipeline from scratch.

## Alternatives Considered

### Deploying a NAT Gateway for Private Internet Egress
* **Pros:** Simpler configuration; allows Lambdas to access arbitrary external resources.
* **Cons:** Expensive. NAT Gateways cost approximately $32/month per gateway baseline, plus data processing fees, which violates the cost optimization design directive.
* **Rejected:** interface endpoints are cheaper and restrict outbound traffic strictly to designated AWS APIs, enhancing security.

## Consequences
* **Well-Architected Compliance:** Production infrastructure matches AWS best practices with network boundaries separating the database, application, and public entry points.
* **Zero Public Entry Points:** Neither the database nor the bastion host has a public IP address or open public ports, eliminating external scanning vectors.
* **No Dependency Cycles:** The Terraform configuration builds and plans successfully without compilation cycles.
* **Clean Deployability:** Renaming the imports configuration ensures that `terraform plan` outputs a clean slate plan of **99 resources to add** with zero execution errors.
