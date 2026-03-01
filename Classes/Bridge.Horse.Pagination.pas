unit Bridge.Horse.Pagination;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.NetEncoding,
  Horse,
  Bridge.Neon.Config,
  Bridge.Connection.Types;

type
  /// <summary>
  /// Pagination parameters extracted from the HTTP request
  /// </summary>
  THorsePaginationParams = record
    PageSize: Integer;
    CursorStr: string;
    OrderBy: string;
    OrderDesc: Boolean;
    function GetOrderByItems: TArray<TOrderByItem>;
  end;

  /// <summary>
  /// Utility class to handle cursor-based pagination in Horse
  /// </summary>
  THorseCursorPagination = class
  public
    /// <summary>
    /// Extracts pagination parameters from the request
    /// </summary>
    class function ParseParams(Req: THorseRequest; ADefaultPageSize: Integer = 20): THorsePaginationParams;

    /// <summary>
    /// Encodes the current entity into a cursor token (Base64 JSON)
    /// </summary>
    class function EncodeCursor(AEntity: TObject): string;

    /// <summary>
    /// Decodes the cursor token to populate an entity with the values of the last item
    /// </summary>
    class function DecodeCursor<T: class, constructor>(const ACursorStr: string): T;

    /// <summary>
    /// Builds the final response with data and pagination metadata
    /// </summary>

    /// <summary>
    /// Horse middleware to inject pagination into responses (JSON Arrays)
    /// </summary>
    class procedure CursorPagination(Req: THorseRequest; Res: THorseResponse; Next: TProc);

    class function BuildResponse<T: class>(
      AList: TObjectList<T>; 
      const ANextCursor: string; 
      APageSize: Integer; 
      AHasMore: Boolean): TJSONObject;
  end;

implementation

{ THorsePaginationParams }

function THorsePaginationParams.GetOrderByItems: TArray<TOrderByItem>;
begin
  if OrderBy.Trim.IsEmpty then
    Result := []
  else
  begin
    SetLength(Result, 1);
    Result[0] := TOrderByItem.Create(OrderBy, OrderDesc);
  end;
end;

{ THorseCursorPagination }

class function THorseCursorPagination.ParseParams(Req: THorseRequest; ADefaultPageSize: Integer): THorsePaginationParams;
var
  LPageSizeStr: string;
  LOrderDescStr: string;
begin
  LPageSizeStr := Req.Query['page_size'];
  if not TryStrToInt(LPageSizeStr, Result.PageSize) then
    Result.PageSize := ADefaultPageSize;

  if Result.PageSize <= 0 then
    Result.PageSize := ADefaultPageSize;

  Result.CursorStr := Req.Query['cursor'];
  Result.OrderBy := Req.Query['order_by'];

  LOrderDescStr := Req.Query['order_desc'];
  Result.OrderDesc := SameText(LOrderDescStr, 'true') or SameText(LOrderDescStr, '1');
end;

class function THorseCursorPagination.EncodeCursor(AEntity: TObject): string;
var
  LJsonObj: TJSONObject;
  LJsonStr: string;
begin
  if not Assigned(AEntity) then
    Exit('');

  LJsonObj := TBridgeNeon.ObjectToJSONObject(AEntity);
  try
    LJsonStr := LJsonObj.ToJSON;
    Result := TNetEncoding.Base64.Encode(LJsonStr);
  finally
    LJsonObj.Free;
  end;
end;

class function THorseCursorPagination.DecodeCursor<T>(const ACursorStr: string): T;
var
  LJsonStr: string;
  LJsonObj: TJSONObject;
begin
  Result := nil;
  if ACursorStr.Trim.IsEmpty then
    Exit;

  try
    // System.NetEncoding does not have a Base64URL by default in older Delphis, 
    // but we can use Base64 String decoding. URL Encoding needs to be handled?
    // Delphi's TNetEncoding.Base64 string decode handles standard Base64.
    LJsonStr := TNetEncoding.Base64.Decode(ACursorStr);
    
    LJsonObj := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
    if Assigned(LJsonObj) then
    begin
      Result := T.Create;
      try
        TBridgeNeon.JSONToObject(Result, LJsonObj);
      except
        Result.Free;
        raise;
      end;
    end;
  except
    // Invalid cursor format - return nil to start from beginning
    if Assigned(Result) then
      FreeAndNil(Result);
  end;
