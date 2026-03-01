unit Bridge.Connection.SQLServer;

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
  FireDAC.Phys.MSSQL,
  FireDAC.Phys.MSSQLDef,
  FireDAC.Phys.ODBCBase,
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
  TConnectionSQLServer = class(TBaseConnection)
  strict private
    FDriverLink: TFDPhysMSSQLDriverLink;
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
    function GetQuotedTableName(const AObject: TObject): string; override;
    function CreateDataSet(const ASQLValue: string): TFDQuery; override;

    procedure InsertBatch(const AList: TObject; AClassType: TClass); override;
  end;

implementation

uses
  Bridge.Connection.Factory,
  Bridge.Connection.Generator.SQLServer;

{ TConnectionSQLServer }

constructor TConnectionSQLServer.Create(ACredentials: IConnectionCredentialsProvider;
  ADriverConfig: IDriverConfigProvider;
  ASQLGenerator: ISQLGenerator);
begin
  if not Assigned(ASQLGenerator) then
    ASQLGenerator := TSQLServerGenerator.Create;

  inherited Create(ACredentials, ADriverConfig, ASQLGenerator);
  if not Assigned(FDriverConfig) then
    FDriverConfig := TDefaultDriverConfig.Create(dtSQLServer);

  ConfigureDriver;
  FConnection := Self.CreateConnection;
end;

destructor TConnectionSQLServer.Destroy;
begin
  FDriverLink.Free;
  inherited;
end;

procedure TConnectionSQLServer.ConfigureDriver;
begin
  FDriverLink := TFDPhysMSSQLDriverLink.Create(nil);

  if FDriverConfig.GetVendorLib <> '' then
    FDriverLink.VendorLib := FDriverConfig.GetVendorLib;

  if FDriverConfig.GetVendorHome <> '' then
    FDriverLink.VendorHome := FDriverConfig.GetVendorHome;

  if FDriverConfig.GetODBCDriver <> '' then
    FDriverLink.ODBCDriver := FDriverConfig.GetODBCDriver;

  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
end;

function TConnectionSQLServer.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.Params.Clear;
  Result.Params.Add('DriverID=' + FCredentials.GetDriverID);
  Result.Params.Add('Server=' + FCredentials.GetServer);
  Result.Params.Add('Database=' + FCredentials.GetDatabase);
  Result.Params.Add('User_Name=' + FCredentials.GetUserName);
  Result.Params.Add('Password=' + FCredentials.GetPassword);
  Result.Params.Add('LoginTimeout=30');
  Result.Params.Add('ApplicationName=BridgeFramework');
  Result.Params.Add('MARS=Yes');
  Result.Params.Add('TrustServerCertificate=Yes');
  Result.LoginPrompt := False;
  Result.Connected := True;
end;

function TConnectionSQLServer.CreateDataSet(const ASQLValue: string): TFDQuery;
begin
  Result := inherited CreateDataSet(ASQLValue);
  Result.CachedUpdates := True;
  Result.UpdateOptions.UpdateNonBaseFields := True;
end;

function TConnectionSQLServer.getColumns(const ATable: string): TStringList;
const
  LSQL = 'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = %s';
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

function TConnectionSQLServer.getId(const ATable: string): Integer;
const
  LComand = 'SELECT IDENT_CURRENT(%s) AS ID';
var
  LQuery: TFDQuery;
begin
  LQuery := Self.CreateDataSet(Format(LComand, [QuotedStr(ATable)]));
  try
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsInteger;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TConnectionSQLServer.GetQuotedTableName(const AObject: TObject): string;
begin
  Result := '[' + inherited GetQuotedTableName(AObject) + ']';
end;

function TConnectionSQLServer.getSeq(const ATable, AColumnName: string): Variant;
const
  LInstruction = 'SELECT (ISNULL(MAX(%s), 0) + 1) AS SEQUENCE FROM %s';
var
  LValue: Variant;
begin
  Self.Execute(Format(LInstruction, [AColumnName, ATable]), LValue);
  Result := LValue;
end;

procedure TConnectionSQLServer.InsertBatch(const AList: TObject; AClassType: TClass);
begin
  TBatchOperationHelper.Insert(
    FConnection,
    AList,
    AClassType,
    function(TableName: string): TStringList
    begin
      Result := Self.getColumns(TableName);
    end,
    function(Identifier: string): string
    begin
      Result := '[' + Identifier + ']';
    end
  );
end;

initialization
  TConnectionFactory.RegisterConnection(dbSQLServer, TConnectionSQLServer);

end.
