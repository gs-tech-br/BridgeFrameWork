unit Bridge.MetaData.Validation.Helper;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Classes,
  System.Variants,
  System.TypInfo,
  System.Generics.Collections,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Consts,
  Bridge.FastRtti;

type
  TValidationError = record
    PropertyName: string;
    ErrorMessage: string;
    ErrorCode: string;
  end;

  TValidationResult = record
    IsValid: Boolean;
    Errors: TArray<TValidationError>;
    function GetErrorMessages: TStringList;
    function HasError(const APropertyName: string): Boolean;
    function GetErrorByProperty(const APropertyName: string): TValidationError;
    function ToString: string;
  end;

  // Helper class
  TValidationHelper = class
  private
    class function ValidatePropertyMeta(AObject: TObject; const APropMeta: TPropertyMeta): TArray<TValidationError>;
    class function ValidateColumnAttribute(const APropertyName: string; AValue: Variant; ATypeKind: TTypeKind; APropMeta: TPropertyMeta): TArray<TValidationError>;
    class function CreateError(const APropertyName, AMessage, ACode: string): TValidationError;
  public
    class function ValidateObject(AObject: TObject): TValidationResult;
    class function ValidateProperty(AObject: TObject; const APropertyName: string): TValidationResult;

    // Métodos movidos do Manager para validar campos obrigatórios e tamanho
    class function ValidateRequiredFields(AObject: TObject): TValidationResult;
    class function ValidateFieldLengths(AObject: TObject): TValidationResult;

    class function ValidateRequired(const AValue: Variant; ATypeKind: TTypeKind; const APropertyName: string): TValidationError;
    class function ValidateMaxLength(const AValue: Variant; AMaxLength: Integer; const APropertyName: string): TValidationError;
    class function ValidateRange(const AValue: Variant; AMin, AMax: Variant; ATypeKind: TTypeKind; const APropertyName: string): TValidationError;
  end;

implementation

{ TValidationResult }

function TValidationResult.GetErrorMessages: TStringList;
var
  LError: TValidationError;
begin
  Result := TStringList.Create;
  for LError in Errors do
    Result.Add(LError.ErrorMessage);
end;

function TValidationResult.HasError(const APropertyName: string): Boolean;
var
  LError: TValidationError;
begin
  Result := False;
  for LError in Errors do
  begin
    if SameText(LError.PropertyName, APropertyName) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TValidationResult.GetErrorByProperty(const APropertyName: string): TValidationError;
var
  LError: TValidationError;
begin
  Result.PropertyName := '';
  Result.ErrorMessage := '';
  Result.ErrorCode := '';

  for LError in Errors do
  begin
    if SameText(LError.PropertyName, APropertyName) then
    begin
      Result := LError;
      Break;
    end;
  end;
end;

function TValidationResult.ToString: string;
var
  LList: TStringList;
begin
  LList := GetErrorMessages;
  try
    Result := LList.Text;
    if Result.EndsWith(sLineBreak) then
      Result := Result.Substring(0, Result.Length - Length(sLineBreak)); 
  finally
    LList.Free;
  end;
end;

{ TValidationHelper }

class function TValidationHelper.ValidateObject(AObject: TObject): TValidationResult;
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LErrors: TList<TValidationError>;
  LPropertyErrors: TArray<TValidationError>;
  LError: TValidationError;
begin
  LErrors := TList<TValidationError>.Create;
  try
    if not Assigned(AObject) then
    begin
      LErrors.Add(CreateError('Object', TMetaDataConsts.NULL_OBJECT, TMetaDataConsts.ERR_NULL_OBJ));
    end
    else
    begin
      LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
      for LPropMeta in LMetaData.AllProperties do
      begin
        LPropertyErrors := ValidatePropertyMeta(AObject, LPropMeta);
        for LError in LPropertyErrors do
          LErrors.Add(LError);
      end;
    end;

    Result.Errors := LErrors.ToArray;
    Result.IsValid := LErrors.Count = 0;
  finally
    LErrors.Free;
  end;
end;

class function TValidationHelper.ValidateProperty(AObject: TObject; const APropertyName: string): TValidationResult;
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LErrors: TArray<TValidationError>;
  LFound: Boolean;
  LPropertyName: string;
