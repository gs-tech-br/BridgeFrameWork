unit Tests.Async;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Bridge.MetaData.Types,
  Bridge.Async.Controller,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Tests.Shared;

procedure TestSaveAsyncInsert;
procedure TestSaveAsyncUpdate;
procedure TestDeleteAsync;
procedure TestRestoreAsync;
procedure TestFindAsync;
procedure RunAllAsyncTests;

implementation

procedure TestSaveAsyncInsert;
var
  LConn: IConnection;
  LController: TAsyncController;
  LPerson: TPerson;
  LCompleted: Boolean;
  LGeneratedId: Integer;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  WriteLn('=== TestSaveAsyncInsert ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  // Configurar callbacks para usar a mesma conexão de teste
  TAsyncController.OnAcquireConnection := function: IConnection
    begin
      Result := LConn;
    end;
  TAsyncController.OnReleaseConnection := procedure(AConn: IConnection)
    begin
      // Não liberar - será liberado no finally
    end;
  
  LController := TAsyncController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'John Doe';
      LPerson.Age := 30;
      
      LCompleted := False;
      LSuccess := False;
      LErrorMsg := '';
      LGeneratedId := 0;
      
      LController.SaveAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LSuccess := AResult.Sucess;
          if not LSuccess then
            LErrorMsg := AResult.Message;
          LCompleted := True;
        end,
        procedure(AError: string)
        begin
          LErrorMsg := AError;
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
      if LSuccess then
        LGeneratedId := LPerson.Id;
      
    finally
      LPerson.Free;
    end;
    
    if LSuccess then
      WriteLn('  ✓ Insert bem-sucedido! ID gerado: ', LGeneratedId)
    else if LErrorMsg <> '' then
      WriteLn('  ✗ Erro: ', LErrorMsg);
      
  finally
    LController.Free;
    TAsyncController.OnAcquireConnection := nil;
    TAsyncController.OnReleaseConnection := nil;
  end;
  
  WriteLn('');
end;

procedure TestSaveAsyncUpdate;
var
  LConn: IConnection;
  LController: TAsyncController;
  LPerson: TPerson;
  LCompleted: Boolean;
  LInsertedId: Integer;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  WriteLn('=== TestSaveAsyncUpdate ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  TAsyncController.OnAcquireConnection := function: IConnection
    begin
      Result := LConn;
    end;
  TAsyncController.OnReleaseConnection := procedure(AConn: IConnection)
    begin
    end;
  
  LController := TAsyncController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'Jane Doe';
      LPerson.Age := 25;
      
      LCompleted := False;
      LController.SaveAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
      LInsertedId := LPerson.Id;
      WriteLn('  Registro inserido com ID: ', LInsertedId);
      
      LPerson.Name := 'Jane Smith';
      LPerson.Age := 26;
      
      LCompleted := False;
      LSuccess := False;
      LErrorMsg := '';
      
      LController.SaveAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LSuccess := AResult.Sucess;
          if not LSuccess then
            LErrorMsg := AResult.Message;
          LCompleted := True;
        end,
        procedure(AError: string)
        begin
          LErrorMsg := AError;
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
    finally
      LPerson.Free;
    end;
    
    if LSuccess then
      WriteLn('  ✓ Update bem-sucedido!')
    else if LErrorMsg <> '' then
      WriteLn('  ✗ Erro: ', LErrorMsg);
      
  finally
    LController.Free;
    TAsyncController.OnAcquireConnection := nil;
    TAsyncController.OnReleaseConnection := nil;
  end;
  
  WriteLn('');
end;

procedure TestDeleteAsync;
var
  LConn: IConnection;
  LController: TAsyncController;
  LPerson: TPerson;
  LCompleted: Boolean;
  LInsertedId: Integer;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  WriteLn('=== TestDeleteAsync ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  TAsyncController.OnAcquireConnection := function: IConnection
    begin
      Result := LConn;
    end;
  TAsyncController.OnReleaseConnection := procedure(AConn: IConnection)
    begin
    end;
  
  LController := TAsyncController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'To Delete';
      LPerson.Age := 99;
      
      LCompleted := False;
      LController.SaveAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
      LInsertedId := LPerson.Id;
      WriteLn('  Registro inserido com ID: ', LInsertedId);
      
      LCompleted := False;
      LSuccess := False;
      LErrorMsg := '';
      
      LController.DeleteAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LSuccess := AResult.Sucess;
          if not LSuccess then
            LErrorMsg := AResult.Message;
          LCompleted := True;
        end,
        procedure(AError: string)
        begin
          LErrorMsg := AError;
          LCompleted := True;
        end);

      while not LCompleted do
        Sleep(50);
      
    finally
      LPerson.Free;
    end;
    
    if LSuccess then
      WriteLn('  ✓ Delete bem-sucedido!')
    else if LErrorMsg <> '' then
      WriteLn('  ✗ Erro: ', LErrorMsg);
      
  finally
    LController.Free;
    TAsyncController.OnAcquireConnection := nil;
    TAsyncController.OnReleaseConnection := nil;
  end;
  
  WriteLn('');
end;

procedure TestRestoreAsync;
var
  LConn: IConnection;
  LController: TAsyncController;
  LPerson: TSoftDeletePerson;
  LCompleted: Boolean;
  LInsertedId: Integer;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  WriteLn('=== TestRestoreAsync ===');
  
  LConn := CreateTestConnection;
  CreateSoftDeletePersonTable(LConn);
  
  TAsyncController.OnAcquireConnection := function: IConnection
    begin
      Result := LConn;
    end;
  TAsyncController.OnReleaseConnection := procedure(AConn: IConnection)
    begin
    end;
  
  LController := TAsyncController.Create(LConn);
  try
    LPerson := TSoftDeletePerson.Create;
    try
      LPerson.Name := 'To Restore';
      
      LCompleted := False;
      LController.SaveAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
      LInsertedId := LPerson.Id;
      WriteLn('  Registro inserido com ID: ', LInsertedId);
      
      LCompleted := False;
      LController.DeleteAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
      WriteLn('  Registro soft-deleted');
      
      LCompleted := False;
      LSuccess := False;
      LErrorMsg := '';
      
      LController.RestoreAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LSuccess := AResult.Sucess;
          if not LSuccess then
            LErrorMsg := AResult.Message;
          LCompleted := True;
        end,
        procedure(AError: string)
        begin
          LErrorMsg := AError;
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
    finally
      LPerson.Free;
    end;
    
    if LSuccess then
      WriteLn('  ✓ Restore bem-sucedido!')
    else if LErrorMsg <> '' then
      WriteLn('  ✗ Erro: ', LErrorMsg);
      
  finally
    LController.Free;
    TAsyncController.OnAcquireConnection := nil;
    TAsyncController.OnReleaseConnection := nil;
  end;
  
  WriteLn('');
end;

procedure TestFindAsync;
var
  LConn: IConnection;
  LController: TAsyncController;
  LPerson: TPerson;
  LCompleted: Boolean;
  LInsertedId: Integer;
  LFoundId: Integer;
  LFoundName: string;
  LFoundAge: Integer;
  LWasFound: Boolean;
  LErrorMsg: string;
begin
  WriteLn('=== TestFindAsync ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  TAsyncController.OnAcquireConnection := function: IConnection
    begin
      Result := LConn;
    end;
  TAsyncController.OnReleaseConnection := procedure(AConn: IConnection)
    begin
    end;
  
  LController := TAsyncController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'To Find';
      LPerson.Age := 42;
      
      LCompleted := False;
      LController.SaveAsync(LPerson,
        procedure(AResult: TValidate)
        begin
          LCompleted := True;
        end);
      
      while not LCompleted do
        Sleep(50);
      
      LInsertedId := LPerson.Id;
      WriteLn('  Registro inserido com ID: ', LInsertedId);
      
    finally
      LPerson.Free;
    end;
    
    LCompleted := False;
    LWasFound := False;
    LErrorMsg := '';
    LFoundId := 0;
    LFoundName := '';
    LFoundAge := 0;
    
    LController.FindAsync<TPerson>(LInsertedId,
      procedure(APerson: TPerson)
      begin
        if Assigned(APerson) then
        begin
          LWasFound := True;
          LFoundId := APerson.Id;
          LFoundName := APerson.Name;
          LFoundAge := APerson.Age;
          APerson.Free;
        end;
        LCompleted := True;
      end,
      procedure(AError: string)
      begin
        LErrorMsg := AError;
        LCompleted := True;
      end);
    
    while not LCompleted do
      Sleep(50);
    
    if LWasFound then
    begin
      WriteLn('  ✓ Registro encontrado!');
      WriteLn('    ID: ', LFoundId);
      WriteLn('    Name: ', LFoundName);
      WriteLn('    Age: ', LFoundAge);
    end
    else if LErrorMsg <> '' then
      WriteLn('  ✗ Erro: ', LErrorMsg)
    else
      WriteLn('  ✗ Registro não encontrado');
      
  finally
    LController.Free;
    TAsyncController.OnAcquireConnection := nil;
    TAsyncController.OnReleaseConnection := nil;
  end;
  
  WriteLn('');
end;

procedure RunAllAsyncTests;
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('  TESTES DE OPERAÇÕES ASSÍNCRONAS');
  WriteLn('========================================');
  WriteLn('');
  
  TestSaveAsyncInsert;
  TestSaveAsyncUpdate;
  TestDeleteAsync;
  TestRestoreAsync;
  TestFindAsync;
  
  WriteLn('========================================');
  WriteLn('  TESTES CONCLUÍDOS');
  WriteLn('========================================');
  WriteLn('');
end;

end.
