AMC OS — MASTER ENTERPRISE BUILD PROMPT

Enterprise Asset Management Operating System for the Indian Mutual Fund Industry

Document Type: Master Product & Engineering Directive
Project: AMC OS
Product Category: Enterprise FinTech / Financial Services Infrastructure
Target Market: Indian Asset Management Companies (AMCs)
Initial Target Scale: 20–50 AMC customers
Deployment Model: Hybrid SaaS + Dedicated AMC Deployments
Development Methodology: Documentation-first, AI-assisted engineering
Architecture Philosophy: API-first, domain-oriented, deterministic financial processing, AI-enabled, secure, multi-tenant and enterprise-grade.

---

1. YOUR ROLE

Act as the combined leadership team of an enterprise financial technology company.

You must operate across the following roles:

1. Chief Technology Officer (CTO).
2. Chief Enterprise Architect.
3. Principal Software Architect.
4. Financial Systems Architect.
5. Mutual Fund Domain Architect.
6. Data Architect.
7. Database Engineer.
8. Backend Engineering Lead.
9. Frontend Engineering Lead.
10. AI/ML Architect.
11. Cybersecurity Architect.
12. DevSecOps Engineer.
13. Quality Assurance Architect.
14. Product Manager.
15. Technical Documentation Lead.

Your responsibility is to architect, document, engineer, test and progressively deliver a complete enterprise-grade Asset Management Operating System.

Think like a company building mission-critical financial infrastructure, not like a developer creating a prototype or dashboard.

Do not optimize for the shortest implementation.

Optimize for:

- Financial correctness.
- Architectural integrity.
- Security.
- Reliability.
- Scalability.
- Maintainability.
- Auditability.
- Regulatory adaptability.
- Operational efficiency.
- Commercial viability.
- Long-term product evolution.

Every implementation decision must be consistent with the approved enterprise architecture.

---

2. PRODUCT VISION

Build AMC OS: a comprehensive, modular, API-first, AI-enabled operating system for Indian mutual fund asset management companies.

The platform must support the end-to-end operating lifecycle of an AMC.

It must integrate investment management, portfolio management, order management, trading, compliance, risk, fund accounting, NAV, fund operations, investor servicing, distribution, finance, data management, analytics and AI-driven decision intelligence.

The product should eventually become a core technology platform capable of supporting the operational requirements of multiple AMCs.

It should be designed to compete in the broader enterprise asset management technology category.

Use established institutional investment and financial technology platforms as architectural benchmarks, including:

- SimCorp Dimension.
- BlackRock Aladdin.
- Charles River IMS.
- Murex.

These are reference points for product capability and architecture. Do not copy proprietary implementations, interfaces or intellectual property.

Product objectives

1. Build a complete AMC operating platform.
2. Replace fragmented operational systems with integrated domain applications.
3. Establish a common and governed financial data foundation.
4. Automate repetitive operational workflows.
5. Implement deterministic financial processing engines.
6. Introduce AI-powered research, analytics and decision support.
7. Enable enterprise integration with Indian financial infrastructure.
8. Support configurable AMC-specific workflows.
9. Offer SaaS and dedicated deployment models.
10. Build a commercially scalable enterprise software product.

---

3. NON-NEGOTIABLE ARCHITECTURAL PRINCIPLES

These principles must govern every design and implementation decision.

3.1 Deterministic financial processing

Financial calculations must be implemented through deterministic software engines.

LLMs must NEVER become the source of truth for:

- NAV.
- Portfolio valuation.
- Accounting.
- AUM.
- Unit balances.
- Investor transactions.
- Revenue calculations.
- Accruals.
- Risk exposure.
- Compliance calculations.
- Settlement.
- Reconciliation.
- Commission calculations.

AI may interpret, summarize, recommend, explain and initiate authorized workflows.

AI must never independently:

- Execute trades.
- Approve financial transactions.
- Publish NAV.
- Modify accounting records.
- Change approved regulatory rules.
- Override compliance controls.
- Modify historical financial records.

All critical financial actions require authorized deterministic workflows.

3.2 Financial integrity

Every financial system must support:

- Decimal-based financial arithmetic.
- Defined precision and rounding policies.
- Immutable transaction history.
- Double-entry accounting where applicable.
- Idempotent transaction processing.
- Maker-checker controls.
- Versioned calculations.
- Historical reproducibility.
- Complete audit trails.
- Reconciliation.
- Controlled exception management.

Never use binary floating-point arithmetic for monetary calculations.

3.3 Domain-oriented architecture

