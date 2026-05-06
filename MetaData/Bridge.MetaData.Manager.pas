unit Bridge.MetaData.Manager;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Consts,
  Bridge.MetaData.Types,
  Bridge.FastRtti;

type

  TMetaDataHelper = class helper for TObject
  public
    function Column(const APropertyName: string): string;
    function ApplySoftDelete: Boolean;
    function ApplyRestore: Boolean;
  end;

  TMetaDataUtils = class
  public
    class function NameOf<T: class>(const APropName: string): string; overload;
    class function NameOf(AClass: TClass; const APropName: string): string; overload;
    class function ColumnOf<T: class>(const APropName: string): string; overload;
    class function ColumnOf(AClass: TClass; const APropName: string): string; overload;
  end;

  TReservedVocabulary = class
  public
    const KEY = '{ID}';
    const COMPOSITE_KEY = '{EMPRESA}';
  end;

  // Singleton para gerenciar metadados RTTI com cache
  TMetaDataManager = class
  private
    class var FInstance: TMetaDataManager;
    class var FContext: TRttiContext;
    class var FLock: TObject;

    FMetaDataCache: TDictionary<string, TEntityMetaData>;

    constructor Create;

    function BuildMetaData(AClassType: TClass): TEntityMetaData;
    function ExtractTableName(AType: TRttiType): string;
    function ExtractPrimaryKeyField(AType: TRttiType): TRttiField;
    function ExtractCompositeKeyField(AType: TRttiType): TRttiField;
    function FindFieldForProperty(AType: TRttiType; const APropName: string): TRttiField;

    function GetFieldColumnInfo(AField: TRttiField; AType: TRttiType; out AColumnName: string; out ASize: Integer; out AIsRequired: Boolean): Boolean;
    function IsFieldIgnored(AField: TRttiField; AType: TRttiType): Boolean;
    function IsAutoIncrementField(AField: TRttiField; AType: TRttiType): Boolean;
    function IsMappableType(ATypeKind: TTypeKind): Boolean;
    function ExtractSoftDeleteMeta(AType: TRttiType): TSoftDeleteMeta;
    function ExtractAuditEnabled(AType: TRttiType): Boolean;

  public
    class function Instance: TMetaDataManager;
    destructor Destroy; override;

    function GetMetaData(AClassType: TClass): TEntityMetaData; overload;
    function GetMetaData(AObject: TObject): TEntityMetaData; overload;
    function ResolveColumnName(AClassType: TClass; const AKeyOrProperty: string): string;

    function GetTableName(AObject: TObject): string; overload;
    function GetTableName(AClassType: TClass): string; overload;
    function GetPrimaryKeyField(AObject: TObject): TRttiField; overload;
    function GetPrimaryKeyField(AClassType: TClass): TRttiField; overload;
    function GetPrimaryKeyOffset(AClassType: TClass): Integer;
    function GetPrimaryKeyTypeKind(AClassType: TClass): TTypeKind;
    function GetColumnName(AObject: TObject; const APropertyName: string): string;

    function IsAutoIncrement(AObject: TObject): Boolean; overload;
    
    // Métodos de validação depreciados - usar TValidationHelper
    // function AreRequiredFieldsValid(AObject: TObject): TValidate; deprecated 'Use TValidationHelper.ValidateRequiredFields';
    // function AreFieldsLengthsValid(AObject: TObject): TValidate; deprecated 'Use TValidationHelper.ValidateFieldLengths';

    procedure ClearCache;
    function GetCacheInfo: string;
  end;

implementation

{ TMetaDataManager }

constructor TMetaDataManager.Create;
begin
  inherited;
  FMetaDataCache := TDictionary<string, TEntityMetaData>.Create;
end;

destructor TMetaDataManager.Destroy;
var
  LPair: TPair<string, TEntityMetaData>;
begin
  for LPair in FMetaDataCache do
    LPair.Value.ColumnMappings.Free;
  FMetaDataCache.Free;

  inherited;
end;

class function TMetaDataManager.Instance: TMetaDataManager;
begin
  if not Assigned(FInstance) then
  begin
    TMonitor.Enter(FLock);
    try
      if not Assigned(FInstance) then
      begin
        FInstance := TMetaDataManager.Create;
        FContext := TRttiContext.Create;
      end;
    finally
      TMonitor.Exit(FLock);
    end;
  end;
  Result := FInstance;
end;

