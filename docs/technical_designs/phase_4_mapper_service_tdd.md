---
App Version: 1.0.0
---

## Objective
Focus: Intelligent Data Ingestion and UI State Synchronization

## Tech Stack
- **Base Stack:** See [tech_stack.md](tech_stack.md)
- **Module Specific:** `thefuzz` (Fuzzy logic), `pandas` (Data Parsing)

## Project Structure
- `backend/src/verity_portal/intake/router.py` → Intake confirmation endpoints.
- `backend/src/verity_portal/intake/service.py` → Fuzzy logic and mapping logic.
- `frontend/src/app/features/intake/shared-mapper.component.ts` → Reactive mapping UI.

## Code Style & Standards
- **Fuzzy Thresholding:** Use a minimum confidence threshold of 70% for automatic suggestions.
- **Signal-Based Forms:** Avoid traditional Angular `FormGroup` for the mapping table; use a record signal for better performance and reactivity.
- **Pandas Safety:** Use `chunks` for parsing if necessary, although 50MB files typically fit in memory.

## Boundaries
- **Always do:** Normalize all headers (lowercase/strip) before passing to the fuzzy matcher.
- **Never do:** Perform the mapping logic inside the FastAPI route; delegate to the `Mapper` domain service.
- **Never do:** Allow the user to "Confirm" if required schema fields are missing a mapping.

---

## Requirements

### FR-4.1: Fuzzy Logic Mapping Suggestions
**Architectural Rationale:** Using `fuzz.ratio` provides a deterministic and performant way to calculate string similarity without the overhead of machine learning models.

#### 4.1.1. Technical Design Specification
- **Library:** `thefuzz` with the `python-Levenshtein` speedup.
- **Logic:** `(lowercase_header, system_attribute) -> score`.

#### 4.1.2. Implementation Details
- [x] Created `Mapper` domain service.
- [x] Implemented normalization logic.
- [x] Added unit tests for exact and fuzzy matching cases.

#### 4.1.3. Verification Plan
- [x] **Unit Test:** `pytest tests/domain/services/test_mapper.py`

---

### FR-4.2: Data Ingestion API
**Architectural Rationale:** Storing confirmed data as `JSONB` in the `IntakeRecordModel` allows the system to support any number of custom audit fields without migrations.

#### 4.2.1. Technical Design Specification
- **Endpoints:** `POST /intake/upload` and `POST /intake/confirm/{job_id}`.
- **Storage:** `IntakeRecordModel` with a `data` JSONB column.

#### 4.2.2. Implementation Details
- [x] Implemented `Pandas` based header extraction.
- [x] Integrated `FileManager` to retrieve staged files during confirmation.
- [x] Created integration tests for the full upload-to-confirm lifecycle.

#### 4.2.3. Verification Plan
- [x] **Integration Test:** `pytest tests/infrastructure/api/test_intake.py`

---

### FR-4.3: Reactive Shared Mapper UI
**Architectural Rationale:** Angular Signals provide a more granular change detection mechanism than Zone.js for large mapping tables, resulting in a smoother UI.

#### 4.3.1. Technical Design Specification
- **State:** `mappings = signal<Record<string, string>>({})`.
- **UI:** `MatTable` with custom cells for `MatSelect` mapping selectors.

#### 4.3.2. Implementation Details
- [x] Built `SharedMapperComponent` as a standalone component.
- [x] Wired up Signal-based validation for the "Confirm" button.
- [x] Implemented error handling for failed uploads.

#### 4.3.3. Verification Plan
- [x] **Unit Test:** `npm test -- shared-mapper.component.spec.ts`
