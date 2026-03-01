unit Bridge.Connection.Pool;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  Bridge.Connection.Interfaces;

type
  /// <summary>
  /// Manages a pool of database connections to support multi-threaded access
  /// without the overhead of creating/destroying connections for every operation.
  /// </summary>
  IConnectionPool = interface
    ['{89A5074C-1596-4886-A4C3-72C155681E27}']
    /// <summary>
    /// Retrieves a connection from the pool.
    /// If the pool is empty, a new connection is created.
    /// </summary>
    function AcquireConnection: IConnection;

    /// <summary>
    /// Returns a connection to the pool for reuse.
    /// </summary>
    procedure ReleaseConnection(const AConnection: IConnection);
  end;

  TConnectionPool = class(TInterfacedObject, IConnectionPool)
  private
    class var FInstance: IConnectionPool;
    class var FLock: TCriticalSection;
  
  private
    FConnections: TStack<IConnection>;
    FInternalLock: TCriticalSection;
    FMaxConnections: Integer;
    
    constructor Create;
  public
    class function GetInstance: IConnectionPool;
    class constructor Create;
    class destructor Destroy;

    destructor Destroy; override;

    function AcquireConnection: IConnection;
    procedure ReleaseConnection(const AConnection: IConnection);
    
    /// <summary>
    /// Configures the maximum number of idle connections to keep in the pool.
    /// Default is 10.
    /// </summary>
    property MaxConnections: Integer read FMaxConnections write FMaxConnections;
  end;

implementation

uses
  Bridge.Connection.Factory;

{ TConnectionPool }

class constructor TConnectionPool.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TConnectionPool.Destroy;
begin
  FLock.Free;
end;

constructor TConnectionPool.Create;
begin
  inherited Create;
  FConnections := TStack<IConnection>.Create;
  FInternalLock := TCriticalSection.Create;
  FMaxConnections := 10;
end;

destructor TConnectionPool.Destroy;
begin
  FInternalLock.Free;
  FConnections.Free; // Interfaces inside will be released if refcount drops
  inherited;
end;

function TConnectionPool.AcquireConnection: IConnection;
begin
  FInternalLock.Enter;
  try
    if FConnections.Count > 0 then
      Result := FConnections.Pop
    else
      // Nothing in pool, create a fresh one using the Factory
      Result := TConnectionFactory.New.CreateDataAccessObject;
  finally
    FInternalLock.Leave;
  end;
end;
    
procedure TConnectionPool.ReleaseConnection(const AConnection: IConnection);
begin
  if AConnection = nil then Exit;

  FInternalLock.Enter;
  try
    // Only return to pool if we haven't exceeded usage (simple logic for now)
    // and if the connection is still valid (could add check here)
    
    if FConnections.Count < FMaxConnections then
      FConnections.Push(AConnection)
    else
      // Let it go out of scope and destroy if pool is full (Result := nil implied by caller dropping ref)
      ; 
  finally
    FInternalLock.Leave;
  end;
end;

class function TConnectionPool.GetInstance: IConnectionPool;
begin
  // Double-checked locking for thread-safe singleton
  if FInstance = nil then
  begin
    FLock.Enter;
    try
      if FInstance = nil then
        FInstance := TConnectionPool.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

end.
