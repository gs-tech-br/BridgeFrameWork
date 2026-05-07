unit Bridge.Rest.Controller;

interface

uses
  System.Classes,
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Data.DB,
  Horse,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Connection.Pool,
  Bridge.Neon.Config,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Types,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Validation.Helper,
  Bridge.Base.Model,
  Bridge.Controller.Interfaces,
  Bridge.Base.Controller,
  Bridge.Controller.Errors,
  Bridge.Horse.Pagination;

type
  TBaseModelClass = class of TBaseModel;

  /// <summary>
  /// Base REST Controller class.
  /// </summary>
  TRestController = class(TBaseController)
  public
    procedure Get(Req: THorseRequest; Res: THorseResponse; Next: TProc); virtual;
    procedure GetAll(Req: THorseRequest; Res: THorseResponse; Next: TProc); virtual;
    procedure GetAllPaged(Req: THorseRequest; Res: THorseResponse; Next: TProc); virtual;
    procedure Post(Req: THorseRequest; Res: THorseResponse; Next: TProc); virtual;
    procedure Put(Req: THorseRequest; Res: THorseResponse; Next: TProc); virtual;
    procedure Patch(Req: THorseRequest; Res: THorseResponse; Next: TProc); virtual;
    procedure Del(Req: THorseRequest; Res: THorseResponse; Next: TProc); overload; virtual;
    procedure RegisterRoutes(App: THorse; const BasePath: string); virtual;

  protected
    procedure SafeExecute(Res: THorseResponse; AAction: TProc); virtual;
  end;

  /// <summary>
  /// Generic REST Controller with auto JSON support.
  /// </summary>
  TRestController<T: class, constructor; TModel: TBaseModel, constructor> = class(TRestController)
  public
    constructor Create; override;
    constructor Create(AConnection: IConnection); override;

    procedure Get(Req: THorseRequest; Res: THorseResponse; Next: TProc); override;
    procedure GetAll(Req: THorseRequest; Res: THorseResponse; Next: TProc); override;
    procedure GetAllPaged(Req: THorseRequest; Res: THorseResponse; Next: TProc); override;
    procedure Post(Req: THorseRequest; Res: THorseResponse; Next: TProc); override;
    procedure Put(Req: THorseRequest; Res: THorseResponse; Next: TProc); override;
    procedure Patch(Req: THorseRequest; Res: THorseResponse; Next: TProc); override;
    procedure Del(Req: THorseRequest; Res: THorseResponse; Next: TProc); overload; override;
    procedure RegisterRoutes(App: THorse; const BasePath: string); override;
  end;

implementation

{ TRestController }

procedure TRestController.Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  if Assigned(Next) then Next;
end;