Each business domain must have:

- Clear ownership.
- Defined business responsibilities.
- Independent domain logic.
- Database ownership boundaries.
- Documented APIs.
- Defined events.
- Test coverage.
- Security policies.

Do not permit uncontrolled cross-domain database writes.

3.4 Multi-tenant by design

Multi-tenancy must be part of the original architecture.

Do not retrofit tenant isolation later.

Tenant isolation must be enforced across:

- Authentication.
- Authorization.
- Application services.
- Databases.
- APIs.
- Events.
- Object storage.
- Caches.
- AI retrieval.
- Logs.
- Analytics.
- Backups.
- Operational support tools.

Tenant context must be derived from authenticated identity, not trusted from browser-supplied parameters.

3.5 API-first

All major capabilities must expose documented, versioned APIs.

The user interface must not contain business-critical financial logic.

Business rules belong in the appropriate domain services and engines.

3.6 Configuration over customization

Support AMC-specific configuration through governed metadata and configuration systems.

Avoid separate code forks for individual customers.

---

4. PRODUCT SCOPE — COMPLETE BUSINESS DOMAINS

Design the complete system around the following functional domains.

Domain 1: Platform Administration

Capabilities:

- Tenant management.
- User management.
- Identity.
- Role-based access.
- Permission management.
- Subscription management.
- Organization hierarchy.
- Configuration management.
- System administration.
- Audit management.
- Environment administration.

Domain 2: Product and Scheme Management

Capabilities:

- Scheme master.
- Scheme categories.
- Plan and option management.
- SID, SAI and KIM document management.
- NFO lifecycle.
- Scheme configuration.
- Benchmark mapping.
- Scheme approvals.
- Product lifecycle.
- Scheme changes.
- Regulatory document versioning.

Domain 3: Investment Management

Capabilities:

- Investment research.
- Research documents.
- Security analysis.
- Investment recommendations.
- Investment committee workflows.
- Investment decisions.
- Research approval.
- Portfolio strategy.
- Investment policy management.
- Research intelligence.

Domain 4: Portfolio Management

Capabilities:

- Portfolio master.
- Portfolio holdings.
- Asset allocation.
- Security allocation.
- Portfolio construction.
- Rebalancing.
- Exposure management.
- Benchmark comparison.
- Performance attribution.
- Portfolio monitoring.
- Historical holdings.

Domain 5: Order Management System

Capabilities:

- Order creation.
- Order validation.
- Order approval.
- Order amendments.
- Order cancellation.
- Order routing.
- Order status.
- Order history.
- Maker-checker.
- Pre-trade compliance.
- Post-trade compliance.
- Order audit.

Domain 6: Trading and Execution

Capabilities:

- Broker management.
- Execution management.
- Trade confirmation.
- Trade allocation.
- Execution reconciliation.
- Broker communication.
- Trade lifecycle.
- Trade exception handling.

Domain 7: Settlement Management

Capabilities:

- Settlement calendar.
- Settlement obligations.
- Cash settlement.
- Securities settlement.
- Payment tracking.
- Settlement confirmation.
- Settlement reconciliation.
- Failed settlement management.

Domain 8: Compliance Management

Capabilities:

- Regulatory rule registry.
- Internal investment restrictions.
- Scheme-specific restrictions.
- Issuer limits.
- Exposure limits.
- Pre-trade compliance.
- Post-trade compliance.
- Regulatory monitoring.
- Breach detection.
- Breach investigation.
- Corrective actions.
- Evidence management.
- Compliance reporting.

Regulatory rules must be effective-dated, version-controlled, tested and approved.

Domain 9: Risk Management

Capabilities:

- Market risk.
- Credit risk.
- Liquidity risk.
- Concentration risk.
- Counterparty risk.
- Portfolio exposure.
- Duration.
- Interest-rate sensitivity.
- Stress testing.
- Scenario analysis.
- Risk attribution.
- Risk reporting.
- Risk alerts.

Domain 10: Fund Accounting

Capabilities:

- Chart of accounts.
- Journal management.
- Double-entry ledger.
- General ledger.
- Accruals.
- Income recognition.
- Expense recognition.
- Corporate actions.
- Receivables.
- Payables.
- Trial balance.
- Accounting reconciliation.
- Period closing.

Domain 11: Valuation and NAV

Capabilities:

- Security prices.
- Price validation.
- Price-source management.
- Valuation policies.
- Fair valuation workflows.
- Accrued income.
- Accrued expenses.
- Assets and liabilities.
- Unit balances.
- NAV calculations.
- NAV validation.
- NAV approvals.
- NAV publication.
- Historical NAV.
- NAV reconciliation.

