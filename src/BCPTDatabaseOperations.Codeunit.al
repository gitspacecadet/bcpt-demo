codeunit 50150 "BCPT DB Complex Query"
{
    // BCPT Test Scenario: Complex Database Queries
    // Executes complex queries joining multiple tables.
    // Designed to generate RT0012 telemetry for SQL analysis.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        QueryComplexityParam: Text[20];
        IterationCountParam: Integer;
        ScenarioNameTxt: Label 'Complex Database Queries';

    trigger OnRun()
    var
        TotalRecords: Integer;
        QueryTime: Duration;
        StartTime: DateTime;
        i: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        TotalRecords := 0;
        StartTime := CurrentDateTime();

        for i := 1 to IterationCountParam do begin
            case QueryComplexityParam of
                'Simple':
                    TotalRecords += ExecuteSimpleQuery();
                'Medium':
                    TotalRecords += ExecuteMediumQuery();
                'Complex':
                    TotalRecords += ExecuteComplexQuery();
                'Heavy':
                    TotalRecords += ExecuteHeavyQuery();
                else
                    TotalRecords += ExecuteMediumQuery();
            end;
        end;

        QueryTime := CurrentDateTime() - StartTime;

        BCPTTestContext.SetCustomDimension('Complexity', QueryComplexityParam);
        BCPTTestContext.SetCustomDimension('Iterations', Format(IterationCountParam));
        BCPTTestContext.SetCustomDimension('TotalRecords', Format(TotalRecords));
        BCPTTestContext.SetCustomDimension('TotalTimeMs', Format(QueryTime));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        QueryComplexityParam := CopyStr(BCPTSetupUtilities.ParseParameterText(Parameters, 'Complexity', 'Medium'), 1, 20);
        IterationCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'Iterations', 3);

        IsInitialized := true;
    end;

    local procedure ExecuteSimpleQuery(): Integer
    var
        Item: Record Item;
        RecordCount: Integer;
    begin
        // Simple single-table query
        Item.SetRange(Blocked, false);
        Item.SetLoadFields("No.", Description, "Unit Price");

        if Item.FindSet() then
            repeat
                RecordCount += 1;
            until (Item.Next() = 0) or (RecordCount >= 500);

        exit(RecordCount);
    end;

    local procedure ExecuteMediumQuery(): Integer
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        RecordCount: Integer;
    begin
        // Medium complexity - join sales lines with items
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetLoadFields("Document No.", "No.", Quantity, "Unit Price", Amount);

        if SalesLine.FindSet() then
            repeat
                if Item.Get(SalesLine."No.") then begin
                    Item.CalcFields(Inventory);
                    RecordCount += 1;
                end;
            until (SalesLine.Next() = 0) or (RecordCount >= 200);

        exit(RecordCount);
    end;

    local procedure ExecuteComplexQuery(): Integer
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Item: Record Item;
        CustLedgerEntry: Record "Cust. Ledger Entry";
        RecordCount: Integer;
        CustomerCount: Integer;
    begin
        // Complex query - multiple table joins and calculations
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.SetLoadFields("No.", Name, "Balance (LCY)");

        if Customer.FindSet() then
            repeat
                // Calculate customer balance
                Customer.CalcFields("Balance (LCY)", "Balance Due (LCY)");

                // Get open sales orders
                SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                SalesHeader.SetRange("Sell-to Customer No.", Customer."No.");
                SalesHeader.SetLoadFields("No.", Amount);
                if SalesHeader.FindSet() then
                    repeat
                        SalesHeader.CalcFields(Amount);

                        // Get lines and check inventory
                        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                        SalesLine.SetRange("Document No.", SalesHeader."No.");
                        SalesLine.SetRange(Type, SalesLine.Type::Item);
                        SalesLine.SetLoadFields("No.", Quantity);
                        if SalesLine.FindSet() then
                            repeat
                                if Item.Get(SalesLine."No.") then begin
                                    Item.CalcFields(Inventory);
                                    RecordCount += 1;
                                end;
                            until SalesLine.Next() = 0;
                    until SalesHeader.Next() = 0;

                // Get recent ledger entries
                CustLedgerEntry.SetRange("Customer No.", Customer."No.");
                CustLedgerEntry.SetRange("Posting Date", CalcDate('<-90D>', WorkDate()), WorkDate());
                CustLedgerEntry.SetLoadFields("Entry No.", Amount);
                RecordCount += CustLedgerEntry.Count();

                CustomerCount += 1;
            until (Customer.Next() = 0) or (CustomerCount >= 20);

        exit(RecordCount);
    end;

    local procedure ExecuteHeavyQuery(): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Item: Record Item;
        RecordCount: Integer;
        ItemCount: Integer;
    begin
        // Heavy query - large dataset with calculations
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetLoadFields("No.", Description, "Unit Cost");

        if Item.FindSet() then
            repeat
                // Get all ledger entries
                ItemLedgerEntry.SetRange("Item No.", Item."No.");
                ItemLedgerEntry.SetRange("Posting Date", CalcDate('<-1Y>', WorkDate()), WorkDate());
                ItemLedgerEntry.SetLoadFields("Entry No.", Quantity, "Cost Amount (Actual)");
                if ItemLedgerEntry.FindSet() then
                    repeat
                        ItemLedgerEntry.CalcFields("Cost Amount (Actual)");

                        // Get value entries for each item ledger entry
                        ValueEntry.SetRange("Item Ledger Entry No.", ItemLedgerEntry."Entry No.");
                        ValueEntry.SetLoadFields("Entry No.", "Cost Amount (Actual)");
                        RecordCount += ValueEntry.Count();

                    until ItemLedgerEntry.Next() = 0;

                // Calculate all flowfields
                Item.CalcFields(
                    Inventory,
                    "Qty. on Purch. Order",
                    "Qty. on Sales Order",
                    "Net Change"
                );

                ItemCount += 1;
            until (Item.Next() = 0) or (ItemCount >= 50);

        exit(RecordCount);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'Complexity=Medium,Iterations=3';
    end;
}

