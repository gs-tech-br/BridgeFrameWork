unit Bridge.Connection.Postgres;

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
  FireDAC.Phys.PG,
  FireDAC.Phys.PGDef,
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
  TConnectionPostgres = class(TBaseConnection)
  strict private
    FDriverLink: TFDPhysPGDriverLink;
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
  Bridge.Connection.Generator.Postgres;

{ TConnectionPostgres }

constructor TConnectionPostgres.Create(ACredentials: IConnectionCredentialsProvider;
  ADriverConfig: IDriverConfigProvider;
  ASQLGenerator: ISQLGenerator);
begin
  if not Assigned(ASQLGenerator) then
    ASQLGenerator := TPostgresGenerator.Create;

  inherited Create(ACredentials, ADriverConfig, ASQLGenerator);
  
  if not Assigned(FDriverConfig) then
    FDriverConfig := TDefaultDriverConfig.Create(dtPostgres);

  ConfigureDriver;
  FConnection := Self.CreateConnection;
end;

destructor TConnectionPostgres.Destroy;
begin
  FDriverLink.Free;
  inherited;
end;

procedure TConnectionPostgres.ConfigureDriver;
begin
  FDriverLink := TFDPhysPgDriverLink.Create(nil);

  if FDriverConfig.GetVendorLib <> '' then
    FDriverLink.VendorLib := FDriverConfig.GetVendorLib;

  if FDriverConfig.GetVendorHome <> '' then
    FDriverLink.VendorHome := FDriverConfig.GetVendorHome;

  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
end;

function TConnectionPostgres.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'PG';
  Result.Params.Values['Server'] := FCredentials.GetServer;
  Result.Params.Values['Port'] := FCredentials.GetPort;
  Result.Params.Database := FCredentials.GetDatabase;
  Result.Params.UserName := FCredentials.GetUserName;
  Result.Params.Password := FCredentials.GetPassword;
  Result.LoginPrompt := False;
  Result.Connected := True;
end;

function TConnectionPostgres.getColumns(const ATable: string): TStringList;
const
  LSQL = 'SELECT column_name FROM information_schema.columns WHERE table_name = %s';
var
  LQuery: TFDQuery;
  LTableNameKey: string;
  LCachedList: TStringList;
begin
  LTableNameKey := LowerCase(ATable);

  if not FCacheColumns.TryGetValue(LTableNameKey, LCachedList) then
  begin
    LCachedList := TStringList.Create;
    LQuery := Self.CreateDataSet(Format(LSQL, [QuotedStr(LowerCase(ATable))]));
    try
      LQuery.Open;
      LQuery.First;
      while not LQuery.Eof do
      begin
        LCachedList.Add(LQuery.FieldByName('column_name').AsString);
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

function TConnectionPostgres.getId(const ATable: string): Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := Self.CreateDataSet(Format('SELECT MAX(id) as id FROM %s', [ATable]));
  try
    LQuery.Open;
    Result := LQuery.FieldByName('id').AsInteger;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TConnectionPostgres.getSeq(const ATable, AColumnName: string): Variant;
var
  LValue: Variant;
begin
  Self.Execute(Format('SELECT (COALESCE(MAX(%s), 0) + 1) AS sequence FROM %s', [AColumnName, ATable]), LValue);
  Result := LValue;
end;

initialization
  TConnectionFactory.RegisterConnection(dbPostgres, TConnectionPostgres);

end.
