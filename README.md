# BCPT Demo - Business Central Performance Test Toolkit

A comprehensive collection of Business Central Performance Test Toolkit (BCPT) scenarios designed to generate telemetry data for performance analysis in Application Insights.

## Overview

This repository contains production-ready BCPT test codeunits that simulate realistic business operations in Dynamics 365 Business Central. The tests are designed to:

- Generate traceable telemetry events (RT0005, RT0012, RT0027, RT0028)
- Support various load profiles (single user to 25+ concurrent users)
- Cover all major business areas (Sales, Purchase, Inventory, Reports, API)
- Enable performance baseline establishment and regression testing

## Test Scenarios

### Sales Operations (50101-50103)
| Codeunit | Name | Description |
|----------|------|-------------|
| 50101 | BCPT Sales Create Post Order | Creates and posts sales orders with configurable line counts |
| 50102 | BCPT Sales Invoice Batch | Batch processes multiple sales invoices |
| 50103 | BCPT Sales Customer Search | Customer lookup and search operations |

### Purchase Operations (50110-50112)
| Codeunit | Name | Description |
|----------|------|-------------|
| 50110 | BCPT Purchase Order Tracking | Creates purchase orders with item tracking |
| 50111 | BCPT Purchase Invoice Post | Posts purchase invoices |
| 50112 | BCPT Vendor Payment Process | Processes vendor payments |

### Inventory Operations (50120-50122)
| Codeunit | Name | Description |
|----------|------|-------------|
| 50120 | BCPT Inventory Item Lookup | Item search and lookup operations |
| 50121 | BCPT Inventory Adjustment | Posts inventory adjustments |
| 50122 | BCPT Inventory Availability | Calculates inventory availability |

### Report Operations (50130-50133)
| Codeunit | Name | Description |
|----------|------|-------------|
| 50130 | BCPT Report Sales Statistics | Runs sales statistics report |
| 50131 | BCPT Report Inventory Value | Runs inventory valuation report |
| 50132 | BCPT Report Customer Ledger | Runs customer ledger report |
| 50133 | BCPT Report Vendor Ledger | Runs vendor ledger report |

### API Operations (50140-50142)
| Codeunit | Name | Description |
|----------|------|-------------|
| 50140 | BCPT API Read Customers | Simulates API GET requests for customers |
| 50141 | BCPT API Create Sales Order | Simulates API POST for sales orders |
| 50142 | BCPT API OData Query | Simulates OData query operations |

### Database Operations (50150-50153)
| Codeunit | Name | Description |
|----------|------|-------------|
| 50150 | BCPT DB Complex Query | Complex multi-table queries |
| 50151 | BCPT DB Lock Contention | Operations that test lock handling |
| 50152 | BCPT DB Large Dataset | Large dataset processing |
| 50153 | BCPT DB Aggregate Operations | Aggregation and summarization |

## Pre-configured Test Suites

The `config/BCPTSuites.json` file contains ready-to-use suite configurations:

| Suite Code | Duration | Users | Purpose |
|------------|----------|-------|---------|
| BCPT-QUICK | 5 min | 1 | Quick smoke test |
| BCPT-BASELINE | 10 min | 1-2 | Establish performance baseline |
| BCPT-LOAD-5 | 30 min | 5 | Light load testing |
| BCPT-LOAD-10 | 45 min | 10 | Medium load testing |
| BCPT-LOAD-25 | 60 min | 25 | Heavy load testing |
| BCPT-STRESS | 60 min | 18+ | Stress testing / breaking point |
| BCPT-API-ONLY | 30 min | 8 | API performance focus |
| BCPT-REPORTS | 20 min | 6 | Report performance focus |
| BCPT-DATABASE | 30 min | 7 | Database performance focus |
| BCPT-ENDURANCE | 4 hours | 5 | Long-running stability test |

## Prerequisites

1. **Business Central Environment**
   - BC version 21.0 or later
   - Performance Toolkit app installed
   - Tests-TestLibraries app installed (for test utilities)

2. **Application Insights**
   - Azure Application Insights resource provisioned
   - Connection string configured in BC Admin Center

