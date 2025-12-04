codeunit 50130 "BCPT Report Sales Statistics"
{
    // BCPT Test Scenario: Run Sales Statistics Report
    // Executes sales statistics report with various filters.
    // Tests report rendering performance and data aggregation.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        CustomerNoPool: List of [Code[20]];
        DateRangeDaysParam: Integer;
        IncludeDetailsParam: Boolean;
        ScenarioNameTxt: Label 'Run Sales Statistics Report';

    trigger OnRun()
    var
        Customer: Record Customer;
        SalesStatistics: Report "Customer - Sales Statistics";
        StartDate: Date;
        EndDate: Date;
        CustomerFilter: Code[20];
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Set date range
        EndDate := WorkDate();
        StartDate := CalcDate('<-' + Format(DateRangeDaysParam) + 'D>', EndDate);

        // Optionally filter by customer
        if CustomerNoPool.Count() > 0 then
            if Random(2) = 1 then
                CustomerFilter := CustomerNoPool.Get(Random(CustomerNoPool.Count()));

        // Run the report (SaveAs to avoid UI)
        Customer.SetRange("Date Filter", StartDate, EndDate);
        if CustomerFilter <> '' then
            Customer.SetRange("No.", CustomerFilter);

        SalesStatistics.SetTableView(Customer);
        SalesStatistics.UseRequestPage(false);
        SalesStatistics.Run();

        BCPTTestContext.SetCustomDimension('DateRange', Format(StartDate) + ' - ' + Format(EndDate));
        BCPTTestContext.SetCustomDimension('CustomerFilter', CustomerFilter);
        BCPTTestContext.SetCustomDimension('DateRangeDays', Format(DateRangeDaysParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        DateRangeDaysParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'DateRangeDays', 90);
        IncludeDetailsParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'IncludeDetails', true);

        // Build customer pool
        Clear(CustomerNoPool);
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.SetLoadFields("No.");
        if Customer.FindSet() then
            repeat
                CustomerNoPool.Add(Customer."No.");
            until (Customer.Next() = 0) or (CustomerNoPool.Count() >= 100);

        IsInitialized := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'DateRangeDays=90,IncludeDetails=true';
    end;
}

