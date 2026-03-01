unit Bridge.RttiHelper;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.SysUtils,
  System.Variants,
  System.Generics.Collections;

type
  /// <summary>
  /// Helper class for RTTI operations.
  /// Provides methods for dynamic constructor invocation and type inspection.
  /// </summary>
  TRttiHelper = class
  private
    class var FContext: TRttiContext;
    class var FInitialized: Boolean;

    class procedure EnsureInitialized;
  public
    class destructor Destroy;

    /// <summary>
    /// Invokes a constructor with the specified parameters.
    /// </summary>
    /// <param name="AClass">Class to instantiate</param>
    /// <param name="AParams">Constructor parameters as TValue array</param>
    /// <returns>New instance of the class</returns>
    class function InvokeConstructor(AClass: TClass; const AParams: array of TValue): TObject; overload;

    /// <summary>
    /// Invokes a parameterless constructor.
    /// </summary>
    /// <param name="AClass">Class to instantiate</param>
    /// <returns>New instance of the class</returns>
    class function InvokeConstructor(AClass: TClass): TObject; overload;

    /// <summary>
    /// Invokes a constructor with a single interface parameter.
    /// </summary>
    /// <param name="AClass">Class to instantiate</param>
    /// <param name="AInterface">Interface to pass to constructor</param>
    /// <param name="AInterfaceType">TypeInfo of the interface</param>
    /// <returns>New instance of the class</returns>
    class function InvokeConstructorWithInterface(AClass: TClass; const AInterface: IInterface; AInterfaceType: PTypeInfo): TObject;

    /// <summary>
    /// Finds a constructor that accepts the specified parameter types.
    /// </summary>
    /// <param name="AClass">Class to search</param>
    /// <param name="AParamTypes">Array of TypeInfo for expected parameters</param>
    /// <returns>TRttiMethod if found, nil otherwise</returns>
    class function FindConstructor(AClass: TClass; const AParamTypes: array of PTypeInfo): TRttiMethod;

    /// <summary>
    /// Checks if a class has a constructor with the specified parameter types.
    /// </summary>
    class function HasConstructor(AClass: TClass; const AParamTypes: array of PTypeInfo): Boolean;

    /// <summary>
    /// Gets all public properties of a class.
    /// </summary>
    class function GetProperties(AClass: TClass): TArray<TRttiProperty>;

    /// <summary>
    /// Gets a property by name.
    /// </summary>
    class function GetProperty(AClass: TClass; const APropertyName: string): TRttiProperty;

    /// <summary>
    /// Sets a property value by name.
    /// </summary>
    class procedure SetPropertyValue(AObject: TObject; const APropertyName: string; const AValue: TValue);

    /// <summary>
    /// Gets a property value by name.
    /// </summary>
    class function GetPropertyValue(AObject: TObject; const APropertyName: string): TValue;

    /// <summary>
    /// Checks if an object implements a specific interface.
    /// </summary>
    class function ImplementsInterface(AObject: TObject; const AIID: TGUID): Boolean;

    /// <summary>
    /// Gets the RTTI context (shared instance).
    /// </summary>
    class property Context: TRttiContext read FContext;
  end;

implementation

uses
  Bridge.Connection.Interfaces;

{ TRttiHelper }

class destructor TRttiHelper.Destroy;
begin
  if FInitialized then
    FContext.Free;
end;

class procedure TRttiHelper.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FContext := TRttiContext.Create;
    FInitialized := True;
  end;
end;

class function TRttiHelper.InvokeConstructor(AClass: TClass): TObject;
begin
  Result := InvokeConstructor(AClass, []);
end;

class function TRttiHelper.InvokeConstructor(AClass: TClass; const AParams: array of TValue): TObject;
var
  LType: TRttiType;
  LMethod: TRttiMethod;
  LParams: TArray<TValue>;
  I: Integer;
begin
  EnsureInitialized;

  LType := FContext.GetType(AClass);
  if LType = nil then
    raise Exception.CreateFmt('RTTI not available for class %s', [AClass.ClassName]);

  // Convert open array to dynamic array
  SetLength(LParams, Length(AParams));
  for I := 0 to High(AParams) do
    LParams[I] := AParams[I];

  // Find matching constructor
  for LMethod in LType.GetMethods('Create') do
  begin
    if LMethod.IsConstructor and (Length(LMethod.GetParameters) = Length(LParams)) then
    begin
      Result := LMethod.Invoke(AClass, LParams).AsObject;
      Exit;
    end;
  end;

  raise Exception.CreateFmt('No matching constructor found for class %s with %d parameters',
    [AClass.ClassName, Length(LParams)]);
