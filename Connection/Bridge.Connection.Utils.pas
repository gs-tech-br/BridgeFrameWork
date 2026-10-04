unit Bridge.Connection.Utils;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.StrUtils,
  System.Variants,
  System.Rtti,
  System.TypInfo,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Bridge.Connection.Types,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Mapper,
  Bridge.FastRtti,
  Bridge.Connection.Log.Manager;



  function GetComparisonOperator(const AOperator: TComparisonOperator): string;
  function GetLogicOperator(const AOperator: TLogicOperator): string;
  function FormatValue(const AValue: Variant; const AOperator: TComparisonOperator): string;

type
  /// <summary>
  /// Helper class for batch insert operations using prepared statements.
  /// Centralizes the InsertBatch logic for all database connectors.
  /// </summary>
  TBatchOperationHelper = class
  public
    class procedure Insert(
      AConnection: TFDConnection;
      const AList: TObject;
      AClassType: TClass;
      AGetColumns: TFunc<string, TStringList>;
      AQuoteIdentifier: TFunc<string, string> = nil);

    class procedure Update(
      AConnection: TFDConnection;
      const AList: TObject;
      AClassType: TClass;
      AGetColumns: TFunc<string, TStringList>;
      AQuoteIdentifier: TFunc<string, string> = nil);

    class procedure Delete(
      AConnection: TFDConnection;
      const AList: TObject;
      AClassType: TClass;
      AQuoteIdentifier: TFunc<string, string> = nil);
  end;

implementation

/// <summary>
/// Parameter type of a Variant property in a batch, taken from the first non-null
/// row. ftUnknown when every row is null: the caller writes NULL as a literal,
/// since FireDAC rejects an array parameter whose data type it cannot infer.
/// Other property types keep ftUnknown and let FireDAC infer it as before.
/// </summary>
function BatchParamDataType(AList: TList<TObject>; const APropMeta: TPropertyMeta): TFieldType;
var
  LObject: TObject;
  LValue: Variant;
begin
  // [NullIfZero] rows may hold NULL, so the type cannot be left to inference.
  if APropMeta.NullIfZero then
    if APropMeta.TypeKind = tkInt64 then
      Exit(ftLargeint)
    else
      Exit(ftInteger);

  Result := ftUnknown;
  if APropMeta.TypeKind <> tkVariant then
    Exit;

  for LObject in AList do
  begin
    LValue := TFastField.GetVariant(LObject, APropMeta.Offset);
    if not (VarIsNull(LValue) or VarIsEmpty(LValue)) then
      Exit(VarTypeToDataType(VarType(LValue)));
  end;
end;

{ TBatchOperationHelper }

class procedure TBatchOperationHelper.Insert(
  AConnection: TFDConnection;
  const AList: TObject;
  AClassType: TClass;
  AGetColumns: TFunc<string, TStringList>;
  AQuoteIdentifier: TFunc<string, string>);
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LTableName: string;
  LFields, LParams: string;
  LQuery: TFDQuery;
  LTableColumns: TStringList;
  LMappedProperties: TList<TPropertyMeta>;
  LObject: TObject;
  I, J: Integer;
  LValue: Variant;
  LLogManager: TLogManager;
  LCount: Integer;
  LColumnName: string;
  LGenericList: TList<TObject>;
  LCachedParams: TArray<TFDParam>;
  LParamTypes: TList<TFieldType>;
  LParamType: TFieldType;