codeunit 50151 "BCPT DB Lock Contention"
{
    // BCPT Test Scenario: Lock Contention Operations
    // Operations designed to create lock contention scenarios.
    // Generates RT0027 (Lock Timeout) and RT0028 (Deadlock) telemetry.
    // WARNING: Use with caution - can impact system performance.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        NumberSeriesCode: Code[20];
        OperationTypeParam: Text[30];
        ScenarioNameTxt: Label 'Lock Contention Operations';

    trigger OnRun()
    var
        OperationType: Text[30];
        OperationResult: Text[50];
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        case OperationTypeParam of
            'NumberSeries':
                begin
                    OperationType := 'NumberSeries';
                    OperationResult := Format(UpdateNumberSeries());
                end;
            'SequentialInsert':
                begin
                    OperationType := 'SequentialInsert';
                    OperationResult := Format(PerformSequentialInserts());
                end;
            'ModifySameRecord':
                begin
                    OperationType := 'ModifySameRecord';
                    OperationResult := Format(ModifySameRecord());
                end;
            'CalcSumsQuery':
                begin
                    OperationType := 'CalcSumsQuery';
                    OperationResult := Format(PerformCalcSums());
                end;
            else begin
                OperationType := 'NumberSeries';
                OperationResult := Format(UpdateNumberSeries());
            end;
        end;

        BCPTTestContext.SetCustomDimension('OperationType', OperationType);
        BCPTTestContext.SetCustomDimension('OperationResult', OperationResult);

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        NoSeries: Record "No. Series";
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        OperationTypeParam := CopyStr(BCPTSetupUtilities.ParseParameterText(Parameters, 'OperationType', 'NumberSeries'), 1, 30);

        // Find a number series to use
        NoSeries.SetLoadFields(Code);
        if NoSeries.FindFirst() then
            NumberSeriesCode := NoSeries.Code;

        IsInitialized := true;
    end;

    local procedure UpdateNumberSeries(): Integer
    var
        NoSeriesLine: Record "No. Series Line";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        NewNo: Code[20];
        UpdateCount: Integer;
    begin
        // This operation typically causes lock contention
        // Multiple sessions trying to get next number from same series
        if NumberSeriesCode = '' then
            exit(0);

        NoSeriesLine.SetRange("Series Code", NumberSeriesCode);
        if NoSeriesLine.FindSet(true) then begin
            NoSeriesLine.LockTable();
            // Simulate getting next number
            NewNo := NoSeriesMgt.GetNextNo(NumberSeriesCode, WorkDate(), true);
            UpdateCount := 1;
        end;

        exit(UpdateCount);
    end;

    local procedure PerformSequentialInserts(): Integer
    var
        TempBlob: Codeunit "Temp Blob";
        DummyRecord: Record "Sales Comment Line";
        InsertCount: Integer;
        i: Integer;
        DocumentNo: Code[20];
        LineNo: Integer;
    begin
        // Sequential inserts on same table - can cause page latch contention
        DocumentNo := 'BCPT-LOCK-' + Format(SessionId());

        for i := 1 to 10 do begin
            LineNo := i * 10000;
            DummyRecord.Init();
            DummyRecord."Document Type" := DummyRecord."Document Type"::"Blanket Order";
            DummyRecord."No." := DocumentNo;
            DummyRecord."Line No." := LineNo;
            DummyRecord.Date := WorkDate();
            DummyRecord.Comment := 'BCPT Lock Test ' + Format(CurrentDateTime());
            if DummyRecord.Insert() then
                InsertCount += 1;
        end;

        // Clean up
        DummyRecord.SetRange("No.", DocumentNo);
        DummyRecord.DeleteAll();

        exit(InsertCount);
    end;

    local procedure ModifySameRecord(): Integer
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        OriginalValue: Code[10];
        ModifyCount: Integer;
    begin
        // Modifying same record causes lock contention
        // Using GL Setup as it's always present
        if GeneralLedgerSetup.Get() then begin
            GeneralLedgerSetup.LockTable();
            OriginalValue := GeneralLedgerSetup."Global Dimension 1 Code";

            // Just read the record under lock
            GeneralLedgerSetup.Get();
            ModifyCount := 1;
        end;

        exit(ModifyCount);
    end;

    local procedure PerformCalcSums(): Integer
    var
        GLEntry: Record "G/L Entry";
        TotalDebit: Decimal;
        TotalCredit: Decimal;
    begin
        // CalcSums on large table - can cause read locks
        GLEntry.SetRange("Posting Date", CalcDate('<-1Y>', WorkDate()), WorkDate());

        GLEntry.CalcSums("Debit Amount", "Credit Amount");
        TotalDebit := GLEntry."Debit Amount";
        TotalCredit := GLEntry."Credit Amount";

        exit(1);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'OperationType=NumberSeries';
    end;
}