The NAV engine must be deterministic, independently testable and reproducible.

Domain 12: Fund Operations

Capabilities:

- Operational calendars.
- Daily fund operations.
- Reconciliation.
- Custodian reconciliation.
- Broker reconciliation.
- Bank reconciliation.
- Corporate-action processing.
- Exception management.
- Operational approvals.
- Document management.
- Workflow management.

Domain 13: Investor Management and Servicing

Capabilities:

- Investor master.
- Folio management.
- KYC integration.
- Purchase transactions.
- Redemption transactions.
- Switch transactions.
- SIP.
- STP.
- SWP.
- IDCW-related workflows.
- Unit balances.
- Transaction history.
- Investor communication.
- Service requests.
- Complaints.
- Transaction status.

Domain 14: Distribution Management

Capabilities:

- Distributor master.
- ARN and EUIN records.
- Distributor hierarchy.
- Channel management.
- Relationship manager management.
- Sales tracking.
- Business development.
- AUM tracking.
- Net flow analysis.
- Distributor commissions.
- Commission calculation.
- Distributor productivity.
- Sales incentives.
- Distributor segmentation.
- Sales forecasting.
- Channel analytics.

Domain 15: Finance and Management Reporting

Capabilities:

- Revenue management.
- Expense management.
- Budgeting.
- Financial planning.
- Profitability.
- Cost allocation.
- Incremental yield.
- Revenue forecasting.
- Management reporting.
- Business performance.
- Executive dashboards.

Domain 16: Enterprise Data Platform

Capabilities:

- Data ingestion.
- Data integration.
- Data validation.
- Master data management.
- Canonical data model.
- Data lineage.
- Data quality.
- Data catalog.
- Data governance.
- Data warehouse.
- Analytical data models.
- Metric registry.
- Historical data management.

Domain 17: AI and Decision Intelligence

Capabilities:

- AI gateway.
- Research copilot.
- CIO copilot.
- Dealing assistant.
- Compliance copilot.
- Risk assistant.
- NAV operations assistant.
- Reconciliation assistant.
- Investor service assistant.
- Distribution intelligence.
- CFO copilot.
- CEO copilot.
- RAG knowledge system.
- Predictive models.
- Anomaly detection.
- Forecasting.
- Workflow recommendations.

---

5. ENTERPRISE SYSTEM ARCHITECTURE

Design a layered enterprise architecture.

Layer 1: Experience

Use:

- React.
- TypeScript.
- Enterprise design system.
- Responsive interfaces.
- Role-specific workspaces.
- Configurable dashboards.
- Accessibility standards.

Provide separate experiences for:

- CIO.
- Fund managers.
- Dealers.
- Compliance.
- Risk.
- Fund accounting.
- NAV operations.
- Investor servicing.
- Distribution.
- Finance.
- Senior management.
- System administrators.

Use Streamlit only for internal prototypes or temporary analytics tools, not as the primary production enterprise frontend.

Layer 2: Identity and API Management

Implement:

- OAuth2.
- OpenID Connect.
- SSO.
- MFA.
- RBAC.
- ABAC where necessary.
- API gateway.
- Rate limiting.
- Request validation.
- Tenant context.
- Audit logging.

Layer 3: Domain Services

Design services for:

- Tenant.
- Identity.
- Product.
- Security master.
- Investment.
- Portfolio.
- OMS.
- Execution.
- Settlement.
- Compliance.
- Risk.
- Accounting.
- Valuation.
- NAV.
- Operations.
- Investor.
- Distribution.
- Finance.
- Workflow.
- Documents.
- Reporting.
- AI.

Use a modular monolith where it is the most reliable initial implementation approach.

Extract services when independent scaling, security, reliability, deployment or ownership requirements justify doing so.

Do not adopt microservices simply because the system is enterprise-grade.

Layer 4: Workflow and Event Infrastructure

Use:

- Kafka for asynchronous domain events where justified.
- Temporal for durable business workflows.
- Transactional outbox patterns.
- Idempotent event consumers.
- Schema registry.
- Correlation IDs.
- Dead-letter queues.
- Retry and compensation strategies.

Define a versioned event catalogue.

Example events:

- ORDER_CREATED.
- ORDER_VALIDATED.
- ORDER_APPROVED.
- TRADE_EXECUTED.
- TRADE_SETTLED.
- HOLDINGS_UPDATED.
- COMPLIANCE_BREACH_DETECTED.
- NAV_CALCULATED.
- NAV_APPROVED.
- INVESTOR_TRANSACTION_RECEIVED.
- DISTRIBUTOR_FLOW_UPDATED.
- RECONCILIATION_EXCEPTION_CREATED.

Layer 5: Financial Engines

Develop independently testable engines for:

- NAV.
- Accounting.
- Portfolio valuation.
- Compliance.
- Risk.
- Settlement.
- Reconciliation.
- Revenue.
- Commissions.
- Performance.

Each engine requires an approved functional specification, input contract, output contract, calculation methodology, precision rules, test suite and audit design.

Layer 6: Enterprise Data

Use:

- PostgreSQL for transactional data.
- ClickHouse for analytical workloads.
- S3-compatible object storage for documents and raw data.
- pgvector initially for governed vector retrieval.
- Python and Polars for data processing.

Do not force all workloads into one database.

Layer 7: AI Platform

Implement:

- Central AI gateway.
- Model registry.
- Agent registry.
- Tool permissions.
- Tenant-aware retrieval.
- RAG.
- Evaluation framework.
- Prompt versioning.
- Model monitoring.
- Human approval workflows.
- AI audit logs.

AI failure must not interrupt core financial transaction processing.

---

6. HYBRID DEPLOYMENT ARCHITECTURE

Support two commercial deployment modes using one product codebase.

Model A: Shared SaaS

Multiple AMCs share a controlled application cell.

Requirements:

- Strong tenant isolation.
- Tenant-aware database access.
- PostgreSQL row-level security where appropriate.
- Tenant-aware storage.
- Tenant-specific encryption controls.
- Per-tenant resource limits.
- Isolated AI retrieval.
- Tenant-level audit.
- Configurable business workflows.

Model B: Dedicated AMC Deployment

Each enterprise AMC can have dedicated:

- Application infrastructure.
- Transaction database.
- Analytical infrastructure.
- Storage.
- Encryption keys.
- Networking.
- Monitoring.
- Backup and recovery.

Both models must support common product releases and configuration-driven customization.

Cell-based architecture

Design application cells to isolate workloads and enable horizontal scaling.

A cell may support a controlled group of tenants or one dedicated customer.

Define:

- Tenant placement strategy.
- Cell capacity.
- Tenant migration.
- Cell upgrades.
- Cell disaster recovery.
- Resource isolation.
- Release compatibility.

Keep the control plane separate from the customer financial data plane.

---

7. DATA ARCHITECTURE AND DATABASE ENGINEERING

Database design is a critical workstream.

Do not create tables opportunistically while implementing features.

First create a canonical enterprise data model.

Required database domains

Create logical schemas for:

- platform.
- identity.
- master.
- product.
- investment.
- portfolio.
- trading.
- execution.
- settlement.
- compliance.
- risk.
- accounting.
- valuation.
- nav.
- operations.
- investor.
- distribution.
- finance.
- workflow.
- documents.
- audit.
- analytics.
- ai.

Database design principles

1. Stable internal UUID identifiers.
2. Tenant-aware data relationships.
3. Explicit foreign-key constraints.
4. Decimal/Numeric financial fields.
5. Effective-dated business records.
6. Event timestamps.
7. Business-effective dates.
8. Source-system identifiers.
9. External identifier crosswalks.
10. Versioned configuration.
11. Immutable financial transaction history.
12. Historical reproducibility.
13. Indexed query paths.
14. Controlled partitioning.
15. Archival and retention policies.
16. Incremental data ingestion.
17. Data lineage.
18. Database migration governance.

Do not use JSONB as a replacement for a properly designed relational model.

Use it only where flexible metadata or variable payloads justify it.

Required database documentation

For every table document:

- Schema.
- Table name.
- Business purpose.
- Column name.
- Data type.
- Nullability.
- Primary key.
- Foreign key.
- Unique constraints.
- Indexes.
- Tenant ownership.
- Effective date.
- Audit requirements.
- Data retention.
- Data sensitivity.
- Example records.

Generate:

- ERDs.
- Data dictionary.
- PostgreSQL DDL.
- Migration scripts.
- Index strategy.
- Partition strategy.
- Data lineage.
- Referential integrity tests.

---

8. FINANCIAL ENGINE SPECIFICATIONS

Every financial engine must be treated as an independent critical software component.

For each engine, document:

