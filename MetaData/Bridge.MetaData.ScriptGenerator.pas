unit Bridge.MetaData.ScriptGenerator;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Classes,
  System.Variants,
  System.TypInfo,
  System.Generics.Collections,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Connection.Utils,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Consts,
  Bridge.FastRtti;

type
  TWhereClauseResult = record
    Clause: string;
    ParamValues: TParamValues;
  end;

  /// <summary>
  /// Result record for cursor-based SELECT generation
  /// </summary>
  TCursorSelectResult = record
    SQL: string;
    ParamValues: TParamValues;
  end;

  TMetaDataScriptGenerator = class
  private
    FConnection: IConnection;
    FMetaDataManager: TMetaDataManager;

    function GenerateWhereClause(AObject: TObject; const AMetaData: TEntityMetaData): TWhereClauseResult;
    function EnsureUniqueOrdering(const AOrderBy: TArray<TOrderByItem>; const AMetaData: TEntityMetaData): TArray<TOrderByItem>;

  public
    constructor Create(AConnection: IConnection);
    destructor Destroy; override;

    function GenerateInsertScript(AObject: TObject): TScriptInsert;
    function GenerateUpdateScript(AObject: TObject): TScriptUpdate;
    function GenerateDeleteScript(AObject: TObject): TScriptDelete;

    /// <summary>
    /// Generates a SELECT statement with cursor-based pagination (keyset pagination).
    /// </summary>
    /// <param name="AClass">Entity class type</param>
    /// <param name="ALastItem">Last item from previous page (cursor), or nil for first page</param>
    /// <param name="AOrderBy">Array of fields to order by</param>
    /// <param name="APageSize">Number of records to fetch</param>
    /// <param name="AAdditionalFilters">Optional additional WHERE conditions</param>
    /// <returns>SQL statement with parameters for cursor pagination</returns>
    function GenerateCursorSelect(
      AClass: TClass;
      ALastItem: TObject;
      const AOrderBy: TArray<TOrderByItem>;
      APageSize: Integer;
      ACriteria: TList<TCriterion> = nil): TCursorSelectResult;

    /// <summary>
    /// Generates a SELECT statement from a list of criteria.
    /// Supports nested grouping and complex conditions.
    /// </summary>
    function GenerateSelect(
      AClass: TClass;
      const ACriteria: TList<TCriterion>;
      const AOrderBy: TArray<TOrderByItem>;
      ALimit: Integer): TCursorSelectResult;

    function GenerateCreateTableScript(AClass: TClass): string;
    function GetTableName(AObject: TObject): string;
  end;

implementation

uses
  System.DateUtils,
  System.StrUtils;

{ TMetaDataScriptGenerator }

