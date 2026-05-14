---
App Version: 1.0.0
---

## Objective
Implement a secure, stateless authentication system that supports both permanent corporate users and frictionless guest access for demos.

## Requirement ID: FR-2.1 – Corporate Domain Validation
### Business Context & Rationale (The "Why")
To ensure that only authorized personnel from Verity or partner corporations can create permanent accounts, registration must be restricted to specific email domains.

### Functional Requirements
- **FR-2.1.1: Domain Whitelisting.** The system shall only allow registration for users with email addresses from a pre-configured list of allowed domains (e.g., `corporate.com`).
- **FR-2.1.2: Password Hashing.** All user passwords must be hashed using a secure, industry-standard algorithm (Bcrypt).

### Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that registration fails if the email domain is not in the whitelist.
- **AC 2:** Verify that passwords are never stored in plain text in the database.

---

## Requirement ID: FR-2.2 – Stateless JWT Authentication
### Business Context & Rationale (The "Why")
A stateless architecture allows the backend to scale easily and simplifies the interaction between the Angular frontend and the REST API.

### Functional Requirements
- **FR-2.2.1: JWT Issuance.** Upon successful login, the system shall issue a JSON Web Token (JWT) containing user identity and roles.
- **FR-2.2.2: Protected Routes.** The frontend shall use the JWT to authorize access to protected routes and API endpoints.

### Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that accessing `/dashboard` without a valid token redirects the user to the login page.
- **AC 2:** Verify that the token contains the correct `sub` and `role` claims.

---

## Requirement ID: FR-2.3 – Frictionless Guest Access
### Business Context & Rationale (The "Why")
Recruiters and evaluators need immediate access to the dashboard to view the portal's capabilities without the friction of a full registration and verification process.

### Functional Requirements
- **FR-2.3.1: Guest JWT.** The system shall provide a "One-Click Guest Login" that issues a temporary JWT with a `guest` role.
- **FR-2.3.2: Restricted Persistence.** Guest users shall have access to demo features but will not have persistent account records.

### Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that clicking "Guest Login" successfully authenticates the user and navigates to the dashboard.
