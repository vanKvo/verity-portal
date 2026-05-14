# Phase 2: Auth Module & Guest Login Technical Design

---

App Version: 1.0.0

---

## Objective
Focus: Secure Identity Management and Stateless Authentication

## Tech Stack
- **Base Stack:** See [tech_stack.md](tech_stack.md)
- **Module Specific:** PyJWT, Passlib (Bcrypt)

## Project Structure
- `backend/src/verity_portal/identity/models.py` → User entity and password hashing logic.
- `backend/src/verity_portal/identity/router.py` → Login/Register/Guest endpoints.
- `frontend/src/app/core/services/auth.service.ts` → Signal-based auth state.
- `frontend/src/app/core/guards/auth.guard.ts` → Route protection logic.

## Code Style & Standards
- **Statelessness:** The backend must not use server-side sessions.
- **Signal-Based State:** The frontend must use Angular Signals for the `currentUser` state to ensure reactive UI updates.
- **Interface-Driven:** Auth responses must follow the `AuthResponse` interface.

## Boundaries
- **Always do:** Use `localStorage` or `sessionStorage` for token storage during this phase.
- **Never do:** Return the user's hashed password in any API response.

---

## Requirements

### FR-2.1: Corporate Domain Validation
**Architectural Rationale:** Centralizing domain validation in the `User` domain model ensures that business rules are enforced regardless of the entry point (API or CLI).

#### Technical Design Specification
- **Library:** `passlib[bcrypt]` for secure hashing.
- **Validation:** Regex-based domain check against a configurable whitelist.

#### Implementation Details
- [x] Implemented `User` domain model with `verify_password` and `hash_password`.
- [x] Added `UserModel` SQLAlchemy adapter.
- [x] Implemented `/auth/register` with domain validation.

#### Verification Plan
- [x] **Manual Check:** Verify that registration fails if the email domain is not in the whitelist.

---

### FR-2.2: Stateless JWT Authentication
**Architectural Rationale:** JWTs allow for a decentralized authentication check, reducing database load on subsequent requests.

#### Technical Design Specification
- **Library:** `PyJWT` for token encoding/decoding.
- **Flow:** Standard OAuth2 Password flow.

#### Implementation Details
- [x] Implemented token generation utility.
- [x] Created `AuthService` in Angular to manage login and token persistence.
- [x] Implemented `AuthGuard` to protect dashboard routes.

#### Verification Plan
- [x] **Manual Check:** Verify that accessing `/dashboard` without a valid token redirects the user to the login page.

---

### FR-2.3: Frictionless Guest Access
**Architectural Rationale:** Utilizing the same JWT mechanism for guests ensures that the frontend logic for authentication remains unified.

#### Technical Design Specification
- **Logic:** Issuing a token with `sub: guest` and `role: guest` without a database lookup.

#### Implementation Details
- [x] Implemented `/auth/guest-login` endpoint.
- [x] Added "Guest Access" button to the `LoginComponent`.
- [x] Configured `GuestGuard` to allow recruiters immediate entry.

#### Verification Plan
- [x] **Manual Check:** Verify that clicking "Guest Login" successfully authenticates the user and navigates to the dashboard.

---

### FR-2.4: Stubbed RBAC Contract (Deferred Complexity)
**Architectural Rationale:** We must secure endpoints early to ensure our TDD process is accurate (tests must supply valid roles), but we want to avoid building a complex role administration UI right now.

#### Technical Design Specification
- **Backend Contract:** Create a simple FastAPI dependency `require_role(role_name: str)` that inspects the JWT payload's `roles` array.
- **Token Injection:** During login or guest access, inject a hardcoded array of roles (e.g., `["ROLE_EXPORT_CONTROL"]`) into the token payload.
- **Frontend Deferment:** Do not build UI guards for hiding elements based on roles yet. Let the backend handle 403 Forbidden rejections.

#### Implementation Details
- [ ] Implement `require_role` in `backend/src/verity_portal/core/security/roles.py`.
- [ ] Update `Guest Login` token generation to include necessary module roles.

#### Verification Plan
- [ ] **Unit Test:** Verify that accessing an endpoint with `Depends(require_role("ADMIN"))` using a standard user token returns HTTP 403.