3. **Test Data**
   - Customers, Vendors, Items in the database
   - The tests will create data as needed, but performance is better with existing data

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/your-org/bcpt-demo.git
```

### 2. Build and Publish the Extension
```bash
# Using AL Language extension in VS Code
# Or using alc.exe:
alc.exe /project:"path/to/bcpt-demo" /packagecachepath:"path/to/symbols"
```

### 3. Publish to BC Environment
```powershell
Publish-BcContainerApp -containerName "your-container" -appFile "path/to/BCPT Demo Performance Tests_1.0.0.0.app"
```

## Running Tests

### Option 1: From BC Client

1. Search for "BCPT Suites" in BC
2. Create a new suite or import from `config/BCPTSuites.json`
3. Add scenarios (test codeunits) to the suite
4. Configure parameters as needed
5. Click "Start" to run the suite

### Option 2: Using PowerShell

```powershell
# Run a BCPT suite
Invoke-BcContainerBcptRun -containerName "your-container" -suiteCode "BCPT-BASELINE"
```

### Option 3: Using API

```http
POST /api/v2.0/bcptSuites('BCPT-BASELINE')/start
Authorization: Bearer {token}
```

## Parameterization

Each test codeunit supports parameters via the `OnGetParameters` event. Common parameters:

### Sales Order Test (50101)
```
MinLines=1,MaxLines=5,PostOrder=true,CustomerPoolSize=50,ItemPoolSize=100
```

### Batch Invoice Test (50102)
```
BatchSize=5,LinesPerInvoice=3
```

### Customer Search Test (50103)
```
SearchByName=true,SearchByCity=true,SearchByPostCode=false,IncludeBalanceCalc=true
```

### Complex Query Test (50150)
```
Complexity=Medium,Iterations=3
```
Valid complexity values: Simple, Medium, Complex, Heavy

## Telemetry Signals Generated

| Signal | Description |
|--------|-------------|
| RT0005 | Long running AL operations (>1000ms) |
| RT0012 | Long running SQL queries (>1000ms) |
| RT0027 | Lock timeout warnings |
| RT0028 | Deadlock events |
| BCPT-0001 | Suite started |
| BCPT-0002 | Suite finished |
| BCPT-0003 | Scenario iteration started |
| BCPT-0004 | Scenario iteration finished |

## Custom Dimensions

Each scenario adds custom dimensions to telemetry for analysis:

- `LineCount` - Number of document lines processed
- `CustomerNo` / `VendorNo` / `ItemNo` - Entity identifiers
- `DocumentNo` - Document number created
- `PostSuccess` - Whether posting succeeded
- `RecordsProcessed` - Count of records processed
- `SearchType` - Type of search operation performed

## Performance Targets

| Operation | Target | Warning | Critical |
|-----------|--------|---------|----------|
| Page load | <500ms | >1000ms | >2000ms |
| Document creation | <2000ms | >3000ms | >5000ms |
| Posting operation | <5000ms | >8000ms | >15000ms |
| API GET | <200ms | >500ms | >1000ms |
| API POST | <500ms | >1000ms | >2000ms |
| Report execution | <10000ms | >20000ms | >60000ms |

## Analyzing Results

After running tests, analyze results in Application Insights. See [ANALYZE-RESULTS.md](docs/ANALYZE-RESULTS.md) for comprehensive KQL queries.

Quick verification query:
```kql
traces
| where timestamp > ago(1h)
| where customDimensions.eventId startswith "BCPT"
| summarize count() by tostring(customDimensions.eventId)
```

## Best Practices

1. **Baseline First**: Always run BCPT-BASELINE before load testing
2. **Warm Up**: Allow 2-3 minutes of warm-up before measuring
3. **Consistent Data**: Use same dataset for comparison tests
4. **Isolation**: Run tests on isolated environment when possible
5. **Monitor Resources**: Track CPU, memory, and database during tests
6. **Document Changes**: Record what changed between test runs

## Troubleshooting

### No Telemetry Data
- Verify Application Insights connection string in BC Admin Center
- Check that telemetry is enabled for the environment
- Wait 5-10 minutes for telemetry ingestion

### Tests Failing with Errors
- Check that test libraries are installed
- Verify adequate test data exists
- Review BC event log for errors

### Lock Timeouts
- Reduce concurrent sessions
- Increase user delay settings
- Check for conflicting operations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or modify test scenarios
4. Update documentation
5. Submit a pull request

## License

MIT License - See LICENSE file for details.

## Related Resources

- [BC Performance Toolkit Documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-performance-toolkit)
- [BC Telemetry Documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/telemetry-overview)
- [Application Insights KQL Reference](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