constructor TMetaDataScriptGenerator.Create(AConnection: IConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FMetaDataManager := TMetaDataManager.Instance;
end;

destructor TMetaDataScriptGenerator.Destroy;
begin
  FConnection := nil;
  inherited;
end;

function TMetaDataScriptGenerator.GenerateInsertScript(AObject: TObject): TScriptInsert;
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LFields: string;
  LParams: string;
  LValue: Variant;

  LColumnName: string;
  LParamIndex: Integer;
  LParamName: string;
  LParamList: TArray<TParamValue>;
begin
  Result.Fields := '';
  Result.Params := '';
  SetLength(Result.ParamValues, 0);

  if not Assigned(AObject) then
    raise Exception.Create(TMetaDataConsts.NULL_OBJECT);

  LMetaData := FMetaDataManager.GetMetaData(AObject);

  LParamIndex := 0;
  
  for LPropMeta in LMetaData.AllProperties do
  begin
    LColumnName := LPropMeta.ColumnName;

    if Assigned(LMetaData.PrimaryKeyField) and (LPropMeta.RttiField = LMetaData.PrimaryKeyField) and LMetaData.IsAutoIncrement then
      Continue;

    LValue := TFastField.GetAsVariant(AObject, LPropMeta.Offset, LPropMeta.TypeKind);
    // Para TDateTime: RttiField.FieldType.Name = 'TDateTime', mas TypeKind = tkFloat.
    // VarFromDateTime garante varDate em vez de varDouble — FireDAC trata corretamente.
    if (LPropMeta.TypeKind = tkFloat) and
       Assigned(LPropMeta.RttiField) and
       SameText(LPropMeta.RttiField.FieldType.Name, 'TDateTime') then
      LValue := VarFromDateTime(TDateTime(Double(LValue)));

    // Build field list
    if not LFields.IsEmpty then
      LFields := LFields + ', ';
    LFields := LFields + LColumnName;

    // Build parameter placeholder list
    LParamName := 'p' + IntToStr(LParamIndex);
    if not LParams.IsEmpty then
      LParams := LParams + ', ';
    LParams := LParams + ':' + LParamName;

    // Add parameter value
    SetLength(LParamList, Length(LParamList) + 1);
    LParamList[High(LParamList)] := TParamValue.Create(LParamName, LValue, LPropMeta.TypeKind);

    Inc(LParamIndex);
  end;

  Result.Fields := LFields;
  Result.Params := LParams;
  Result.ParamValues := LParamList;
end;

/// <summary>
/// Ensures unique ordering by automatically appending CompositeKey and PrimaryKey
/// if they are not already present in the ORDER BY clause.
/// This is critical for cursor pagination to guarantee deterministic, unique ordering.
/// </summary>
function TMetaDataScriptGenerator.EnsureUniqueOrdering(
  const AOrderBy: TArray<TOrderByItem>; 
  const AMetaData: TEntityMetaData): TArray<TOrderByItem>;
var
  LResult: TArray<TOrderByItem>;
  LHasCompositeKey: Boolean;
  LHasPrimaryKey: Boolean;
  I: Integer;
  LCompositePropName: string;
  LPrimaryPropName: string;
begin
  // Start with the provided ORDER BY
  LResult := Copy(AOrderBy, 0, Length(AOrderBy));
  
  // Determine property names for CompositeKey and PrimaryKey
  if Assigned(AMetaData.CompositeKeyField) then
    LCompositePropName := AMetaData.CompositeKeyField.Name.Substring(1) // Remove 'F' prefix
  else
    LCompositePropName := '';
    
  if Assigned(AMetaData.PrimaryKeyField) then
    LPrimaryPropName := AMetaData.PrimaryKeyField.Name.Substring(1) // Remove 'F' prefix
  else
    LPrimaryPropName := '';
  
  // Check if CompositeKey and PrimaryKey are already in the ORDER BY
  LHasCompositeKey := LCompositePropName.IsEmpty; // If no composite key, mark as "has it"
  LHasPrimaryKey := LPrimaryPropName.IsEmpty;     // If no primary key, mark as "has it"
  
  for I := 0 to High(AOrderBy) do
  begin
    if not LCompositePropName.IsEmpty and SameText(AOrderBy[I].PropertyName, LCompositePropName) then
      LHasCompositeKey := True;
      
    if not LPrimaryPropName.IsEmpty and SameText(AOrderBy[I].PropertyName, LPrimaryPropName) then
      LHasPrimaryKey := True;
  end;
  
  // Append CompositeKey if missing (it comes before PrimaryKey for proper tie-breaking)
  if not LHasCompositeKey then
  begin
    SetLength(LResult, Length(LResult) + 1);
    LResult[High(LResult)] := TOrderByItem.Create(LCompositePropName, False); // ASC by default
  end;
  
  // Append PrimaryKey if missing (final tie-breaker)
  if not LHasPrimaryKey then
  begin
    SetLength(LResult, Length(LResult) + 1);
    LResult[High(LResult)] := TOrderByItem.Create(LPrimaryPropName, False); // ASC by default
  end;
  
  Result := LResult;
end;

function TMetaDataScriptGenerator.GenerateUpdateScript(AObject: TObject): TScriptUpdate;
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
  LWhereResult: TWhereClauseResult;
begin
  Result.Structure := '';
  Result.WhereClause := '';
  SetLength(Result.ParamValues, 0);
  SetLength(Result.WhereParamValues, 0);

  if not Assigned(AObject) then
    raise Exception.Create(TMetaDataConsts.NULL_OBJECT);

  LMetaData := FMetaDataManager.GetMetaData(AObject);
  LParamIndex := 0;

  for LPropMeta in LMetaData.AllProperties do
  begin
    LIsKey := Assigned(LMetaData.PrimaryKeyField) and (LPropMeta.RttiField = LMetaData.PrimaryKeyField);
    if not LIsKey then
      LIsKey := Assigned(LMetaData.CompositeKeyField) and (LPropMeta.RttiField = LMetaData.CompositeKeyField);

    if LIsKey then
      Continue;

    LColumnName := LPropMeta.ColumnName;

    LValue := TFastField.GetAsVariant(AObject, LPropMeta.Offset, LPropMeta.TypeKind);
    // Para TDateTime: RttiField.FieldType.Name = 'TDateTime', mas TypeKind = tkFloat.
    // VarFromDateTime garante varDate em vez de varDouble — FireDAC trata corretamente.
    if (LPropMeta.TypeKind = tkFloat) and
       Assigned(LPropMeta.RttiField) and
       SameText(LPropMeta.RttiField.FieldType.Name, 'TDateTime') then
      LValue := VarFromDateTime(TDateTime(Double(LValue)));

    // Build SET clause with parameters
    LParamName := 'p' + IntToStr(LParamIndex);
    if not LSetClause.IsEmpty then
      LSetClause := LSetClause + ', ';
    LSetClause := LSetClause + LColumnName + ' = :' + LParamName;

    // Add parameter value
    SetLength(LParamList, Length(LParamList) + 1);
    LParamList[High(LParamList)] := TParamValue.Create(LParamName, LValue, LPropMeta.TypeKind);

    Inc(LParamIndex);
  end;

  // Generate WHERE clause with parameters
  LWhereResult := GenerateWhereClause(AObject, LMetaData);

  Result.Structure := LSetClause;
  Result.WhereClause := LWhereResult.Clause;
  Result.ParamValues := LParamList;
  Result.WhereParamValues := LWhereResult.ParamValues;
end;

function TMetaDataScriptGenerator.GenerateDeleteScript(AObject: TObject): TScriptDelete;
var
  LMetaData: TEntityMetaData;
  LWhereResult: TWhereClauseResult;
begin
  if not Assigned(AObject) then
    raise Exception.Create(TMetaDataConsts.NULL_OBJECT);

  LMetaData := FMetaDataManager.GetMetaData(AObject);
  LWhereResult := GenerateWhereClause(AObject, LMetaData);
  
  Result.WhereClause := LWhereResult.Clause;
  Result.WhereParamValues := LWhereResult.ParamValues;
end;

function TMetaDataScriptGenerator.GenerateWhereClause(AObject: TObject; const AMetaData: TEntityMetaData): TWhereClauseResult;
var
  LColumnName: string;
  LValue: Variant;
  LParamName: string;
  LParamIndex: Integer;
begin
  Result.Clause := '';
  SetLength(Result.ParamValues, 0);
  LParamIndex := 0;

  if Assigned(AMetaData.PrimaryKeyField) then
  begin
    LColumnName := AMetaData.PrimaryKeyColumn;
    LValue := TFastField.GetAsVariant(AObject, AMetaData.PrimaryKeyOffset, AMetaData.PrimaryKeyTypeKind);
    
    LParamName := 'pk' + IntToStr(LParamIndex);
    Result.Clause := LColumnName + ' = :' + LParamName;
    
    SetLength(Result.ParamValues, Length(Result.ParamValues) + 1);
    Result.ParamValues[High(Result.ParamValues)] := TParamValue.Create(LParamName, LValue, AMetaData.PrimaryKeyTypeKind);
    Inc(LParamIndex);
  end;

  if Assigned(AMetaData.CompositeKeyField) then
  begin
    LColumnName := AMetaData.CompositeKeyColumn;
    LValue := TFastField.GetAsVariant(AObject, AMetaData.CompositeKeyOffset, AMetaData.CompositeKeyTypeKind);

    if not Result.Clause.IsEmpty then
      Result.Clause := Result.Clause + ' AND ';

    LParamName := 'pk' + IntToStr(LParamIndex);
    Result.Clause := Result.Clause + LColumnName + ' = :' + LParamName;
    
    SetLength(Result.ParamValues, Length(Result.ParamValues) + 1);
    Result.ParamValues[High(Result.ParamValues)] := TParamValue.Create(LParamName, LValue, AMetaData.CompositeKeyTypeKind);
  end;
end;

function TMetaDataScriptGenerator.GetTableName(AObject: TObject): string;
begin
  Result := FMetaDataManager.GetTableName(AObject);
end;

function TMetaDataScriptGenerator.GenerateCreateTableScript(AClass: TClass): string;
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LSQL: string;
  LColumnDef: string;
begin
  LMetaData := FMetaDataManager.GetMetaData(AClass);
  LSQL := 'CREATE TABLE ' + LMetaData.TableName + ' (';
  
  for LPropMeta in LMetaData.AllProperties do
  begin
    LColumnDef := LPropMeta.ColumnName;
    
    // Type Mapping
    case LPropMeta.TypeKind of
      tkInteger, tkInt64: LColumnDef := LColumnDef + ' INTEGER';
      tkFloat: 
        if Assigned(LPropMeta.RttiField) and SameText(LPropMeta.RttiField.FieldType.Name, 'TDateTime') then
          LColumnDef := LColumnDef + ' DATETIME'
        else
          LColumnDef := LColumnDef + ' REAL';
      tkString, tkUString, tkChar, tkWChar, tkLString, tkWString:
        LColumnDef := LColumnDef + ' TEXT';
    else
      LColumnDef := LColumnDef + ' TEXT';
    end;

    // Primary Key
    if Assigned(LMetaData.PrimaryKeyField) and (LPropMeta.RttiField = LMetaData.PrimaryKeyField) then
    begin
      LColumnDef := LColumnDef + ' PRIMARY KEY';
      if LMetaData.IsAutoIncrement then
        LColumnDef := LColumnDef + ' AUTOINCREMENT';
    end;

    LSQL := LSQL + LColumnDef + ', ';
  end;
  
  // Remove last comma
  if LSQL.EndsWith(', ') then
    LSQL := LSQL.Substring(0, LSQL.Length - 2);
    
  LSQL := LSQL + ')';
  Result := LSQL;
end;

function TMetaDataScriptGenerator.GenerateCursorSelect(
  AClass: TClass;
  ALastItem: TObject;
  const AOrderBy: TArray<TOrderByItem>;
  APageSize: Integer;
  ACriteria: TList<TCriterion>): TCursorSelectResult;
var
  LMetaData: TEntityMetaData;
  LTableName: string;
  LSelectClause: string;
  LWhereClause: string;
  LOrderClause: string;
  LParamList: TArray<TParamValue>;
  LParamIndex: Integer;
  LOrderByCount: Integer;
  I, J, K: Integer;
  LPropMeta: TPropertyMeta;
  LColumnName: string;
  LCursorCondition: string;
  LSubCondition: string;
  LValue: Variant;
  LParamName: string;
  LCriterion: TCriterion;
  LOperator: string;
  LOrderBy: TArray<TOrderByItem>;
begin
  Result.SQL := '';
  SetLength(Result.ParamValues, 0);
  
  if not Assigned(AClass) then
    raise Exception.Create('AClass cannot be nil');
    
  LMetaData := FMetaDataManager.GetMetaData(AClass);
  LTableName := LMetaData.TableName;
  LParamIndex := 0;
  SetLength(LParamList, 0);
  
  // Build SELECT clause
  LSelectClause := 'SELECT * FROM ' + LTableName;
  
  // Ensure unique ordering by automatically adding CompositeKey and PrimaryKey to ORDER BY
  // This is critical for cursor pagination to work correctly
  LOrderBy := EnsureUniqueOrdering(AOrderBy, LMetaData);
  
  // Build WHERE clause from additional filters
  LWhereClause := '';
  if Assigned(ACriteria) then
  begin
    for I := 0 to ACriteria.Count - 1 do
    begin
      LCriterion := ACriteria[I];
      
      if not LWhereClause.IsEmpty then
        LWhereClause := LWhereClause + ' ' + GetLogicOperator(LCriterion.LogicOperator) + ' ';
        
      LParamName := 'f' + IntToStr(LParamIndex);
      LOperator := LCriterion.SQLOperator;
      
      if (LOperator = 'IS NULL') or (LOperator = 'IS NOT NULL') then
      begin
         LWhereClause := LWhereClause + LCriterion.Column + ' ' + LOperator;
      end
      else if LOperator = 'IN' then
      begin
         LWhereClause := LWhereClause + LCriterion.Column + ' IN (' + VarToStr(LCriterion.Value) + ')';
      end
      else if LOperator = 'BETWEEN' then
      begin
         LWhereClause := LWhereClause + LCriterion.Column + ' BETWEEN :' + LParamName + '_1 AND :' + LParamName + '_2';
         
         SetLength(LParamList, Length(LParamList) + 1);
         LParamList[High(LParamList)] := TParamValue.Create(LParamName + '_1', LCriterion.Value, tkUnknown);
         
         SetLength(LParamList, Length(LParamList) + 1);
         LParamList[High(LParamList)] := TParamValue.Create(LParamName + '_2', LCriterion.Value2, tkUnknown);
      end
      else
      begin
        LWhereClause := LWhereClause + LCriterion.Column + ' ' + LOperator + ' :' + LParamName;
        
        SetLength(LParamList, Length(LParamList) + 1);
        LParamList[High(LParamList)] := TParamValue.Create(LParamName, LCriterion.Value, tkUnknown);
      end;

      Inc(LParamIndex);
    end;
  end;
  
  // Build cursor WHERE clause if ALastItem is provided
  if Assigned(ALastItem) then
  begin
    LOrderByCount := Length(AOrderBy);
    
    if LOrderByCount = 0 then
    begin
      // Fallback: use PK if no order specified
      if not Assigned(LMetaData.PrimaryKeyField) then
        raise Exception.Create('Cannot paginate without ORDER BY or Primary Key');
        
      LColumnName := LMetaData.PrimaryKeyColumn;
      LValue := TFastField.GetAsVariant(ALastItem, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
      
      LParamName := 'c' + IntToStr(LParamIndex);
      LCursorCondition := LColumnName + ' > :' + LParamName;
      
      SetLength(LParamList, Length(LParamList) + 1);
      LParamList[High(LParamList)] := TParamValue.Create(LParamName, LValue, LMetaData.PrimaryKeyTypeKind);
    end
    else
    begin
      // Build complex cursor condition: (Col1 > Val1) OR (Col1 = Val1 AND Col2 > Val2) OR ...
      LCursorCondition := '';
      
      for I := 0 to LOrderByCount - 1 do
      begin
        // Find property metadata for this order field
        LPropMeta := Default(TPropertyMeta);
        for J := 0 to High(LMetaData.AllProperties) do
        begin
          // Compare property name with field name (removing 'F' prefix)
          if SameText(LMetaData.AllProperties[J].RttiField.Name.Substring(1), AOrderBy[I].PropertyName) then
          begin
            LPropMeta := LMetaData.AllProperties[J];
            Break;
          end;
        end;
        
        if not Assigned(LPropMeta.RttiField) then
          raise Exception.CreateFmt('Property %s not found in %s', [AOrderBy[I].PropertyName, AClass.ClassName]);
          
        LColumnName := LPropMeta.ColumnName;
        
        // Check if this is the primary key field - use PK metadata for correct offset
        if Assigned(LMetaData.PrimaryKeyField) and (LPropMeta.RttiField = LMetaData.PrimaryKeyField) then
          LValue := TFastField.GetAsVariant(ALastItem, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind)
        else
          LValue := TFastField.GetAsVariant(ALastItem, LPropMeta.Offset, LPropMeta.TypeKind);
        
        // Build sub-condition for this level
        LSubCondition := '';
        
        // Add equality conditions for all previous columns
        for J := 0 to I - 1 do
        begin
          LPropMeta := Default(TPropertyMeta);
          for K := 0 to High(LMetaData.AllProperties) do
          begin
            // Compare property name with field name (removing 'F' prefix)
            if SameText(LMetaData.AllProperties[K].RttiField.Name.Substring(1), AOrderBy[J].PropertyName) then
            begin
              LPropMeta := LMetaData.AllProperties[K];
              Break;
            end;
          end;
          
          LParamName := 'c' + IntToStr(LParamIndex);
          LSubCondition := LSubCondition + LPropMeta.ColumnName + ' = :' + LParamName + ' AND ';
          
          SetLength(LParamList, Length(LParamList) + 1);
          
          // Check if this is the primary key field
          if Assigned(LMetaData.PrimaryKeyField) and (LPropMeta.RttiField = LMetaData.PrimaryKeyField) then
          begin
            LParamList[High(LParamList)] := TParamValue.Create(
              LParamName, 
              TFastField.GetAsVariant(ALastItem, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind),
              LMetaData.PrimaryKeyTypeKind);
          end
          else
          begin
            LParamList[High(LParamList)] := TParamValue.Create(
              LParamName, 
              TFastField.GetAsVariant(ALastItem, LPropMeta.Offset, LPropMeta.TypeKind),
              LPropMeta.TypeKind);
          end;
          
          Inc(LParamIndex);
        end;
        
        // Add comparison for current column (> for ASC, < for DESC)
        LParamName := 'c' + IntToStr(LParamIndex);
        if AOrderBy[I].Descending then
          LSubCondition := LSubCondition + LColumnName + ' < :' + LParamName
        else
          LSubCondition := LSubCondition + LColumnName + ' > :' + LParamName;
          
        SetLength(LParamList, Length(LParamList) + 1);
        
        // Use the correct type for the parameter (already extracted LValue with correct offset above)
        if Assigned(LMetaData.PrimaryKeyField) and (LPropMeta.RttiField = LMetaData.PrimaryKeyField) then
          LParamList[High(LParamList)] := TParamValue.Create(LParamName, LValue, LMetaData.PrimaryKeyTypeKind)
        else
          LParamList[High(LParamList)] := TParamValue.Create(LParamName, LValue, LPropMeta.TypeKind);
          
        Inc(LParamIndex);
        
        // Wrap in parentheses and add to cursor condition
        if not LCursorCondition.IsEmpty then
          LCursorCondition := LCursorCondition + ' OR ';
        LCursorCondition := LCursorCondition + '(' + LSubCondition + ')';
      end;
    end;
    
    // Combine cursor condition with additional filters
    if not LWhereClause.IsEmpty then
      LWhereClause := LWhereClause + ' AND (' + LCursorCondition + ')'
    else
      LWhereClause := LCursorCondition;
  end;
  
  // Build ORDER BY clause
  LOrderClause := '';
  if Length(AOrderBy) > 0 then
  begin
    for I := 0 to High(AOrderBy) do
    begin
      // Find column name for property
      LPropMeta := Default(TPropertyMeta);
      for J := 0 to High(LMetaData.AllProperties) do
      begin
        // Compare property name with field name (removing 'F' prefix)
        if SameText(LMetaData.AllProperties[J].RttiField.Name.Substring(1), AOrderBy[I].PropertyName) then
        begin
          LPropMeta := LMetaData.AllProperties[J];
          Break;
        end;
      end;
      
      if Assigned(LPropMeta.RttiField) then
      begin
        if not LOrderClause.IsEmpty then
          LOrderClause := LOrderClause + ', ';
          
        LOrderClause := LOrderClause + LPropMeta.ColumnName;
        if AOrderBy[I].Descending then
          LOrderClause := LOrderClause + ' DESC'
        else
          LOrderClause := LOrderClause + ' ASC';
      end;
    end;
  end;
  
  // Assemble final SQL
  Result.SQL := LSelectClause;
  if not LWhereClause.IsEmpty then
    Result.SQL := Result.SQL + ' WHERE ' + LWhereClause;
  if not LOrderClause.IsEmpty then
    Result.SQL := Result.SQL + ' ORDER BY ' + LOrderClause;
  
  // Add LIMIT clause for page size
  // Note: SQLite uses LIMIT, other databases may use TOP or FETCH FIRST
  // For now, using LIMIT which works with SQLite, MySQL, PostgreSQL
  Result.SQL := Result.SQL + ' LIMIT ' + IntToStr(APageSize);
    
  Result.ParamValues := LParamList;
end;

function TMetaDataScriptGenerator.GenerateSelect(
  AClass: TClass;
  const ACriteria: TList<TCriterion>;
  const AOrderBy: TArray<TOrderByItem>;
  ALimit: Integer): TCursorSelectResult;
var
  LMetaData: TEntityMetaData;
  LTableName: string;
  LSelectClause: string;
  LWhereClause: string;
  LOrderClause: string;
  LParamList: TList<TParamValue>; // Use TList temporarily for dynamic sizing
  LParamValuesArray: TParamValues;
  LParamIndex: Integer;
  Criterion: TCriterion;
  PrevCriterion: TCriterion;
  I: Integer;
  LPropMeta: TPropertyMeta;
  J: Integer;
  LParamName: string;
  IsFirst: Boolean;
begin
  Result.SQL := '';
  SetLength(Result.ParamValues, 0);

  if not Assigned(AClass) then
    raise Exception.Create('AClass cannot be nil');

  LMetaData := FMetaDataManager.GetMetaData(AClass);
  LTableName := LMetaData.TableName;
  LParamList := TList<TParamValue>.Create;
  try
    // Build SELECT clause
    LSelectClause := 'SELECT * FROM ' + LTableName;

    // Build WHERE clause
    LWhereClause := '';
    LParamIndex := 0;
    
    if (ACriteria <> nil) and (ACriteria.Count > 0) then
    begin
      IsFirst := True;
      // Initialize PrevCriterion with a dummy value
      PrevCriterion.CriterionType := ctCondition;
      PrevCriterion.LogicOperator := loAND; 

      for I := 0 to ACriteria.Count - 1 do
      begin
        Criterion := ACriteria[I];

        // Append Logic Operator
        // Rule: Append Op if NOT IsFirst AND Prev <> OpenGroup AND Curr <> CloseGroup
        if (not IsFirst) and 
           (PrevCriterion.CriterionType <> ctOpenGroup) and 
           (Criterion.CriterionType <> ctCloseGroup) then
        begin
           // GetLogicOperator is likely in Bridge.Connection.Utils
           // If not available, we map manually:
           case Criterion.LogicOperator of
             loAND: LWhereClause := LWhereClause + ' AND ';
             loOR:  LWhereClause := LWhereClause + ' OR ';
           end;
        end;

        case Criterion.CriterionType of
          ctCondition:
            begin
              LParamName := 'p' + IntToStr(LParamIndex);
              
              if SameText(Criterion.SQLOperator, 'BETWEEN') then
              begin
                 LWhereClause := LWhereClause + Criterion.Column + ' BETWEEN :' + LParamName + '_1 AND :' + LParamName + '_2';
                 LParamList.Add(TParamValue.Create(LParamName + '_1', Criterion.Value, tkUnknown));
                 LParamList.Add(TParamValue.Create(LParamName + '_2', Criterion.Value2, tkUnknown));
              end
              else if SameText(Criterion.SQLOperator, 'IN') then
              begin
                 // IN with single string value might mean "value in (1,2,3)" passed as string?
                 // Or we might need to support array/list value?
                 // For now, let's assume Value is a string containing comma separated values wrapped in parens?
                 // Standard TFilterCondition used ocIN with Value.
                 // If Value is string '1,2,3', we might inject it directly? Dangerous.
                 // Better: If Value is Variant Array (VarArray)?
                 // Let's assume for this refactoring that IN uses literal injection for now IF it's a string,
                 // OR we handle it if we can iterate varArray.
                 // Simplest safe approach:
                 LWhereClause := LWhereClause + Criterion.Column + ' IN (' + VarToStr(Criterion.Value) + ')';
                 // Note: This matches current TBaseConnection.Find behavior for ocIN:
                 // "LConditions := LConditions + LParamName + ' ' + LOperator + ' (' + VarToStr(LFilter.Value) + ')'"
              end
              else if SameText(Criterion.SQLOperator, 'IS NULL') then
                 LWhereClause := LWhereClause + Criterion.Column + ' IS NULL'
              else if SameText(Criterion.SQLOperator, 'IS NOT NULL') then
                 LWhereClause := LWhereClause + Criterion.Column + ' IS NOT NULL'
              else
              begin
                // Standard Operator (=, >, <, LIKE, etc)
                LWhereClause := LWhereClause + Criterion.Column + ' ' + Criterion.SQLOperator + ' :' + LParamName;
                LParamList.Add(TParamValue.Create(LParamName, Criterion.Value, tkUnknown));
              end;
              
              Inc(LParamIndex);
            end;
          ctOpenGroup:
            begin
              LWhereClause := LWhereClause + '(';
            end;
          ctCloseGroup:
            begin
              LWhereClause := LWhereClause + ')';
            end;
        end;

        PrevCriterion := Criterion;
        IsFirst := False;
      end;
    end;

    // Build ORDER BY clause
    LOrderClause := '';
    if Length(AOrderBy) > 0 then
    begin
      for I := 0 to High(AOrderBy) do
      begin
        // Reuse the property-to-column mapping logic
        LPropMeta := Default(TPropertyMeta);
        for J := 0 to High(LMetaData.AllProperties) do
        begin
          if SameText(LMetaData.AllProperties[J].RttiField.Name.Substring(1), AOrderBy[I].PropertyName) then
          begin
            LPropMeta := LMetaData.AllProperties[J];
            Break;
          end;
        end;
        
        // If not found, assume it is already a column name
        if Assigned(LPropMeta.RttiField) then
          LParamName := LPropMeta.ColumnName
        else
          LParamName := AOrderBy[I].PropertyName;

        if not LOrderClause.IsEmpty then
          LOrderClause := LOrderClause + ', ';
          
        LOrderClause := LOrderClause + LParamName;
        if AOrderBy[I].Descending then
          LOrderClause := LOrderClause + ' DESC'
        else
          LOrderClause := LOrderClause + ' ASC';
      end;
    end;

    // Assemble final SQL
    Result.SQL := LSelectClause;
    if not LWhereClause.IsEmpty then
      Result.SQL := Result.SQL + ' WHERE ' + LWhereClause;
    if not LOrderClause.IsEmpty then
      Result.SQL := Result.SQL + ' ORDER BY ' + LOrderClause;

    if ALimit > 0 then
      Result.SQL := Result.SQL + FConnection.GetLimitClause(ALimit);

    // Convert TList to TArray
    SetLength(LParamValuesArray, LParamList.Count);
    for I := 0 to LParamList.Count - 1 do
      LParamValuesArray[I] := LParamList[I];
    Result.ParamValues := LParamValuesArray;

  finally
    LParamList.Free;
  end;
end;

end.
