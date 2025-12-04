codeunit 50110 "BCPT Purchase Order Tracking"
{
    // BCPT Test Scenario: Create Purchase Orders with Item Tracking
    // Creates purchase orders with lot/serial tracking assignments.
    // Tests item tracking performance which is often a bottleneck.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        VendorNoPool: List of [Code[20]];
        TrackedItemNoPool: List of [Code[20]];
        NonTrackedItemNoPool: List of [Code[20]];
        MinLinesParam: Integer;
        MaxLinesParam: Integer;
        UseItemTrackingParam: Boolean;
        ScenarioNameTxt: Label 'Create Purchase Order with Tracking';

    trigger OnRun()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorNo: Code[20];
        LineCount: Integer;
        TrackedLineCount: Integer;
        i: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Select random vendor
        if VendorNoPool.Count() = 0 then
            VendorNoPool.Add(BCPTSetupUtilities.CreateRandomVendor());
        VendorNo := VendorNoPool.Get(Random(VendorNoPool.Count()));

        LineCount := BCPTSetupUtilities.GetRandomLineCount(MinLinesParam, MaxLinesParam);
        TrackedLineCount := 0;

        // Create purchase order
        CreatePurchaseOrderHeader(PurchaseHeader, VendorNo);

        for i := 1 to LineCount do begin
            if UseItemTrackingParam and (TrackedItemNoPool.Count() > 0) and (Random(2) = 1) then begin
                CreatePurchaseLineWithTracking(PurchaseHeader);
                TrackedLineCount += 1;
            end else
                CreatePurchaseLine(PurchaseHeader);
        end;

        BCPTTestContext.SetCustomDimension('VendorNo', VendorNo);
        BCPTTestContext.SetCustomDimension('DocumentNo', PurchaseHeader."No.");
        BCPTTestContext.SetCustomDimension('LineCount', Format(LineCount));
        BCPTTestContext.SetCustomDimension('TrackedLineCount', Format(TrackedLineCount));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Vendor: Record Vendor;
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();

        MinLinesParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'MinLines', 2);
        MaxLinesParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'MaxLines', 8);
        UseItemTrackingParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'UseItemTracking', true);

        // Build vendor pool
        Clear(VendorNoPool);
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Vendor.SetLoadFields("No.");
        if Vendor.FindSet() then
            repeat
                VendorNoPool.Add(Vendor."No.");
            until (Vendor.Next() = 0) or (VendorNoPool.Count() >= 50);

        while VendorNoPool.Count() < 10 do
            VendorNoPool.Add(BCPTSetupUtilities.CreateRandomVendor());

        // Build item pools (tracked vs non-tracked)
        Clear(TrackedItemNoPool);
        Clear(NonTrackedItemNoPool);
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetLoadFields("No.", "Item Tracking Code");
        if Item.FindSet() then
            repeat
                if Item."Item Tracking Code" <> '' then begin
                    if ItemTrackingCode.Get(Item."Item Tracking Code") then
                        if ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."SN Specific Tracking" then
                            TrackedItemNoPool.Add(Item."No.")
                        else
                            NonTrackedItemNoPool.Add(Item."No.");
                end else
                    NonTrackedItemNoPool.Add(Item."No.");
            until (Item.Next() = 0) or (NonTrackedItemNoPool.Count() >= 100);

        while NonTrackedItemNoPool.Count() < 20 do
            NonTrackedItemNoPool.Add(BCPTSetupUtilities.CreateRandomItem());

        IsInitialized := true;
    end;

    local procedure CreatePurchaseOrderHeader(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20])
    begin
        PurchaseHeader.Init();
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
        PurchaseHeader.Insert(true);
        PurchaseHeader.Validate("Buy-from Vendor No.", VendorNo);
        PurchaseHeader.Validate("Posting Date", WorkDate());
        PurchaseHeader.Validate("Order Date", WorkDate());
        PurchaseHeader."Vendor Invoice No." := 'BCPT-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2><Seconds,2>');
        PurchaseHeader.Modify(true);
    end;

    local procedure CreatePurchaseLine(var PurchaseHeader: Record "Purchase Header")
    var
        PurchaseLine: Record "Purchase Line";
        ItemNo: Code[20];
        LineNo: Integer;
    begin
        if NonTrackedItemNoPool.Count() = 0 then
            exit;
        ItemNo := NonTrackedItemNoPool.Get(Random(NonTrackedItemNoPool.Count()));

        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        if PurchaseLine.FindLast() then
            LineNo := PurchaseLine."Line No." + 10000
        else
            LineNo := 10000;

        PurchaseLine.Init();
        PurchaseLine."Document Type" := PurchaseHeader."Document Type";
        PurchaseLine."Document No." := PurchaseHeader."No.";
        PurchaseLine."Line No." := LineNo;
        PurchaseLine.Insert(true);
        PurchaseLine.Validate(Type, PurchaseLine.Type::Item);
        PurchaseLine.Validate("No.", ItemNo);
        PurchaseLine.Validate(Quantity, BCPTSetupUtilities.GetRandomQuantity());
        PurchaseLine.Validate("Direct Unit Cost", BCPTSetupUtilities.GetRandomUnitPrice() * 0.7);
        PurchaseLine.Modify(true);
    end;

    local procedure CreatePurchaseLineWithTracking(var PurchaseHeader: Record "Purchase Header")
    var
        PurchaseLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        ItemNo: Code[20];
        LineNo: Integer;
        LotNo: Code[50];
        EntryNo: Integer;
    begin
        if TrackedItemNoPool.Count() = 0 then begin
            CreatePurchaseLine(PurchaseHeader);
            exit;
        end;
        ItemNo := TrackedItemNoPool.Get(Random(TrackedItemNoPool.Count()));

        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        if PurchaseLine.FindLast() then
            LineNo := PurchaseLine."Line No." + 10000
        else
            LineNo := 10000;

        PurchaseLine.Init();
        PurchaseLine."Document Type" := PurchaseHeader."Document Type";
        PurchaseLine."Document No." := PurchaseHeader."No.";
        PurchaseLine."Line No." := LineNo;
        PurchaseLine.Insert(true);
        PurchaseLine.Validate(Type, PurchaseLine.Type::Item);
        PurchaseLine.Validate("No.", ItemNo);
        PurchaseLine.Validate(Quantity, BCPTSetupUtilities.GetRandomQuantity());
        PurchaseLine.Validate("Direct Unit Cost", BCPTSetupUtilities.GetRandomUnitPrice() * 0.7);
        PurchaseLine.Modify(true);

        // Assign lot tracking
        LotNo := 'BCPT-LOT-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2><Seconds,2>');

        ReservationEntry.LockTable();
        if ReservationEntry.FindLast() then
            EntryNo := ReservationEntry."Entry No." + 1
        else
            EntryNo := 1;

        ReservationEntry.Init();
        ReservationEntry."Entry No." := EntryNo;
        ReservationEntry.Positive := true;
        ReservationEntry."Item No." := ItemNo;
        ReservationEntry."Location Code" := PurchaseLine."Location Code";
        ReservationEntry."Quantity (Base)" := PurchaseLine."Quantity (Base)";
        ReservationEntry.Quantity := PurchaseLine.Quantity;
        ReservationEntry."Reservation Status" := ReservationEntry."Reservation Status"::Surplus;
        ReservationEntry."Source Type" := Database::"Purchase Line";
        ReservationEntry."Source Subtype" := PurchaseLine."Document Type".AsInteger();
        ReservationEntry."Source ID" := PurchaseLine."Document No.";
        ReservationEntry."Source Ref. No." := PurchaseLine."Line No.";
        ReservationEntry."Lot No." := LotNo;
        ReservationEntry."Creation Date" := Today();
        ReservationEntry."Created By" := UserId();
        ReservationEntry.Insert();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'MinLines=2,MaxLines=8,UseItemTracking=true';
    end;
}

