unit Bridge.Lazy;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.Variants;

type
  /// <summary>
  /// Lazy-loaded value wrapper. Loads the value on first access.
  /// </summary>
  /// <summary>
  /// Lazy-loaded value wrapper. Loads the value on first access.
  /// </summary>
  TLazy<T: class> = class
  private
    FValue: T;
    FLoaded: Boolean;
    FForeignKeyValue: Variant;
    FLoadFunc: TFunc<Variant, T>;
    FLoadFuncObject: TFunc<Variant, TObject>;
    FOwnsObject: Boolean;
    function GetValue: T;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Configures the lazy loader function and FK value.
    /// </summary>
    procedure SetLoader(ALoadFunc: TFunc<Variant, T>; AFKValue: Variant); overload;
    procedure SetLoaderObject(ALoadFunc: TFunc<Variant, TObject>; AFKValue: Variant);

    /// <summary>
    /// Sets the value directly (marks as loaded).
    /// </summary>
    procedure SetValue(AValue: T);

    /// <summary>
    /// Returns the loaded value, triggering load if needed.
    /// </summary>
    property Value: T read GetValue;

    /// <summary>
    /// Returns true if value has been loaded.
    /// </summary>
    function IsLoaded: Boolean;

    /// <summary>
    /// Returns the FK value without triggering load.
    /// </summary>
    function GetForeignKeyValue: Variant;

    /// <summary>
    /// Determines if the Lazy wrapper owns the object (frees it on destroy). Default True.
    /// </summary>
    property OwnsObject: Boolean read FOwnsObject write FOwnsObject;
  end;

  /// <summary>
  /// Lazy-loaded list wrapper for 1:N relationships.
  /// </summary>
  TLazyList<T: class> = class
  private
    FList: TObjectList<T>;
    FLoaded: Boolean;
    FParentKeyValue: Variant;
    FLoadFunc: TFunc<Variant, TObjectList<T>>;
    FLoadFuncObject: TFunc<Variant, TObject>; // Returns TObjectList<T> as TObject
    FDummyT: T; // Dummy field to extract generic type T via RTTI (accessed via reflection only)
    function GetList: TObjectList<T>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetLoader(ALoadFunc: TFunc<Variant, TObjectList<T>>; AParentKeyValue: Variant); overload;
    procedure SetLoaderObject(ALoadFunc: TFunc<Variant, TObject>; AParentKeyValue: Variant);
    property List: TObjectList<T> read GetList;
    function IsLoaded: Boolean;
    function GetParentKeyValue: Variant;
  end;

implementation

{ TLazy<T> }

constructor TLazy<T>.Create;
begin
  FOwnsObject := True;
  FLoaded := False;
end;

destructor TLazy<T>.Destroy;
begin
  if FOwnsObject and FLoaded and Assigned(FValue) then
    if TObject(FValue) is TObject then
      TObject(FValue).Free;
  inherited;
end;

function TLazy<T>.GetValue: T;
begin
  if not FLoaded then
  begin
    if Assigned(FLoadFunc) then
      FValue := FLoadFunc(FForeignKeyValue)
    else if Assigned(FLoadFuncObject) then
      FValue := T(FLoadFuncObject(FForeignKeyValue));
    FLoaded := True;
  end;
  Result := FValue;
end;

procedure TLazy<T>.SetLoader(ALoadFunc: TFunc<Variant, T>; AFKValue: Variant);
begin
  // Safety: Free previous value if we own it and it was loaded
  if FOwnsObject and FLoaded and Assigned(FValue) then
  begin
    if TObject(FValue) is TObject then
      TObject(FValue).Free;
    FValue := Default(T); 
  end;

  FLoadFunc := ALoadFunc;
  FLoadFuncObject := nil;
  FForeignKeyValue := AFKValue;
  FLoaded := False;
end;

procedure TLazy<T>.SetLoaderObject(ALoadFunc: TFunc<Variant, TObject>; AFKValue: Variant);
begin
  // Safety: Free previous value if we own it and it was loaded
  if FOwnsObject and FLoaded and Assigned(FValue) then
  begin
    if TObject(FValue) is TObject then
      TObject(FValue).Free;
    FValue := Default(T);
  end;

  FLoadFunc := nil;
  FLoadFuncObject := ALoadFunc;
  FForeignKeyValue := AFKValue;
  FLoaded := False;
end;

procedure TLazy<T>.SetValue(AValue: T);
begin
  if FOwnsObject and FLoaded and Assigned(FValue) and (FValue <> AValue) then
    TObject(FValue).Free;

  FValue := AValue;
  FLoaded := True;
end;

function TLazy<T>.IsLoaded: Boolean;
begin
  Result := FLoaded;
end;

function TLazy<T>.GetForeignKeyValue: Variant;
begin
  Result := FForeignKeyValue;
end;

{ TLazyList<T> }

constructor TLazyList<T>.Create;
begin
  FLoaded := False;
end;

destructor TLazyList<T>.Destroy;
begin
  if Assigned(FList) then
    FList.Free;
  inherited;
end;

function TLazyList<T>.GetList: TObjectList<T>;
begin
  if not FLoaded then
  begin
    if Assigned(FLoadFunc) then
      FList := FLoadFunc(FParentKeyValue)
    else if Assigned(FLoadFuncObject) then
      FList := TObjectList<T>(FLoadFuncObject(FParentKeyValue));
    FLoaded := True;
  end;
  
  if not Assigned(FList) then
    FList := TObjectList<T>.Create(True);
    
  Result := FList;
end;

procedure TLazyList<T>.SetLoader(ALoadFunc: TFunc<Variant, TObjectList<T>>; AParentKeyValue: Variant);
begin
  FLoadFunc := ALoadFunc;
  FLoadFuncObject := nil;
  FParentKeyValue := AParentKeyValue;
  FLoaded := False;
end;

procedure TLazyList<T>.SetLoaderObject(ALoadFunc: TFunc<Variant, TObject>; AParentKeyValue: Variant);
begin
  FLoadFunc := nil;
  FLoadFuncObject := ALoadFunc;
  FParentKeyValue := AParentKeyValue;
  FLoaded := False;
  FDummyT := nil; // Initialize to suppress "unused field" warning
end;

function TLazyList<T>.IsLoaded: Boolean;
begin
  Result := FLoaded;
end;

function TLazyList<T>.GetParentKeyValue: Variant;
begin
  Result := FParentKeyValue;
end;

end.
