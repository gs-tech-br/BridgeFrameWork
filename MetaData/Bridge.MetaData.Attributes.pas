unit Bridge.MetaData.Attributes;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.Variants,
  System.Generics.Collections;

type
  /// <summary>
  /// Attribute to mark a class as an database entity (table mapping).
  /// </summary>
  EntityAttribute = class(TCustomAttribute)
  private
    FTableName: string;
  public
    constructor Create(const ATableName: string);
    property TableName: string read FTableName;
  end;

  /// <summary>
  /// Attribute to mark a property as primary key.
  /// </summary>
  IdAttribute = class(TCustomAttribute)
  private
    FAutoIncrement: Boolean;
  public
    constructor Create(AAutoIncrement: Boolean = True);
    property AutoIncrement: Boolean read FAutoIncrement;
  end;

  /// <summary>
  /// Attribute to mark a property as part of a composite key.
  /// </summary>
  CompositeKeyAttribute = class(TCustomAttribute)
    constructor Create;
  end;

  /// <summary>
  /// Attribute to map a property to a database column with specific options.
  /// </summary>
  ColumnAttribute = class(TCustomAttribute)
  private
    FColumnName: string;
    FSize: Integer;
    FNullable: Boolean;
  public
    constructor Create(const AColumnName: string; ASize: Integer = 0; ANullable: Boolean = True);
    property ColumnName: string read FColumnName;
    property Size: Integer read FSize;
    property Nullable: Boolean read FNullable;
  end;

  /// <summary>
  /// Attribute to ignore a property during database mapping.
  /// The property will not be included in Insert/Update/Select operations.
  /// </summary>
  IgnoreAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  /// Marks a property as a lazy-loaded reference to another entity (N:1).
  /// The referenced entity is loaded on first access.
  /// </summary>
  /// <example>
  /// [BelongsTo('IdCliente')]  // FK column in this table
  /// property Cliente: TCliente read GetCliente;
  /// </example>
  BelongsToAttribute = class(TCustomAttribute)
  private
    FForeignKeyColumn: string;
  public
    /// <param name="AForeignKeyColumn">Name of the FK column in the current table</param>
    constructor Create(const AForeignKeyColumn: string);
    property ForeignKeyColumn: string read FForeignKeyColumn;
  end;

  /// <summary>
  /// Marks a property as a lazy-loaded collection of child entities (1:N).
  /// The collection is loaded on first access.
  /// </summary>
  /// <example>
  /// [HasMany('IdPedido')]  // FK column in child table
  /// property Itens: TObjectList<TItemPedido> read GetItens;
  /// </example>
  HasManyAttribute = class(TCustomAttribute)
  private
    FForeignKeyColumn: string;
  public
    /// <param name="AForeignKeyColumn">Name of the FK column in the child table</param>
    constructor Create(const AForeignKeyColumn: string);
    property ForeignKeyColumn: string read FForeignKeyColumn;
  end;

  CaptionAttribute = class(TCustomAttribute)
  private
    FCaption: string;
  public
    constructor Create(const ACaption: string);
    property Caption: string read FCaption;
  end;

  /// <summary>
  /// Attribute to mark an entity for soft delete behavior.
  /// When soft-deleted, the specified field is set to the delete value instead of removing the record.
  /// </summary>
  SoftDeleteAttribute = class(TCustomAttribute)
  private
    FFieldName: string;
    FDeleteValue: Variant;
    FRestoreValue: Variant;
  public
    /// <param name="AFieldName">Column/Property name that controls soft delete</param>
    /// <param name="ADeleteValue">Value to set when soft-deleting</param>
    /// <param name="ARestoreValue">Value to set when restoring (default: empty/null)</param>
    constructor Create(const AFieldName: string; const ADeleteValue: Variant; const ARestoreValue: Variant); overload;
    constructor Create(const AFieldName: string; const ADeleteValue: Variant); overload;
    
    // Constructors for Field/Property usage (FieldName inferred)
    constructor Create(const ADeleteValue: Variant; const ARestoreValue: Variant); overload;
    constructor Create(const ADeleteValue: Variant); overload;
    
    // Explicit Integer constructors to avoid Variant RTTI issues
    constructor Create(const ADeleteValue: Integer; const ARestoreValue: Integer); overload;
    constructor Create(const ADeleteValue: Integer); overload;
    property FieldName: string read FFieldName;
    property DeleteValue: Variant read FDeleteValue;
    property RestoreValue: Variant read FRestoreValue;
  end;

  /// <summary>
  /// Attribute to enable automatic audit logging for an entity.
  /// </summary>
  AuditAttribute = class(TCustomAttribute)
  end;

  TAggregationOptions = (taNone, taMax, taCount, taSum, taAvg);

  FormatOptionsAttribute = class(TCustomAttribute)
  private
    FKind: TTypeKind;
    FFormat: string;
    FAggregation: TAggregationOptions;
    FVisible: Boolean;
    FEditing: Boolean;
  public
    constructor Create(
      AKind: TTypeKind;
      const AFormat: string = '';
      AAggregation: TAggregationOptions = taNone;
      AVisible: Boolean = True;
      AEditing: Boolean = False);

    property Kind: TTypeKind read FKind;
    property Format: string read FFormat;
    property Aggregation: TAggregationOptions read FAggregation;
    property Visible: Boolean read FVisible;
    property Editing: Boolean read FEditing;
  end;

  TPropertyMeta = record
    RttiField: TRttiField;       
    Offset: Integer;             
    TypeKind: TTypeKind;         
    ColumnName: string;
    IsRequired: Boolean;
    MaxLength: Integer;
  end;

  /// <summary>
  /// Record for soft delete metadata
  /// </summary>
  TSoftDeleteMeta = record
    Enabled: Boolean;
    FieldName: string;
    Offset: Integer;
    TypeKind: TTypeKind;
    DeleteValue: Variant;
    RestoreValue: Variant;
  end;

  // Record for class metadata cache (Entity)
  TEntityMetaData = record
    TableName: string;

    // Primary Key 
    PrimaryKeyField: TRttiField;
    PrimaryKeyOffset: Integer;
    PrimaryKeyTypeKind: TTypeKind;
    PrimaryKeyColumn: string;
    IsAutoIncrement: Boolean;

    // Composite Key 
    CompositeKeyField: TRttiField;
    CompositeKeyOffset: Integer;
    CompositeKeyTypeKind: TTypeKind;
    CompositeKeyColumn: string;

    // Soft Delete support
    SoftDelete: TSoftDeleteMeta;

    // Optimized lists for iteration
    AllProperties: TArray<TPropertyMeta>;
    RequiredProperties: TArray<TPropertyMeta>;
    LengthProperties: TArray<TPropertyMeta>;

    // Dictionary for fast lookup by property name
    ColumnMappings: TDictionary<string, string>;

    // Audit support
    AuditEnabled: Boolean;
  end;

