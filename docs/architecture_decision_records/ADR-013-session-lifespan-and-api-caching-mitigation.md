# ADR-013: Session Lifespan Scoping and API Caching Mitigation

## Status
Accepted

## Date
2026-06-11

## Context
Verity Portal is designed for compliance-sensitive corporate environments ( CMMC 2.0, ITAR, and SOC 2 audits). We observed two critical session lifetime and data security issues:
1. **Persistent Tab Sessions:** The frontend stored user data in `localStorage`, and the backend `refresh_token` cookie was set with a persistent `max_age` of 7 days. This caused sessions (including Guest sessions) to persist indefinitely when tabs were closed and reopened, violating standard corporate session lifespan controls.
2. **Potential Cross-User Data Exposure:** The backend API endpoints did not explicitly return `Cache-Control` headers. Under HTTP/1.1 heuristic caching guidelines (RFC 7234), intermediate CDN caches (like AWS CloudFront) or local browsers could cache `GET` response payloads (such as lists of compliance violations). This meant unauthorized users could potentially be served cached sensitive data directly from the CDN edge cache, bypassing backend authentication and role checks.

## Decision
We decided to resolve these security issues with the following changes:

1. **Frontend Session Scoping:** Move all token and user session storage in the Angular frontend from `localStorage` to `sessionStorage`. Because `sessionStorage` is tab-scoped, closing the browser tab immediately destroys the user's access token.
2. **Session-Only Cookies on Backend:** Remove the `max_age` attribute from the `refresh_token` cookie in the FastAPI backend (`identity/router.py`). When the browser closes, the browser automatically destroys this cookie.
3. **Explicit API Cache Control Middleware:** Add a global HTTP middleware in FastAPI (`main.py`) to inject strict caching headers to prevent browser, proxy, and CDN caching:
   * **For `/health` (Public, Non-Sensitive):** Inject `Cache-Control: public, max-age=60` to allow safe 1-minute caching, saving server and API Gateway invocation costs during high-frequency automated health checks.
   * **For All Other Routes (Private Compliance & Auth):** Inject `Cache-Control: no-store, no-cache, must-revalidate, max-age=0`, `Pragma: no-cache`, and `Expires: 0` to completely block storage.

## Alternatives Considered

### Triggering `/auth/logout` via browser `unload` events
* **Pros**: Explicitly tells the backend to terminate the session on close.
* **Cons**: Extremely unreliable. Browsers frequently abort asynchronous requests during page unload. Additionally, if a user has multiple tabs open, closing one tab would trigger a backend logout, immediately invalidating the session for the remaining active tabs.
* **Rejected**: Insecure and poor user experience.

## Consequences
* **Clean Tab-Close Logouts:** Closing the browser tab now guarantees the session is terminated. Opening the app in a new tab/window will force a redirect to the login screen.
* **Secured CDN and Edge Caching:** All API responses containing sensitive compliance information are guaranteed not to be cached by CloudFront, preventing any unauthorized cross-user session leakage at the CDN layer.
* **Cost Savings for Public Checks:** The `/health` route can be safely served from CloudFront edge caches for up to 1 minute, preventing unnecessary invocations of the backend Lambda function.
