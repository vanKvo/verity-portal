---
trigger: manual
---

Goal: The "60-Second" Rule which a recruiter/technical lead/developer should understand what the project does and your tech stack within 60 seconds of landing on the page.

# Project Name
One-paragraph description of what this project does.

## Key Features & Impacts
* **Digitalized Shipping Management:** Decreased customer wait times by nearly 50% during peak shipping seasons via digital shipping order orchestration;reduced operational costs by eliminating manual processes and reducing errors.
* **Inventory Management System:** Centralized inventory management system that replaced physical ledgers with an automated tracking system, providing low-stock alerts and preventing service interruptions.
* **Sales Reports:** Developed a reporting engine that aggregates daily sales and shipping metrics, enabling data-driven inventory procurement.
* **Customer Management:** Centralized customer information and shipping history for better customer service. 

## Architecture
Brief overview of the project structure and key design decisions.
Link to ADRs for details.

## Tech Stack
Frontend:	Angular, TypeScript, Tailwind CSS
Backend:	Python (FastAPI) / Java (Spring Boot), PostgreSQL
Cloud:	AWS (Lambda, S3, RDS, Bedrock, API Gateway)
DevOps:	GitHub Actions, Docker, AWS CDK / Terraform

## Cloud & Security Best Practices
Infrastructure as Code (IaC): Entire environment provisioned via AWS CDK for reproducibility.
Least Privilege: IAM roles strictly scoped to specific S3 buckets and DB tables.
Secrets Management: Sensitive data retrieved at runtime via AWS Secrets Manager.
Containerization: Fully Dockerized services for environment parity.

## Quick Start
<details>
<summary>Click to expand setup instructions</summary>

### Prerequisites
* Docker & Docker Compose

### Installation
1.  **Clone the repository & navigate to the portal:**
    ```bash
    git clone https://github.com/your-username/vietstar-shipping.git
    cd vietstar-shipping/business_portal
    ```
2.  **Configure Environment:**
    Create a `.env` file in the `business_portal` directory and add your database credentials.
3.  **Launch via Docker:**
    ```bash
    docker-compose up --build -d
    ```
4.  **Access:**
    The application will be available at `http://localhost:8081`.

### Demo Data Management
To ensure a consistent demonstration experience, the database is initialized with professional seed data. If the data is modified during a demo and Needs to be reset:

1. **Stop the containers and remove the data volume:**
   ```bash
   docker-compose down -v
   ```
2. **Restart the stack:**
   ```bash
   docker-compose up -d
   ```
This will trigger the initialization scripts (`1_schema.sql` and `2_data.sql`) to recreate the database from scratch with the original test data.

</details>