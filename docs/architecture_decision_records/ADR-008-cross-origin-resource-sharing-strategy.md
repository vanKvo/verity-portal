# ADR-008: Cross-Origin Resource Sharing (CORS) and Token Security Strategy

## Status
Accepted

## Date
2026-05-18

## Context
As a decoupled client-server application, the Verity Portal frontend (Angular running on `http://localhost:4200`) must communicate with the backend API (FastAPI running on `http://localhost:8000`). Because these exist on different origins, the browser enforces the Same-Origin Policy.

To authorize requests (such as uploading compliance rosters), the frontend must attach a stateless JWT access token in the `Authorization: Bearer <token>` header. However, making credentialed cross-origin requests introduces two security and functional challenges:
1. **Token Leakage Risk**: A naive Angular HTTP interceptor that attaches the `Authorization` header to *every* outgoing request will leak sensitive JWT tokens to any third-party APIs (e.g., external CDNs, mapping services, or fonts) called by the frontend.
2. **CORS Preflight Restrictions**: The browser sends an `OPTIONS` preflight request before any non-simple request (such as `POST` requests with JSON payloads or custom headers like `Authorization`). If the backend's CORS configuration is invalid, the preflight request fails, leading to `401 Unauthorized` or CORS blocks.
3. **Credentials and Wildcards**: Under the W3C CORS specification, when a request is made with credentials/headers (`Access-Control-Allow-Credentials: true`), the server's `Access-Control-Allow-Origin` header **cannot** be a wildcard (`*`). It must explicitly match the incoming origin.

## Decision
We decided to adopt a zero-trust, highly-secure CORS and token propagation policy:

1. **Explicit Client-Side Origin Filtering**: The frontend functional `authInterceptor` must never globally append the `Authorization` header. Instead, it must inject `ConfigService` and explicitly verify that the destination URL starts with the backend's configured `apiUrl` before attaching the JWT.
2. **Non-Wildcard Backend CORS Configuration**: We deprecated the `allow_origins=["*"]` wildcard in the backend's FastAPI `CORSMiddleware`. Instead, the backend must dynamically accept or explicitly whitelist known client origins (e.g., `http://localhost:4200` in development, or specific environments configured via `.env`).
3. **Safe Preflight Handling**: FastAPI's `CORSMiddleware` will intercept and automatically handle the `OPTIONS` preflight negotiations before they reach protected route dependencies (which would otherwise reject them due to missing tokens).

## Alternatives Considered

### Global Interceptor Headers (No Origin Filtering)
- **Pros**: Extremely simple to write; no config dependency in interceptors.
- **Cons**: Severe security vulnerability. It will transmit the client's high-stakes compliance token to any external web service the application communicates with.
- **Rejected**: Fails strict enterprise security guidelines.

### Wildcard Origins with Disabled Credentials
- **Pros**: Bypasses the wildcard restriction by not allowing credentials.
- **Cons**: We cannot send the standard `Authorization` header, breaking our role-based authorization model (`ROLE_HR`, `ROLE_ECO`, `ROLE_PM`).
- **Rejected**: Strict RBAC requires secure token authorization headers.

## Consequences
- **Security**: Zero leakage of sensitive JWT credentials to external endpoints.
- **Compliance**: The strict separation of origins and restriction of whitelisted domains aligns with federal compliance standards (such as CMMC 2.0 AC.L2-3.1.22 for controlling public information flow).
- **Maintainability**: Adding new backend services or changing domain hosts only requires updating the centralized environment configuration (`ConfigService` and `.env`), without changing interceptor or router logic.
