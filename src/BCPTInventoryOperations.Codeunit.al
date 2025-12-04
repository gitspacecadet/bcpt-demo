codeunit 50120 "BCPT Inventory Item Lookup"
{
    // BCPT Test Scenario: Item Lookup and Search Operations
    // Tests item search performance with various criteria and filters.
    // Generates RT0012 telemetry for SQL query analysis.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        SearchTermPool: List of [Text[50]];
        CategoryCodePool: List of [Code[20]];
        CalcInventoryParam: Boolean;
        CalcAvailabilityParam: Boolean;
        SearchCountParam: Integer;
        ScenarioNameTxt: Label 'Item Lookup and Search';

    trigger OnRun()
    var
        Item: Record Item;
        SearchTerm: Text[50];
        RecordsFound: Integer;
        TotalSearches: Integer;
        i: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        RecordsFound := 0;
        TotalSearches := 0;

        for i := 1 to SearchCountParam do begin
            // Perform different types of searches
            case Random(4) of
                1:
                    RecordsFound += SearchItemsByDescription();
                2:
                    RecordsFound += SearchItemsByCategory();
                3:
                    RecordsFound += SearchItemsByVendor();
                4:
                    RecordsFound += SearchItemsWithFilters();
            end;
            TotalSearches += 1;
        end;

        // Calculate inventory and availability if configured
        if CalcInventoryParam then
            CalculateInventoryLevels();

        if CalcAvailabilityParam then
            CalculateItemAvailability();

        BCPTTestContext.SetCustomDimension('TotalSearches', Format(TotalSearches));
        BCPTTestContext.SetCustomDimension('RecordsFound', Format(RecordsFound));
        BCPTTestContext.SetCustomDimension('CalcInventory', Format(CalcInventoryParam));
        BCPTTestContext.SetCustomDimension('CalcAvailability', Format(CalcAvailabilityParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Item: Record Item;
        ItemCategory: Record "Item Category";
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();

        CalcInventoryParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'CalcInventory', true);
        CalcAvailabilityParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'CalcAvailability', true);
        SearchCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'SearchCount', 5);

        // Build search term pool
        Clear(SearchTermPool);
        Item.SetLoadFields(Description);
        if Item.FindSet() then
            repeat
                if Item.Description <> '' then
                    SearchTermPool.Add(CopyStr(Item.Description, 1, 5));
            until (Item.Next() = 0) or (SearchTermPool.Count() >= 50);

        SearchTermPool.Add('Item');
        SearchTermPool.Add('Test');
        SearchTermPool.Add('A');
        SearchTermPool.Add('B');

        // Build category pool
        Clear(CategoryCodePool);
        ItemCategory.SetLoadFields(Code);
        if ItemCategory.FindSet() then
            repeat
                CategoryCodePool.Add(ItemCategory.Code);
            until (ItemCategory.Next() = 0) or (CategoryCodePool.Count() >= 20);

        IsInitialized := true;
    end;

    local procedure SearchItemsByDescription(): Integer
    var
        Item: Record Item;
        SearchTerm: Text[50];
    begin
        if SearchTermPool.Count() > 0 then
            SearchTerm := SearchTermPool.Get(Random(SearchTermPool.Count()))
        else
            SearchTerm := 'A';

        Item.SetFilter(Description, '@*' + SearchTerm + '*');
        Item.SetLoadFields("No.", Description, "Unit Price", Inventory);
        exit(Item.Count());
    end;

    local procedure SearchItemsByCategory(): Integer
    var
        Item: Record Item;
        CategoryCode: Code[20];
    begin
        if CategoryCodePool.Count() = 0 then
            exit(0);

        CategoryCode := CategoryCodePool.Get(Random(CategoryCodePool.Count()));
        Item.SetRange("Item Category Code", CategoryCode);
        Item.SetLoadFields("No.", Description, "Item Category Code");
        exit(Item.Count());
    end;

    local procedure SearchItemsByVendor(): Integer
    var
        Item: Record Item;
        Vendor: Record Vendor;
    begin
        Vendor.SetLoadFields("No.");
        if not Vendor.FindFirst() then
            exit(0);

        Item.SetRange("Vendor No.", Vendor."No.");
        Item.SetLoadFields("No.", Description, "Vendor No.");
        exit(Item.Count());
    end;

    local procedure SearchItemsWithFilters(): Integer
    var
        Item: Record Item;
    begin
        // Complex filter with multiple conditions
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetFilter("Unit Price", '>%1', 0);
        Item.SetLoadFields("No.", Description, "Unit Price", Type, Blocked);
        exit(Item.Count());
    end;

    local procedure CalculateInventoryLevels()
    var
        Item: Record Item;
        TotalInventory: Decimal;
        ItemCount: Integer;
    begin
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        if Item.FindSet() then
            repeat
                Item.CalcFields(Inventory, "Qty. on Purch. Order", "Qty. on Sales Order");
                TotalInventory += Item.Inventory;
                ItemCount += 1;
            until (Item.Next() = 0) or (ItemCount >= 100);
    end;

    local procedure CalculateItemAvailability()
    var
        Item: Record Item;
        ItemAvailabilityFormsMgt: Codeunit "Item Availability Forms Mgt";
        AvailableQty: Decimal;
        ItemCount: Integer;
    begin
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        if Item.FindSet() then
            repeat
                Item.CalcFields(
                    Inventory,
                    "Qty. on Purch. Order",
                    "Qty. on Sales Order",
                    "Qty. on Service Order",
                    "Qty. on Job Order",
                    "Qty. on Assembly Order",
                    "Qty. on Prod. Order"
                );
                AvailableQty := Item.Inventory - Item."Qty. on Sales Order" + Item."Qty. on Purch. Order";
                ItemCount += 1;
            until (Item.Next() = 0) or (ItemCount >= 50);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'CalcInventory=true,CalcAvailability=true,SearchCount=5';
    end;
}

