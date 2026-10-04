unit Bridge.Tests.ColumnTypes;

// Column type recognition in the ORM: metadata validation, dataset mapping by
// property type, SQL generation and JSON for Variant and [NullIfZero] columns.

interface

uses
  System.Variants,
  DUnitX.TestFramework,
  Bridge.MetaData.Attributes;

type
  [Entity('ORM_TYPES')]
  TOrmTypes = class
  private
    [Id(True)]
    [Column('ID', 0, False)]
    FId: Integer;
    [Column('QTY')]
    FQty: Integer;
    [Column('BIG')]
    FBig: Int64;
    [Column('AMOUNT')]
    FAmount: Double;
    [Column('ACTIVE')]
    FActive: Boolean;
    [Column('NAME', 50)]
    FName: string;
    [Column('CREATED_AT')]
    FCreatedAt: TDateTime;
    [Column('PRICE')]
    FPrice: Currency;
    [Column('REF', 0, True)]
    FRef: Variant;
    [Column('ID_PARENT', 0, True)]
    [NullIfZero]
    FIdParent: Integer;
    [Column('ID_BIG_PARENT', 0, True)]
    [NullIfZero]
    FIdBigParent: Int64;
    // No [Column]: internal state, outside the mapping.
    FState: Variant;
    FCounter: Byte;
  public
    constructor Create;
    property Id: Integer read FId write FId;
    property Qty: Integer read FQty write FQty;
    property Big: Int64 read FBig write FBig;
    property Amount: Double read FAmount write FAmount;
    property Active: Boolean read FActive write FActive;
    property Name: string read FName write FName;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property Price: Currency read FPrice write FPrice;
    property Ref: Variant read FRef write FRef;
    property IdParent: Integer read FIdParent write FIdParent;
    property IdBigParent: Int64 read FIdBigParent write FIdBigParent;
    property State: Variant read FState write FState;
    property Counter: Byte read FCounter write FCounter;
  end;

  [Entity('ORM_BYTE_COLUMN')]
  TOrmByteColumn = class
  private
    [Id(True)]
    [Column('ID', 0, False)]
    FId: Integer;
    [Column('CODE')]
    FCode: Byte;
  public
    property Id: Integer read FId write FId;
    property Code: Byte read FCode write FCode;
  end;

  [Entity('ORM_NULL_IF_ZERO_DOUBLE')]
  TOrmNullIfZeroDouble = class
  private
    [Id(True)]
    [Column('ID', 0, False)]
    FId: Integer;
    [Column('PRICE', 0, True)]
    [NullIfZero]
    FPrice: Double;
  public
    property Id: Integer read FId write FId;
    property Price: Double read FPrice write FPrice;
  end;

  [TestFixture]
  TColumnMetadataTests = class
  public
    [Test]
    procedure VariantWithColumn_IsMapped;
    [Test]
    procedure FieldsWithoutColumn_AreNotMapped;
    [Test]
    procedure ColumnOfUnsupportedType_Raises;
    [Test]
    procedure NullIfZeroOnNonIntegerField_Raises;
    [Test]
    procedure NullIfZero_IsFlaggedOnlyOnMarkedColumns;
    [Test]
    procedure Currency_IsMappedAndFlagged;
  end;

  [TestFixture]
  TDataMapperTests = class
  public
    [Test]
    procedure ConvertsByPropertyType;
    [Test]
    procedure NullIntoVariant_ReplacesPreviousValue;
    [Test]
    procedure BcdIntoVariant_BecomesDouble;
    [Test]
    procedure NullIntoNullIfZero_ResetsToZero;
    [Test]
    procedure ValueIntoNullIfZero_IsRead;
    [Test]
    procedure ColumnValue_NullIfZeroZero_IsNull;
    [Test]
    procedure ColumnValue_NullIfZeroValue_IsKept;
    [Test]
    procedure ColumnValue_DateTime_IsVarDate;
    [Test]
    procedure ColumnValue_Currency_IsReadAsCurrency;
  end;

  [TestFixture]
  TScriptGenerationTests = class
  public
    [Test]
    procedure Insert_NullValues_AreWrittenAsNullLiteral;
    [Test]
    procedure Insert_FilledValues_BecomeParameters;
    [Test]
    procedure Update_NullValues_AreWrittenAsNullLiteral;
    [Test]
    procedure UpdatePartial_NullIfZeroZero_IsWrittenAsNullLiteral;
  end;

  [TestFixture]
  TNullIfZeroJsonTests = class
  public
    [Test]
    procedure Serialize_Zero_IsNull;
    [Test]
    procedure Serialize_Value_IsNumber;
    [Test]
    procedure Deserialize_Null_IsZero;
    [Test]
    procedure Deserialize_Number_IsValue;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Bridge.Connection.Types,
  Bridge.Connection.Generator.Interfaces,
  Bridge.Connection.Generator.Base,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Mapper,
  Bridge.MetaData.ScriptGenerator,
  Bridge.Neon.Config;

