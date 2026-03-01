unit Tests.QueryBuilder;

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  Bridge.MetaData.Types,
  Bridge.Connection.Interfaces,
  Bridge.Base.Controller,
  Bridge.Controller.Interfaces,
  Tests.Shared;

procedure TestQueryBuilder(AConnection: IConnection);

implementation

uses
  System.Variants;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

type
  /// <summary>
  /// Controller local para testes que gerencia a entidade TPerson.
  /// Necessário pois TPerson não herda de TBaseModel.
  /// </summary>
  TPersonController = class(TBaseController)
  public
    constructor Create(AConnection: IConnection); reintroduce;
  end;

constructor TPersonController.Create(AConnection: IConnection);
begin
  inherited Create(AConnection);
  FEntityClass := TPerson;
end;

procedure TestQueryBuilder(AConnection: IConnection);
var
  LController: TPersonController;
  LQuery: TFDQuery;
  LPerson: TPerson;
  LResult: TValidate;
begin
  WriteLn('--------------------------------------------------');
  WriteLn('Testing Fluent Query Builder');
  WriteLn('--------------------------------------------------');

  // Setup
  try
    AConnection.Execute('DROP TABLE IF EXISTS PERSON');
  except
    // Ignore if not exists
  end;
  CreatePersonTable(AConnection);

  LController := TPersonController.Create(AConnection);
  try
    // Insert Data
    LPerson := TPerson.Create;
    try
      LPerson.Name := 'Alice';
      LPerson.Age := 20;
      LResult := LController.Insert(LPerson);
      Assert(LResult.Sucess, 'Insert Alice failed: ' + LResult.Message);

      LPerson.Name := 'Bob';
      LPerson.Age := 30;
      LResult := LController.Insert(LPerson);
      Assert(LResult.Sucess, 'Insert Bob failed: ' + LResult.Message);

      LPerson.Name := 'Charlie';
      LPerson.Age := 40;
      LResult := LController.Insert(LPerson);
      Assert(LResult.Sucess, 'Insert Charlie failed: ' + LResult.Message);
    finally
      LPerson.Free;
    end;

    // Test 1: Simple Equality
    WriteLn('Test 1: Simple Equality (Age = 30)');
    LQuery := LController.Find
      .Where('AGE', 30)
      .Execute;
    try
      Assert(LQuery.RecordCount = 1, 'Expected 1 record');
      Assert(LQuery.FieldByName('NAME').AsString = 'Bob', 'Expected Bob');
      WriteLn('  PASS');
    finally
      LQuery.Free;
    end;

    // Test 2: Operator
    WriteLn('Test 2: Operator (Age > 25)');
    LQuery := LController.Find
      .Where('AGE >', 25)
      .Execute;
    try
      Assert(LQuery.RecordCount = 2, 'Expected 2 records'); // Bob(30), Charlie(40)
      WriteLn('  PASS');
    finally
      LQuery.Free;
    end;

    // Test 3: AND Logic
    WriteLn('Test 3: AND Logic (Age > 20 AND Age < 40)');
    LQuery := LController.Find
      .Where('AGE >', 20)
      .And_
      .Where('AGE <', 40)
      .Execute;
    try
      Assert(LQuery.RecordCount = 1, 'Expected 1 record'); // Bob(30)
      Assert(LQuery.FieldByName('NAME').AsString = 'Bob', 'Expected Bob');
      WriteLn('  PASS');
    finally
      LQuery.Free;
    end;

    // Test 4: OR Logic
    WriteLn('Test 4: OR Logic (Name = Alice OR Name = Charlie)');
    LQuery := LController.Find
      .Where('NAME', 'Alice')
      .Or_
      .Where('NAME', 'Charlie')
      .Execute;
    try
      Assert(LQuery.RecordCount = 2, 'Expected 2 records');
      WriteLn('  PASS');
    finally
      LQuery.Free;
    end;

    // Test 5: Grouping
    WriteLn('Test 5: Grouping (Name=Alice OR (Age=30 AND Name=Bob))');
    // Corresponds to: Alice(20) -> True. Bob(30) -> True. Charlie(40) -> False.
    LQuery := LController.Find
      .Where('NAME', 'Alice')
      .Or_
      .BeginGroup
        .Where('AGE', 30)
        .And_
        .Where('NAME', 'Bob')
      .EndGroup
      .Execute;
    try
      Assert(LQuery.RecordCount = 2, 'Expected 2 records'); // Alice and Bob
      WriteLn('  PASS');
    finally
      LQuery.Free;
    end;

    // Test 6: Order By and Limit
    WriteLn('Test 6: Order By Age DESC Limit 1');
    LQuery := LController.Find
      .OrderBy('AGE', True) // Descending
      .Limit(1)
      .Execute;
    try
      Assert(LQuery.RecordCount = 1, 'Expected 1 record');
      Assert(LQuery.FieldByName('NAME').AsString = 'Charlie', 'Expected Charlie (Oldest)');
      WriteLn('  PASS');
    finally
      LQuery.Free;
    end;

    // Test 7: Grouping with Operator string
    WriteLn('Test 7: Grouping with Operator String (Age > 25 AND (Name LIKE %arl%))');
    // Bob(30, Bob) -> Match Age, Fail Name
    // Charlie(40, Charlie) -> Match Age, Match Name
    LQuery := LController.Find
      .Where('AGE >', 25)
      .And_
      .BeginGroup
        .Where('NAME LIKE', '%arl%')
      .EndGroup
      .Execute;
    try
      Assert(LQuery.RecordCount = 1, 'Expected 1 record'); // Charlie
      Assert(LQuery.FieldByName('NAME').AsString = 'Charlie', 'Expected Charlie');
      WriteLn('  PASS');
    finally
      LQuery.Free;
    end;

  finally
    LController.Free;
  end;
  WriteLn('All QueryBuilder Tests Passed');
  WriteLn('');
end;

end.