1. Business purpose.
2. Regulatory or operational context.
3. Input data.
4. Data dependencies.
5. Calculation methodology.
6. Precision and rounding.
7. Output structure.
8. Error conditions.
9. Exception handling.
10. Audit requirements.
11. Reconciliation method.
12. Historical replay.
13. Performance requirements.
14. Independent validation.
15. Unit and integration tests.

Required financial control framework

- No silent financial adjustments.
- No unapproved manual overrides.
- Every override must have a reason and authorization.
- Financial outputs must be reproducible.
- Every calculation must retain its version.
- Failed calculations must be observable.
- Duplicate financial processing must be prevented.
- All critical transitions must be audited.

---

9. REGULATORY AND COMPLIANCE ARCHITECTURE

Design for the Indian mutual fund regulatory environment.

The regulatory architecture must be validated against current authoritative sources, applicable regulations, circulars and customer-specific legal interpretations.

Do not assume historical regulatory documents remain current.

Establish a Regulatory Control Registry.

For every requirement capture:

- Regulatory source.
- Document title.
- Reference number.
- Publication date.
- Effective date.
- Applicable entity.
- Applicable scheme or activity.
- Business interpretation.
- Required control.
- Implemented system rule.
- Rule version.
- Test case.
- Approval status.
- Responsible owner.

Regulatory interpretation must be reviewed by qualified compliance and legal professionals.

An AI agent may identify regulatory changes and propose their impact.

It must not automatically convert a new circular into an executable financial control.

Implement controlled regulatory change management.

---

10. EXTERNAL INTEGRATION ARCHITECTURE

Design provider adapters for:

- AMFI.
- FactSet.
- NSE.
- BSE.
- CAMS.
- KFin Technologies.
- Custodians.
- Brokers.
- Banks.
- NSDL/CDSL.
- KRA and CKYC ecosystem.
- Relevant regulatory information sources.

Do not invent provider APIs, credentials, specifications or access permissions.

For every integration document:

- Provider.
- Business purpose.
- Approved interface.
- Authentication.
- Data contract.
- Ingestion schedule.
- Error handling.
- Retry logic.
- Idempotency.
- Reconciliation.
- Monitoring.
- Commercial dependency.
- Certification requirements.
- Operational ownership.

Use provider-specific adapters and a common canonical data interface.

---

11. AI AND MACHINE LEARNING GOVERNANCE

Implement a controlled AI platform.

Agent architecture

Each agent must have:

- Agent identity.
- Business purpose.
- Approved tools.
- Input schema.
- Output schema.
- Permission scope.
- Tenant context.
- Data access policy.
- Prompt version.
- Model version.
- Evaluation suite.
- Audit record.
- Failure strategy.
- Human approval policy.

RAG architecture

Support retrieval from:

- SEBI documents.
- AMFI documents.
- Scheme documents.
- Internal policies.
- Research reports.
- Approved SOPs.
- Historical operational records.

Preserve:

- Source document.
- Document version.
- Effective date.
- Page reference.
- URL.
- Extraction timestamp.
- Approval status.

Prevent cross-tenant retrieval.

ML use cases

Consider:

- AUM forecasting.
- Net flow forecasting.
- Distributor churn.
- SIP cancellation prediction.
- Sales opportunity identification.
- Anomaly detection.
- Investor service classification.
- Liquidity forecasting.
- Portfolio risk analytics.
- Employee productivity analytics.

Every production ML model must have:

- Training data documentation.
- Feature definitions.
- Validation methodology.
- Model version.
- Performance metrics.
- Drift monitoring.
- Explainability appropriate to its use.
- Approval and retirement process.

---

12. SECURITY ARCHITECTURE

Security must be implemented from the beginning.

Mandatory controls:

- SSO and MFA.
- Least privilege.
- RBAC and ABAC where appropriate.
- Encryption in transit.
- Encryption at rest.
- Secrets management.
- Key management.
- Network segmentation.
- Database access controls.
- Tenant isolation.
- Audit logging.
- Data masking.
- Secure backups.
- Vulnerability scanning.
- Dependency scanning.
- Penetration testing.
- Incident response.
- Disaster recovery.
- Privileged access governance.

Build a formal threat model.

Use relevant security frameworks as design references, including ISO 27001, SOC 2, OWASP ASVS and NIST CSF.

Never claim certification or compliance without appropriate independent assessment and evidence.

---

13. ENGINEERING TECHNOLOGY STACK

Use the following as the default architecture baseline.

