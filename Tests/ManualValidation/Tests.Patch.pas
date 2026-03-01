unit Tests.Patch;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Bridge.MetaData.Types,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Controller.Interfaces,
  Bridge.Base.Controller,
  Tests.Shared;

procedure TestPatchSingleField;
procedure TestPatchMultipleFields;
procedure TestPatchNonExistentEntity;
procedure TestPatchInvalidField;
procedure RunAllPatchTests;

implementation

procedure TestPatchSingleField;
var
  LConn: IConnection;
  LController: TBaseController;
  LPerson: TPerson;
  LId: Integer;
begin
  WriteLn('=== TestPatchSingleField ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  LController := TBaseController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'Original Name';
      LPerson.Age := 30;
      LController.Insert(LPerson);
      LId := LPerson.Id;
      
      WriteLn('  Registro inserido com ID: ', LId);
      
      // Criar novo objeto para representar o PATCH
      // No Horse, o JSON é mapeado para o objeto carregado, 
      // mas aqui vamos testar o UpdatePartial diretamente.
      LPerson.Name := 'Updated Name';
      LPerson.Age := 99; // Este campo NÃO deve ser atualizado no BD se não estiver no array
      
      LController.UpdatePartial(LPerson, ['Name']);
      
      // Carregar novamente para verificar
      LPerson.Name := '';
      LPerson.Age := 0;
      LController.Load(LPerson, LId);
      
      if (LPerson.Name = 'Updated Name') and (LPerson.Age = 30) then
        WriteLn('  ✓ Sucesso: Apenas o campo Name foi atualizado!')
      else
      begin
        WriteLn('  ✗ Erro:');
        WriteLn('    Name esperado: Updated Name, obtido: ', LPerson.Name);
        WriteLn('    Age esperado: 30, obtido: ', LPerson.Age);
      end;
      
    finally
      LPerson.Free;
    end;
  finally
    LController.Free;
  end;
  WriteLn('');
end;

procedure TestPatchMultipleFields;
var
  LConn: IConnection;
  LController: TBaseController;
  LPerson: TPerson;
  LId: Integer;
begin
  WriteLn('=== TestPatchMultipleFields ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  LController := TBaseController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'Original Name';
      LPerson.Age := 30;
      LController.Insert(LPerson);
      LId := LPerson.Id;
      
      LPerson.Name := 'New Name';
      LPerson.Age := 25;
      
      LController.UpdatePartial(LPerson, ['Name', 'Age']);
      
      LPerson.Name := '';
      LPerson.Age := 0;
      LController.Load(LPerson, LId);
      
      if (LPerson.Name = 'New Name') and (LPerson.Age = 25) then
        WriteLn('  ✓ Sucesso: Ambos os campos foram atualizados!')
      else
        WriteLn('  ✗ Erro na atualização de múltiplos campos');
        
    finally
      LPerson.Free;
    end;
  finally
    LController.Free;
  end;
  WriteLn('');
end;

procedure TestPatchNonExistentEntity;
var
  LConn: IConnection;
  LController: TBaseController;
  LPerson: TPerson;
begin
  WriteLn('=== TestPatchNonExistentEntity ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  LController := TBaseController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Id := 999;
      LPerson.Name := 'Nobody';
      
      try
        LController.UpdatePartial(LPerson, ['Name']);
        WriteLn('  ✓ Sucesso: UpdatePartial executado (SQL UPDATE não afeta linhas mas não gera erro de sintaxe)');
      except
        on E: Exception do
          WriteLn('  ✗ Erro inesperado: ', E.Message);
      end;
    finally
      LPerson.Free;
    end;
  finally
    LController.Free;
  end;
  WriteLn('');
end;

procedure TestPatchInvalidField;
var
  LConn: IConnection;
  LController: TBaseController;
  LPerson: TPerson;
  LValidate: TValidate;
begin
  WriteLn('=== TestPatchInvalidField ===');
  
  LConn := CreateTestConnection;
  CreatePersonTable(LConn);
  
  LController := TBaseController.Create(LConn);
  try
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'Test';
      LController.Insert(LPerson);
      
      // O Controller captura exceções internas e retorna em TValidate
      LValidate := LController.UpdatePartial(LPerson, ['InvalidField']);
      
      if not LValidate.Sucess then
        WriteLn('  ✓ Sucesso: Erro detectado corretamente: ', LValidate.Message)
      else
        WriteLn('  ✗ Erro: Deveria ter retornado Sucess = False para campo inválido');
    finally
      LPerson.Free;
    end;
  finally
    LController.Free;
  end;
  WriteLn('');
end;

procedure RunAllPatchTests;
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('  TESTES DE ATUALIZAÇÃO PARCIAL (PATCH)');
  WriteLn('========================================');
  WriteLn('');
  
  TestPatchSingleField;
  TestPatchMultipleFields;
  TestPatchNonExistentEntity;
  TestPatchInvalidField;
  
  WriteLn('========================================');
  WriteLn('  TESTES CONCLUÍDOS');
  WriteLn('========================================');
  WriteLn('');
end;

end.