function TMetaDataManager.GetMetaData(AClassType: TClass): TEntityMetaData;
var
  LClassName: string;
begin
  LClassName := AClassType.ClassName;

  TMonitor.Enter(FLock);
  try
    if not FMetaDataCache.TryGetValue(LClassName, Result) then
    begin
      TMonitor.Exit(FLock);
      try
        Result := BuildMetaData(AClassType);
      finally
        TMonitor.Enter(FLock);
      end;
      FMetaDataCache.Add(LClassName, Result);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TMetaDataManager.GetMetaData(AObject: TObject): TEntityMetaData;
begin
  Result := GetMetaData(AObject.ClassType);
end;

function TMetaDataManager.BuildMetaData(AClassType: TClass): TEntityMetaData;
var
  LType: TRttiType;
  LField: TRttiField;
  LListAll, LListRequired, LListLength: TList<TPropertyMeta>;
  LPropMeta: TPropertyMeta;
  LColName: string;
  LSize: Integer;
  LIsRequired: Boolean;
  LPropName: string;
begin
  LType := FContext.GetType(AClassType);

  Result.TableName := ExtractTableName(LType);
  Result.ColumnMappings := TDictionary<string, string>.Create;

  Result.PrimaryKeyField := ExtractPrimaryKeyField(LType);
  if Assigned(Result.PrimaryKeyField) then
  begin
    Result.PrimaryKeyOffset := Result.PrimaryKeyField.Offset;
    Result.PrimaryKeyTypeKind := Result.PrimaryKeyField.FieldType.TypeKind;
    Result.IsAutoIncrement := IsAutoIncrementField(Result.PrimaryKeyField, LType);
    GetFieldColumnInfo(Result.PrimaryKeyField, LType, Result.PrimaryKeyColumn, LSize, LIsRequired);
  end
  else
  begin
    Result.PrimaryKeyOffset := -1;
    Result.PrimaryKeyTypeKind := tkUnknown;
    Result.PrimaryKeyColumn := '';
    Result.IsAutoIncrement := False;
  end;

  Result.CompositeKeyField := ExtractCompositeKeyField(LType);
  Result.CompositeKeyColumn := '';
  Result.CompositeKeyOffset := -1;
  Result.CompositeKeyTypeKind := tkUnknown;
  if Assigned(Result.CompositeKeyField) then
  begin
    Result.CompositeKeyOffset := Result.CompositeKeyField.Offset;
    Result.CompositeKeyTypeKind := Result.CompositeKeyField.FieldType.TypeKind;
    GetFieldColumnInfo(Result.CompositeKeyField, LType, Result.CompositeKeyColumn, LSize, LIsRequired);
  end;

  // Extract SoftDelete metadata
  Result.SoftDelete := ExtractSoftDeleteMeta(LType);
  
  // Extract Audit metadata
  Result.AuditEnabled := ExtractAuditEnabled(LType);

  LListAll := TList<TPropertyMeta>.Create;
  LListRequired := TList<TPropertyMeta>.Create;
  LListLength := TList<TPropertyMeta>.Create;
  try
    for LField in LType.GetFields do
    begin
      if not LField.Name.StartsWith('F') then
        Continue;

      if not IsMappableType(LField.FieldType.TypeKind) then
        Continue;

      if IsFieldIgnored(LField, LType) then
        Continue;

      if GetFieldColumnInfo(LField, LType, LColName, LSize, LIsRequired) then
      begin
        LPropName := LField.Name.Substring(1);

        LPropMeta.RttiField := LField;
        LPropMeta.Offset := LField.Offset;
        LPropMeta.TypeKind := LField.FieldType.TypeKind;
        LPropMeta.ColumnName := LColName;
        LPropMeta.MaxLength := LSize;
        LPropMeta.IsRequired := LIsRequired;

        LListAll.Add(LPropMeta);
        Result.ColumnMappings.Add(LPropName, LColName);

        if LIsRequired then
          LListRequired.Add(LPropMeta);

        if (LSize > 0) and (LField.FieldType.TypeKind in [tkString, tkLString, tkWString, tkUString]) then
          LListLength.Add(LPropMeta);
      end;
    end;
    Result.AllProperties := LListAll.ToArray;
    Result.RequiredProperties := LListRequired.ToArray;
    Result.LengthProperties := LListLength.ToArray;
  finally
    LListAll.Free;
    LListRequired.Free;
    LListLength.Free;
  end;
