# Accounting System — Target Architecture

## System Overview

```mermaid
graph TB
    subgraph Commands["Commands (Thin Wrappers)"]
        CMD_M[MonthlyRateCalculation]
        CMD_MP[MonthlyRateCalculationPre]
        CMD_D[DailyRateCalculationPre]
        CMD_S[SendJournals]
        CMD_DC[DataCorrection]
        CMD_CL[ClearCalculationLogs]
    end

    subgraph Shared["Shared Infrastructure"]
        BC[BatchContext]
        TC[TenantConfig Interface]
        BL[BatchLock - Mutex]
        BTC[BizmatesTenantConfig]
        ZTC[ZipanTenantConfig]
    end

    subgraph Services["Services (Business Logic)"]
        MRS[Monthly Rate Service]
        DRS[Daily Rate Service]
        JS[Journals Service]
        RS[Refund Service]
        CLS[Cleanup Service]
        CS[Correction Service]
    end

    subgraph Reports["Report Generation"]
        MCSV[Monthly CSV Service]
        DCSV[Daily CSV Service]
        SCSV[Summary CSV Service]
        RP[Report Packager - ZIP + Email]
    end

    subgraph Data["Data Layer"]
        LMR[(log_monthly_rate_calculation)]
        LDR[(log_daily_rate_calculation)]
        LSC[(log_sum_calculation)]
        TC_DB[(trn_charge)]
    end

    subgraph External["External Integrations"]
        FT[Freee Token Service]
        FI[Freee Invoice Service]
        FJ[Freee Journal Sync]
    end

    %% Command → Shared
    CMD_M --> BC
    CMD_MP --> BC
    CMD_D --> BC
    CMD_S --> BC
    CMD_DC --> BC
    CMD_M --> BL
    CMD_D --> BL
    CMD_S --> BL

    %% Shared → Services
    BC --> MRS
    BC --> DRS
    BC --> JS
    TC --> MRS
    TC --> DRS
    TC --> JS
    TC --> CS
    TC --> CLS
    BTC -.->|implements| TC
    ZTC -.->|implements| TC

    %% Services → Data
    MRS --> LMR
    MRS --> RS
    DRS --> LDR
    JS --> MRS
    JS --> DRS
    JS --> FJ
    CLS --> LMR
    CLS --> LDR
    CLS --> LSC
    RS --> TC_DB

    %% Services → Reports
    MRS --> MCSV
    DRS --> DCSV
    LSC --> SCSV
    MCSV --> RP
    DCSV --> RP
    SCSV --> RP

    %% External
    JS --> FT
    JS --> FI
    CMD_D --> FT
    CMD_D --> FI
```

## Data Flow — Monthly Batch

```mermaid
flowchart LR
    subgraph Input
        EXE[Execution Date]
    end

    subgraph Context
        BC[BatchContext<br/>targetYm, startDate, endDate, isPre]
    end

    subgraph PerTenant["Per Tenant (Bizmates + Zipan)"]
        CTE[CTE Query<br/>Normal Charge Rows]
        RQ[Refund Query<br/>Negative Charges]
        MRG[Merge Results]
        INS[INSERT into<br/>log table]
    end

    subgraph Output
        CSV[CSV Generation<br/>SELECT * FROM log]
        ZIP[ZIP + Email]
    end

    EXE --> BC
    BC --> CTE
    BC --> RQ
    CTE --> MRG
    RQ --> MRG
    MRG --> INS
    INS --> CSV
    CSV --> ZIP
```

## Tenant Strategy Pattern

```mermaid
classDiagram
    class TenantConfig {
        <<interface>>
        +connection() string
        +serviceName() string
        +monthlyPlanIds() array
        +tableName(base, isPre) string
        +cleanupTables() array
    }

    class BizmatesTenantConfig {
        +connection() "mysql"
        +serviceName() "Bizmates"
        +monthlyPlanIds() [16..29]
        +tableName() "log_*" / "log_*_pre"
        +cleanupTables() [8 tables]
    }

    class ZipanTenantConfig {
        +connection() "zipan"
        +serviceName() "Zipan"
        +monthlyPlanIds() [16,17,18]
        +tableName() "log_*" / "log_*_pre"
        +cleanupTables() [12 tables]
    }

    class BatchContext {
        +targetYm: string
        +startDate: string
        +endDate: string
        +isPre: bool
        +executionDate: string
    }

    class MonthlyRateService {
        +execute(context, tenants) void
        -buildCteQuery(context, tenant) string
        -buildRefundQuery(context, tenant) string
    }

    TenantConfig <|.. BizmatesTenantConfig
    TenantConfig <|.. ZipanTenantConfig
    MonthlyRateService --> TenantConfig : uses
    MonthlyRateService --> BatchContext : uses
```

## Implementation Phases

```mermaid
gantt
    title Refactor Phases
    dateFormat  YYYY-MM-DD
    section Phase 1 (Ship Now)
    BatchContext + TenantConfig    :p1a, 2026-06-04, 2d
    Move refund into execute()    :p1b, after p1a, 2d
    Simplify CSV + models         :p1c, after p1b, 1d
    section Phase 2 (Next Quarter)
    Merge Pre/Final logic         :p2a, 2026-07-01, 4d
    Parameterized query builder   :p2b, after p2a, 3d
    DTO replacement               :p2c, after p2b, 1d
    section Phase 3 (Later)
    Daily Service extraction      :p3a, 2026-08-01, 3d
    Journals decomposition        :p3b, after p3a, 5d
    Correction handlers           :p3c, after p3b, 2d
    Report Packager               :p3d, after p3c, 2d
```

---

## How to Render

1. **VS Code**: Install "Markdown Preview Mermaid Support" extension → Open this file → Ctrl+Shift+V
2. **Online**: Copy any mermaid block to [mermaid.live](https://mermaid.live) → Export as PNG/SVG
3. **Draw.io**: File → Import → Paste mermaid code