{ TOrmTypes }

constructor TOrmTypes.Create;
begin
  inherited Create;
  FRef := Null;
  FState := Null;
end;

{ Helpers }

function FindColumn(AClass: TClass; const AColumn: string; out AMeta: TPropertyMeta): Boolean;
var
  LPropMeta: TPropertyMeta;
begin
  for LPropMeta in TMetaDataManager.Instance.GetMetaData(AClass).AllProperties do
    if SameText(LPropMeta.ColumnName, AColumn) then
    begin
      AMeta := LPropMeta;
      Exit(True);
    end;
  Result := False;
end;

function HasColumn(AClass: TClass; const AColumn: string): Boolean;
var
  LMeta: TPropertyMeta;
begin
  Result := FindColumn(AClass, AColumn, LMeta);
end;

function ColumnMeta(const AColumn: string): TPropertyMeta;
begin
  if not FindColumn(TOrmTypes, AColumn, Result) then
    raise Exception.CreateFmt('Column %s not mapped', [AColumn]);
end;

procedure AddBcdField(ATable: TFDMemTable; const AName: string);
var
  LDef: TFieldDef;
begin
  LDef := ATable.FieldDefs.AddFieldDef;
  LDef.Name := AName;
  LDef.DataType := ftFMTBCD;
  LDef.Precision := 18;
  LDef.Size := 4;
end;

function CreateTable: TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  // Column types differ from the property types on purpose.
  Result.FieldDefs.Add('QTY', ftLargeint);
  Result.FieldDefs.Add('BIG', ftLargeint);
  AddBcdField(Result, 'AMOUNT');
  Result.FieldDefs.Add('ACTIVE', ftInteger);
  Result.FieldDefs.Add('NAME', ftWideString, 50);
  Result.FieldDefs.Add('CREATED_AT', ftDateTime);
  AddBcdField(Result, 'PRICE');
  AddBcdField(Result, 'REF');
  Result.FieldDefs.Add('ID_PARENT', ftInteger);
  Result.FieldDefs.Add('ID_BIG_PARENT', ftLargeint);
  Result.CreateDataSet;
end;

procedure MapRow(ATable: TFDMemTable; AEntity: TOrmTypes);
begin
  TDataMapper.MapDataSetToEntity(ATable, AEntity, TMetaDataManager.Instance.GetMetaData(TOrmTypes));
end;

function CountNullParams(const AParams: TParamValues): Integer;
var
  LParam: TParamValue;
begin
  Result := 0;
  for LParam in AParams do
    if VarIsNull(LParam.Value) or VarIsEmpty(LParam.Value) then
      Inc(Result);
end;

procedure AssertNear(AExpected, AActual: Double; const AMessage: string = '');
begin
  Assert.IsTrue(Abs(AExpected - AActual) < 0.00001,
    Format('%s expected %g, got %g', [AMessage, AExpected, AActual]));
end;

function FindParam(const AParams: TParamValues; AValue: Integer): Boolean;
var
  LParam: TParamValue;
