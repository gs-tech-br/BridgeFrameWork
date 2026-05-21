unit Tests.ResponseProtection;

interface

procedure RunResponseProtectionTest;

implementation

uses
  System.SysUtils,
  System.JSON,
  Bridge.MetaData.Attributes,
  Bridge.Neon.Config,
  Bridge.ResponseProtection,
  Bridge.Horse.Pagination;

type
  [Entity('PRODUCTION_LOT_PROTECTION_TEST')]
  TProductionLotProtectionTest = class
  private
    FId: Integer;
    FCode: string;
    FQuantity: Double;
    FTotalCost: Currency;
    FContributionMargin: Currency;
    FPrivateNote: string;
  public
    [Id(False)]
    [Column('ID')]
    property Id: Integer read FId write FId;

    [Column('CODE', 30)]
    property Code: string read FCode write FCode;

    [Column('QUANTITY')]
    property Quantity: Double read FQuantity write FQuantity;

    [Column('TOTAL_COST')]
    [ProtectedField('lot.cost.view', pfRemove, 'financial')]
    property TotalCost: Currency read FTotalCost write FTotalCost;

    [Column('CONTRIBUTION_MARGIN')]
    [ProtectedField('lot.cost.view', pfNull, 'financial')]
    property ContributionMargin: Currency read FContributionMargin write FContributionMargin;

    [Column('PRIVATE_NOTE', 100)]
    [ProtectedField('lot.private.view', pfMask, 'lgpd', 'analysis', '***')]
    property PrivateNote: string read FPrivateNote write FPrivateNote;
  end;

  TTestPrivilegeResolver = class(TInterfacedObject, IBridgePrivilegeResolver)
  private
    FPrivileges: TArray<string>;
    FCallCount: Integer;
  public
    constructor Create(const APrivileges: TArray<string>);
    procedure SetPrivileges(const APrivileges: TArray<string>);
    function GetPrivileges(ASubject: TBridgePrivilegeSubject): TArray<string>;
    property CallCount: Integer read FCallCount;
  end;