begin
  Result.IsValid := False;
  SetLength(Result.Errors, 0);

  if not Assigned(AObject) then
  begin
    SetLength(Result.Errors, 1);
    Result.Errors[0] := CreateError('Object', TMetaDataConsts.NULL_OBJECT, TMetaDataConsts.ERR_NULL_OBJ);
    Exit;
  end;

  LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
  LFound := False;

  for LPropMeta in LMetaData.AllProperties do
  begin
    if Assigned(LPropMeta.RttiField) then
      LPropertyName := LPropMeta.RttiField.Name.Substring(1)
    else
      LPropertyName := '';

    if SameText(LPropertyName, APropertyName) then
    begin
      LFound := True;
      LErrors := ValidatePropertyMeta(AObject, LPropMeta);
      Break;
    end;
  end;

  if not LFound then
  begin
    SetLength(Result.Errors, 1);
    Result.Errors[0] := CreateError(APropertyName, Format(TMetaDataConsts.PROPERTY_NOT_FOUND, [APropertyName]), TMetaDataConsts.ERR_PROP_NOT_FOUND);
    Exit;
  end;

  Result.Errors := LErrors;
  Result.IsValid := Length(LErrors) = 0;
end;

class function TValidationHelper.ValidateRequiredFields(AObject: TObject): TValidationResult;
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LErrors: TList<TValidationError>;
  LValue: Variant;
  LError: TValidationError;
  LFieldName: string;
begin
  LErrors := TList<TValidationError>.Create;
  try
    if not Assigned(AObject) then
    begin
      LErrors.Add(CreateError('Object', TMetaDataConsts.NULL_OBJECT, TMetaDataConsts.ERR_NULL_OBJ));
    end
    else
    begin
      LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
      for LPropMeta in LMetaData.RequiredProperties do
      begin
        LValue := TFastField.GetAsVariant(AObject, LPropMeta.Offset, LPropMeta.TypeKind);
        LFieldName := LPropMeta.RttiField.Name.Substring(1);
        
        LError := ValidateRequired(LValue, LPropMeta.TypeKind, LFieldName);
        if not LError.ErrorMessage.IsEmpty then
          LErrors.Add(LError);
      end;
    end;

    Result.Errors := LErrors.ToArray;
    Result.IsValid := LErrors.Count = 0;
  finally
    LErrors.Free;
  end;
end;

class function TValidationHelper.ValidateFieldLengths(AObject: TObject): TValidationResult;
var
  LMetaData: TEntityMetaData;
  LPropMeta: TPropertyMeta;
  LErrors: TList<TValidationError>;
  LValue: Variant;
  LError: TValidationError;
  LFieldName: string;
begin
  LErrors := TList<TValidationError>.Create;
  try
    if not Assigned(AObject) then
    begin
      LErrors.Add(CreateError('Object', TMetaDataConsts.NULL_OBJECT, TMetaDataConsts.ERR_NULL_OBJ));
    end
    else
    begin
      LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
      for LPropMeta in LMetaData.LengthProperties do
      begin
        LValue := TFastField.GetAsVariant(AObject, LPropMeta.Offset, LPropMeta.TypeKind);
        LFieldName := LPropMeta.RttiField.Name.Substring(1);
        
        if not (VarIsNull(LValue) or VarIsEmpty(LValue)) then
        begin
          LError := ValidateMaxLength(LValue, LPropMeta.MaxLength, LFieldName);
          if not LError.ErrorMessage.IsEmpty then
            LErrors.Add(LError);
        end;
      end;
    end;

    Result.Errors := LErrors.ToArray;
    Result.IsValid := LErrors.Count = 0;
  finally
    LErrors.Free;
  end;
end;

class function TValidationHelper.ValidatePropertyMeta(AObject: TObject; const APropMeta: TPropertyMeta): TArray<TValidationError>;
var
  LErrors: TList<TValidationError>;
  LColumnErrors: TArray<TValidationError>;
  LError: TValidationError;
  LValue: Variant;
  LPropertyName: string;
