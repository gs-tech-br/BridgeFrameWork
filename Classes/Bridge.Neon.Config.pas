/// <summary>
/// Bridge.Neon.Config - Configuração centralizada do Neon para o BridgeFrameWork
/// </summary>
/// <remarks>
/// Esta unit fornece uma camada de abstração sobre a biblioteca Neon,
/// centralizando a configuração de serialização JSON para APIs REST.
/// </remarks>
unit Bridge.Neon.Config;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.JSON,
  System.Generics.Collections,
  Neon.Core.Persistence,
  Neon.Core.Persistence.JSON,
  Neon.Core.Types;

type
  /// <summary>
  /// Gerenciador de configuração Neon integrado ao Bridge
  /// </summary>
  TBridgeNeon = class
  private
    class var FConfig: INeonConfiguration;
  public
    /// <summary>
    /// Define uma configuração personalizada para o Neon.
    /// Se não for definida, usa o padrão CamelCase.
    /// </summary>
    class procedure SetConfig(AConfig: INeonConfiguration);

    /// <summary>
    /// Retorna a configuração atual do Neon.
    /// </summary>
    class function Config: INeonConfiguration;

    /// <summary>
    /// Serializa um objeto para TJSONValue
    /// </summary>
    class function ObjectToJSON(AObject: TObject): TJSONValue;

    /// <summary>
    /// Serializa um objeto para TJSONObject
    /// </summary>
    class function ObjectToJSONObject(AObject: TObject): TJSONObject;

    /// <summary>
    /// Serializa um objeto para string JSON
    /// </summary>
    class function ObjectToJSONString(AObject: TObject; APretty: Boolean = False): string;

    /// <summary>
    /// Serializa uma lista de objetos para TJSONArray
    /// </summary>
    class function ListToJSONArray<T: class>(AList: TObjectList<T>): TJSONArray;

    /// <summary>
    /// Serializa uma lista de objetos para string JSON
    /// </summary>
    class function ListToJSONString<T: class>(AList: TObjectList<T>): string;

    /// <summary>
    /// Desserializa JSON para um objeto existente
    /// </summary>
    class procedure JSONToObject(AObject: TObject; AJSON: TJSONValue); overload;

    /// <summary>
    /// Desserializa JSON criando uma nova instância do objeto
    /// </summary>
    class function JSONToObject<T: class, constructor>(AJSON: TJSONValue): T; overload;

    /// <summary>
    /// Formata um TJSONValue como string (com ou sem indentação)
    /// </summary>
    class function Print(AJSONValue: TJSONValue; APretty: Boolean = True): string;
  end;

implementation

{ TBridgeNeon }

class procedure TBridgeNeon.SetConfig(AConfig: INeonConfiguration);
begin
  FConfig := AConfig;
end;

class function TBridgeNeon.Config: INeonConfiguration;
begin
  if not Assigned(FConfig) then
  begin
    FConfig := TNeonConfiguration.Default
      .SetMembers([TNeonMembers.Properties])        // Serializa properties, não fields
      .SetVisibility([mvPublic, mvPublished])       // Visibilidade public e published
      .SetMemberCase(TNeonCase.CamelCase)           // camelCase padrão
      .SetUseUTCDate(True)                          // Datas em formato UTC ISO 8601
      .SetIgnoreFieldPrefix(True)                   // Ignora prefixo "F" se serializar fields
      .SetAutoCreate(False)                         // Não criar objetos nil automaticamente
      .SetRaiseExceptions(False);                   // Não lançar exceções, apenas logar erros
  end;
  Result := FConfig;
end;

class function TBridgeNeon.ObjectToJSON(AObject: TObject): TJSONValue;
begin
  Result := TNeon.ObjectToJSON(AObject, Config);
end;

class function TBridgeNeon.ObjectToJSONObject(AObject: TObject): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := TNeon.ObjectToJSON(AObject, Config);
  if LValue is TJSONObject then
    Result := TJSONObject(LValue)
  else
  begin
    LValue.Free;
    Result := TJSONObject.Create;
  end;
end;

class function TBridgeNeon.ObjectToJSONString(AObject: TObject; APretty: Boolean): string;
var
  LValue: TJSONValue;
begin
  LValue := ObjectToJSON(AObject);
  try
    if APretty then
      Result := Print(LValue, True)
    else
      Result := LValue.ToJSON;
  finally
    LValue.Free;
  end;
end;

class function TBridgeNeon.ListToJSONArray<T>(AList: TObjectList<T>): TJSONArray;
var
  LValue: TJSONValue;
begin
  LValue := TNeon.ObjectToJSON(AList, Config);
  if LValue is TJSONArray then
    Result := TJSONArray(LValue)
  else
  begin
    LValue.Free;
    Result := TJSONArray.Create;
  end;
end;

class function TBridgeNeon.ListToJSONString<T>(AList: TObjectList<T>): string;
var
  LArray: TJSONArray;
begin
  LArray := ListToJSONArray<T>(AList);
  try
    Result := LArray.ToJSON;
  finally
    LArray.Free;
  end;
end;

class procedure TBridgeNeon.JSONToObject(AObject: TObject; AJSON: TJSONValue);
begin
  TNeon.JSONToObject(AObject, AJSON, Config);
end;

class function TBridgeNeon.JSONToObject<T>(AJSON: TJSONValue): T;
begin
  Result := T.Create;
  try
    TNeon.JSONToObject(Result, AJSON, Config);
  except
    Result.Free;
    raise;
  end;
end;

class function TBridgeNeon.Print(AJSONValue: TJSONValue; APretty: Boolean): string;
begin
  Result := TNeon.Print(AJSONValue, APretty);
end;

end.
