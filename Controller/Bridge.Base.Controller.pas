unit Bridge.Base.Controller;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  System.Variants,
  System.Threading,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Option,
  Bridge.MetaData.Validation.Helper,
  Bridge.Connection.Types,
  Bridge.Connection.Interfaces,
  Bridge.Model.Interfaces,
  Bridge.Controller.Interfaces,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Mapper,
  Bridge.MetaData.Types,
  Bridge.MetaData.EntityInitializer,
  Bridge.Lazy,
  Bridge.Base.Model,
  Bridge.FastRtti,
  Bridge.RttiHelper,
  Bridge.Controller.Registry,
  Bridge.Controller.Errors;

type

  TAuditUser = record
    UserId: string;
    UserName: string;
  end;

  /// <summary>
  /// Base Controller class with common CRUD logic.
  /// Supports both Model injection and standalone usage.
  /// </summary>
  TBaseController = class(TInterfacedObject, IController)
  protected
    FModel: IModel;
    FContext: TRttiContext;
    FEntityClass: TClass;
    FAuditUser: TAuditUser;
    
    function allowsInsert(Sender: TObject): TValidate; virtual;
    function allowsUpdate(Sender: TObject): TValidate; virtual;
    function allowsDelete(Sender: TObject): TValidate; virtual;
    
    function GetCustomId(Sender: TObject): Variant; virtual;
    procedure EnsureId(Sender: TObject); virtual;
    procedure SetConnection(AConnection: IConnection); virtual;

    /// <summary>
    /// Sets default field values before Insert.
    /// Override this method to set common fields like CreatedAt, UserId, CompanyId.
    /// </summary>
    /// <param name="Sender">Entity object to set default values</param>
    procedure SetDefaultFields(Sender: TObject); virtual;

    /// <summary>
    /// Initializes lazy-loaded properties based on [BelongsTo] and [HasMany] attributes.
    /// Called automatically after Load.
    /// </summary>
    procedure InitializeLazyProperties(Sender: TObject); virtual;

    /// <summary>
    /// Non-generic method to load a list of entities.
    /// Implementation discovers the item type from the list using RTTI and calls LoadAllByClass.
    /// Used internally by lazy loading and for dynamic loading (e.g. Audit Logs).
    /// </summary>
    function LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean; virtual;

    { Internal helpers - Delegated to TDataMapper }
    function PrepareFieldMapping(ADataSet: TDataSet; AMetaData: TEntityMetaData): Bridge.MetaData.Mapper.TFieldMappingList;
    procedure MapDataSetToEntity(AEntity: TObject; AMappings: Bridge.MetaData.Mapper.TFieldMappingList); overload;
    procedure MapDataSetToEntity(AQuery: TDataSet; AEntity: TObject); overload;
    procedure MapDataSetToEntity(AQuery: TDataSet; AEntity: TObject; AMetaData: TEntityMetaData); overload;

  public
    // Alias for compatibility
    type TFieldMappingList = Bridge.MetaData.Mapper.TFieldMappingList;

    /// <summary>
    /// Creates a Controller with a new TModel using Singleton connection.
    /// Use for desktop applications.
    /// </summary>
    constructor Create; overload; virtual;

    /// <summary>
    /// Creates a Controller with an injected Model.
    /// Use for APIs where each request needs isolated connection.
    /// </summary>
    /// <param name="AModel">Model instance to use</param>
    constructor Create(AModel: IModel); overload; virtual;

    /// <summary>
    /// Creates a Controller with a new TModel using injected connection.
    /// Convenience constructor for APIs.
    /// </summary>
    /// <param name="AConnection">Connection to use for data access</param>
    constructor Create(AConnection: IConnection); overload; virtual;

    destructor Destroy; override;
    
    procedure SetAuditUser(const AUserId: string; const AUserName: string);

    function FindInternal(AClass: TClass; AId: Variant; ACompositeKeyValue: Integer = 0): TFDQuery;
    function FindAll(AClass: TClass; ACriteria: TList<TCriterion>): TFDQuery; overload;
    function FindAll(ACriteria: TList<TCriterion>): TFDQuery; overload;

    function Load(Sender: TObject; AId: Integer): Boolean; overload;
    function Load(Sender: TObject; AId: Int64): Boolean; overload;
    function Load(Sender: TObject; AId: String): Boolean; overload;

    function Load(Sender: TObject; AId: Integer; ACompositeKeyValue: Integer): Boolean; overload;
    function Load(Sender: TObject; AId: Int64; ACompositeKeyValue: Integer): Boolean; overload;
    function Load(Sender: TObject; AId: String; ACompositeKeyValue: Integer): Boolean; overload;

    function Find(AId: Integer): TFDQuery; overload;
    function Find(AId: Int64): TFDQuery; overload;
    function Find(AId: String): TFDQuery; overload;

    function Find(AId: Integer; ACompositeKeyValue: Integer): TFDQuery; overload;
    function Find(AId: Int64; ACompositeKeyValue: Integer): TFDQuery; overload;
    function Find(AId: String; ACompositeKeyValue: Integer): TFDQuery; overload;
    function Find: IQueryBuilder; overload;
    function Find<T: class, constructor>: IQueryBuilder; overload;

    function LoadAll<T: class, constructor>(AList: TObjectList<T>;
      ACriteria: TList<TCriterion>): Boolean; overload;

    function LoadNext<T: class, constructor>(
      AList: TObjectList<T>;
      ALastItem: TObject;
      APageSize: Integer;
      const AOrderBy: TArray<TOrderByItem>;
      ACriteria: TList<TCriterion> = nil): Boolean; overload;

    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;

    function GetLastId: Variant;

    // Helper support methods (exposed for TControllerHelper)


    // Interface implementation
    function GetModel: IModel;
    function GetContext: TRttiContext;

    property Model: IModel read FModel;
    property Context: TRttiContext read FContext;

    /// <summary>
    /// Restores a soft-deleted entity.
    /// </summary>
    function Insert(Sender: TObject): TValidate; virtual;
    function Update(Sender: TObject): TValidate; virtual;
    function UpdatePartial(Sender: TObject; const AFieldsToUpdate: TArray<string>): TValidate; virtual;
    function Delete(Sender: TObject): TValidate; virtual;
    function Restore(Sender: TObject): TValidate; virtual;

    function Save(Sender: TObject): TValidate; virtual;

    // Event Hooks - Override in derived controllers
    procedure BeforeInsert(Sender: TObject); virtual;
    procedure AfterInsert(Sender: TObject); virtual;
    procedure BeforeUpdate(Sender: TObject); virtual;
    procedure AfterUpdate(Sender: TObject); virtual;
    procedure BeforeDelete(Sender: TObject); virtual;
    procedure AfterDelete(Sender: TObject); virtual;
  end;

  /// <summary>
  /// Generic Controller that automatically creates the Model.
  /// Eliminates the need to implement SetModel.
  /// </summary>
  /// <typeparam name="TModelClass">Model class type (must inherit from TBaseModel)</typeparam>
  TController<TModelClass: TBaseModel, constructor> = class(TBaseController)
  protected
    /// <summary>
    /// Factory method to create the Model instance.
    /// Override this method to customize Model creation with injected connection.
    /// </summary>
    /// <param name="AConnection">Connection to use (nil for Singleton)</param>
    /// <returns>Model instance</returns>
    function CreateModel(AConnection: IConnection): IModel; virtual;

    function LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean; override;
    procedure SetConnection(AConnection: IConnection); override;

  public
    // Alias for compatibility
    type TFieldMappingList = Bridge.MetaData.Mapper.TFieldMappingList;

    /// <summary>
    /// Creates a Controller with automatically instantiated Model using Singleton.
    /// </summary>
    constructor Create; override;

    /// <summary>
    /// Creates a Controller with automatically instantiated Model using injected connection.
    /// Override CreateModel to customize Model creation with connection.
    /// </summary>
    /// <param name="AConnection">Connection to use for data access</param>
    constructor Create(AConnection: IConnection); override;

  end;