codeunit 50111 "BCPT Purchase Invoice Post"
{
    // BCPT Test Scenario: Post Purchase Invoices
    // Creates and posts purchase invoices to test AP processing performance.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        VendorNoPool: List of [Code[20]];
        ItemNoPool: List of [Code[20]];
        LineCountParam: Integer;
        ScenarioNameTxt: Label 'Post Purchase Invoice';

    trigger OnRun()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchPost: Codeunit "Purch.-Post";
        VendorNo: Code[20];
        PostSuccess: Boolean;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        VendorNo := VendorNoPool.Get(Random(VendorNoPool.Count()));

        // Create purchase invoice
        CreatePurchaseInvoice(PurchaseHeader, VendorNo);

        BCPTTestContext.SetCustomDimension('VendorNo', VendorNo);
        BCPTTestContext.SetCustomDimension('DocumentNo', PurchaseHeader."No.");
        BCPTTestContext.SetCustomDimension('LineCount', Format(LineCountParam));

        // Post the invoice
        Commit();
        PostSuccess := PurchPost.Run(PurchaseHeader);

        BCPTTestContext.SetCustomDimension('PostSuccess', Format(PostSuccess));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Vendor: Record Vendor;
        Item: Record Item;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        LineCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'LineCount', 5);

        // Build vendor pool
        Clear(VendorNoPool);
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Vendor.SetLoadFields("No.");
        if Vendor.FindSet() then
            repeat
                VendorNoPool.Add(Vendor."No.");
            until (Vendor.Next() = 0) or (VendorNoPool.Count() >= 50);

        while VendorNoPool.Count() < 10 do
            VendorNoPool.Add(BCPTSetupUtilities.CreateRandomVendor());

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

    local procedure CreatePurchaseInvoice(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20])
    var
        PurchaseLine: Record "Purchase Line";
        ItemNo: Code[20];
        i: Integer;
        LineNo: Integer;
    begin
        PurchaseHeader.Init();
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Invoice;
        PurchaseHeader.Insert(true);
        PurchaseHeader.Validate("Buy-from Vendor No.", VendorNo);
        PurchaseHeader.Validate("Posting Date", WorkDate());
        PurchaseHeader."Vendor Invoice No." := 'BCPT-INV-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2>');
        PurchaseHeader.Modify(true);

        LineNo := 10000;
        for i := 1 to LineCountParam do begin
            ItemNo := ItemNoPool.Get(Random(ItemNoPool.Count()));

            PurchaseLine.Init();
            PurchaseLine."Document Type" := PurchaseHeader."Document Type";
            PurchaseLine."Document No." := PurchaseHeader."No.";
            PurchaseLine."Line No." := LineNo;
            PurchaseLine.Insert(true);
            PurchaseLine.Validate(Type, PurchaseLine.Type::Item);
            PurchaseLine.Validate("No.", ItemNo);
            PurchaseLine.Validate(Quantity, BCPTSetupUtilities.GetRandomQuantity());
            PurchaseLine.Validate("Direct Unit Cost", BCPTSetupUtilities.GetRandomUnitPrice() * 0.7);
            PurchaseLine.Modify(true);

            LineNo += 10000;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'LineCount=5';
    end;
}