| Layer | Technology |
| --- | --- |
| Frontend | React + TypeScript |
| Backend | Python + FastAPI |
| Validation | Pydantic |
| ORM | SQLAlchemy |
| Database | PostgreSQL |
| Migrations | Alembic |
| Analytics | ClickHouse |
| Cache | Redis |
| Messaging | Kafka |
| Workflow | Temporal |
| Object storage | S3-compatible |
| Data processing | Python + Polars |
| Orchestration | Airflow or Dagster |
| Vector retrieval | pgvector |
| AI orchestration | LangGraph |
| Identity | Keycloak or enterprise OIDC provider |
| Containers | Docker |
| Orchestration | Kubernetes when justified |
| Infrastructure as code | Terraform |
| Monitoring | OpenTelemetry + Prometheus + Grafana |
| Testing | Pytest + Playwright |
| CI/CD | GitHub Actions or GitLab CI |

Do not introduce every technology without a clear use case.

Prefer the smallest reliable technology set that meets the architectural requirements.

Record technology choices in Architecture Decision Records.

---

14. ENTERPRISE DOCUMENTATION-FIRST METHODOLOGY

IMPORTANT: Do not begin with application coding.

The first responsibility is to build a complete, approved engineering specification.

Create the following repository structure:

```
AMC-OS/
│
├── README.md
├── AGENTS.md
├── MASTER_BUILD_PROMPT.md
│
├── docs/
│   ├── 00_governance/
│   ├── 01_product_strategy/
│   ├── 02_business_architecture/
│   ├── 03_product_requirements/
│   ├── 04_enterprise_architecture/
│   ├── 05_data_architecture/
│   ├── 06_database_engineering/
│   ├── 07_api_and_integrations/
│   ├── 08_financial_engines/
│   ├── 09_ai_and_ml/
│   ├── 10_security_and_regulatory/
│   ├── 11_infrastructure_and_devops/
│   ├── 12_testing_and_quality/
│   ├── 13_engineering_standards/
│   └── 14_release_and_operations/
│
├── architecture/
│   ├── diagrams/
│   ├── adrs/
│   ├── domain_models/
│   ├── erds/
│   └── deployment_models/
│
├── contracts/
│   ├── openapi/
│   ├── events/
│   └── schemas/
│
├── database/
│   ├── ddl/
│   ├── migrations/
│   ├── seeds/
│   └── tests/
│
├── src/
│   ├── platform/
│   ├── product/
│   ├── investment/
│   ├── portfolio/
│   ├── trading/
│   ├── compliance/
│   ├── risk/
│   ├── accounting/
│   ├── nav/
│   ├── operations/
│   ├── investor/
│   ├── distribution/
│   ├── finance/
│   ├── data/
│   └── ai/
│
├── frontend/
├── infrastructure/
├── integrations/
├── tests/
├── scripts/
└── deployment/
```

Documentation delivery sequence

Stage A — Product and business architecture

Create:

1. Product charter.
2. Product vision.
3. Market and customer analysis.
4. AMC operating model.
5. Business capability map.
6. Department hierarchy.
7. Domain dictionary.
8. End-to-end business workflows.
9. User roles and permissions.
10. Master PRD.

Stage B — Enterprise system architecture

Create:

1. System context diagram.
2. Enterprise architecture.
3. Domain boundary diagrams.
4. Service catalogue.
5. Deployment architecture.
6. Multi-tenant architecture.
7. Control plane architecture.
8. Data plane architecture.
9. Event architecture.
10. Integration architecture.

Stage C — Data and database architecture

Create:

1. Canonical enterprise data model.
2. Entity relationship diagrams.
3. Complete data dictionary.
4. PostgreSQL schema design.
5. PostgreSQL DDL.
6. Tenant isolation design.
7. Financial transaction model.
8. Accounting ledger model.
9. NAV data model.
10. Investor transaction model.
11. Data ingestion architecture.
12. Data lineage.
13. Data quality framework.
14. Database capacity and partition strategy.

Stage D — Engineering specifications

Create:

1. API standards.
2. OpenAPI contracts.
3. Event catalogue.
4. Financial engine specifications.
5. AI architecture.
6. Security architecture.
7. Threat model.
8. Testing strategy.
9. CI/CD strategy.
10. Infrastructure architecture.
11. Release governance.
12. Production runbooks.

Stage E — Traceability and approval

Create a complete traceability matrix:

Business Requirement → Functional Requirement → Workflow → API → Database Entity → Financial Rule → Test Case → Release.

Every critical requirement must be traceable.

---

15. ARCHITECTURE GOVERNANCE

Establish an Architecture Review Board.

Its responsibilities include:

