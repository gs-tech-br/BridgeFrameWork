unit Tests.CursorTieBreaking;

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  FireDAC.Stan.Param,
  Bridge.MetaData.Types,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Controller.Helper,
  Bridge.Base.Controller,
  Bridge.MetaData.Attributes,
  Tests.Shared;

type
  // Test entity with CompositeKey
  [Entity('PRODUCT')]
  TProduct = class
  private
    [CompositeKey]
    [Column('COMPANY_ID')]
    FCompanyId: Integer;
    
    [Id(True)]
    [Column('ID')]
    FId: Integer;
    
    [Column('NAME')]
    FName: String;
    
    [Column('PRICE')]
    FPrice: Double;
  public
    property CompanyId: Integer read FCompanyId write FCompanyId;
    property Id: Integer read FId write FId;
    property Name: String read FName write FName;
    property Price: Double read FPrice write FPrice;
  end;

procedure TestCursorTieBreaking;

implementation

procedure CreateProductTable(AConnection: IConnection);
begin
  AConnection.Execute('DROP TABLE IF EXISTS PRODUCT');
  AConnection.Execute(
    'CREATE TABLE PRODUCT (' +
    '  COMPANY_ID INTEGER NOT NULL, ' +
    '  ID INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    '  NAME TEXT NOT NULL, ' +
    '  PRICE REAL NOT NULL' +
    ')');
end;

procedure TestCursorTieBreaking;
var
  LController: TBaseController;
  LConnection: IConnection;
  LList: TObjectList<TProduct>;
  LLastItem: TProduct;
  LOrderBy: TArray<TOrderByItem>;
  LResult: TValidate;
  LPageNum: Integer;
  I: Integer;
  LProduct: TProduct;
begin
  WriteLn('=== Teste de Desempate Automático (CompositeKey + PrimaryKey) ===');
  WriteLn;
  
  // Criar conexão e tabela de teste
  LConnection := CreateTestConnection;
  CreateProductTable(LConnection);
  LController := CreateTestController(LConnection);
  
  // Inserir dados de teste com preços duplicados para forçar desempate
  WriteLn('Inserindo 15 produtos com preços duplicados...');
  for I := 1 to 15 do
  begin
    LProduct := TProduct.Create;
    try
      LProduct.CompanyId := ((I - 1) div 5) + 1; // 3 empresas: 1, 2, 3
      LProduct.Name := 'Product ' + IntToStr(I);
      LProduct.Price := 10.0 + ((I - 1) mod 3) * 5.0; // Preços: 10, 15, 20 (repetidos)
      LController.Insert(LProduct);
    finally
      LProduct.Free;
    end;
  end;
  WriteLn('Produtos inseridos com sucesso!');
  WriteLn;

  try
    // Ordenar APENAS por Price (sem especificar CompositeKey ou PrimaryKey)
    // O sistema deve adicionar automaticamente CompanyId e Id para desempate
    SetLength(LOrderBy, 1);
    LOrderBy[0] := TOrderByItem.Create('Price', False); // ASC
    
    WriteLn('Ordenação especificada: Price ASC');
    WriteLn('Esperado: Sistema adiciona automaticamente CompanyId e Id para desempate único');
    WriteLn;
    
    LList := TObjectList<TProduct>.Create;
    try
      LPageNum := 1;
      LLastItem := nil;
      
      WriteLn('Carregando páginas (5 registros por página):');
      WriteLn;
      
      repeat
        WriteLn(Format('--- Página %d ---', [LPageNum]));
        
        // Carregar próxima página
        LResult := LController.LoadNext<TProduct>(
          LList,
          LLastItem,
          5,  // Page size
          LOrderBy,
          nil);
        
        if LResult.Sucess then
        begin
          // Exibir apenas os registros NOVOS (últimos 5 adicionados)
          for I := Max(0, LList.Count - 5) to LList.Count - 1 do
          begin
            WriteLn(Format('  CompanyId: %d, ID: %d, Nome: %s, Preço: %.2f', [
              LList[I].CompanyId,
              LList[I].Id,
              LList[I].Name,
              LList[I].Price
            ]));
          end;
          
          // Guardar último item como cursor para próxima página
          if LList.Count > 0 then
            LLastItem := LList[LList.Count - 1];
          
          WriteLn;
          Inc(LPageNum);
          
          // Limitar a 3 páginas para o teste
          if LPageNum > 3 then
            Break;
        end
        else
        begin
          WriteLn('  (Sem mais registros)');
        end;
        
      until not LResult.Sucess;
      
      WriteLn;
      WriteLn(Format('Total de páginas carregadas: %d', [LPageNum - 1]));
      WriteLn(Format('Total de registros na lista: %d', [LList.Count]));
      WriteLn;
      WriteLn('✅ Se os registros estão ordenados por Price, depois CompanyId, depois Id,');
      WriteLn('   então o desempate automático está funcionando corretamente!');
      
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