implementation

{ EntityAttribute }

constructor EntityAttribute.Create(const ATableName: string);
begin
  inherited Create;
  FTableName := ATableName;
end;

{ IdAttribute }

constructor IdAttribute.Create(AAutoIncrement: Boolean);
begin
  inherited Create;
  FAutoIncrement := AAutoIncrement;
end;

{ ColumnAttribute }

constructor ColumnAttribute.Create(const AColumnName: string; ASize: Integer; ANullable: Boolean);
begin
  inherited Create;
  FColumnName := AColumnName;
  FSize := ASize;
  FNullable := ANullable;
end;

{ CompositeKeyAttribute }

constructor CompositeKeyAttribute.Create;
begin
  inherited Create;
end;

{ CaptionAttribute }

constructor CaptionAttribute.Create(const ACaption: string);
begin
  inherited Create;
  FCaption := ACaption;
end;

{ FormatOptionsAttribute }

constructor FormatOptionsAttribute.Create(
  AKind: TTypeKind;
  const AFormat: string = '';
  AAggregation: TAggregationOptions = taNone;
  AVisible: Boolean = True;
  AEditing: Boolean = False);
begin
  inherited Create;
  FKind := AKind;
  FFormat := AFormat;
  FAggregation := AAggregation;
  FVisible := AVisible;
  FEditing := AEditing;
end;

{ SoftDeleteAttribute }

constructor SoftDeleteAttribute.Create(const AFieldName: string;
  const ADeleteValue: Variant; const ARestoreValue: Variant);
begin
  inherited Create;
  FFieldName := AFieldName;
  FDeleteValue := ADeleteValue;
  FRestoreValue := ARestoreValue;
end;

constructor SoftDeleteAttribute.Create(const AFieldName: string;
  const ADeleteValue: Variant);
begin
  inherited Create;
  FFieldName := AFieldName;
  FDeleteValue := ADeleteValue;
  FRestoreValue := Null;
end;

constructor SoftDeleteAttribute.Create(const ADeleteValue: Variant;
  const ARestoreValue: Variant);
begin
  inherited Create;
  FFieldName := ''; // Inferred from attached field
  FDeleteValue := ADeleteValue;
  FRestoreValue := ARestoreValue;
end;

constructor SoftDeleteAttribute.Create(const ADeleteValue: Variant);
begin
  inherited Create;
  FFieldName := ''; // Inferred from attached field
  FDeleteValue := ADeleteValue;
  FRestoreValue := Null;
end;

constructor SoftDeleteAttribute.Create(const ADeleteValue: Integer;
  const ARestoreValue: Integer);
begin
  inherited Create;
  FFieldName := ''; 
  FDeleteValue := ADeleteValue;
  FRestoreValue := ARestoreValue;
end;

constructor SoftDeleteAttribute.Create(const ADeleteValue: Integer);
begin
  inherited Create;
  FFieldName := '';
  FDeleteValue := ADeleteValue;
  FRestoreValue := Null;
end;

{ BelongsToAttribute }

constructor BelongsToAttribute.Create(const AForeignKeyColumn: string);
begin
  inherited Create;
  FForeignKeyColumn := AForeignKeyColumn;
end;

{ HasManyAttribute }

constructor HasManyAttribute.Create(const AForeignKeyColumn: string);
begin
  inherited Create;
  FForeignKeyColumn := AForeignKeyColumn;
end;

end.
