unit Bridge.Controller.QueryBuilder;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.StrUtils,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Bridge.Connection.Interfaces,
  Bridge.Controller.Interfaces,
  Bridge.Model.Interfaces,
  Bridge.Connection.Types,
  Bridge.MetaData.ScriptGenerator;

type

  TQueryBuilder = class(TInterfacedObject, IQueryBuilder)
  private
    FModel: IModel;
    FClass: TClass;
    FCriteria: TList<TCriterion>;
    FOrderBy: TList<TOrderByItem>; // Using TList for easier building
    FLimit: Integer;
    FNextLogic: TLogicOperator;

    procedure AddCriterion(ACriterion: TCriterion);
  public
    constructor Create(AModel: IModel; AClass: TClass);
    destructor Destroy; override;

    function Where(const AField: string; AValue: Variant): IQueryBuilder; overload;
    function Where(const AField, AOperator: string; AValue: Variant): IQueryBuilder; overload;
    function And_: IQueryBuilder;
    function Or_: IQueryBuilder;
    function BeginGroup: IQueryBuilder;
    function EndGroup: IQueryBuilder;
    function OrderBy(const AField: string; ADescending: Boolean = False): IQueryBuilder;
    function Limit(ALimit: Integer): IQueryBuilder;
    function Execute: TFDQuery;
  end;

implementation

uses
  Bridge.Connection.Utils;

{ TQueryBuilder }

constructor TQueryBuilder.Create(AModel: IModel; AClass: TClass);
begin
  inherited Create;
  FModel := AModel;
  FClass := AClass;
  FCriteria := TList<TCriterion>.Create;
  FOrderBy := TList<TOrderByItem>.Create;
  FLimit := 0;
  FNextLogic := loAND; // Default logic
end;

destructor TQueryBuilder.Destroy;
begin
  FCriteria.Free;
  FOrderBy.Free;
  inherited;
end;

procedure TQueryBuilder.AddCriterion(ACriterion: TCriterion);
begin
  FCriteria.Add(ACriterion);
  // Reset logic to AND for subsequent additions, unless explicitly changed
  FNextLogic := loAND;
end;

function TQueryBuilder.Where(const AField: string; AValue: Variant): IQueryBuilder;
var
  LField: string;
  LOperator: string;
  LParts: TArray<string>;
begin
  // Check if Field contains operator (e.g., 'Data >')
  LParts := AField.Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(LParts) > 1 then
  begin
    // Assuming last part is operator if it matches common SQL operators
    // Simple heuristic: if > 1 part, treat last as operator?
    // User requested: "Data >", value
    // Let's support: 'Field Operator'
    LOperator := LParts[Length(LParts)-1];
    LField := String.Join(' ', Copy(LParts, 0, Length(LParts)-1));
    Result := Where(LField, LOperator, AValue);
  end
  else
  begin
    Result := Where(AField, '=', AValue);
  end;
end;

function TQueryBuilder.Where(const AField, AOperator: string;
  AValue: Variant): IQueryBuilder;
begin
  AddCriterion(TCriterion.Create(AField, AOperator, AValue, FNextLogic));
  Result := Self;
end;

function TQueryBuilder.And_: IQueryBuilder;
begin
  FNextLogic := loAND;
  Result := Self;
end;

function TQueryBuilder.Or_: IQueryBuilder;
begin
  FNextLogic := loOR;
  Result := Self;
end;

function TQueryBuilder.BeginGroup: IQueryBuilder;
begin
  AddCriterion(TCriterion.Create(ctOpenGroup, FNextLogic));
  Result := Self;
end;

function TQueryBuilder.EndGroup: IQueryBuilder;
begin
  // EndGroup logic operator (for *it*) is irrelevant as it doesn't start a new term
  // But we pass FNextLogic just in case the type requires it, though usually ignored.
  // Actually, EndGroup connects to previous item inside group? No.
  // EndGroup simply closes.
  AddCriterion(TCriterion.Create(ctCloseGroup, loAND)); 
  Result := Self;
end;

function TQueryBuilder.OrderBy(const AField: string;
  ADescending: Boolean): IQueryBuilder;
begin
  FOrderBy.Add(TOrderByItem.Create(AField, ADescending));
  Result := Self;
end;

function TQueryBuilder.Limit(ALimit: Integer): IQueryBuilder;
begin
  FLimit := ALimit;
  Result := Self;
end;

function TQueryBuilder.Execute: TFDQuery;
var
  LScriptGenerator: TMetaDataScriptGenerator;
  LCursorResult: TCursorSelectResult;
  LConnection: IConnection;
  I: Integer;
begin
  // We need to access IConnection from Model.
  // IModel exposes Connection property.
  LConnection := FModel.Connection;
  LScriptGenerator := TMetaDataScriptGenerator.Create(LConnection);
  try
    LCursorResult := LScriptGenerator.GenerateSelect(
      FClass,
      FCriteria,
      FOrderBy.ToArray,
      FLimit
    );
    
    Result := LConnection.CreateDataSet(LCursorResult.SQL);
    try
      // Bind parameters
      for I := 0 to High(LCursorResult.ParamValues) do
      begin
        Result.ParamByName(LCursorResult.ParamValues[I].Name).Value := LCursorResult.ParamValues[I].Value;
      end;
      
      Result.Open;
    except
      on E: Exception do
      begin
        Result.Free;
        raise;
      end;
    end;
  finally
    LScriptGenerator.Free;
  end;
end;



end.