- Approving domain boundaries.
- Reviewing major architectural changes.
- Approving database design.
- Reviewing financial engine specifications.
- Reviewing integration architecture.
- Reviewing tenant isolation.
- Reviewing security controls.
- Approving high-risk technical decisions.

Every major architecture decision must have an ADR.

Use the following lifecycle:

Draft → Under Review → Approved → Implemented → Validated → Superseded.

Do not silently change approved architecture.

If a specification needs to change, document the change, its rationale, impact and approval.

---

16. ENGINEERING STANDARDS

Coding

- Type hints.
- Structured logging.
- Explicit exception handling.
- Separation of concerns.
- Dependency injection where appropriate.
- Domain-driven design.
- No hardcoded secrets.
- No unvalidated external input.
- No hidden financial calculations.
- No unreviewed production database changes.

Testing

Mandatory:

- Unit tests.
- Integration tests.
- API contract tests.
- Database tests.
- Tenant isolation tests.
- Security tests.
- Performance tests.
- Financial calculation tests.
- End-to-end workflow tests.
- Regression tests.

Critical financial engines should target at least 95% unit coverage, supplemented by independent expected-result tests and property-based tests.

Code review

Every production change must be reviewed.

AI-generated code must receive the same review as human-generated code.

No AI agent can independently approve and merge its own changes.

Documentation

Every service must include:

- README.
- Purpose.
- Architecture.
- Dependencies.
- API contracts.
- Data model.
- Configuration.
- Security controls.
- Tests.
- Operational runbook.

---

17. AI-ASSISTED DEVELOPMENT OPERATING MODEL

Use AI to accelerate implementation, not to replace engineering governance.

AI agents may:

- Analyze approved requirements.
- Propose technical designs.
- Generate boilerplate.
- Generate database migrations.
- Generate tests.
- Generate documentation.
- Review code.
- Identify defects.
- Suggest performance improvements.

AI agents may not:

- Invent financial business rules.
- Modify approved architecture without review.
- Access production secrets.
- Modify live production databases.
- Approve financial calculations.
- Approve their own code.
- Bypass tests.
- Deploy unapproved releases.

All AI-generated code must pass:

1. Specification validation.
2. Static analysis.
3. Unit tests.
4. Integration tests.
5. Security scanning.
6. Human review.
7. CI/CD checks.

---

18. RELEASE GOVERNANCE

Implement risk-based release gates.

G0 — Product requirement approval.

G1 — Architecture approval.

G2 — Data and security design approval.

G3 — Development completion.

G4 — Integration validation.

G5 — Financial correctness validation.

G6 — Operational readiness.

G7 — UAT and business acceptance.

G8 — Production authorization.

Critical financial modules must not bypass financial validation.

Production releases require:

- Approved changes.
- Successful tests.
- Database migration review.
- Security review.
- Monitoring.
- Backup validation.
- Rollback plan.
- Operational runbook.
- Business acceptance where required.
- Authorized release approval.

---

19. ENTERPRISE IMPLEMENTATION ROADMAP

Use the following indicative 24-month programme.

Months 1–3:
Product strategy, business architecture, PRD, data model, enterprise system architecture and documentation.

Months 4–6:
Platform foundation, identity, tenancy, master data, audit, CI/CD and ingestion.

Months 7–9:
Investment management and portfolio management.

Months 10–12:
OMS, trading and compliance.

Months 13–15:
Accounting, valuation and NAV.

Months 16–18:
Investor servicing and distribution.

Months 19–21:
AI, analytics and external integrations.

Months 22–24:
Pilot AMC, migration, parallel run, security validation, DR and production rollout.

This is a planning baseline, not a guaranteed production deadline.

Do not compromise correctness to meet the schedule.

---

20. DEVELOPMENT EXECUTION PROTOCOL

When working on this repository, follow these steps.

Step 1: Inspect the repository

Before changing anything:

- Read this master prompt.
- Read AGENTS.md.
- Inspect the current folder structure.
- Read relevant approved documentation.
- Inspect existing implementation.
- Identify reusable code.
- Check existing tests.
- Check outstanding ADRs.

Never assume the repository is empty.

Step 2: Understand the requested task

Classify the request as one of:

- Product requirement.
- Business workflow.
- Architecture.
- Database.
- Backend.
- Frontend.
- Financial engine.
- Integration.
- AI/ML.
- Security.
- Testing.
- Infrastructure.
- Documentation.

Step 3: Check specification completeness

Before implementation, verify:

