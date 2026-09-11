unit Bridge.Controller.Registry;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Bridge.Connection.Interfaces,
  Bridge.Controller.Interfaces,
  Bridge.Controller.Errors;

type
  /// <summary>
  /// Controller factory function type.
  /// </summary>
  TControllerFactory = TFunc<IController>;

  /// <summary>
  /// Controller factory that receives the connection the controller must use.
  /// Hosts that serve one connection per request (multi-tenant APIs) rely on
  /// this so a resolved controller never falls back to the global singleton.
  /// </summary>
  TControllerConnectionFactory = TFunc<IConnection, IController>;

  /// <summary>
  /// Global registry for Controllers by entity type.
  /// Allows automatic resolution of Controllers for lazy loading.
  /// </summary>
  TControllerRegistry = class
  private
    class var FInstance: TControllerRegistry;
    class var FLock: TObject;

    FRegistry: TDictionary<PTypeInfo, TControllerConnectionFactory>;

    constructor Create;
  public
    class function Instance: TControllerRegistry;
    destructor Destroy; override;

    /// <summary>
    /// Registers a controller factory for an entity type.
    /// The controller is built without a connection; when the caller provides
    /// one it is applied afterwards via SetConnection.
    /// </summary>
    procedure RegisterController(AEntityType: PTypeInfo; AFactory: TControllerFactory);

    /// <summary>
    /// Registers a controller factory that builds the controller already bound
    /// to the caller's connection.
    /// </summary>
    procedure RegisterControllerWithConnection(AEntityType: PTypeInfo;
      AFactory: TControllerConnectionFactory);

    /// <summary>
    /// Registers a controller factory using generics.
    /// </summary>
    procedure Register<TEntity: class; TControllerClass: class, constructor>;

    /// <summary>
    /// Gets a controller for the given entity type, using the global singleton
    /// connection.
    /// </summary>
    function GetController(AEntityType: PTypeInfo): IController; overload;

    /// <summary>
    /// Gets a controller for the given entity type bound to AConnection.
    /// </summary>
    function GetController(AEntityType: PTypeInfo; AConnection: IConnection): IController; overload;

    /// <summary>
    /// Gets a controller using generics.
    /// </summary>
    function Get<TEntity: class>: IController;

    /// <summary>
    /// Gets a controller using generics, bound to AConnection.
    /// </summary>
    function GetWithConnection<TEntity: class>(AConnection: IConnection): IController;

    /// <summary>
    /// Checks if a controller is registered for the entity type.
    /// </summary>
    function HasController(AEntityType: PTypeInfo): Boolean;

    /// <summary>
    /// Clears all registrations.
    /// </summary>
    procedure Clear;
  end;

implementation

uses
  Bridge.RttiHelper;

{ TControllerRegistry }

constructor TControllerRegistry.Create;
begin
  inherited Create;
  FRegistry := TDictionary<PTypeInfo, TControllerConnectionFactory>.Create;
end;

destructor TControllerRegistry.Destroy;
begin
  FRegistry.Free;
  inherited;
end;

class function TControllerRegistry.Instance: TControllerRegistry;
begin
  if not Assigned(FInstance) then
  begin
    TMonitor.Enter(FLock);
    try
      if not Assigned(FInstance) then
        FInstance := TControllerRegistry.Create;
    finally
      TMonitor.Exit(FLock);
    end;
  end;
  Result := FInstance;
end;

procedure TControllerRegistry.RegisterController(AEntityType: PTypeInfo;
  AFactory: TControllerFactory);
begin
  RegisterControllerWithConnection(
    AEntityType,
    function(AConnection: IConnection): IController
    begin
      Result := AFactory();
      if Assigned(Result) and Assigned(AConnection) then
        Result.SetConnection(AConnection);
    end
  );
end;

procedure TControllerRegistry.RegisterControllerWithConnection(
  AEntityType: PTypeInfo; AFactory: TControllerConnectionFactory);
begin
  TMonitor.Enter(FLock);
  try
    FRegistry.AddOrSetValue(AEntityType, AFactory);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TControllerRegistry.Register<TEntity, TControllerClass>;
begin
  RegisterControllerWithConnection(
    TypeInfo(TEntity),
    function(AConnection: IConnection): IController
    var
      LController: TObject;
      LBoundToConnection: Boolean;
    begin
      // Prefer the constructor that takes the caller's connection. Building the
      // controller first and only then calling SetConnection would resolve the
      // singleton meanwhile, which is not available to hosts where every
      // request carries its own connection.
      LBoundToConnection :=
        Assigned(AConnection) and
        TRttiHelper.HasConstructor(TControllerClass, [TypeInfo(IConnection)]);

      if LBoundToConnection then
        LController := TRttiHelper.InvokeConstructorWithInterface(
          TControllerClass,
          AConnection,
          TypeInfo(IConnection)
        )
      else
        LController := TControllerClass.Create;

      if not Supports(LController, IController, Result) then
      begin
        LController.Free;
        raise EBridgeControllerError.CreateFmt(SControllerNotInterface,
          [TControllerClass.ClassName]);
      end;

      if Assigned(AConnection) and (not LBoundToConnection) then
        Result.SetConnection(AConnection);
    end
  );
end;

function TControllerRegistry.GetController(AEntityType: PTypeInfo): IController;
begin
  Result := GetController(AEntityType, nil);
end;

function TControllerRegistry.GetController(AEntityType: PTypeInfo;
  AConnection: IConnection): IController;
var
  LFactory: TControllerConnectionFactory;
  LFound: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    LFound := FRegistry.TryGetValue(AEntityType, LFactory);
  finally
    TMonitor.Exit(FLock);
  end;

  if not LFound then
    raise EBridgeControllerError.CreateFmt(SControllerNotRegistered,
      [GetTypeName(AEntityType)]);

  Result := LFactory(AConnection);
end;

function TControllerRegistry.Get<TEntity>: IController;
begin
  Result := GetController(TypeInfo(TEntity), nil);
end;

function TControllerRegistry.GetWithConnection<TEntity>(
  AConnection: IConnection): IController;
begin
  Result := GetController(TypeInfo(TEntity), AConnection);
end;

function TControllerRegistry.HasController(AEntityType: PTypeInfo): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRegistry.ContainsKey(AEntityType);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TControllerRegistry.Clear;
begin
  TMonitor.Enter(FLock);
  try
    FRegistry.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

initialization
  TControllerRegistry.FLock := TObject.Create;

finalization
  if Assigned(TControllerRegistry.FInstance) then
  begin
    TControllerRegistry.FInstance.Free;
    TControllerRegistry.FInstance := nil;
  end;
  FreeAndNil(TControllerRegistry.FLock);

end.
