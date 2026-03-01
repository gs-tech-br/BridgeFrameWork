unit Bridge.Connection.Base;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Comp.UI,
  FireDAC.DApt,
  FireDAC.Phys,
  FireDAC.Stan.Async,
  FireDAC.Stan.Def,
  FireDAC.Stan.Param,
  FireDAC.Stan.Pool,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Connection.Data,
  Bridge.Driver.Config,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.MetaData.ScriptGenerator,
  Bridge.Connection.Log.Manager,
  Bridge.FastRtti,
  Bridge.Connection.Utils,
  Bridge.Connection.Generator.Interfaces;

type
  TBaseConnection = class;
  TConnectionClass = class of TBaseConnection;
  
  TBaseConnection = class(TInterfacedObject, IConnection)
  protected
    FConnection: TFDConnection;
    FWaitCursor: TFDGUIxWaitCursor;
    FCacheColumns: TObjectDictionary<string, TStringList>;
    FCachePK: TDictionary<string, string>;
    FCredentials: IConnectionCredentialsProvider;
    FDriverConfig: IDriverConfigProvider;
    FMetaDataGenerator: TMetaDataScriptGenerator;
    FSQLGenerator: ISQLGenerator;

    // Abstract methods to be implemented by child classes
    function CreateConnection: TFDConnection; virtual; abstract;
    procedure ConfigureDriver; virtual; abstract;

    // Helper methods available to child classes
    function CreateQuery(const ASQL: string; const AParams: TParamValues = nil): TFDQuery;
    procedure ApplyParams(AQuery: TFDQuery; const AParams: TParamValues);
    procedure OnDataSetBeforeOpen(DataSet: TDataSet);
    procedure OnDataSetAfterOpen(DataSet: TDataSet);

  public
    constructor Create; overload;
    constructor Create(ACredentials: IConnectionCredentialsProvider); overload;
    constructor Create(ACredentials: IConnectionCredentialsProvider; 
      ADriverConfig: IDriverConfigProvider;
      ASQLGenerator: ISQLGenerator = nil); overload; virtual;
    destructor Destroy; override;

    // IConnection implementation
    function getConnection: TFDConnection;
    function CreateTempTable(Sender: TFDQuery): TFDMemTable;
    function CreateDataSet(const ASQLValue: string): TFDQuery; virtual;
    
    // Abstract/Virtual methods specific to each database
    function getSeq(const ATable, AColumnName: string): Variant; virtual; abstract;
    function getId(const ATable: string): Integer; virtual; abstract;
    function getColumns(const ATable: string): TStringList; virtual; abstract;
    
    // Common implementations (can be overridden if needed)
    function GetPrimaryKey(const ATable: string): string; overload; virtual;
    function GetPrimaryKey(const AObject: TObject): string; overload; virtual;
    function GetQuotedTableName(const AObject: TObject): string; virtual;
    
    function Find(const ATable: string;
      ACriteria: TList<TCriterion>): TFDQuery;
      
    procedure InsertBatch(const AList: TObject; AClassType: TClass); virtual;
    procedure UpdateBatch(const AList: TObject; AClassType: TClass); virtual;
    procedure DeleteBatch(const AList: TObject; AClassType: TClass); virtual;
    
    procedure Insert(const AObject: TObject; out AId: Variant); virtual;
    procedure Update(const AObject: TObject); virtual;
    procedure UpdatePartial(const AObject: TObject; const AFieldsToUpdate: TArray<string>); virtual;
    procedure Delete(const AObject: TObject); virtual;
    
    procedure Execute(const ASQLValue: String); overload;    
    procedure Execute(const ACommand: TDBCommand); overload; virtual;
    procedure Execute(const ACommand: TDBCommand; out AValue: Variant); overload; virtual;
    procedure Execute(const ASQLValue: String; out AValue: Variant); overload;
    
    function GetInsertCommand(const AObject: TObject): TDBCommand; virtual;
    function GetUpdateCommand(const AObject: TObject): TDBCommand;
    function GetUpdatePartialCommand(const AObject: TObject; const AFieldsToUpdate: TArray<string>): TDBCommand;
    function GetDeleteCommand(const AObject: TObject): TDBCommand;
    
    procedure SetCredentials(ACredentials: IConnectionCredentialsProvider);
    
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;

    /// <summary>
    /// Returns the database-specific LIMIT clause for a given page size.
    /// Default implementation returns ' LIMIT N' (SQLite, PostgreSQL, MySQL).
    /// SQL Server connectors should override to return ' FETCH FIRST N ROWS ONLY' or use TOP.
    /// </summary>
    function GetLimitClause(const ALimit: Integer): string; virtual;
  end;

