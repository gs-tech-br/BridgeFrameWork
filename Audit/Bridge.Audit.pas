unit Bridge.Audit;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Variants,
  System.TypInfo,
  System.JSON,
  Neon.Core.Persistence.JSON,
  Neon.Core.Types,
  Bridge.Neon.Config,
  Bridge.FastRtti,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Attributes,
  Bridge.Connection.Interfaces,
  Bridge.Model.Interfaces,
  Bridge.Audit.Entity,
  Bridge.Audit.Controller;

type
  /// <summary>
  /// Manages Audit Log capture and processing.
  /// </summary>
  TAuditManager = class
  public
    class function IsAuditEnabled(AObject: TObject): Boolean;
    class function CloneEntity(AObject: TObject): TObject;
    class procedure CaptureAudit(AConnection: IConnection; AObject: TObject; const AAction: string; AOldValue: TObject; const AUserId, AUserName: string);
  end;

implementation

{ TAuditManager }

class function TAuditManager.IsAuditEnabled(AObject: TObject): Boolean;
begin
  Result := TMetaDataManager.Instance.GetMetaData(AObject).AuditEnabled;
end;

class function TAuditManager.CloneEntity(AObject: TObject): TObject;
var
  LContext: TRttiContext;
  LJSONValue: TJSONValue;
  LObj: TObject;
begin
  // Clone using JSON serialization/deserialization for deep copy
  LJSONValue := TNeon.ObjectToJSON(AObject);
  try
    LContext := TRttiContext.Create;
    try
      LObj := AObject.ClassType.Create;
      TNeon.JSONToObject(LObj, LJSONValue, TBridgeNeon.Config);
      Result := LObj;
    finally
      LContext.Free;
    end;
  finally
    LJSONValue.Free;
  end;
end;

class procedure TAuditManager.CaptureAudit(AConnection: IConnection; AObject: TObject; const AAction: string; AOldValue: TObject; const AUserId, AUserName: string);
var
  LAuditLog: TAuditLog;
  LMetaData: TEntityMetaData;
  LId: Variant;
  LJSON: TJSONValue;
  LController: TAuditController;
begin
  if not IsAuditEnabled(AObject) then 
    Exit;

  LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
  
  LAuditLog := TAuditLog.Create;
  try
    LAuditLog.TableName := LMetaData.TableName;
    
    // Extract Record ID
    if Assigned(LMetaData.PrimaryKeyField) then
    begin
        LId := TFastField.GetAsVariant(AObject, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
        LAuditLog.RecordId := VarToStr(LId);
    end;

    LAuditLog.Action := AAction;
    LAuditLog.CreatedAt := Now;
    
    // User Context
    LAuditLog.UserId := AUserId;
    LAuditLog.UserName := AUserName;
    
    // State Capture
    if Assigned(AOldValue) then
    begin
      LJSON := TNeon.ObjectToJSON(AOldValue);
      try
        LAuditLog.OldValue := LJSON.ToJSON;
      finally
        LJSON.Free;
      end;
    end;
      
    if AAction <> 'DELETE' then
    begin
      LJSON := TNeon.ObjectToJSON(AObject);
      try
        LAuditLog.NewValue := LJSON.ToJSON;
      finally
        LJSON.Free;
      end;
    end;
      
    // Save Audit Log
    LController := TAuditController.Create(AConnection);
    try
      LController.Insert(LAuditLog);
    finally
      LController.Free;
    end;
    
  finally
    LAuditLog.Free;
  end;
end;

end.