implementation

uses
  Bridge.Connection.Pool,
  Bridge.Audit,
  Bridge.Controller.QueryBuilder;

{ TBaseController }

constructor TBaseController.Create;
begin
  inherited Create;
  FContext := TRttiContext.Create;
  FModel := TBaseModel.Create;
end;

function TBaseController.GetModel: IModel;
begin
  Result := FModel;
end;

function TBaseController.GetContext: TRttiContext;
begin
  Result := FContext;
end;

constructor TBaseController.Create(AModel: IModel);
begin
  inherited Create;
  FContext := TRttiContext.Create;
  if not Assigned(AModel) then
    raise EBridgeControllerError.Create(SControllerModelNull);
  FModel := AModel;
end;

constructor TBaseController.Create(AConnection: IConnection);
begin
  inherited Create;
  FContext := TRttiContext.Create;
  SetConnection(AConnection);
end;

destructor TBaseController.Destroy;
begin
  FContext.Free;
  FModel := nil;
  inherited;
end;

function TBaseController.GetCustomId(Sender: TObject): Variant;
begin
  Result := Null;
end;

procedure TBaseController.EnsureId(Sender: TObject);
var
  LMetaData: TEntityMetaData;
  LId: Variant;
begin
  LMetaData := TMetaDataManager.Instance.GetMetaData(Sender);
  // Only if PK exists and NOT AutoIncrement
  if Assigned(LMetaData.PrimaryKeyField) and (not LMetaData.IsAutoIncrement) then
  begin
    LId := TFastField.GetAsVariant(Sender, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
    
    // Check if ID is empty/null/zero
    if (VarIsNull(LId) or VarIsEmpty(LId) or ((VarType(LId) in [varInteger, varSmallInt, varByte, varInt64]) and (LId = 0))) then
    begin
      LId := GetCustomId(Sender);
      
      // If custom ID generated, set it
      if not (VarIsNull(LId) or VarIsEmpty(LId)) then
        TFastField.SetByTypeKind(Sender, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind, LId);
    end;
  end;
end;

function TBaseController.LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean;
begin
  Result := False;
end;

function TBaseController.FindAll(AClass: TClass;
  ACriteria: TList<TCriterion>): TFDQuery;
var
  LTableName: string;
begin
  LTableName := TMetaDataManager.Instance.GetTableName(AClass);
  Result := FModel.FindAll(LTableName, ACriteria);
end;

function TBaseController.FindAll(ACriteria: TList<TCriterion>): TFDQuery;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefined);
  Result := Self.FindAll(FEntityClass, ACriteria);
