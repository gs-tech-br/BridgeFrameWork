unit Tests.Write;

interface

uses
  System.SysUtils,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Base.Controller,
  Bridge.MetaData.Types,
  Bridge.MetaData.Manager,
  Tests.Shared;

/// <summary>
/// Teste básico de Insert
/// </summary>
procedure RunBasicInsertTest;

/// <summary>
/// Teste de Delete
/// </summary>
procedure RunDeleteTest;

/// <summary>
/// Teste de Update
/// </summary>
procedure RunUpdateTest;
    
/// <summary>
/// Teste de SQL Injection
/// </summary>
procedure RunSqlInjectionTest;

implementation

procedure RunBasicInsertTest;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LLoaded: TPerson;
  LId: Integer;
begin
  Writeln('===========================================');
  Writeln(' INSERT TEST');
  Writeln('===========================================');
  Writeln('');

  // 1. Setup
  Writeln('[1] Creating SQLite in-memory connection...');
  LConnection := CreateTestConnection;
  Writeln('    OK');

  Writeln('[2] Creating PERSON table...');
  CreatePersonTable(LConnection);
  Writeln('    OK');

  Writeln('[3] Creating TBaseController...');
  LController := CreateTestController(LConnection);
  Writeln('    OK');
  
  try
    // 4. Insert
    Writeln('[4] Inserting TPerson (Name=John Doe, Age=30)...');
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'John Doe';
      LPerson.Age := 30;
      
      LController.Insert(LPerson);
      LId := LPerson.Id;
      
      Writeln('    Returned ID: ', LId);
      
      if LId = 0 then
      begin
        Writeln('    [FAIL] ID should not be 0 after insert (AutoInc)');
        Exit;
      end
      else
        Writeln('    [PASS] AutoInc ID assigned correctly');
        
    finally
      LPerson.Free;
    end;

    // 5. Verify
    Writeln('[5] Loading TPerson with ID=', LId, '...');
    LLoaded := TPerson.Create;
    try
      if LController.Load(LLoaded, LId) then
      begin
        Writeln('    Loaded Name: ', LLoaded.Name);
        Writeln('    Loaded Age:  ', LLoaded.Age);
        
        if (LLoaded.Name = 'John Doe') and (LLoaded.Age = 30) then
        begin
          Writeln('    [PASS] Data integrity verified');
          Writeln('');
          Writeln('===========================================');
          Writeln(' INSERT TEST PASSED!');
          Writeln('===========================================');
        end
        else
          Writeln('    [FAIL] Data mismatch');
      end
      else
        Writeln('    [FAIL] Record not found');
        
    finally
      LLoaded.Free;
    end;

  finally
    LController.Free;
  end;
end;

procedure RunDeleteTest;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LLoaded: TPerson;
  LId: Integer;
  LResult: TValidate;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' DELETE TEST');
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
  
  try
    // 3. Insert a record first
    Writeln('[3] Inserting test record...');
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'ToDelete';
      LPerson.Age := 25;
      LController.Insert(LPerson);
      LId := LPerson.Id;
      Writeln('    Inserted ID: ', LId);
    finally
      LPerson.Free;
    end;

    // 4. Delete the record
    Writeln('[4] Deleting record with ID=', LId, '...');
    LPerson := TPerson.Create;
    try
      LPerson.Id := LId;
      LResult := LController.Delete(LPerson);
      if LResult.Sucess then
        Writeln('    [PASS] Delete returned success')
      else
        Writeln('    [FAIL] Delete failed: ', LResult.Message);
    finally
      LPerson.Free;
    end;

    // 5. Verify record is gone
    Writeln('[5] Verifying record is deleted...');
    LLoaded := TPerson.Create;
    try
      if not LController.Load(LLoaded, LId) then
      begin
        Writeln('    [PASS] Record not found (correctly deleted)');
        Writeln('');
        Writeln('===========================================');
        Writeln(' DELETE TEST PASSED!');
        Writeln('===========================================');
      end
      else
        Writeln('    [FAIL] Record still exists after delete');
    finally
      LLoaded.Free;
    end;

  finally
    LController.Free;
  end;
