# architecture/erds

Entity relationship diagrams. Annexes of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (Step 15, Draft), one file per domain; they carry no ID of their own. The v0.9 ERDs in DA-000 Ch 3 are replaced by these.

| File | Domain | Schemas |
| --- | --- | --- |
| [D01](D01_platform_identity_audit.md) | Platform Administration | `platform`, `identity`, `audit` |
| [D02](D02_product.md) | Product and Scheme Management | `product` |
| [D03](D03_investment.md) | Investment Management | `investment` |
| [D04](D04_portfolio.md) | Portfolio Management | `portfolio` |
| [D05](D05_trading.md) | Order Management System | `trading` |
| [D06](D06_execution.md) | Trading and Execution | `execution` |
| [D07](D07_settlement.md) | Settlement Management | `settlement` |
| [D08](D08_compliance.md) | Compliance Management | `compliance` |
| [D09](D09_risk.md) | Risk Management | `risk` |
| [D10](D10_accounting.md) | Fund Accounting | `accounting` |
| [D11](D11_valuation_nav.md) | Valuation and NAV | `valuation`, `nav` |
| [D12](D12_operations_workflow_documents.md) | Fund Operations | `operations`, `workflow`, `documents` |
| [D13](D13_investor.md) | Investor Management and Servicing | `investor` |
| [D14](D14_distribution.md) | Distribution Management | `distribution` |
| [D15](D15_finance.md) | Finance and Management Reporting | `finance` |
| [D16](D16_master_analytics.md) | Enterprise Data Platform | `master`, `analytics` |
| [D17](D17_ai.md) | AI and Decision Intelligence | `ai` |

The standard per-schema tables (outbox, delivery, inbox, dead letter, idempotency key) are described once in DA-001 §3.2 and not drawn in each diagram.