end;

function TBaseController.FindInternal(AClass: TClass; AId: Variant;
  ACompositeKeyValue: Integer): TFDQuery;
var
  LCriteria: TList<TCriterion>;
  LKeyColumn: string;
  LCompanyColumn: string;
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LAdjustedId: Variant;
begin
  LCriteria := TList<TCriterion>.Create;
  try
    LMetaData := TMetaDataManager.Instance.GetMetaData(AClass);
    if Assigned(LMetaData.PrimaryKeyField) then
      LKeyColumn := LMetaData.PrimaryKeyColumn
    else
      LKeyColumn := TMetaDataManager.Instance.ResolveColumnName(AClass, TReservedVocabulary.KEY);

    LAdjustedId := AId;
    // Fix String ID to properly match Postgres numeric ID if column is numeric
    if VarIsType(AId, varString) or VarIsType(AId, varUString) or VarIsType(AId, varOleStr) then
    begin
      for LPropMeta in LMetaData.AllProperties do
      begin
        if SameText(LPropMeta.ColumnName, LKeyColumn) then
        begin
          if LPropMeta.TypeKind in [tkInteger, tkInt64] then
            LAdjustedId := StrToIntDef(VarToStr(AId), 0);
          Break;
        end;
      end;
    end;

    LCriteria.Add(TCriterion.Create(LKeyColumn, '=', LAdjustedId));

    if ACompositeKeyValue > 0 then
    begin
      LCompanyColumn := TMetaDataManager.Instance.ResolveColumnName(AClass, TReservedVocabulary.COMPOSITE_KEY);
      LCriteria.Add(TCriterion.Create(LCompanyColumn, '=', ACompositeKeyValue));
    end;

    Result := Self.FindAll(AClass, LCriteria);
  finally
    LCriteria.Free;
  end;
end;

function TBaseController.GetLastId: Variant;
begin
  Result := FModel.GetLastId;
end;

function TBaseController.allowsUpdate(Sender: TObject): TValidate;
var
  LResult: TValidationResult;
begin
  LResult := TValidationHelper.ValidateRequiredFields(Sender);
  if not LResult.IsValid then
  begin
    Result.Sucess := False;
    Result.Message := LResult.ToString;
    Exit;
  end;

  LResult := TValidationHelper.ValidateFieldLengths(Sender);
  Result.Sucess := LResult.IsValid;
  Result.Message := LResult.ToString;
end;

