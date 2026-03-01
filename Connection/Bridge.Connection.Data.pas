unit Bridge.Connection.Data;

interface

uses
  System.IniFiles,
  System.SysUtils,
  System.Classes;

type
  TDataBaseConnection = (dbSQLServer = 1, dbMySQL = 2, dbPostgres = 3, dbSQLite = 4, dbOracle = 5, dbFirebird = 6);

  /// <summary>
  /// Interface to provide connection credentials.
  /// Projects using BridgeFrameWork can implement this interface
  /// to define their own credentials strategy.
  /// </summary>
  IConnectionCredentialsProvider = interface
    ['{8D4E5F6A-1B2C-4567-89AB-CDEF01234568}']
    function GetDriverID: string;
    function GetServer: string;
    function GetPort: string;
    function GetDatabase: string;
    function GetUserName: string;
    function GetPassword: string;
    function GetDataBaseConnection: TDataBaseConnection;
  end;

  /// <summary>
  /// Default credentials provider implementation.
  /// Reads connection info from the application .ini file.
  /// </summary>
  TConnectionData = class(TInterfacedObject, IConnectionCredentialsProvider)
  private
    FDriverID: string;
    FServer: string;
    FPort: string;
    FDatabase: string;
    FUserName: string;
    FPassword: string;
  public
    constructor Create;
    procedure LoadConnectionInfo;

    function GetDriverID: string;
    function GetServer: string;
    function GetPort: string;
    function GetDatabase: string;
    function GetUserName: string;
    function GetPassword: string;
    function GetDataBaseConnection: TDataBaseConnection;

    property DriverID: string read FDriverID;
    property Server: string read FServer;
    property Port: string read FPort;
    property Database: string read FDatabase;
    property UserName: string read FUserName;
    property Password: string read FPassword;
  end;

implementation

{ TConnectionData }

constructor TConnectionData.Create;
begin
  inherited Create;
  LoadConnectionInfo;
end;

function TConnectionData.GetDriverID: string;
begin
  Result := FDriverID;
end;

function TConnectionData.GetServer: string;
begin
  Result := FServer;
end;

function TConnectionData.GetPort: string;
begin
  Result := FPort;
end;

function TConnectionData.GetDatabase: string;
begin
  Result := FDatabase;
end;

function TConnectionData.GetUserName: string;
begin
  Result := FUserName;
end;

function TConnectionData.GetPassword: string;
begin
  Result := FPassword;
end;

function TConnectionData.GetDataBaseConnection: TDataBaseConnection;
begin
  if SameText(FDriverID, 'MSSQL') then
    Result := dbSQLServer
  else if SameText(FDriverID, 'SQLite') then
    Result := dbSQLite
  else if SameText(FDriverID, 'MySQL') then
    Result := dbMySQL
  else if SameText(FDriverID, 'PG') or SameText(FDriverID, 'Postgres') then
    Result := dbPostgres
  else if SameText(FDriverID, 'Ora') or SameText(FDriverID, 'Oracle') then
    Result := dbOracle
  else if SameText(FDriverID, 'FB') or SameText(FDriverID, 'Firebird') then
    Result := dbFirebird
  else
    Result := dbSQLServer;
end;

procedure TConnectionData.LoadConnectionInfo;
var
  LIniFile: TIniFile;
begin
  LIniFile := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  try
    FDriverID := LIniFile.ReadString('Database', 'DriverID', 'SQLite');
    FServer := LIniFile.ReadString('Database', 'Server', 'localhost');
    FPort := LIniFile.ReadString('Database', 'Port', '');
    FDatabase := LIniFile.ReadString('Database', 'Database', 'database.db');
    FUserName := LIniFile.ReadString('Database', 'UserName', '');
    FPassword := LIniFile.ReadString('Database', 'Password', '');
  finally
    LIniFile.Free;
  end;
end;

end.