implementation

uses
  Bridge.Connection.Generator.Base;

{ TBaseConnection }

constructor TBaseConnection.Create;
begin
  Create(TConnectionData.Create, nil, nil);
end;

constructor TBaseConnection.Create(ACredentials: IConnectionCredentialsProvider);
begin
  Create(ACredentials, nil, nil);
end;

constructor TBaseConnection.Create(ACredentials: IConnectionCredentialsProvider;
  ADriverConfig: IDriverConfigProvider;
  ASQLGenerator: ISQLGenerator);
begin
  inherited Create;
  FCredentials := ACredentials;
  FDriverConfig := ADriverConfig;
  
  if Assigned(ASQLGenerator) then
    FSQLGenerator := ASQLGenerator
  else
    FSQLGenerator := TBaseSQLGenerator.Create; // Default fallback

  FMetaDataGenerator := TMetaDataScriptGenerator.Create(Self);
  FCacheColumns := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  FCachePK := TDictionary<string, string>.Create;
end;

destructor TBaseConnection.Destroy;
begin
  FCachePK.Free;
  FCacheColumns.Free;
  FMetaDataGenerator.Free;
  FConnection.Free;
  FWaitCursor.Free;
  inherited;
end;

function TBaseConnection.getConnection: TFDConnection;
begin
  Result := FConnection;
end;

