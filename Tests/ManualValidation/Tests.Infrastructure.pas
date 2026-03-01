unit Tests.Infrastructure;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Bridge.Connection.Interfaces,
  Bridge.Controller.Interfaces,
  Bridge.Controller.Registry,
  Bridge.Connection.Pool,
  Bridge.Base.Controller,
  Tests.Shared;

/// <summary>
/// Teste do Controller Registry
/// </summary>
procedure RunControllerRegistryTest;

/// <summary>
/// Teste do Connection Pool
/// </summary>
procedure RunConnectionPoolTest;

implementation

procedure RunControllerRegistryTest;
var
  LRegistry: TControllerRegistry;
  LController: IController;
  LConnection: IConnection;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' CONTROLLER REGISTRY TEST');
  Writeln('===========================================');
  Writeln('');

  // 1. Setup Connection for controller factory
  LConnection := CreateTestConnection;

  // 2. Get Registry instance
  Writeln('[1] Getting TControllerRegistry singleton instance...');
  LRegistry := TControllerRegistry.Instance;
  if Assigned(LRegistry) then
    Writeln('    [PASS] Registry instance obtained')
  else
  begin
    Writeln('    [FAIL] Registry instance is nil');
    Exit;
  end;

  try
    // 3. Register a controller factory
    Writeln('[2] Registering controller factory for TPerson...');
    LRegistry.RegisterController(
      TypeInfo(TPerson),
      function: IController
      begin
        Result := TBaseController.Create(LConnection);
      end
    );
    Writeln('    OK');

    // 4. Check if controller is registered
    Writeln('[3] Checking if controller is registered...');
    if LRegistry.HasController(TypeInfo(TPerson)) then
      Writeln('    [PASS] Controller is registered')
    else
    begin
      Writeln('    [FAIL] Controller not found in registry');
      Exit;
    end;

    // 5. Get controller from registry
    Writeln('[4] Getting controller from registry...');
    LController := LRegistry.GetController(TypeInfo(TPerson));
    if Assigned(LController) then
    begin
      Writeln('    [PASS] Controller retrieved successfully');
      Writeln('');
      Writeln('===========================================');
      Writeln(' CONTROLLER REGISTRY TEST PASSED!');
      Writeln('===========================================');
    end
    else
      Writeln('    [FAIL] Retrieved controller is nil');

  finally
    // 6. Clear registry
    LRegistry.Clear;
  end;
end;

procedure RunConnectionPoolTest;
var
  LPool: IConnectionPool;
  LConn1, LConn2: IConnection;
begin
  Writeln('');
  Writeln('===========================================');
  Writeln(' CONNECTION POOL TEST');
  Writeln('===========================================');
  Writeln('');

  // 1. Get Pool instance
  Writeln('[1] Getting TConnectionPool singleton instance...');
  LPool := TConnectionPool.GetInstance;
  if Assigned(LPool) then
    Writeln('    [PASS] Pool instance obtained')
  else
  begin
    Writeln('    [FAIL] Pool instance is nil');
    Exit;
  end;

  // 2. Acquire connection
  Writeln('[2] Acquiring connection from pool...');
  LConn1 := LPool.AcquireConnection;
  if Assigned(LConn1) then
    Writeln('    [PASS] Connection acquired')
  else
  begin
    Writeln('    [FAIL] Acquired connection is nil');
    Exit;
  end;

  // 3. Release connection back to pool
  Writeln('[3] Releasing connection back to pool...');
  LPool.ReleaseConnection(LConn1);
  Writeln('    OK');

  // 4. Acquire again (should get same or pooled connection)
  Writeln('[4] Acquiring connection again (should reuse pooled)...');
  LConn2 := LPool.AcquireConnection;
  if Assigned(LConn2) then
  begin
    Writeln('    [PASS] Connection acquired from pool');
    Writeln('');
    Writeln('===========================================');
    Writeln(' CONNECTION POOL TEST PASSED!');
    Writeln('===========================================');
  end
  else
    Writeln('    [FAIL] Second acquired connection is nil');

  // Release
  LPool.ReleaseConnection(LConn2);
end;

end.
