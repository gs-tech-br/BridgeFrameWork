unit Bridge.Base.Model;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.Rtti,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Bridge.Model.Interfaces,
  Bridge.Connection.Types,
  Bridge.Connection.Interfaces,
  Bridge.MetaData.ScriptGenerator,
  Bridge.Model.Errors;

type
  TCommandType = (ctInsert, ctUpdate, ctDelete, ctCustom);

  // TTransactionCommand removed - buffering logic deprecated

  /// <summary>
  /// Base Model class for data access operations.
  /// Supports both Singleton connection (desktop) and injected connection (API).
  /// </summary>
  TBaseModel = class(TInterfacedObject, IModel)
  protected
    FLastId: Variant;
    FDataAccessObject: IConnection;

    function ExistsFieldValue(const ATableName, AFieldName, AFieldValue: string): Boolean;
    function ExistsFieldValueByID(const AId: Integer;
      const ATableName, AFieldName, AFieldValue: string): Boolean;

  strict private
    // Buffering logic removed

  public
    /// <summary>
    /// Creates a Model using the Singleton connection.
    /// Use this constructor for desktop applications.
    /// </summary>
    constructor Create; overload; virtual;

    /// <summary>
    /// Creates a Model using an injected connection.
    /// Use this constructor for APIs where each request needs isolated connection.
    /// </summary>
    /// <param name="AConnection">Connection to use for data access</param>
    constructor Create(AConnection: IConnection); overload; virtual;

    destructor Destroy; override;

    function Find(const ATableName: string; const AId: Integer): TFDQuery; virtual;
    function FindAll(const ATableName: string; const ACriteria: TList<TCriterion>): TFDQuery; virtual;
    function FindCustom(ASQL: string): TFDMemTable;
    
    /// <summary>
    /// Executes cursor-based pagination query and returns the result dataset.
    /// This is the Model layer responsibility - SQL generation and execution.
    /// </summary>
    function LoadNext(
      AClass: TClass;
      ALastItem: TObject;
      APageSize: Integer;
      const AOrderBy: TArray<TOrderByItem>;
      ACriteria: TList<TCriterion> = nil): TFDQuery; virtual;

    procedure Insert(Sender: TObject);
    procedure Update(Sender: TObject);
    procedure UpdatePartial(Sender: TObject; const AFieldsToUpdate: TArray<string>);
    procedure Delete(Sender: TObject);
    procedure Restore(Sender: TObject);

    procedure InsertBatch(const AList: TObject; AClassType: TClass);
    procedure UpdateBatch(const AList: TObject; AClassType: TClass);
    procedure DeleteBatch(const AList: TObject; AClassType: TClass);

    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;

    function GetLastId: Variant;

    /// <summary>
    /// Returns the connection used by this Model.
    /// </summary>
    function GetConnection: IConnection;
    property Connection: IConnection read GetConnection;

    class function New: IModel;
  end;

implementation

uses
  Bridge.Connection.Singleton,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.FastRtti;

{ TTransactionCommand }

// TTransactionCommand implementation removed

{ TBaseModel }

class function TBaseModel.New: IModel;
begin
  Result := Self.Create;
end;

constructor TBaseModel.Create;
begin
  // Desktop mode: use Singleton connection
  FDataAccessObject := TConnectionSingleton.GetInstance;
end;

constructor TBaseModel.Create(AConnection: IConnection);
begin
  // API mode: use injected connection
  if not Assigned(AConnection) then
    raise EBridgeModelError.Create(SModelConnectionNull);

  FDataAccessObject := AConnection;
end;

destructor TBaseModel.Destroy;
begin
  // Remove forceful rollback from Destroy.
  // This causes transactions on shared connections to abort prematurely when
  // transient models (like TDetailModel) are destroyed within a larger transaction scope.
  // Responsibility for transaction management lies with the Controller or the outer scope.
  //
  // if InTransaction then
  //   Rollback;

  FDataAccessObject := nil;
  inherited;
end;

// Buffering methods removed

procedure TBaseModel.StartTransaction;
begin
  if InTransaction then
    raise EBridgeTransactionError.Create(SModelTransactionAlreadyActive);

  FDataAccessObject.StartTransaction;
end;

procedure TBaseModel.Commit;
begin
  if not InTransaction then
    raise EBridgeTransactionError.Create(SModelNoActiveTransaction);

  try
    FDataAccessObject.Commit;
  except
    on E: Exception do
    begin
      Rollback;
      raise EBridgeTransactionError.CreateFmt(SModelErrorCommitting, [E.Message]);
    end;
  end;
end;

procedure TBaseModel.Rollback;
begin
  if not InTransaction then
    Exit;

  FDataAccessObject.Rollback;
end;

function TBaseModel.InTransaction: Boolean;
begin
  Result := FDataAccessObject.InTransaction;
end;

// Buffering methods removed

function TBaseModel.ExistsFieldValue(const ATableName, AFieldName, AFieldValue: string): Boolean;
var
  LCriteria: TList<TCriterion>;
begin
  LCriteria := TList<TCriterion>.Create;
  try
    LCriteria.Add(TCriterion.Create(AFieldName.ToUpper, '=', AFieldValue));
    Result := FDataAccessObject.Find(ATableName, LCriteria).RecordCount > 0;
  finally
    LCriteria.Free;
  end;
end;

function TBaseModel.ExistsFieldValueByID(const AId: Integer;
  const ATableName, AFieldName, AFieldValue: string): Boolean;
var
  LCriteria: TList<TCriterion>;
  LPrimaryKey: String;
