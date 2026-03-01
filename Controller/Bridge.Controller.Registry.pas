unit Bridge.Controller.Registry;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Bridge.Controller.Interfaces,
  Bridge.Controller.Errors;

type
  /// <summary>
  /// Controller factory function type.
  /// </summary>
  TControllerFactory = TFunc<IController>;

  /// <summary>
  /// Global registry for Controllers by entity type.
  /// Allows automatic resolution of Controllers for lazy loading.
  /// </summary>
  TControllerRegistry = class
  private
    class var FInstance: TControllerRegistry;
    class var FLock: TObject;

    FRegistry: TDictionary<PTypeInfo, TControllerFactory>;

    constructor Create;
  public
    class function Instance: TControllerRegistry;
    destructor Destroy; override;

    /// <summary>
    /// Registers a controller factory for an entity type.
    /// </summary>
    procedure RegisterController(AEntityType: PTypeInfo; AFactory: TControllerFactory);

    /// <summary>
    /// Registers a controller factory using generics.
    /// </summary>
    procedure Register<TEntity: class; TControllerClass: class, constructor>;

    /// <summary>
    /// Gets a controller for the given entity type.
    /// </summary>
    function GetController(AEntityType: PTypeInfo): IController;

    /// <summary>
    /// Gets a controller using generics.
    /// </summary>
    function Get<TEntity: class>: IController;

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

{ TControllerRegistry }

constructor TControllerRegistry.Create;
begin
  inherited Create;
  FRegistry := TDictionary<PTypeInfo, TControllerFactory>.Create;
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
  TMonitor.Enter(FLock);
  try
    FRegistry.AddOrSetValue(AEntityType, AFactory);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TControllerRegistry.Register<TEntity, TControllerClass>;
begin
  RegisterController(
    TypeInfo(TEntity),
    function: IController
    var
      LController: TObject;
    begin
      LController := TControllerClass.Create;
      if not Supports(LController, IController, Result) then
      begin
        LController.Free;
        raise EBridgeControllerError.CreateFmt(SControllerNotInterface,
          [TControllerClass.ClassName]);
      end;
    end
  );
end;

function TControllerRegistry.GetController(AEntityType: PTypeInfo): IController;
var
  LFactory: TControllerFactory;
begin
  TMonitor.Enter(FLock);
  try
    if FRegistry.TryGetValue(AEntityType, LFactory) then
      Result := LFactory()
    else
      raise EBridgeControllerError.CreateFmt(SControllerNotRegistered,
        [GetTypeName(AEntityType)]);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TControllerRegistry.Get<TEntity>: IController;
begin
  Result := GetController(TypeInfo(TEntity));
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
