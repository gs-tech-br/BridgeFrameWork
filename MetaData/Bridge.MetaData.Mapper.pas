unit Bridge.MetaData.Mapper;

interface

uses
  Data.DB,
  System.Generics.Collections,
  System.SysUtils,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.FastRtti;

type
  // Defining TFieldMappingList requires TPropertyMeta from Bridge.MetaData.Attributes
  TFieldMappingList = TList<TPair<TPropertyMeta, TField>>;

  TDataMapper = class
  public
    class function PrepareFieldMapping(ADataSet: TDataSet; AMetaData: TEntityMetaData): TFieldMappingList;
    class procedure MapDataSetToEntity(AEntity: TObject; AMappings: TFieldMappingList); overload;
    class procedure MapDataSetToEntity(AQuery: TDataSet; AEntity: TObject; AMetaData: TEntityMetaData); overload;
  end;

implementation

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

class procedure TDataMapper.MapDataSetToEntity(AEntity: TObject;
  AMappings: TFieldMappingList);
var
  LMapping: TPair<TPropertyMeta, TField>;
  LField: TField;
  LMeta: TPropertyMeta;
begin
  for LMapping in AMappings do
  begin
    LField := LMapping.Value;
    LMeta := LMapping.Key;

    if LField.IsNull then
      Continue;

    case LField.DataType of
      ftSmallint, ftInteger, ftAutoInc, ftShortint, ftWord, ftByte:
        TFastField.SetInteger(AEntity, LMeta.Offset, LField.AsInteger);

      ftLargeint:
        TFastField.SetInt64(AEntity, LMeta.Offset, LField.AsLargeInt);

      ftFloat, ftExtended, ftSingle:
        TFastField.SetDouble(AEntity, LMeta.Offset, LField.AsFloat);

      ftCurrency, ftBCD, ftFMTBCD:
        TFastField.SetCurrency(AEntity, LMeta.Offset, LField.AsCurrency);

      ftBoolean:
        TFastField.SetBoolean(AEntity, LMeta.Offset, LField.AsBoolean);

      ftDate, ftTime, ftDateTime, ftTimeStamp:
        TFastField.SetDateTime(AEntity, LMeta.Offset, LField.AsDateTime);
    else
      TFastField.SetString(AEntity, LMeta.Offset, LField.AsString);
    end;
  end;
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

    if (LField = nil) or LField.IsNull then
      Continue;

    case LField.DataType of
      ftSmallint, ftInteger, ftAutoInc, ftShortint, ftWord, ftByte:
        TFastField.SetInteger(AEntity, LPropMeta.Offset, LField.AsInteger);

      ftLargeint:
         TFastField.SetInt64(AEntity, LPropMeta.Offset, LField.AsLargeInt);

      ftFloat, ftExtended, ftSingle:
        TFastField.SetDouble(AEntity, LPropMeta.Offset, LField.AsFloat);

      ftCurrency, ftBCD, ftFMTBCD:
        TFastField.SetCurrency(AEntity, LPropMeta.Offset, LField.AsCurrency);

      ftBoolean:
        TFastField.SetBoolean(AEntity, LPropMeta.Offset, LField.AsBoolean);

      ftDate, ftTime, ftDateTime, ftTimeStamp:
        TFastField.SetDateTime(AEntity, LPropMeta.Offset, LField.AsDateTime);
    else
      TFastField.SetString(AEntity, LPropMeta.Offset, LField.AsString);
    end;
  end;
end;

end.
