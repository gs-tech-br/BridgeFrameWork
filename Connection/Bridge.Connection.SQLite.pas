unit Bridge.Connection.SQLite;

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
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
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
  TConnectionSQLite = class(TBaseConnection)
  strict private
    FDriverLink: TFDPhysSQLiteDriverLink;
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
  Bridge.Connection.Generator.SQLite;

{ TConnectionSQLite }

constructor TConnectionSQLite.Create(ACredentials: IConnectionCredentialsProvider;
  ADriverConfig: IDriverConfigProvider;
  ASQLGenerator: ISQLGenerator);
begin
  if not Assigned(ASQLGenerator) then
    ASQLGenerator := TSQLiteGenerator.Create;

  inherited Create(ACredentials, ADriverConfig, ASQLGenerator);
  if not Assigned(FDriverConfig) then
    FDriverConfig := TDefaultDriverConfig.Create(dtSQLite);

  ConfigureDriver;
  FConnection := Self.CreateConnection;
end;

destructor TConnectionSQLite.Destroy;
begin
  FDriverLink.Free;
  inherited;
end;

procedure TConnectionSQLite.ConfigureDriver;
begin
  FDriverLink := TFDPhysSQLiteDriverLink.Create(nil);

  if FDriverConfig.GetVendorLib <> '' then
    FDriverLink.VendorLib := FDriverConfig.GetVendorLib;

  if FDriverConfig.GetVendorHome <> '' then
    FDriverLink.VendorHome := FDriverConfig.GetVendorHome;

  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
end;

function TConnectionSQLite.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := FCredentials.GetDatabase;
  Result.LoginPrompt := False;
  Result.Connected := True;
end;

function TConnectionSQLite.getColumns(const ATable: string): TStringList;
var
  LQuery: TFDQuery;
  LSQL: string;
  LTableNameKey: string;
  LCachedList: TStringList;
  LField: TField;
begin
  LTableNameKey := UpperCase(ATable);

  if not FCacheColumns.TryGetValue(LTableNameKey, LCachedList) then
  begin
    LCachedList := TStringList.Create;
    LSQL := Format('PRAGMA table_info(%s)', [ATable]);
    LQuery := Self.CreateDataSet(LSQL);
    try
      LQuery.Open;
      LQuery.First;
      LField := LQuery.FieldByName('name');
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

function TConnectionSQLite.getId(const ATable: string): Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := Self.CreateDataSet(Format('SELECT MAX(ID) as ID FROM %s', [ATable]));
  try
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsInteger;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TConnectionSQLite.getSeq(const ATable, AColumnName: string): Variant;
var
  LValue: Variant;
begin
  Self.Execute(Format('SELECT (IFNULL(MAX(%s), 0) + 1) AS SEQUENCE FROM %s', [AColumnName, ATable]), LValue);
  Result := LValue;
end;

initialization
  TConnectionFactory.RegisterConnection(dbSQLite, TConnectionSQLite);

end.