function TBaseController.allowsDelete(Sender: TObject): TValidate;
begin
  Result.Sucess := True;
  Result.Message := EmptyStr;
end;

function TBaseController.allowsInsert(Sender: TObject): TValidate;
var
  LResult: TValidationResult;
begin
  LResult := TValidationHelper.ValidateRequiredFields(Sender);
  if not LResult.IsValid then
  begin
    Result.Sucess := False;
    Result.Message := LResult.ToString;
    Exit;
  end;

  LResult := TValidationHelper.ValidateFieldLengths(Sender);
  Result.Sucess := LResult.IsValid;
  Result.Message := LResult.ToString;
end;

function TBaseController.UpdatePartial(Sender: TObject; const AFieldsToUpdate: TArray<string>): TValidate;
begin
  Result := Self.allowsUpdate(Sender);
  if not Result.Sucess then
    Exit;

  try
    Self.BeforeUpdate(Sender);
    FModel.UpdatePartial(Sender, AFieldsToUpdate);
    Result.Sucess := True;
    Self.AfterUpdate(Sender);
  except
    on E: Exception do
    begin
      Result.Sucess := False;
      Result.Message := E.Message;
    end;
  end;
end;

function TBaseController.Delete(Sender: TObject): TValidate;
var
  LValidation: TValidate;
  LOldValue: TObject;
  LRefId: Variant;
begin
  LValidation := Self.allowsDelete(Sender);
  if not LValidation.Sucess then
    Exit;

  LOldValue := nil;
  try
    try
      if TAuditManager.IsAuditEnabled(Sender) then
      begin
          // For Delete, we need to capture the current state before it's gone
          // But since Sender is already loaded (presumably), we might use it.
          // However, to be safe and ensure we have DB state, let's clone or reload.
          LOldValue := TAuditManager.CloneEntity(Sender);
        // Try load by ID from Sender
        LRefId := GetCustomId(Sender);
        if VarIsNull(LRefId) or VarIsEmpty(LRefId) then
          LRefId := TFastField.GetAsVariant(Sender, TMetaDataManager.Instance.GetMetaData(Sender).PrimaryKeyOffset, TMetaDataManager.Instance.GetMetaData(Sender).PrimaryKeyTypeKind);

        if VarType(LRefId) = varString then
          Load(LOldValue, String(LRefId))
        else
          Load(LOldValue, Int64(LRefId));
    end;

      Self.BeforeDelete(Sender);
      FModel.Delete(Sender);

      if TAuditManager.IsAuditEnabled(Sender) then
        TAuditManager.CaptureAudit(FModel.Connection, Sender, 'DELETE', LOldValue, FAuditUser.UserId, FAuditUser.UserName);

      Result.Sucess := True;
      Self.AfterDelete(Sender);
    except
      on E: Exception do
      begin
        Result.Sucess := False;
        Result.Message := E.Message;
      end;
    end;
  finally
    LOldValue.Free;
  end;
end;

function TBaseController.Restore(Sender: TObject): TValidate;
begin
  // Validation for Restore
  // Ideally, Restore only makes sense if the entity is soft-deleted.
  // We can just try to restore it.

  try
    // We implicitly allow restore if we have an ID (which Update checks implicitly via SQL WHERE)
    // No specific allowsRestore hooks requested yet.
    
    FModel.Restore(Sender);
    Result.Sucess := True;
  except
    on E: Exception do
    begin
      Result.Sucess := False;
      Result.Message := E.Message;
    end;
  end;
end;

function TBaseController.Insert(Sender: TObject): TValidate;
var
  LMetaData: TEntityMetaData;
  LId: Variant;
