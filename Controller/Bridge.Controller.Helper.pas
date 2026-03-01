unit Bridge.Controller.Helper;

interface

uses

  System.Generics.Collections,
  System.SysUtils,
  System.Variants,
  System.Rtti,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Bridge.FastRtti,
  Bridge.MetaData.Types,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Mapper,
  Bridge.Connection.Types,
  Bridge.Model.Interfaces,
  Bridge.Controller.Interfaces,
  Bridge.Base.Controller;

type
  TControllerHelper = class helper for TBaseController
  public
    // Advanced/Extension Methods
    function Exists<T: class>(AId: Variant): Boolean; overload;
    function Exists<T: class>(ACriteria: TList<TCriterion>): Boolean; overload;

    function Count<T: class>: Integer; overload;
    function Count<T: class>(ACriteria: TList<TCriterion>): Integer; overload;

    function Clone<T: class, constructor>(ASource: T): T;

    function LoadAllOrdered<T: class, constructor>(AList: TObjectList<T>;
      const AOrderBy: TArray<TOrderByItem>;
      ACriteria: TList<TCriterion> = nil): Boolean;

    function LoadPaged<T: class, constructor>(AList: TObjectList<T>;
      APage, APageSize: Integer;
      ACriteria: TList<TCriterion> = nil): TPaginationResult;

    function LoadFromDataSet<T: class, constructor>(AList: TObjectList<T>;
      ADataSet: TDataSet): Boolean;

    // Batch Operations extension
    function InsertBatch<T: class>(const AList: TObjectList<T>): TValidate;
    function UpdateBatch<T: class>(const AList: TObjectList<T>): TValidate;
    function DeleteBatch<T: class>(const AList: TObjectList<T>): TValidate;

    /// <summary>
    /// Loads the next page of records using cursor-based pagination (keyset pagination).
    /// More efficient than OFFSET/LIMIT for large datasets.
    /// </summary>
    /// <param name="AList">Target list to populate with results</param>
    /// <param name="ALastItem">Last item from previous page (cursor), or nil for first page</param>
    /// <param name="APageSize">Number of records to fetch</param>
    /// <param name="AOrderBy">Array of fields to order by (required for consistent pagination)</param>
    /// <param name="ACriteria">Optional additional WHERE conditions</param>
    /// <returns>True if records were loaded, False if no more records</returns>
    function LoadNext<T: class, constructor>(
      AList: TObjectList<T>;
      ALastItem: T;
      APageSize: Integer;
      const AOrderBy: TArray<TOrderByItem>;
      ACriteria: TList<TCriterion> = nil): TValidate;
  end;

implementation

{ TControllerHelper }

function TControllerHelper.Exists<T>(AId: Variant): Boolean;
var
  LTableName: string;
  LKeyColumn: string;
begin
  LTableName := TMetaDataManager.Instance.GetTableName(T);
  LKeyColumn := TMetaDataManager.Instance.ResolveColumnName(T, TReservedVocabulary.KEY);

  with Self.FindInternal(T, AId) do
  try
    Result := not IsEmpty;
  finally
    Free;
  end;
end;

function TControllerHelper.Exists<T>(ACriteria: TList<TCriterion>): Boolean;
var
  LQuery: TFDQuery;
begin
  LQuery := Self.FindAll(T, ACriteria);
  try
    Result := LQuery.RecordCount > 0;
  finally
    LQuery.Free;
  end;
end;

function TControllerHelper.Count<T>: Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := Self.FindAll(T, nil);
  try
    Result := LQuery.RecordCount;
  finally
    LQuery.Free;
  end;
end;

function TControllerHelper.Count<T>(ACriteria: TList<TCriterion>): Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := Self.FindAll(T, ACriteria);
  try
    Result := LQuery.RecordCount;
  finally
    LQuery.Free;
  end;
end;

