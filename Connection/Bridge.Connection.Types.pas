unit Bridge.Connection.Types;

interface

uses
  System.Variants,
  System.TypInfo;

type
  /// <summary>
  /// Represents a parameter for parameterized SQL queries.
  /// Used to prevent SQL Injection by separating values from SQL text.
  /// </summary>
  TParamValue = record
    Name: string;
    Value: Variant;
    TypeKind: TTypeKind;
    constructor Create(const AName: string; AValue: Variant; ATypeKind: TTypeKind);
  end;

  TParamValues = TArray<TParamValue>;

  TScriptInsert = record
    Fields: string;
    /// <summary>
    /// SQL with parameter placeholders (e.g., ':p0, :p1, :p2')
    /// </summary>
    Params: string;
    /// <summary>
    /// Parameter values for binding
    /// </summary>
    ParamValues: TParamValues;
  end;

  TScriptUpdate = record
    /// <summary>
    /// SQL SET clause with parameter placeholders (e.g., 'Name = :p0, Age = :p1')
    /// </summary>
    Structure: string;
    /// <summary>
    /// SQL WHERE clause with parameter placeholders (e.g., 'Id = :pk0')
    /// </summary>
    WhereClause: string;
    /// <summary>
    /// Parameter values for SET clause
    /// </summary>
    ParamValues: TParamValues;
    /// <summary>
    /// Parameter values for WHERE clause (primary/composite key)
    /// </summary>
    WhereParamValues: TParamValues;
  end;

  TScriptDelete = record
    /// <summary>
    /// SQL WHERE clause with parameter placeholders
    /// </summary>
    WhereClause: string;
    /// <summary>
    /// Parameter values for WHERE clause
    /// </summary>
    WhereParamValues: TParamValues;
  end;

  TComparisonOperator = (coEqual, coGreater, coLess, coNotEqual, coLike, coIN,
    coBetween, coGreaterEqual, coLessEqual, coIsNull, coIsNotNull);
  TLogicOperator = (loAND, loOR);

  TCriterionType = (ctCondition, ctOpenGroup, ctCloseGroup);

  TCriterion = record
    CriterionType: TCriterionType;
    Column: string;
    Value: Variant;
    Value2: Variant; // For BETWEEN
    SQLOperator: string;
    LogicOperator: TLogicOperator;
    constructor Create(const AColumn, ASQLOperator: string; AValue: Variant; ALogic: TLogicOperator = loAND); overload;
    constructor Create(const AColumn, ASQLOperator: string; AValue, AValue2: Variant; ALogic: TLogicOperator = loAND); overload;
    constructor Create(const AColumn: string; AOperator: TComparisonOperator; AValue: Variant; ALogic: TLogicOperator = loAND); overload;
    constructor Create(const AColumn: string; AOperator: TComparisonOperator; AValue, AValue2: Variant; ALogic: TLogicOperator = loAND); overload;
    constructor Create(AType: TCriterionType; ALogic: TLogicOperator = loAND); overload;
  end;

  /// <summary>
  /// Order by item for sorting operations
  /// </summary>
  TOrderByItem = record
    PropertyName: string;
    Descending: Boolean;
    constructor Create(const APropertyName: string; ADescending: Boolean = False);
  end;

  /// <summary>
  /// Represents a database command with SQL and parameters
  /// </summary>
  TDBCommand = record
    SQL: string;
    Params: TParamValues;
  end;

  /// <summary>
  /// Result record for paginated queries
  /// </summary>
  TPaginationResult = record
    TotalRecords: Integer;
    TotalPages: Integer;
    CurrentPage: Integer;
    PageSize: Integer;
    HasNextPage: Boolean;
    HasPreviousPage: Boolean;
    function Create(ATotalRecords, ACurrentPage, APageSize: Integer): TPaginationResult;
  end;

implementation

{ TParamValue }

constructor TParamValue.Create(const AName: string; AValue: Variant; ATypeKind: TTypeKind);
begin
  Name := AName;
  Value := AValue;
  TypeKind := ATypeKind;
end;

{ TOrderByItem }

constructor TOrderByItem.Create(const APropertyName: string; ADescending: Boolean);
begin
  PropertyName := APropertyName;
  Descending := ADescending;
end;

{ TCriterion }

function ComparisonOperatorToSQL(const AOperator: TComparisonOperator): string;
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
  else
    Result := '=';
  end;
end;

constructor TCriterion.Create(const AColumn, ASQLOperator: string; AValue: Variant;
  ALogic: TLogicOperator);
begin
  CriterionType := ctCondition;
  Column := AColumn;
  SQLOperator := ASQLOperator;
  Value := AValue;
  Value2 := Null;
  LogicOperator := ALogic;
end;

constructor TCriterion.Create(const AColumn, ASQLOperator: string; AValue,
  AValue2: Variant; ALogic: TLogicOperator);
begin
  CriterionType := ctCondition;
  Column := AColumn;
  SQLOperator := ASQLOperator;
  Value := AValue;
  Value2 := AValue2;
  LogicOperator := ALogic;
end;

constructor TCriterion.Create(const AColumn: string; AOperator: TComparisonOperator;
  AValue: Variant; ALogic: TLogicOperator);
begin
  Create(AColumn, ComparisonOperatorToSQL(AOperator), AValue, ALogic);
end;

constructor TCriterion.Create(const AColumn: string; AOperator: TComparisonOperator;
  AValue, AValue2: Variant; ALogic: TLogicOperator);
begin
  Create(AColumn, ComparisonOperatorToSQL(AOperator), AValue, AValue2, ALogic);
end;

constructor TCriterion.Create(AType: TCriterionType; ALogic: TLogicOperator);
begin
  CriterionType := AType;
  LogicOperator := ALogic;
  Column := '';
  SQLOperator := '';
  Value := Null;
  Value2 := Null;
end;

{ TPaginationResult }

function TPaginationResult.Create(ATotalRecords, ACurrentPage, APageSize: Integer): TPaginationResult;
begin
  Result.TotalRecords := ATotalRecords;
  Result.CurrentPage := ACurrentPage;
  Result.PageSize := APageSize;

  if APageSize > 0 then
    Result.TotalPages := (ATotalRecords + APageSize - 1) div APageSize
  else
    Result.TotalPages := 0;

  Result.HasPreviousPage := ACurrentPage > 1;
  Result.HasNextPage := ACurrentPage < Result.TotalPages;
end;

end.
