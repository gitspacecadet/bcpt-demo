# Analyzing BCPT Results with Application Insights

This document provides comprehensive KQL queries for analyzing Business Central Performance Test Toolkit results in Azure Application Insights.

## Table of Contents
1. [Quick Verification](#quick-verification)
2. [Suite Execution Summary](#suite-execution-summary)
3. [Scenario Performance Analysis](#scenario-performance-analysis)
4. [Long Running Operations (RT0005)](#long-running-operations-rt0005)
5. [Long Running SQL (RT0012)](#long-running-sql-rt0012)
6. [Lock Analysis (RT0027, RT0028)](#lock-analysis)
7. [Performance Trending](#performance-trending)
8. [Comparison Queries](#comparison-queries)
9. [Custom Dimension Analysis](#custom-dimension-analysis)
10. [Dashboard Queries](#dashboard-queries)

---

## Quick Verification

### Verify Telemetry is Flowing
```kql
// Check recent BCPT telemetry events
traces
| where timestamp > ago(1h)
| where customDimensions.eventId startswith "BCPT"
    or customDimensions.eventId in ("RT0005", "RT0012", "RT0027", "RT0028")
| summarize
    EventCount = count(),
    FirstEvent = min(timestamp),
    LastEvent = max(timestamp)
    by EventId = tostring(customDimensions.eventId)
| order by EventCount desc
```

### Quick Health Check
```kql
// Overall test health - last 24 hours
let bcptData = traces
| where timestamp > ago(24h)
| where customDimensions.eventId startswith "BCPT";
bcptData
| summarize
    TotalIterations = countif(customDimensions.eventId == "BCPT-0004"),
    SuccessIterations = countif(customDimensions.eventId == "BCPT-0004" and customDimensions.success == "true"),
    FailedIterations = countif(customDimensions.eventId == "BCPT-0004" and customDimensions.success == "false")
| extend SuccessRate = round(100.0 * SuccessIterations / TotalIterations, 2)
```

---

## Suite Execution Summary

### List All Suite Runs
```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "BCPT-0001" // Suite started
| project
    timestamp,
    SuiteCode = tostring(customDimensions.suiteCode),
    SuiteDescription = tostring(customDimensions.suiteDescription),
    Duration = tostring(customDimensions.durationMinutes),
    Environment = tostring(customDimensions.environmentName),
    CompanyName = tostring(customDimensions.companyName)
| order by timestamp desc
```

### Suite Completion Status
```kql
// Match suite starts with completions
let suiteStarts = traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "BCPT-0001"
| project
    StartTime = timestamp,
    SuiteCode = tostring(customDimensions.suiteCode),
    RunId = tostring(customDimensions.bcptRunId);
let suiteEnds = traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "BCPT-0002"
| project
    EndTime = timestamp,
    SuiteCode = tostring(customDimensions.suiteCode),
    RunId = tostring(customDimensions.bcptRunId),
    TotalIterations = toint(customDimensions.totalIterations),
    SuccessIterations = toint(customDimensions.successIterations),
    FailedIterations = toint(customDimensions.failedIterations);
suiteStarts
| join kind=leftouter suiteEnds on RunId
| project
    StartTime,
    SuiteCode,
    EndTime,
    ActualDuration = EndTime - StartTime,
    TotalIterations,
    SuccessIterations,
    FailedIterations,
    SuccessRate = round(100.0 * SuccessIterations / TotalIterations, 2)
| order by StartTime desc
```

---

## Scenario Performance Analysis

### Scenario Duration Statistics
```kql
// Performance statistics per scenario
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "BCPT-0004" // Scenario iteration finished
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs),
    Success = customDimensions.success == "true"
| summarize
    Iterations = count(),
    SuccessCount = countif(Success),
    FailCount = countif(not(Success)),
    AvgDurationMs = round(avg(DurationMs), 2),
    P50DurationMs = round(percentile(DurationMs, 50), 2),
    P90DurationMs = round(percentile(DurationMs, 90), 2),
    P99DurationMs = round(percentile(DurationMs, 99), 2),
    MinDurationMs = round(min(DurationMs), 2),
    MaxDurationMs = round(max(DurationMs), 2)
    by ScenarioName
| extend SuccessRate = round(100.0 * SuccessCount / Iterations, 2)
| order by AvgDurationMs desc
```

### Scenario Duration Over Time
```kql
// Track scenario performance over time
traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs)
| summarize
    AvgDurationMs = avg(DurationMs),
    P90DurationMs = percentile(DurationMs, 90)
    by ScenarioName, bin(timestamp, 1h)
| render timechart
```

### Slowest Iterations
```kql
// Find the slowest individual iterations
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs),
    SessionId = tostring(customDimensions.sessionId),
    IterationNo = tostring(customDimensions.iterationNo)
| top 50 by DurationMs desc
| project timestamp, ScenarioName, DurationMs, SessionId, IterationNo
```

---

## Long Running Operations (RT0005)

### Top Long Running AL Operations
```kql
// Find slowest AL operations during BCPT runs
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "RT0005"
| extend
    ObjectType = tostring(customDimensions.alObjectType),
    ObjectId = tostring(customDimensions.alObjectId),
    ObjectName = tostring(customDimensions.alObjectName),
    MethodName = tostring(customDimensions.alMethodName),
    ExecutionTimeMs = todouble(customDimensions.executionTimeInMs)
| summarize
    Occurrences = count(),
    AvgDurationMs = round(avg(ExecutionTimeMs), 2),
    MaxDurationMs = round(max(ExecutionTimeMs), 2),
    TotalTimeMs = round(sum(ExecutionTimeMs), 2)
    by ObjectType, ObjectName, MethodName
| order by TotalTimeMs desc
| take 50
```

### Long Running Operations by Scenario
```kql
// Correlate RT0005 events with BCPT scenarios
let bcptSessions = traces
| where timestamp > ago(24h)
| where customDimensions.eventId in ("BCPT-0003", "BCPT-0004")
| extend SessionId = tostring(customDimensions.sessionId)
| summarize by SessionId;
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "RT0005"
| extend SessionId = tostring(customDimensions.clientSessionId)
| join kind=inner bcptSessions on SessionId
| extend
    ObjectName = tostring(customDimensions.alObjectName),
    MethodName = tostring(customDimensions.alMethodName),
    ExecutionTimeMs = todouble(customDimensions.executionTimeInMs)
| summarize
    Occurrences = count(),
    AvgDurationMs = avg(ExecutionTimeMs)
    by ObjectName, MethodName
| order by Occurrences desc
```

### Operations Exceeding Thresholds
```kql
// Find operations exceeding performance thresholds
let thresholdMs = 2000; // 2 second threshold
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "RT0005"
| extend
    ExecutionTimeMs = todouble(customDimensions.executionTimeInMs)
| where ExecutionTimeMs > thresholdMs
| extend
    ObjectName = tostring(customDimensions.alObjectName),
    MethodName = tostring(customDimensions.alMethodName)
| summarize
    ViolationCount = count(),
    AvgExcessMs = avg(ExecutionTimeMs - thresholdMs),
    MaxDurationMs = max(ExecutionTimeMs)
    by ObjectName, MethodName
| order by ViolationCount desc
```

---

## Long Running SQL (RT0012)

### Top Slow SQL Queries
```kql
// Find slowest SQL queries
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "RT0012"
| extend
    SqlStatement = tostring(customDimensions.sqlStatement),
    ExecutionTimeMs = todouble(customDimensions.executionTimeInMs),
    RowsRead = toint(customDimensions.rowsRead),
    TableName = extract(@"FROM\s+\"?(\w+)\"?", 1, tostring(customDimensions.sqlStatement))
| summarize
    Occurrences = count(),
    AvgDurationMs = round(avg(ExecutionTimeMs), 2),
    MaxDurationMs = round(max(ExecutionTimeMs), 2),
    AvgRowsRead = round(avg(RowsRead), 0),
    TotalTimeMs = round(sum(ExecutionTimeMs), 2)
    by TableName
| order by TotalTimeMs desc
```

### SQL Queries by Object
```kql
// Which AL objects generate the most slow SQL
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "RT0012"
| extend
    ObjectName = tostring(customDimensions.alObjectName),
    ExecutionTimeMs = todouble(customDimensions.executionTimeInMs)
| summarize
    SlowQueryCount = count(),
    TotalSqlTimeMs = sum(ExecutionTimeMs),
    AvgQueryTimeMs = avg(ExecutionTimeMs)
    by ObjectName
| order by TotalSqlTimeMs desc
| take 20
```

### Missing Index Indicators
```kql
// Queries with high row reads relative to result (potential missing index)
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "RT0012"
| extend
    SqlStatement = tostring(customDimensions.sqlStatement),
    RowsRead = toint(customDimensions.rowsRead),
    ExecutionTimeMs = todouble(customDimensions.executionTimeInMs)
| where RowsRead > 10000 // High row reads
| summarize
    Occurrences = count(),
    AvgRowsRead = avg(RowsRead),
    AvgDurationMs = avg(ExecutionTimeMs)
    by SqlStatement
| order by AvgRowsRead desc
| take 20
```

---

## Lock Analysis

### Lock Timeout Events (RT0027)
```kql
// Find lock timeout occurrences
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "RT0027"
| extend
    ObjectName = tostring(customDimensions.alObjectName),
    TableName = tostring(customDimensions.tableName),
    LockType = tostring(customDimensions.lockType)
| summarize
    LockTimeouts = count(),
    FirstOccurrence = min(timestamp),
    LastOccurrence = max(timestamp)
    by ObjectName, TableName, LockType
| order by LockTimeouts desc
```

### Deadlock Events (RT0028)
```kql
// Analyze deadlock events
traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "RT0028"
| extend
    ObjectName = tostring(customDimensions.alObjectName),
    DeadlockInfo = tostring(customDimensions.deadlockInfo)
| project timestamp, ObjectName, DeadlockInfo
| order by timestamp desc
```

### Lock Hotspots
```kql
// Identify tables with frequent lock issues
traces
| where timestamp > ago(24h)
| where customDimensions.eventId in ("RT0027", "RT0028")
| extend
    EventType = tostring(customDimensions.eventId),
    TableName = tostring(customDimensions.tableName)
| summarize
    LockTimeouts = countif(EventType == "RT0027"),
    Deadlocks = countif(EventType == "RT0028")
    by TableName
| where LockTimeouts > 0 or Deadlocks > 0
| order by LockTimeouts + Deadlocks desc
```

---

## Performance Trending

### Daily Performance Trend
```kql
// Track performance over days
traces
| where timestamp > ago(30d)
| where customDimensions.eventId == "BCPT-0004"
| extend DurationMs = todouble(customDimensions.durationMs)
| summarize
    AvgDurationMs = avg(DurationMs),
    P90DurationMs = percentile(DurationMs, 90),
    Iterations = count()
    by bin(timestamp, 1d)
| render timechart
```

### Performance by Hour of Day
```kql
// Identify performance patterns by time of day
traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "BCPT-0004"
| extend
    DurationMs = todouble(customDimensions.durationMs),
    HourOfDay = hourofday(timestamp)
| summarize
    AvgDurationMs = avg(DurationMs),
    P90DurationMs = percentile(DurationMs, 90)
    by HourOfDay
| order by HourOfDay asc
```

### Regression Detection
```kql
// Compare recent performance to baseline
let baselinePeriod = traces
| where timestamp between (ago(14d) .. ago(7d))
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs)
| summarize
    BaselineAvg = avg(DurationMs),
    BaselineP90 = percentile(DurationMs, 90)
    by ScenarioName;
let recentPeriod = traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs)
| summarize
    RecentAvg = avg(DurationMs),
    RecentP90 = percentile(DurationMs, 90)
    by ScenarioName;
baselinePeriod
| join kind=inner recentPeriod on ScenarioName
| extend
    AvgChangePercent = round(100.0 * (RecentAvg - BaselineAvg) / BaselineAvg, 2),
    P90ChangePercent = round(100.0 * (RecentP90 - BaselineP90) / BaselineP90, 2)
| project
    ScenarioName,
    BaselineAvg = round(BaselineAvg, 2),
    RecentAvg = round(RecentAvg, 2),
    AvgChangePercent,
    BaselineP90 = round(BaselineP90, 2),
    RecentP90 = round(RecentP90, 2),
    P90ChangePercent
| order by AvgChangePercent desc
```

---

## Comparison Queries

### Compare Two Test Runs
```kql
// Compare performance between two specific test runs
let run1Id = "your-run-id-1";
let run2Id = "your-run-id-2";
let run1 = traces
| where customDimensions.bcptRunId == run1Id
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs)
| summarize Run1Avg = avg(DurationMs), Run1P90 = percentile(DurationMs, 90) by ScenarioName;
let run2 = traces
| where customDimensions.bcptRunId == run2Id
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs)
| summarize Run2Avg = avg(DurationMs), Run2P90 = percentile(DurationMs, 90) by ScenarioName;
run1
| join kind=fullouter run2 on ScenarioName
| project
    ScenarioName = coalesce(ScenarioName, ScenarioName1),
    Run1Avg = round(Run1Avg, 2),
    Run2Avg = round(Run2Avg, 2),
    ChangePercent = round(100.0 * (Run2Avg - Run1Avg) / Run1Avg, 2)
| order by ChangePercent desc
```

### Compare Suites
```kql
// Compare performance across different suite types
traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "BCPT-0004"
| extend
    SuiteCode = tostring(customDimensions.suiteCode),
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs)
| summarize
    AvgDurationMs = avg(DurationMs),
    P90DurationMs = percentile(DurationMs, 90),
    Iterations = count()
    by SuiteCode, ScenarioName
| order by SuiteCode, ScenarioName
```

---

## Custom Dimension Analysis

### Analyze by Line Count
```kql
// Correlation between line count and performance
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    LineCount = toint(customDimensions.LineCount),
    DurationMs = todouble(customDimensions.durationMs)
| where isnotempty(LineCount)
| summarize
    AvgDurationMs = avg(DurationMs),
    Iterations = count()
    by ScenarioName, LineCount
| order by ScenarioName, LineCount
```

### Performance by Document Type
```kql
// Performance breakdown by operation type
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DocumentNo = tostring(customDimensions.DocumentNo),
    PostSuccess = tostring(customDimensions.PostSuccess),
    DurationMs = todouble(customDimensions.durationMs)
| summarize
    TotalIterations = count(),
    SuccessCount = countif(PostSuccess == "true" or PostSuccess == "True"),
    AvgDurationMs = avg(DurationMs)
    by ScenarioName
| extend SuccessRate = round(100.0 * SuccessCount / TotalIterations, 2)
```

---

## Dashboard Queries

### Executive Summary
```kql
// High-level summary for dashboards
let timeRange = ago(24h);
let bcptData = traces
| where timestamp > timeRange
| where customDimensions.eventId startswith "BCPT";
let iterations = bcptData
| where customDimensions.eventId == "BCPT-0004"
| extend Success = customDimensions.success == "true", DurationMs = todouble(customDimensions.durationMs);
iterations
| summarize
    TotalIterations = count(),
    SuccessRate = round(100.0 * countif(Success) / count(), 2),
    AvgDurationMs = round(avg(DurationMs), 2),
    P90DurationMs = round(percentile(DurationMs, 90), 2),
    MaxDurationMs = round(max(DurationMs), 2)
```

### Performance Scorecard
```kql
// Scorecard with pass/fail against targets
let targets = datatable(ScenarioCategory:string, TargetMs:double)
[
    "Sales", 2000,
    "Purchase", 2000,
    "Inventory", 1000,
    "Report", 10000,
    "API", 500,
    "Database", 3000
];
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs)
| extend ScenarioCategory = case(
    ScenarioName contains "Sales", "Sales",
    ScenarioName contains "Purchase", "Purchase",
    ScenarioName contains "Inventory", "Inventory",
    ScenarioName contains "Report", "Report",
    ScenarioName contains "API", "API",
    ScenarioName contains "DB", "Database",
    "Other"
)
| summarize AvgDurationMs = avg(DurationMs), P90DurationMs = percentile(DurationMs, 90) by ScenarioCategory
| join kind=leftouter targets on ScenarioCategory
| extend
    AvgStatus = iff(AvgDurationMs <= TargetMs, "PASS", "FAIL"),
    P90Status = iff(P90DurationMs <= TargetMs * 1.5, "PASS", "FAIL")
| project ScenarioCategory, TargetMs, AvgDurationMs = round(AvgDurationMs, 2), AvgStatus, P90DurationMs = round(P90DurationMs, 2), P90Status
```

### Real-Time Monitoring
```kql
// Live monitoring during test execution
traces
| where timestamp > ago(5m)
| where customDimensions.eventId == "BCPT-0004"
| extend
    ScenarioName = tostring(customDimensions.scenarioName),
    DurationMs = todouble(customDimensions.durationMs),
    Success = customDimensions.success == "true"
| summarize
    RecentIterations = count(),
    SuccessRate = round(100.0 * countif(Success) / count(), 2),
    AvgDurationMs = round(avg(DurationMs), 2)
    by bin(timestamp, 1m), ScenarioName
| order by timestamp desc
```

---

## Tips for Analysis

1. **Start with Quick Verification** - Always verify telemetry is flowing before deep analysis

2. **Use Time Ranges Appropriately**
   - Quick checks: `ago(1h)` or `ago(24h)`
   - Trend analysis: `ago(7d)` or `ago(30d)`
   - Specific runs: Use `bcptRunId` filter

3. **Correlate Events** - Join BCPT events with RT0005/RT0012 using session IDs

4. **Set Meaningful Thresholds** - Define what "slow" means for your environment

5. **Export Results** - Use `| render` for charts or export to CSV for reporting

6. **Create Alerts** - Set up Application Insights alerts for performance regressions

## Next Steps

After analyzing results:
1. Identify top bottlenecks from RT0005/RT0012 queries
2. Review code for optimization opportunities
3. Add SetLoadFields where missing
4. Optimize SQL-heavy operations
5. Re-run tests to verify improvements
