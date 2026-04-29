# ADR-003: Data Intake and Shared Mapper Strategy

## Status
Accepted

## Date
2026-04-28

## Context
Phase 4 requires a robust mechanism to intake messy, heterogeneous data files (e.g., HR exports, LMS logs, IT inventories) and map their inconsistent column headers to our system's required target schemas before ingestion.
Key requirements:
- Needs to intelligently assist the user in mapping headers to reduce manual effort.
- The system must store the mapped records dynamically, as the incoming data structure will vary significantly across the 5 core compliance modules.
- The UI needs to be highly responsive and validate that all mandatory target fields are mapped before allowing ingestion.

## Decision
We implemented a **Shared Mapper Service** utilizing Fuzzy Logic and JSONB storage:

1.  **Fuzzy Mapping (Domain Layer)**: We chose `thefuzz` library using the `fuzz.ratio` scoring method combined with text normalization (lowercasing, stripping spaces/underscores). This proved highly accurate for standardizing disparate header names (e.g., matching "FName" to "first_name").
2.  **Dynamic Storage (Infrastructure Layer)**: We created the `IntakeRecordModel` utilizing PostgreSQL's `JSON` (JSONB) column type to store the ingested data rows. This allows us to store fully mapped, heterogeneous data without requiring rigid, module-specific database tables for the raw intake layer.
3.  **Data Processing**: We leverage `pandas` to read the staged CSV/XLSX files, efficiently apply the user-confirmed column renaming, and convert the DataFrame into JSON records for database insertion.
4.  **Reactive UI (Frontend)**: We built a standalone `SharedMapperComponent` in Angular 21, leveraging **Signals** (`signal`, `computed`) to manage the mapping state. This provides real-time validation to ensure users map all required fields before the "Confirm & Process" button is enabled.

## Alternatives Considered

### Explicit Table Schemas for Each Module
- **Pros**: Strong typing at the database level; traditional SQL querying is easier.
- **Cons**: Extremely rigid. Every time a new data source is added or a schema changes slightly, a new database migration is required. It cannot easily handle the unpredictable nature of user-uploaded files.
- **Rejected**: JSONB storage provides the necessary schema flexibility for the raw intake layer while still allowing PostgreSQL to perform performant querying during the later reconciliation phases.

### Exact-Match Only or Dictionary-Based Mapping
- **Pros**: Simple to implement; highly predictable.
- **Cons**: Forces the user to manually map almost every column if the source system slightly renames an export column (e.g., "EmployeeName" vs "Emp Name").
- **Rejected**: The `thefuzz` library drastically reduces user friction by providing intelligent, high-confidence automated suggestions.

## Consequences
- **Flexibility**: The `JSON` column approach completely eliminates schema drift issues during the intake phase.
- **Accuracy**: The `fuzz.ratio` algorithm with normalization effectively handles common variations in data exports, improving the user experience.
- **Scalability**: Processing large files via `pandas` into dictionary records and batch-inserting them is highly efficient.
- **Trade-offs**: Querying JSONB columns in PostgreSQL requires specific syntax (`->>`), which the domain services will need to account for during the actual reconciliation and analysis phases (Phase 5).