end;

/// <summary>
/// Find the TRttiField corresponding to a property by name.
/// </summary>
function TMetaDataManager.FindFieldForProperty(AType: TRttiType; const APropName: string): TRttiField;
var
  LField: TRttiField;
  LExpectedFieldName: string;
begin
  Result := nil;
  LExpectedFieldName := 'F' + APropName;
  for LField in AType.GetFields do
  begin
    if SameText(LField.Name, LExpectedFieldName) then
      Exit(LField);
  end;
end;

/// <summary>
/// Retrieves column information from a TRttiField
/// Search for attributes in the corresponding property or in the field itself.
/// </summary>
function TMetaDataManager.GetFieldColumnInfo(AField: TRttiField; AType: TRttiType;
  out AColumnName: string; out ASize: Integer; out AIsRequired: Boolean): Boolean;
var
  LAttribute: TCustomAttribute;
  LColumnAttr: ColumnAttribute;
  LProperty: TRttiProperty;
  LPropName: string;
begin
  Result := True;
  LPropName := AField.Name.Substring(1);
  AColumnName := LPropName;
  ASize := 0;
  AIsRequired := False;

  for LAttribute in AField.GetAttributes do
  begin
    if LAttribute is ColumnAttribute then
    begin
      LColumnAttr := ColumnAttribute(LAttribute);
      AColumnName := LColumnAttr.ColumnName;
      ASize := LColumnAttr.Size;
      if not LColumnAttr.Nullable then
        AIsRequired := True;
      Exit;  // ColumnAttribute takes priority
    end;
  end;

  LProperty := AType.GetProperty(LPropName);
  if Assigned(LProperty) then
  begin
    for LAttribute in LProperty.GetAttributes do
    begin
      if LAttribute is ColumnAttribute then
      begin
        LColumnAttr := ColumnAttribute(LAttribute);
        AColumnName := LColumnAttr.ColumnName;
        ASize := LColumnAttr.Size;
        if not LColumnAttr.Nullable then
          AIsRequired := True;
      end
      else if LAttribute is IdAttribute then
      begin
        AIsRequired := False;
      end
      else if LAttribute is CompositeKeyAttribute then
      begin
        AIsRequired := True;
      end;
    end;
  end;
end;

function TMetaDataManager.ExtractTableName(AType: TRttiType): string;
var
  LAttribute: TCustomAttribute;
begin
  Result := '';
  for LAttribute in AType.GetAttributes do
  begin
    if LAttribute is EntityAttribute then
    begin
      Result := EntityAttribute(LAttribute).TableName;
      Break;
    end;
  end;
  if Result.IsEmpty then
    Result := AType.Name;
end;

/// <summary>
/// Extracts the Primary Key field based on the [Id] attribute.
/// Searches first in properties, then in fields for flexibility.
/// </summary>
function TMetaDataManager.ExtractPrimaryKeyField(AType: TRttiType): TRttiField;
var
  LProperty: TRttiProperty;
  LField: TRttiField;
  LAttribute: TCustomAttribute;
begin
  Result := nil;
  
  // First, search in properties (traditional approach)
  for LProperty in AType.GetProperties do
  begin
    for LAttribute in LProperty.GetAttributes do
    begin
      if LAttribute is IdAttribute then
      begin
        Result := FindFieldForProperty(AType, LProperty.Name);
        Exit;
      end;
    end;
  end;
  
  // If not found in properties, search directly in fields
  for LField in AType.GetFields do
  begin
    if not LField.Name.StartsWith('F') then
      Continue;
      
    for LAttribute in LField.GetAttributes do
    begin
      if LAttribute is IdAttribute then
      begin
        Result := LField;
        Exit;
      end;
    end;
  end;
end;

/// <summary>
/// Extracts the Composite Key field based on the [CompositeKey] attribute.
/// Searches first in properties, then in fields for flexibility.
/// </summary>
function TMetaDataManager.ExtractCompositeKeyField(AType: TRttiType): TRttiField;
var
  LProperty: TRttiProperty;
  LField: TRttiField;
  LAttribute: TCustomAttribute;
