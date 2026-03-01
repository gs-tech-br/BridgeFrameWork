unit Bridge.Connection.MySQL;

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
  FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef,
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
  TConnectionMySQL = class(TBaseConnection)
  strict private
    FDriverLink: TFDPhysMySQLDriverLink;
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
  end;

implementation

uses
  Bridge.Connection.Factory,
  Bridge.Connection.Generator.MySQL;

{ TConnectionMySQL }

constructor TConnectionMySQL.Create(ACredentials: IConnectionCredentialsProvider;
  ADriverConfig: IDriverConfigProvider;
  ASQLGenerator: ISQLGenerator);
begin
  if not Assigned(ASQLGenerator) then
    ASQLGenerator := TMySQLGenerator.Create;

  inherited Create(ACredentials, ADriverConfig, ASQLGenerator);
  
  if not Assigned(FDriverConfig) then
    FDriverConfig := TDefaultDriverConfig.Create(dtMySQL);

  ConfigureDriver;
  FConnection := Self.CreateConnection;
end;

destructor TConnectionMySQL.Destroy;
begin
  FDriverLink.Free;
  inherited;
end;

procedure TConnectionMySQL.ConfigureDriver;
begin
  FDriverLink := TFDPhysMySQLDriverLink.Create(nil);

  if FDriverConfig.GetVendorLib <> '' then
    FDriverLink.VendorLib := FDriverConfig.GetVendorLib;

  if FDriverConfig.GetVendorHome <> '' then
    FDriverLink.VendorHome := FDriverConfig.GetVendorHome;

  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
end;

function TConnectionMySQL.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'MySQL';
  Result.Params.Values['Server'] := FCredentials.GetServer;
  Result.Params.Values['Port'] := FCredentials.GetPort;
  Result.Params.Database := FCredentials.GetDatabase;
  Result.Params.UserName := FCredentials.GetUserName;
  Result.Params.Password := FCredentials.GetPassword;
  Result.LoginPrompt := False;
  Result.Connected := True;
end;

function TConnectionMySQL.getColumns(const ATable: string): TStringList;
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

function TConnectionMySQL.getId(const ATable: string): Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := Self.CreateDataSet('SELECT LAST_INSERT_ID() AS ID');
  try
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsInteger;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TConnectionMySQL.getSeq(const ATable, AColumnName: string): Variant;
var
  LValue: Variant;
begin
  Self.Execute(Format('SELECT (IFNULL(MAX(%s), 0) + 1) AS SEQUENCE FROM %s', [AColumnName, ATable]), LValue);
  Result := LValue;
end;

initialization
  TConnectionFactory.RegisterConnection(dbMySQL, TConnectionMySQL);

end.
