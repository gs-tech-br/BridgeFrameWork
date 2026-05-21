unit Bridge.ResponseProtection;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  Horse,
  Bridge.Connection.Interfaces,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager;

type
  TBridgePrivilegeSubject = class
  private
    FUserId: string;
    FUserName: string;
    FTenantId: string;
    FRoles: TArray<string>;
  public
    constructor Create(const AUserId, AUserName, ATenantId: string;
      const ARoles: TArray<string>);

    function CacheKey: string;

    property UserId: string read FUserId write FUserId;
    property UserName: string read FUserName write FUserName;
    property TenantId: string read FTenantId write FTenantId;
    property Roles: TArray<string> read FRoles write FRoles;
  end;

  IBridgePrivilegeSubjectProvider = interface
    ['{4207212C-CB90-4C19-9F4D-CE0FA93DF244}']
    function GetSubject(Req: THorseRequest): TBridgePrivilegeSubject;
  end;

  IBridgePrivilegeResolver = interface
    ['{0BF61D08-0BA7-4BA6-8AD7-9A8749882D4F}']
    function GetPrivileges(ASubject: TBridgePrivilegeSubject): TArray<string>;
  end;

  TBridgeHeaderSubjectProvider = class(TInterfacedObject, IBridgePrivilegeSubjectProvider)
  private
    FUserIdHeader: string;
    FUserNameHeader: string;
    FTenantIdHeader: string;
    FRolesHeader: string;
    function HeaderValue(Req: THorseRequest; const AName: string): string;
    function SplitRoles(const ARoles: string): TArray<string>;
  public
    constructor Create(
      const AUserIdHeader: string = 'X-Bridge-User-Id';
      const AUserNameHeader: string = 'X-Bridge-User-Name';
      const ATenantIdHeader: string = 'X-Bridge-Tenant-Id';
      const ARolesHeader: string = 'X-Bridge-Roles');

    function GetSubject(Req: THorseRequest): TBridgePrivilegeSubject;
  end;

  TBridgeDatabasePrivilegeResolver = class(TInterfacedObject, IBridgePrivilegeResolver)
  private
    FConnection: IConnection;
  public
    constructor Create(AConnection: IConnection);
    function GetPrivileges(ASubject: TBridgePrivilegeSubject): TArray<string>;
  end;

  TBridgeResponseProtectionManager = class
  private
    class var FEnabled: Boolean;
    class var FFailClosed: Boolean;
    class var FCacheTTLSeconds: Integer;
    class var FLock: TObject;
    class var FSubjectProvider: IBridgePrivilegeSubjectProvider;
    class var FPrivilegeResolver: IBridgePrivilegeResolver;
    class var FPrivilegeCache: TObjectDictionary<string, TObject>;

    class constructor Initialize;
    class destructor Finalize;

    class function NormalizePrivilege(const APrivilegeCode: string): string;
    class function GetPrivilegesForCurrentSubject: TArray<string>;
    class function HasPrivilege(const APrivilegeCode: string): Boolean;
    class procedure StorePrivilegesInCache(const ACacheKey: string;
      const APrivileges: TArray<string>);
    class function TryGetCachedPrivileges(const ACacheKey: string;
      out APrivileges: TArray<string>): Boolean;
    class procedure ApplyDeniedField(AObject: TJSONObject;
      const AFieldMeta: TProtectedFieldMeta);
    class procedure FilterJSONObject(AObject: TJSONObject; AEntityClass: TClass);
  public
    class procedure SetSubjectProvider(AProvider: IBridgePrivilegeSubjectProvider);
    class procedure SetPrivilegeResolver(AResolver: IBridgePrivilegeResolver);
    class procedure UseHeaderSubjectProvider;

    class procedure SetEnabled(AEnabled: Boolean);
    class procedure SetFailClosed(AFailClosed: Boolean);
    class procedure SetCacheTTL(ASeconds: Integer);
    class procedure ClearCache;
    class procedure InvalidateSubject(const AUserId: string; const ATenantId: string = '');

    class procedure BeginRequest(Req: THorseRequest);
    class procedure EndRequest;
    class function CurrentSubject: TBridgePrivilegeSubject;
    class procedure SetCurrentSubject(ASubject: TBridgePrivilegeSubject; AOwnsSubject: Boolean = True);
    class procedure ClearCurrentSubject;

    class function Middleware: THorseCallback; overload;
    class function Middleware(AEntityClass: TClass): THorseCallback; overload;

    class function FieldNameToJSONName(const AFieldName: string): string;
    class function TryGetProtectedField(const AMetaData: TEntityMetaData;
      const APropMeta: TPropertyMeta; out AFieldMeta: TProtectedFieldMeta): Boolean; overload;
    class function TryGetProtectedField(AEntityClass: TClass;
      const APropertyOrColumnOrJSONName: string; out AFieldMeta: TProtectedFieldMeta): Boolean; overload;
    class function CanAccessField(AEntityClass: TClass;
      const AFieldMeta: TProtectedFieldMeta): Boolean;
    class function CanAccessProperty(AEntityClass: TClass;
      const APropertyOrColumnOrJSONName: string): Boolean;

    class procedure FilterJSON(AJSON: TJSONValue; AEntityClass: TClass);
  end;

