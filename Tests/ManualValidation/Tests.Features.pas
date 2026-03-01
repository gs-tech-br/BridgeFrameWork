unit Tests.Features;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  Bridge.MetaData.Types,
  Bridge.Connection.Interfaces,
  Bridge.Connection.SQLite,
  Bridge.Base.Controller,
  Bridge.Async.Controller,
  Bridge.Connection.Data,
  Tests.Shared;

procedure RunSoftDeleteTest;
procedure RunAsyncTest;

implementation

type
  TAsyncPersonController = class(TAsyncController)
  end;

procedure RunSoftDeleteTest;
var
  LConn: IConnection;
  LController: TBaseController;
  LPerson: TSoftDeletePerson;
  LQuery: TDataSet;
begin
  Writeln('--------------------------------------------------');
  Writeln('TEST: SoftDelete');
  Writeln('--------------------------------------------------');
  LConn := CreateTestConnection;
  CreateSoftDeletePersonTable(LConn);
  LController := CreateTestController(LConn);
  try
    LPerson := TSoftDeletePerson.Create;
    try
      LPerson.Name := 'John Doe';
      LPerson.IsDeleted := 0; 
      
      // 1. Insert
      LController.Insert(LPerson);
      Writeln('Inserted Person ID: ', LPerson.Id);

      // 2. Delete (Should be Soft Delete)
      Writeln('Deleting Person...');
      LController.Delete(LPerson);
      
      // 3. Verify in Database
      // We manually select to check the IS_DELETED flag
      LQuery := LConn.CreateDataSet(Format('SELECT IS_DELETED FROM PERSON_SOFT WHERE ID = %d', [LPerson.Id]));
      try
        TFDQuery(LQuery).Open;
        if not LQuery.IsEmpty then
        begin
           if LQuery.FieldByName('IS_DELETED').AsInteger = 1 then
             Writeln('SUCCESS: Record exists and IS_DELETED = 1')
           else
             Writeln('FAILURE: Record exists but IS_DELETED = ', LQuery.FieldByName('IS_DELETED').AsInteger);
        end
        else
          Writeln('FAILURE: Record was biologically deleted!');
      finally
        LQuery.Free;
      end;
      
      // 4. Restore
      Writeln('Restoring Person...');
      LController.Restore(LPerson);
      
      // 5. Verify Restore
      LQuery := LConn.CreateDataSet(Format('SELECT IS_DELETED FROM PERSON_SOFT WHERE ID = %d', [LPerson.Id]));
      try
        TFDQuery(LQuery).Open;
        if not LQuery.IsEmpty then
        begin
           if LQuery.FieldByName('IS_DELETED').AsInteger = 0 then
             Writeln('SUCCESS: Record restored (IS_DELETED = 0)')
           else
             Writeln('FAILURE: Record restored but IS_DELETED = ', LQuery.FieldByName('IS_DELETED').AsInteger);
        end;
      finally
        LQuery.Free;
      end;
      
    finally
      LPerson.Free;
    end;
  finally
    LController.Free;
  end;
end;

type
  TFileCredentials = class(TInterfacedObject, IConnectionCredentialsProvider)
  public
    function GetDriverID: string;
    function GetServer: string;
    function GetPort: string;
    function GetDatabase: string;
    function GetUserName: string;
    function GetPassword: string;
    function GetDataBaseConnection: TDataBaseConnection;
  end;

function TFileCredentials.GetDriverID: string; begin Result := 'SQLite'; end;
function TFileCredentials.GetServer: string; begin Result := ''; end;
function TFileCredentials.GetPort: string; begin Result := ''; end;
function TFileCredentials.GetDatabase: string; begin Result := 'test_async.db'; end;
function TFileCredentials.GetUserName: string; begin Result := ''; end;
function TFileCredentials.GetPassword: string; begin Result := ''; end;
function TFileCredentials.GetDataBaseConnection: TDataBaseConnection; begin Result := dbSQLite; end;

procedure RunAsyncTest;
var
  LConn: IConnection;
  LAsyncController: TAsyncPersonController;
  I: Integer;
  LFinished: Boolean;
  LSuccess: Boolean;
  LMsg: string;
begin
  Writeln('--------------------------------------------------');
  Writeln('TEST: Async Controller');
  Writeln('--------------------------------------------------');
  
  if FileExists('test_async.db') then
    DeleteFile('test_async.db');
    
  // Setup Connection and Data
  LConn := TConnectionSQLite.Create(TFileCredentials.Create);
  CreatePersonTable(LConn);
  
  Writeln('Inserting 10 records for Async Test...');
  // Insert some data using standard controller or direct execution
  for I := 1 to 10 do
  begin
    LConn.Execute(Format('INSERT INTO PERSON (NAME, AGE) VALUES (''User %d'', %d)', [I, 20 + I]));
  end;
  
  // Configure Async Controller Dependency Injection
  TAsyncController.OnAcquireConnection := function: IConnection
    begin
      Result := TConnectionSQLite.Create(TFileCredentials.Create);
    end;
    
  TAsyncController.OnReleaseConnection := procedure(C: IConnection)
    begin
      // Let interface refcounting handle it, or explicit close if needed
      // Since it's an interface, local variable in AsyncController will release it.
      // But we can log here.
      // Writeln('Async Connection Released'); 
    end;

  LAsyncController := TAsyncPersonController.Create; // Connection not needed for constructor if pool/DI is used
  try
    LFinished := False;
    LSuccess := False;
    LMsg := '';
    
    Writeln('Starting Async LoadAll...');
    
    LAsyncController.LoadAllAsync<TPerson>(nil, 
      procedure(AList: TObjectList<TPerson>)
      begin
        Writeln('Async Callback Executed!');
        if Assigned(AList) then
        begin
          Writeln(Format('Loaded %d records', [AList.Count]));
          if AList.Count = 10 then
            LSuccess := True
          else
            LMsg := 'Count mismatch';
          AList.Free;
        end
        else
          LMsg := 'List is nil';
          
        LFinished := True;
      end,
      procedure(AError: string)
      begin
        Writeln('Async Error: ' + AError);
        LMsg := AError;
        LFinished := True;
      end
    );
    
    Writeln('Waiting for async operation...');
    // Simple event loop for console
    while not LFinished do
    begin
      CheckSynchronize(10); // Process main thread queue
      Sleep(10);
    end;
    
    if LSuccess then
      Writeln('SUCCESS: Async LoadAll completed correctly.')
    else
      Writeln('FAILURE: ' + LMsg);
      
  finally
    LAsyncController.Free;
    // Clear DI
    TAsyncController.OnAcquireConnection := nil;
    TAsyncController.OnReleaseConnection := nil;
    
    // Cleanup DB file (need to ensure connections are closed!)
    LConn := nil; // Release main connection
  end;
  
  // Give some time for threads/OS to release file lock if we want to delete validly
  Sleep(100);
  if FileExists('test_async.db') then
    DeleteFile('test_async.db'); 
end;

end.