codeunit 50121 "BCPT Inventory Adjustment"
{
    // BCPT Test Scenario: Inventory Adjustments
    // Creates and posts inventory adjustments to test warehouse operations.
    // Generates posting telemetry for item ledger analysis.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        ItemNoPool: List of [Code[20]];
        LocationCodePool: List of [Code[10]];
        AdjustmentCountParam: Integer;
        UseLocationsParam: Boolean;
        ScenarioNameTxt: Label 'Post Inventory Adjustment';

    trigger OnRun()
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        ItemNo: Code[20];
        LocationCode: Code[10];
        AdjustmentQty: Decimal;
        i: Integer;
        PostedCount: Integer;
        LineNo: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        // Find item journal template and batch
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Item);
        ItemJournalTemplate.SetRange(Recurring, false);
        if not ItemJournalTemplate.FindFirst() then begin
            BCPTTestContext.SetCustomDimension('Error', 'No item journal template found');
            BCPTTestContext.EndScenario(ScenarioNameTxt);
            exit;
        end;

        ItemJournalBatch.SetRange("Journal Template Name", ItemJournalTemplate.Name);
        if not ItemJournalBatch.FindFirst() then begin
            BCPTTestContext.SetCustomDimension('Error', 'No item journal batch found');
            BCPTTestContext.EndScenario(ScenarioNameTxt);
            exit;
        end;

        PostedCount := 0;
        LineNo := 10000;

        for i := 1 to AdjustmentCountParam do begin
            ItemNo := ItemNoPool.Get(Random(ItemNoPool.Count()));

            if UseLocationsParam and (LocationCodePool.Count() > 0) then
                LocationCode := LocationCodePool.Get(Random(LocationCodePool.Count()))
            else
                LocationCode := '';

            // Randomly choose positive or negative adjustment
            if Random(2) = 1 then
                AdjustmentQty := BCPTSetupUtilities.GetRandomQuantity()
            else
                AdjustmentQty := -BCPTSetupUtilities.GetRandomQuantity() / 2;

            // Create adjustment line
            ItemJournalLine.Init();
            ItemJournalLine."Journal Template Name" := ItemJournalTemplate.Name;
            ItemJournalLine."Journal Batch Name" := ItemJournalBatch.Name;
            ItemJournalLine."Line No." := LineNo;
            if AdjustmentQty > 0 then
                ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::"Positive Adjmt."
            else begin
                ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::"Negative Adjmt.";
                AdjustmentQty := Abs(AdjustmentQty);
            end;
            ItemJournalLine."Posting Date" := WorkDate();
            ItemJournalLine."Document No." := 'BCPT-ADJ-' + Format(i) + '-' + Format(CurrentDateTime(), 0, '<Hours24><Minutes,2><Seconds,2>');
            ItemJournalLine.Validate("Item No.", ItemNo);
            if LocationCode <> '' then
                ItemJournalLine.Validate("Location Code", LocationCode);
            ItemJournalLine.Validate(Quantity, AdjustmentQty);
            ItemJournalLine.Insert(true);

            // Post the adjustment
            Commit();
            if ItemJnlPostLine.Run(ItemJournalLine) then
                PostedCount += 1;

            LineNo += 10000;
        end;

        BCPTTestContext.SetCustomDimension('AdjustmentCount', Format(AdjustmentCountParam));
        BCPTTestContext.SetCustomDimension('PostedCount', Format(PostedCount));
        BCPTTestContext.SetCustomDimension('UseLocations', Format(UseLocationsParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Item: Record Item;
        Location: Record Location;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        AdjustmentCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'AdjustmentCount', 5);
        UseLocationsParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'UseLocations', true);

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
        Parameters := 'AdjustmentCount=5,UseLocations=true';
    end;
}

