codeunit 50140 "BCPT API Read Customers"
{
    // BCPT Test Scenario: Simulate API Customer Read Operations
    // Simulates typical API GET requests for customer data.
    // Tests API-style data retrieval patterns.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        CustomerNoPool: List of [Code[20]];
        ReadCountParam: Integer;
        IncludeRelatedDataParam: Boolean;
        PageSizeParam: Integer;
        ScenarioNameTxt: Label 'API Read Customers';

    trigger OnRun()
    var
        Customer: Record Customer;
        CustomerNo: Code[20];
        i: Integer;
        RecordsRead: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        RecordsRead := 0;

        for i := 1 to ReadCountParam do begin
            case Random(3) of
                1:
                    // Single record read (GET by ID)
                    RecordsRead += ReadSingleCustomer();
                2:
                    // Paginated list read (GET collection)
                    RecordsRead += ReadCustomerList();
                3:
                    // Filtered read (GET with $filter)
                    RecordsRead += ReadCustomersWithFilter();
            end;

            // Include related data reads if configured
            if IncludeRelatedDataParam then
                ReadRelatedCustomerData();
        end;

        BCPTTestContext.SetCustomDimension('ReadCount', Format(ReadCountParam));
        BCPTTestContext.SetCustomDimension('RecordsRead', Format(RecordsRead));
        BCPTTestContext.SetCustomDimension('IncludeRelated', Format(IncludeRelatedDataParam));
        BCPTTestContext.SetCustomDimension('PageSize', Format(PageSizeParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        ReadCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'ReadCount', 10);
        IncludeRelatedDataParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'IncludeRelated', true);
        PageSizeParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'PageSize', 20);

        // Build customer pool
        Clear(CustomerNoPool);
        Customer.SetLoadFields("No.");
        if Customer.FindSet() then
            repeat
                CustomerNoPool.Add(Customer."No.");
            until (Customer.Next() = 0) or (CustomerNoPool.Count() >= 200);

        IsInitialized := true;
    end;

    local procedure ReadSingleCustomer(): Integer
    var
        Customer: Record Customer;
        CustomerNo: Code[20];
    begin
        if CustomerNoPool.Count() = 0 then
            exit(0);

        CustomerNo := CustomerNoPool.Get(Random(CustomerNoPool.Count()));

        // Simulate API field selection (common fields requested via $select)
        Customer.SetLoadFields(
            "No.", Name, "Name 2", Address, "Address 2", City,
            "Post Code", "Country/Region Code", "Phone No.", "E-Mail",
            "Balance (LCY)", "Credit Limit (LCY)", Blocked
        );

        if Customer.Get(CustomerNo) then begin
            // Calculate flowfields that would be included in API response
            Customer.CalcFields("Balance (LCY)", "Balance Due (LCY)");
            exit(1);
        end;
        exit(0);
    end;

    local procedure ReadCustomerList(): Integer
    var
        Customer: Record Customer;
        RecordCount: Integer;
        i: Integer;
    begin
        // Simulate paginated API list read
        Customer.SetLoadFields(
            "No.", Name, Address, City, "Post Code",
            "Country/Region Code", "Phone No.", "E-Mail", Blocked
        );

        RecordCount := 0;
        if Customer.FindSet() then
            repeat
                RecordCount += 1;
            until (Customer.Next() = 0) or (RecordCount >= PageSizeParam);

        exit(RecordCount);
    end;

    local procedure ReadCustomersWithFilter(): Integer
    var
        Customer: Record Customer;
        FilterType: Integer;
    begin
        FilterType := Random(4);

        Customer.SetLoadFields("No.", Name, City, "Balance (LCY)", Blocked);

        case FilterType of
            1:
                // Filter by name contains
                Customer.SetFilter(Name, '@*A*');
            2:
                // Filter by city
                Customer.SetFilter(City, '<>%1', '');
            3:
                // Filter by balance
                Customer.SetFilter("Balance (LCY)", '>%1', 0);
            4:
                // Filter by not blocked
                Customer.SetRange(Blocked, Customer.Blocked::" ");
        end;

        exit(Customer.Count());
    end;

    local procedure ReadRelatedCustomerData()
    var
        Customer: Record Customer;
        CustLedgerEntry: Record "Cust. Ledger Entry";
        ShipToAddress: Record "Ship-to Address";
        CustomerNo: Code[20];
    begin
        if CustomerNoPool.Count() = 0 then
            exit;

        CustomerNo := CustomerNoPool.Get(Random(CustomerNoPool.Count()));

        // Read ship-to addresses (navigation property)
        ShipToAddress.SetRange("Customer No.", CustomerNo);
        ShipToAddress.SetLoadFields(Code, Name, Address, City);
        if ShipToAddress.FindSet() then
            repeat
            until ShipToAddress.Next() = 0;

        // Read recent ledger entries (navigation property)
        CustLedgerEntry.SetRange("Customer No.", CustomerNo);
        CustLedgerEntry.SetRange("Posting Date", CalcDate('<-30D>', WorkDate()), WorkDate());
        CustLedgerEntry.SetLoadFields("Entry No.", "Document Type", "Document No.", "Posting Date", Amount);
        if CustLedgerEntry.FindSet() then
            repeat
            until CustLedgerEntry.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'ReadCount=10,IncludeRelated=true,PageSize=20';
    end;
}

