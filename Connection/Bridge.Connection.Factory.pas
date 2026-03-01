unit Bridge.Connection.Factory;

interface

uses
  System.Generics.Collections,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Data,
  Bridge.Connection.Base;

type
  /// <summary>
  /// Interface for the connection Factory.
  /// </summary>
  IConnectionFactory = interface
    ['{7A4F2AFD-2BDD-4EB1-9DB7-996FD6B32BBB}']
    function CreateDataAccessObject: IConnection;
  end;

  /// <summary>
  /// Factory for creating database connections.
  /// Supports custom credentials provider registration.
  /// Uses a registration mechanism to decouple from concrete connection classes.
  /// </summary>
  TConnectionFactory = class(TInterfacedObject, IConnectionFactory)
  private
    class var FRegistry: TDictionary<TDataBaseConnection, TConnectionClass>;
    FCredentialsProvider: IConnectionCredentialsProvider;

    function CreateDataAccessObject: IConnection;
    function GetCredentialsProvider: IConnectionCredentialsProvider;

  public
    constructor Create(AProvider: IConnectionCredentialsProvider = nil);
    class destructor Destroy;
    class constructor Create;
    
    class function New(AProvider: IConnectionCredentialsProvider = nil): IConnectionFactory;
    class procedure RegisterConnection(AType: TDataBaseConnection; AClass: TConnectionClass);
  end;

implementation

uses
  System.SysUtils;

{ TConnectionFactory }

class constructor TConnectionFactory.Create;
begin
  FRegistry := TDictionary<TDataBaseConnection, TConnectionClass>.Create;
end;

class destructor TConnectionFactory.Destroy;
begin
  FRegistry.Free;
end;

constructor TConnectionFactory.Create(AProvider: IConnectionCredentialsProvider);
begin
  FCredentialsProvider := AProvider;
end;

class function TConnectionFactory.New(AProvider: IConnectionCredentialsProvider): IConnectionFactory;
begin
  Result := Self.Create(AProvider);
end;

class procedure TConnectionFactory.RegisterConnection(AType: TDataBaseConnection; AClass: TConnectionClass);
begin
  FRegistry.AddOrSetValue(AType, AClass);
end;

function TConnectionFactory.GetCredentialsProvider: IConnectionCredentialsProvider;
begin
  if Assigned(FCredentialsProvider) then
    Result := FCredentialsProvider
  else
    Result := TConnectionData.Create;
end;

function TConnectionFactory.CreateDataAccessObject: IConnection;
var
  LCredentials: IConnectionCredentialsProvider;
  LConnectionClass: TConnectionClass;
  LDbType: TDataBaseConnection;
begin
  LCredentials := GetCredentialsProvider;
  LDbType := LCredentials.GetDataBaseConnection;

  if FRegistry.TryGetValue(LDbType, LConnectionClass) then
  begin
    // Create the connection using the base constructor.
    // The specific connection class should handle its own generator creation in its overridden constructor.
    Result := LConnectionClass.Create(LCredentials, nil, nil); 
  end
  else
    raise Exception.CreateFmt('No connection registered for database type: %d', [Ord(LDbType)]);
end;

end.