begin
  for LParam in AParams do
    if (not VarIsNull(LParam.Value)) and VarIsOrdinal(LParam.Value) and (LParam.Value = AValue) then
      Exit(True);
  Result := False;
end;

{ TColumnMetadataTests }

procedure TColumnMetadataTests.VariantWithColumn_IsMapped;
begin
  Assert.IsTrue(HasColumn(TOrmTypes, 'REF'));
end;

procedure TColumnMetadataTests.FieldsWithoutColumn_AreNotMapped;
begin
  Assert.IsFalse(HasColumn(TOrmTypes, 'State'), 'Variant without [Column]');
  Assert.IsFalse(HasColumn(TOrmTypes, 'Counter'), 'Byte mapped only by convention');
  Assert.IsTrue(HasColumn(TOrmTypes, 'QTY'));
end;

procedure TColumnMetadataTests.ColumnOfUnsupportedType_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TMetaDataManager.Instance.GetMetaData(TOrmByteColumn);
    end,
    Exception
  );
end;

procedure TColumnMetadataTests.NullIfZeroOnNonIntegerField_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TMetaDataManager.Instance.GetMetaData(TOrmNullIfZeroDouble);
    end,
    Exception
  );
end;

procedure TColumnMetadataTests.NullIfZero_IsFlaggedOnlyOnMarkedColumns;
begin
  Assert.IsTrue(ColumnMeta('ID_PARENT').NullIfZero);
  Assert.IsTrue(ColumnMeta('ID_BIG_PARENT').NullIfZero);
  Assert.IsFalse(ColumnMeta('QTY').NullIfZero);
  Assert.IsFalse(ColumnMeta('REF').NullIfZero);
end;

procedure TColumnMetadataTests.Currency_IsMappedAndFlagged;
begin
  Assert.IsTrue(ColumnMeta('PRICE').IsCurrency);
  Assert.IsFalse(ColumnMeta('AMOUNT').IsCurrency, 'Double is not Currency');
end;

{ TDataMapperTests }

procedure TDataMapperTests.ConvertsByPropertyType;
var
  LTable: TFDMemTable;
  LEntity: TOrmTypes;
  LCreatedAt: TDateTime;
begin
  LTable := CreateTable;
  LEntity := TOrmTypes.Create;
  try
    LCreatedAt := EncodeDate(2026, 10, 4) + EncodeTime(13, 30, 0, 0);
    LTable.Append;
    LTable.FieldByName('QTY').AsLargeInt := 7;
    LTable.FieldByName('BIG').AsLargeInt := 5000000000;
    LTable.FieldByName('AMOUNT').AsFloat := 12.3456;
    LTable.FieldByName('ACTIVE').AsInteger := 1;
    LTable.FieldByName('NAME').AsString := 'Sheet';
    LTable.FieldByName('CREATED_AT').AsDateTime := LCreatedAt;
    LTable.FieldByName('PRICE').AsCurrency := 1500.75;
    LTable.FieldByName('REF').AsFloat := 42;
    LTable.Post;

    MapRow(LTable, LEntity);

    Assert.AreEqual(7, LEntity.Qty);
    Assert.IsTrue(LEntity.Big = 5000000000, 'Int64 kept');
    AssertNear(12.3456, LEntity.Amount, 'AMOUNT');
    Assert.IsTrue(LEntity.Active);
    Assert.AreEqual('Sheet', LEntity.Name);
    AssertNear(LCreatedAt, LEntity.CreatedAt, 'CREATED_AT');
    Assert.IsTrue(LEntity.Price = 1500.75, 'Currency read with its own layout');
    Assert.AreEqual(42, Integer(LEntity.Ref));
  finally
    LEntity.Free;
    LTable.Free;
  end;
end;

procedure TDataMapperTests.NullIntoVariant_ReplacesPreviousValue;
var
  LTable: TFDMemTable;
  LEntity: TOrmTypes;
