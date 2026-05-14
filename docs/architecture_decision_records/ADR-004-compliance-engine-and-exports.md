# ADR-004: Compliance Engine and Data Export Strategy

## Status
Accepted

## Date
2026-05-05

## Context
As we build the Compliance Core (Phase 5) starting with the Leaver/Mover Access Audit, we need to decide how to handle data type standardization (specifically dates) and how to deliver the audit results to the users (Exporting).
Key requirements:
- Data ingested from various HR and IT systems will have unpredictable date formats.
- The Compliance Logic requires strict `datetime` comparisons to identify security violations accurately.
- Users require formal, non-editable PDF reports for federal examiners (CMMC/ITAR) and sanitized CSVs for back-system updates.

## Decision
1.  **Date Standardization in the Mapping Phase**: Instead of cluttering the Compliance Engine with complex parsing logic, we will enforce date standardization (e.g., parsing to ISO-8601 strings) during the file ingestion/mapping phase using `pandas.to_datetime()`. This ensures the business logic always operates on clean, standardized data.
2.  **Stateless Compliance Engine**: The `audit_leaver_mover` service will remain a pure function taking in standard Python objects (lists of dicts) and outputting the exact violation records. It will not interact with the database.
3.  **Export Generation Services**: We will introduce dedicated `Exporter` logic to handle generating CSVs and PDFs from the violation records. We will use standard libraries (like `csv` in standard lib, and `fpdf2` or `reportlab` for PDFs) to construct auditor-ready documents on the fly from the audit API.

## Alternatives Considered

### Date Parsing in Domain Logic
- **Pros**: Keeps the mapping phase simple and "dumb."
- **Cons**: Domain logic becomes tightly coupled with specific string formats, increasing complexity and test surface area.
- **Rejected**: The mapping phase is explicitly designed to standardize data. Moving parsing there adheres to the "Single Responsibility Principle."

### Storing Audit Results in the Database
- **Pros**: Provides a historical record of all audits run.
- **Cons**: Premature optimization. Given that the raw intake records are already stored, the audit can be rerun deterministically at any time. Storing the output doubles the storage requirement for no immediate MVP benefit.
- **Rejected**: We will generate the Audit Dashboard and Exports on the fly. If historical tracking becomes a requirement, we will introduce an `AuditReportModel` in the future.

## Consequences
- **Accuracy**: Forcing date standardization during ingestion guarantees that the compliance rules won't fail due to string formatting edge cases.
- **Compliance**: Providing immediate PDF exports satisfies the core business requirement for federal examiner "Audit Defense."
- **Dependencies**: We will need to introduce a new backend dependency for PDF generation (e.g., `poetry add fpdf2`).
