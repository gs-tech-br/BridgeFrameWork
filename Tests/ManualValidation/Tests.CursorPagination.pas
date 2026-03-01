unit Tests.CursorPagination;

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  Bridge.MetaData.Types,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Controller.Helper,
  Bridge.Base.Controller,
  Tests.Shared;

procedure TestCursorPagination;

implementation

procedure TestCursorPagination;
var
  LController: TBaseController;
  LConnection: IConnection;
  LList: TObjectList<TPerson>;
  LLastItem: TPerson;
  LOrderBy: TArray<TOrderByItem>;
  LResult: TValidate;
  LPageNum: Integer;
  I: Integer;
  LPerson: TPerson;
begin
  WriteLn('=== Teste de Paginação por Cursor ===');
  WriteLn;
  
  // Criar conexão e tabela de teste
  LConnection := CreateTestConnection;
  CreatePersonTable(LConnection);
  LController := CreateTestController(LConnection);
  
  // Inserir dados de teste (20 registros)
  WriteLn('Inserindo 20 registros de teste...');
  for I := 1 to 20 do
  begin
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'Person ' + IntToStr(I);
      LPerson.Age := 20 + I;
      LController.Insert(LPerson);
    finally
      LPerson.Free;
    end;
  end;
  WriteLn('Registros inseridos com sucesso!');
  WriteLn;

  try
    // Configurar ordenação por ID ASC
    SetLength(LOrderBy, 1);
    LOrderBy[0] := TOrderByItem.Create('Id', False); // ASC
    
    LList := TObjectList<TPerson>.Create;
    try
      LPageNum := 1;
      LLastItem := nil;
      
      WriteLn('Carregando páginas (5 registros por página):');
      WriteLn;
      
      repeat
        WriteLn(Format('--- Página %d ---', [LPageNum]));
        
        // Carregar próxima página
        LResult := LController.LoadNext<TPerson>(
          LList,
          LLastItem,
          5,  // Page size
          LOrderBy,
          nil);
        
        if LResult.Sucess then
        begin
          // Exibir apenas os registros NOVOS (últimos 5 adicionados)
          // Como LoadNext não limpa a lista, ela acumula
          for I := Max(0, LList.Count - 5) to LList.Count - 1 do
          begin
            WriteLn(Format('  ID: %d, Nome: %s, Idade: %d', [
              LList[I].Id,
              LList[I].Name,
              LList[I].Age
            ]));
          end;
          
          // Guardar último item como cursor para próxima página
          if LList.Count > 0 then
            LLastItem := LList[LList.Count - 1];
          
          WriteLn;
          Inc(LPageNum);
          
          // Limitar a 4 páginas para o teste
          if LPageNum > 4 then
            Break;
        end
        else
        begin
          WriteLn('  (Sem mais registros)');
          WriteLn('  Erro: ', LResult.Message);
        end;
        
      until not LResult.Sucess;
      
      WriteLn;
      WriteLn(Format('Total de páginas carregadas: %d', [LPageNum - 1]));
      WriteLn(Format('Total de registros na lista: %d', [LList.Count]));
      
    finally
      LList.Free;
    end;
    
  finally
    LController.Free;
  end;
  
  WriteLn;
  WriteLn('=== Teste Concluído ===');
  WriteLn;
end;

end.
