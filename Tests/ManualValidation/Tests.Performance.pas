unit Tests.Performance;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Base.Controller,
  Bridge.Controller.Helper,
  Tests.Shared;

var
  GTimeNoTransaction: Double;
  GTimeWithTransaction: Double;
  GTimeWithInsertBatch: Double;
  GTimeWithUpdateBatch: Double;
  GTimeWithDeleteBatch: Double;

/// <summary>
/// Stress test sem transação
/// </summary>
procedure RunStressTest;

/// <summary>
/// Stress test com transação
/// </summary>
procedure RunStressTestWithTransaction;

/// <summary>
/// Stress test com InsertBatch
/// </summary>
/// <summary>
/// Stress test com InsertBatch
/// </summary>
procedure RunStressTestWithInsertBatch;

/// <summary>
/// Stress test com UpdateBatch
/// </summary>
procedure RunStressTestWithUpdateBatch;

/// <summary>
/// Stress test com DeleteBatch
/// </summary>
procedure RunStressTestWithDeleteBatch;

/// <summary>
/// Exibe resumo comparativo de performance
/// </summary>
procedure PrintPerformanceSummary;

implementation

procedure RunStressTest;
const
  RECORD_COUNT = 1000;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LList: TObjectList<TPerson>;
  LParams: TList<TCriterion>;
  LStartTime, LEndTime: TDateTime;
  LInsertTime: Double;
  I: Integer;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' STRESS TEST - ', RECORD_COUNT, ' Records');
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
  LParams := TList<TCriterion>.Create;

  try
    // 3. INSERT 1000 records
    Writeln('[3] Inserting ', RECORD_COUNT, ' records...');
    LStartTime := Now;

    for I := 1 to RECORD_COUNT do
    begin
      LPerson := TPerson.Create;
      try
        LPerson.Name := 'Person_' + IntToStr(I);
        LPerson.Age := 20 + (I mod 50);
        LController.Insert(LPerson);
      finally
        LPerson.Free;
      end;
    end;

    LEndTime := Now;
    LInsertTime := (LEndTime - LStartTime) * 24 * 60 * 60 * 1000;
    GTimeNoTransaction := LInsertTime;
    Writeln('    Inserted ', RECORD_COUNT, ' records in ', LInsertTime:0:2, ' ms');
    Writeln('    Avg: ', (LInsertTime / RECORD_COUNT):0:4, ' ms/record');

    // 4. LoadAll
    Writeln('[4] Loading all ', RECORD_COUNT, ' records with LoadAll...');
    LController.LoadAll<TPerson>(LList, LParams);
    Writeln('    Loaded: ', LList.Count, ' records');

    Writeln('');
    Writeln('===========================================');
    Writeln(' STRESS TEST PASSED!');
    Writeln('===========================================');
    Writeln(' Insert: ', LInsertTime:0:2, ' ms total (no transaction)');
    Writeln('===========================================');

  finally
    LParams.Free;
    LList.Free;
    LController.Free;
  end;
end;

procedure RunStressTestWithTransaction;
const
  RECORD_COUNT = 1000;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LList: TObjectList<TPerson>;
  LParams: TList<TCriterion>;
  LStartTime, LEndTime: TDateTime;
  LInsertTime: Double;
  I: Integer;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' STRESS TEST WITH TRANSACTION - ', RECORD_COUNT, ' Records');
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
  LParams := TList<TCriterion>.Create;

  try
    // 3. INSERT 1000 records WITH TRANSACTION
    Writeln('[3] Inserting ', RECORD_COUNT, ' records WITH TRANSACTION...');
    LStartTime := Now;

    LController.StartTransaction;
    try
      for I := 1 to RECORD_COUNT do
      begin
        LPerson := TPerson.Create;
        try
          LPerson.Name := 'Person_' + IntToStr(I);
          LPerson.Age := 20 + (I mod 50);
          LController.Insert(LPerson);
        finally
          LPerson.Free;
        end;
      end;
      LController.Commit;
    except
      LController.Rollback;
      raise;
    end;

    LEndTime := Now;
    LInsertTime := (LEndTime - LStartTime) * 24 * 60 * 60 * 1000;
    GTimeWithTransaction := LInsertTime;
    Writeln('    Inserted ', RECORD_COUNT, ' records in ', LInsertTime:0:2, ' ms');
    Writeln('    Avg: ', (LInsertTime / RECORD_COUNT):0:4, ' ms/record');

    // 4. LoadAll
    Writeln('[4] Loading all ', RECORD_COUNT, ' records with LoadAll...');
    LController.LoadAll<TPerson>(LList, LParams);
    Writeln('    Loaded: ', LList.Count, ' records');

    Writeln('');
    Writeln('===========================================');
    Writeln(' TRANSACTION TEST PASSED!');
    Writeln('===========================================');
    Writeln(' Insert: ', LInsertTime:0:2, ' ms total (with transaction)');
    Writeln('===========================================');

  finally
    LParams.Free;
    LList.Free;
    LController.Free;
  end;
