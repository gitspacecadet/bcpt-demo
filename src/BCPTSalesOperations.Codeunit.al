codeunit 50101 "BCPT Sales Create Post Order"
{
    // BCPT Test Scenario: Create and Post Sales Orders
    // This codeunit creates sales orders with configurable line counts and posts them.
    // Generates RT0005 (Long Running AL) and RT0012 (Long Running SQL) telemetry.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        CustomerNoPool: List of [Code[20]];
        ItemNoPool: List of [Code[20]];
        MinLinesParam: Integer;
        MaxLinesParam: Integer;
        PostOrderParam: Boolean;
        CustomerPoolSize: Integer;
        ItemPoolSize: Integer;
        ScenarioNameTxt: Label 'Create and Post Sales Order';
        NoCustomersErr: Label 'No customers available in the customer pool.';
        NoItemsErr: Label 'No items available in the item pool.';

    trigger OnRun()
    var
        SalesHeader: Record "Sales Header";
        CustomerNo: Code[20];
        LineCount: Integer;
        i: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Select random customer from pool
        if CustomerNoPool.Count() = 0 then
            Error(NoCustomersErr);
        CustomerNo := CustomerNoPool.Get(Random(CustomerNoPool.Count()));

        // Determine line count for this iteration
        LineCount := BCPTSetupUtilities.GetRandomLineCount(MinLinesParam, MaxLinesParam);

        // Create sales order header
        CreateSalesOrderHeader(SalesHeader, CustomerNo);

        // Add sales lines
        for i := 1 to LineCount do
            CreateSalesOrderLine(SalesHeader);

        // Log custom dimensions for telemetry analysis
        BCPTTestContext.SetCustomDimension('LineCount', Format(LineCount));
        BCPTTestContext.SetCustomDimension('CustomerNo', CustomerNo);
        BCPTTestContext.SetCustomDimension('DocumentNo', SalesHeader."No.");

        // Post the order if configured
        if PostOrderParam then
            PostSalesOrder(SalesHeader);

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        Item: Record Item;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();

        // Parse parameters with defaults
        MinLinesParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'MinLines', 1);
        MaxLinesParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'MaxLines', 5);
        PostOrderParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'PostOrder', true);
        CustomerPoolSize := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'CustomerPoolSize', 50);
        ItemPoolSize := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'ItemPoolSize', 100);

        // Build customer pool
        Clear(CustomerNoPool);
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.SetLoadFields("No.");
        if Customer.FindSet() then
            repeat
                CustomerNoPool.Add(Customer."No.");
            until (Customer.Next() = 0) or (CustomerNoPool.Count() >= CustomerPoolSize);

        // Ensure minimum customers exist
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
            until (Item.Next() = 0) or (ItemNoPool.Count() >= ItemPoolSize);

        // Ensure minimum items exist
        while ItemNoPool.Count() < 20 do
            ItemNoPool.Add(BCPTSetupUtilities.CreateRandomItem());

        IsInitialized := true;
    end;

    local procedure CreateSalesOrderHeader(var SalesHeader: Record "Sales Header"; CustomerNo: Code[20])
    begin
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("Posting Date", WorkDate());
        SalesHeader.Validate("Order Date", WorkDate());
        SalesHeader."External Document No." := 'BCPT-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2><Seconds,2>');
        SalesHeader.Modify(true);
    end;

    local procedure CreateSalesOrderLine(var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        ItemNo: Code[20];
        LineNo: Integer;
    begin
        if ItemNoPool.Count() = 0 then
            Error(NoItemsErr);
        ItemNo := ItemNoPool.Get(Random(ItemNoPool.Count()));

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            LineNo := SalesLine."Line No." + 10000
        else
            LineNo := 10000;

        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := LineNo;
        SalesLine.Insert(true);
        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", ItemNo);
        SalesLine.Validate(Quantity, BCPTSetupUtilities.GetRandomQuantity());
        SalesLine.Validate("Unit Price", BCPTSetupUtilities.GetRandomUnitPrice());
        SalesLine.Modify(true);
    end;

    local procedure PostSalesOrder(var SalesHeader: Record "Sales Header")
    var
        SalesPost: Codeunit "Sales-Post";
    begin
        SalesHeader.Ship := true;
        SalesHeader.Invoice := true;
        SalesPost.Run(SalesHeader);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'MinLines=1,MaxLines=5,PostOrder=true,CustomerPoolSize=50,ItemPoolSize=100';
    end;
}