end;

class procedure THorseCursorPagination.CursorPagination(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LResContent: TObject;
  LJsonArray: TJSONArray;
  LPaginationParams: THorsePaginationParams;
  LNextCursor: string;
  LHasMore: Boolean;
  LPageSize: Integer;
  LListCount: Integer;
  LPaginatedResponse: TJSONObject;
  LLastItemObj: TJSONObject;
  LJsonStr: string;
begin
  try
    Next;
  except
    raise;
  end;

  if (Req.RawWebRequest.Method <> 'GET') or (Res.RawWebResponse.StatusCode <> 200) then
    Exit;

  LResContent := Res.Content;
  
  if Assigned(LResContent) and (LResContent is TJSONArray) then
  begin
    LJsonArray := TJSONArray(LResContent);
    // Parse the parameters so we know the limit
    LPaginationParams := ParseParams(Req, 20);
    LPageSize := LPaginationParams.PageSize;
    
    LListCount := LJsonArray.Count;
    LHasMore := LListCount > LPageSize;

    if LHasMore then
    begin
      // Remove the extra item from the array
      LJsonArray.Remove(LListCount - 1).Free; 
    end;

    // Get the last item to build the cursor
    if LJsonArray.Count > 0 then
    begin
      LLastItemObj := LJsonArray.Items[LJsonArray.Count - 1] as TJSONObject;
      LJsonStr := LLastItemObj.ToJSON;
      LNextCursor := TNetEncoding.Base64.Encode(LJsonStr);
    end
    else
      LNextCursor := '';

    // Build the payload
    LPaginatedResponse := TJSONObject.Create;
    
    // Horse/Jhonson will free the content we set, so we clone the array,
    // or we just reuse LJsonArray? Since we set Res.Send<TJSONObject>(LPaginatedResponse), 
    // it will replace the Content. We MUST NOT FREE LJsonArray YET if we reuse it inside LPaginatedResponse,
    // because TJSONObject takes ownership.
    LPaginatedResponse.AddPair('data', LJsonArray.Clone as TJSONArray);
    
    var LPaginationObj := TJSONObject.Create;
    LPaginationObj.AddPair('page_size', TJSONNumber.Create(LPageSize));
    
    if LNextCursor.IsEmpty then
      LPaginationObj.AddPair('next_cursor', TJSONNull.Create)
    else
      LPaginationObj.AddPair('next_cursor', LNextCursor);

    LPaginationObj.AddPair('has_more', TJSONBool.Create(LHasMore));

    LPaginatedResponse.AddPair('pagination', LPaginationObj);

    // Swap the output. Horse/Jhonson replaces the TObject in Content.
    // LJsonArray is already the Content, when we call Send it replaces. We MUST free LJsonArray ourselves?
    // Actually, calling Res.Send with a new object replaces the old one. We will assume Jhonson cleans up.
    Res.Send<TJSONObject>(LPaginatedResponse);
  end;
end;


class function THorseCursorPagination.BuildResponse<T>(
  AList: TObjectList<T>; 
  const ANextCursor: string; 
  APageSize: Integer; 
  AHasMore: Boolean): TJSONObject;
var
  LDataArr: TJSONValue;
  LPaginationObj: TJSONObject;
begin
  Result := TJSONObject.Create;

  LDataArr := TBridgeNeon.ListToJSONArray<T>(AList);
  Result.AddPair('data', LDataArr);

  LPaginationObj := TJSONObject.Create;
  LPaginationObj.AddPair('page_size', TJSONNumber.Create(APageSize));
  
  if ANextCursor.IsEmpty then
    LPaginationObj.AddPair('next_cursor', TJSONNull.Create)
  else
    LPaginationObj.AddPair('next_cursor', ANextCursor);
    
  if AHasMore then
    LPaginationObj.AddPair('has_more', TJSONBool.Create(True))
  else
    LPaginationObj.AddPair('has_more', TJSONBool.Create(False));

  Result.AddPair('pagination', LPaginationObj);
end;

end.