codeunit 50112 "BCPT Vendor Payment Process"
{
    // BCPT Test Scenario: Process Vendor Payments
    // Creates payment journal lines and posts vendor payments.
    // Tests payment processing and bank reconciliation performance.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        VendorNoPool: List of [Code[20]];
        BankAccountNo: Code[20];
        PaymentCountParam: Integer;
        UseApplyToDocParam: Boolean;
        ScenarioNameTxt: Label 'Process Vendor Payments';

    trigger OnRun()
    var
        GenJournalLine: Record "Gen. Journal Line";
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        VendorNo: Code[20];
        PaymentAmount: Decimal;
        i: Integer;
        PostedCount: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Find payment journal template and batch
        GenJournalTemplate.SetRange(Type, GenJournalTemplate.Type::Payments);
        if not GenJournalTemplate.FindFirst() then begin
            BCPTTestContext.SetCustomDimension('Error', 'No payment journal template found');
            BCPTTestContext.EndScenario(ScenarioNameTxt);
            exit;
        end;

        GenJournalBatch.SetRange("Journal Template Name", GenJournalTemplate.Name);
        if not GenJournalBatch.FindFirst() then begin
            BCPTTestContext.SetCustomDimension('Error', 'No payment journal batch found');
            BCPTTestContext.EndScenario(ScenarioNameTxt);
            exit;
        end;

        PostedCount := 0;

        for i := 1 to PaymentCountParam do begin
            VendorNo := VendorNoPool.Get(Random(VendorNoPool.Count()));
            PaymentAmount := BCPTSetupUtilities.GetRandomUnitPrice() * 10;

            // Create payment line
            GenJournalLine.Init();
            GenJournalLine."Journal Template Name" := GenJournalTemplate.Name;
            GenJournalLine."Journal Batch Name" := GenJournalBatch.Name;
            GenJournalLine."Line No." := GetNextLineNo(GenJournalTemplate.Name, GenJournalBatch.Name);
            GenJournalLine."Document Type" := GenJournalLine."Document Type"::Payment;
            GenJournalLine."Document No." := 'BCPT-PAY-' + Format(i) + '-' + Format(CurrentDateTime(), 0, '<Hours24><Minutes,2><Seconds,2>');
            GenJournalLine."Posting Date" := WorkDate();
            GenJournalLine."Account Type" := GenJournalLine."Account Type"::Vendor;
            GenJournalLine.Validate("Account No.", VendorNo);
            GenJournalLine.Validate(Amount, PaymentAmount);
            GenJournalLine."Bal. Account Type" := GenJournalLine."Bal. Account Type"::"Bank Account";
            GenJournalLine.Validate("Bal. Account No.", BankAccountNo);
            GenJournalLine.Insert(true);

            // Apply to open documents if configured
            if UseApplyToDocParam then
                ApplyToOpenVendorEntries(GenJournalLine, VendorNo);

            // Post the payment
            Commit();
            if GenJnlPostLine.Run(GenJournalLine) then
                PostedCount += 1;
        end;

        BCPTTestContext.SetCustomDimension('PaymentCount', Format(PaymentCountParam));
        BCPTTestContext.SetCustomDimension('PostedCount', Format(PostedCount));
        BCPTTestContext.SetCustomDimension('ApplyToDoc', Format(UseApplyToDocParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Vendor: Record Vendor;
        BankAccount: Record "Bank Account";
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        PaymentCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'PaymentCount', 3);
        UseApplyToDocParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'ApplyToDoc', false);

        // Build vendor pool
        Clear(VendorNoPool);
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Vendor.SetLoadFields("No.");
        if Vendor.FindSet() then
            repeat
                VendorNoPool.Add(Vendor."No.");
            until (Vendor.Next() = 0) or (VendorNoPool.Count() >= 50);

        while VendorNoPool.Count() < 10 do
            VendorNoPool.Add(BCPTSetupUtilities.CreateRandomVendor());

        // Get first bank account
        BankAccount.SetLoadFields("No.");
        if BankAccount.FindFirst() then
            BankAccountNo := BankAccount."No.";

        IsInitialized := true;
    end;

    local procedure GetNextLineNo(TemplateName: Code[10]; BatchName: Code[10]): Integer
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.SetRange("Journal Template Name", TemplateName);
        GenJournalLine.SetRange("Journal Batch Name", BatchName);
        if GenJournalLine.FindLast() then
            exit(GenJournalLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure ApplyToOpenVendorEntries(var GenJournalLine: Record "Gen. Journal Line"; VendorNo: Code[20])
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        VendorLedgerEntry.SetRange("Vendor No.", VendorNo);
        VendorLedgerEntry.SetRange(Open, true);
        VendorLedgerEntry.SetRange("Document Type", VendorLedgerEntry."Document Type"::Invoice);
        VendorLedgerEntry.SetLoadFields("Document No.", "Remaining Amount");
        if VendorLedgerEntry.FindFirst() then begin
            GenJournalLine."Applies-to Doc. Type" := GenJournalLine."Applies-to Doc. Type"::Invoice;
            GenJournalLine."Applies-to Doc. No." := VendorLedgerEntry."Document No.";
            VendorLedgerEntry.CalcFields("Remaining Amount");
            GenJournalLine.Validate(Amount, -VendorLedgerEntry."Remaining Amount");
            GenJournalLine.Modify();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'PaymentCount=3,ApplyToDoc=false';
    end;
}
