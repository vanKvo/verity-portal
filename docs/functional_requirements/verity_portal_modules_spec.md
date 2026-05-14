# Schema Documentation & Rationale
## Schema for each module.
1. ITAR & Export Control

    Documentation: This module requires a many-to-many relationship logic (handled in the service layer) between personnel and projects.

    Rationale: We use a custom ENUM for citizenship_status to prevent "data drift" from messy Excel imports. The project_sensitivity table is crucial because it allows the system to identify not just who is a foreign national, but specifically which sensitive projects they are accessing—the core of ITAR enforcement.

    Primary User: Export Control Officer or Trade Compliance Officer. They are legally responsible for ensuring foreign nationals don't access restricted tech.

    Reconciliation Logic: Must reconcile **HR Data (Citizenship Status)** against **Program Management Data (Project Rosters)** to detect when a foreign national is assigned to an ITAR-restricted project.

2. Clearance & Training Watchdog

    Documentation: Focuses on the temporal validity of credentials.

    Rationale: By storing both last_training_date and training_expiration_date, the system can perform proactive calculations. This allows the UI to display "Upcoming Violations," enabling the Security Office to intervene before a clearance actually lapses.

    Primary User: Facility Security Officer (FSO). They manage government security clearances (Secret, Top Secret) and ensure training doesn't lapse.

    Reconciliation Logic: Must reconcile **Security Office Records (Clearance Levels)** against **LMS Data (Learning Management System Training Logs)** to detect when an employee holds an active clearance but their mandatory training has expired.

3. Leaver / Mover Access Audit

    Documentation: A reconciliation table for CMMC (Cybersecurity Maturity Model Certification) compliance.

    Rationale: The critical logic here is the comparison between hr_termination_date and last_system_login. If a login occurs even one day after termination, it represents a high-risk security gap. We include org_unit to track "Movers" who may have retained access to old department folders.

    Primary User: IT Security / IAM (Identity & Access Management) Admin. They are responsible for making sure terminated employees lose system access immediately.

    Reconciliation Logic: Must reconcile **HR Data (Termination/Transfer Dates)** against **IT Infrastructure Data (Active Directory Logs)** to detect if an employee logged into a system after their official HR termination date.

4. IT Asset & PO Audit

    Documentation: Links Procurement (Finance) to physical Inventory (IT).

    Rationale: Discrepancies in this table identify "Ghost Assets." By tracking the po_number alongside the asset_tag, the system provides a financial audit trail that ensures the company is only paying maintenance and licensing for hardware that is physically verified in the IN_USE status.

    Primary User: IT Asset Manager. They own the IT physical inventory data and need to reconcile it against what the company bought (Finance).

    Reconciliation Logic: Must reconcile **Procurement Data (Purchase Orders/Invoices)** against **IT Helpdesk Data (Physical Inventory Scans)** to detect "Ghost Assets"—items the company is paying for but IT cannot locate.

5. Labor Billing Audit

    Documentation: Designed for DCAA (Defense Contract Audit Agency) compliance.

    Rationale: The labor_category (what the government is billed) must align with the actual_employee_grade (the employee's verified resume/HR level). This schema identifies "Labor Category Creep," protecting the company from fraud allegations and ensuring contractual integrity.

    Primary User: Finance Controller or DCAA Compliance Auditor. They ensure the government is being billed the correct rate for an employee's actual skillset.

    Reconciliation Logic: Must reconcile **HR Data (Actual Employee Grade/Resume Level)** against **Accounting Data (Labor Category billed to the Government)** to detect "Labor Category Creep" and prevent billing fraud.

## Module,Primary Data Source (Department),Secondary Data Source (System)
ITAR & Export Control,HR / Legal (Citizenship),Program Management (Project Lists)
Clearance & Training,Security Office (FSO),LMS (Learning Management System)
Leaver/Mover Audit,HR (Status/Dates),IT / Infrastructure (Active Directory)
IT Asset & PO Audit,Procurement / Finance,IT Helpdesk (Inventory Manager)
Labor Billing Audit,Accounting / Finance,HR (Labor Category/Grade)