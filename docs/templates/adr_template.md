# ADR-[Number]: [Title]

## Status
[Proposed | Accepted | Rejected | Deprecated | Superceded]

## Date
YYYY-MM-DD

## Context
[Describe the forces at play, including the problem statement, business constraints, and technical requirements.]

Key requirements:
- [Requirement 1]
- [Requirement 2]

**Example:**
Verity Portal is an automated data reconciliation and compliance engine for the defense sector. We require an authentication mechanism that secures corporate data while simultaneously supporting a low-friction "Guest Login" feature to allow recruiters or evaluators to bypass the standard registration flow during demos.

Key requirements:
- Securing standard user accounts using corporate domains (`corporate.com`, `verity.com`).
- Secure password handling.
- Stateless authentication suitable for an Angular frontend and FastAPI backend via REST API.
- Immediate access for guests/recruiters without creating full user profiles with credentials.

## Decision
[State the chosen solution clearly. Explain the "How" and "What" of the implementation. Use numbered lists for specific flows, architecture components, or steps if applicable.]

**Example:**
We will use **OAuth2 with stateless JWT (JSON Web Tokens)** and **Bcrypt** for password hashing. The auth flow will consist of three paths:
1. `POST /auth/register`: Creates a permanent user after validating the corporate email domain. Hashes passwords via Bcrypt.
2. `POST /auth/login`: Issues a standard JWT.
3. `POST /auth/guest-login`: Issues a temporary JWT assigned to a pseudo "guest" user role. This bypasses the password requirement and allows the UI to render the dashboard immediately.

## Alternatives Considered

### [Alternative 1 Name]
- Pros: [Why this was a good idea]
- Cons: [Why this was a bad idea]
- Rejected: [Specific reason why it was not chosen]

**Example:**
### Session-based Cookies
- Pros: Simple to invalidate, well-supported.
- Cons: Requires server-side state (e.g., Redis). May add complexity given our strict Hexagonal architecture and potential for stateless API scaling.
- Rejected: JWTs simplify the FastAPI backend implementation and align better with typical single-page application (Angular) decoupled architectures.

## Consequences
[Describe the outcomes of the decision—both positive and negative. Use a simple bulleted list to detail technical debts, new requirements, or system changes.]

**Example:**
- The frontend must securely store the JWT (preferably in memory or secure HTTP-only cookies eventually, but `localStorage`/`sessionStorage` initially for development).
- Guest users will not have persistent database records, or will share a generic "guest" identity payload encoded entirely in the JWT.
- We must implement JWT decoding and validation in FastAPI dependencies to protect Domain Layer endpoints.