codeunit 50122 "BCPT Inventory Availability"
{
    // BCPT Test Scenario: Calculate Inventory Availability
    // Performs availability calculations across multiple items and dates.
    // This is a computationally expensive operation for performance testing.

    SingleInstance = true;
    SubType = Test;

    var
        BCPTTestContext: Codeunit "BCPT Test Context";
        BCPTSetupUtilities: Codeunit "BCPT Setup Utilities";
        IsInitialized: Boolean;
        ItemNoPool: List of [Code[20]];
        LocationCodePool: List of [Code[10]];
        ItemCountParam: Integer;
        DateRangeDaysParam: Integer;
        IncludeVariantsParam: Boolean;
        ScenarioNameTxt: Label 'Calculate Inventory Availability';

    trigger OnRun()
    var
        Item: Record Item;
        ItemNo: Code[20];
        CalculatedItems: Integer;
        TotalAvailable: Decimal;
        i: Integer;
    begin
        if not IsInitialized then
            Initialize();

        BCPTTestContext.StartScenario(ScenarioNameTxt);

        CalculatedItems := 0;
        TotalAvailable := 0;

        for i := 1 to ItemCountParam do begin
            if ItemNoPool.Count() = 0 then
                exit;

            ItemNo := ItemNoPool.Get(Random(ItemNoPool.Count()));

            // Calculate availability for this item
            TotalAvailable += CalculateItemAvailability(ItemNo);
            CalculatedItems += 1;

            // Calculate projected availability over date range
            CalculateProjectedAvailability(ItemNo);
        end;

        BCPTTestContext.SetCustomDimension('ItemsCalculated', Format(CalculatedItems));
        BCPTTestContext.SetCustomDimension('TotalAvailable', Format(TotalAvailable, 0, '<Integer><Decimals,2>'));
        BCPTTestContext.SetCustomDimension('DateRangeDays', Format(DateRangeDaysParam));
        BCPTTestContext.SetCustomDimension('IncludeVariants', Format(IncludeVariantsParam));

        BCPTTestContext.EndScenario(ScenarioNameTxt);
    end;

    local procedure Initialize()
    var
        Item: Record Item;
        Location: Record Location;
        Parameters: Text;
    begin
        Parameters := BCPTTestContext.GetParameters();
        ItemCountParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'ItemCount', 20);
        DateRangeDaysParam := BCPTSetupUtilities.ParseParameterInteger(Parameters, 'DateRangeDays', 30);
        IncludeVariantsParam := BCPTSetupUtilities.ParseParameterBoolean(Parameters, 'IncludeVariants', true);

        // Build item pool
        Clear(ItemNoPool);
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetLoadFields("No.");
        if Item.FindSet() then
            repeat
                ItemNoPool.Add(Item."No.");
            until (Item.Next() = 0) or (ItemNoPool.Count() >= 200);

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

    local procedure CalculateItemAvailability(ItemNo: Code[20]): Decimal
    var
        Item: Record Item;
        AvailableQty: Decimal;
        LocationCode: Code[10];
        i: Integer;
    begin
        if not Item.Get(ItemNo) then
            exit(0);

        // Calculate for each location
        for i := 1 to LocationCodePool.Count() do begin
            LocationCode := LocationCodePool.Get(i);
            Item.SetRange("Location Filter", LocationCode);
            Item.CalcFields(
                Inventory,
                "Qty. on Purch. Order",
                "Qty. on Sales Order",
                "Reserved Qty. on Inventory",
                "Reserved Qty. on Purch. Orders",
                "Reserved Qty. on Sales Orders"
            );
            AvailableQty += Item.Inventory - Item."Qty. on Sales Order" + Item."Qty. on Purch. Order";
        end;

        // Also calculate without location filter (all locations)
        Item.SetRange("Location Filter");
        Item.CalcFields(
            Inventory,
            "Qty. on Purch. Order",
            "Qty. on Sales Order",
            "Qty. on Service Order",
            "Qty. on Job Order",
            "Qty. on Assembly Order",
            "Qty. on Prod. Order"
        );

        exit(Item.Inventory - Item."Qty. on Sales Order" + Item."Qty. on Purch. Order");
    end;

    local procedure CalculateProjectedAvailability(ItemNo: Code[20])
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        StartDate: Date;
        EndDate: Date;
        CurrentDate: Date;
    begin
        if not Item.Get(ItemNo) then
            exit;

        StartDate := WorkDate();
        EndDate := CalcDate('<+' + Format(DateRangeDaysParam) + 'D>', StartDate);

        // Calculate availability for each day in range (expensive operation)
        CurrentDate := StartDate;
        while CurrentDate <= EndDate do begin
            Item.SetRange("Date Filter", 0D, CurrentDate);
            Item.CalcFields(
                "Net Change",
                "Purchases (Qty.)",
                "Sales (Qty.)"
            );
            CurrentDate := CurrentDate + 7; // Weekly intervals to reduce load
        end;

        // Include variant calculations if configured
        if IncludeVariantsParam then begin
            ItemVariant.SetRange("Item No.", ItemNo);
            if ItemVariant.FindSet() then
                repeat
                    Item.SetRange("Variant Filter", ItemVariant.Code);
                    Item.CalcFields(Inventory, "Qty. on Sales Order", "Qty. on Purch. Order");
                until ItemVariant.Next() = 0;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BCPT Test Context", OnGetParameters, '', false, false)]
    local procedure OnGetParameters(var Parameters: Text)
    begin
        Parameters := 'ItemCount=20,DateRangeDays=30,IncludeVariants=true';
    end;
}