procedure AssertCondition(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function NewLot: TProductionLotProtectionTest;
begin
  Result := TProductionLotProtectionTest.Create;
  Result.Id := 10;
  Result.Code := 'LOT-001';
  Result.Quantity := 120;
  Result.TotalCost := 1500.75;
  Result.ContributionMargin := 375.10;
  Result.PrivateNote := 'internal financial note';
end;

{ TTestPrivilegeResolver }

constructor TTestPrivilegeResolver.Create(const APrivileges: TArray<string>);
begin
  inherited Create;
  SetPrivileges(APrivileges);
end;

procedure TTestPrivilegeResolver.SetPrivileges(const APrivileges: TArray<string>);
begin
  FPrivileges := Copy(APrivileges, 0, Length(APrivileges));
  FCallCount := 0;
end;

function TTestPrivilegeResolver.GetPrivileges(
  ASubject: TBridgePrivilegeSubject): TArray<string>;
begin
  Inc(FCallCount);
  Result := Copy(FPrivileges, 0, Length(FPrivileges));
end;

procedure TestDeniedFieldsAreProtected(AResolver: TTestPrivilegeResolver);
var
  LLot: TProductionLotProtectionTest;
  LJSON: TJSONObject;
  LMargin: TJSONValue;
  LPrivateNote: TJSONValue;
begin
  AResolver.SetPrivileges([]);
  TBridgeResponseProtectionManager.ClearCache;

  LLot := NewLot;
  try
    LJSON := TBridgeNeon.ObjectToJSONObject(LLot);
    try
      AssertCondition(Assigned(LJSON.GetValue('id')), 'JSON should keep id');
      AssertCondition(Assigned(LJSON.GetValue('code')), 'JSON should keep code');
      AssertCondition(not Assigned(LJSON.GetValue('totalCost')), 'totalCost must be removed without privilege');

      LMargin := LJSON.GetValue('contributionMargin');
      AssertCondition(Assigned(LMargin) and (LMargin is TJSONNull),
        'contributionMargin must be null without privilege');

      LPrivateNote := LJSON.GetValue('privateNote');
      AssertCondition(Assigned(LPrivateNote) and SameText(LPrivateNote.Value, '***'),
        'privateNote must be masked without privilege');

      Writeln('SUCCESS: protected fields are removed, nulled and masked');
    finally
      LJSON.Free;
    end;
  finally
    LLot.Free;
  end;
end;

procedure TestAllowedFieldsAreVisible(AResolver: TTestPrivilegeResolver);
var
  LLot: TProductionLotProtectionTest;
  LJSON: TJSONObject;
begin
  AResolver.SetPrivileges(['lot.cost.view', 'lot.private.view']);
  TBridgeResponseProtectionManager.ClearCache;

  LLot := NewLot;
  try
    LJSON := TBridgeNeon.ObjectToJSONObject(LLot);
    try
      AssertCondition(Assigned(LJSON.GetValue('totalCost')), 'totalCost should be visible with privilege');
      AssertCondition(Assigned(LJSON.GetValue('contributionMargin')), 'contributionMargin should be visible with privilege');
      AssertCondition(Assigned(LJSON.GetValue('privateNote')) and SameText(LJSON.GetValue('privateNote').Value, 'internal financial note'),
        'privateNote should be visible with privilege');
      Writeln('SUCCESS: authorized subject can see protected fields');
    finally
      LJSON.Free;
    end;
  finally
    LLot.Free;
  end;
end;

procedure TestPrivilegeCache(AResolver: TTestPrivilegeResolver);
var
  LLot: TProductionLotProtectionTest;
  LJSON: TJSONObject;
begin
  AResolver.SetPrivileges(['lot.cost.view']);
  TBridgeResponseProtectionManager.ClearCache;

  LLot := NewLot;
  try
    LJSON := TBridgeNeon.ObjectToJSONObject(LLot);
    LJSON.Free;

    LJSON := TBridgeNeon.ObjectToJSONObject(LLot);
    LJSON.Free;

    AssertCondition(AResolver.CallCount = 1,
      Format('Privilege resolver should be called once while cached. Got %d', [AResolver.CallCount]));

    TBridgeResponseProtectionManager.InvalidateSubject('USER_1', 'TENANT_1');
    LJSON := TBridgeNeon.ObjectToJSONObject(LLot);
    LJSON.Free;

    AssertCondition(AResolver.CallCount = 2,
      Format('Privilege resolver should be called after invalidation. Got %d', [AResolver.CallCount]));

    Writeln('SUCCESS: privilege cache and invalidation work');
  finally
    LLot.Free;
  end;
end;

procedure TestProtectedPropertyAccess(AResolver: TTestPrivilegeResolver);
begin
  AResolver.SetPrivileges([]);
  TBridgeResponseProtectionManager.ClearCache;
  AssertCondition(not TBridgeResponseProtectionManager.CanAccessProperty(TProductionLotProtectionTest, 'TotalCost'),
    'TotalCost order/filter must be denied without privilege');

  AResolver.SetPrivileges(['lot.cost.view']);
  TBridgeResponseProtectionManager.ClearCache;
  AssertCondition(TBridgeResponseProtectionManager.CanAccessProperty(TProductionLotProtectionTest, 'TotalCost'),
    'TotalCost order/filter must be allowed with privilege');

  Writeln('SUCCESS: protected order/filter checks respect privileges');
end;

procedure TestCursorDoesNotExposeProtectedFields(AResolver: TTestPrivilegeResolver);
var
  LLot: TProductionLotProtectionTest;
  LCursor: string;
  LDecoded: TProductionLotProtectionTest;
begin
  AResolver.SetPrivileges([]);
  TBridgeResponseProtectionManager.ClearCache;

  LLot := NewLot;
  try
    LCursor := THorseCursorPagination.EncodeCursor(LLot, []);
    LDecoded := THorseCursorPagination.DecodeCursor<TProductionLotProtectionTest>(LCursor);
    try
      AssertCondition(Assigned(LDecoded), 'Cursor should decode into an entity');
      AssertCondition(LDecoded.Id = LLot.Id, 'Cursor should keep the primary key');
      AssertCondition(LDecoded.TotalCost = 0, 'Cursor must not include protected cost');
      Writeln('SUCCESS: cursor keeps only key/order data and does not expose protected cost');
    finally
      LDecoded.Free;
    end;
  finally
    LLot.Free;
  end;
end;

procedure RunResponseProtectionTest;
var
  LResolver: TTestPrivilegeResolver;
begin
  Writeln('--------------------------------------------------');
  Writeln('TEST: Response protection');
  Writeln('--------------------------------------------------');

  LResolver := TTestPrivilegeResolver.Create([]);
  TBridgeResponseProtectionManager.SetEnabled(True);
  TBridgeResponseProtectionManager.SetFailClosed(True);
  TBridgeResponseProtectionManager.SetCacheTTL(300);
  TBridgeResponseProtectionManager.SetPrivilegeResolver(LResolver as IBridgePrivilegeResolver);
  TBridgeResponseProtectionManager.SetCurrentSubject(
    TBridgePrivilegeSubject.Create('USER_1', 'Operator', 'TENANT_1', []));
  try
    TestDeniedFieldsAreProtected(LResolver);
    TestAllowedFieldsAreVisible(LResolver);
    TestPrivilegeCache(LResolver);
    TestProtectedPropertyAccess(LResolver);
    TestCursorDoesNotExposeProtectedFields(LResolver);
  finally
    TBridgeResponseProtectionManager.ClearCurrentSubject;
    TBridgeResponseProtectionManager.SetPrivilegeResolver(nil);
    TBridgeResponseProtectionManager.ClearCache;
  end;

  Writeln('--------------------------------------------------');
end;

end.
