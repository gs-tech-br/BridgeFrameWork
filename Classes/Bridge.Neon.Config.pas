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

uses
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager;

const
  BRIDGE_NEON_MAX_RELATION_DEPTH = 1;

threadvar
  GBridgeNeonRelationDepth: Integer;

type
  TBridgeLazySerializer = class(TCustomSerializer)
  protected
    class function CanHandle(AType: PTypeInfo): Boolean; override;
  public
    function Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject; AContext: ISerializerContext): TJSONValue; override;
    function Deserialize(AValue: TJSONValue; const AData: TValue; ANeonObject: TNeonRttiObject; AContext: IDeserializerContext): TValue; override;
  end;

  TBridgeLazyListSerializer = class(TCustomSerializer)
  protected
    class function CanHandle(AType: PTypeInfo): Boolean; override;
  public
    function Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject; AContext: ISerializerContext): TJSONValue; override;
    function Deserialize(AValue: TJSONValue; const AData: TValue; ANeonObject: TNeonRttiObject; AContext: IDeserializerContext): TValue; override;
  end;

  TBridgeEntitySerializer = class(TCustomSerializer)
  protected
    class function CanHandle(AType: PTypeInfo): Boolean; override;
  public
    function Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject; AContext: ISerializerContext): TJSONValue; override;
    function Deserialize(AValue: TJSONValue; const AData: TValue; ANeonObject: TNeonRttiObject; AContext: IDeserializerContext): TValue; override;
  end;

function BridgeTypeName(AType: PTypeInfo): string;
begin
  if Assigned(AType) then
    Result := GetTypeName(AType)
  else
    Result := EmptyStr;
end;

function BridgeIsLazyType(AType: PTypeInfo): Boolean;
var
  LTypeName: string;
begin
  LTypeName := BridgeTypeName(AType);
  Result := LTypeName.Contains('TLazy<') and not LTypeName.Contains('TLazyList<');
end;

function BridgeIsLazyListType(AType: PTypeInfo): Boolean;
begin
  Result := BridgeTypeName(AType).Contains('TLazyList<');
end;

function BridgeIsEntityType(AType: PTypeInfo): Boolean;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LAttr: TCustomAttribute;
begin
  Result := False;
  if not Assigned(AType) then
    Exit;

  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AType);
    if not Assigned(LType) or not LType.IsInstance then
      Exit;

    for LAttr in LType.GetAttributes do
    begin
      if LAttr is EntityAttribute then
        Exit(True);
    end;
  finally
    LContext.Free;
  end;
end;

function BridgeFieldToJSONName(const AFieldName: string): string;
var
  LName: string;
begin
  LName := AFieldName;
  if LName.StartsWith('F') and (LName.Length > 1) then
    LName := LName.Substring(1);

  Result := TCaseAlgorithm.PascalToCamel(LName);
end;

function BridgeFieldIgnored(AField: TRttiField; AType: TRttiType): Boolean;
var
  LAttr: TCustomAttribute;
  LProp: TRttiProperty;
  LPropName: string;
begin
  Result := False;

  for LAttr in AField.GetAttributes do
  begin
    if LAttr is IgnoreAttribute then
      Exit(True);
  end;

  if not AField.Name.StartsWith('F') then
    Exit;

  LPropName := AField.Name.Substring(1);
  LProp := AType.GetProperty(LPropName);
  if Assigned(LProp) then
  begin
    for LAttr in LProp.GetAttributes do
    begin
      if LAttr is IgnoreAttribute then
        Exit(True);
    end;
  end;
end;

function BridgeFieldIsRelation(AField: TRttiField): Boolean;
var
  LAttr: TCustomAttribute;
begin
  Result := False;
  for LAttr in AField.GetAttributes do
  begin
    if (LAttr is BelongsToAttribute) or (LAttr is HasManyAttribute) then
      Exit(True);
  end;
end;

