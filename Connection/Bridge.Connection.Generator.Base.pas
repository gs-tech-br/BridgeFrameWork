unit Bridge.Connection.Generator.Base;

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  Bridge.Connection.Types,
  Bridge.Connection.Generator.Interfaces,
  Bridge.MetaData.ScriptGenerator,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Attributes,
  Bridge.FastRtti;

type
  TBaseSQLGenerator = class(TInterfacedObject, ISQLGenerator)
  protected
    function GetQuotedTableName(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): string; virtual;
  public
    function GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand; virtual;
    function GenerateUpdate(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand; virtual;
    function GenerateUpdatePartial(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator; const AFieldsToUpdate: TArray<string>): TDBCommand; virtual;
    function GenerateDelete(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand; virtual;
    function GenerateSelect(const ATable: string; const AId: Variant; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand; virtual;
    function GetLastInsertIdSQL: string; virtual;
    function GetLimitSQL(const ASQL: string; AFetch, AOffset: Integer): string; virtual;
  end;

implementation

{ TBaseSQLGenerator }

function TBaseSQLGenerator.GetQuotedTableName(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): string;
begin
  Result := AMetaDataGenerator.GetTableName(AObject);
end;

function TBaseSQLGenerator.GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;
const
  LInsert = 'INSERT INTO %s (%s) VALUES (%s)';
var
  LScript: TScriptInsert;
  LTableName: string;
begin
  if not Assigned(AObject) then
    raise Exception.Create('Object cannot be null');

  LTableName := GetQuotedTableName(AObject, AMetaDataGenerator);
  LScript := AMetaDataGenerator.GenerateInsertScript(AObject);

  if LScript.Fields.IsEmpty or (Length(LScript.ParamValues) = 0) then
    raise Exception.Create('Could not generate insert script for ' + AObject.ClassName);

  Result.SQL := Format(LInsert, [LTableName, LScript.Fields, LScript.Params]);
  Result.Params := LScript.ParamValues;
end;

function TBaseSQLGenerator.GenerateUpdate(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;
const
  LUpdate = 'UPDATE %s SET %s WHERE %s';
var
  LScript: TScriptUpdate;
  LTableName: string;
  I: Integer;
begin
  if not Assigned(AObject) then
    raise Exception.Create('Object cannot be null');

  LTableName := GetQuotedTableName(AObject, AMetaDataGenerator);
  LScript := AMetaDataGenerator.GenerateUpdateScript(AObject);

  if LScript.Structure.IsEmpty then
    raise Exception.Create('Could not generate update script for ' + AObject.ClassName);

  if LScript.WhereClause.IsEmpty then
    raise Exception.Create('Primary key not found for ' + AObject.ClassName);

  Result.SQL := Format(LUpdate, [LTableName, LScript.Structure, LScript.WhereClause]);
  
  SetLength(Result.Params, Length(LScript.ParamValues) + Length(LScript.WhereParamValues));
  for I := 0 to High(LScript.ParamValues) do
    Result.Params[I] := LScript.ParamValues[I];
  for I := 0 to High(LScript.WhereParamValues) do
    Result.Params[Length(LScript.ParamValues) + I] := LScript.WhereParamValues[I];
end;

function TBaseSQLGenerator.GenerateUpdatePartial(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator; const AFieldsToUpdate: TArray<string>): TDBCommand;
const
  LUpdate = 'UPDATE %s SET %s WHERE %s';
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LSetClause: string;
  LValue: Variant;
  LColumnName: string;
  LIsKey: Boolean;
  LParamIndex: Integer;
  LParamName: string;
  LParamList: TArray<TParamValue>;
  LWhereClause: string;
  LWhereParamValues: TParamValues;
  LPKValue: Variant;
  LTableName: string;
  I, J: Integer;
  LFieldFound: Boolean;
  LFieldName: string;
begin
  if not Assigned(AObject) then
    raise Exception.Create('Object cannot be null');

  if Length(AFieldsToUpdate) = 0 then
    raise Exception.Create('At least one field must be specified for partial update');

  LTableName := AMetaDataGenerator.GetTableName(AObject);
  LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
  LParamIndex := 0;
  SetLength(LParamList, 0);

  // Build SET clause only for specified fields
  for I := 0 to High(AFieldsToUpdate) do
  begin
    LFieldName := AFieldsToUpdate[I];
    LFieldFound := False;

    // Find the property metadata for this field
    for J := 0 to High(LMetaData.AllProperties) do
    begin
      LPropMeta := LMetaData.AllProperties[J];
      
      // Check if this is a key field (skip keys in SET clause)
      LIsKey := Assigned(LMetaData.PrimaryKeyField) and (LPropMeta.RttiField = LMetaData.PrimaryKeyField);
      if not LIsKey then
        LIsKey := Assigned(LMetaData.CompositeKeyField) and (LPropMeta.RttiField = LMetaData.CompositeKeyField);

      // Match by property name (removing 'F' prefix from field name)
      if SameText(LPropMeta.RttiField.Name.Substring(1), LFieldName) then
      begin
        LFieldFound := True;
        
        if LIsKey then
          raise Exception.CreateFmt('Cannot update key field: %s', [LFieldName]);

        LColumnName := LPropMeta.ColumnName;
        LValue := TFastField.GetAsVariant(AObject, LPropMeta.Offset, LPropMeta.TypeKind);

        // Build SET clause with parameters
        LParamName := 'p' + IntToStr(LParamIndex);
        if not LSetClause.IsEmpty then
          LSetClause := LSetClause + ', ';
        LSetClause := LSetClause + LColumnName + ' = :' + LParamName;

        // Add parameter value
        SetLength(LParamList, Length(LParamList) + 1);
        LParamList[High(LParamList)] := TParamValue.Create(LParamName, LValue, LPropMeta.TypeKind);

        Inc(LParamIndex);
        Break;
      end;
    end;

    if not LFieldFound then
      raise Exception.CreateFmt('Field not found in entity: %s', [LFieldName]);
  end;

  // Generate WHERE clause with primary key
  if not Assigned(LMetaData.PrimaryKeyField) then
    raise Exception.Create('Primary key not found for ' + AObject.ClassName);

  LColumnName := LMetaData.PrimaryKeyColumn;
  LPKValue := TFastField.GetAsVariant(AObject, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
  
  LParamName := 'pk0';
  LWhereClause := LColumnName + ' = :' + LParamName;
  
  SetLength(LWhereParamValues, 1);
  LWhereParamValues[0] := TParamValue.Create(LParamName, LPKValue, LMetaData.PrimaryKeyTypeKind);

  // Add composite key if present
  if Assigned(LMetaData.CompositeKeyField) then
  begin
    LColumnName := LMetaData.CompositeKeyColumn;
    LPKValue := TFastField.GetAsVariant(AObject, LMetaData.CompositeKeyOffset, LMetaData.CompositeKeyTypeKind);
    
    LParamName := 'pk1';
    LWhereClause := LWhereClause + ' AND ' + LColumnName + ' = :' + LParamName;
    
    SetLength(LWhereParamValues, 2);
    LWhereParamValues[1] := TParamValue.Create(LParamName, LPKValue, LMetaData.CompositeKeyTypeKind);
  end;

  Result.SQL := Format(LUpdate, [LTableName, LSetClause, LWhereClause]);
  
  // Combine SET and WHERE parameters
  SetLength(Result.Params, Length(LParamList) + Length(LWhereParamValues));
  for I := 0 to High(LParamList) do
    Result.Params[I] := LParamList[I];
  for I := 0 to High(LWhereParamValues) do
    Result.Params[Length(LParamList) + I] := LWhereParamValues[I];
end;

function TBaseSQLGenerator.GenerateDelete(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;
const
  LDelete = 'DELETE FROM %s WHERE %s';
var
  LScript: TScriptDelete;
  LTableName: string;
begin
  if not Assigned(AObject) then
    raise Exception.Create('Object cannot be null');

  LTableName := GetQuotedTableName(AObject, AMetaDataGenerator);
  LScript := AMetaDataGenerator.GenerateDeleteScript(AObject);

  if LScript.WhereClause.IsEmpty then
    raise Exception.Create('Primary key not found for ' + AObject.ClassName);

  Result.SQL := Format(LDelete, [LTableName, LScript.WhereClause]);
  Result.Params := LScript.WhereParamValues;
end;

function TBaseSQLGenerator.GenerateSelect(const ATable: string; const AId: Variant; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;
begin
  // Basic implementation, can be expanded
  Result.SQL := Format('SELECT * FROM %s WHERE ID = :ID', [ATable]);
  SetLength(Result.Params, 1);
  Result.Params[0] := TParamValue.Create('ID', AId, tkVariant); 
end;

function TBaseSQLGenerator.GetLastInsertIdSQL: string;
begin
  Result := '';
end;

function TBaseSQLGenerator.GetLimitSQL(const ASQL: string; AFetch, AOffset: Integer): string;
begin
  // Default standard SQL (works for older versions of some DBs or generic)
  // Note: Modern SQL uses OFFSET FETCH or LIMIT
  Result := Format('%s LIMIT %d OFFSET %d', [ASQL, AFetch, AOffset]);
end;

end.