codeunit 50141 "BCPT API Create Sales Order"
{
    // BCPT Test Scenario: Simulate API Sales Order Creation
    // Simulates typical API POST requests to create sales orders.
    // Tests API-style document creation patterns.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        CustomerNoPool: List of [Code[20]];
        ItemNoPool: List of [Code[20]];
        LineCountParam: Integer;
        ValidateFieldsParam: Boolean;
        ScenarioNameTxt: Label 'API Create Sales Order';

    trigger OnRun()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CustomerNo: Code[20];
        ItemNo: Code[20];
        i: Integer;
        LineNo: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Simulate API POST - Create sales order header
        CustomerNo := CustomerNoPool.Get(Random(CustomerNoPool.Count()));

        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader.Insert(true);

        if ValidateFieldsParam then begin
            // Full validation path (like API with validation)
            SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
            SalesHeader.Validate("Order Date", WorkDate());
            SalesHeader.Validate("Posting Date", WorkDate());
            SalesHeader.Validate("Shipment Date", CalcDate('<+7D>', WorkDate()));
        end else begin
            // Direct assignment (faster but less validation)
            SalesHeader."Sell-to Customer No." := CustomerNo;
            SalesHeader."Order Date" := WorkDate();
            SalesHeader."Posting Date" := WorkDate();
        end;

        SalesHeader."External Document No." := 'API-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2><Seconds,2>');
        SalesHeader.Modify(true);

        // Simulate API POST - Add lines (like lines subpage API)
        LineNo := 10000;
        for i := 1 to LineCountParam do begin
            ItemNo := ItemNoPool.Get(Random(ItemNoPool.Count()));

            SalesLine.Init();
            SalesLine."Document Type" := SalesHeader."Document Type";
            SalesLine."Document No." := SalesHeader."No.";
            SalesLine."Line No." := LineNo;
            SalesLine.Insert(true);

            if ValidateFieldsParam then begin
                SalesLine.Validate(Type, SalesLine.Type::Item);
                SalesLine.Validate("No.", ItemNo);
                SalesLine.Validate(Quantity, BCPTSetupUtilities.GetRandomQuantity());
                SalesLine.Validate("Unit Price", BCPTSetupUtilities.GetRandomUnitPrice());
            end else begin
                SalesLine.Type := SalesLine.Type::Item;
                SalesLine."No." := ItemNo;
                SalesLine.Quantity := BCPTSetupUtilities.GetRandomQuantity();
                SalesLine."Unit Price" := BCPTSetupUtilities.GetRandomUnitPrice();
            end;

            SalesLine.Modify(true);
            LineNo += 10000;
        end;

        BCPTTestContext.SetCustomDimension('CustomerNo', CustomerNo);
        BCPTTestContext.SetCustomDimension('DocumentNo', SalesHeader."No.");
        BCPTTestContext.SetCustomDimension('LineCount', Format(LineCountParam));
        BCPTTestContext.SetCustomDimension('ValidateFields', Format(ValidateFieldsParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        Item: Record Item;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        LineCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'LineCount', 3);
        ValidateFieldsParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'ValidateFields', true);

        // Build customer pool
        Clear(CustomerNoPool);
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.SetLoadFields("No.");
        if Customer.FindSet() then
            repeat
                CustomerNoPool.Add(Customer."No.");
            until (Customer.Next() = 0) or (CustomerNoPool.Count() >= 50);

        while CustomerNoPool.Count() < 10 do
            CustomerNoPool.Add(BCPTSetupUtilities.CreateRandomCustomer());

        // Build item pool
        Clear(ItemNoPool);
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetLoadFields("No.");
        if Item.FindSet() then
            repeat
                ItemNoPool.Add(Item."No.");
            until (Item.Next() = 0) or (ItemNoPool.Count() >= 100);

        while ItemNoPool.Count() < 20 do
            ItemNoPool.Add(BCPTSetupUtilities.CreateRandomItem());

        IsInitialized := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'LineCount=3,ValidateFields=true';
    end;
}

