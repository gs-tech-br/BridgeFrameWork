unit Tests.JsonIgnore;

interface

procedure RunJsonIgnoreTest;

implementation

uses
  System.SysUtils,
  System.JSON,
  Bridge.Lazy,
  Bridge.Neon.Config,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager;

type
  [Entity('USUARIO')]
  TUsuario = class
  private
    [Id(True)]
    [Column('ID')]
    FId: Integer;

    [Column('NOME')]
    FNome: string;

    [Column('SENHA')]
    [JsonIgnore(True, False)]
    FSenha: string;
  public
    property Id: Integer read FId write FId;
    property Nome: string read FNome write FNome;
    property Senha: string read FSenha write FSenha;
  end;

  [Entity('USUARIO_PROPERTY_IGNORE')]
  TUsuarioPropertyIgnore = class
  private
    [Id(True)]
    [Column('ID')]
    FId: Integer;

    [Column('TOKEN')]
    FToken: string;
  public
    property Id: Integer read FId write FId;

    [JsonIgnore(True, False)]
    property Token: string read FToken write FToken;
  end;

  [Entity('ESTOQUE_MOVIMENTO')]
  TEstoqueMovimento = class
  private
    [Id(True)]
    [Column('ID')]
    FId: Integer;

    [Column('USUARIO_ID')]
    FUsuarioId: Integer;

    [BelongsTo('USUARIO_ID')]
    FUsuario: TLazy<TUsuario>;
  public
    constructor Create;
    destructor Destroy; override;

    property Id: Integer read FId write FId;
    property UsuarioId: Integer read FUsuarioId write FUsuarioId;
    property Usuario: TLazy<TUsuario> read FUsuario;
  end;

procedure AssertCondition(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function MetaDataContainsColumn(const AColumnName: string): Boolean;
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
begin
  Result := False;
  LMetaData := TMetaDataManager.Instance.GetMetaData(TUsuario);
  for LPropMeta in LMetaData.AllProperties do
  begin
    if SameText(LPropMeta.ColumnName, AColumnName) then
      Exit(True);
  end;
end;

procedure TestORMKeepsJsonIgnoredField;
begin
  AssertCondition(MetaDataContainsColumn('SENHA'),
    '[JsonIgnore] should not remove SENHA from ORM metadata');
  Writeln('SUCCESS: SENHA remains mapped by ORM metadata');
end;

procedure TestSerializeSkipsJsonIgnoredField;
var
  LUsuario: TUsuario;
  LJSON: TJSONObject;
begin
  LUsuario := TUsuario.Create;
  try
    LUsuario.Id := 1;
    LUsuario.Nome := 'Joao';
    LUsuario.Senha := 'hash-secret';

    LJSON := TBridgeNeon.ObjectToJSONObject(LUsuario);
    try
      AssertCondition(Assigned(LJSON.GetValue('id')), 'Serialized JSON should contain id');
      AssertCondition(Assigned(LJSON.GetValue('nome')), 'Serialized JSON should contain nome');
      AssertCondition(not Assigned(LJSON.GetValue('senha')), 'Serialized JSON must not contain senha');
      Writeln('SUCCESS: ObjectToJSONObject hides senha');
    finally
      LJSON.Free;
    end;
  finally
    LUsuario.Free;
  end;
end;

procedure TestDeserializeReadsJsonIgnoredFieldWhenAllowed;
var
  LUsuario: TUsuario;
  LJSON: TJSONValue;
begin
  LJSON := TJSONObject.ParseJSONValue('{"id":2,"nome":"Maria","senha":"hash-in"}');
  try
    AssertCondition(Assigned(LJSON), 'Setup failure: JSON payload was not parsed');

    LUsuario := TUsuario.Create;
    try
      TBridgeNeon.JSONToObject(LUsuario, LJSON);
      AssertCondition(LUsuario.Id = 2, 'JSONToObject should populate id');
      AssertCondition(LUsuario.Nome = 'Maria', 'JSONToObject should populate nome');
      AssertCondition(LUsuario.Senha = 'hash-in',
        'JSONToObject should populate senha when JsonIgnore ignores only serialization');
      Writeln('SUCCESS: JSONToObject reads senha when deserialize is allowed');
    finally
      LUsuario.Free;
    end;
  finally
    LJSON.Free;
  end;
end;

procedure TestPropertyAttributeIsRespected;
var
  LUsuario: TUsuarioPropertyIgnore;
  LJSON: TJSONObject;
begin
  LUsuario := TUsuarioPropertyIgnore.Create;
  try
    LUsuario.Id := 3;
    LUsuario.Token := 'property-secret';

    LJSON := TBridgeNeon.ObjectToJSONObject(LUsuario);
    try
      AssertCondition(Assigned(LJSON.GetValue('id')), 'Serialized JSON should contain id');
      AssertCondition(not Assigned(LJSON.GetValue('token')),
        'JsonIgnore on the property should hide token');
      Writeln('SUCCESS: JsonIgnore on property is respected');
    finally
      LJSON.Free;
    end;
  finally
    LUsuario.Free;
  end;
end;

procedure TestLazySerializationSkipsNestedSecret;
var
  LMovimento: TEstoqueMovimento;
  LUsuario: TUsuario;
  LJSON: TJSONObject;
  LUsuarioJSONValue: TJSONValue;
  LUsuarioJSON: TJSONObject;
begin
  LMovimento := TEstoqueMovimento.Create;
  try
    LUsuario := TUsuario.Create;
    LUsuario.Id := 4;
    LUsuario.Nome := 'Usuario lazy';
    LUsuario.Senha := 'lazy-secret';

    LMovimento.Id := 10;
    LMovimento.UsuarioId := LUsuario.Id;
    LMovimento.Usuario.SetValue(LUsuario);

    LJSON := TBridgeNeon.ObjectToJSONObject(LMovimento);
    try
      LUsuarioJSONValue := LJSON.GetValue('usuario');
      AssertCondition(LUsuarioJSONValue is TJSONObject, 'Lazy usuario should be serialized as an object');

      LUsuarioJSON := TJSONObject(LUsuarioJSONValue);
      AssertCondition(Assigned(LUsuarioJSON.GetValue('nome')), 'Nested usuario should contain nome');
      AssertCondition(not Assigned(LUsuarioJSON.GetValue('senha')),
        'Nested lazy usuario must not expose senha');
      Writeln('SUCCESS: Lazy usuario serialization hides senha');
    finally
      LJSON.Free;
    end;
  finally
    LMovimento.Free;
  end;
end;

procedure RunJsonIgnoreTest;
begin
  Writeln('--------------------------------------------------');
  Writeln('TEST: JsonIgnore attribute');
  Writeln('--------------------------------------------------');

  TestORMKeepsJsonIgnoredField;
  TestSerializeSkipsJsonIgnoredField;
  TestDeserializeReadsJsonIgnoredFieldWhenAllowed;
  TestPropertyAttributeIsRespected;
  TestLazySerializationSkipsNestedSecret;

  Writeln('--------------------------------------------------');
end;

{ TEstoqueMovimento }

constructor TEstoqueMovimento.Create;
begin
  inherited Create;
  FUsuario := TLazy<TUsuario>.Create;
end;

destructor TEstoqueMovimento.Destroy;
begin
  FUsuario.Free;
  inherited;
end;

end.
