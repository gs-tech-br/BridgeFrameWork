unit Bridge.MetaData.EntityInitializer;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.SysUtils,
  System.Variants,
  System.Generics.Collections,
  Bridge.Connection.Interfaces,
  Bridge.Controller.Interfaces,
  Bridge.Controller.Registry,
  Bridge.Connection.Types,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.FastRtti,
  Bridge.RttiHelper; 

type
  /// <summary>
  /// Class responsible for initializing framework entities
  /// It deals with lazy loading and property mapping.
  /// </summary>
  TEntityInitializer = class
  public
    /// <summary>
    /// Initializes lazy-loaded properties (BelongsTo and HasMany) on an entity.
    /// Supports both TLazy<T> fields and TObjectList<T> properties.
    /// </summary>
    /// <param name="AEntity">Entity with lazy properties</param>
    /// <param name="AConnection">Optional connection context to share transaction state</param>
    class procedure InitializeLazyProperties(AEntity: TObject; AConnection: IConnection = nil);

    /// <summary>
    /// Initializes a single BelongsTo lazy property with a loader function.
    /// </summary>
    class procedure InitAnyBelongsTo(AEntity: TObject; AField: TRttiField; AFKValue: Variant; AConnection: IConnection = nil);

    /// <summary>
    /// Initializes a single HasMany lazy property via TLazyList field.
    /// </summary>
    class procedure InitAnyHasMany(AEntity: TObject; AField: TRttiField; AParentPKValue: Variant; const AFKColumn: string; AConnection: IConnection = nil);

    /// <summary>
    /// Initializes a HasMany relationship on a TObjectList<T> field.
    /// </summary>
    class procedure InitAnyHasManyList(AEntity: TObject; AField: TRttiField; AParentPKValue: Variant; const AFKColumn: string; AConnection: IConnection = nil);

    /// <summary>
    /// Gets a property value by column name from an object.
    /// </summary>
    class function GetPropertyValueByColumn(AObject: TObject; const AColumnName: string): Variant;
  end;

implementation

{ TEntityInitializer }

class function TEntityInitializer.GetPropertyValueByColumn(AObject: TObject; const AColumnName: string): Variant;
var
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LColumnAttr: ColumnAttribute;
  LIsIgnored: Boolean;
begin
  Result := Null;
  LType := TRttiHelper.Context.GetType(AObject.ClassType);

  for LProp in LType.GetProperties do
  begin
    LIsIgnored := False;
    for LAttr in LProp.GetAttributes do
      if LAttr is IgnoreAttribute then
      begin
        LIsIgnored := True;
        Break;
      end;
    if LIsIgnored then
      Continue;

    if not (LProp.PropertyType.TypeKind in
      [tkInteger, tkInt64, tkFloat, tkString, tkUString,
       tkEnumeration, tkChar, tkWChar, tkLString, tkWString]) then
      Continue;

    for LAttr in LProp.GetAttributes do
    begin
      if LAttr is ColumnAttribute then
      begin
        LColumnAttr := ColumnAttribute(LAttr);
        if SameText(LColumnAttr.ColumnName, AColumnName) then
        begin
          Result := LProp.GetValue(AObject).AsVariant;
          Exit;
        end;
      end;
    end;

    if SameText(LProp.Name, AColumnName) then
    begin
      Result := LProp.GetValue(AObject).AsVariant;
      Exit;
    end;
  end;
end;

class procedure TEntityInitializer.InitializeLazyProperties(AEntity: TObject; AConnection: IConnection);
var
  LType: TRttiType;
  LField: TRttiField;
  LAttr: TCustomAttribute;
  LBelongsTo: BelongsToAttribute;
  LHasMany: HasManyAttribute;
  LFKValue: Variant;
  LPKValue: Variant;
  LMetaData: TEntityMetaData;