begin
  LErrors := TList<TValidationError>.Create;
  try
    LValue := TFastField.GetAsVariant(AObject, APropMeta.Offset, APropMeta.TypeKind);
    
    if Assigned(APropMeta.RttiField) then
      LPropertyName := APropMeta.RttiField.Name.Substring(1)
    else
      LPropertyName := APropMeta.ColumnName;

    LColumnErrors := ValidateColumnAttribute(LPropertyName, LValue, APropMeta.TypeKind, APropMeta);
    for LError in LColumnErrors do
      LErrors.Add(LError);

    Result := LErrors.ToArray;
  finally
    LErrors.Free;
  end;
end;

class function TValidationHelper.ValidateColumnAttribute(const APropertyName: string; AValue: Variant; ATypeKind: TTypeKind; APropMeta: TPropertyMeta): TArray<TValidationError>;
var
  LErrors: TList<TValidationError>;
  LError: TValidationError;
begin
  LErrors := TList<TValidationError>.Create;
  try
    if APropMeta.IsRequired then
    begin
      LError := ValidateRequired(AValue, ATypeKind, APropertyName);
      if not LError.ErrorMessage.IsEmpty then
        LErrors.Add(LError);
    end;

    if APropMeta.MaxLength > 0 then
    begin
      LError := ValidateMaxLength(AValue, APropMeta.MaxLength, APropertyName);
      if not LError.ErrorMessage.IsEmpty then
        LErrors.Add(LError);
    end;

    Result := LErrors.ToArray;
  finally
    LErrors.Free;
  end;
end;

class function TValidationHelper.ValidateRequired(const AValue: Variant; ATypeKind: TTypeKind; const APropertyName: string): TValidationError;
begin
  Result.PropertyName := '';
  Result.ErrorMessage := '';
  Result.ErrorCode := '';

  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    Result := CreateError(APropertyName, Format(TMetaDataConsts.REQUIRED_FIELD, [APropertyName]), TMetaDataConsts.ERR_REQUIRED);
    Exit;
  end;

  if ATypeKind in [tkString, tkLString, tkWString, tkUString] then
  begin
    if VarToStr(AValue).Trim.IsEmpty then
    begin
      Result := CreateError(APropertyName, Format(TMetaDataConsts.REQUIRED_FIELD, [APropertyName]), TMetaDataConsts.ERR_REQUIRED);
    end;
  end;
end;

class function TValidationHelper.ValidateMaxLength(const AValue: Variant; AMaxLength: Integer; const APropertyName: string): TValidationError;
var
  LStrValue: string;
begin
  Result.PropertyName := '';
  Result.ErrorMessage := '';
  Result.ErrorCode := '';

  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit;

  LStrValue := VarToStr(AValue);
  if Length(LStrValue) > AMaxLength then
  begin
    Result := CreateError(APropertyName, Format(TMetaDataConsts.MAX_LENGTH_EXCEEDED, [APropertyName, AMaxLength, Length(LStrValue)]), TMetaDataConsts.ERR_MAX_LENGTH);
  end;
end;

class function TValidationHelper.ValidateRange(const AValue: Variant; AMin, AMax: Variant; ATypeKind: TTypeKind; const APropertyName: string): TValidationError;
begin
  Result.PropertyName := '';
  Result.ErrorMessage := '';
  Result.ErrorCode := '';

  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit;

  case ATypeKind of
    tkInteger, tkInt64:
      begin
        if (Integer(AValue) < AMin) or (Integer(AValue) > AMax) then
        begin
          Result := CreateError(APropertyName, Format(TMetaDataConsts.OUT_OF_RANGE, [APropertyName, VarToStr(AMin), VarToStr(AMax)]), TMetaDataConsts.ERR_RANGE);
        end;
      end;
    tkFloat:
      begin
        if (Double(AValue) < AMin) or (Double(AValue) > AMax) then
        begin
          Result := CreateError(APropertyName, Format(TMetaDataConsts.OUT_OF_RANGE, [APropertyName, VarToStr(AMin), VarToStr(AMax)]), TMetaDataConsts.ERR_RANGE);
        end;
      end;
  end;
end;

class function TValidationHelper.CreateError(const APropertyName, AMessage, ACode: string): TValidationError;
begin
  Result.PropertyName := APropertyName;
  Result.ErrorMessage := AMessage;
  Result.ErrorCode := ACode;
end;

end.