begin
  Self.SetDefaultFields(Sender);
  Self.EnsureId(Sender);

  // Validate Mandatory PK for non-auto-increment
  LMetaData := TMetaDataManager.Instance.GetMetaData(Sender);
  if Assigned(LMetaData.PrimaryKeyField) and (not LMetaData.IsAutoIncrement) then
  begin
    LId := TFastField.GetAsVariant(Sender, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
    if (VarIsNull(LId) or VarIsEmpty(LId) or ((VarType(LId) in [varInteger, varSmallInt, varByte, varInt64]) and (LId = 0))) then
    begin
      Result.Sucess := False;
      Result.Message := Format(SControllerPKRequired, [LMetaData.PrimaryKeyColumn]);
      Exit;
    end;
  end;

  Result := Self.allowsInsert(Sender);
  if not Result.Sucess then
    Exit;

  try
    Self.BeforeInsert(Sender);
    FModel.Insert(Sender);
    
    // Capture Audit after Insert (to get the generated ID)
    if TAuditManager.IsAuditEnabled(Sender) then
      TAuditManager.CaptureAudit(FModel.Connection, Sender, 'INSERT', nil, FAuditUser.UserId, FAuditUser.UserName);
      
    Result.Sucess := True;
    Self.AfterInsert(Sender);
  except
    on E: Exception do
    begin
      Result.Sucess := False;
      Result.Message := E.Message;
    end;
  end;
end;


function TBaseController.Update(Sender: TObject): TValidate;
var
  LOldValue: TObject;
  LRefId: Variant;
  LMetaData: TEntityMetaData;
begin
  Result := Self.allowsUpdate(Sender);
  if not Result.Sucess then
    Exit;

  LOldValue := nil;
  try
    try
      if TAuditManager.IsAuditEnabled(Sender) then
      begin
        // Logic to capture OldValue
        LOldValue := TAuditManager.CloneEntity(Sender); // Create a clean instance
        LMetaData := TMetaDataManager.Instance.GetMetaData(Sender);

        if Assigned(LMetaData.PrimaryKeyField) then
        begin
           LRefId := TFastField.GetAsVariant(Sender, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
           // Try to load state from DB
           if VarType(LRefId) = varString then
             Load(LOldValue, String(LRefId))
           else
             Load(LOldValue, Int64(LRefId));
        end;
      end;

      Self.BeforeUpdate(Sender);
      FModel.Update(Sender);

      if TAuditManager.IsAuditEnabled(Sender) then
        TAuditManager.CaptureAudit(FModel.Connection, Sender, 'UPDATE', LOldValue, FAuditUser.UserId, FAuditUser.UserName);

      Result.Sucess := True;
      Self.AfterUpdate(Sender);
    except
      on E: Exception do
      begin
        Result.Sucess := False;
        Result.Message := E.Message;
      end;
    end;
  finally
    LOldValue.Free;
  end;
end;


function TBaseController.Load(Sender: TObject; AId: Integer): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(Sender) then
    Exit;

  LQuery := Self.FindInternal(Sender.ClassType, AId);
  try
    if not LQuery.IsEmpty then
    begin
      MapDataSetToEntity(LQuery, Sender);
      InitializeLazyProperties(Sender);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TBaseController.Load(Sender: TObject; AId: Int64): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(Sender) then Exit;

  LQuery := Self.FindInternal(Sender.ClassType, AId);
  try
    if not LQuery.IsEmpty then
    begin
      MapDataSetToEntity(LQuery, Sender);
      InitializeLazyProperties(Sender);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TBaseController.Load(Sender: TObject; AId: String): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(Sender) then
    Exit;

  LQuery := Self.FindInternal(Sender.ClassType, AId);
  try
    if not LQuery.IsEmpty then
    begin
      MapDataSetToEntity(LQuery, Sender);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TBaseController.Load(Sender: TObject; AId: Integer; ACompositeKeyValue: Integer): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(Sender) then Exit;

  LQuery := Self.FindInternal(Sender.ClassType, AId, ACompositeKeyValue);
  try
    if not LQuery.IsEmpty then
    begin
      MapDataSetToEntity(LQuery, Sender);
      InitializeLazyProperties(Sender);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TBaseController.Load(Sender: TObject; AId: Int64; ACompositeKeyValue: Integer): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(Sender) then
    Exit;

  LQuery := Self.FindInternal(Sender.ClassType, AId, ACompositeKeyValue);
  try
    if not LQuery.IsEmpty then
    begin
      MapDataSetToEntity(LQuery, Sender);
      InitializeLazyProperties(Sender);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TBaseController.Load(Sender: TObject; AId: String; ACompositeKeyValue: Integer): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(Sender) then
    Exit;

  LQuery := Self.FindInternal(Sender.ClassType, AId, ACompositeKeyValue);
  try
    if not LQuery.IsEmpty then
    begin
      MapDataSetToEntity(LQuery, Sender);
      InitializeLazyProperties(Sender);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TBaseController.PrepareFieldMapping(ADataSet: TDataSet; AMetaData: TEntityMetaData): TFieldMappingList;
begin
  Result := TDataMapper.PrepareFieldMapping(ADataSet, AMetaData);
end;

procedure TBaseController.MapDataSetToEntity(AEntity: TObject; AMappings: TFieldMappingList);
begin
  TDataMapper.MapDataSetToEntity(AEntity, AMappings);
end;

procedure TBaseController.MapDataSetToEntity(AQuery: TDataSet; AEntity: TObject;
  AMetaData: TEntityMetaData);
begin
  TDataMapper.MapDataSetToEntity(AQuery, AEntity, AMetaData);
end;

procedure TBaseController.MapDataSetToEntity(AQuery: TDataSet; AEntity: TObject);
var
  LMetaData: TEntityMetaData;
  LMetaManager: TMetaDataManager;
begin
  LMetaManager := TMetaDataManager.Instance;
  LMetaData := LMetaManager.GetMetaData(AEntity);

  Self.MapDataSetToEntity(AQuery, AEntity, LMetaData);
end;

procedure TBaseController.SetDefaultFields(Sender: TObject);
begin
  // Default implementation does nothing.
end;

procedure TBaseController.InitializeLazyProperties(Sender: TObject);
begin
  if not Assigned(Sender) then
    Exit;
  
  // Pass current connection to initializer for shared context in transactions
  TEntityInitializer.InitializeLazyProperties(Sender, FModel.Connection);
end;

procedure TBaseController.BeforeInsert(Sender: TObject);
begin
  // Override in derived controllers
end;

procedure TBaseController.AfterInsert(Sender: TObject);
begin
  // Override in derived controllers
end;

procedure TBaseController.BeforeUpdate(Sender: TObject);
begin
  // Override in derived controllers
end;

procedure TBaseController.AfterUpdate(Sender: TObject);
begin
  // Override in derived controllers
end;

procedure TBaseController.BeforeDelete(Sender: TObject);
begin
  // Override in derived controllers
end;

procedure TBaseController.AfterDelete(Sender: TObject);
begin
  // Override in derived controllers
end;

function TBaseController.Save(Sender: TObject): TValidate;
var
  LMetaData: TEntityMetaData;
  LIsNew: Boolean;
begin
  LMetaData := TMetaDataManager.Instance.GetMetaData(Sender);

  LIsNew := True;
  if Assigned(LMetaData.PrimaryKeyField) then
    LIsNew := TFastField.IsEmpty(Sender, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);

  if LIsNew then
    Result := Self.Insert(Sender)
  else
    Result := Self.Update(Sender);
end;

procedure TBaseController.StartTransaction;
begin
  FModel.StartTransaction;
end;

procedure TBaseController.Commit;
begin
  FModel.Commit;
end;

procedure TBaseController.Rollback;
begin
  FModel.Rollback;
end;

procedure TBaseController.SetConnection(AConnection: IConnection);
begin
  // Default implementation using base model
  // Can be overridden by generic controller to use specific model
  FModel := TBaseModel.Create(AConnection);
end;


function TBaseController.Find(AId: Integer): TFDQuery;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefinedFind);
  Result := Self.FindInternal(FEntityClass, AId);
end;

function TBaseController.Find(AId: Int64): TFDQuery;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefinedFind);
  Result := Self.FindInternal(FEntityClass, AId);