begin
  if not Assigned(AEntity) then
    Exit;

  LType := TRttiHelper.Context.GetType(AEntity.ClassType);
  LMetaData := TMetaDataManager.Instance.GetMetaData(AEntity);
  
  if Assigned(LMetaData.PrimaryKeyField) then
    LPKValue := TFastField.GetAsVariant(AEntity, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind)
  else
    LPKValue := Null;

  // Iterate over FIELDS only
  for LField in LType.GetFields do
  begin
    for LAttr in LField.GetAttributes do
    begin
      if LAttr is BelongsToAttribute then
      begin
        LBelongsTo := BelongsToAttribute(LAttr);
        LFKValue := GetPropertyValueByColumn(AEntity, LBelongsTo.ForeignKeyColumn);
        InitAnyBelongsTo(AEntity, LField, LFKValue, AConnection);
      end
      else if LAttr is HasManyAttribute then
      begin
        LHasMany := HasManyAttribute(LAttr);
        
        // Distinguish between TLazyList<T> (record) and TObjectList<T> (class)
        if LField.FieldType.TypeKind = tkRecord then
           InitAnyHasMany(AEntity, LField, LPKValue, LHasMany.ForeignKeyColumn, AConnection)
        else if (LField.FieldType.TypeKind = tkClass) and 
                (LField.FieldType.Name.StartsWith('TObjectList<')) then
           InitAnyHasManyList(AEntity, LField, LPKValue, LHasMany.ForeignKeyColumn, AConnection);
      end;
    end;
  end;
end;

class procedure TEntityInitializer.InitAnyBelongsTo(AEntity: TObject; AField: TRttiField; AFKValue: Variant; AConnection: IConnection);
var
  LValueField: TRttiField;
  LGenericType: TRttiType;
  LClass: TClass;
  LValue: TValue;
  LSetLoaderMethod: TRttiMethod;
  LLoadFunc: TFunc<Variant, TObject>;
begin
  LValueField := AField.FieldType.GetField('FValue');
  if not Assigned(LValueField) then Exit;
  LGenericType := LValueField.FieldType;
  
  if LGenericType.TypeKind = tkClass then
    LClass := LGenericType.AsInstance.MetaclassType
  else
    Exit;

  LValue := AField.GetValue(AEntity);
  
  LSetLoaderMethod := AField.FieldType.GetMethod('SetLoaderObject');
  if Assigned(LSetLoaderMethod) then
  begin
    LLoadFunc := function(AId: Variant): TObject
      var
        LController: IController;
        LResult: TObject;
      begin
        Result := nil;
        if VarIsNull(AId) or VarIsEmpty(AId) or ((VarType(AId) = varInteger) and (Integer(AId) = 0)) then
          Exit;

        if TControllerRegistry.Instance.HasController(LGenericType.Handle) then
        begin
          LController := TControllerRegistry.Instance.GetController(LGenericType.Handle);
          if Assigned(AConnection) then
            LController.SetConnection(AConnection);

          LResult := LClass.Create;
          try
             if Supports(LController, IController) then
             begin
               if VarType(AId) = varString then
                 LController.Load(LResult, String(AId))
               else
                 LController.Load(LResult, Int64(AId)); 
               Result := LResult;
             end
             else
             begin
               LResult.Free;
             end;
          except
             LResult.Free;
             raise;
          end;
        end;
      end;
    
    LSetLoaderMethod.Invoke(LValue, [TValue.From<TFunc<Variant, TObject>>(LLoadFunc), TValue.FromVariant(AFKValue)]);
    AField.SetValue(AEntity, LValue);
  end;
end;

class procedure TEntityInitializer.InitAnyHasMany(AEntity: TObject; AField: TRttiField; AParentPKValue: Variant; const AFKColumn: string; AConnection: IConnection);
var
  LDummyField: TRttiField;
  LListField: TRttiField;
  LEntityType: TRttiType;
  LListType: TRttiType;
  LValue: TValue;
  LSetLoaderMethod: TRttiMethod;
  LLoadFunc: TFunc<Variant, TObject>;