function TControllerHelper.Clone<T>(ASource: T): T;
var
  LTarget: T;
  LProps: TArray<TRttiProperty>;
  LProp: TRttiProperty;
  LValue: TValue;
  LMetaData: TEntityMetaData;
begin
  if not Assigned(ASource) then
    Exit(nil);
    
  LTarget := T.Create;
  LMetaData := TMetaDataManager.Instance.GetMetaData(T);

  LProps := Self.Context.GetType(T).GetProperties;
  
  for LProp in LProps do
  begin
    if not LProp.IsWritable then Continue;
    if Assigned(LMetaData.PrimaryKeyField) and (LProp.Name = LMetaData.PrimaryKeyField.Name) then
      Continue;
      
    LValue := LProp.GetValue(TObject(ASource));
    LProp.SetValue(TObject(LTarget), LValue);
  end;
  Result := LTarget;
end;

function TControllerHelper.LoadAllOrdered<T>(AList: TObjectList<T>;
  const AOrderBy: TArray<TOrderByItem>;
  ACriteria: TList<TCriterion>): Boolean;
var
  LCriteria: TList<TCriterion>;
  LOwnCriteria: Boolean;
begin
  LOwnCriteria := not Assigned(ACriteria);
  if LOwnCriteria then
    LCriteria := TList<TCriterion>.Create
  else
    LCriteria := ACriteria;

  try
    // AOrderBy é passado para FindAll no futuro quando o GenerateSelect suportar ordering.
    // Por enquanto, ordering é feito via sql order by no LoadAll.
    Result := Self.LoadAll<T>(AList, LCriteria);
  finally
    if LOwnCriteria then
      LCriteria.Free;
  end;
end;

function TControllerHelper.LoadPaged<T>(AList: TObjectList<T>;
  APage, APageSize: Integer;
  ACriteria: TList<TCriterion>): TPaginationResult;
var
  LAllItems: TObjectList<T>;
  LCriteria: TList<TCriterion>;
  LOwnCriteria: Boolean;
  LStart, LEnd, I: Integer;
begin
  LOwnCriteria := not Assigned(ACriteria);
  if LOwnCriteria then
    LCriteria := TList<TCriterion>.Create
  else
    LCriteria := ACriteria;

  LAllItems := TObjectList<T>.Create(False);
  try
    Self.LoadAll<T>(LAllItems, LCriteria);
    Result := Result.Create(LAllItems.Count, APage, APageSize);

    LStart := (APage - 1) * APageSize;
    LEnd := LStart + APageSize - 1;
    if LEnd >= LAllItems.Count then
      LEnd := LAllItems.Count - 1;

    AList.Clear;
    for I := LStart to LEnd do
    begin
      if I < LAllItems.Count then
        AList.Add(LAllItems[I]);
    end;
    
    LAllItems.OwnsObjects := False;
  finally
    LAllItems.Free;
    if LOwnCriteria then
      LCriteria.Free;
  end;
end;

function TControllerHelper.LoadFromDataSet<T>(AList: TObjectList<T>;
  ADataSet: TDataSet): Boolean;
var
  LItem: T;
  LMetaData: TEntityMetaData;
  LMetaManager: TMetaDataManager;
  LMappings: TBaseController.TFieldMappingList;
begin
  Result := False;

  if (not Assigned(AList)) or (not Assigned(ADataSet)) then
    Exit;

  if ADataSet.IsEmpty then
    Exit;

  AList.Clear;
  ADataSet.DisableControls;
  LMappings := nil;
  try
    if ADataSet.RecordCount > 0 then
    begin
      LMetaManager := TMetaDataManager.Instance;
      LMetaData := LMetaManager.GetMetaData(T);
      LMappings := TDataMapper.PrepareFieldMapping(ADataSet, LMetaData);
    end;

    ADataSet.First;
    while not ADataSet.Eof do
    begin
      LItem := T.Create;
      try
        if Assigned(LMappings) then
          TDataMapper.MapDataSetToEntity(TObject(LItem), LMappings)
        else
          TDataMapper.MapDataSetToEntity(ADataSet, TObject(LItem), LMetaData); 
          
        AList.Add(LItem);
      except
        LItem.Free;
        Exit(False);
      end;
      ADataSet.Next;
    end;
    Result := AList.Count > 0;
  finally
    LMappings.Free;
    ADataSet.EnableControls;
  end;
