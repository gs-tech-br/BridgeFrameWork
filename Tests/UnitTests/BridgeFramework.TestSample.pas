unit BridgeFramework.TestSample;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSampleTest = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestOne;
    [Test]
    [TestCase('TestA','1,2')]
    [TestCase('TestB','3,4')]
    procedure TestTwo(const AValue1 : Integer;const AValue2 : Integer);
  end;

implementation

procedure TSampleTest.Setup;
begin
end;

procedure TSampleTest.TearDown;
begin
end;

procedure TSampleTest.TestOne;
begin
  Assert.IsTrue(True);
end;

procedure TSampleTest.TestTwo(const AValue1 : Integer;const AValue2 : Integer);
begin
  Assert.IsTrue(AValue1 < AValue2);
end;

initialization
  TDUnitX.RegisterTestFixture(TSampleTest);

end.
