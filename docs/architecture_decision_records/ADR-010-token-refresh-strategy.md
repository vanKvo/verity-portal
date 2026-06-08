# ADR-010: Token Refresh Strategy (Access + HttpOnly Refresh Token Flow)

## Status
Accepted

## Date
2026-05-28

## Context
Verity Portal users currently experience premature session expiration during operation. The application's JWT access tokens have a short expiration lifespan (30 minutes) to minimize the impact of token leakage. However, forcing users to log out and re-authenticate every 30 minutes degrades the user experience significantly. 

We need a secure session extension mechanism that achieves two goals:
1. Keeps the user's session active seamlessly as long as they are actively using the application.
2. Prevents the security vulnerabilities associated with long-lived tokens stored in accessible browser storage (`localStorage`).

## Decision
We will implement an **Access + HttpOnly Refresh Token Flow** with token rotation.

1. **Short-lived Access Tokens (JWT):** The backend issues an access token with a 30-minute expiration. This token is returned in the JSON response payload and stored in `localStorage` for frontend authorization.
2. **HttpOnly Refresh Cookies:** The backend also generates a cryptographically signed Refresh Token (expires in 7 days) and sets it as an **`HttpOnly`**, **`Secure`** (dynamically toggled based on debug mode), and **`SameSite=Lax`** cookie named `refresh_token`.
3. **On-Demand Silent Refresh:** 
   - We will implement an Angular `HttpInterceptor` that catches `401 Unauthorized` responses from the backend.
   - When a 401 occurs, the interceptor halts failed requests and silently calls `POST /auth/refresh-token` with `withCredentials: true` (instructing the browser to automatically include the HttpOnly cookie).
    - If the refresh token is valid, the backend returns a new Access Token and sets a rotated/refreshed HttpOnly `refresh_token` cookie.
    - The interceptor replaces the stored access token and retries the original failed requests.
    - **Concurrency Locking (Mutex):** Because parallel HTTP requests can all return `401 Unauthorized` simultaneously when the access token expires, a naïve interceptor would fire multiple concurrent `/auth/refresh-token` requests. Under strict token rotation rules, this causes race conditions (and subsequent false security replays). To prevent this, the interceptor uses a synchronization lock (`isRefreshing` boolean) and queues parallel requests using a RxJS `BehaviorSubject`. Only a single refresh request is sent to the backend; all other requests wait and are retried once the new access token is broadcast.
4. **Secure Logout:** A backend `POST /auth/logout` endpoint will be added to securely delete the HttpOnly cookie.

## Alternatives Considered

### Proactive Polling / Sliding Session via LocalStorage
- **Pros:** Extremely simple to implement entirely in frontend JS using timers.
- **Cons:** High CPU overhead due to periodic automatic calls (even when the user is inactive). Requires holding a powerful, long-lived session key in JavaScript-accessible storage (`localStorage`), which is highly vulnerable to Cross-Site Scripting (XSS) extraction.
- **Rejected:** The security standard for sensitive compliance data demands keeping long-lived credentials out of JavaScript scope.

### Stateless Long-Lived Access Tokens (e.g., 24 Hours)
- **Pros:** Zero implementation complexity.
- **Cons:** If an access token is leaked or intercepted, it remains valid for 24 hours with no mechanism for immediate administrative revocation.
- **Rejected:** Strictly prohibited by high-security corporate/defense standards.

## Consequences
- **Security Hardening:** The 7-day session boundary is now fully protected against XSS because the Refresh Token cannot be read by any JavaScript execution on the page.
- **Network Performance & Resource Efficiency:** Token refresh only occurs *on-demand* (when an access token actually expires and the user tries to make a request). This saves substantial CPU cycles on both the frontend and backend compared to polling timers.
- **Race Condition Prevention:** Standard concurrent page requests (e.g., multiple dashboard widgets loading in parallel) do not trigger multiple refresh requests or cause unexpected logouts under sliding token rotation.
- **Cross-Origin Configuration (CORS):** Backend CORS configuration must support `allow_credentials=True` and define explicit allowed origins (`http://localhost:4200`) instead of wildcards (`*`). (This is already supported in our current CORS setup).
- **Session Revocability:** An administrator can disable the account or clear the user session. Once the short-lived access token expires (within minutes), the next automatic refresh will call `/auth/refresh-token`, find the session invalid, and deny entry.
