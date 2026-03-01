unit Tests.Lazy;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Bridge.Lazy;

procedure RunLazyTest;

implementation

var
  GObjectCount: Integer = 0;

type
  TTestObject = class
  public
    constructor Create;
    destructor Destroy; override;
  end;

{ TTestObject }

constructor TTestObject.Create;
begin
  AtomicIncrement(GObjectCount);
end;

destructor TTestObject.Destroy;
begin
  AtomicDecrement(GObjectCount);
  inherited;
end;

procedure RunLazyTest;
var
  LLazy: TLazy<TTestObject>;
  LObj: TTestObject;
begin
  Writeln('--------------------------------------------------');
  Writeln('TEST: Lazy Loading & Memory Management');
  Writeln('--------------------------------------------------');

  GObjectCount := 0;

  // 1. Basic Creation & Loading
  Writeln('1. Basic Creation & Loading');
  LLazy := TLazy<TTestObject>.Create;
  try
    if LLazy.IsLoaded then
      Writeln('FAILURE: Should not be loaded initially')
    else
      Writeln('SUCCESS: Not loaded initially');

    LLazy.SetLoader(function(V: Variant): TTestObject
      begin
        Result := TTestObject.Create;
      end, 0);

    if LLazy.IsLoaded then
      Writeln('FAILURE: Should not be loaded after SetLoader')
    else
      Writeln('SUCCESS: Not loaded after SetLoader');

    LObj := LLazy.Value; // Trigger Load
    if Assigned(LObj) and LLazy.IsLoaded then
      Writeln('SUCCESS: Loaded on access')
    else
      Writeln('FAILURE: Failed to load on access');
      
    if GObjectCount = 1 then
      Writeln('SUCCESS: Object count is 1')
    else
      Writeln('FAILURE: Object count is ', GObjectCount);
      
  finally
    LLazy.Free;
  end;

  if GObjectCount = 0 then
    Writeln('SUCCESS: Object freed after Lazy destruction')
  else
    Writeln('FAILURE: Memory Leak! Object count: ', GObjectCount);
    
  Writeln('');

  // 2. Testing Memory Leak Fix (SetLoader reset)
  Writeln('2. Testing SetLoader Memory Fix');
  GObjectCount := 0;
  LLazy := TLazy<TTestObject>.Create;
  try
    LLazy.SetLoader(function(V: Variant): TTestObject
      begin
        Result := TTestObject.Create;
      end, 0);

    LObj := LLazy.Value; // Trigger load to exist in GObjectCount
    if not Assigned(LObj) then
      Writeln('FAILURE: Failed to trigger load');

    if GObjectCount <> 1 then
      Writeln('FAILURE: Setup failed, count: ', GObjectCount);
      
    // SetLoader again - Matches logic: "if FOwnsObject and FLoaded and Assigned(FValue) -> Free"
    // This should free the PREVIOUS object
    LLazy.SetLoader(function(V: Variant): TTestObject
      begin
        Result := TTestObject.Create;
      end, 0);
      
    if GObjectCount = 0 then
      Writeln('SUCCESS: Previous object freed on SetLoader')
    else
      Writeln('FAILURE: Previous object leaked! Count: ', GObjectCount);

    LObj := LLazy.Value; // Trigger load for the NEW loader
    if not (Assigned(LObj) and (GObjectCount = 1)) then
      Writeln('FAILURE: New object not created correctly')
    else
      Writeln('SUCCESS: New object created');
      
  finally
    LLazy.Free;
  end;
  
  if GObjectCount = 0 then
    Writeln('SUCCESS: All objects freed')
  else
    Writeln('FAILURE: Memory Leak! Count: ', GObjectCount);
    
  Writeln('');

  // 3. Testing OwnsObject = False
  Writeln('3. Testing OwnsObject = False');
  GObjectCount := 0;
  LObj := TTestObject.Create; // Create manually
  LLazy := TLazy<TTestObject>.Create;
  try
    LLazy.OwnsObject := False;
    LLazy.SetValue(LObj); // Set directly
    
    // Destroy Lazy, but should NOT destroy Obj
  finally
    LLazy.Free;
  end;
  
  if GObjectCount = 1 then
  begin
    Writeln('SUCCESS: Object preserved (OwnsObject=False)');
    LObj.Free; // Cleanup manually
  end
  else
    Writeln('FAILURE: Object destroyed unexpectedly! Count: ', GObjectCount);
    
    
  if GObjectCount = 0 then
    Writeln('SUCCESS: Manual cleanup done')
  else
    Writeln('FAILURE: Memory Leak! Count: ', GObjectCount);
    
  Writeln('--------------------------------------------------');
end;

end.