codeunit 50102 "BCPT Sales Invoice Batch"
{
    // BCPT Test Scenario: Process Sales Invoices in Batches
    // Creates multiple sales invoices and posts them in a batch operation.
    // Tests batch posting performance and generates posting telemetry.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        CustomerNoPool: List of [Code[20]];
        ItemNoPool: List of [Code[20]];
        BatchSizeParam: Integer;
        LinesPerInvoiceParam: Integer;
        ScenarioNameTxt: Label 'Batch Post Sales Invoices';

    trigger OnRun()
    var
        SalesHeader: Record "Sales Header";
        SalesHeaderToPost: Record "Sales Header";
        BatchNo: Text[20];
        i: Integer;
        SuccessCount: Integer;
        FailCount: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        BatchNo := Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2>');
        SuccessCount := 0;
        FailCount := 0;

        // Create batch of invoices
        for i := 1 to BatchSizeParam do begin
            CreateSalesInvoice(SalesHeader);
            SalesHeader."External Document No." := 'BATCH-' + BatchNo + '-' + Format(i);
            SalesHeader.Modify();
        end;

        // Post all invoices in batch
        SalesHeaderToPost.SetRange("Document Type", SalesHeaderToPost."Document Type"::Invoice);
        SalesHeaderToPost.SetFilter("External Document No.", 'BATCH-' + BatchNo + '*');
        if SalesHeaderToPost.FindSet() then
            repeat
                if PostSalesInvoice(SalesHeaderToPost) then
                    SuccessCount += 1
                else
                    FailCount += 1;
            until SalesHeaderToPost.Next() = 0;

        BCPTTestContext.SetCustomDimension('BatchSize', Format(BatchSizeParam));
        BCPTTestContext.SetCustomDimension('SuccessCount', Format(SuccessCount));
        BCPTTestContext.SetCustomDimension('FailCount', Format(FailCount));
        BCPTTestContext.SetCustomDimension('BatchNo', BatchNo);

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        Item: Record Item;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();

        BatchSizeParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'BatchSize', 5);
        LinesPerInvoiceParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'LinesPerInvoice', 3);

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

    local procedure CreateSalesInvoice(var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        CustomerNo: Code[20];
        ItemNo: Code[20];
        i: Integer;
        LineNo: Integer;
    begin
        CustomerNo := CustomerNoPool.Get(Random(CustomerNoPool.Count()));

        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Invoice;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("Posting Date", WorkDate());
        SalesHeader.Modify(true);

        LineNo := 10000;
        for i := 1 to LinesPerInvoiceParam do begin
            ItemNo := ItemNoPool.Get(Random(ItemNoPool.Count()));

            SalesLine.Init();
            SalesLine."Document Type" := SalesHeader."Document Type";
            SalesLine."Document No." := SalesHeader."No.";
            SalesLine."Line No." := LineNo;
            SalesLine.Insert(true);
            SalesLine.Validate(Type, SalesLine.Type::Item);
            SalesLine.Validate("No.", ItemNo);
            SalesLine.Validate(Quantity, BCPTSetupUtilities.GetRandomQuantity());
            SalesLine.Modify(true);

            LineNo += 10000;
        end;
    end;

    local procedure PostSalesInvoice(var SalesHeader: Record "Sales Header"): Boolean
    var
        SalesPost: Codeunit "Sales-Post";
    begin
        Commit();
        if not SalesPost.Run(SalesHeader) then
            exit(false);
        exit(true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'BatchSize=5,LinesPerInvoice=3';
    end;
}

codeunit 50103 "BCPT Sales Customer Search"
{
    // BCPT Test Scenario: Customer Search Operations
    // Tests customer lookup performance with various search criteria.
    // Simulates typical user search patterns generating RT0012 telemetry.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        SearchTermPool: List of [Text[100]];
        SearchByNameParam: Boolean;
        SearchByCityParam: Boolean;
        SearchByPostCodeParam: Boolean;
        IncludeBalanceCalcParam: Boolean;
        ScenarioNameTxt: Label 'Customer Search Operations';

    trigger OnRun()
    var
        Customer: Record Customer;
        SearchTerm: Text[100];
        RecordsFound: Integer;
        SearchType: Text[50];
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Select random search term
        if SearchTermPool.Count() > 0 then
            SearchTerm := SearchTermPool.Get(Random(SearchTermPool.Count()))
        else
            SearchTerm := 'A';

        // Perform search based on configuration
        RecordsFound := 0;
        SearchType := '';

        if SearchByNameParam then begin
            SearchType := 'Name';
            RecordsFound := SearchCustomersByName(SearchTerm);
        end;

        if SearchByCityParam then begin
            if SearchType <> '' then
                SearchType += ', ';
            SearchType += 'City';
            RecordsFound += SearchCustomersByCity(SearchTerm);
        end;

        if SearchByPostCodeParam then begin
            if SearchType <> '' then
                SearchType += ', ';
            SearchType += 'PostCode';
            RecordsFound += SearchCustomersByPostCode(SearchTerm);
        end;

        // Calculate balance if configured (expensive operation)
        if IncludeBalanceCalcParam then
            CalculateCustomerBalances();

        BCPTTestContext.SetCustomDimension('SearchTerm', SearchTerm);
        BCPTTestContext.SetCustomDimension('SearchType', SearchType);
        BCPTTestContext.SetCustomDimension('RecordsFound', Format(RecordsFound));
        BCPTTestContext.SetCustomDimension('IncludedBalanceCalc', Format(IncludeBalanceCalcParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();

        SearchByNameParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'SearchByName', true);
        SearchByCityParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'SearchByCity', true);
        SearchByPostCodeParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'SearchByPostCode', false);
        IncludeBalanceCalcParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'IncludeBalanceCalc', true);

        // Build search term pool from existing customer data
        Clear(SearchTermPool);
        Customer.SetLoadFields(Name, City, "Post Code");
        if Customer.FindSet() then
            repeat
                if Customer.Name <> '' then
                    SearchTermPool.Add(CopyStr(Customer.Name, 1, 3));
                if Customer.City <> '' then
                    SearchTermPool.Add(Customer.City);
            until (Customer.Next() = 0) or (SearchTermPool.Count() >= 100);

        // Add some generic search terms
        SearchTermPool.Add('A');
        SearchTermPool.Add('B');
        SearchTermPool.Add('C');
        SearchTermPool.Add('Test');
        SearchTermPool.Add('Customer');

        IsInitialized := true;
    end;

    local procedure SearchCustomersByName(SearchTerm: Text[100]): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetFilter(Name, '@*' + SearchTerm + '*');
        Customer.SetLoadFields("No.", Name, "Balance (LCY)");
        exit(Customer.Count());
    end;

    local procedure SearchCustomersByCity(SearchTerm: Text[100]): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetFilter(City, '@*' + SearchTerm + '*');
        Customer.SetLoadFields("No.", Name, City);
        exit(Customer.Count());
    end;

    local procedure SearchCustomersByPostCode(SearchTerm: Text[100]): Integer
    var
        Customer: Record Customer;
    begin
        Customer.SetFilter("Post Code", '@' + SearchTerm + '*');
        Customer.SetLoadFields("No.", Name, "Post Code");
        exit(Customer.Count());
    end;

    local procedure CalculateCustomerBalances()
    var
        Customer: Record Customer;
        TotalBalance: Decimal;
        CustomerCount: Integer;
    begin
        // This is an expensive operation that calculates flowfields
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        if Customer.FindSet() then
            repeat
                Customer.CalcFields("Balance (LCY)", "Balance Due (LCY)");
                TotalBalance += Customer."Balance (LCY)";
                CustomerCount += 1;
            until (Customer.Next() = 0) or (CustomerCount >= 100);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'SearchByName=true,SearchByCity=true,SearchByPostCode=false,IncludeBalanceCalc=true';
    end;
}
