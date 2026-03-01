unit Tests.Read;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Base.Controller,
  Bridge.Controller.Helper,
  Tests.Shared;

/// <summary>
/// Teste de LoadAll
/// </summary>
procedure RunLoadAllTest;

/// <summary>
/// Teste de LoadFromDataSet
/// </summary>
procedure RunLoadFromDataSetTest;

implementation

procedure RunLoadAllTest;
const
  RECORD_COUNT = 10;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LList: TObjectList<TPerson>;
  LQuery: TFDQuery;
  I: Integer;
  LValid: Boolean;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' LOADALL TEST');
  Writeln('===========================================');
  Writeln('');

  // 1. Setup
  Writeln('[1] Creating SQLite in-memory connection...');
  LConnection := CreateTestConnection;
  Writeln('    OK');

  Writeln('[2] Creating PERSON table...');
  CreatePersonTable(LConnection);
  Writeln('    OK');

  LController := CreateTestController(LConnection);
  LList := TObjectList<TPerson>.Create(True);
  
  try
    // 3. Insert records
    Writeln('[3] Inserting ', RECORD_COUNT, ' test records...');
    for I := 1 to RECORD_COUNT do
    begin
      LPerson := TPerson.Create;
      try
        LPerson.Name := 'Person_' + IntToStr(I);
        LPerson.Age := 20 + I;
        LController.Insert(LPerson);
      finally
        LPerson.Free;
      end;
    end;
    Writeln('    OK');

    // 4. LoadAll
    Writeln('[4] Loading all records with Fluent API...');
    LQuery := LController.Find<TPerson>.Execute;
    try
      if LController.LoadFromDataSet<TPerson>(LList, LQuery) then
      begin
        Writeln('    [PASS] Fluent query returned records');
        Writeln('    Loaded count: ', LList.Count);
        
        // 5. Verify data
        Writeln('[5] Verifying data...');
        LValid := True;
        
        if LList.Count <> RECORD_COUNT then
        begin
          Writeln('    [FAIL] Expected ', RECORD_COUNT, ' records, got ', LList.Count);
          LValid := False;
        end
        else if (LList[0].Name <> 'Person_1') or (LList[RECORD_COUNT-1].Name <> 'Person_' + IntToStr(RECORD_COUNT)) then
        begin
          Writeln('    [FAIL] Data mismatch');
          LValid := False;
        end;
        
        if LValid then
        begin
          Writeln('    [PASS] All records verified');
          
          // 6. Test filtered Load
          Writeln('[6] Testing filtered Fluent Query (Age > 25)...');
          LList.Clear;
          
          LQuery.Free; // Free previous query before reuse
          LQuery := LController.Find<TPerson>
            .Where('AGE >', 25)
            .Execute;
          try
            LController.LoadFromDataSet<TPerson>(LList, LQuery);
          finally
            // LQuery will be freed below
          end;
            
          Writeln('    Filtered count: ', LList.Count);
          if LList.Count = 5 then // 26, 27, 28, 29, 30
            Writeln('    [PASS] Filter verified')
          else
            Writeln('    [FAIL] Filter failed');

          Writeln('');
          Writeln('===========================================');
          Writeln(' LOADALL TEST PASSED!');
          Writeln('===========================================');
        end;
      end
      else
        Writeln('    [FAIL] Fluent query returned no records');
    finally
      LQuery.Free;
    end;
  finally
    LList.Free;
    LController.Free;
  end;
end;

procedure RunLoadFromDataSetTest;
var
  LController: TBaseController;
  LConnection: IConnection;
  LMemTable: TFDMemTable;
  LList: TObjectList<TPerson>;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' LOADFROMDATASET TEST');
  Writeln('===========================================');
  Writeln('');

  // 1. Setup
  Writeln('[1] Creating SQLite in-memory connection...');
  LConnection := CreateTestConnection;
  Writeln('    OK');

  LController := CreateTestController(LConnection);
  LList := TObjectList<TPerson>.Create(True);
  LMemTable := TFDMemTable.Create(nil);
  
  try
    // 2. Setup MemTable
    Writeln('[2] Creating TFDMemTable with test data...');
    LMemTable.FieldDefs.Add('ID', ftInteger);
    LMemTable.FieldDefs.Add('NAME', ftString, 100);
    LMemTable.FieldDefs.Add('AGE', ftInteger);
    LMemTable.CreateDataSet;
    
    LMemTable.Append;
    LMemTable.FieldByName('ID').AsInteger := 1;
    LMemTable.FieldByName('NAME').AsString := 'Person_A';
    LMemTable.FieldByName('AGE').AsInteger := 25;
    LMemTable.Post;
    
    LMemTable.Append;
    LMemTable.FieldByName('ID').AsInteger := 2;
    LMemTable.FieldByName('NAME').AsString := 'Person_B';
    LMemTable.FieldByName('AGE').AsInteger := 30;
    LMemTable.Post;
    
    LMemTable.Append;
    LMemTable.FieldByName('ID').AsInteger := 3;
    LMemTable.FieldByName('NAME').AsString := 'Person_C';
    LMemTable.FieldByName('AGE').AsInteger := 40;
    LMemTable.Post;
    
    Writeln('    OK - Added 3 records');

    // 3. Load from DataSet
    Writeln('[3] Calling LoadFromDataSet...');
    if LController.LoadFromDataSet<TPerson>(LList, LMemTable) then
    begin
      Writeln('    [PASS] LoadFromDataSet returned True');
      Writeln('    Loaded count: ', LList.Count);
      
      // 4. Verify data
      Writeln('[4] Verifying loaded data...');
      if LList.Count = 3 then
      begin
        if (LList[0].Name = 'Person_A') and (LList[0].Age = 25) and
           (LList[1].Name = 'Person_B') and (LList[1].Age = 30) and
           (LList[2].Name = 'Person_C') and (LList[2].Age = 40) then
        begin
          Writeln('    [PASS] All records loaded correctly');
          Writeln('');
          Writeln('===========================================');
          Writeln(' LOADFROMDATASET TEST PASSED!');
          Writeln('===========================================');
        end
        else
          Writeln('    [FAIL] Data mismatch');
      end
      else
        Writeln('    [FAIL] Expected 3 records, got ', LList.Count);
    end
    else
      Writeln('    [FAIL] LoadFromDataSet returned False');

  finally
    LMemTable.Free;
    LList.Free;
    LController.Free;
  end;
end;

end.