procedure TRestController.GetAll(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  if Assigned(Next) then Next;
end;

procedure TRestController.GetAllPaged(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  if Assigned(Next) then Next;
end;

procedure TRestController.Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  if Assigned(Next) then Next;
end;

procedure TRestController.Put(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  if Assigned(Next) then Next;
end;

procedure TRestController.Patch(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  if Assigned(Next) then Next;
end;

procedure TRestController.Del(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  if Assigned(Next) then Next;
end;

procedure TRestController.SafeExecute(Res: THorseResponse; AAction: TProc);
begin
  try
    AAction();
  except
    on E: Exception do
      Res.Send('Error: ' + E.Message).Status(THTTPStatus.InternalServerError);
  end;
end;

procedure TRestController.RegisterRoutes(App: THorse; const BasePath: string);
begin
  App.Get('/' + BasePath, GetAll);
  App.Get('/' + BasePath + '/paged', GetAllPaged);
  App.Get('/' + BasePath + '/:id', Get);
  App.Post('/' + BasePath, Post);
  App.Put('/' + BasePath + '/:id', Put);
  App.Patch('/' + BasePath + '/:id', Patch);
  App.Delete('/' + BasePath + '/:id', Del);
end;

{ TRestController<T, TModel> }

constructor TRestController<T, TModel>.Create;
begin
  inherited Create; 
  // Base creates TBaseModel. We overwrite with TModel.
  FModel := TModel.Create;
end;

constructor TRestController<T, TModel>.Create(AConnection: IConnection);
begin
  inherited Create(AConnection);
  // Base creates TBaseModel. We overwrite with TModel.
  // Using TBaseModelClass cast to helper access the virtual constructor
  FModel := TBaseModelClass(TModel).Create(AConnection);
end;

procedure TRestController<T, TModel>.RegisterRoutes(App: THorse; const BasePath: string);
type
  TBaseCtrlClass = class of TBaseController;
var
  LCtrlClass: TBaseCtrlClass;
  LPathId, LPathPaged, LPath: string;
begin
  LCtrlClass := TBaseCtrlClass(Self.ClassType);
  LPath := '/' + BasePath;
  LPathPaged := '/' + BasePath + '/paged';
  LPathId := '/' + BasePath + '/:id';

  App.Get(LPath, 
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LConn: IConnection;
      LCtrl: TRestController<T, TModel>;
    begin
      LConn := TConnectionPool.GetInstance.AcquireConnection;
      LCtrl := nil;
      try
        LCtrl := LCtrlClass.Create(LConn) as TRestController<T, TModel>;
        LCtrl.GetAll(Req, Res, Next);
      finally
        LCtrl.Free;
        TConnectionPool.GetInstance.ReleaseConnection(LConn);
      end;
    end);

  App.Get(LPathPaged, 
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LConn: IConnection;
      LCtrl: TRestController<T, TModel>;
    begin
      LConn := TConnectionPool.GetInstance.AcquireConnection;
      LCtrl := nil;
      try
        LCtrl := LCtrlClass.Create(LConn) as TRestController<T, TModel>;
        LCtrl.GetAllPaged(Req, Res, Next);
      finally
        LCtrl.Free;
        TConnectionPool.GetInstance.ReleaseConnection(LConn);
      end;
    end);

  App.Get(LPathId, 
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LConn: IConnection;
      LCtrl: TRestController<T, TModel>;
    begin
      LConn := TConnectionPool.GetInstance.AcquireConnection;
      LCtrl := nil;
      try
        LCtrl := LCtrlClass.Create(LConn) as TRestController<T, TModel>;
        LCtrl.Get(Req, Res, Next);
      finally
        LCtrl.Free;
        TConnectionPool.GetInstance.ReleaseConnection(LConn);
      end;
    end);

  App.Post(LPath, 
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LConn: IConnection;
      LCtrl: TRestController<T, TModel>;
    begin
      LConn := TConnectionPool.GetInstance.AcquireConnection;
      LCtrl := nil;
      try
        LCtrl := LCtrlClass.Create(LConn) as TRestController<T, TModel>;
        LCtrl.Post(Req, Res, Next);
      finally
        LCtrl.Free;
        TConnectionPool.GetInstance.ReleaseConnection(LConn);
      end;
    end);

  App.Put(LPathId, 
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LConn: IConnection;
      LCtrl: TRestController<T, TModel>;
    begin
      LConn := TConnectionPool.GetInstance.AcquireConnection;
      LCtrl := nil;
      try
        LCtrl := LCtrlClass.Create(LConn) as TRestController<T, TModel>;
        LCtrl.Put(Req, Res, Next);
      finally
        LCtrl.Free;
        TConnectionPool.GetInstance.ReleaseConnection(LConn);
      end;
    end);

  App.Patch(LPathId, 
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LConn: IConnection;
      LCtrl: TRestController<T, TModel>;
    begin
      LConn := TConnectionPool.GetInstance.AcquireConnection;
      LCtrl := nil;
      try
        LCtrl := LCtrlClass.Create(LConn) as TRestController<T, TModel>;
        LCtrl.Patch(Req, Res, Next);
      finally
        LCtrl.Free;
        TConnectionPool.GetInstance.ReleaseConnection(LConn);
      end;
    end);

  App.Delete(LPathId, 
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LConn: IConnection;
      LCtrl: TRestController<T, TModel>;
    begin
      LConn := TConnectionPool.GetInstance.AcquireConnection;
      LCtrl := nil;
      try
        LCtrl := LCtrlClass.Create(LConn) as TRestController<T, TModel>;
        LCtrl.Del(Req, Res, Next);
      finally
        LCtrl.Free;
        TConnectionPool.GetInstance.ReleaseConnection(LConn);
      end;
    end);
end;

procedure TRestController<T, TModel>.Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  SafeExecute(Res, procedure
    var
      LId: string;
      LEntity: T;
      LJsonObj: TJSONObject;
    begin
      LId := Req.Params['id'];
      LEntity := T.Create;
      try
        if Self.Load(TObject(LEntity), LId) then
        begin
          LJsonObj := TBridgeNeon.ObjectToJSONObject(TObject(LEntity));
          try
            Res.Send<TJSONObject>(LJsonObj);
          except
            LJsonObj.Free;
            raise;
          end;
        end
        else
          Res.Status(THTTPStatus.NotFound);
      finally
        LEntity.Free;
      end;
    end);
end;

procedure TRestController<T, TModel>.GetAll(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  SafeExecute(Res, procedure
    var
      LList: TObjectList<T>;
      LCriteria: TList<TCriterion>;
      LParams: THorsePaginationParams;
      LLastItem: T;
      LJsonValue: TJSONValue;
      LPair: TPair<string, string>;
      LQueryName, LColName, LVal: string;
      LMetaData: TEntityMetaData;
      LPropMeta: TPropertyMeta;
      LIsMapped: Boolean;
    begin
      LList := TObjectList<T>.Create;
      LCriteria := TList<TCriterion>.Create;
      LMetaData := TMetaDataManager.Instance.GetMetaData(T);
      
      for LPair in Req.Query.Dictionary do
      begin
        LQueryName := LPair.Key.Trim.ToLower;
        if (LQueryName = 'page_size') or (LQueryName = 'cursor') or
           (LQueryName = 'order_by') or (LQueryName = 'order_desc') then
          Continue;

        LColName := TMetaDataManager.Instance.ResolveColumnName(T, LPair.Key);
        LVal := LPair.Value;
        
        // Remove wrapping quotes if present
        if (LVal.Length >= 2) and (LVal.StartsWith('''')) and (LVal.EndsWith('''')) then
          LVal := LVal.Substring(1, LVal.Length - 2)
        else if (LVal.Length >= 2) and (LVal.StartsWith('"')) and (LVal.EndsWith('"')) then
          LVal := LVal.Substring(1, LVal.Length - 2);
          
        // Mapeia o tipo da propriedade para aplicar a condicao correta (LIKE ou =) e tipagem (StrToIntDef para Integer)
        LIsMapped := False;
        for LPropMeta in LMetaData.AllProperties do
        begin
          if SameText(LPropMeta.ColumnName, LColName) then
          begin
            LIsMapped := True;
            case LPropMeta.TypeKind of
              tkInteger, tkInt64:
                LCriteria.Add(TCriterion.Create(LColName, '=', StrToIntDef(LVal, 0)));
              tkString, tkLString, tkWString, tkUString:
                LCriteria.Add(TCriterion.Create(LColName, 'LIKE', '%' + LVal + '%'));
              else
                LCriteria.Add(TCriterion.Create(LColName, '=', LVal));
            end;
            Break;
          end;
        end;

        // Fallback for non-mapped columns, assumes string comparison default
        if not LIsMapped then
          LCriteria.Add(TCriterion.Create(LColName, '=', LVal));
      end;
      
      LParams := THorseCursorPagination.ParseParams(Req, 20); // Default 20
      LLastItem := THorseCursorPagination.DecodeCursor<T>(LParams.CursorStr);
      try
        // Request one extra item to check if there are more pages
        if Self.LoadNext<T>(LList, TObject(LLastItem), LParams.PageSize + 1, LParams.GetOrderByItems, LCriteria) then
        begin
          LJsonValue := TBridgeNeon.ListToJSONArray<T>(LList);
          Res.Send<TJSONArray>(TJSONArray(LJsonValue));
        end
        else
          Res.Send<TJSONArray>(TJSONArray.Create);
      finally
        if Assigned(LLastItem) then LLastItem.Free;
        LCriteria.Free;
        LList.Free;
      end;
    end);
end;

procedure TRestController<T, TModel>.GetAllPaged(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  SafeExecute(Res, procedure
    var
      LList: TObjectList<T>;
      LCriteria: TList<TCriterion>;
      LParams: THorsePaginationParams;
      LLastItem: T;
      LNextCursor: string;
      LHasMore: Boolean;
      LPair: TPair<string, string>;
      LQueryName, LColName, LVal: string;
      LMetaData: TEntityMetaData;
      LPropMeta: TPropertyMeta;
      LIsMapped: Boolean;
    begin
      LList := TObjectList<T>.Create;
      LCriteria := TList<TCriterion>.Create;
      LMetaData := TMetaDataManager.Instance.GetMetaData(T);
      
      for LPair in Req.Query.Dictionary do
      begin
        LQueryName := LPair.Key.Trim.ToLower;
        if (LQueryName = 'page_size') or (LQueryName = 'cursor') or
           (LQueryName = 'order_by') or (LQueryName = 'order_desc') then
          Continue;

        LColName := TMetaDataManager.Instance.ResolveColumnName(T, LPair.Key);
        LVal := LPair.Value;
        
        // Remove wrapping quotes if present
        if (LVal.Length >= 2) and (LVal.StartsWith('''')) and (LVal.EndsWith('''')) then
          LVal := LVal.Substring(1, LVal.Length - 2)
        else if (LVal.Length >= 2) and (LVal.StartsWith('"')) and (LVal.EndsWith('"')) then
          LVal := LVal.Substring(1, LVal.Length - 2);

        // Mapeia o tipo da propriedade para aplicar a condicao correta (LIKE ou =) e tipagem (StrToIntDef para Integer)
        LIsMapped := False;
        for LPropMeta in LMetaData.AllProperties do
        begin
          if SameText(LPropMeta.ColumnName, LColName) then
          begin
            LIsMapped := True;
            case LPropMeta.TypeKind of
              tkInteger, tkInt64:
                LCriteria.Add(TCriterion.Create(LColName, '=', StrToIntDef(LVal, 0)));
              tkString, tkLString, tkWString, tkUString:
                LCriteria.Add(TCriterion.Create(LColName, 'LIKE', '%' + LVal + '%'));
              else
                LCriteria.Add(TCriterion.Create(LColName, '=', LVal));
            end;
            Break;
          end;
        end;

        // Fallback for non-mapped columns, assumes string comparison default
        if not LIsMapped then
          LCriteria.Add(TCriterion.Create(LColName, '=', LVal));
      end;
      
      LParams := THorseCursorPagination.ParseParams(Req, 20); // Default 20
      LLastItem := THorseCursorPagination.DecodeCursor<T>(LParams.CursorStr);
      
      try
        // Request one extra item to check if there are more pages
        if Self.LoadNext<T>(LList, TObject(LLastItem), LParams.PageSize + 1, LParams.GetOrderByItems, LCriteria) then
        begin
          LHasMore := LList.Count > LParams.PageSize;
          
          if LHasMore then
            LList.Delete(LList.Count - 1); // Remove the extra item
            
          if LList.Count > 0 then
            LNextCursor := THorseCursorPagination.EncodeCursor(TObject(LList.Last))
          else
            LNextCursor := '';
            
          Res.Send<TJSONObject>(THorseCursorPagination.BuildResponse<T>(LList, LNextCursor, LParams.PageSize, LHasMore));
        end
        else
        begin
          // Empty result
          Res.Send<TJSONObject>(THorseCursorPagination.BuildResponse<T>(LList, '', LParams.PageSize, False));
        end;
      finally
        if Assigned(LLastItem) then LLastItem.Free;
        LCriteria.Free;
        LList.Free;
      end;
    end);
end;

procedure TRestController<T, TModel>.Patch(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  SafeExecute(Res, procedure
    var
      LEntity: T;
      LBody: TJSONObject;
      LId: string;
      LValidate: TValidate;
      LResponseJson: TJSONObject;
      LFieldsToUpdate: TArray<string>;
      LPair: TJSONPair;
      I: Integer;
    begin
      LId := Req.Params['id'];

      try
        LBody := Req.Body<TJSONObject>;
      except
        Res.Status(THTTPStatus.BadRequest).Send('Invalid JSON Body');
        Exit;
      end;

      if not Assigned(LBody) then
      begin
        Res.Status(THTTPStatus.BadRequest).Send('JSON Body required');
        Exit;
      end;

      LEntity := T.Create;
      try
        // Load existing entity from database
        if not Self.Load(TObject(LEntity), LId) then
        begin
          Res.Status(THTTPStatus.NotFound);
          Exit;
        end;

        // Extract field names from JSON body
        SetLength(LFieldsToUpdate, LBody.Count);
        I := 0;
        for LPair in LBody do
        begin
          LFieldsToUpdate[I] := LPair.JsonString.Value;
          Inc(I);
        end;

        // Apply only the fields present in JSON to the loaded entity
        TBridgeNeon.JSONToObject(TObject(LEntity), LBody);

        // Update only the specified fields in the database
        LValidate := Self.UpdatePartial(TObject(LEntity), LFieldsToUpdate);

        if LValidate.Sucess then
        begin
          LResponseJson := TBridgeNeon.ObjectToJSONObject(TObject(LEntity));
          try
            Res.Status(THTTPStatus.OK).Send<TJSONObject>(LResponseJson);
          except
             LResponseJson.Free;
             raise;
          end;
        end
        else
          Res.Status(THTTPStatus.BadRequest).Send(LValidate.Message);
      finally
        LEntity.Free;
      end;
    end);
end;

procedure TRestController<T, TModel>.Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  SafeExecute(Res, procedure
    var
      LEntity: T;
      LBody: TJSONObject;
      LValidate: TValidate;
      LResponseJson: TJSONObject;
    begin
      try
        LBody := Req.Body<TJSONObject>;
      except
        Res.Status(THTTPStatus.BadRequest).Send('Invalid JSON Body');
        Exit;
      end;

      if not Assigned(LBody) then
      begin
        Res.Status(THTTPStatus.BadRequest).Send('JSON Body required');
        Exit;
      end;

      LEntity := T.Create;
      try
        TBridgeNeon.JSONToObject(TObject(LEntity), LBody);
        
        LValidate := Self.Insert(TObject(LEntity));
        
        if LValidate.Sucess then
        begin
          LResponseJson := TBridgeNeon.ObjectToJSONObject(TObject(LEntity));
          try
            Res.Status(THTTPStatus.Created).Send<TJSONObject>(LResponseJson);
          except
            LResponseJson.Free;
            raise;
          end;
        end
        else
          Res.Status(THTTPStatus.BadRequest).Send(LValidate.Message);
      finally
        LEntity.Free;
      end;
    end);
end;

procedure TRestController<T, TModel>.Put(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  SafeExecute(Res, procedure
    var
      LEntity: T;
      LBody: TJSONObject;
      LId: string;
      LValidate: TValidate;
      LResponseJson: TJSONObject;
    begin
      LId := Req.Params['id'];

      try
        LBody := Req.Body<TJSONObject>;
      except
        Res.Status(THTTPStatus.BadRequest).Send('Invalid JSON Body');
        Exit;
      end;

      if not Assigned(LBody) then
      begin
        Res.Status(THTTPStatus.BadRequest).Send('JSON Body required');
        Exit;
      end;

      LEntity := T.Create;
      try
        TBridgeNeon.JSONToObject(TObject(LEntity), LBody);
        
        // Ideally set ID here, but Model usually handles using Entity ID.
        // Assuming Entity ID property is mapped correctly.
        
        LValidate := Self.Update(TObject(LEntity));
        
        if LValidate.Sucess then
        begin
          LResponseJson := TBridgeNeon.ObjectToJSONObject(TObject(LEntity));
          try
            Res.Status(THTTPStatus.OK).Send<TJSONObject>(LResponseJson);
          except
             LResponseJson.Free;
             raise;
          end;
        end
        else
          Res.Status(THTTPStatus.BadRequest).Send(LValidate.Message);
      finally
        LEntity.Free;
      end;
    end);
end;

procedure TRestController<T, TModel>.Del(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  SafeExecute(Res, procedure
    var
      LEntity: T;
      LId: string;
      LValidate: TValidate;
    begin
      LId := Req.Params['id'];
      LEntity := T.Create;
      try
        if not Self.Load(TObject(LEntity), LId) then
        begin
          Res.Status(THTTPStatus.NotFound);
          Exit;
        end;

        LValidate := Self.Delete(TObject(LEntity));
        
        if LValidate.Sucess then
          Res.Status(THTTPStatus.NoContent)
        else
          Res.Status(THTTPStatus.BadRequest).Send(LValidate.Message);
      finally
        LEntity.Free;
      end;
    end);
end;

end.
