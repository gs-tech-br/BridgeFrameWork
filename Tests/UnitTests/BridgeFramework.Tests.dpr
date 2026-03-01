program BridgeFramework.Tests;

uses
  System.SysUtils,
  Vcl.Forms,
  TestInsight.DUnitX,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  BridgeFramework.TestSample in 'BridgeFramework.TestSample.pas';

{$R *.res}

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  exit;
{$ENDIF}
  Application.Initialize;
  Application.Title := 'DUnitX';
  DUnitX.Loggers.GUI.VCL.Run;
end.
