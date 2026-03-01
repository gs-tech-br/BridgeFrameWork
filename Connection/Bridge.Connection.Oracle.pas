unit Bridge.Connection.Oracle;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Comp.UI,
  FireDAC.DApt,
  FireDAC.Phys,
  FireDAC.Phys.Oracle,
  FireDAC.Phys.OracleDef,
  FireDAC.Stan.Async,
  FireDAC.Stan.Def,
  FireDAC.Stan.Param,
  FireDAC.Stan.Pool,
  Bridge.Connection.Base,
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
  TConnectionOracle = class(TBaseConnection)
  strict private
    FDriverLink: TFDPhysOracleDriverLink;
  protected
    function CreateConnection: TFDConnection; override;
    procedure ConfigureDriver; override;
  public
    constructor Create(ACredentials: IConnectionCredentialsProvider;
      ADriverConfig: IDriverConfigProvider;
      ASQLGenerator: ISQLGenerator = nil); override;
    destructor Destroy; override;

    function getSeq(const ATable, AColumnName: string): Variant; override;
    function getId(const ATable: string): Integer; override;
    function getColumns(const ATable: string): TStringList; override;

    function GetInsertCommand(const AObject: TObject): TDBCommand; override;
    procedure Execute(const ACommand: TDBCommand; out AValue: Variant); override;
  end;

implementation

uses
  Bridge.Connection.Factory,
  Bridge.Connection.Generator.Oracle;

{ TConnectionOracle }

constructor TConnectionOracle.Create(ACredentials: IConnectionCredentialsProvider;
  ADriverConfig: IDriverConfigProvider;
  ASQLGenerator: ISQLGenerator);
begin
  if not Assigned(ASQLGenerator) then
    ASQLGenerator := TOracleGenerator.Create;

  inherited Create(ACredentials, ADriverConfig, ASQLGenerator);
  if not Assigned(FDriverConfig) then
    FDriverConfig := TDefaultDriverConfig.Create(dtOracle);

  ConfigureDriver;
  FConnection := Self.CreateConnection;
end;

destructor TConnectionOracle.Destroy;
begin
  FDriverLink.Free;
  inherited;
end;

procedure TConnectionOracle.ConfigureDriver;
begin
  FDriverLink := TFDPhysOracleDriverLink.Create(nil);

  if FDriverConfig.GetVendorLib <> '' then
    FDriverLink.VendorLib := FDriverConfig.GetVendorLib;

  if FDriverConfig.GetVendorHome <> '' then
    FDriverLink.VendorHome := FDriverConfig.GetVendorHome;

  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
end;

function TConnectionOracle.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'Ora';
  Result.Params.Values['Server'] := FCredentials.GetServer;
  Result.Params.Values['Port'] := FCredentials.GetPort;
  Result.Params.Values['Database'] := FCredentials.GetDatabase;
  Result.Params.UserName := FCredentials.GetUserName;
  Result.Params.Password := FCredentials.GetPassword;
  Result.LoginPrompt := False;
  Result.Connected := True;
end;

function TConnectionOracle.getColumns(const ATable: string): TStringList;
const
  LSQL = 'SELECT COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE TABLE_NAME = %s';
var
  LQuery: TFDQuery;
  LCachedList: TStringList;
  LTableNameKey: string;
  LField: TField;
begin
  LTableNameKey := UpperCase(ATable);

  if not FCacheColumns.TryGetValue(LTableNameKey, LCachedList) then
  begin
    LCachedList := TStringList.Create;
    LQuery := Self.CreateDataSet(Format(LSQL, [QuotedStr(ATable)]));
    try
      LQuery.Open;
      LQuery.First;
      LField := LQuery.FieldByName('COLUMN_NAME');
      while not LQuery.Eof do
      begin
        LCachedList.Add(LField.AsString);
        LQuery.Next;
      end;
      FCacheColumns.Add(LTableNameKey, LCachedList);
    finally
      FreeAndNil(LQuery);
    end;
  end;

  Result := TStringList.Create;
  Result.Assign(LCachedList);
end;

function TConnectionOracle.getId(const ATable: string): Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := Self.CreateDataSet(Format('SELECT MAX(ID) AS ID FROM %s', [ATable]));
  try
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsInteger;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TConnectionOracle.getSeq(const ATable, AColumnName: string): Variant;
var
  LValue: Variant;
begin
  Self.Execute(Format('SELECT (COALESCE(MAX(%s), 0) + 1) AS SEQUENCE FROM %s', [AColumnName, ATable]), LValue);
  Result := LValue;
end;

function TConnectionOracle.GetInsertCommand(const AObject: TObject): TDBCommand;
const
  LInsertWithReturn = 'INSERT INTO %s (%s) VALUES (%s) RETURNING %s INTO :ID';
var
  LScript: TScriptInsert;
  LPrimaryKey: string;
  LPkFieldName: string;
  LMetaData: TEntityMetaData;
  LTableName: string;
begin
  LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);

  if TMetaDataManager.Instance.IsAutoIncrement(AObject) then
  begin
    LTableName := FMetaDataGenerator.GetTableName(AObject);
    LScript := FMetaDataGenerator.GenerateInsertScript(AObject);

    LPkFieldName := LMetaData.PrimaryKeyField.Name.Substring(1);
    LPrimaryKey := TMetaDataManager.Instance.GetColumnName(AObject, LPkFieldName);

    Result.SQL := Format(LInsertWithReturn, [LTableName, LScript.Fields, LScript.Params, LPrimaryKey]);
    Result.Params := LScript.ParamValues;
  end
  else
  begin
    Result := inherited GetInsertCommand(AObject);
  end;
end;

procedure TConnectionOracle.Execute(const ACommand: TDBCommand; out AValue: Variant);
var
  LQuery: TFDQuery;
begin
  if ACommand.SQL.Contains('RETURNING') and ACommand.SQL.Contains('INTO :ID') then
  begin
    LQuery := CreateQuery(ACommand.SQL, ACommand.Params);
    try
      LQuery.ParamByName('ID').ParamType := ptOutput;
      LQuery.ParamByName('ID').DataType := ftInteger;

      LQuery.ExecSQL;

      AValue := LQuery.ParamByName('ID').Value;
    finally
      LQuery.Free;
    end;
  end
  else
  begin
    inherited Execute(ACommand, AValue);
  end;
end;

initialization
  TConnectionFactory.RegisterConnection(dbOracle, TConnectionOracle);

end.