end;

procedure RunUpdateTest;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LId: Integer;
  LResult: TValidate;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' UPDATE TEST');
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
  
  try
    // 3. Insert initial record
    Writeln('[3] Inserting initial record (Name=Original, Age=20)...');
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'Original';
      LPerson.Age := 20;
      LController.Insert(LPerson);
      LId := LPerson.Id;
      Writeln('    Inserted ID: ', LId);
    finally
      LPerson.Free;
    end;

    // 4. Update the record
    Writeln('[4] Updating record (Name=Modified, Age=35)...');
    LPerson := TPerson.Create;
    try
      LPerson.Id := LId;
      LPerson.Name := 'Modified';
      LPerson.Age := 35;
      LResult := LController.Update(LPerson);
      if LResult.Sucess then
        Writeln('    [PASS] Update returned success')
      else
      begin
        Writeln('    [FAIL] Update failed: ', LResult.Message);
        Exit;
      end;
    finally
      LPerson.Free;
    end;

    // 5. Reload and verify changes
    Writeln('[5] Reloading and verifying changes...');
    LPerson := TPerson.Create;
    try
      if LController.Load(LPerson, LId) then
      begin
        Writeln('    Loaded Name: ', LPerson.Name);
        Writeln('    Loaded Age:  ', LPerson.Age);
        
        if (LPerson.Name = 'Modified') and (LPerson.Age = 35) then
        begin
          Writeln('    [PASS] Data correctly updated');
          Writeln('');
          Writeln('===========================================');
          Writeln(' UPDATE TEST PASSED!');
          Writeln('===========================================');
        end
        else
          Writeln('    [FAIL] Data mismatch after update');
      end
      else
        Writeln('    [FAIL] Record not found after update');
    finally
      LPerson.Free;
    end;

  finally
    LController.Free;
  end;
end;

procedure RunSqlInjectionTest;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LLoaded: TPerson;
  LId: Integer;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' SQL INJECTION TEST');
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

  try
    try
      // 3. Insert Malicious Payload
      Writeln('[3] Inserting malicious payload (Name=''Hacker''''); DROP TABLE PERSON; --'')...');
      
      LPerson := TPerson.Create;
      try
        LPerson.Name := 'Hacker''); DROP TABLE PERSON; --';
        LPerson.Age := 99;
        
        LController.Insert(LPerson);
        LId := LPerson.Id;
        
        Writeln('    Inserted ID: ', LId);
        Writeln('    [PASS] No SQL Error raised (Injection prevented?)');
      finally
        LPerson.Free;
      end;

      // 4. Verify Integrity
      Writeln('[4] Verifying data integrity and table existence...');
      LLoaded := TPerson.Create;
      try
        if LController.Load(LLoaded, LId) then
        begin
          Writeln('    Loaded Name: ', LLoaded.Name);
          
          if LLoaded.Name = 'Hacker''); DROP TABLE PERSON; --' then
          begin
            Writeln('    [PASS] Name stored literally (Values escaped correctly)');
            Writeln('    [PASS] Table still exists (DROP TABLE failed)');
            Writeln('');
            Writeln('===========================================');
            Writeln(' SQL INJECTION TEST PASSED!');
            Writeln('===========================================');
          end
          else
            Writeln('    [FAIL] Name stored incorrectly: ', LLoaded.Name);
        end
        else
          Writeln('    [FAIL] Record not found');
      finally
        LLoaded.Free;
      end;
      
    except
      on E: Exception do
      begin
        Writeln('    [FAIL] Exception raised: ', E.Message);
        // Table might be dropped or syntax error due to bad escaping
      end;
    end;

  finally
    LController.Free;
  end;
end;

end.