end;

function TBaseController.Find(AId: String): TFDQuery;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefinedFind);
  Result := Self.FindInternal(FEntityClass, AId);
end;

function TBaseController.Find(AId: Integer; ACompositeKeyValue: Integer): TFDQuery;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefinedFind);
  Result := Self.FindInternal(FEntityClass, AId, ACompositeKeyValue);
end;

function TBaseController.Find(AId: Int64; ACompositeKeyValue: Integer): TFDQuery;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefinedFind);
  Result := Self.FindInternal(FEntityClass, AId, ACompositeKeyValue);
end;

function TBaseController.Find(AId: String; ACompositeKeyValue: Integer): TFDQuery;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefinedFind);
  Result := Self.FindInternal(FEntityClass, AId, ACompositeKeyValue);
end;

function TBaseController.Find: IQueryBuilder;
begin
  if not Assigned(FEntityClass) then
    raise EBridgeControllerError.Create(SControllerEntityNotDefined);
  Result := TQueryBuilder.Create(FModel, FEntityClass);
end;

function TBaseController.Find<T>: IQueryBuilder;
begin
  Result := TQueryBuilder.Create(FModel, T);
end;

function TBaseController.LoadAll<T>(AList: TObjectList<T>;
  ACriteria: TList<TCriterion>): Boolean;