function TBaseConnection.CreateDataSet(const ASQLValue: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := ASQLValue;
  Result.BeforeOpen := OnDataSetBeforeOpen;
  Result.AfterOpen := OnDataSetAfterOpen;
end;

function TBaseConnection.CreateQuery(const ASQL: string; const AParams: TParamValues): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := FConnection;
    Result.SQL.Text := ASQL;
    if Length(AParams) > 0 then
      ApplyParams(Result, AParams);
  except
    Result.Free;
    raise;
  end;
end;

function TBaseConnection.CreateTempTable(Sender: TFDQuery): TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  Result.Data := Sender.Data;
end;

procedure TBaseConnection.Execute(const ASQLValue: String);
begin
  FConnection.ExecSQL(ASQLValue);
end;

procedure TBaseConnection.Execute(const ASQLValue: String; out AValue: Variant);
var
  LQuery: TFDQuery;
begin
  LQuery := CreateDataSet(ASQLValue);
  try
    LQuery.Open;
    if not LQuery.IsEmpty then
      AValue := LQuery.Fields[0].AsVariant;
  finally
    LQuery.Free;
  end;
end;

procedure TBaseConnection.Execute(const ACommand: TDBCommand);
var
  LQuery: TFDQuery;
begin
  LQuery := CreateQuery(ACommand.SQL, ACommand.Params);
  try
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TBaseConnection.Execute(const ACommand: TDBCommand; out AValue: Variant);
var
  LQuery: TFDQuery;
begin
  LQuery := CreateQuery(ACommand.SQL, ACommand.Params);
  try
    LQuery.Open; // Default behavior assumes query returns result set (RETURNING/OUTPUT)
    if not LQuery.IsEmpty then
      AValue := LQuery.Fields[0].AsVariant;
  finally
    LQuery.Free;
  end;
end;

procedure TBaseConnection.ApplyParams(AQuery: TFDQuery; const AParams: TParamValues);
var
  I: Integer;
  LParam: TParamValue;
  LFDParam: TFDParam;
begin
  for I := 0 to Length(AParams) - 1 do
  begin
    LParam := AParams[I];
    LFDParam := AQuery.ParamByName(LParam.Name);
    // Para TDateTime (varDate), usar AsDateTime evita ambiguidade com varDouble
    if VarType(LParam.Value) = varDate then
      LFDParam.AsDateTime := VarToDateTime(LParam.Value)
    else
      LFDParam.Value := LParam.Value;
  end;
end;

function TBaseConnection.Find(const ATable: string;
  ACriteria: TList<TCriterion>): TFDQuery;
var
  LSQL: string;
  LWhere: string;
  LParamName: string;
  LCriteriaItem: TCriterion;
  LOperator: string;
  I: Integer;
begin
  LSQL := Format('SELECT * FROM %s', [ATable]);
  LWhere := '';

  if (Assigned(ACriteria)) and (ACriteria.Count > 0) then
  begin
    for I := 0 to ACriteria.Count - 1 do
    begin
      LCriteriaItem := ACriteria[I];
      LOperator := LCriteriaItem.SQLOperator;
      LParamName := 'p' + IntToStr(I);

      // Primeiro item: prefixo WHERE; demais: operador lógico do item atual
      if LWhere = '' then
        LWhere := ' WHERE '
      else
        LWhere := LWhere + GetLogicOperator(LCriteriaItem.LogicOperator);

      if SameText(LOperator, 'IN') then
        LWhere := LWhere + LCriteriaItem.Column + ' IN (' + VarToStr(LCriteriaItem.Value) + ')'
      else if SameText(LOperator, 'BETWEEN') then
        LWhere := LWhere + LCriteriaItem.Column + ' BETWEEN :' + LParamName + '_1 AND :' + LParamName + '_2'
      else if SameText(LOperator, 'IS NULL') or SameText(LOperator, 'IS NOT NULL') then
        LWhere := LWhere + LCriteriaItem.Column + ' ' + UpperCase(LOperator)
      else
        LWhere := LWhere + LCriteriaItem.Column + ' ' + LOperator + ' :' + LParamName;
    end;
    LSQL := LSQL + LWhere;
  end;

  Result := CreateDataSet(LSQL);

  if (Assigned(ACriteria)) and (ACriteria.Count > 0) then
  begin
    for I := 0 to ACriteria.Count - 1 do
    begin
      LCriteriaItem := ACriteria[I];
      LOperator := LCriteriaItem.SQLOperator;
      LParamName := 'p' + IntToStr(I);

      // Sem parâmetros para IN, IS NULL, IS NOT NULL
      if SameText(LOperator, 'IN') or
         SameText(LOperator, 'IS NULL') or
         SameText(LOperator, 'IS NOT NULL') then
        Continue;

      if SameText(LOperator, 'BETWEEN') then
      begin
        Result.ParamByName(LParamName + '_1').Value := LCriteriaItem.Value;
        Result.ParamByName(LParamName + '_2').Value := LCriteriaItem.Value2;
      end
      else if SameText(LOperator, 'LIKE') then
        Result.ParamByName(LParamName).Value := '%' + VarToStr(LCriteriaItem.Value) + '%'
      else
        Result.ParamByName(LParamName).Value := LCriteriaItem.Value;
    end;
  end;

  Result.Open;
end;

function TBaseConnection.GetPrimaryKey(const ATable: string): string;
begin
  Result := 'ID';
end;

function TBaseConnection.GetPrimaryKey(const AObject: TObject): string;
var
  LField: TRttiField;
begin
  LField := TMetaDataManager.Instance.GetPrimaryKeyField(AObject);
  if Assigned(LField) then
    Result := LField.Name.Substring(1)
  else
    Result := 'ID';
end;

function TBaseConnection.GetQuotedTableName(const AObject: TObject): string;
begin
  Result := FMetaDataGenerator.GetTableName(AObject);
end;

procedure TBaseConnection.InsertBatch(const AList: TObject; AClassType: TClass);
begin
  TBatchOperationHelper.Insert(
    FConnection,
    AList,
    AClassType,
    function(TableName: string): TStringList
    begin
      Result := Self.getColumns(TableName);
    end
  );
end;

procedure TBaseConnection.Update(const AObject: TObject);
begin
  Execute(GetUpdateCommand(AObject));
end;

procedure TBaseConnection.UpdatePartial(const AObject: TObject; const AFieldsToUpdate: TArray<string>);
begin
  Execute(GetUpdatePartialCommand(AObject, AFieldsToUpdate));
end;

procedure TBaseConnection.UpdateBatch(const AList: TObject; AClassType: TClass);
begin
  TBatchOperationHelper.Update(
    FConnection,
    AList,
    AClassType,
    function(TableName: string): TStringList
    begin
      Result := Self.getColumns(TableName);
    end
  );
end;

procedure TBaseConnection.Delete(const AObject: TObject);
begin
  Execute(GetDeleteCommand(AObject));
end;

procedure TBaseConnection.DeleteBatch(const AList: TObject; AClassType: TClass);
begin
  TBatchOperationHelper.Delete(
    FConnection,
    AList,
    AClassType
  );
end;

function TBaseConnection.GetInsertCommand(const AObject: TObject): TDBCommand;
begin
  Result := FSQLGenerator.GenerateInsert(AObject, FMetaDataGenerator);
end;

function TBaseConnection.GetUpdateCommand(const AObject: TObject): TDBCommand;
begin
  Result := FSQLGenerator.GenerateUpdate(AObject, FMetaDataGenerator);
end;

function TBaseConnection.GetUpdatePartialCommand(const AObject: TObject; const AFieldsToUpdate: TArray<string>): TDBCommand;
begin
  Result := FSQLGenerator.GenerateUpdatePartial(AObject, FMetaDataGenerator, AFieldsToUpdate);
end;

function TBaseConnection.GetDeleteCommand(const AObject: TObject): TDBCommand;
begin
  Result := FSQLGenerator.GenerateDelete(AObject, FMetaDataGenerator);
end;

procedure TBaseConnection.StartTransaction;
begin
  if InTransaction then
    raise Exception.Create('Transaction is already active');

  try
    FConnection.StartTransaction;
  except
    on E: Exception do
      raise Exception.Create('Error starting transaction: ' + E.Message);
  end;
end;

procedure TBaseConnection.Commit;
begin
  Writeln('DEBUG: TBaseConnection.Commit called. InTransaction=' + BoolToStr(InTransaction, True));
  if not InTransaction then
    raise Exception.Create('No active transaction to commit');

  try
    FConnection.Commit;
  except
    on E: Exception do
    begin
      try
        Rollback;
      except
      end;
      raise Exception.Create('Error committing transaction: ' + E.Message);
    end;
  end;
end;

procedure TBaseConnection.Rollback;
begin
  Writeln('DEBUG: TBaseConnection.Rollback called. InTransaction=' + BoolToStr(InTransaction, True));
  if not InTransaction then
    Exit;

  try
    FConnection.Rollback;
  except
    on E: Exception do
      raise Exception.Create('Error rolling back transaction: ' + E.Message);
  end;
end;

function TBaseConnection.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

function TBaseConnection.GetLimitClause(const ALimit: Integer): string;
begin
  // Default implementation for SQLite, PostgreSQL and MySQL.
  // SQL Server connectors should override to use FETCH FIRST N ROWS ONLY.
  Result := ' LIMIT ' + IntToStr(ALimit);
end;

procedure TBaseConnection.OnDataSetAfterOpen(DataSet: TDataSet);
begin
  TLogManager.GetInstance.SendDoneToConsole(DataSet);
end;

procedure TBaseConnection.OnDataSetBeforeOpen(DataSet: TDataSet);
begin
  if DataSet is TFDQuery then
  begin
    // WriteLog(TFDQuery) chama ExtractQueryLog que substitui :p0, :p1... pelos valores reais
    TLogManager.GetInstance.WriteLog(TFDQuery(DataSet));
  end;
end;

procedure TBaseConnection.SetCredentials(ACredentials: IConnectionCredentialsProvider);
begin
  FCredentials := ACredentials;
end;

procedure TBaseConnection.Insert(const AObject: TObject; out AId: Variant);
var
  LMetaData: TEntityMetaData;
  LLastIdSQL: string;
begin
  if not Assigned(AObject) then
    raise Exception.Create('Object cannot be null');

  LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
  if not Assigned(LMetaData.PrimaryKeyField) then
    raise Exception.CreateFmt('A classe %s does not have a primary key defined ([Id]).', [AObject.ClassName]);

  // Use Generator to determine best insert strategy
  if TMetaDataManager.Instance.IsAutoIncrement(AObject) then
  begin
    // Check if generator provides a separate LastInsertId SQL (like MySQL)
    LLastIdSQL := FSQLGenerator.GetLastInsertIdSQL;
    
    if LLastIdSQL <> '' then
    begin
      Execute(GetInsertCommand(AObject));
      Execute(LLastIdSQL, AId);
    end
    else
    begin
      Execute(GetInsertCommand(AObject), AId);
    end;
    
    TFastField.SetByTypeKind(AObject, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind, AId);
  end
  else
  begin
    Execute(GetInsertCommand(AObject));
    AId := TFastField.GetAsVariant(AObject, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
  end;
end;

end.