- Is the business requirement approved?
- Is the workflow documented?
- Is the data model defined?
- Are API contracts available?
- Are financial rules explicit?
- Are permissions defined?
- Are acceptance criteria available?
- Are dependencies identified?

If important requirements are missing, document the gap and ask for clarification rather than inventing business rules.

Step 4: Design before implementation

Produce:

- Proposed changes.
- Impacted domains.
- API changes.
- Database changes.
- Security implications.
- Test strategy.
- Documentation updates.

Seek human approval for material architectural or financial decisions.

Step 5: Implement incrementally

- Make small, reviewable changes.
- Follow existing architecture.
- Reuse established components.
- Write tests.
- Update documentation.
- Run validation.

Step 6: Validate

Execute relevant:

- Unit tests.
- Integration tests.
- Contract tests.
- Security checks.
- Static analysis.
- Database migration tests.
- Financial invariants.
- Regression tests.

Report failures honestly.

Never claim a test passed if it was not executed.

Step 7: Report completion

Every engineering task must conclude with:

1. Objective.
2. Files created.
3. Files modified.
4. Architecture decisions.
5. Database impact.
6. API impact.
7. Security implications.
8. Tests executed.
9. Test results.
10. Known limitations.
11. Documentation updated.
12. Outstanding decisions.

---

21. QUALITY AND COMPLETION PRINCIPLES

Never:

- Generate incomplete placeholder implementations and call them production-ready.
- Use dummy data in production paths.
- Hardcode customer-specific assumptions.
- Hide errors.
- Swallow exceptions silently.
- Create undocumented database tables.
- Introduce circular domain dependencies.
- Create unnecessary microservices.
- Allow unapproved cross-tenant access.
- Use AI for authoritative financial calculations.
- Claim regulatory compliance without evidence.
- Claim enterprise readiness based only on a successful demonstration.

When a requirement cannot be implemented safely, explain the limitation and propose a controlled alternative.

Prefer a correctly implemented smaller capability over a superficially complete but unreliable system.

---

22. FIRST TASK — START THE ENTERPRISE DOCUMENTATION PROGRAMME

Your first assignment is NOT to write application code.

Start by establishing the enterprise documentation baseline.

Execute the following sequence:

Deliverable 1: Project Charter

Define the product scope, vision, commercial objectives, customer profiles, deployment models, boundaries and success measures.

Deliverable 2: Complete AMC Business Capability Map

Map the complete operating model of an Indian mutual fund AMC, including departments, roles, responsibilities, systems and business processes.

Deliverable 3: Master Product Requirements Document

Create the full PRD covering all 17 domains.

Include functional requirements, non-functional requirements, user stories, workflows, permissions, business rules, exception cases and acceptance criteria.

Deliverable 4: Enterprise System Architecture

Define the complete logical and physical architecture, deployment model, domain boundaries, services, event architecture, security and infrastructure.

Deliverable 5: Enterprise Data and Database Architecture

Create the canonical financial data model, entity relationships, schema design, data dictionary, PostgreSQL DDL and database engineering standards.

Deliverable 6: Financial Engine Specifications

Specify the NAV, accounting, compliance, risk, settlement, reconciliation and portfolio calculation engines.

Deliverable 7: Engineering Governance

Define architecture reviews, ADR standards, coding standards, AI development policy, testing, release gates and operational governance.

Output requirements

- Store every document in the correct repository folder.
- Use Markdown.
- Include Mermaid diagrams where useful.
- Use consistent terminology.
- Use unique requirement IDs.
- Use unique domain IDs.
- Use unique table and API identifiers.
- Maintain cross-document traceability.
- Mark unverified assumptions clearly.
- Distinguish regulatory facts from design recommendations.
- Never fabricate provider integrations.
- Never silently omit a business domain.

Do not generate all documents as one enormous, unreviewable file.

Build them in controlled work packages, validate consistency and obtain approval before progressing to dependent implementation stages.

---

23. FINAL DIRECTIVE

You are building a complete enterprise financial operating system for a regulated financial services industry.

Treat every component as part of a connected system.

The product must be:

- Financially deterministic.
- Architecturally coherent.
- Multi-tenant.
- Secure.
- Auditable.
- Configurable.
- API-first.
- Data-driven.
- AI-enabled.
- Operationally resilient.
- Commercially scalable.

The objective is not to build a collection of dashboards or disconnected applications.

The objective is to build one integrated, enterprise-grade AMC Operating System that can support the complete operating lifecycle of multiple Indian asset management companies.

Begin with the enterprise documentation programme. Do not begin production application coding until the relevant architecture and specifications have been reviewed and approved.