var
  LQuery: TFDQuery;
  LItem: T;
  LMappings: TFieldMappingList;
  LMetaData: TEntityMetaData;
  LItemObject: TObject;
begin
  Result := False;
  if not Assigned(AList) then Exit;

  LQuery := Self.FindAll(T, ACriteria);
  try
    if not LQuery.IsEmpty then
    begin
      LMetaData := TMetaDataManager.Instance.GetMetaData(T);
      LMappings := Self.PrepareFieldMapping(LQuery, LMetaData);
      try
        while not LQuery.Eof do
        begin
          LItem := T.Create;
          LItemObject := TObject(LItem); // Cast to TObject for methods
          try
            Self.MapDataSetToEntity(LItemObject, LMappings);
            Self.InitializeLazyProperties(LItemObject);
            AList.Add(LItem);
          except
            LItem.Free;
            raise;
          end;
          LQuery.Next;
        end;
      finally
        LMappings.Free;
      end;
      Result := AList.Count > 0;
    end;
  finally
    LQuery.Free;
  end;
end;

function TBaseController.LoadNext<T>(AList: TObjectList<T>;
  ALastItem: TObject; APageSize: Integer;
  const AOrderBy: TArray<TOrderByItem>;
  ACriteria: TList<TCriterion>): Boolean;
var
  LQuery: TFDQuery;
  LItem: T;
  LMappings: TFieldMappingList;
  LMetaData: TEntityMetaData;
  LItemObject: TObject;
begin
  Result := False;
  if not Assigned(AList) then Exit;

  LQuery := FModel.LoadNext(T, ALastItem, APageSize, AOrderBy, ACriteria);
  if not Assigned(LQuery) then Exit; // Model may return nil on error
  
  try
    try
      if not LQuery.IsEmpty then
      begin
        LMetaData := TMetaDataManager.Instance.GetMetaData(T);
        LMappings := Self.PrepareFieldMapping(LQuery, LMetaData);
        try
          while not LQuery.Eof do
          begin
            LItem := T.Create;
            LItemObject := TObject(LItem); // Cast to TObject for methods
            try
              Self.MapDataSetToEntity(LItemObject, LMappings);
              Self.InitializeLazyProperties(LItemObject);
              AList.Add(LItem);
            except
              LItem.Free;
              raise;
            end;
            LQuery.Next;
          end;
        finally
          LMappings.Free;
        end;
        Result := AList.Count > 0;
      end;
    except
      on E: Exception do
        raise EBridgeControllerError.CreateFmt('Error loading paginated list: %s', [E.Message]);
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TBaseController.SetAuditUser(const AUserId, AUserName: string);
begin
  FAuditUser.UserId := AUserId;
  FAuditUser.UserName := AUserName;
end;

{ TController<TModelClass> }

function TController<TModelClass>.CreateModel(AConnection: IConnection): IModel;
var
  LInstance: TObject;
begin
  if not Assigned(AConnection) then
  begin
    // No connection - use default constructor (Singleton)
    Result := TModelClass.Create;
  end
  else
  begin
    // Use RTTI to invoke constructor with IConnection parameter
    try
      LInstance := TRttiHelper.InvokeConstructorWithInterface(
        TModelClass,
        AConnection,
        TypeInfo(IConnection)
      );
      if Supports(LInstance, IModel, Result) then
        { Result is already assigned by Supports }
      else
        Result := TModelClass.Create;
    except
      // If constructor with connection not found, fall back to default
      Result := TModelClass.Create;
    end;
  end;
end;

procedure TController<TModelClass>.SetConnection(AConnection: IConnection);
begin
  FModel := CreateModel(AConnection);
end;

function TController<TModelClass>.LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean;
begin
  if AList is TObjectList<TModelClass> then
    Result := Self.LoadAll<TModelClass>(TObjectList<TModelClass>(AList), ACriteria)
  else
    Result := False;
end;

constructor TController<TModelClass>.Create;
begin
  inherited Create;
  FModel := CreateModel(IConnection(nil));
end;

constructor TController<TModelClass>.Create(AConnection: IConnection);
begin
  inherited Create;
  FContext := TRttiContext.Create;
  FModel := CreateModel(AConnection);
end;

end.
