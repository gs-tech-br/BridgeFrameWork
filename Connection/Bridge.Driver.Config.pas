unit Bridge.Driver.Config;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Interface para configuração de drivers de banco de dados.
  /// Permite injetar configurações customizadas de VendorLib para diferentes plataformas.
  /// </summary>
  IDriverConfigProvider = interface
    ['{A7E8C3D2-4B5F-6E1A-9C0D-8F2E7A3B5C1D}']
    /// <summary>
    /// Retorna o caminho da biblioteca do driver (ex: libmysql.dll, libpq.so)
    /// </summary>
    function GetVendorLib: string;

    /// <summary>
    /// Retorna o diretório base onde as bibliotecas estão localizadas (opcional)
    /// </summary>
    function GetVendorHome: string;

    /// <summary>
    /// Retorna o nome do driver ODBC (usado apenas para SQL Server em Linux)
    /// Ex: 'ODBC Driver 17 for SQL Server'
    /// </summary>
    function GetODBCDriver: string;
  end;

  /// <summary>
  /// Tipo de banco de dados suportado pelo framework
  /// </summary>
  TDatabaseType = (
    dtSQLServer,
    dtMySQL,
    dtOracle,
    dtPostgres,
    dtSQLite,
    dtFirebird
  );

  /// <summary>
  /// Implementação padrão de configuração de driver.
  /// Retorna valores padrão baseado no sistema operacional e tipo de banco.
  /// </summary>
  TDefaultDriverConfig = class(TInterfacedObject, IDriverConfigProvider)
  private
    FDatabaseType: TDatabaseType;
    FVendorLib: string;
    FVendorHome: string;
    FODBCDriver: string;
    procedure SetDefaultValues;
  public
    constructor Create(ADatabaseType: TDatabaseType);

    function GetVendorLib: string;
    function GetVendorHome: string;
    function GetODBCDriver: string;

    property VendorLib: string read FVendorLib write FVendorLib;
    property VendorHome: string read FVendorHome write FVendorHome;
    property ODBCDriver: string read FODBCDriver write FODBCDriver;
  end;

  /// <summary>
  /// Implementação customizável de configuração de driver.
  /// Permite ao desenvolvedor definir valores específicos.
  /// </summary>
  TCustomDriverConfig = class(TInterfacedObject, IDriverConfigProvider)
  private
    FVendorLib: string;
    FVendorHome: string;
    FODBCDriver: string;
  public
    constructor Create(const AVendorLib: string; const AVendorHome: string = '';
      const AODBCDriver: string = '');

    function GetVendorLib: string;
    function GetVendorHome: string;
    function GetODBCDriver: string;

    property VendorLib: string read FVendorLib write FVendorLib;
    property VendorHome: string read FVendorHome write FVendorHome;
    property ODBCDriver: string read FODBCDriver write FODBCDriver;
  end;

implementation

{ TDefaultDriverConfig }

constructor TDefaultDriverConfig.Create(ADatabaseType: TDatabaseType);
begin
  inherited Create;
  FDatabaseType := ADatabaseType;
  SetDefaultValues;
end;

procedure TDefaultDriverConfig.SetDefaultValues;
begin
  FVendorHome := '';
  FODBCDriver := '';

  case FDatabaseType of
    dtSQLServer:
      begin
        {$IFDEF MSWINDOWS}
        FVendorLib := 'odbc32.dll';
        {$ELSE}
        FVendorLib := 'libodbc.so';
        FODBCDriver := 'ODBC Driver 17 for SQL Server';
        {$ENDIF}
      end;

    dtMySQL:
      begin
        {$IFDEF MSWINDOWS}
        FVendorLib := 'libmysql.dll';
        {$ELSE}
        FVendorLib := 'libmysqlclient.so';
        {$ENDIF}
      end;

    dtOracle:
      begin
        {$IFDEF MSWINDOWS}
        FVendorLib := 'oci.dll';
        {$ELSE}
        FVendorLib := 'libclntsh.so';
        {$ENDIF}
      end;

    dtPostgres:
      begin
        {$IFDEF MSWINDOWS}
        FVendorLib := 'libpq.dll';
        {$ELSE}
        FVendorLib := 'libpq.so.5';
        {$ENDIF}
      end;

    dtSQLite:
      begin
        {$IFDEF MSWINDOWS}
        FVendorLib := ''; // FireDAC inclui SQLite embutido no Windows
        {$ELSE}
        FVendorLib := 'libsqlite3.so';
        {$ENDIF}
      end;

    dtFirebird:
      begin
        {$IFDEF MSWINDOWS}
        FVendorLib := 'fbclient.dll';
        {$ELSE}
        FVendorLib := 'libfbclient.so';
        {$ENDIF}
      end;
  end;
end;

function TDefaultDriverConfig.GetVendorLib: string;
begin
  Result := FVendorLib;
end;

function TDefaultDriverConfig.GetVendorHome: string;
begin
  Result := FVendorHome;
end;

function TDefaultDriverConfig.GetODBCDriver: string;
begin
  Result := FODBCDriver;
end;

{ TCustomDriverConfig }

constructor TCustomDriverConfig.Create(const AVendorLib: string;
  const AVendorHome: string; const AODBCDriver: string);
begin
  inherited Create;
  FVendorLib := AVendorLib;
  FVendorHome := AVendorHome;
  FODBCDriver := AODBCDriver;
end;

function TCustomDriverConfig.GetVendorLib: string;
begin
  Result := FVendorLib;
end;

function TCustomDriverConfig.GetVendorHome: string;
begin
  Result := FVendorHome;
end;

function TCustomDriverConfig.GetODBCDriver: string;
begin
  Result := FODBCDriver;
end;

end.