begin
  LTable := CreateTable;
  LEntity := TOrmTypes.Create;
  try
    LEntity.Ref := 5;
    LEntity.Qty := 3;
    LTable.Append;
    LTable.FieldByName('NAME').AsString := 'No reference';
    LTable.Post;

    MapRow(LTable, LEntity);

    Assert.IsTrue(VarIsNull(LEntity.Ref), 'NULL becomes Null in a Variant');
    // Other types keep the current value on NULL, as before.
    Assert.AreEqual(3, LEntity.Qty);
  finally
    LEntity.Free;
    LTable.Free;
  end;
end;

procedure TDataMapperTests.BcdIntoVariant_BecomesDouble;
var
  LTable: TFDMemTable;
  LEntity: TOrmTypes;
begin
  LTable := CreateTable;
  LEntity := TOrmTypes.Create;
  try
    LTable.Append;
    LTable.FieldByName('REF').AsFloat := 1.5;
    LTable.Post;

    MapRow(LTable, LEntity);

    Assert.AreEqual(Integer(varDouble), Integer(VarType(LEntity.Ref) and varTypeMask));
    AssertNear(1.5, Double(LEntity.Ref), 'REF');
  finally
    LEntity.Free;
    LTable.Free;
  end;
end;

procedure TDataMapperTests.NullIntoNullIfZero_ResetsToZero;
var
  LTable: TFDMemTable;
  LEntity: TOrmTypes;
begin
  LTable := CreateTable;
  LEntity := TOrmTypes.Create;
  try
    LEntity.IdParent := 9;
    LEntity.IdBigParent := 9;
    LTable.Append;
    LTable.FieldByName('NAME').AsString := 'No parent';
    LTable.Post;

    MapRow(LTable, LEntity);

    Assert.AreEqual(0, LEntity.IdParent);
    Assert.IsTrue(LEntity.IdBigParent = 0, 'Int64 [NullIfZero] reset');
  finally
    LEntity.Free;
    LTable.Free;
  end;
end;

procedure TDataMapperTests.ValueIntoNullIfZero_IsRead;
var
  LTable: TFDMemTable;
  LEntity: TOrmTypes;
begin
  LTable := CreateTable;
  LEntity := TOrmTypes.Create;
  try
    LTable.Append;
    LTable.FieldByName('ID_PARENT').AsInteger := 11;
    LTable.FieldByName('ID_BIG_PARENT').AsLargeInt := 6000000000;
    LTable.Post;

    MapRow(LTable, LEntity);

    Assert.AreEqual(11, LEntity.IdParent);
    Assert.IsTrue(LEntity.IdBigParent = 6000000000, 'Int64 [NullIfZero] read');
  finally
    LEntity.Free;
    LTable.Free;
  end;
end;

procedure TDataMapperTests.ColumnValue_NullIfZeroZero_IsNull;
var
  LEntity: TOrmTypes;
begin
  LEntity := TOrmTypes.Create;
  try
    Assert.IsTrue(VarIsNull(TDataMapper.ColumnValue(LEntity, ColumnMeta('ID_PARENT'))));
    Assert.IsTrue(VarIsNull(TDataMapper.ColumnValue(LEntity, ColumnMeta('ID_BIG_PARENT'))));
    // Without [NullIfZero] the zero is a value.
    Assert.AreEqual(0, Integer(TDataMapper.ColumnValue(LEntity, ColumnMeta('QTY'))));
  finally
    LEntity.Free;
  end;
end;

procedure TDataMapperTests.ColumnValue_NullIfZeroValue_IsKept;
var
  LEntity: TOrmTypes;
begin
  LEntity := TOrmTypes.Create;
  try
    LEntity.IdParent := 4;
    Assert.AreEqual(4, Integer(TDataMapper.ColumnValue(LEntity, ColumnMeta('ID_PARENT'))));
  finally
    LEntity.Free;
  end;
end;

procedure TDataMapperTests.ColumnValue_DateTime_IsVarDate;
var
  LEntity: TOrmTypes;
  LValue: Variant;
