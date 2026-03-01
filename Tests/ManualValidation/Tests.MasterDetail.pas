unit Tests.MasterDetail;

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  Bridge.Base.Controller,
  Bridge.Connection.Interfaces,
  Bridge.Controller.Registry,
  Tests.MasterDetail.Entities,
  Tests.MasterDetail.Controller,
  Tests.Shared;

procedure RunMasterDetailTest;

implementation

procedure RunMasterDetailTest;
var
  LMaster: TMaster;
  LDetail: TDetail;
  LController: TMasterController;
  LConnection: IConnection;
  LMasterId: Integer;
  LCount: Variant;
  LQuery: TDataSet;
begin
  Writeln('--------------------------------------------------');
  Writeln('Running Master-Detail Transaction Test...');
  
  // 1. Setup Connection
  LConnection := CreateTestConnection;
  
  // 2. Register Controllers
  TControllerRegistry.Instance.Register<TMaster, TMasterController>;
  TControllerRegistry.Instance.Register<TDetail, TDetailController>;
  
  // Create Tables for Test
  LConnection.Execute(
    'CREATE TABLE TEST_MASTER (' +
    '  ID INTEGER PRIMARY KEY, ' +
    '  DESCRIPTION VARCHAR(100) ' +
    ')'
  );
  
  LConnection.Execute(
    'CREATE TABLE TEST_DETAIL (' +
    '  ID INTEGER PRIMARY KEY, ' +
    '  MASTER_ID INTEGER, ' +
    '  DESCRIPTION VARCHAR(100), ' +
    '  FOREIGN KEY (MASTER_ID) REFERENCES TEST_MASTER(ID)' +
    ')'
  );

  // 3. Create Controller with connection
  LController := TMasterController.Create(LConnection);
  
  try
    LMaster := TMaster.Create;
    LDetail := TDetail.Create;
    try
      Writeln('Starting Transaction...');
      LController.StartTransaction;
      
      // 1. Insert Master
      LMaster.Description := 'Master Record ' + FormatDateTime('hh:nn:ss', Now);
      Writeln('Inserting Master...');
      if not LController.Insert(LMaster).Sucess then
        raise Exception.Create('Failed to insert Master');
      
      LMasterId := LMaster.Id;
      Writeln(Format('Master ID Generated: %d', [LMasterId]));
      
      if LMasterId <= 0 then
        raise Exception.Create('Error: Master ID was not generated immediately!');

      // 2. Insert Detail with Master ID
      LDetail.MasterId := LMasterId;
      LDetail.Description := 'Detail for Master ' + IntToStr(LMasterId);
      Writeln('Inserting Detail...');
      
      // We can use a TDetailController here if we want strict typing or just use LController.Insert if generic enough
      // But LController is TMasterController. 
      // Ideally we should use TDetailController for inserting detail if we want to follow MVC pattern strictly.
      // However, for simplicity let's use a new controller for detail or if TBaseController can handle it (it can if model allows)
      // Since TMasterController is bound to TMasterModel/TMasterEntity (via FEntityClass), using it to insert TDetail might fail inside logic if it relies on FEntityClass
      // Let's create a temporary detail controller for insertion to be safe and correct.
      with TDetailController.Create(LConnection) do
      try
        if not Insert(LDetail).Sucess then
          raise Exception.Create('Failed to insert Detail');
      finally
        Free;
      end;
      
      Writeln(Format('Detail ID Generated: %d', [LDetail.Id]));

      // 3. Verify Master Visibility within Transaction
      Writeln('Verifying Master visibility within transaction...');
      Writeln('InTransaction: ' + BoolToStr(LConnection.InTransaction, True));
      
      // SQL Direct Check
      try
        LConnection.Execute('SELECT COUNT(*) FROM TEST_MASTER WHERE ID = ' + IntToStr(LMasterId), LCount);
        Writeln('Count Result: ' + VarToStr(LCount));
      except
        on E: Exception do Writeln('SQL Check Error: ' + E.Message);
      end;
      
      if Integer(LCount) = 0 then
         raise Exception.Create('Error: Master record not visible (SQL Direct Check)!');
         
      // FindInternal Check
      LQuery := LController.FindInternal(TMaster, LMasterId);
      try
        if LQuery.RecordCount = 0 then
          raise Exception.Create('Error: Master record not visible via FindInternal!');
      finally
        LQuery.Free;
      end;

      // 4. Verify Lazy Loading (Relationships) check
      // We need to Load the entity to trigger lazy loading
      Writeln('Verifying Relationship Loading (With Same Transaction Context)...');
      
      LMaster.Free; // Free previous instance
      LMaster := TMaster.Create;
      
      // Load Master - This should trigger lazy loading of Details
      // Since TMasterController has the connection with active transaction, 
      // and EntityInitializer will inject this connection into the lazy loader controller (TDetailController),
      // the Details should be visible!
      if LController.Load(LMaster, LMasterId) then
      begin
        Writeln(Format('Master Loaded. Checking Details count: %d', [LMaster.Details.Count]));

        if LMaster.Details.Count > 0 then
          Writeln('SUCCESS: Details loaded correctly via HasMany within Transaction!')
        else
        begin
          Writeln('FAILURE: Details not loaded (Count=0). Lazy load failed to share transaction context.');
          raise Exception.Create('Lazy Loading failed in transaction');
        end;
      end
      else
        raise Exception.Create('Error: Could not load Master for Lazy Load check.');
        
      LController.Commit;
      Writeln('Transaction Committed.');
      
      Writeln('SUCCESS: Master-Detail Transaction Test Passed.');
    except
      on E: Exception do
      begin
        Writeln('ERROR: ' + E.Message);
        try
           LController.Rollback;
           Writeln('Transaction Rolled Back.');
        except
        end;
        raise; // Re-raise to fail test
      end;
    end;
  finally
    LController.Free; // This will close the connection if it owns it or if reference counting drops
    // In our case connection is interface managed.
  end;
end;

end.