end;

class function TRttiHelper.InvokeConstructorWithInterface(AClass: TClass;
  const AInterface: IInterface; AInterfaceType: PTypeInfo): TObject;
var
  LType: TRttiType;
  LMethod: TRttiMethod;
  LConnection: IConnection;
begin
  EnsureInitialized;

  LType := FContext.GetType(AClass);
  if LType = nil then
    raise Exception.CreateFmt('RTTI not available for class %s', [AClass.ClassName]);

  for LMethod in LType.GetMethods('Create') do
  begin
    if LMethod.IsConstructor and (Length(LMethod.GetParameters) = 1) then
    begin
      if LMethod.GetParameters[0].ParamType.Handle = AInterfaceType then
      begin
        // Usar o tipo concreto IConnection para evitar EInvalidCast no Invoke
        if Supports(AInterface, IConnection, LConnection) then
          Result := LMethod.Invoke(AClass, [TValue.From<IConnection>(LConnection)]).AsObject
        else
          Result := LMethod.Invoke(AClass, [TValue.From<IInterface>(AInterface)]).AsObject;
        Exit;
      end;
    end;
  end;

  raise Exception.CreateFmt('No constructor found for class %s accepting interface %s',
    [AClass.ClassName, AInterfaceType.Name]);
end;

class function TRttiHelper.FindConstructor(AClass: TClass;
  const AParamTypes: array of PTypeInfo): TRttiMethod;
var
  LType: TRttiType;
  LMethod: TRttiMethod;
  LParams: TArray<TRttiParameter>;
  I: Integer;
  LMatch: Boolean;
begin
  EnsureInitialized;
  Result := nil;

  LType := FContext.GetType(AClass);
  if LType = nil then
    Exit;

  for LMethod in LType.GetMethods('Create') do
  begin
    if not LMethod.IsConstructor then
      Continue;

    LParams := LMethod.GetParameters;
    if Length(LParams) <> Length(AParamTypes) then
      Continue;

    LMatch := True;
    for I := 0 to High(AParamTypes) do
    begin
      if LParams[I].ParamType.Handle <> AParamTypes[I] then
      begin
        LMatch := False;
        Break;
      end;
    end;

    if LMatch then
      Exit(LMethod);
  end;
end;

class function TRttiHelper.HasConstructor(AClass: TClass;
  const AParamTypes: array of PTypeInfo): Boolean;
begin
  Result := FindConstructor(AClass, AParamTypes) <> nil;
end;

class function TRttiHelper.GetProperties(AClass: TClass): TArray<TRttiProperty>;
var
  LType: TRttiType;
begin
  EnsureInitialized;

  LType := FContext.GetType(AClass);
  if LType <> nil then
    Result := LType.GetProperties
  else
    SetLength(Result, 0);
end;

class function TRttiHelper.GetProperty(AClass: TClass;
  const APropertyName: string): TRttiProperty;
var
  LType: TRttiType;
begin
  EnsureInitialized;
  Result := nil;

  LType := FContext.GetType(AClass);
  if LType <> nil then
    Result := LType.GetProperty(APropertyName);
end;

class procedure TRttiHelper.SetPropertyValue(AObject: TObject;
  const APropertyName: string; const AValue: TValue);
var
  LProp: TRttiProperty;
begin
  LProp := GetProperty(AObject.ClassType, APropertyName);
  if LProp <> nil then
    LProp.SetValue(AObject, AValue)
  else
    raise Exception.CreateFmt('Property %s not found in class %s',
      [APropertyName, AObject.ClassName]);
end;

class function TRttiHelper.GetPropertyValue(AObject: TObject;
  const APropertyName: string): TValue;
var
  LProp: TRttiProperty;
begin
  LProp := GetProperty(AObject.ClassType, APropertyName);
  if LProp <> nil then
    Result := LProp.GetValue(AObject)
  else
    raise Exception.CreateFmt('Property %s not found in class %s',
      [APropertyName, AObject.ClassName]);
end;

class function TRttiHelper.ImplementsInterface(AObject: TObject;
  const AIID: TGUID): Boolean;
var
  LIntf: IInterface;
begin
  Result := Supports(AObject, AIID, LIntf);
end;

end.