begin
  if not Assigned(AList) then
    raise Exception.Create('List cannot be null');

  // Hard cast to TList<TObject> for performance (layout compatibility for reference types)
  LGenericList := TList<TObject>(AList);
  LCount := LGenericList.Count;

  if LCount = 0 then
    Exit;

  if not Assigned(AQuoteIdentifier) then
    AQuoteIdentifier := function(S: string): string begin Result := S; end;

  LMetaData := TMetaDataManager.Instance.GetMetaData(AClassType);
  LTableName := LMetaData.TableName;
  LLogManager := TLogManager.GetInstance;

  LFields := '';
  LParams := '';
  LMappedProperties := TList<TPropertyMeta>.Create;
  LParamTypes := TList<TFieldType>.Create;
  LTableColumns := AGetColumns(LTableName);
  try
    for LPropMeta in LMetaData.AllProperties do
    begin
      if Assigned(LMetaData.PrimaryKeyField) and
         (LPropMeta.RttiField = LMetaData.PrimaryKeyField) and
         LMetaData.IsAutoIncrement then
        Continue;

      if LTableColumns.IndexOf(LPropMeta.ColumnName) = -1 then
        Continue;

      if not LFields.IsEmpty then
      begin
        LFields := LFields + ', ';
        LParams := LParams + ', ';
      end;

      LColumnName := AQuoteIdentifier(LPropMeta.ColumnName);
      LFields := LFields + LColumnName;

      LParamType := BatchParamDataType(LGenericList, LPropMeta);
      if (LPropMeta.TypeKind = tkVariant) and (LParamType = ftUnknown) then
      begin
        LParams := LParams + 'NULL';
        Continue;
      end;

      LParams := LParams + ':P' + IntToStr(LMappedProperties.Count);
      LMappedProperties.Add(LPropMeta);
      LParamTypes.Add(LParamType);
    end;

    if LFields.IsEmpty then
      raise Exception.CreateFmt('No mappable columns found for %s', [AClassType.ClassName]);

    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := AConnection;
      LQuery.SQL.Text := Format('INSERT INTO %s (%s) VALUES (%s)',
        [AQuoteIdentifier(LTableName), LFields, LParams]);

      LQuery.Params.ArraySize := LCount;

      // Cache params for faster access
      SetLength(LCachedParams, LMappedProperties.Count);
      for I := 0 to LMappedProperties.Count - 1 do
      begin
        LCachedParams[I] := LQuery.Params[I];
        if LParamTypes[I] <> ftUnknown then
          LCachedParams[I].DataType := LParamTypes[I];
      end;

      for I := 0 to LCount - 1 do
      begin
        LObject := LGenericList[I]; // Direct access
        
        for J := 0 to LMappedProperties.Count - 1 do
        begin
          LPropMeta := LMappedProperties[J];
          LValue := TDataMapper.ColumnValue(LObject, LPropMeta);
          // Access cached param directly
          LCachedParams[J].Values[I] := LValue;
        end;
      end;

      LQuery.Execute(LCount, 0);
      LLogManager.WriteLogInfo(Format('[InsertBatch] inserted %d records into %s', [LCount, LTableName]));
    finally
      LQuery.Free;
    end;
  finally
    LParamTypes.Free;
    LMappedProperties.Free;
    LTableColumns.Free;
  end;
end;

class procedure TBatchOperationHelper.Update(
  AConnection: TFDConnection;
  const AList: TObject;
  AClassType: TClass;
  AGetColumns: TFunc<string, TStringList>;
  AQuoteIdentifier: TFunc<string, string>);
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LTableName: string;
  LSetClause: string;
  LQuery: TFDQuery;
  LTableColumns: TStringList;
  LMappedProperties: TList<TPropertyMeta>;
  LObject: TObject;
  I, J: Integer;
  LValue: Variant;
  LLogManager: TLogManager;
  LCount: Integer;
  LColumnName: string;
  LPKValue: Variant;
  LGenericList: TList<TObject>;
  LCachedParams: TArray<TFDParam>;
  LCachedPKParam: TFDParam;
  LParamTypes: TList<TFieldType>;
  LParamType: TFieldType;