implementation

uses
  System.DateUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

type
  TBridgePrivilegeCacheEntry = class
  private
    FExpiresAt: TDateTime;
    FPrivileges: TDictionary<string, Boolean>;
  public
    constructor Create(const APrivileges: TArray<string>; AExpiresAt: TDateTime);
    destructor Destroy; override;
    function ToArray: TArray<string>;
    function Contains(const APrivilegeCode: string): Boolean;
    property ExpiresAt: TDateTime read FExpiresAt;
  end;

threadvar
  GBridgePrivilegeSubject: TBridgePrivilegeSubject;
  GBridgePrivilegeSubjectOwned: Boolean;

{ TBridgePrivilegeSubject }

constructor TBridgePrivilegeSubject.Create(const AUserId, AUserName,
  ATenantId: string; const ARoles: TArray<string>);
begin
  inherited Create;
  FUserId := AUserId;
  FUserName := AUserName;
  FTenantId := ATenantId;
  FRoles := Copy(ARoles, 0, Length(ARoles));
end;

function TBridgePrivilegeSubject.CacheKey: string;
begin
  Result := LowerCase(Trim(FTenantId)) + '|' + LowerCase(Trim(FUserId));
end;

{ TBridgeHeaderSubjectProvider }

constructor TBridgeHeaderSubjectProvider.Create(const AUserIdHeader,
  AUserNameHeader, ATenantIdHeader, ARolesHeader: string);
begin
  inherited Create;
  FUserIdHeader := AUserIdHeader;
  FUserNameHeader := AUserNameHeader;
  FTenantIdHeader := ATenantIdHeader;
  FRolesHeader := ARolesHeader;
end;

function TBridgeHeaderSubjectProvider.HeaderValue(Req: THorseRequest;
  const AName: string): string;
var
  LPair: TPair<string, string>;
begin
  Result := '';
  if not Assigned(Req) then
    Exit;

  for LPair in Req.Headers.Dictionary do
  begin
    if SameText(LPair.Key, AName) then
      Exit(LPair.Value);
  end;
end;

function TBridgeHeaderSubjectProvider.SplitRoles(const ARoles: string): TArray<string>;
var
  LParts: TArray<string>;
  LRole: string;
  I: Integer;
begin
  LParts := ARoles.Split([',']);
  SetLength(Result, 0);
  for LRole in LParts do
  begin
    if LRole.Trim.IsEmpty then
      Continue;

    I := Length(Result);
    SetLength(Result, I + 1);
    Result[I] := LRole.Trim;
  end;
end;

function TBridgeHeaderSubjectProvider.GetSubject(Req: THorseRequest): TBridgePrivilegeSubject;
var
  LUserId: string;
begin
  LUserId := HeaderValue(Req, FUserIdHeader);
  if LUserId.Trim.IsEmpty then
    Exit(nil);

  Result := TBridgePrivilegeSubject.Create(
    LUserId,
    HeaderValue(Req, FUserNameHeader),
    HeaderValue(Req, FTenantIdHeader),
    SplitRoles(HeaderValue(Req, FRolesHeader)));
end;

{ TBridgeDatabasePrivilegeResolver }