begin
  LEntity := TOrmTypes.Create;
  try
    LEntity.CreatedAt := EncodeDate(2026, 10, 4);
    LValue := TDataMapper.ColumnValue(LEntity, ColumnMeta('CREATED_AT'));
    Assert.AreEqual(Integer(varDate), Integer(VarType(LValue) and varTypeMask));
  finally
    LEntity.Free;
  end;
end;

procedure TDataMapperTests.ColumnValue_Currency_IsReadAsCurrency;
var
  LEntity: TOrmTypes;
  LValue: Variant;
begin
  LEntity := TOrmTypes.Create;
  try
    LEntity.Price := 1500.75;
    // TFastField.GetAsVariant alone would reinterpret the scaled Int64 as a Double.
    LValue := TDataMapper.ColumnValue(LEntity, ColumnMeta('PRICE'));
    Assert.AreEqual(Integer(varCurrency), Integer(VarType(LValue) and varTypeMask));
    Assert.IsTrue(Currency(LValue) = 1500.75, 'ColumnValue');
    Assert.IsTrue(Currency(TDataMapper.PropertyValue(LEntity, ColumnMeta('PRICE'))) = 1500.75, 'PropertyValue');
  finally
    LEntity.Free;
  end;
end;

{ TScriptGenerationTests }

procedure TScriptGenerationTests.Insert_NullValues_AreWrittenAsNullLiteral;
var
  LGenerator: TMetaDataScriptGenerator;
  LEntity: TOrmTypes;
  LScript: TScriptInsert;
begin
  // INSERT/UPDATE generation does not use the connection.
  LGenerator := TMetaDataScriptGenerator.Create(nil);
  LEntity := TOrmTypes.Create;
  try
    LScript := LGenerator.GenerateInsertScript(LEntity);

    Assert.Contains(LScript.Fields, 'REF');
    Assert.Contains(LScript.Fields, 'ID_PARENT');
    Assert.Contains(LScript.Fields, 'ID_BIG_PARENT');
    // REF, ID_PARENT and ID_BIG_PARENT go as NULL; the 7 other columns are parameters
    // (ID is auto increment).
    Assert.AreEqual(7, Integer(Length(LScript.ParamValues)));
    Assert.AreEqual(0, CountNullParams(LScript.ParamValues));
  finally
    LEntity.Free;
    LGenerator.Free;
  end;
end;

procedure TScriptGenerationTests.Insert_FilledValues_BecomeParameters;
var
  LGenerator: TMetaDataScriptGenerator;
  LEntity: TOrmTypes;
  LScript: TScriptInsert;
begin
  LGenerator := TMetaDataScriptGenerator.Create(nil);
  LEntity := TOrmTypes.Create;
  try
    LEntity.Ref := 9;
    LEntity.IdParent := 21;
    LEntity.IdBigParent := 22;
    LScript := LGenerator.GenerateInsertScript(LEntity);

    Assert.DoesNotContain(LScript.Params, 'NULL');
    Assert.AreEqual(10, Integer(Length(LScript.ParamValues)));
    Assert.IsTrue(FindParam(LScript.ParamValues, 21), 'ID_PARENT parameter');
    Assert.IsTrue(FindParam(LScript.ParamValues, 22), 'ID_BIG_PARENT parameter');
  finally
    LEntity.Free;
    LGenerator.Free;
  end;
end;

procedure TScriptGenerationTests.Update_NullValues_AreWrittenAsNullLiteral;
var
  LGenerator: TMetaDataScriptGenerator;
  LEntity: TOrmTypes;
  LScript: TScriptUpdate;
begin
  LGenerator := TMetaDataScriptGenerator.Create(nil);
  LEntity := TOrmTypes.Create;
  try
    LEntity.Id := 1;
    LScript := LGenerator.GenerateUpdateScript(LEntity);

    Assert.Contains(LScript.Structure, 'REF = NULL');
    Assert.Contains(LScript.Structure, 'ID_PARENT = NULL');
    Assert.Contains(LScript.Structure, 'ID_BIG_PARENT = NULL');
    Assert.AreEqual(0, CountNullParams(LScript.ParamValues));
  finally
    LEntity.Free;
    LGenerator.Free;
  end;