end;

procedure RunStressTestWithInsertBatch;
const
  RECORD_COUNT = 1000;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LList: TObjectList<TPerson>;
  LInsertList: TObjectList<TPerson>;
  LParams: TList<TCriterion>;
  LStartTime, LEndTime: TDateTime;
  LInsertTime: Double;
  I: Integer;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' STRESS TEST WITH INSERTBATCH - ', RECORD_COUNT, ' Records');
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
  LInsertList := TObjectList<TPerson>.Create(True);
  LParams := TList<TCriterion>.Create;

  try
    // 3. Prepare batch list
    Writeln('[3] Preparing ', RECORD_COUNT, ' records for batch insert...');
    for I := 1 to RECORD_COUNT do
    begin
      LPerson := TPerson.Create;
      LPerson.Name := 'Person_' + IntToStr(I);
      LPerson.Age := 20 + (I mod 50);
      LInsertList.Add(LPerson);
    end;
    Writeln('    OK');

    // 4. INSERT with InsertBatch + Transaction
    Writeln('[4] Inserting ', RECORD_COUNT, ' records WITH InsertBatch + Transaction...');
    LStartTime := Now;

    LController.StartTransaction;
    try
      LController.InsertBatch<TPerson>(LInsertList);
      LController.Commit;
    except
      LController.Rollback;
      raise;
    end;

    LEndTime := Now;
    LInsertTime := (LEndTime - LStartTime) * 24 * 60 * 60 * 1000;
    GTimeWithInsertBatch := LInsertTime;
    Writeln('    Inserted ', RECORD_COUNT, ' records in ', LInsertTime:0:2, ' ms');
    Writeln('    Avg: ', (LInsertTime / RECORD_COUNT):0:4, ' ms/record');

    // 5. LoadAll
    Writeln('[5] Loading all ', RECORD_COUNT, ' records with LoadAll...');
    LController.LoadAll<TPerson>(LList, LParams);
    Writeln('    Loaded: ', LList.Count, ' records');

    Writeln('');
    Writeln('===========================================');
    Writeln(' INSERTBATCH TEST PASSED!');
    Writeln('===========================================');
    Writeln(' Insert: ', LInsertTime:0:2, ' ms total (InsertBatch)');
    Writeln('===========================================');

  finally
    LParams.Free;
    LInsertList.Free;
    LList.Free;
    LController.Free;
  end;
end;

procedure RunStressTestWithUpdateBatch;
const
  RECORD_COUNT = 1000;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LUpdateList: TObjectList<TPerson>;
  LStartTime, LEndTime: TDateTime;
  LUpdateTime: Double;
  I: Integer;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' STRESS TEST WITH UPDATEBATCH - ', RECORD_COUNT, ' Records');
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
  LUpdateList := TObjectList<TPerson>.Create(True);

  try
    // 3. Prepare initial data (Insert 1000 records)
    Writeln('[3] Preparing ', RECORD_COUNT, ' records (InsertBatch)...');
    for I := 1 to RECORD_COUNT do
    begin
      LPerson := TPerson.Create;
      LPerson.Name := 'Person_' + IntToStr(I);
      LPerson.Age := 20 + (I mod 50);
      LUpdateList.Add(LPerson);
    end;

    LController.StartTransaction;
    try
      LController.InsertBatch<TPerson>(LUpdateList);
      LController.Commit;
    except
      LController.Rollback;
      raise;
    end;
    Writeln('    OK (Inserted)');

    // 4. Update data in memory
    Writeln('[4] Updating objects in memory...');
    for LPerson in LUpdateList do
    begin
      LPerson.Name := LPerson.Name + '_Updated';
      LPerson.Age := LPerson.Age + 1;
    end;
    Writeln('    OK');

    // 5. UPDATE with UpdateBatch
    Writeln('[5] Updating ', RECORD_COUNT, ' records WITH UpdateBatch + Transaction...');
    LStartTime := Now;

    LController.StartTransaction;
    try
      LController.UpdateBatch<TPerson>(LUpdateList);
      LController.Commit;
    except
      LController.Rollback;
      raise;
    end;

    LEndTime := Now;
    LUpdateTime := (LEndTime - LStartTime) * 24 * 60 * 60 * 1000;
    GTimeWithUpdateBatch := LUpdateTime;
    Writeln('    Updated ', RECORD_COUNT, ' records in ', LUpdateTime:0:2, ' ms');
    Writeln('    Avg: ', (LUpdateTime / RECORD_COUNT):0:4, ' ms/record');

    Writeln('');
    Writeln('===========================================');
    Writeln(' UPDATEBATCH TEST PASSED!');
    Writeln('===========================================');
    Writeln(' Update: ', LUpdateTime:0:2, ' ms total (UpdateBatch)');
    Writeln('===========================================');

  finally
    LUpdateList.Free;
    LController.Free;
  end;