constructor TBridgeDatabasePrivilegeResolver.Create(AConnection: IConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TBridgeDatabasePrivilegeResolver.GetPrivileges(
  ASubject: TBridgePrivilegeSubject): TArray<string>;
var
  LQuery: TFDQuery;
  LAllows: TDictionary<string, Boolean>;
  LDenies: TDictionary<string, Boolean>;
  LCode: string;
  LEffect: string;
  LPair: TPair<string, Boolean>;
  I: Integer;
const
  SQL_PRIVILEGES =
    'SELECT DISTINCT P.CODE, RP.EFFECT ' +
    'FROM BRIDGE_PRIVILEGE P ' +
    'JOIN BRIDGE_ROLE_PRIVILEGE RP ON RP.PRIVILEGE_ID = P.ID ' +
    'JOIN BRIDGE_ROLE R ON R.ID = RP.ROLE_ID ' +
    'JOIN BRIDGE_USER_ROLE UR ON UR.ROLE_ID = R.ID ' +
    'WHERE P.ACTIVE = 1 ' +
    'AND R.ACTIVE = 1 ' +
    'AND RP.ACTIVE = 1 ' +
    'AND UR.ACTIVE = 1 ' +
    'AND UR.USER_ID = :USER_ID ' +
    'AND (:TENANT_ID = '''' OR UR.TENANT_ID = :TENANT_ID OR UR.TENANT_ID IS NULL OR UR.TENANT_ID = '''')';
begin
  SetLength(Result, 0);
  if (not Assigned(FConnection)) or (not Assigned(ASubject)) or ASubject.UserId.Trim.IsEmpty then
    Exit;

  LAllows := TDictionary<string, Boolean>.Create;
  LDenies := TDictionary<string, Boolean>.Create;
  try
    LQuery := FConnection.CreateDataSet(SQL_PRIVILEGES);
    try
      LQuery.ParamByName('USER_ID').AsString := ASubject.UserId;
      LQuery.ParamByName('TENANT_ID').AsString := ASubject.TenantId;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        LCode := LowerCase(Trim(LQuery.FieldByName('CODE').AsString));
        LEffect := UpperCase(Trim(LQuery.FieldByName('EFFECT').AsString));

        if not LCode.IsEmpty then
        begin
          if LEffect = 'DENY' then
            LDenies.AddOrSetValue(LCode, True)
          else
            LAllows.AddOrSetValue(LCode, True);
        end;

        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;

    SetLength(Result, 0);
    for LPair in LAllows do
    begin
      if LDenies.ContainsKey(LPair.Key) then
        Continue;

      I := Length(Result);
      SetLength(Result, I + 1);
      Result[I] := LPair.Key;
    end;
  finally
    LAllows.Free;
    LDenies.Free;
  end;
end;

{ TBridgePrivilegeCacheEntry }

constructor TBridgePrivilegeCacheEntry.Create(const APrivileges: TArray<string>;
  AExpiresAt: TDateTime);
var
  LPrivilege: string;
  LCode: string;
begin
  inherited Create;
  FExpiresAt := AExpiresAt;
  FPrivileges := TDictionary<string, Boolean>.Create;
  for LPrivilege in APrivileges do
  begin
    LCode := LowerCase(Trim(LPrivilege));
    if not LCode.IsEmpty then
      FPrivileges.AddOrSetValue(LCode, True);
  end;
end;

destructor TBridgePrivilegeCacheEntry.Destroy;
begin
  FPrivileges.Free;
  inherited;
end;

function TBridgePrivilegeCacheEntry.Contains(const APrivilegeCode: string): Boolean;
begin
  Result := FPrivileges.ContainsKey(LowerCase(Trim(APrivilegeCode)));
end;

function TBridgePrivilegeCacheEntry.ToArray: TArray<string>;
var
  LPair: TPair<string, Boolean>;
  I: Integer;
begin
  SetLength(Result, FPrivileges.Count);
  I := 0;
  for LPair in FPrivileges do
  begin
    Result[I] := LPair.Key;
    Inc(I);
  end;
end;

{ TBridgeResponseProtectionManager }

class constructor TBridgeResponseProtectionManager.Initialize;
begin
  FEnabled := True;
  FFailClosed := True;
  FCacheTTLSeconds := 300;
  FLock := TObject.Create;
  FPrivilegeCache := TObjectDictionary<string, TObject>.Create([doOwnsValues]);
end;

class destructor TBridgeResponseProtectionManager.Finalize;
begin
  ClearCurrentSubject;
  FSubjectProvider := nil;
  FPrivilegeResolver := nil;
  FPrivilegeCache.Free;
  FLock.Free;
end;

class function TBridgeResponseProtectionManager.NormalizePrivilege(
  const APrivilegeCode: string): string;
begin
  Result := LowerCase(Trim(APrivilegeCode));
end;

class procedure TBridgeResponseProtectionManager.SetSubjectProvider(
  AProvider: IBridgePrivilegeSubjectProvider);
begin
  FSubjectProvider := AProvider;
end;

class procedure TBridgeResponseProtectionManager.SetPrivilegeResolver(
  AResolver: IBridgePrivilegeResolver);
begin
  ClearCache;
  FPrivilegeResolver := AResolver;
end;

class procedure TBridgeResponseProtectionManager.UseHeaderSubjectProvider;
begin
  SetSubjectProvider(TBridgeHeaderSubjectProvider.Create);
end;

class procedure TBridgeResponseProtectionManager.SetEnabled(AEnabled: Boolean);
begin
  FEnabled := AEnabled;
end;

class procedure TBridgeResponseProtectionManager.SetFailClosed(AFailClosed: Boolean);
begin
  FFailClosed := AFailClosed;
end;

class procedure TBridgeResponseProtectionManager.SetCacheTTL(ASeconds: Integer);
begin
  if ASeconds < 0 then
    ASeconds := 0;
  FCacheTTLSeconds := ASeconds;
end;

class procedure TBridgeResponseProtectionManager.ClearCache;
begin
  TMonitor.Enter(FLock);
  try
    if Assigned(FPrivilegeCache) then
      FPrivilegeCache.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TBridgeResponseProtectionManager.InvalidateSubject(
  const AUserId, ATenantId: string);
var
  LKey: string;
  LPair: TPair<string, TObject>;
  LKeysToRemove: TList<string>;
begin
  LKey := LowerCase(Trim(ATenantId)) + '|' + LowerCase(Trim(AUserId));

  TMonitor.Enter(FLock);
  try
    if not Trim(ATenantId).IsEmpty then
    begin
      FPrivilegeCache.Remove(LKey);
      Exit;
    end;

    LKeysToRemove := TList<string>.Create;
    try
      for LPair in FPrivilegeCache do
      begin
        if LPair.Key.EndsWith('|' + LowerCase(Trim(AUserId))) then
          LKeysToRemove.Add(LPair.Key);
      end;

      for LKey in LKeysToRemove do
        FPrivilegeCache.Remove(LKey);
    finally
      LKeysToRemove.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TBridgeResponseProtectionManager.BeginRequest(Req: THorseRequest);
var
  LSubject: TBridgePrivilegeSubject;
begin
  ClearCurrentSubject;
  LSubject := nil;

  if Assigned(FSubjectProvider) then
    LSubject := FSubjectProvider.GetSubject(Req);

  SetCurrentSubject(LSubject, True);
end;

class procedure TBridgeResponseProtectionManager.EndRequest;
begin
  ClearCurrentSubject;
end;

class function TBridgeResponseProtectionManager.CurrentSubject: TBridgePrivilegeSubject;
begin
  Result := GBridgePrivilegeSubject;
end;

class procedure TBridgeResponseProtectionManager.SetCurrentSubject(
  ASubject: TBridgePrivilegeSubject; AOwnsSubject: Boolean);
begin
  ClearCurrentSubject;
  GBridgePrivilegeSubject := ASubject;
  GBridgePrivilegeSubjectOwned := AOwnsSubject;
end;

class procedure TBridgeResponseProtectionManager.ClearCurrentSubject;
begin
  if GBridgePrivilegeSubjectOwned then
    FreeAndNil(GBridgePrivilegeSubject)
  else
    GBridgePrivilegeSubject := nil;

  GBridgePrivilegeSubjectOwned := False;
end;

class function TBridgeResponseProtectionManager.Middleware: THorseCallback;
begin
  Result := Middleware(nil);
end;

class function TBridgeResponseProtectionManager.Middleware(
  AEntityClass: TClass): THorseCallback;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LContent: TObject;
    begin
      BeginRequest(Req);
      try
        Next;
        LContent := Res.Content;
        if Assigned(LContent) and (LContent is TJSONValue) then
          FilterJSON(TJSONValue(LContent), AEntityClass);
      finally
        EndRequest;
      end;
    end;
end;

class function TBridgeResponseProtectionManager.FieldNameToJSONName(
  const AFieldName: string): string;
var
  LName: string;
  LFirstChar: Char;
begin
  LName := AFieldName;
  if LName.StartsWith('F') and (LName.Length > 1) then
    LName := LName.Substring(1);

  Result := LName;
  if Result.IsEmpty then
    Exit;

  LFirstChar := LowerCase(Result.Chars[0]).Chars[0];
  Result := Result.Remove(0, 1).Insert(0, LFirstChar);
end;

class function TBridgeResponseProtectionManager.TryGetProtectedField(
  const AMetaData: TEntityMetaData; const APropMeta: TPropertyMeta;
  out AFieldMeta: TProtectedFieldMeta): Boolean;
var
  LFieldMeta: TProtectedFieldMeta;
begin
  Result := False;
  AFieldMeta := Default(TProtectedFieldMeta);

  if not AMetaData.ResponseProtectionEnabled then
    Exit;

  for LFieldMeta in AMetaData.ProtectedFields do
  begin
    if Assigned(APropMeta.RttiField) and (LFieldMeta.RttiField = APropMeta.RttiField) then
    begin
      AFieldMeta := LFieldMeta;
      Exit(True);
    end;
  end;
end;

class function TBridgeResponseProtectionManager.TryGetProtectedField(
  AEntityClass: TClass; const APropertyOrColumnOrJSONName: string;
  out AFieldMeta: TProtectedFieldMeta): Boolean;
var
  LMetaData: TEntityMetaData;
  LFieldMeta: TProtectedFieldMeta;
  LName: string;
begin
  Result := False;
  AFieldMeta := Default(TProtectedFieldMeta);
  if not Assigned(AEntityClass) then
    Exit;

  LName := Trim(APropertyOrColumnOrJSONName);
  if LName.IsEmpty then
    Exit;

  LMetaData := TMetaDataManager.Instance.GetMetaData(AEntityClass);
  if not LMetaData.ResponseProtectionEnabled then
    Exit;

  for LFieldMeta in LMetaData.ProtectedFields do
  begin
    if SameText(LFieldMeta.PropertyName, LName) or
       SameText(LFieldMeta.ColumnName, LName) or
       SameText(LFieldMeta.JSONName, LName) then
    begin
      AFieldMeta := LFieldMeta;
      Exit(True);
    end;
  end;
end;

class function TBridgeResponseProtectionManager.GetPrivilegesForCurrentSubject: TArray<string>;
var
  LSubject: TBridgePrivilegeSubject;
  LCacheKey: string;
begin
  SetLength(Result, 0);
  LSubject := CurrentSubject;
  if not Assigned(LSubject) then
    Exit;

  LCacheKey := LSubject.CacheKey;
  if TryGetCachedPrivileges(LCacheKey, Result) then
    Exit;

  if Assigned(FPrivilegeResolver) then
    Result := FPrivilegeResolver.GetPrivileges(LSubject);

  StorePrivilegesInCache(LCacheKey, Result);
end;

class function TBridgeResponseProtectionManager.TryGetCachedPrivileges(
  const ACacheKey: string; out APrivileges: TArray<string>): Boolean;
var
  LEntryObject: TObject;
  LEntry: TBridgePrivilegeCacheEntry;
begin
  Result := False;
  SetLength(APrivileges, 0);
  if ACacheKey.Trim.IsEmpty or (FCacheTTLSeconds = 0) then
    Exit;

  TMonitor.Enter(FLock);
  try
    if not FPrivilegeCache.TryGetValue(ACacheKey, LEntryObject) then
      Exit;

    LEntry := TBridgePrivilegeCacheEntry(LEntryObject);
    if LEntry.ExpiresAt < Now then
    begin
      FPrivilegeCache.Remove(ACacheKey);
      Exit;
    end;

    APrivileges := LEntry.ToArray;
    Result := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TBridgeResponseProtectionManager.StorePrivilegesInCache(
  const ACacheKey: string; const APrivileges: TArray<string>);
var
  LEntry: TBridgePrivilegeCacheEntry;
begin
  if ACacheKey.Trim.IsEmpty or (FCacheTTLSeconds = 0) then
    Exit;

  LEntry := TBridgePrivilegeCacheEntry.Create(APrivileges,
    IncSecond(Now, FCacheTTLSeconds));

  TMonitor.Enter(FLock);
  try
    FPrivilegeCache.Remove(ACacheKey);
    FPrivilegeCache.Add(ACacheKey, LEntry);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TBridgeResponseProtectionManager.HasPrivilege(
  const APrivilegeCode: string): Boolean;
var
  LPrivileges: TArray<string>;
  LPrivilege: string;
  LCode: string;
  LCurrentPrivilege: string;
  LSubject: TBridgePrivilegeSubject;
begin
  Result := False;
  LCode := NormalizePrivilege(APrivilegeCode);
  if LCode.IsEmpty then
    Exit(not FFailClosed);

  LSubject := CurrentSubject;
  if (not Assigned(LSubject)) or (not Assigned(FPrivilegeResolver)) then
    Exit(not FFailClosed);

  LPrivileges := GetPrivilegesForCurrentSubject;
  for LPrivilege in LPrivileges do
  begin
    LCurrentPrivilege := NormalizePrivilege(LPrivilege);
    if (LCurrentPrivilege = '*') or SameText(LCurrentPrivilege, LCode) then
      Exit(True);
  end;
end;

class function TBridgeResponseProtectionManager.CanAccessField(
  AEntityClass: TClass; const AFieldMeta: TProtectedFieldMeta): Boolean;
begin
  if not FEnabled then
    Exit(True);

  Result := HasPrivilege(AFieldMeta.PrivilegeCode);
end;

class function TBridgeResponseProtectionManager.CanAccessProperty(
  AEntityClass: TClass; const APropertyOrColumnOrJSONName: string): Boolean;
var
  LFieldMeta: TProtectedFieldMeta;
begin
  if not TryGetProtectedField(AEntityClass, APropertyOrColumnOrJSONName, LFieldMeta) then
    Exit(True);

  Result := CanAccessField(AEntityClass, LFieldMeta);
end;

class procedure TBridgeResponseProtectionManager.ApplyDeniedField(
  AObject: TJSONObject; const AFieldMeta: TProtectedFieldMeta);
var
  LPair: TJSONPair;
  LMaskValue: string;
begin
  if not Assigned(AObject) then
    Exit;

  LPair := AObject.RemovePair(AFieldMeta.JSONName);
  if Assigned(LPair) then
    LPair.Free;

  case AFieldMeta.DenyStrategy of
    pfNull:
      AObject.AddPair(AFieldMeta.JSONName, TJSONNull.Create);
    pfMask:
      begin
        LMaskValue := AFieldMeta.MaskValue;
        if LMaskValue.IsEmpty then
          LMaskValue := '***';
        AObject.AddPair(AFieldMeta.JSONName, LMaskValue);
      end;
  else
    // pfRemove: the pair was already removed.
  end;
end;

class procedure TBridgeResponseProtectionManager.FilterJSONObject(
  AObject: TJSONObject; AEntityClass: TClass);
var
  LMetaData: TEntityMetaData;
  LFieldMeta: TProtectedFieldMeta;
begin
  if (not FEnabled) or (not Assigned(AObject)) or (not Assigned(AEntityClass)) then
    Exit;

  LMetaData := TMetaDataManager.Instance.GetMetaData(AEntityClass);
  if not LMetaData.ResponseProtectionEnabled then
    Exit;

  for LFieldMeta in LMetaData.ProtectedFields do
  begin
    if not CanAccessField(AEntityClass, LFieldMeta) then
      ApplyDeniedField(AObject, LFieldMeta);
  end;
end;

class procedure TBridgeResponseProtectionManager.FilterJSON(AJSON: TJSONValue;
  AEntityClass: TClass);
var
  I: Integer;
  LObject: TJSONObject;
  LData: TJSONValue;
begin
  if (not FEnabled) or (not Assigned(AJSON)) or (not Assigned(AEntityClass)) then
    Exit;

  if AJSON is TJSONArray then
  begin
    for I := 0 to TJSONArray(AJSON).Count - 1 do
      FilterJSON(TJSONArray(AJSON).Items[I], AEntityClass);
    Exit;
  end;

  if AJSON is TJSONObject then
  begin
    LObject := TJSONObject(AJSON);
    LData := LObject.GetValue('data');
    if Assigned(LData) and (LData is TJSONArray) then
      FilterJSON(LData, AEntityClass);

    FilterJSONObject(LObject, AEntityClass);
  end;
end;

end.
