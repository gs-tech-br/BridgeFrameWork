unit Bridge.MetaData.Mapper;

interface

uses
  Data.DB,
  System.Generics.Collections,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.FastRtti;

type
  // Defining TFieldMappingList requires TPropertyMeta from Bridge.MetaData.Attributes
  TFieldMappingList = TList<TPair<TPropertyMeta, TField>>;

  TDataMapper = class
  private
    class function FieldAsBoolean(AField: TField): Boolean; static;
    class procedure AssignField(AEntity: TObject; const AMeta: TPropertyMeta; AField: TField); static;
  public
    class function PrepareFieldMapping(ADataSet: TDataSet; AMetaData: TEntityMetaData): TFieldMappingList;
    class procedure MapDataSetToEntity(AEntity: TObject; AMappings: TFieldMappingList); overload;
    class procedure MapDataSetToEntity(AQuery: TDataSet; AEntity: TObject; AMetaData: TEntityMetaData); overload;
    /// <summary>
    /// Column value as a plain Variant (Null, Integer, Int64, Double, Boolean, Date or
    /// string). BCD and currency columns become varDouble, so JSON and parameters see
    /// a number instead of a custom Variant type.
    /// </summary>
    class function FieldAsVariant(AField: TField): Variant; static;
    /// <summary>
    /// Raw property value. Unlike TFastField.GetAsVariant (driven by TypeKind only),
    /// it reads a Currency field as Currency instead of reinterpreting it as Double.
    /// </summary>
    class function PropertyValue(AEntity: TObject; const AMeta: TPropertyMeta): Variant; static;
    /// <summary>
    /// Value to write into the column: Null for a [NullIfZero] zero, varDate for a
    /// TDateTime (a tkFloat that FireDAC would otherwise bind as Double).
    /// </summary>
    class function ColumnValue(AEntity: TObject; const AMeta: TPropertyMeta): Variant; static;
  end;

implementation

const
  DATE_TIME_FIELD_TYPES = [ftDate, ftTime, ftDateTime, ftTimeStamp, ftOraTimeStamp, ftTimeStampOffset];
  INTEGER_FIELD_TYPES = [ftSmallint, ftInteger, ftAutoInc, ftShortint, ftWord, ftByte, ftLongWord];
  // Qualified: System.TypInfo also declares ftExtended and ftSingle (TFloatType).
  FLOAT_FIELD_TYPES = [ftFloat, Data.DB.ftExtended, Data.DB.ftSingle, ftCurrency, ftBCD, ftFMTBCD];

{ TDataMapper }

class function TDataMapper.PrepareFieldMapping(ADataSet: TDataSet;
  AMetaData: TEntityMetaData): TFieldMappingList;
var
  LPropMeta: TPropertyMeta;
  LField: TField;
begin
  Result := TFieldMappingList.Create;
  for LPropMeta in AMetaData.AllProperties do
  begin
    // Perform FieldByName lookup ONLY ONCE here
    LField := ADataSet.FindField(LPropMeta.ColumnName);
    if Assigned(LField) then
      Result.Add(TPair<TPropertyMeta, TField>.Create(LPropMeta, LField));
  end;
end;

class function TDataMapper.FieldAsBoolean(AField: TField): Boolean;
begin
  if AField.DataType = ftBoolean then
    Result := AField.AsBoolean
  else if AField.DataType in INTEGER_FIELD_TYPES + [ftLargeint] then
    Result := AField.AsLargeInt <> 0
  else
    Result := StrToBoolDef(AField.AsString, False);
end;

class function TDataMapper.FieldAsVariant(AField: TField): Variant;
begin
  if AField.IsNull then
    Exit(Null);

  if AField.DataType in INTEGER_FIELD_TYPES then
    Result := AField.AsInteger
  else if AField.DataType = ftLargeint then
    Result := AField.AsLargeInt
  else if AField.DataType in FLOAT_FIELD_TYPES then
    Result := AField.AsFloat
  else if AField.DataType = ftBoolean then
    Result := AField.AsBoolean
  else if AField.DataType in DATE_TIME_FIELD_TYPES then
    Result := VarFromDateTime(AField.AsDateTime)
  else
    Result := AField.AsString;
end;

/// <summary>
/// Writes the column into the entity field. The setter follows the property type
/// (validated by TMetaDataManager), never the column type: a BIGINT column into an
/// Integer field or a NUMERIC column into a Double field used to write bytes of the
/// wrong size or layout.
/// </summary>
class procedure TDataMapper.AssignField(AEntity: TObject; const AMeta: TPropertyMeta; AField: TField);
begin
  if AMeta.TypeKind = tkVariant then
  begin
    // NULL is a value for Variant properties: it must not keep a previous value.
    TFastField.SetVariant(AEntity, AMeta.Offset, FieldAsVariant(AField));
    Exit;
  end;

  if AField.IsNull then
  begin
    // [NullIfZero]: NULL is the zero, so it must not keep a previous value either.
    if AMeta.NullIfZero then
      TFastField.SetByTypeKind(AEntity, AMeta.Offset, AMeta.TypeKind, 0);
    Exit;
  end;

  case AMeta.TypeKind of
    tkInteger:
      TFastField.SetInteger(AEntity, AMeta.Offset, AField.AsInteger);

    tkInt64:
      TFastField.SetInt64(AEntity, AMeta.Offset, AField.AsLargeInt);

    tkFloat:
      if AMeta.IsCurrency then
        TFastField.SetCurrency(AEntity, AMeta.Offset, AField.AsCurrency)
      else if AField.DataType in DATE_TIME_FIELD_TYPES then
        TFastField.SetDateTime(AEntity, AMeta.Offset, AField.AsDateTime)
      else
        TFastField.SetDouble(AEntity, AMeta.Offset, AField.AsFloat);

    tkEnumeration:
      TFastField.SetBoolean(AEntity, AMeta.Offset, FieldAsBoolean(AField));

    tkUString:
      TFastField.SetString(AEntity, AMeta.Offset, AField.AsString);
  end;
end;

class function TDataMapper.PropertyValue(AEntity: TObject; const AMeta: TPropertyMeta): Variant;
begin
  if AMeta.IsCurrency then
    Result := TFastField.GetCurrency(AEntity, AMeta.Offset)
  else
    Result := TFastField.GetAsVariant(AEntity, AMeta.Offset, AMeta.TypeKind);
end;

class function TDataMapper.ColumnValue(AEntity: TObject; const AMeta: TPropertyMeta): Variant;
begin
  Result := PropertyValue(AEntity, AMeta);

  if AMeta.NullIfZero and (Result = 0) then
    Exit(Null);

  if (AMeta.TypeKind = tkFloat) and
     Assigned(AMeta.RttiField) and
     SameText(AMeta.RttiField.FieldType.Name, 'TDateTime') then
    Result := VarFromDateTime(TDateTime(Double(Result)));
end;

class procedure TDataMapper.MapDataSetToEntity(AEntity: TObject;
  AMappings: TFieldMappingList);
var
  LMapping: TPair<TPropertyMeta, TField>;
begin
  for LMapping in AMappings do
    AssignField(AEntity, LMapping.Key, LMapping.Value);
end;

class procedure TDataMapper.MapDataSetToEntity(AQuery: TDataSet; AEntity: TObject;
  AMetaData: TEntityMetaData);
var
  LPropMeta: TPropertyMeta;
  LField: TField;
begin
  for LPropMeta in AMetaData.AllProperties do
  begin
    LField := AQuery.FindField(LPropMeta.ColumnName);
    if Assigned(LField) then
      AssignField(AEntity, LPropMeta, LField);
  end;
end;

end.