function BridgeObjectToValue(AObject: TObject): TValue;
var
  LContext: TRttiContext;
  LType: TRttiType;
begin
  Result := TValue.Empty;
  if not Assigned(AObject) then
    Exit;

  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AObject.ClassType);
    if Assigned(LType) then
      TValue.Make(@AObject, LType.Handle, Result)
    else
      Result := TValue.From<TObject>(AObject);
  finally
    LContext.Free;
  end;
end;

{ TBridgeLazySerializer }

class function TBridgeLazySerializer.CanHandle(AType: PTypeInfo): Boolean;
begin
  Result := BridgeIsLazyType(AType);
end;

function TBridgeLazySerializer.Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject;
  AContext: ISerializerContext): TJSONValue;
var
  LObject: TObject;
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LLazyValue: TValue;
begin
  LObject := AValue.AsObject;
  if not Assigned(LObject) then
    Exit(TJSONNull.Create);

  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(LObject.ClassType);
    LProp := LType.GetProperty('Value');
    if not Assigned(LProp) then
      Exit(TJSONNull.Create);

    LLazyValue := LProp.GetValue(LObject);
    if LLazyValue.IsObject and (LLazyValue.AsObject = nil) then
      Exit(TJSONNull.Create);

    Result := AContext.WriteDataMember(LLazyValue, True);
    if not Assigned(Result) then
      Result := TJSONNull.Create;
  finally
    LContext.Free;
  end;
end;

function TBridgeLazySerializer.Deserialize(AValue: TJSONValue; const AData: TValue;
  ANeonObject: TNeonRttiObject; AContext: IDeserializerContext): TValue;
begin
  Result := AData;
end;

{ TBridgeLazyListSerializer }

class function TBridgeLazyListSerializer.CanHandle(AType: PTypeInfo): Boolean;
begin
  Result := BridgeIsLazyListType(AType);
end;

function TBridgeLazyListSerializer.Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject;
  AContext: ISerializerContext): TJSONValue;
var
  LObject: TObject;
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LListValue: TValue;
begin
  LObject := AValue.AsObject;
  if not Assigned(LObject) then
    Exit(TJSONArray.Create);

  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(LObject.ClassType);
    LProp := LType.GetProperty('List');
    if not Assigned(LProp) then
      Exit(TJSONArray.Create);

    LListValue := LProp.GetValue(LObject);
    Result := AContext.WriteDataMember(LListValue, True);
    if not Assigned(Result) then
      Result := TJSONArray.Create;
  finally
    LContext.Free;
  end;
end;

function TBridgeLazyListSerializer.Deserialize(AValue: TJSONValue; const AData: TValue;
  ANeonObject: TNeonRttiObject; AContext: IDeserializerContext): TValue;
begin
  Result := AData;
end;

{ TBridgeEntitySerializer }

class function TBridgeEntitySerializer.CanHandle(AType: PTypeInfo): Boolean;
begin
  Result := BridgeIsEntityType(AType);
end;

function TBridgeEntitySerializer.Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject;
  AContext: ISerializerContext): TJSONValue;
var
  LObject: TObject;
  LJSON: TJSONObject;
  LJSONValue: TJSONValue;
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
  LFieldValue: TValue;
  LCurrentDepth: Integer;
