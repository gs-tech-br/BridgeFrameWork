unit Tests.Horse.Request.Encoding;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  THorseRequestEncodingTest = class(TObject)
  public
    [Test]
    procedure DecodePossibleUtf8MojibakeFixesPortugueseAccents;
    [Test]
    procedure DecodePossibleUtf8MojibakeKeepsValidUnicode;
    [Test]
    procedure DecodePossibleUtf8MojibakeKeepsLegitimateMarkerChars;
  end;

implementation

uses
  Horse.Request;

procedure THorseRequestEncodingTest.DecodePossibleUtf8MojibakeFixesPortugueseAccents;
var
  LExpectedLeticia: string;
  LExpectedAction: string;
  LMojibakeLeticia: string;
  LMojibakeAction: string;
begin
  LExpectedLeticia := 'Let' + #$00ED + 'cia Porto';
  LExpectedAction := 'A' + #$00E7 + #$00E3 + 'o Jo' + #$00E3 + 'o Pe' + #$00E7 + 'a';
  LMojibakeLeticia := 'Let' + #$00C3 + #$00AD + 'cia Porto';
  LMojibakeAction := 'A' + #$00C3 + #$00A7 + #$00C3 + #$00A3 + 'o Jo' +
    #$00C3 + #$00A3 + 'o Pe' + #$00C3 + #$00A7 + 'a';

  Assert.AreEqual(LExpectedLeticia, DecodePossibleUtf8Mojibake(LMojibakeLeticia));
  Assert.AreEqual(LExpectedAction, DecodePossibleUtf8Mojibake(LMojibakeAction));
end;

procedure THorseRequestEncodingTest.DecodePossibleUtf8MojibakeKeepsLegitimateMarkerChars;
var
  LValue: string;
begin
  LValue := #$00C1 + 'rea ' + #$00C2 + 'ngulo ' + #$00E2 + 'mbito';
  Assert.AreEqual(LValue, DecodePossibleUtf8Mojibake(LValue));
end;

procedure THorseRequestEncodingTest.DecodePossibleUtf8MojibakeKeepsValidUnicode;
var
  LLeticia: string;
  LAction: string;
begin
  LLeticia := 'Let' + #$00ED + 'cia Porto';
  LAction := 'A' + #$00E7 + #$00E3 + 'o Jo' + #$00E3 + 'o Pe' + #$00E7 + 'a';

  Assert.AreEqual(LLeticia, DecodePossibleUtf8Mojibake(LLeticia));
  Assert.AreEqual(LAction, DecodePossibleUtf8Mojibake(LAction));
end;

initialization
  TDUnitX.RegisterTestFixture(THorseRequestEncodingTest);

end.
