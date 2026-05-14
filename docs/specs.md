Master AI Prompt: The Verity Portal Implementation

Role: You are a Senior Full-Stack Architect and Security Engineer specialized in defense-sector internal tools. Your task is to build Verity Portal, an automated data reconciliation and compliance engine.
1. Core Architecture & Tech Stack

    Architecture Pattern: Strict Hexagonal Architecture (Ports & Adapters).

    Frontend: Angular 21 using Signals for state management, Standalone Components, and Angular Material.

    Backend: FastAPI (Python 3.11+) with Pandas for the data reconciliation domain.

    Database: PostgreSQL 16+ using SQLAlchemy (ORM) for relational audit trails and JSONB for raw spreadsheet data storage.

    Infrastructure: Multi-stage Docker setup with Nginx serving as a reverse proxy for the Angular build and a Uvicorn process for the API.

2. Identity & Access Management (IAM)

    Module: Develop a standalone Auth Feature Module in Angular.

    Security: Implement OAuth2 with JWT tokens and Bcrypt password hashing in PostgreSQL.

    Access Path: * Implement a full Registration/Login flow restricted to corporate email domains.

        Crucial for Demo: Provide a "One-Click Guest Login" button on the landing page that bypasses registration for immediate recruiter access.
        
    RBAC Strategy: Implement a "Stubbed RBAC" contract via FastAPI dependencies (`require_role`) to protect endpoints and enforce honest TDD from day one, but defer building the complex Role Administration UI until later phases.

3. The "High-Impact Five" Domain Logic

The system must support these five specific reconciliation modules in the Domain Layer:

    ITAR & Export Control: Cross-references employee citizenship vs. project sensitivity levels.

    Clearance & Training Watchdog: Validates active security clearances and mandatory training completion.

    Leaver/Mover Access Audit (CMMC Focus): Detects system logins occurring after HR termination/transfer dates.

    IT Asset & PO Audit: Matches procurement serial numbers to physical inventory in use.

    Labor Billing Audit: Ensures billed labor categories match contractual mandates.

4. UI/UX Design (Defense Professionalism)

    Theme: High-density, professional "BAE Navy" palette. Primary: #002244, Background: #F8F9FA, Error: #D32F2F.

    Navigation: Persistent Sidebar Navigation.

    Workflow: Use an Angular Material Stepper for the data lifecycle:

        Scenario Selection: Pick one of the 5 modules.

        Data Intake: Upload "Source of Truth" vs. "Activity" CSV/XLSX files.

        Shared Mapper: A smart mapping interface using Fuzzy Logic (thefuzz) to link messy headers to system attributes.

        Analysis: Visualize mismatches with status chips (Valid, Warning, Violation).

        Resolution: Generate Auditor-Ready PDF Defense Reports and Sanitized CSV exports.

5. Deliverables & Implementation Order

    Phase 1: Setup the Hexagonal folder structure and the PostgreSQL schema (JSONB support included).

    Phase 2: Implement the Auth Module with the Guest Login feature.

    Phase 3: Build the Shared Mapper Service in Angular 21 using Signals.

    Phase 4: Implement the ITAR Compliance module as the first functional vertical slice.

    Phase 5: Build the PDF Export Adapter using the Python ReportLab library.

Final Command: "Generate the boilerplate structure and the Auth Module first. Ensure all Angular code uses Signals for change detection and all Python code uses type hints."