begin
  Result := nil;
  
  // First, search in properties
  for LProperty in AType.GetProperties do
  begin
    for LAttribute in LProperty.GetAttributes do
    begin
      if LAttribute is CompositeKeyAttribute then
      begin
        Result := FindFieldForProperty(AType, LProperty.Name);
        Exit;
      end;
    end;
  end;
  
  // If not found in properties, search directly in fields
  for LField in AType.GetFields do
  begin
    if not LField.Name.StartsWith('F') then
      Continue;
      
    for LAttribute in LField.GetAttributes do
    begin
      if LAttribute is CompositeKeyAttribute then
      begin
        Result := LField;
        Exit;
      end;
    end;
  end;
end;

function TMetaDataManager.ExtractSoftDeleteMeta(AType: TRttiType): TSoftDeleteMeta;
var
  LAttribute: TCustomAttribute;
  LSoftDelete: SoftDeleteAttribute;
  LField: TRttiField;
  LProp: TRttiProperty;
begin
  Result.Enabled := False;
  Result.FieldName := '';
  Result.DeleteValue := Null;
  Result.RestoreValue := Null;

  // 1. Check Class Attributes (Legacy/Explicit Field Name)
  for LAttribute in AType.GetAttributes do
  begin
    if LAttribute is SoftDeleteAttribute then
    begin
      LSoftDelete := SoftDeleteAttribute(LAttribute);
      // Validates if FieldName was provided since it's on the class
      if LSoftDelete.FieldName.IsEmpty then 
        Continue; 

      Result.Enabled := True;
      Result.FieldName := LSoftDelete.FieldName;
      Result.DeleteValue := LSoftDelete.DeleteValue;
      Result.RestoreValue := LSoftDelete.RestoreValue;
      
      LField := FindFieldForProperty(AType, LSoftDelete.FieldName);
      if Assigned(LField) then
      begin
        Result.Offset := LField.Offset;
        Result.TypeKind := LField.FieldType.TypeKind;
      end
      else
      begin
        Result.Offset := -1;
        Result.TypeKind := tkUnknown;
      end;
      Exit;
    end;
  end;

  // 2. Check Fields
  for LField in AType.GetFields do
  begin
    for LAttribute in LField.GetAttributes do
    begin
      if LAttribute is SoftDeleteAttribute then
      begin
        LSoftDelete := SoftDeleteAttribute(LAttribute);
        Result.Enabled := True;
        Result.FieldName := LField.Name; // Use field name directly
        // Remove 'F' prefix if it exists and looks like a field, for consistency with properties?
        // Actually, for internal use (Offset), Field Name doesn't matter much, 
        // but for logging/debugging it does. 
        // Let's keep the real field name.
        
        Result.DeleteValue := LSoftDelete.DeleteValue;
        Result.RestoreValue := LSoftDelete.RestoreValue;
        
        Result.Offset := LField.Offset;
        Result.TypeKind := LField.FieldType.TypeKind;
        Exit;
      end;
    end;
  end;

  // 3. Check Properties
  for LProp in AType.GetProperties do
  begin
    for LAttribute in LProp.GetAttributes do
    begin
      if LAttribute is SoftDeleteAttribute then
      begin
        LSoftDelete := SoftDeleteAttribute(LAttribute);
        Result.Enabled := True;
        Result.FieldName := LProp.Name;
        Result.DeleteValue := LSoftDelete.DeleteValue;
        Result.RestoreValue := LSoftDelete.RestoreValue;
        
        LField := FindFieldForProperty(AType, LProp.Name);
        if Assigned(LField) then
        begin
          Result.Offset := LField.Offset;
          Result.TypeKind := LField.FieldType.TypeKind;
        end
        else
        begin
           // If no backing field found (e.g. getter/setter methods only), 
           // we can't use FastRtti (Direct Memory Access).
           // Ideally we should warn or support fallback validation.
           Result.Offset := -1;
           Result.TypeKind := tkUnknown;
        end;
        Exit;
      end;
    end;
  end;
end;

function TMetaDataManager.ExtractAuditEnabled(AType: TRttiType): Boolean;
var
  LAttribute: TCustomAttribute;
begin
  Result := False;
  for LAttribute in AType.GetAttributes do
  begin
    if LAttribute is AuditAttribute then
    begin
      Exit(True);
    end;
  end;
end;

function TMetaDataManager.GetTableName(AObject: TObject): string;
begin
  Result := GetMetaData(AObject).TableName;
end;

function TMetaDataManager.GetTableName(AClassType: TClass): string;
begin
  Result := GetMetaData(AClassType).TableName;
end;

function TMetaDataManager.GetPrimaryKeyField(AObject: TObject): TRttiField;
begin
  Result := GetMetaData(AObject).PrimaryKeyField;
