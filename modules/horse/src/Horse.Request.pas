unit Horse.Request;

{$IF DEFINED(FPC)}
{$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  SysUtils,
  fpHTTP,
  HTTPDefs,
{$ELSE}
  System.SysUtils,
  Web.HTTPApp,
{$IF CompilerVersion > 32.0}
  Web.ReqMulti,
{$ENDIF}
{$ENDIF}
  Horse.Core.Param,
  Horse.Session,
  Horse.Commons;

function DecodePossibleUtf8Mojibake(const AValue: string): string;

type
  THorseRequest = class
  private
    FWebRequest: {$IF DEFINED(FPC)}TRequest{$ELSE}TWebRequest{$ENDIF};
    FHeaders: THorseCoreParam;
    FQuery: THorseCoreParam;
    FParams: THorseCoreParam;
    FContentFields: THorseCoreParam;
    FCookie: THorseCoreParam;
    FBody: TObject;
    FSession: TObject;
    FSessions: THorseSessions;
    procedure InitializeQuery;
    procedure InitializeParams;
    procedure InitializeContentFields;
    procedure InitializeCookie;
    function IsMultipartForm: Boolean;
    function IsFormURLEncoded: Boolean;
    function CanLoadContentFields: Boolean;
  public
    function Body: string; overload; virtual;
    function Body<T: class>: T; overload;
    function Body(const ABody: TObject): THorseRequest; overload; virtual;
    function Session<T: class>: T; overload;
    function Session(const ASession: TObject): THorseRequest; overload; virtual;
    function Headers: THorseCoreParam; virtual;
    function Query: THorseCoreParam; virtual;
    function Params: THorseCoreParam; virtual;
    function Cookie: THorseCoreParam; virtual;
    function ContentFields: THorseCoreParam; virtual;
    function Sessions: THorseSessions; virtual;
    function MethodType: TMethodType; virtual;
    function ContentType: string; virtual;
    function Host: string; virtual;
    function PathInfo: string; virtual;
    function RawWebRequest: {$IF DEFINED(FPC)}TRequest{$ELSE}TWebRequest{$ENDIF}; virtual;
    constructor Create(const AWebRequest: {$IF DEFINED(FPC)}TRequest{$ELSE}TWebRequest{$ENDIF});
    destructor Destroy; override;
  end;

implementation

uses      
{$IF DEFINED(FPC)}
  Classes,
{$ELSE}
  System.Classes,
{$ENDIF}
  Horse.Core.Param.Header;

{$IFNDEF FPC}
function CountMojibakeMarkers(const AValue: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(AValue) do
  begin
    if (AValue[I] = #$00C2) or
       (AValue[I] = #$00C3) or
       (AValue[I] = #$00E2) then
      Inc(Result);
  end;
end;

function HasUnicodeReplacementChar(const AValue: string): Boolean;
begin
  Result := Pos(#$FFFD, AValue) > 0;
end;

function TryGetWindows1252Byte(const AChar: Char; out AByte: Byte): Boolean;
begin
  Result := True;

  if Ord(AChar) <= $FF then
  begin
    AByte := Byte(Ord(AChar));
    Exit;
  end;

  case Ord(AChar) of
    $20AC: AByte := $80;
    $201A: AByte := $82;
    $0192: AByte := $83;
    $201E: AByte := $84;
    $2026: AByte := $85;
    $2020: AByte := $86;
    $2021: AByte := $87;
    $02C6: AByte := $88;
    $2030: AByte := $89;
    $0160: AByte := $8A;
    $2039: AByte := $8B;
    $0152: AByte := $8C;
    $017D: AByte := $8E;
    $2018: AByte := $91;
    $2019: AByte := $92;
    $201C: AByte := $93;
    $201D: AByte := $94;
    $2022: AByte := $95;
    $2013: AByte := $96;
    $2014: AByte := $97;
    $02DC: AByte := $98;
    $2122: AByte := $99;
    $0161: AByte := $9A;
    $203A: AByte := $9B;
    $0153: AByte := $9C;
    $017E: AByte := $9E;
    $0178: AByte := $9F;
  else
    Result := False;
  end;
end;

function TryDecodeWindows1252TextAsUtf8(
  const AValue: string;
  out ADecoded: string
): Boolean;
var
  I: Integer;
  LBytes: TBytes;
  LByte: Byte;
begin
  Result := False;
  ADecoded := '';
  SetLength(LBytes, Length(AValue));

  for I := 1 to Length(AValue) do
  begin
    if not TryGetWindows1252Byte(AValue[I], LByte) then
      Exit;

    LBytes[I - 1] := LByte;
  end;

  try
    ADecoded := TEncoding.UTF8.GetString(LBytes);
    Result := not HasUnicodeReplacementChar(ADecoded);
  except
    ADecoded := '';
  end;
end;
{$ENDIF}

function DecodePossibleUtf8Mojibake(const AValue: string): string;
{$IFNDEF FPC}
var
  LDecoded: string;
  LMarkerCount: Integer;
{$ENDIF}
begin
  Result := AValue;

{$IFNDEF FPC}
  LMarkerCount := CountMojibakeMarkers(AValue);
  if LMarkerCount = 0 then
    Exit;

  if not TryDecodeWindows1252TextAsUtf8(AValue, LDecoded) then
    Exit;

  if CountMojibakeMarkers(LDecoded) < LMarkerCount then
    Result := LDecoded;
{$ENDIF}
end;

function THorseRequest.Body: string;
begin
  Result := DecodePossibleUtf8Mojibake(FWebRequest.Content);
end;

function THorseRequest.Body(const ABody: TObject): THorseRequest;
begin
  Result := Self;
  if Assigned(FBody) then
    FBody.Free;
  FBody := ABody;
end;

function THorseRequest.Body<T>: T;
begin
  Result := T(FBody);
end;

function THorseRequest.CanLoadContentFields: Boolean;
begin
  Result := IsMultipartForm or IsFormURLEncoded;
end;

function THorseRequest.ContentFields: THorseCoreParam;
begin
  if not Assigned(FContentFields) then
    InitializeContentFields;
  Result := FContentFields;
end;

function THorseRequest.Cookie: THorseCoreParam;
begin
  if not Assigned(FCookie) then
    InitializeCookie;
  Result := FCookie;
end;

constructor THorseRequest.Create(const AWebRequest: {$IF DEFINED(FPC)}TRequest{$ELSE}TWebRequest{$ENDIF});
begin
  FWebRequest := AWebRequest;
  FSessions := THorseSessions.Create;
end;

destructor THorseRequest.Destroy;
begin
  if Assigned(FHeaders) then
    FreeAndNil(FHeaders);
  if Assigned(FQuery) then
    FreeAndNil(FQuery);
  if Assigned(FParams) then
    FreeAndNil(FParams);
  if Assigned(FContentFields) then
    FreeAndNil(FContentFields);
  if Assigned(FCookie) then
    FreeAndNil(FCookie);
  if Assigned(FBody) then
    FBody.Free;
  if Assigned(FSessions) then
    FSessions.Free;
  inherited;
end;

function THorseRequest.Headers: THorseCoreParam;
var
  LParam: THorseList;
begin
  if not Assigned(FHeaders) then
  begin
    LParam := THorseCoreParamHeader.GetHeaders(FWebRequest);
    FHeaders := THorseCoreParam.Create(LParam).Required(False);
  end;
  Result := FHeaders;
end;

function THorseRequest.Host: string;
begin
  Result := FWebRequest.Host;
end;

function THorseRequest.ContentType: string;
begin
  Result := FWebRequest.ContentType;
end;

function THorseRequest.PathInfo: string;
var
  LPrefix: string;
begin
  LPrefix := EmptyStr;
  if FWebRequest.PathInfo = EmptyStr then
    LPrefix := '/';
  Result := LPrefix + FWebRequest.PathInfo;
end;

procedure THorseRequest.InitializeContentFields;
{$IF NOT DEFINED(FPC)}
const
  CONTENT_DISPOSITION = 'Content-Disposition: form-data; name=';
{$ENDIF}
var
  I: Integer;
  LName: String;
  LValue: String;
begin
  FContentFields := THorseCoreParam.Create(THorseList.Create).Required(False);
  if (not CanLoadContentFields) then
    Exit;

  for I := 0 to Pred(FWebRequest.Files.Count) do
    FContentFields.AddStream(FWebRequest.Files[I].FieldName, FWebRequest.Files[I].Stream);

  for I := 0 to Pred(FWebRequest.ContentFields.Count) do
  begin
    if IsMultipartForm then
    begin
{$IF DEFINED(FPC)}
      LName := FWebRequest.ContentFields.Names[I];
      LValue := FWebRequest.ContentFields.ValueFromIndex[I];
{$ELSE}
{$IF CompilerVersion <= 31.0}
      if FWebRequest.ContentFields[I].StartsWith(CONTENT_DISPOSITION) then
      begin
        LName := FWebRequest.ContentFields[I]
          .Replace(CONTENT_DISPOSITION, EmptyStr)
          .Replace('"', EmptyStr);
        LValue := FWebRequest.ContentFields[I + 1];
      end;
{$ELSE}
      LName := FWebRequest.ContentFields.Names[I];
      LValue := FWebRequest.ContentFields.ValueFromIndex[I];
{$ENDIF}
{$ENDIF}
    end
    else
    begin
      LName := FWebRequest.ContentFields.Names[I];
      LValue := FWebRequest.ContentFields.ValueFromIndex[I];
    end;

    if LName <> EmptyStr then
    begin
      LName := DecodePossibleUtf8Mojibake(LName);
      LValue := DecodePossibleUtf8Mojibake(LValue);
      FContentFields.Dictionary.AddOrSetValue(LName, LValue);
    end;

    LName := EmptyStr;
    LValue := EmptyStr;
  end;
end;

procedure THorseRequest.InitializeCookie;
const
  KEY = 0;
  VALUE = 1;
var
  LParam: TArray<string>;
  LItem: string;
begin
  FCookie := THorseCoreParam.Create(THorseList.Create).Required(False);
  for LItem in FWebRequest.CookieFields do
  begin
    LParam := LItem.Split(['=']);
    FCookie.Dictionary.AddOrSetValue(LParam[KEY], LParam[VALUE]);
  end;
end;

procedure THorseRequest.InitializeParams;
begin
  FParams := THorseCoreParam.Create(THorseList.Create).Required(True);
end;

procedure THorseRequest.InitializeQuery;
var
  LItem, LKey, LValue: string;
  LEqualFirstPos: Integer;
begin
  FQuery := THorseCoreParam.Create(THorseList.Create).Required(False);
  for LItem in FWebRequest.QueryFields do
  begin
    LEqualFirstPos := Pos('=', LItem);
    LKey := Copy(LItem, 1, LEqualFirstPos - 1);
    LValue := Copy(LItem, LEqualFirstPos + 1, Length(LItem));
    LKey := DecodePossibleUtf8Mojibake(LKey);
    LValue := DecodePossibleUtf8Mojibake(LValue);

    if not FQuery.Dictionary.ContainsKey(LKey) then
      FQuery.Dictionary.AddOrSetValue(LKey, LValue)
    else
      FQuery.Dictionary[LKey] := FQuery.Dictionary[LKey] +','+ LValue;
  end;
end;

function THorseRequest.IsFormURLEncoded: Boolean;
var
  LContentType, LFormUrlEncoded: string;
begin
  LContentType := FWebRequest.ContentType;
  LFormUrlEncoded := TMimeTypes.ApplicationXWWWFormURLEncoded.ToString;
{$IF DEFINED(FPC)}
  Result := StrLIComp(PChar(LContentType), PChar(LFormUrlEncoded), Length(LFormUrlEncoded)) = 0;
{$ELSE}
{$IF CompilerVersion <= 30}
  Result := LContentType = PChar(LFormUrlEncoded);
{$ELSE}
  Result := StrLIComp(PChar(LContentType), PChar(LFormUrlEncoded), Length(LFormUrlEncoded)) = 0;
{$IFEND}
{$ENDIF}
end;

function THorseRequest.IsMultipartForm: Boolean;
var
  LContentType, LFormData: string;
begin
  LContentType := FWebRequest.ContentType;
  LFormData := TMimeTypes.MultiPartFormData.ToString;
{$IF DEFINED(FPC)}
  Result := StrLIComp(PChar(LContentType), PChar(LFormData), Length(PChar(LFormData))) = 0;
{$ELSE}
{$IF CompilerVersion <= 30}
  Result := LContentType = PChar(LFormData);
{$ELSE}
  Result := StrLIComp(PChar(LContentType), PChar(LFormData), Length(PChar(LFormData))) = 0;
{$IFEND}
{$ENDIF}
end;

function THorseRequest.MethodType: TMethodType;
begin
  Result := {$IF DEFINED(FPC)}StringCommandToMethodType(FWebRequest.Method); {$ELSE}FWebRequest.MethodType; {$ENDIF}
end;

function THorseRequest.Params: THorseCoreParam;
begin
  if not Assigned(FParams) then
    InitializeParams;
  Result := FParams;
end;

function THorseRequest.Query: THorseCoreParam;
begin
  if not Assigned(FQuery) then
    InitializeQuery;
  Result := FQuery;
end;

function THorseRequest.RawWebRequest: {$IF DEFINED(FPC)}TRequest{$ELSE}TWebRequest{$ENDIF};
begin
  Result := FWebRequest;
end;

function THorseRequest.Session(const ASession: TObject): THorseRequest;
begin
  Result := Self;
  FSession := ASession;
end;

function THorseRequest.Session<T>: T;
begin
  Result := T(FSession);
end;

function THorseRequest.Sessions: THorseSessions;
begin
  Result := FSessions;
end;

end.
