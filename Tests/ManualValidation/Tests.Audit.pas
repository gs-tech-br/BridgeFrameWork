unit Tests.Audit;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Variants,
  System.Generics.Collections,
  Bridge.MetaData.Types,
  Bridge.MetaData.Attributes,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Singleton,
  Bridge.Connection.Types,
  Bridge.Controller.Interfaces,
  Bridge.Base.Model,
  Bridge.Base.Controller,
  Bridge.Audit,
  Bridge.Audit.Entity,
  Bridge.Audit.Controller,
  Tests.Shared,
  Data.DB,
  FireDAC.Comp.Client,
  Bridge.Controller.Helper;

type
  [Entity('AUDIT_TEST_ENTITY')]
  [Audit]
  TAuditTestEntity = class
  private
    FId: Integer;
    FDescription: string;
    FValue: Double;
  public
    [Id(False)]
    [Column('ID')]
    property Id: Integer read FId write FId;
    
    [Column('DESCRIPTION', 100)]
    property Description: string read FDescription write FDescription;
    
    [Column('VALUE')]
    property Value: Double read FValue write FValue;
  end;

  procedure RunAuditTest;

implementation

uses
  Bridge.MetaData.Manager,
  Bridge.MetaData.ScriptGenerator;

procedure CreateAuditTable;
var
  LConnection: IConnection;
  LScriptGen: TMetaDataScriptGenerator;
  LSQL: string;
  LQuery: TFDQuery;
begin
  Writeln('  > Starting CreateAuditTable...');
  try
    LConnection := TConnectionSingleton.GetInstance;
    Writeln('  > Singleton connection obtained');
    
    LScriptGen := TMetaDataScriptGenerator.Create(LConnection);
    try
      Writeln('  > Script generator created');
      
      try
        LConnection.Execute('DROP TABLE IF EXISTS AUDIT_TEST_ENTITY');
        LConnection.Execute('DROP TABLE IF EXISTS AUDIT_LOG');
        Writeln('  > Previous tables dropped (if existed)');
      except
        on E: Exception do Writeln('  > Note: Drop failed: ', E.Message);
      end;

      Writeln('  > Generating script for TAuditTestEntity...');
      LSQL := LScriptGen.GenerateCreateTableScript(TAuditTestEntity);
      Writeln('  > Executing SQL: ', LSQL);
      LConnection.Execute(LSQL);
      Writeln('  > TAuditTestEntity table created successfully');

      Writeln('  > Generating script for TAuditLog...');
      LSQL := LScriptGen.GenerateCreateTableScript(TAuditLog);
      Writeln('  > Executing SQL: ', LSQL);
      LConnection.Execute(LSQL);
      Writeln('  > TAuditLog table created successfully');

      // Verificação
      Writeln('  > Verifying table existence:');
      LQuery := LConnection.CreateDataSet('SELECT name FROM sqlite_master WHERE type=''table'' ORDER BY name');
      try
        LQuery.Open;
        while not LQuery.Eof do
        begin
          Writeln('    [FOUND] ', LQuery.Fields[0].AsString);
          LQuery.Next;
        end;
      finally
        LQuery.Free;
      end;

    finally
      LScriptGen.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('  > FATAL ERROR in CreateAuditTable: [', E.ClassName, '] ', E.Message);
      raise;
    end;
  end;
end;

procedure TestInsertAudit;
var
  LController: TBaseController;
  LEntity: TAuditTestEntity;
  LAuditController: TAuditController;
  LAuditList: TObjectList<TAuditLog>;
  LAudit: TAuditLog;
  LQuery: TFDQuery;
  LResult: TValidate;
begin
  Writeln('  > Testing Insert Audit...');
  
  LController := TBaseController.Create(TConnectionSingleton.GetInstance);
  try
    LController.SetAuditUser('USER_1', 'Test User');
    
    LEntity := TAuditTestEntity.Create;
    try
      LEntity.Id := 100;
      LEntity.Description := 'Test Insert Audit';
      LEntity.Value := 123.45;
      
      try
        Writeln('    - Attempting to clear existing data...');
        LResult := LController.Delete(LEntity); 
      except
        on E: Exception do ;
      end;
      
      Writeln('    - Inserting entity...');
      LResult := LController.Insert(LEntity);
      if not LResult.Sucess then
        raise Exception.Create('Insert failed: ' + LResult.Message);
      Writeln('    - Entity inserted');
    
      // Check Audit Log
      LAuditController := TAuditController.Create(TConnectionSingleton.GetInstance);
      try
        LAuditList := TObjectList<TAuditLog>.Create(True);
        try
          LQuery := LAuditController.Find
            .Where('RECORD_ID', VarToStr(LEntity.Id))
            .And_
            .Where('TABLE_NAME', 'AUDIT_TEST_ENTITY')
            .And_
            .Where('ACTION', 'INSERT')
            .Execute;
          try
            LController.LoadFromDataSet<TAuditLog>(LAuditList, LQuery);
          finally
            LQuery.Free;
          end;
          
          if LAuditList.Count = 0 then
            Writeln('    [FAIL] No audit log found for INSERT')
          else
          begin
            LAudit := LAuditList.Last;
            if (LAudit.UserId = 'USER_1') and (LAudit.UserName = 'Test User') then
              Writeln('    [PASS] Audit log found correctly')
            else
              Writeln(Format('    [FAIL] Incorrect User Info. Expected USER_1/Test User, got %s/%s', [LAudit.UserId, LAudit.UserName]));
              
            if LAudit.NewValue.Contains('Test Insert Audit') then
              Writeln('    [PASS] NewValue contains correct data')
            else
              Writeln('    [FAIL] NewValue does not contain expected data');
          end;
        finally
          LAuditList.Free;
        end;
      finally
        LAuditController.Free;
      end;
    finally
      LEntity.Free;
    end;
  finally
    LController.Free;
  end;
