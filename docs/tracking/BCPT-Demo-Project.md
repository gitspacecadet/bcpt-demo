# BCPT Demo Project Tracking

## Project Overview
- **Repository**: d:/shareVHDs/SharedRepos/bcpt-demo
- **Purpose**: Business Central Performance Test Toolkit demo for generating telemetry data
- **Created**: 2025-12-04
- **Status**: Initial implementation complete

## Files Created

### Core AL Codeunits
| File | Codeunit IDs | Purpose |
|------|--------------|---------|
| `src/BCPTSetup.Codeunit.al` | 50100 | Shared utilities, data pools, parameter parsing |
| `src/BCPTSalesOperations.Codeunit.al` | 50101-50103 | Sales order, invoice batch, customer search |
| `src/BCPTPurchaseOperations.Codeunit.al` | 50110-50112 | Purchase order, invoice, vendor payments |
| `src/BCPTInventoryOperations.Codeunit.al` | 50120-50122 | Item lookup, adjustments, availability |
| `src/BCPTReportOperations.Codeunit.al` | 50130-50133 | Sales, inventory, customer, vendor reports |
| `src/BCPTAPIOperations.Codeunit.al` | 50140-50142 | API read, create, OData queries |
| `src/BCPTDatabaseOperations.Codeunit.al` | 50150-50153 | Complex queries, lock contention, large datasets |

### Configuration
| File | Purpose |
|------|---------|
| `app.json` | AL extension manifest, ID ranges 50100-50199 |
| `config/BCPTSuites.json` | 10 pre-configured test suite definitions |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | Project overview, installation, usage |
| `docs/ANALYZE-RESULTS.md` | Comprehensive KQL queries for telemetry analysis |

## Test Suite Configurations

| Suite Code | Duration | Users | Use Case |
|------------|----------|-------|----------|
| BCPT-QUICK | 5 min | 1 | Quick validation |
| BCPT-BASELINE | 10 min | 1-2 | Baseline measurement |
| BCPT-LOAD-5 | 30 min | 5 | Light load |
| BCPT-LOAD-10 | 45 min | 10 | Medium load |
| BCPT-LOAD-25 | 60 min | 25 | Heavy load |
| BCPT-STRESS | 60 min | 18+ | Breaking point |
| BCPT-API-ONLY | 30 min | 8 | API focus |
| BCPT-REPORTS | 20 min | 6 | Report focus |
| BCPT-DATABASE | 30 min | 7 | Database focus |
| BCPT-ENDURANCE | 4 hours | 5 | Long-running stability |

## Telemetry Signals Generated

- **RT0005**: Long running AL operations (>1000ms)
- **RT0012**: Long running SQL queries (>1000ms)
- **RT0027**: Lock timeout warnings
- **RT0028**: Deadlock events
- **BCPT-0001 to 0004**: BCPT-specific lifecycle events

## Key Design Patterns Used

1. **SingleInstance Pattern**: All test codeunits use `SingleInstance = true` for session persistence
2. **Data Pool Pattern**: Pre-load entity pools (customers, items, vendors) to avoid conflicts
3. **Parameter Pattern**: `OnGetParameters` event subscriber for configurable behavior
4. **SetLoadFields**: Applied throughout for optimal partial record loading
5. **Initialize Guard**: `IsInitialized` pattern for one-time setup per session

## Integration with Telemetry-AzResources-ARM

This BCPT demo is designed to work with the Azure Application Insights infrastructure deployed by the Telemetry-AzResources-ARM template. The KQL queries in `docs/ANALYZE-RESULTS.md` are compatible with BC telemetry ingested into Application Insights.

## Next Steps / Future Enhancements

- [ ] Add warehouse operations scenarios (picks, put-aways)
- [ ] Add job queue simulation scenarios
- [ ] Add dimension value heavy scenarios
- [ ] Create Azure DevOps pipeline for automated test execution
- [ ] Add workbook template for Application Insights dashboards
- [ ] Add alert rule definitions for performance regressions

## Related Projects

- `d:\shareVHDs\SharedRepos\Telemetry-AzResources-ARM` - ARM template for Application Insights deployment

## Notes

- Tests require BC 21.0+ with Performance Toolkit installed
- Tests-TestLibraries dependency is used for LibrarySales, LibraryPurchase, etc.
- Database operations tests (50151) should be used cautiously as they can impact performance
