codeunit 50100 "BCPT Setup Utilities"
{
    // Utility codeunit for BCPT test data setup and helper functions.
    // This codeunit provides shared functionality across all BCPT test scenarios.

    var
        LibrarySales: Codeunit "Library - Sales";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryRandom: Codeunit "Library - Random";
        LibraryUtility: Codeunit "Library - Utility";

    procedure GetRandomCustomerNo(): Code[20]
    var
        Customer: Record Customer;
    begin
        Customer.SetFilter("No.", '<>%1', '');
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        if Customer.FindSet() then begin
            Customer.Next(LibraryRandom.RandInt(Customer.Count()));
            exit(Customer."No.");
        end;
        exit(CreateRandomCustomer());
    end;

    procedure GetRandomVendorNo(): Code[20]
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetFilter("No.", '<>%1', '');
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        if Vendor.FindSet() then begin
            Vendor.Next(LibraryRandom.RandInt(Vendor.Count()));
            exit(Vendor."No.");
        end;
        exit(CreateRandomVendor());
    end;

    procedure GetRandomItemNo(): Code[20]
    var
        Item: Record Item;
    begin
        Item.SetFilter("No.", '<>%1', '');
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        if Item.FindSet() then begin
            Item.Next(LibraryRandom.RandInt(Item.Count()));
            exit(Item."No.");
        end;
        exit(CreateRandomItem());
    end;

    procedure GetRandomLocationCode(): Code[10]
    var
        Location: Record Location;
    begin
        Location.SetRange("Use As In-Transit", false);
        if Location.FindSet() then begin
            Location.Next(LibraryRandom.RandInt(Location.Count()));
            exit(Location.Code);
        end;
        exit('');
    end;

    procedure CreateRandomCustomer(): Code[20]
    var
        Customer: Record Customer;
    begin
        LibrarySales.CreateCustomer(Customer);
        Customer.Name := 'BCPT Test Customer ' + Format(LibraryRandom.RandIntInRange(1000, 9999));
        Customer.Modify();
        exit(Customer."No.");
    end;

    procedure CreateRandomVendor(): Code[20]
    var
        Vendor: Record Vendor;
    begin
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Name := 'BCPT Test Vendor ' + Format(LibraryRandom.RandIntInRange(1000, 9999));
        Vendor.Modify();
        exit(Vendor."No.");
    end;

    procedure CreateRandomItem(): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItem(Item);
        Item.Description := 'BCPT Test Item ' + Format(LibraryRandom.RandIntInRange(1000, 9999));
        Item."Unit Price" := LibraryRandom.RandDecInRange(10, 1000, 2);
        Item."Unit Cost" := Item."Unit Price" * 0.7;
        Item.Modify();
        exit(Item."No.");
    end;

    procedure GetRandomQuantity(): Decimal
    begin
        exit(LibraryRandom.RandDecInRange(1, 100, 2));
    end;

    procedure GetRandomUnitPrice(): Decimal
    begin
        exit(LibraryRandom.RandDecInRange(10, 500, 2));
    end;

    procedure GetRandomLineCount(MinLines: Integer; MaxLines: Integer): Integer
    begin
        exit(LibraryRandom.RandIntInRange(MinLines, MaxLines));
    end;

    procedure SimulateUserDelay(MinMs: Integer; MaxMs: Integer)
    begin
        // Simulate realistic user think time between operations
        Sleep(LibraryRandom.RandIntInRange(MinMs, MaxMs));
    end;

    procedure GetWorkDate(): Date
    begin
        exit(WorkDate());
    end;

    procedure ParseParameterInteger(Parameters: Text; ParameterName: Text; DefaultValue: Integer): Integer
    var
        ParameterValue: Text;
        IntValue: Integer;
    begin
        ParameterValue := GetParameterValue(Parameters, ParameterName);
        if ParameterValue = '' then
            exit(DefaultValue);
        if Evaluate(IntValue, ParameterValue) then
            exit(IntValue);
        exit(DefaultValue);
    end;

    procedure ParseParameterDecimal(Parameters: Text; ParameterName: Text; DefaultValue: Decimal): Decimal
    var
        ParameterValue: Text;
        DecValue: Decimal;
    begin
        ParameterValue := GetParameterValue(Parameters, ParameterName);
        if ParameterValue = '' then
            exit(DefaultValue);
        if Evaluate(DecValue, ParameterValue) then
            exit(DecValue);
        exit(DefaultValue);
    end;

    procedure ParseParameterBoolean(Parameters: Text; ParameterName: Text; DefaultValue: Boolean): Boolean
    var
        ParameterValue: Text;
    begin
        ParameterValue := GetParameterValue(Parameters, ParameterName);
        if ParameterValue = '' then
            exit(DefaultValue);
        exit(UpperCase(ParameterValue) in ['TRUE', 'YES', '1']);
    end;

    procedure ParseParameterText(Parameters: Text; ParameterName: Text; DefaultValue: Text): Text
    var
        ParameterValue: Text;
    begin
        ParameterValue := GetParameterValue(Parameters, ParameterName);
        if ParameterValue = '' then
            exit(DefaultValue);
        exit(ParameterValue);
    end;

    local procedure GetParameterValue(Parameters: Text; ParameterName: Text): Text
    var
        StartPos: Integer;
        EndPos: Integer;
        SearchText: Text;
    begin
        SearchText := ParameterName + '=';
        StartPos := StrPos(Parameters, SearchText);
        if StartPos = 0 then
            exit('');
        StartPos += StrLen(SearchText);
        EndPos := StartPos;
        while (EndPos <= StrLen(Parameters)) and (Parameters[EndPos] <> ',') do
            EndPos += 1;
        exit(CopyStr(Parameters, StartPos, EndPos - StartPos));
    end;

    procedure LogCustomDimension(var BCPTTestContext: Codeunit "BCPT Test Context"; DimensionName: Text; DimensionValue: Text)
    begin
        // Add custom dimension for telemetry tracking
        BCPTTestContext.SetCustomDimension(DimensionName, DimensionValue);
    end;

    procedure EnsureInventoryForItem(ItemNo: Code[20]; LocationCode: Code[10]; MinQuantity: Decimal)
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        Item: Record Item;
    begin
        // Ensure minimum inventory exists for testing
        Item.Get(ItemNo);
        Item.SetFilter("Location Filter", LocationCode);
        Item.CalcFields(Inventory);

        if Item.Inventory >= MinQuantity then
            exit;

        // Find or create item journal batch
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Item);
        ItemJournalTemplate.SetRange(Recurring, false);
        if not ItemJournalTemplate.FindFirst() then
            exit;

        ItemJournalBatch.SetRange("Journal Template Name", ItemJournalTemplate.Name);
        if not ItemJournalBatch.FindFirst() then
            exit;

        // Create positive adjustment
        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := ItemJournalTemplate.Name;
        ItemJournalLine."Journal Batch Name" := ItemJournalBatch.Name;
        ItemJournalLine."Line No." := 10000;
        ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::"Positive Adjmt.";
        ItemJournalLine."Posting Date" := WorkDate();
        ItemJournalLine."Document No." := 'BCPT-ADJ-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2>');
        ItemJournalLine.Validate("Item No.", ItemNo);
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Validate(Quantity, MinQuantity - Item.Inventory + 100);
        ItemJournalLine.Insert(true);

        Codeunit.Run(Codeunit::"Item Jnl.-Post Line", ItemJournalLine);
    end;
}
