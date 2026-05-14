# Project Tech Stack: Verity Portal

This document serves as the Single Source of Truth for the technologies used across the Verity Portal ecosystem.

## Core Backend
- **Language:** Python 3.11 - 3.14 (3.13.9 recommended)
- **Framework:** FastAPI (Asynchronous API)
- **ORM:** SQLAlchemy 2.0+
- **Migrations:** Alembic
- **Validation:** Pydantic v2
- **Data Processing:** Pandas, OpenPyXL
- **Security:** Bcrypt (hashing), PyJWT (authentication)
- **Fuzzy Matching:** `thefuzz` (Levenshtein Distance)

## Core Frontend
- **Framework:** Angular 21+ (Standalone Components, Signals)
- **UI Library:** Angular Material
- **Styling:** SCSS / Vanilla CSS
- **State Management:** Angular Signals / RxJS

## Infrastructure & Storage
- **Database:** PostgreSQL 16+
- **Containerization:** Docker & Docker Compose
- **Package Management:** Poetry (Python), npm (Node.js)
- **Cloud (Production):** AWS S3 (Data Storage), AWS Lightsail/EC2

## Development Tools
- **Testing:** Pytest (Backend), Karma/Jasmine (Frontend)
- **Code Quality:** Ruff / Black (Python), ESLint (Frontend)
- **Documentation:** Markdown (ADRs, TDDs)