codeunit 50152 "BCPT DB Large Dataset"
{
    // BCPT Test Scenario: Large Dataset Processing
    // Processes large datasets to test memory and I/O performance.
    // Generates telemetry for data volume analysis.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        RecordLimitParam: Integer;
        ProcessingTypeParam: Text[20];
        ScenarioNameTxt: Label 'Large Dataset Processing';

    trigger OnRun()
    var
        RecordsProcessed: Integer;
        ProcessingType: Text[20];
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        case ProcessingTypeParam of
            'GLEntries':
                begin
                    ProcessingType := 'GLEntries';
                    RecordsProcessed := ProcessGLEntries();
                end;
            'ItemLedger':
                begin
                    ProcessingType := 'ItemLedger';
                    RecordsProcessed := ProcessItemLedgerEntries();
                end;
            'ValueEntries':
                begin
                    ProcessingType := 'ValueEntries';
                    RecordsProcessed := ProcessValueEntries();
                end;
            'CustLedger':
                begin
                    ProcessingType := 'CustLedger';
                    RecordsProcessed := ProcessCustLedgerEntries();
                end;
            else begin
                ProcessingType := 'GLEntries';
                RecordsProcessed := ProcessGLEntries();
            end;
        end;

        BCPTTestContext.SetCustomDimension('ProcessingType', ProcessingType);
        BCPTTestContext.SetCustomDimension('RecordsProcessed', Format(RecordsProcessed));
        BCPTTestContext.SetCustomDimension('RecordLimit', Format(RecordLimitParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        RecordLimitParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'RecordLimit', 10000);
        ProcessingTypeParam := CopyStr(BCPTSetupUtilities.ParseParameterText(Parameters, 'ProcessingType', 'GLEntries'), 1, 20);

        IsInitialized := true;
    end;

    local procedure ProcessGLEntries(): Integer
    var
        GLEntry: Record "G/L Entry";
        TotalDebit: Decimal;
        TotalCredit: Decimal;
        RecordCount: Integer;
    begin
        GLEntry.SetLoadFields("Entry No.", "G/L Account No.", "Posting Date", "Debit Amount", "Credit Amount");

        if GLEntry.FindSet() then
            repeat
                TotalDebit += GLEntry."Debit Amount";
                TotalCredit += GLEntry."Credit Amount";
                RecordCount += 1;
            until (GLEntry.Next() = 0) or (RecordCount >= RecordLimitParam);

        exit(RecordCount);
    end;

    local procedure ProcessItemLedgerEntries(): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        TotalQuantity: Decimal;
        TotalCost: Decimal;
        RecordCount: Integer;
    begin
        ItemLedgerEntry.SetLoadFields("Entry No.", "Item No.", Quantity, "Cost Amount (Actual)");

        if ItemLedgerEntry.FindSet() then
            repeat
                ItemLedgerEntry.CalcFields("Cost Amount (Actual)");
                TotalQuantity += ItemLedgerEntry.Quantity;
                TotalCost += ItemLedgerEntry."Cost Amount (Actual)";
                RecordCount += 1;
            until (ItemLedgerEntry.Next() = 0) or (RecordCount >= RecordLimitParam);

        exit(RecordCount);
    end;

    local procedure ProcessValueEntries(): Integer
    var
        ValueEntry: Record "Value Entry";
        TotalCost: Decimal;
        RecordCount: Integer;
    begin
        ValueEntry.SetLoadFields("Entry No.", "Item No.", "Cost Amount (Actual)", "Cost Amount (Expected)");

        if ValueEntry.FindSet() then
            repeat
                TotalCost += ValueEntry."Cost Amount (Actual)" + ValueEntry."Cost Amount (Expected)";
                RecordCount += 1;
            until (ValueEntry.Next() = 0) or (RecordCount >= RecordLimitParam);

        exit(RecordCount);
    end;

    local procedure ProcessCustLedgerEntries(): Integer
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        TotalAmount: Decimal;
        RecordCount: Integer;
    begin
        CustLedgerEntry.SetLoadFields("Entry No.", "Customer No.", "Posting Date", Amount, "Remaining Amount");

        if CustLedgerEntry.FindSet() then
            repeat
                CustLedgerEntry.CalcFields("Remaining Amount");
                TotalAmount += CustLedgerEntry."Remaining Amount";
                RecordCount += 1;
            until (CustLedgerEntry.Next() = 0) or (RecordCount >= RecordLimitParam);

        exit(RecordCount);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'RecordLimit=10000,ProcessingType=GLEntries';
    end;
}

codeunit 50153 "BCPT DB Aggregate Operations"
{
    // BCPT Test Scenario: Aggregate and Summarization Operations
    // Performs aggregation queries (SUM, COUNT, AVG) on large tables.
    // Tests database aggregation performance.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        DateRangeDaysParam: Integer;
        GroupByLevelParam: Text[20];
        ScenarioNameTxt: Label 'Database Aggregate Operations';

    trigger OnRun()
    var
        AggregateResults: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Perform various aggregation operations
        AggregateResults := 0;
        AggregateResults += AggregateGLByAccount();
        AggregateResults += AggregateSalesByCustomer();
        AggregateResults += AggregateInventoryByItem();
        AggregateResults += AggregatePurchasesByVendor();

        BCPTTestContext.SetCustomDimension('AggregateResults', Format(AggregateResults));
        BCPTTestContext.SetCustomDimension('DateRangeDays', Format(DateRangeDaysParam));
        BCPTTestContext.SetCustomDimension('GroupByLevel', GroupByLevelParam);

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        DateRangeDaysParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'DateRangeDays', 365);
        GroupByLevelParam := CopyStr(BCPTSetupUtilities.ParseParameterText(Parameters, 'GroupByLevel', 'Account'), 1, 20);

        IsInitialized := true;
    end;

    local procedure AggregateGLByAccount(): Integer
    var
        GLAccount: Record "G/L Account";
        GLEntry: Record "G/L Entry";
        StartDate: Date;
        TotalDebit: Decimal;
        TotalCredit: Decimal;
        AccountCount: Integer;
    begin
        StartDate := CalcDate('<-' + Format(DateRangeDaysParam) + 'D>', WorkDate());

        GLAccount.SetRange("Account Type", GLAccount."Account Type"::Posting);
        GLAccount.SetLoadFields("No.");
        if GLAccount.FindSet() then
            repeat
                GLEntry.SetRange("G/L Account No.", GLAccount."No.");
                GLEntry.SetRange("Posting Date", StartDate, WorkDate());
                GLEntry.CalcSums("Debit Amount", "Credit Amount");
                TotalDebit += GLEntry."Debit Amount";
                TotalCredit += GLEntry."Credit Amount";
                AccountCount += 1;
            until (GLAccount.Next() = 0) or (AccountCount >= 100);

        exit(AccountCount);
    end;

    local procedure AggregateSalesByCustomer(): Integer
    var
        Customer: Record Customer;
        SalesInvoiceHeader: Record "Sales Invoice Header";
        StartDate: Date;
        TotalAmount: Decimal;
        CustomerCount: Integer;
    begin
        StartDate := CalcDate('<-' + Format(DateRangeDaysParam) + 'D>', WorkDate());

        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.SetLoadFields("No.");
        if Customer.FindSet() then
            repeat
                SalesInvoiceHeader.SetRange("Sell-to Customer No.", Customer."No.");
                SalesInvoiceHeader.SetRange("Posting Date", StartDate, WorkDate());
                SalesInvoiceHeader.CalcSums(Amount);
                TotalAmount += SalesInvoiceHeader.Amount;
                CustomerCount += 1;
            until (Customer.Next() = 0) or (CustomerCount >= 50);

        exit(CustomerCount);
    end;

    local procedure AggregateInventoryByItem(): Integer
    var
        Item: Record Item;
        ItemCount: Integer;
        TotalInventory: Decimal;
        TotalValue: Decimal;
    begin
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Item.SetLoadFields("No.", "Unit Cost");
        if Item.FindSet() then
            repeat
                Item.CalcFields(Inventory);
                TotalInventory += Item.Inventory;
                TotalValue += Item.Inventory * Item."Unit Cost";
                ItemCount += 1;
            until (Item.Next() = 0) or (ItemCount >= 100);

        exit(ItemCount);
    end;

    local procedure AggregatePurchasesByVendor(): Integer
    var
        Vendor: Record Vendor;
        PurchInvHeader: Record "Purch. Inv. Header";
        StartDate: Date;
        TotalAmount: Decimal;
        VendorCount: Integer;
    begin
        StartDate := CalcDate('<-' + Format(DateRangeDaysParam) + 'D>', WorkDate());

        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Vendor.SetLoadFields("No.");
        if Vendor.FindSet() then
            repeat
                PurchInvHeader.SetRange("Buy-from Vendor No.", Vendor."No.");
                PurchInvHeader.SetRange("Posting Date", StartDate, WorkDate());
                PurchInvHeader.CalcSums(Amount);
                TotalAmount += PurchInvHeader.Amount;
                VendorCount += 1;
            until (Vendor.Next() = 0) or (VendorCount >= 50);

        exit(VendorCount);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'DateRangeDays=365,GroupByLevel=Account';
    end;
}