end;

procedure TScriptGenerationTests.UpdatePartial_NullIfZeroZero_IsWrittenAsNullLiteral;
var
  LScriptGenerator: TMetaDataScriptGenerator;
  LSQLGenerator: ISQLGenerator;
  LEntity: TOrmTypes;
  LCommand: TDBCommand;
begin
  LScriptGenerator := TMetaDataScriptGenerator.Create(nil);
  LSQLGenerator := TBaseSQLGenerator.Create;
  LEntity := TOrmTypes.Create;
  try
    LEntity.Id := 1;
    LEntity.Qty := 2;
    LCommand := LSQLGenerator.GenerateUpdatePartial(LEntity, LScriptGenerator, ['IdParent', 'Qty']);

    Assert.Contains(LCommand.SQL, 'ID_PARENT = NULL');
    Assert.Contains(LCommand.SQL, 'QTY = :');
    Assert.AreEqual(0, CountNullParams(LCommand.Params));
  finally
    LEntity.Free;
    LScriptGenerator.Free;
  end;
end;

{ TNullIfZeroJsonTests }

procedure TNullIfZeroJsonTests.Serialize_Zero_IsNull;
var
  LEntity: TOrmTypes;
  LJSON: TJSONObject;
begin
  LEntity := TOrmTypes.Create;
  LJSON := TBridgeNeon.ObjectToJSONObject(LEntity);
  try
    Assert.IsTrue(LJSON.GetValue('idParent') is TJSONNull, 'idParent');
    Assert.IsTrue(LJSON.GetValue('idBigParent') is TJSONNull, 'idBigParent');
    Assert.IsTrue(LJSON.GetValue('qty') is TJSONNumber, 'zero without [NullIfZero] stays a number');
  finally
    LJSON.Free;
    LEntity.Free;
  end;
end;

procedure TNullIfZeroJsonTests.Serialize_Value_IsNumber;
var
  LEntity: TOrmTypes;
  LJSON: TJSONObject;
begin
  LEntity := TOrmTypes.Create;
  LEntity.IdParent := 15;
  LJSON := TBridgeNeon.ObjectToJSONObject(LEntity);
  try
    Assert.IsTrue(LJSON.GetValue('idParent') is TJSONNumber);
    Assert.AreEqual(15, (LJSON.GetValue('idParent') as TJSONNumber).AsInt);
  finally
    LJSON.Free;
    LEntity.Free;
  end;
end;

procedure TNullIfZeroJsonTests.Deserialize_Null_IsZero;
var
  LEntity: TOrmTypes;
  LJSON: TJSONObject;
begin
  LEntity := TOrmTypes.Create;
  LJSON := TJSONObject.ParseJSONValue('{"idParent": null, "idBigParent": null}') as TJSONObject;
  try
    LEntity.IdParent := 8;
    LEntity.IdBigParent := 8;
    TBridgeNeon.JSONToObject(LEntity, LJSON);

    Assert.AreEqual(0, LEntity.IdParent);
    Assert.IsTrue(LEntity.IdBigParent = 0, 'Int64 [NullIfZero]');
  finally
    LJSON.Free;
    LEntity.Free;
  end;
end;

procedure TNullIfZeroJsonTests.Deserialize_Number_IsValue;
var
  LEntity: TOrmTypes;
  LJSON: TJSONObject;
begin
  LEntity := TOrmTypes.Create;
  LJSON := TJSONObject.ParseJSONValue('{"idParent": 33}') as TJSONObject;
  try
    TBridgeNeon.JSONToObject(LEntity, LJSON);
    Assert.AreEqual(33, LEntity.IdParent);
  finally
    LJSON.Free;
    LEntity.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TColumnMetadataTests);
  TDUnitX.RegisterTestFixture(TDataMapperTests);
  TDUnitX.RegisterTestFixture(TScriptGenerationTests);
  TDUnitX.RegisterTestFixture(TNullIfZeroJsonTests);

end.