end;

procedure TestUpdateAudit;
var
  LController: TBaseController;
  LEntity: TAuditTestEntity;
  LAuditController: TAuditController;
  LAuditList: TObjectList<TAuditLog>;
  LAudit: TAuditLog;
  LQuery: TFDQuery;
  LResult: TValidate;
begin
  Writeln('  > Testing Update Audit...');
  
  LController := TBaseController.Create(TConnectionSingleton.GetInstance);
  try
    LController.SetAuditUser('USER_2', 'Updater');
    
    LEntity := TAuditTestEntity.Create;
    try
      LEntity.Id := 100;
      LEntity.Description := 'Updated Value';
      LEntity.Value := 999.99;
      
      LResult := LController.Update(LEntity);
      if not LResult.Sucess then
        raise Exception.Create('Update failed: ' + LResult.Message);
      
      LAuditController := TAuditController.Create(TConnectionSingleton.GetInstance);
      try
        LAuditList := TObjectList<TAuditLog>.Create(True);
        try
          LQuery := LAuditController.Find
            .Where('RECORD_ID', VarToStr(LEntity.Id))
            .And_
            .Where('TABLE_NAME', 'AUDIT_TEST_ENTITY')
            .And_
            .Where('ACTION', 'UPDATE')
            .Execute;
          try
            LController.LoadFromDataSet<TAuditLog>(LAuditList, LQuery);
          finally
            LQuery.Free;
          end;
          
          if LAuditList.Count = 0 then
            Writeln('    [FAIL] No audit log found for UPDATE')
          else
          begin
            LAudit := LAuditList.Last;
            if LAudit.OldValue.Contains('Test Insert Audit') and LAudit.NewValue.Contains('Updated Value') then
              Writeln('    [PASS] OldValue and NewValue are correct')
            else
              Writeln('    [FAIL] OldValue or NewValue incorrect');
          end;
        finally
          LAuditList.Free;
        end;
      finally
        LAuditController.Free;
      end;
    finally
      LEntity.Free;
    end;
  finally
    LController.Free;
  end;
end;

procedure TestDeleteAudit;
var
  LController: TBaseController;
  LEntity: TAuditTestEntity;
  LAuditController: TAuditController;
  LAuditList: TObjectList<TAuditLog>;
  LAudit: TAuditLog;
  LQuery: TFDQuery;
  LResult: TValidate;
begin
  Writeln('  > Testing Delete Audit...');
  
  LController := TBaseController.Create(TConnectionSingleton.GetInstance);
  try
    LController.SetAuditUser('USER_3', 'Deleter');
    
    LEntity := TAuditTestEntity.Create;
    try
      LEntity.Id := 100;
      
      LResult := LController.Delete(LEntity);
      if not LResult.Sucess then
        raise Exception.Create('Delete failed: ' + LResult.Message);
      
      LAuditController := TAuditController.Create(TConnectionSingleton.GetInstance);
      try
        LAuditList := TObjectList<TAuditLog>.Create(True);
        try
          LQuery := LAuditController.Find
            .Where('RECORD_ID', VarToStr(LEntity.Id))
            .And_
            .Where('TABLE_NAME', 'AUDIT_TEST_ENTITY')
            .And_
            .Where('ACTION', 'DELETE')
            .Execute;
          try
            LController.LoadFromDataSet<TAuditLog>(LAuditList, LQuery);
          finally
            LQuery.Free;
          end;
          
          if LAuditList.Count = 0 then
            Writeln('    [FAIL] No audit log found for DELETE')
          else
          begin
            LAudit := LAuditList.Last;
            if LAudit.OldValue.Contains('Updated Value') then
               Writeln('    [PASS] Captured OldValue before Delete correctly')
            else
               Writeln('    [FAIL] Failed to capture OldValue before Delete');
          end;
        finally
          LAuditList.Free;
        end;
      finally
        LAuditController.Free;
      end;
    finally
      LEntity.Free;
    end;
  finally
    LController.Free;
  end;
end;

procedure RunAuditTest;
begin
  Writeln('');
  Writeln('========================================');
  Writeln('       TESTING AUDIT LOG           ');
  Writeln('========================================');
  
  CreateAuditTable;
  
  TestInsertAudit;
  TestUpdateAudit;
  TestDeleteAudit;
end;

end.
