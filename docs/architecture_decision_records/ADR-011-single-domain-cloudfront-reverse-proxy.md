# ADR-011: Single Domain CloudFront Reverse Proxy Architecture

## Status
Accepted

## Date
2026-06-06

## Context
In our initial serverless architecture plan, the application was split across two distinct public subdomains:
1. **Frontend**: Mapped to `verityportal.vanmuses.com` pointing to a CloudFront distribution backed by an S3 bucket.
2. **Backend**: Mapped to `api.verityportal.vanmuses.com` pointing to an HTTP API Gateway invoking the FastAPI Lambda function.

While functional, this multi-origin architecture introduced several security, operational, and complexity challenges:
* **CORS (Cross-Origin Resource Sharing) Overhead**: Because the frontend and backend resided on different origins, the user's browser was forced to perform CORS preflight (`OPTIONS`) negotiations for state-changing requests. This increased request latency and required maintaining explicit CORS headers on the FastAPI backend, making it susceptible to misconfiguration or drift.
* **Token Storage Restrictions**: Securing JWT access tokens in client-side `localStorage` exposes them to Cross-Site Scripting (XSS) attacks. A separate subdomain architecture prevents using secure, backend-issued `HttpOnly` cookies with `SameSite=Strict` flags, which is the industry standard for token transport.
* **Attack Surface Exposure**: Exposing the API Gateway directly on a public subdomain reveals the backend endpoint hosting parameters, making it vulnerable to direct scanner discovery, DDoS attacks, or brute force attempts.
* **Administrative Overhead**: Managing Route 53 A-records, ACM SSL validation checks, and API Gateway custom domain mappings for multiple subdomains increases setup complexity and deployment latency.

## Decision
We decided to completely hide the backend API Gateway behind the CloudFront distribution using a **Single Domain CloudFront Reverse Proxy** architecture:

1. **Unified Subdomain**: The entire application (both static assets and API calls) is served under a single subdomain: `verityportal.vanmuses.com`.
2. **Dual Origins in CloudFront**: The CloudFront distribution is configured with two origins:
   * **S3 Bucket Origin**: Stores the static Angular assets, protected by Origin Access Control (OAC).
   * **API Gateway Origin**: Connects CloudFront directly to the backend API Gateway using custom origin configurations.
3. **Path-Based Cache Behaviors**: We configure dynamic cache behaviors in CloudFront to match all API routing prefixes (`/auth/*`, `/intake/*`, `/audit/*`, `/itar/*`, `/data-hub/*`, `/asset-audit/*`, `/health`) and forward them directly to the API Gateway origin. All other traffic falls through to the S3 bucket origin.
4. **CloudFront Function SPA Routing**: We deploy an edge CloudFront Function (`spa_rewrite`) associated with the default cache behavior. It inspects viewer requests and rewrites paths without file extensions (like `/itar-audit` or `/dashboard`) to `/index.html` at the edge in sub-milliseconds.
5. **Removal of Public API Gateway Domain**: The custom domain mappings, Route 53 record sets, and ACM validation configurations for `api.verityportal.vanmuses.com` are completely removed. The API Gateway is hidden from public DNS resolution.

## Alternatives Considered

### Exposing Backend Subdomain with CORS (Previously Planned)
* **Pros**: Simple separate routing configurations in Terraform.
* **Cons**: High CORS complexity, exposes API Gateway domain, prevents the use of strict `SameSite` cookies, and requires multiple Route 53 records.
* **Rejected**: Does not satisfy enterprise security best practices for API shielding.

### Reverse Proxy via Backend-For-Frontend (BFF) Server
* **Pros**: Complete server-side control over auth token exchanges and API routing.
* **Cons**: Requires running an active server instance (e.g., ECS Fargate or EC2) which prevents the application from scaling to zero during idle periods, introducing fixed monthly running costs.
* **Rejected**: Violates our "zero-idle cost" constraint.

## Consequences
* **Enhanced Security**: The backend API is shielded from the public internet. All API requests must traverse CloudFront, allowing us to enforce security policies and block malicious traffic using a single **AWS WAF (Web Application Firewall)** instance attached to the CloudFront distribution.
* **Simplified CORS**: Since both the client-side code and API endpoints are requested from the same domain, origin, and port, CORS preflight checks are bypassed.
* **Secure Cookie Authentication**: Lays the foundation for switching token storage from browser memory/`localStorage` to secure `HttpOnly`, `SameSite=Strict` cookies in future phases.
* **No API Error Interception**: By utilizing an edge CloudFront Function to rewrite SPA paths *before* they reach S3, we avoid configuring global custom error pages (`custom_error_response` in CloudFront). This ensures S3 serves `/index.html` correctly for frontend routes, while backend `404` errors (returned from API Gateway) pass back to the client as clean JSON rather than being intercepted and replaced by Angular HTML.
* **Reduced DNS Complexity**: Only one subdomain (`verityportal.vanmuses.com`) requires Route 53 record sets and ACM certificate validation.