codeunit 50131 "BCPT Report Inventory Value"
{
    // BCPT Test Scenario: Run Inventory Valuation Report
    // Executes inventory valuation report with cost calculations.
    // Tests heavy data processing and cost calculations.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        ItemCategoryPool: List of [Code[20]];
        LocationCodePool: List of [Code[10]];
        AsOfDateParam: Date;
        IncludeExpectedCostParam: Boolean;
        ScenarioNameTxt: Label 'Run Inventory Valuation Report';

    trigger OnRun()
    var
        Item: Record Item;
        InventoryValuation: Report "Inventory Valuation";
        CategoryFilter: Code[20];
        LocationFilter: Code[10];
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Apply filters
        if ItemCategoryPool.Count() > 0 then
            if Random(3) = 1 then
                CategoryFilter := ItemCategoryPool.Get(Random(ItemCategoryPool.Count()));

        if LocationCodePool.Count() > 0 then
            if Random(3) = 1 then
                LocationFilter := LocationCodePool.Get(Random(LocationCodePool.Count()));

        // Set up filters
        Item.SetRange("Date Filter", 0D, AsOfDateParam);
        if CategoryFilter <> '' then
            Item.SetRange("Item Category Code", CategoryFilter);
        if LocationFilter <> '' then
            Item.SetRange("Location Filter", LocationFilter);

        // Run the report
        InventoryValuation.SetTableView(Item);
        InventoryValuation.UseRequestPage(false);
        InventoryValuation.Run();

        BCPTTestContext.SetCustomDimension('AsOfDate', Format(AsOfDateParam));
        BCPTTestContext.SetCustomDimension('CategoryFilter', CategoryFilter);
        BCPTTestContext.SetCustomDimension('LocationFilter', LocationFilter);
        BCPTTestContext.SetCustomDimension('IncludeExpectedCost', Format(IncludeExpectedCostParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        ItemCategory: Record "Item Category";
        Location: Record Location;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        IncludeExpectedCostParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'IncludeExpectedCost', true);
        AsOfDateParam := WorkDate();

        // Build category pool
        Clear(ItemCategoryPool);
        ItemCategory.SetLoadFields(Code);
        if ItemCategory.FindSet() then
            repeat
                ItemCategoryPool.Add(ItemCategory.Code);
            until (ItemCategory.Next() = 0) or (ItemCategoryPool.Count() >= 20);

        // Build location pool
        Clear(LocationCodePool);
        Location.SetRange("Use As In-Transit", false);
        Location.SetLoadFields(Code);
        if Location.FindSet() then
            repeat
                LocationCodePool.Add(Location.Code);
            until (Location.Next() = 0) or (LocationCodePool.Count() >= 10);

        IsInitialized := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'IncludeExpectedCost=true';
    end;
}

codeunit 50132 "BCPT Report Customer Ledger"
{
    // BCPT Test Scenario: Run Customer Ledger Entries Report
    // Executes customer ledger report showing all transactions.
    // Tests ledger data retrieval performance.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        CustomerNoPool: List of [Code[20]];
        DateRangeDaysParam: Integer;
        ShowOpenEntriesOnlyParam: Boolean;
        ScenarioNameTxt: Label 'Run Customer Ledger Report';

    trigger OnRun()
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        CustomerDetailTrial: Report "Customer - Detail Trial Bal.";
        StartDate: Date;
        EndDate: Date;
        CustomerFilter: Code[20];
        EntryCount: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        EndDate := WorkDate();
        StartDate := CalcDate('<-' + Format(DateRangeDaysParam) + 'D>', EndDate);

        // Optionally filter by customer
        if CustomerNoPool.Count() > 0 then
            if Random(2) = 1 then
                CustomerFilter := CustomerNoPool.Get(Random(CustomerNoPool.Count()));

        // Count entries first (for telemetry)
        CustLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if CustomerFilter <> '' then
            CustLedgerEntry.SetRange("Customer No.", CustomerFilter);
        if ShowOpenEntriesOnlyParam then
            CustLedgerEntry.SetRange(Open, true);
        EntryCount := CustLedgerEntry.Count();

        // Run the report
        CustLedgerEntry.Reset();
        CustLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if CustomerFilter <> '' then
            CustLedgerEntry.SetRange("Customer No.", CustomerFilter);

        CustomerDetailTrial.SetTableView(CustLedgerEntry);
        CustomerDetailTrial.UseRequestPage(false);
        CustomerDetailTrial.Run();

        BCPTTestContext.SetCustomDimension('DateRange', Format(StartDate) + ' - ' + Format(EndDate));
        BCPTTestContext.SetCustomDimension('CustomerFilter', CustomerFilter);
        BCPTTestContext.SetCustomDimension('EntryCount', Format(EntryCount));
        BCPTTestContext.SetCustomDimension('ShowOpenOnly', Format(ShowOpenEntriesOnlyParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        DateRangeDaysParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'DateRangeDays', 365);
        ShowOpenEntriesOnlyParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'ShowOpenOnly', false);

        // Build customer pool
        Clear(CustomerNoPool);
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.SetLoadFields("No.");
        if Customer.FindSet() then
            repeat
                CustomerNoPool.Add(Customer."No.");
            until (Customer.Next() = 0) or (CustomerNoPool.Count() >= 100);

        IsInitialized := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'DateRangeDays=365,ShowOpenOnly=false';
    end;
}

codeunit 50133 "BCPT Report Vendor Ledger"
{
    // BCPT Test Scenario: Run Vendor Ledger Entries Report
    // Executes vendor ledger report showing all transactions.
    // Tests vendor ledger data retrieval and calculations.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        VendorNoPool: List of [Code[20]];
        DateRangeDaysParam: Integer;
        IncludeAgingParam: Boolean;
        ScenarioNameTxt: Label 'Run Vendor Ledger Report';

    trigger OnRun()
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        VendorDetailTrial: Report "Vendor - Detail Trial Balance";
        StartDate: Date;
        EndDate: Date;
        VendorFilter: Code[20];
        EntryCount: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        EndDate := WorkDate();
        StartDate := CalcDate('<-' + Format(DateRangeDaysParam) + 'D>', EndDate);

        // Optionally filter by vendor
        if VendorNoPool.Count() > 0 then
            if Random(2) = 1 then
                VendorFilter := VendorNoPool.Get(Random(VendorNoPool.Count()));

        // Count entries for telemetry
        VendorLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if VendorFilter <> '' then
            VendorLedgerEntry.SetRange("Vendor No.", VendorFilter);
        EntryCount := VendorLedgerEntry.Count();

        // Calculate aging if configured
        if IncludeAgingParam then
            CalculateVendorAging(VendorFilter);

        // Run the report
        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if VendorFilter <> '' then
            VendorLedgerEntry.SetRange("Vendor No.", VendorFilter);

        VendorDetailTrial.SetTableView(VendorLedgerEntry);
        VendorDetailTrial.UseRequestPage(false);
        VendorDetailTrial.Run();

        BCPTTestContext.SetCustomDimension('DateRange', Format(StartDate) + ' - ' + Format(EndDate));
        BCPTTestContext.SetCustomDimension('VendorFilter', VendorFilter);
        BCPTTestContext.SetCustomDimension('EntryCount', Format(EntryCount));
        BCPTTestContext.SetCustomDimension('IncludeAging', Format(IncludeAgingParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Vendor: Record Vendor;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        DateRangeDaysParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'DateRangeDays', 365);
        IncludeAgingParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'IncludeAging', true);

        // Build vendor pool
        Clear(VendorNoPool);
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Vendor.SetLoadFields("No.");
        if Vendor.FindSet() then
            repeat
                VendorNoPool.Add(Vendor."No.");
            until (Vendor.Next() = 0) or (VendorNoPool.Count() >= 100);

        IsInitialized := true;
    end;

    local procedure CalculateVendorAging(VendorFilter: Code[20])
    var
        Vendor: Record Vendor;
        TotalBalance: Decimal;
    begin
        if VendorFilter <> '' then
            Vendor.SetRange("No.", VendorFilter);

        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        if Vendor.FindSet() then
            repeat
                Vendor.CalcFields("Balance (LCY)", "Balance Due (LCY)");
                TotalBalance += Vendor."Balance (LCY)";
            until Vendor.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'DateRangeDays=365,IncludeAging=true';
    end;
}