codeunit 50142 "BCPT API OData Query"
{
    // BCPT Test Scenario: Simulate OData Query Operations
    // Simulates OData-style queries with $filter, $top, $skip, $orderby.
    // Tests query performance patterns common in integrations.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        QueryCountParam: Integer;
        MaxRecordsParam: Integer;
        ScenarioNameTxt: Label 'OData Query Operations';

    trigger OnRun()
    var
        QueryType: Text[50];
        RecordsReturned: Integer;
        TotalQueries: Integer;
        i: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        RecordsReturned := 0;
        TotalQueries := 0;

        for i := 1 to QueryCountParam do begin
            case Random(6) of
                1:
                    begin
                        QueryType := 'Items-Filter-Price';
                        RecordsReturned += QueryItemsByPrice();
                    end;
                2:
                    begin
                        QueryType := 'SalesOrders-TopN';
                        RecordsReturned += QuerySalesOrdersTopN();
                    end;
                3:
                    begin
                        QueryType := 'Customers-OrderBy';
                        RecordsReturned += QueryCustomersOrderBy();
                    end;
                4:
                    begin
                        QueryType := 'Vendors-Filter-Balance';
                        RecordsReturned += QueryVendorsByBalance();
                    end;
                5:
                    begin
                        QueryType := 'Items-Filter-Category';
                        RecordsReturned += QueryItemsByCategory();
                    end;
                6:
                    begin
                        QueryType := 'LedgerEntries-DateRange';
                        RecordsReturned += QueryLedgerEntriesByDate();
                    end;
            end;
            TotalQueries += 1;
        end;

        BCPTTestContext.SetCustomDimension('TotalQueries', Format(TotalQueries));
        BCPTTestContext.SetCustomDimension('RecordsReturned', Format(RecordsReturned));
        BCPTTestContext.SetCustomDimension('LastQueryType', QueryType);
        BCPTTestContext.SetCustomDimension('MaxRecords', Format(MaxRecordsParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        QueryCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'QueryCount', 5);
        MaxRecordsParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'MaxRecords', 100);

        IsInitialized := true;
    end;

    local procedure QueryItemsByPrice(): Integer
    var
        Item: Record Item;
        RecordCount: Integer;
        MinPrice: Decimal;
        MaxPrice: Decimal;
    begin
        // Simulate: $filter=unitPrice ge 10 and unitPrice le 500
        MinPrice := Random(50);
        MaxPrice := MinPrice + Random(500);

        Item.SetRange("Unit Price", MinPrice, MaxPrice);
        Item.SetRange(Blocked, false);
        Item.SetLoadFields("No.", Description, "Unit Price", Inventory);

        RecordCount := 0;
        if Item.FindSet() then
            repeat
                RecordCount += 1;
            until (Item.Next() = 0) or (RecordCount >= MaxRecordsParam);

        exit(RecordCount);
    end;

    local procedure QuerySalesOrdersTopN(): Integer
    var
        SalesHeader: Record "Sales Header";
        RecordCount: Integer;
    begin
        // Simulate: $top=50&$orderby=orderDate desc
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetCurrentKey("Order Date");
        SalesHeader.Ascending(false);
        SalesHeader.SetLoadFields("No.", "Sell-to Customer No.", "Order Date", Amount);

        RecordCount := 0;
        if SalesHeader.FindSet() then
            repeat
                SalesHeader.CalcFields(Amount);
                RecordCount += 1;
            until (SalesHeader.Next() = 0) or (RecordCount >= MaxRecordsParam);

        exit(RecordCount);
    end;

    local procedure QueryCustomersOrderBy(): Integer
    var
        Customer: Record Customer;
        RecordCount: Integer;
    begin
        // Simulate: $orderby=name&$top=100
        Customer.SetCurrentKey(Name);
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.SetLoadFields("No.", Name, City, "Balance (LCY)");

        RecordCount := 0;
        if Customer.FindSet() then
            repeat
                RecordCount += 1;
            until (Customer.Next() = 0) or (RecordCount >= MaxRecordsParam);

        exit(RecordCount);
    end;

    local procedure QueryVendorsByBalance(): Integer
    var
        Vendor: Record Vendor;
        RecordCount: Integer;
    begin
        // Simulate: $filter=balanceDue gt 0
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Vendor.SetLoadFields("No.", Name, "Balance (LCY)", "Balance Due (LCY)");

        RecordCount := 0;
        if Vendor.FindSet() then
            repeat
                Vendor.CalcFields("Balance Due (LCY)");
                if Vendor."Balance Due (LCY)" > 0 then
                    RecordCount += 1;
            until (Vendor.Next() = 0) or (RecordCount >= MaxRecordsParam);

        exit(RecordCount);
    end;

    local procedure QueryItemsByCategory(): Integer
    var
        Item: Record Item;
        ItemCategory: Record "Item Category";
        CategoryCode: Code[20];
        RecordCount: Integer;
    begin
        // Simulate: $filter=itemCategoryCode eq 'FURNITURE'
        ItemCategory.SetLoadFields(Code);
        if ItemCategory.FindFirst() then
            CategoryCode := ItemCategory.Code
        else
            exit(0);

        Item.SetRange("Item Category Code", CategoryCode);
        Item.SetRange(Blocked, false);
        Item.SetLoadFields("No.", Description, "Item Category Code", "Unit Price");

        RecordCount := 0;
        if Item.FindSet() then
            repeat
                RecordCount += 1;
            until (Item.Next() = 0) or (RecordCount >= MaxRecordsParam);

        exit(RecordCount);
    end;

    local procedure QueryLedgerEntriesByDate(): Integer
    var
        GLEntry: Record "G/L Entry";
        StartDate: Date;
        EndDate: Date;
        RecordCount: Integer;
    begin
        // Simulate: $filter=postingDate ge 2024-01-01 and postingDate le 2024-12-31
        EndDate := WorkDate();
        StartDate := CalcDate('<-30D>', EndDate);

        GLEntry.SetRange("Posting Date", StartDate, EndDate);
        GLEntry.SetLoadFields("Entry No.", "G/L Account No.", "Posting Date", Amount, "Document No.");

        RecordCount := 0;
        if GLEntry.FindSet() then
            repeat
                RecordCount += 1;
            until (GLEntry.Next() = 0) or (RecordCount >= MaxRecordsParam);

        exit(RecordCount);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'QueryCount=5,MaxRecords=100';
    end;
}
