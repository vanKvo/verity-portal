# ADR-005: Feature-Based Layout (Vertical Slicing)

## Status
Accepted

## Date
2026-05-12

## Context
Verity Portal is an evolving ecosystem of compliance modules (Identity, Intake, Compliance, Analytics). Initially, the project was structured with top-level `domain/` and `infrastructure/` directories. However, as the number of features increased, this separation led to "feature scattering," where adding a single capability required jumping between multiple distant directories.

Key requirements:
- **High Cohesion**: Code that changes together (e.g., all Identity logic) should stay together.
- **Low Coupling**: Features should communicate via explicit public contracts (Services), not internal implementation details.
- **Maintainability**: New developers should be able to understand a feature's entire stack by looking into a single directory.
- **Scalability**: The structure must allow for easy extraction of a feature into a microservice if necessary.

## Decision
We decided to transition the backend architecture from a top-level Layered split to a **Feature-Based Layout (Vertical Slicing)**. 

1. **Project Structure**: The application is organized under `src/verity_portal/` into three main areas:
   - `core/`: Global, non-feature specific infrastructure (database engine, global security, configuration).
   - `shared/`: Reusable primitives, base classes, and cross-feature utilities.
   - `[feature]/`: Self-contained vertical slices (e.g., `identity/`, `intake/`, `compliance/`).
2. **Internal Feature Layout**: Each feature directory contains its own localized layers:
   - `router.py`: API endpoints.
   - `service.py`: Business logic and orchestration (Core).
   - `models.py`: Database entities.
   - `schemas.py`: Pydantic DTOs for request/response validation.
   - `repository.py` (Optional): Explicit data access logic if complexity warrants it.
3. **Communication Rules**: Features must never import models or internal logic from other features. They must interact only via the public methods exposed in another feature's `service.py`.

## Alternatives Considered

### Top-Level Domain/Infrastructure Split
- Pros: Maximum isolation of domain logic from technical frameworks.
- Cons: High cognitive overhead; creates "feature scattering" where a single logic change is spread across `domain/services`, `domain/models`, and `infrastructure/api`.
- Rejected: This top-level directory split was too cumbersome for our development velocity and has been completely replaced by the Feature-Based Layout.

### Traditional Layered Architecture
- Pros: Simple to understand (Models/Views/Controllers).
- Cons: Leads to "God Folders" (e.g., a `models/` folder with 50 unrelated files).
- Rejected: Fails to scale as the number of features grows.

## Consequences
- **Improved Discoverability**: All code related to a feature is now located in one place.
- **Simplified Testing**: Unit and integration tests can be co-located or easily mapped to the feature directory.
- **Contract Enforcement**: Use of Pydantic schemas (`schemas.py`) at the feature boundary ensures that internal database changes do not break the public API.
- **Refactoring Ease**: Extracting the `compliance` feature into a separate service now requires moving a single directory rather than picking files out of a global layered structure.