begin
  LObject := AValue.AsObject;
  if not Assigned(LObject) then
    Exit(TJSONNull.Create);

  LJSON := TJSONObject.Create;
  Result := LJSON;

  LCurrentDepth := GBridgeNeonRelationDepth;
  Inc(GBridgeNeonRelationDepth);
  try
    LMetaData := TMetaDataManager.Instance.GetMetaData(LObject);
    for LPropMeta in LMetaData.AllProperties do
    begin
      if not Assigned(LPropMeta.RttiField) then
        Continue;

      LFieldValue := LPropMeta.RttiField.GetValue(LObject);
      LJSONValue := AContext.WriteDataMember(LFieldValue, True);
      if Assigned(LJSONValue) then
        LJSON.AddPair(BridgeFieldToJSONName(LPropMeta.RttiField.Name), LJSONValue);
    end;

    if LCurrentDepth >= BRIDGE_NEON_MAX_RELATION_DEPTH then
      Exit;

    LContext := TRttiContext.Create;
    try
      LType := LContext.GetType(LObject.ClassType);
      for LField in LType.GetFields do
      begin
        if BridgeFieldIgnored(LField, LType) or not BridgeFieldIsRelation(LField) then
          Continue;

        LFieldValue := LField.GetValue(LObject);
        LJSONValue := AContext.WriteDataMember(LFieldValue, True);
        if Assigned(LJSONValue) then
          LJSON.AddPair(BridgeFieldToJSONName(LField.Name), LJSONValue);
      end;
    finally
      LContext.Free;
    end;
  finally
    Dec(GBridgeNeonRelationDepth);
  end;
end;

function TBridgeEntitySerializer.Deserialize(AValue: TJSONValue; const AData: TValue;
  ANeonObject: TNeonRttiObject; AContext: IDeserializerContext): TValue;
var
  LObject: TObject;
  LJSONObject: TJSONObject;
  LJSONValue: TJSONValue;
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LCurrentValue: TValue;
  LFieldValue: TValue;
begin
  Result := AData;
  if not (AValue is TJSONObject) or not AData.IsObject then
    Exit;

  LObject := AData.AsObject;
  if not Assigned(LObject) then
    Exit;

  LJSONObject := TJSONObject(AValue);
  LMetaData := TMetaDataManager.Instance.GetMetaData(LObject);

  for LPropMeta in LMetaData.AllProperties do
  begin
    if not Assigned(LPropMeta.RttiField) then
      Continue;

    LJSONValue := LJSONObject.GetValue(BridgeFieldToJSONName(LPropMeta.RttiField.Name));
    if not Assigned(LJSONValue) then
      Continue;

    LCurrentValue := LPropMeta.RttiField.GetValue(LObject);
    LFieldValue := AContext.ReadDataMember(LJSONValue, LPropMeta.RttiField.FieldType, LCurrentValue, True);
    if not LFieldValue.IsEmpty then
      LPropMeta.RttiField.SetValue(LObject, LFieldValue);
  end;

  Result := AData;
end;

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
      .SetMembers([TNeonMembers.Fields])            // Serializa fields para respeitar o padrão ORM do Bridge
      .SetVisibility([mvPrivate, mvProtected, mvPublic, mvPublished])
      .SetMemberCase(TNeonCase.CamelCase)           // camelCase padrão
      .SetUseUTCDate(True)                          // Datas em formato UTC ISO 8601
      .SetIgnoreFieldPrefix(True)                   // Ignora prefixo "F" se serializar fields
      .SetAutoCreate(False)                         // Não criar objetos nil automaticamente
      .SetRaiseExceptions(False)                    // Não lançar exceções, apenas logar erros
      .RegisterSerializer(TBridgeLazyListSerializer)
      .RegisterSerializer(TBridgeLazySerializer)
      .RegisterSerializer(TBridgeEntitySerializer);
  end;
  Result := FConfig;
end;

class function TBridgeNeon.ObjectToJSON(AObject: TObject): TJSONValue;
var
  LValue: TValue;
begin
  if not Assigned(AObject) then
    Exit(TNeon.ObjectToJSON(AObject, Config));

  LValue := BridgeObjectToValue(AObject);
  Result := TNeon.ValueToJSON(LValue, Config);
end;

class function TBridgeNeon.ObjectToJSONObject(AObject: TObject): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := ObjectToJSON(AObject);
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
  LItem: T;
begin
  Result := TJSONArray.Create;
  if not Assigned(AList) then
    Exit;

  for LItem in AList do
  begin
    Result.AddElement(ObjectToJSON(TObject(LItem)));
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