begin
  LDummyField := AField.FieldType.GetField('FDummyT');
  if not Assigned(LDummyField) then Exit;
  LEntityType := LDummyField.FieldType;
  
  if LEntityType.TypeKind <> tkClass then Exit;

  LListField := AField.FieldType.GetField('FList');
  if not Assigned(LListField) then Exit;
  LListType := LListField.FieldType;

  LValue := AField.GetValue(AEntity);
  
  LSetLoaderMethod := AField.FieldType.GetMethod('SetLoaderObject');
  
  if Assigned(LSetLoaderMethod) then
  begin
    LLoadFunc := function(AParentValue: Variant): TObject
      var
        LCriteria: TList<TCriterion>;
        LController: IController;
        LResult: TObject;
      begin
        LResult := LListType.AsInstance.MetaclassType.Create;
        
        LCriteria := TList<TCriterion>.Create;
        try
          LCriteria.Add(TCriterion.Create(AFKColumn, '=', AParentValue));
          
          if TControllerRegistry.Instance.HasController(LEntityType.Handle) then
          begin
               LController := TControllerRegistry.Instance.GetController(LEntityType.Handle);
               if Assigned(AConnection) then
                 LController.SetConnection(AConnection);

               if Supports(LController, IController) then
                 LController.LoadList(LResult, LCriteria);
          end;
        finally
          LCriteria.Free;
        end;
        Result := LResult;
      end;
    
    LSetLoaderMethod.Invoke(LValue, [TValue.From<TFunc<Variant, TObject>>(LLoadFunc), TValue.FromVariant(AParentPKValue)]);
    AField.SetValue(AEntity, LValue);
  end;
end;

class procedure TEntityInitializer.InitAnyHasManyList(AEntity: TObject; AField: TRttiField; AParentPKValue: Variant; const AFKColumn: string; AConnection: IConnection);
var
  LEntityType: TRttiType;
  LCriteria: TList<TCriterion>;
  LController: IController;
  LListObject: TObject;
  LMethodClear: TRttiMethod;
  RttiType: TRttiType;
begin
  LListObject := AField.GetValue(AEntity).AsObject;
  if not Assigned(LListObject) then Exit; 

  RttiType := TRttiHelper.Context.GetType(LListObject.ClassType);
  // Implementation detail: Generics often hide exact types in RTTI.
  
  // Let's assume for now we can get it via string parsing of the class name, which works in most Delphi versions.
  // Example: "TObjectList<Tests.MasterDetail.Entities.TDetail>"
  
  // For this fix to be robust, we really need the Entity Type. 
  // Let's rely on the property Type qualified name.
  
  // ... Implementation of type extraction skipped for brevity, assuming we can get it or using a helper ...
  // Wait, I can't skip it if I want it to code.
  
  // HACK: For the specific test case, we know TDetail.
  // GENERIC SOLUTION:
  // Use TReified<T> approach if possible, but here we are in a non-generic method.
  
  // Workaround: We will search for 'ItemType' property? TObjectList doesn't publish it.
  
  // Let's try to get "GetItem" return type or "Add" parameter type.
  {
    LMethod := RttiType.GetMethod('Add');
    LEntityType := LMethod.GetParameters[0].ParamType;
  }
  
  // Proper implementation:
  LEntityType := nil;
  for LMethodClear in RttiType.GetMethods do
  begin
    if (LMethodClear.Name = 'Add') and (Length(LMethodClear.GetParameters) = 1) then
    begin
        LEntityType := LMethodClear.GetParameters[0].ParamType;
        Break;
    end;
  end;

  if not Assigned(LEntityType) then Exit;

  // Now we have the Entity Type, we can find the Controller
  if TControllerRegistry.Instance.HasController(LEntityType.Handle) then
  begin
      LController := TControllerRegistry.Instance.GetController(LEntityType.Handle);
      if Assigned(AConnection) then
        LController.SetConnection(AConnection);

      LCriteria := TList<TCriterion>.Create;
      try
        LCriteria.Add(TCriterion.Create(AFKColumn, '=', AParentPKValue));
        
        // Eager Load: Clear and Fill
        RttiType.GetMethod('Clear').Invoke(LListObject, []);
        
        if Supports(LController, IController) then
          LController.LoadList(LListObject, LCriteria);
      finally
        LCriteria.Free;
      end;
  end;
end;

end.