end;

function TMetaDataManager.GetPrimaryKeyField(AClassType: TClass): TRttiField;
begin
  Result := GetMetaData(AClassType).PrimaryKeyField;
end;

function TMetaDataManager.GetPrimaryKeyOffset(AClassType: TClass): Integer;
begin
  Result := GetMetaData(AClassType).PrimaryKeyOffset;
end;

function TMetaDataManager.GetPrimaryKeyTypeKind(AClassType: TClass): TTypeKind;
begin
  Result := GetMetaData(AClassType).PrimaryKeyTypeKind;
end;

function TMetaDataManager.GetColumnName(AObject: TObject; const APropertyName: string): string;
var
  LMetaData: TEntityMetaData;
begin
  LMetaData := GetMetaData(AObject);
  if not LMetaData.ColumnMappings.TryGetValue(APropertyName, Result) then
    Result := APropertyName;
end;

/// <summary>
/// Checks if a field or its corresponding property has the [Ignore] attribute.
/// </summary>
function TMetaDataManager.IsFieldIgnored(AField: TRttiField; AType: TRttiType): Boolean;
var
  LAttribute: TCustomAttribute;
  LProperty: TRttiProperty;
  LPropName: string;
begin
  Result := False;
  
  // Check attributes in the field itself.
  for LAttribute in AField.GetAttributes do
  begin
    if LAttribute is IgnoreAttribute then
      Exit(True);
  end;
  
  // Check attributes in the corresponding property.
  LPropName := AField.Name.Substring(1); // Remove 'F'
  LProperty := AType.GetProperty(LPropName);
  if Assigned(LProperty) then
  begin
    for LAttribute in LProperty.GetAttributes do
    begin
      if LAttribute is IgnoreAttribute then
        Exit(True);
    end;
  end;
end;

function TMetaDataManager.ResolveColumnName(AClassType: TClass; const AKeyOrProperty: string): string;
var
  LMetaData: TEntityMetaData;
begin
  LMetaData := GetMetaData(AClassType);

  if SameText(AKeyOrProperty, TReservedVocabulary.KEY) then
  begin
    Result := LMetaData.PrimaryKeyColumn;
    if Result.IsEmpty then
      raise Exception.CreateFmt(TMetaDataConsts.TAG_ID_MISSING,
        [TReservedVocabulary.KEY, AClassType.ClassName]);
    Exit;
  end;

  if SameText(AKeyOrProperty, TReservedVocabulary.COMPOSITE_KEY) then
  begin
    Result := LMetaData.CompositeKeyColumn;
    if Result.IsEmpty then
      raise Exception.CreateFmt(TMetaDataConsts.TAG_COMPOSITE_KEY_MISSING,
        [TReservedVocabulary.COMPOSITE_KEY, AClassType.ClassName]);
    Exit;
  end;

  if not LMetaData.ColumnMappings.TryGetValue(AKeyOrProperty, Result) then
    Result := AKeyOrProperty;
end;

/// <summary>
/// Checks if a field has an [Id] attribute with AutoIncrement.
/// </summary>
function TMetaDataManager.IsAutoIncrementField(AField: TRttiField; AType: TRttiType): Boolean;
var
  LAttribute: TCustomAttribute;
  LProperty: TRttiProperty;
  LPropName: string;
begin
  Result := False;
  
  // Check the corresponding property (where the [Id] is usually located).
  LPropName := AField.Name.Substring(1); // Remove 'F'
  LProperty := AType.GetProperty(LPropName);
  if Assigned(LProperty) then
  begin
    for LAttribute in LProperty.GetAttributes do
    begin
      if LAttribute is IdAttribute then
        Exit(IdAttribute(LAttribute).AutoIncrement);
    end;
  end;
  
  for LAttribute in AField.GetAttributes do
  begin
    if LAttribute is IdAttribute then
      Exit(IdAttribute(LAttribute).AutoIncrement);
  end;
end;

function TMetaDataManager.IsAutoIncrement(AObject: TObject): Boolean;
begin
  if not Assigned(AObject) then
    raise Exception.Create(TMetaDataConsts.NULL_OBJECT);
  Result := GetMetaData(AObject).IsAutoIncrement;
end;