begin
  LPrimaryKey := FDataAccessObject.GetPrimaryKey(ATableName);
  LCriteria := TList<TCriterion>.Create;
  try
    LCriteria.Add(TCriterion.Create(LPrimaryKey, '=', AId.ToString));
    LCriteria.Add(TCriterion.Create(AFieldName.ToUpper, '=', AFieldValue.ToUpper));
    Result := FDataAccessObject.Find(ATableName, LCriteria).RecordCount > 0;
  finally
    LCriteria.Free;
  end;
end;

procedure TBaseModel.Insert(Sender: TObject);
begin
  FDataAccessObject.Insert(Sender, FLastId);
end;

procedure TBaseModel.InsertBatch(const AList: TObject; AClassType: TClass);
begin
  // InsertBatch uses prepared statements and should be called within a transaction
  // for optimal performance. It bypasses the command accumulation pattern since
  // it's already optimized for batch execution.
  FDataAccessObject.InsertBatch(AList, AClassType);
end;

procedure TBaseModel.UpdateBatch(const AList: TObject; AClassType: TClass);
begin
  // UpdateBatch uses prepared statements and should be called within a transaction
  // for optimal performance.
  FDataAccessObject.UpdateBatch(AList, AClassType);
end;

procedure TBaseModel.DeleteBatch(const AList: TObject; AClassType: TClass);
begin
  // DeleteBatch uses prepared statements and should be called within a transaction
  // for optimal performance.
  FDataAccessObject.DeleteBatch(AList, AClassType);
end;

procedure TBaseModel.Update(Sender: TObject);
begin
  FDataAccessObject.Update(Sender);
end;

procedure TBaseModel.UpdatePartial(Sender: TObject; const AFieldsToUpdate: TArray<string>);
begin
  FDataAccessObject.UpdatePartial(Sender, AFieldsToUpdate);
end;

procedure TBaseModel.Delete(Sender: TObject);
begin
  // Soft Delete support: if enabled for the entity, update instead of delete
  if Sender.ApplySoftDelete then
    Self.Update(Sender)
  else
    FDataAccessObject.Delete(Sender);
end;

procedure TBaseModel.Restore(Sender: TObject);
begin
  // Restore Delegation - Reverses Soft Delete
  if Sender.ApplyRestore then
  begin
    Self.Update(Sender);
  end;
  // If not soft delete enabled, Restore does nothing or could raise exception.
  // Ideally, Restore only makes sense for SoftDeletable entities.
end;

function TBaseModel.Find(const ATableName: string;
  const AId: Integer): TFDQuery;
var
  LCriteria: TList<TCriterion>;
  LPrimaryKey: String;
begin
  LPrimaryKey := FDataAccessObject.GetPrimaryKey(ATableName);
  LCriteria := TList<TCriterion>.Create;
  try
    LCriteria.Add(TCriterion.Create(LPrimaryKey, '=', AId.ToString));
    Result := FDataAccessObject.Find(ATableName, LCriteria);
  finally
    LCriteria.Free;
  end;
end;

function TBaseModel.FindAll(const ATableName: string; const ACriteria: TList<TCriterion>): TFDQuery;
begin
  Result := FDataAccessObject.Find(ATableName, ACriteria);
end;

function TBaseModel.FindCustom(ASQL: string): TFDMemTable;
var
  Query: TFDQuery;
begin
  Query := FDataAccessObject.CreateDataSet(ASQL);
  try
    try
      Query.Open;
      Result := FDataAccessObject.CreateTempTable(Query);
    except
      on E: Exception do
        raise EBridgeModelError.CreateFmt(SModelFindCustomError, [E.Message]);
    end;
  finally
    FreeAndNil(Query);
  end;
end;

function TBaseModel.LoadNext(
  AClass: TClass;
  ALastItem: TObject;
  APageSize: Integer;
  const AOrderBy: TArray<TOrderByItem>;
  ACriteria: TList<TCriterion> = nil): TFDQuery;
var
  LScriptGenerator: TMetaDataScriptGenerator;
  LCursorResult: TCursorSelectResult;
  LCommand: TDBCommand;
  I: Integer;
begin
  Result := nil;
  
  if not Assigned(AClass) then
    raise EBridgeModelError.Create('AClass cannot be nil');
    
  LScriptGenerator := TMetaDataScriptGenerator.Create(FDataAccessObject);
  try
    // Generate cursor-based SELECT
    LCursorResult := LScriptGenerator.GenerateCursorSelect(
      AClass,
      ALastItem,
      AOrderBy,
      APageSize,
      ACriteria);
    
    // Build command
    LCommand.SQL := LCursorResult.SQL;
    LCommand.Params := LCursorResult.ParamValues;
    
    // Execute query
    Result := FDataAccessObject.CreateDataSet(LCommand.SQL);
    try
      // Bind parameters
      for I := 0 to High(LCommand.Params) do
      begin
        Result.ParamByName(LCommand.Params[I].Name).Value := LCommand.Params[I].Value;
      end;
      
      Result.Open;
    except
      on E: Exception do
      begin
        FreeAndNil(Result);
        raise EBridgeModelError.CreateFmt('Error executing cursor pagination: %s', [E.Message]);
      end;
    end;
  finally
    LScriptGenerator.Free;
  end;
end;

function TBaseModel.GetLastId: Variant;
begin
  Result := FLastId;
end;

function TBaseModel.GetConnection: IConnection;
begin
  Result := FDataAccessObject;
end;

end.