end;

function TControllerHelper.InsertBatch<T>(const AList: TObjectList<T>): TValidate;
begin
  Result.Sucess := True;
  if (not Assigned(AList)) or (AList.Count = 0) then
    Exit;

  try
    Self.Model.InsertBatch(AList, T);
  except
    on E: Exception do
    begin
      Result.Sucess := False;
      Result.Message := E.Message;
    end;
  end;
end;

function TControllerHelper.UpdateBatch<T>(const AList: TObjectList<T>): TValidate;
begin
  Result.Sucess := True;
  if (not Assigned(AList)) or (AList.Count = 0) then
    Exit;

  try
    Self.Model.UpdateBatch(AList, T);
  except
    on E: Exception do
    begin
      Result.Sucess := False;
      Result.Message := E.Message;
    end;
  end;
end;

function TControllerHelper.DeleteBatch<T>(const AList: TObjectList<T>): TValidate;
begin
  Result.Sucess := True;
  if (not Assigned(AList)) or (AList.Count = 0) then
    Exit;

  try
    Self.Model.DeleteBatch(AList, T);
  except
    on E: Exception do
    begin
      Result.Sucess := False;
      Result.Message := E.Message;
    end;
  end;
end;

/// <summary>
/// Loads the next page of records using cursor-based pagination.
/// Controller responsibility: validation and object mapping.
/// Model responsibility: SQL generation and query execution.
/// </summary>
function TControllerHelper.LoadNext<T>(AList: TObjectList<T>;
  ALastItem: T;
  APageSize: Integer;
  const AOrderBy: TArray<TOrderByItem>;
  ACriteria: TList<TCriterion> = nil): TValidate;
var
  LQuery: TFDQuery;
  LItem: T;
  LMetaData: TEntityMetaData;
  LMappings: TBaseController.TFieldMappingList;
begin
  Result.Sucess := True;

  if not Assigned(AList) then
  begin
    Result.Sucess := False;
    Result.Message := 'AList cannot be nil';
    Exit;
  end;
  
  if APageSize <= 0 then
  begin
    Result.Sucess := False;
    Result.Message := 'APageSize must be greater than zero';
    Exit;
  end;

  try
    // Delegate SQL generation and execution to Model
    LQuery := Self.Model.LoadNext(
      T,
      TObject(ALastItem),
      APageSize,
      AOrderBy,
      ACriteria);
    
    if not Assigned(LQuery) then
    begin
      Result.Sucess := False;
      Result.Message := 'Failed to execute pagination query';
      Exit;
    end;
    
    try
      if not LQuery.IsEmpty then
      begin
        LMetaData := TMetaDataManager.Instance.GetMetaData(T);
        LMappings := Self.PrepareFieldMapping(LQuery, LMetaData);
        try
          while not LQuery.Eof do
          begin
            LItem := T.Create;
            try
              Self.MapDataSetToEntity(LItem, LMappings);
              Self.InitializeLazyProperties(LItem);
              AList.Add(LItem);
            except
              on E: Exception do
              begin
                LItem.Free;
                Result.Sucess := False;
                Result.Message := 'Error mapping entity: ' + E.Message;
                Exit;
              end;
            end;
            LQuery.Next;
          end;
        finally
          LMappings.Free;
        end;
      end;

    finally
      LQuery.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Sucess := False;
      Result.Message := 'Error in cursor pagination: ' + E.Message;
    end;
  end;
end;

end.