/// <summary>
/// Checks if a type is mappable to a database.
/// </summary>
function TMetaDataManager.IsMappableType(ATypeKind: TTypeKind): Boolean;
begin
  Result := ATypeKind in
    [tkInteger, tkInt64, tkFloat, tkString, tkUString, tkEnumeration, tkChar, tkWChar, tkLString, tkWString];
end;

procedure TMetaDataManager.ClearCache;
var
  LPair: TPair<string, TEntityMetaData>;
begin
  TMonitor.Enter(FLock);
  try
    for LPair in FMetaDataCache do
      LPair.Value.ColumnMappings.Free;
    FMetaDataCache.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TMetaDataManager.GetCacheInfo: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := Format(TMetaDataConsts.CACHE_INFO, [FMetaDataCache.Count]);
  finally
    TMonitor.Exit(FLock);
  end;
end;


{ TMetaDataHelper }

function TMetaDataHelper.Column(const APropertyName: string): string;
begin
  Result := TMetaDataUtils.ColumnOf(Self.ClassType, APropertyName);
end;

function TMetaDataHelper.ApplySoftDelete: Boolean;
var
  LMetaData: TEntityMetaData;
begin
  Result := False;
  LMetaData := TMetaDataManager.Instance.GetMetaData(Self);
  
  if LMetaData.SoftDelete.Enabled then
  begin
    if LMetaData.SoftDelete.Offset >= 0 then
    begin
      // Fast Path
      TFastField.SetByTypeKind(Self, LMetaData.SoftDelete.Offset, 
        LMetaData.SoftDelete.TypeKind, LMetaData.SoftDelete.DeleteValue);
      Result := True;
    end
    else
    begin
      // Fallback Path (Context RTTI - slower but safe if field lookup failed)
      // Implementation omitted for brevity/optimization focus. 
      // If setup correctly, Offset should always be >= 0.
      raise Exception.CreateFmt('SoftDelete field "%s" not found for optimization.', 
        [LMetaData.SoftDelete.FieldName]);
    end;
  end;
end;


function TMetaDataHelper.ApplyRestore: Boolean;
var
  LMetaData: TEntityMetaData;
begin
  Result := False;
  LMetaData := TMetaDataManager.Instance.GetMetaData(Self);
  
  if LMetaData.SoftDelete.Enabled then
  begin
    if LMetaData.SoftDelete.Offset >= 0 then
    begin
      // Fast Path
      TFastField.SetByTypeKind(Self, LMetaData.SoftDelete.Offset, 
        LMetaData.SoftDelete.TypeKind, LMetaData.SoftDelete.RestoreValue);
      Result := True;
    end
    else
    begin
      // Fallback Path (Context RTTI - slower but safe if field lookup failed)
      // Implementation omitted for brevity/optimization focus. 
      // If setup correctly, Offset should always be >= 0.
      raise Exception.CreateFmt('SoftDelete field "%s" not found for Restore.', 
        [LMetaData.SoftDelete.FieldName]);
    end;
  end;
end;

{ TMetaDataUtils }

class function TMetaDataUtils.NameOf(AClass: TClass; const APropName: string): string;
var
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := APropName;

  {$IFDEF DEBUG}
  if (not APropName.IsEmpty) and (APropName.Chars[0] = '{') then
    Exit;

  LType := TMetaDataManager.Instance.FContext.GetType(AClass);

  if Assigned(LType) then
  begin
    LProp := LType.GetProperty(APropName);
    if not Assigned(LProp) then
      raise Exception.CreateFmt(
        'ERRO DE DESENVOLVIMENTO: A propriedade "%s" não existe na classe "%s".',
        [APropName, AClass.ClassName]);
  end;
  {$ENDIF}
end;

class function TMetaDataUtils.NameOf<T>(const APropName: string): string;
begin
  Result := NameOf(T, APropName);
end;

class function TMetaDataUtils.ColumnOf(AClass: TClass; const APropName: string): string;
begin
  Result := TMetaDataManager.Instance.ResolveColumnName(AClass, NameOf(AClass, APropName));
end;

class function TMetaDataUtils.ColumnOf<T>(const APropName: string): string;
begin
  Result := ColumnOf(T, APropName);
end;

initialization
  TMetaDataManager.FLock := TObject.Create;

finalization
  if Assigned(TMetaDataManager.FInstance) then
  begin
    TMetaDataManager.FInstance.Free;
    TMetaDataManager.FInstance := nil;
  end;
  TMetaDataManager.FContext.Free;
  FreeAndNil(TMetaDataManager.FLock);

end.
