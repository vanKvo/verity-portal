# Master Functional Specification & Roadmap
**Project:** Verity Portal
**App Version:** 1.0.0 (Ongoing)

## Objective
This master document serves as the high-level roadmap and feature tracker for the Verity Portal project. It tracks the implementation status of all major project phases, ensuring alignment between business goals and technical execution.

---

## 🟢 Phase 1: Foundation (Completed)
**Goal:** Establish the core infrastructure and project structure.
- **FR-1.1:** Setup FastAPI backend with Feature-Based Layout (Vertical Slicing).
- **FR-1.2:** Initialize PostgreSQL database with Alembic migrations.
- **FR-1.3:** Setup Angular 21 frontend with Standalone components and Angular Material.
- *Reference:* `phase_1_foundation_spec.md`

## 🟢 Phase 2: Auth Module & Guest Login (Completed)
**Goal:** Secure the application and provide frictionless access for demos.
- **FR-2.1:** Corporate email domain validation for permanent users.
- **FR-2.2:** Stateless JWT authentication (OAuth2).
- **FR-2.3:** "Guest Login" bypass for recruiters/evaluators.
- *Reference:* `ADR-001-authentication-strategy.md`, `phase_2_auth_spec.md`

## 🟢 Phase 3: File Management Service (Completed)
**Goal:** Handle large file ingestion and lifecycle tracking safely.
- **FR-3.1:** 50MB file size validation and asynchronous uploading.
- **FR-3.2:** Temporary `/staging` and permanent `/archive` local storage adapters.
- **FR-3.3:** Database tracking of file metadata in the `verity` schema.
- *Reference:* `phase_3_file_management_spec.md`

## 🟢 Phase 4: Shared Mapper Service (Completed)
**Goal:** Provide an intelligent UI to map heterogeneous data silos.
- **FR-4.1:** Fuzzy logic mapping suggestions (`thefuzz` with >70% confidence).
- **FR-4.2:** Data ingestion API (`/intake/confirm`).
- **FR-4.3:** Reactive Angular `SharedMapperComponent` for user overrides.
- *Reference:* `phase_4_mapper_service_spec.md`

## 🟢 Phase 5: Compliance Engine Core & Exports (Completed)
**Goal:** Reconcile data and generate auditor-ready reports.
- **FR-5.1:** Domain exception handling (`MappingError`, `AuditDataInconsistencyError`).
- **FR-5.2:** Date standardization to ISO-8601 during mapping.
- **FR-5.3:** Leaver/Mover audit logic to detect post-termination access violations.
- **FR-5.4:** PDF (`fpdf2`) and CSV sanitized exports.
- *Reference:* `phase_5_compliance_engine_spec.md`

## 🟢 Phase 5.1: Contextual Intake & UX Hardening (Completed)
**Goal:** Enforce workflow progression and dynamic schema awareness.
- **FR-5.1.1:** Context-Aware Dynamic Mapping
Dynamic `requiredSchema` injection for specific audit types (HR vs. IT).
- **FR-5.1.2:** MatStepper Integration (Guided Audit Workflow)
- **FR-5.1.3:** Structured backend error envelopes (JSON) mapped to `MatSnackBar`.
- *Reference:* `phase_5.1_contextual_intake_spec.md`

## 🟢 Phase 5.2: File Upload Dropbox (Completed)
**Goal:** Modernize the file ingestion UX and enforce strict type safety.
- **FR-5.2.1:** Native drag-and-drop file upload component.
- **FR-5.2.2:** Service layer refactoring (`SharedMapperService`).
- **FR-5.2.3:** Body-based API contract for intake confirmation (replacing query params).
- *Reference:* `phase_5.2_file_upload_spec.md`

---

## 🟢 Phase 6: ITAR & Export Control (Completed)
**Goal:** Enforce ITAR compliance by managing personnel access to sensitive projects.
- **FR-6.1:** Implement many-to-many relationship logic between personnel and projects.
- **FR-6.2:** Utilize custom ENUM for citizenship status to prevent data drift from imports.
- **FR-6.3:** Track project sensitivity to specifically identify sensitive projects accessed by foreign nationals.

## 🟢 Phase 7: IT Asset & PO Audit (Completed)
**Goal:** Reconcile Procurement (Finance) with physical Inventory (IT) to identify discrepancies.
- **FR-7.1:** Track `po_number` alongside `asset_tag` to provide a financial audit trail.
- **FR-7.2:** Identify "Ghost Assets" by comparing financial records against physical verification.
- **FR-7.3:** Ensure maintenance and licensing are only paid for hardware in `IN_USE` status.

## 🟢 Phase 8: Leaver/Mover Access Restructuring (Completed)
**Goal:** Restructure the Leaver/Mover Access Audit module to support automated S3 ingestion of IT activity logs, persistent database violation tracking, dynamic email alerts, and an interactive tabbed dashboard.
- **FR-8.1:** Automatically ingest IT activity logs via S3 event notifications and support manual uploads via the Shared Column Mapper.
- **FR-8.2:** Persist compliance violations in the database with status tracking (`OPEN` and `RESOLVED`) and support resolution audits.
- **FR-8.3:** Dispatch automated email notifications to the security office upon detecting post-termination login events.
- **FR-8.4:** Restructure the frontend interface into dual tabs (Violations and Resolved) with a role-based modal dialog for violation resolution.
- *Reference:* `phase_8_leaver_mover_restructure_spec.md`

## 🟡 Phase 9: Labor Billing Audit (Planned)
**Goal:** Enforce DCAA compliance by aligning billed labor with actual employee grades.
- **FR-9.1:** Compare `labor_category` (government billing) with `actual_employee_grade` (HR verification).
- **FR-9.2:** Identify instances of "Labor Category Creep" to prevent fraud allegations.
- **FR-9.3:** Ensure contractual integrity between Accounting/Finance and HR systems.

## 🟡 Phase 10: Clearance & Training Watchdog (Planned)
**Goal:** Monitor the temporal validity of credentials to prevent compliance lapses.
- **FR-10.1:** Track both `last_training_date` and `training_expiration_date`.
- **FR-10.2:** Perform proactive calculations to identify and display "Upcoming Violations".
- **FR-10.3:** Enable Security Office intervention before clearances officially lapse.