end;

procedure RunStressTestWithDeleteBatch;
const
  RECORD_COUNT = 1000;
var
  LController: TBaseController;
  LConnection: IConnection;
  LPerson: TPerson;
  LDeleteList: TObjectList<TPerson>;
  LStartTime, LEndTime: TDateTime;
  LDeleteTime: Double;
  I: Integer;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' STRESS TEST WITH DELETEBATCH - ', RECORD_COUNT, ' Records');
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
  LDeleteList := TObjectList<TPerson>.Create(True);

  try
    // 3. Prepare initial data
    Writeln('[3] Preparing ', RECORD_COUNT, ' records (InsertBatch)...');
    for I := 1 to RECORD_COUNT do
    begin
      LPerson := TPerson.Create;
      LPerson.Name := 'Person_' + IntToStr(I);
      LPerson.Age := 20 + (I mod 50);
      LDeleteList.Add(LPerson);
    end;

    LController.StartTransaction;
    try
      LController.InsertBatch<TPerson>(LDeleteList);
      LController.Commit;
    except
      LController.Rollback;
      raise;
    end;
    Writeln('    OK (Inserted)');

    // 4. DELETE with DeleteBatch
    Writeln('[4] Deleting ', RECORD_COUNT, ' records WITH DeleteBatch + Transaction...');
    LStartTime := Now;

    LController.StartTransaction;
    try
      LController.DeleteBatch<TPerson>(LDeleteList);
      LController.Commit;
    except
      LController.Rollback;
      raise;
    end;

    LEndTime := Now;
    LDeleteTime := (LEndTime - LStartTime) * 24 * 60 * 60 * 1000;
    GTimeWithDeleteBatch := LDeleteTime;
    Writeln('    Deleted ', RECORD_COUNT, ' records in ', LDeleteTime:0:2, ' ms');
    Writeln('    Avg: ', (LDeleteTime / RECORD_COUNT):0:4, ' ms/record');

    Writeln('');
    Writeln('===========================================');
    Writeln(' DELETEBATCH TEST PASSED!');
    Writeln('===========================================');
    Writeln(' Delete: ', LDeleteTime:0:2, ' ms total (DeleteBatch)');
    Writeln('===========================================');

  finally
    LDeleteList.Free;
    LController.Free;
  end;
end;

procedure PrintPerformanceSummary;
begin
  Writeln('');
  Writeln('');
  Writeln('*******************************************');
  Writeln('*       PERFORMANCE COMPARISON SUMMARY    *');
  Writeln('*          (1000 records insert)          *');
  Writeln('*******************************************');
  Writeln('');
  Writeln('  Method                    | Time       ');
  Writeln('  --------------------------|----------- ');
  Writeln('  Insert (no transaction)   | ', GTimeNoTransaction:8:2, ' ms');
  Writeln('  Insert (with transaction) | ', GTimeWithTransaction:8:2, ' ms');
  Writeln('  InsertBatch + Transaction | ', GTimeWithInsertBatch:8:2, ' ms');
  Writeln('  UpdateBatch + Transaction | ', GTimeWithUpdateBatch:8:2, ' ms');
  Writeln('  DeleteBatch + Transaction | ', GTimeWithDeleteBatch:8:2, ' ms');
  Writeln('');
  if GTimeWithInsertBatch > 0 then
  begin
    if GTimeWithTransaction > 0 then
      Writeln('  Speedup vs Transaction   : ', (GTimeWithTransaction / GTimeWithInsertBatch):6:1, 'x faster');
    if GTimeNoTransaction > 0 then
      Writeln('  Speedup vs No Transaction: ', (GTimeNoTransaction / GTimeWithInsertBatch):6:1, 'x faster');
  end;
  Writeln('');
  Writeln('*******************************************');
end;

end.