begin
  if not Assigned(AList) then raise Exception.Create('List cannot be null');

  // Hard cast to TList<TObject> for performance
  LGenericList := TList<TObject>(AList);
  LCount := LGenericList.Count;

  if LCount = 0 then Exit;

  if not Assigned(AQuoteIdentifier) then AQuoteIdentifier := function(S: string): string begin Result := S; end;

  LMetaData := TMetaDataManager.Instance.GetMetaData(AClassType);
  LTableName := LMetaData.TableName;
  LLogManager := TLogManager.GetInstance;

  if not Assigned(LMetaData.PrimaryKeyField) then
    raise Exception.Create('Primary key required for batch update');

  LSetClause := '';
  LMappedProperties := TList<TPropertyMeta>.Create;
  LParamTypes := TList<TFieldType>.Create;
  LTableColumns := AGetColumns(LTableName);
  try
    for LPropMeta in LMetaData.AllProperties do
    begin
      // Skip PK in SET clause
      if (LPropMeta.RttiField = LMetaData.PrimaryKeyField) then Continue;
      if LTableColumns.IndexOf(LPropMeta.ColumnName) = -1 then Continue;

      if not LSetClause.IsEmpty then LSetClause := LSetClause + ', ';

      LColumnName := AQuoteIdentifier(LPropMeta.ColumnName);

      LParamType := BatchParamDataType(LGenericList, LPropMeta);
      if (LPropMeta.TypeKind = tkVariant) and (LParamType = ftUnknown) then
      begin
        LSetClause := LSetClause + LColumnName + ' = NULL';
        Continue;
      end;

      LSetClause := LSetClause + Format('%s = :P%d', [LColumnName, LMappedProperties.Count]);
      LMappedProperties.Add(LPropMeta);
      LParamTypes.Add(LParamType);
    end;

    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := AConnection;
      // UPDATE Table SET Col1=:P0 WHERE ID=:PID
      LQuery.SQL.Text := Format('UPDATE %s SET %s WHERE %s = :PID', 
        [AQuoteIdentifier(LTableName), LSetClause, AQuoteIdentifier(LMetaData.PrimaryKeyColumn)]);

      LQuery.Params.ArraySize := LCount;

      // Cache params for faster access
      SetLength(LCachedParams, LMappedProperties.Count);
      for I := 0 to LMappedProperties.Count - 1 do
      begin
        LCachedParams[I] := LQuery.Params[I];
        if LParamTypes[I] <> ftUnknown then
          LCachedParams[I].DataType := LParamTypes[I];
      end;

      LCachedPKParam := LQuery.ParamByName('PID');

      for I := 0 to LCount - 1 do
      begin
        LObject := LGenericList[I]; // Direct access
        
        // Set properties
        for J := 0 to LMappedProperties.Count - 1 do
        begin
          LPropMeta := LMappedProperties[J];
          LValue := TDataMapper.ColumnValue(LObject, LPropMeta);
          // Access cached param directly
          LCachedParams[J].Values[I] := LValue;
        end;

        // Set PK
        LPKValue := TFastField.GetAsVariant(LObject, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
        LCachedPKParam.Values[I] := LPKValue;
      end;

      LQuery.Execute(LCount, 0);
      LLogManager.WriteLogInfo(Format('[UpdateBatch] updated %d records in %s', [LCount, LTableName]));
    finally
      LQuery.Free;
    end;
  finally
    LParamTypes.Free;
    LMappedProperties.Free;
    LTableColumns.Free;
  end;
end;

class procedure TBatchOperationHelper.Delete(
  AConnection: TFDConnection;
  const AList: TObject;
  AClassType: TClass;
  AQuoteIdentifier: TFunc<string, string>);
var
  LMetaData: TEntityMetaData;
  LTableName: string;
  LQuery: TFDQuery;
  LObject: TObject;
  I: Integer;
  LLogManager: TLogManager;
  LCount: Integer;
  LPKValue: Variant;
  LGenericList: TList<TObject>;
  LCachedPKParam: TFDParam;
begin
  if not Assigned(AList) then raise Exception.Create('List cannot be null');
  
  // Hard cast to TList<TObject> for performance
  LGenericList := TList<TObject>(AList);
  LCount := LGenericList.Count;

  if LCount = 0 then Exit;

  if not Assigned(AQuoteIdentifier) then AQuoteIdentifier := function(S: string): string begin Result := S; end;

  LMetaData := TMetaDataManager.Instance.GetMetaData(AClassType);
  LTableName := LMetaData.TableName;
  LLogManager := TLogManager.GetInstance;

  if not Assigned(LMetaData.PrimaryKeyField) then
    raise Exception.Create('Primary key required for batch delete');

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := AConnection;
    LQuery.SQL.Text := Format('DELETE FROM %s WHERE %s = :PID', 
      [AQuoteIdentifier(LTableName), AQuoteIdentifier(LMetaData.PrimaryKeyColumn)]);

    LQuery.Params.ArraySize := LCount;
    LCachedPKParam := LQuery.ParamByName('PID');

    for I := 0 to LCount - 1 do
    begin
      LObject := LGenericList[I]; // Direct access
      
      // Access cached param directly
      LPKValue := TFastField.GetAsVariant(LObject, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
      LCachedPKParam.Values[I] := LPKValue;
    end;

    LQuery.Execute(LCount, 0);
    LLogManager.WriteLogInfo(Format('[DeleteBatch] deleted %d records from %s', [LCount, LTableName]));
  finally
    LQuery.Free;
  end;
end;



function GetComparisonOperator(const AOperator: TComparisonOperator): string;
begin
  case AOperator of
    coEqual: Result := '=';
    coGreater: Result := '>';
    coLess: Result := '<';
    coNotEqual: Result := '<>';
    coLike: Result := 'LIKE';
    coIN: Result := 'IN';
    coBetween: Result := 'BETWEEN';
    coGreaterEqual: Result := '>=';
    coLessEqual: Result := '<=';
    coIsNull: Result := 'IS NULL';
    coIsNotNull: Result := 'IS NOT NULL';
  end;
end;

function GetLogicOperator(const AOperator: TLogicOperator): string;
begin
  case AOperator of
    loAND: Result := ' AND ';
    loOR: Result := ' OR ';
  end;
end;

function FormatValue(const AValue: Variant; const AOperator: TComparisonOperator): string;
var
  LVarType: TVarType;
begin
  if (AOperator = coIsNull) or (AOperator = coIsNotNull) then
    Exit(''); // No value needed for IS NULL / IS NOT NULL

  if VarIsClear(AValue) or VarIsEmpty(AValue) then
    Exit('NULL');

  LVarType := VarType(AValue);

  case LVarType of
    varSmallint, varInteger, varSingle, varDouble, varCurrency,
    varShortInt, varByte, varWord, varLongWord, varInt64, varUInt64:
    begin
      Result := VarToStr(AValue);
    end;

    varBoolean:
    begin
      Result := '0';
      if AValue then
        Result := '1';
    end;

    varDate:
    begin
      Result := QuotedStr(FormatDateTime('yyyy-mm-dd', VarToDateTime(AValue)));
    end

    else
    begin
      Result := QuotedStr(VarToStr(AValue));
      if AOperator = coLike then
        Result := QuotedStr('%' + VarToStr(AValue) + '%');
    end;
  end;
end;

end.
