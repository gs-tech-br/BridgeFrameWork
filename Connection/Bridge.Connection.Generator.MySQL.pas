unit Bridge.Connection.Generator.MySQL;

interface

uses
  Bridge.Connection.Generator.Base,
  Bridge.Connection.Generator.Interfaces;

type
  TMySQLGenerator = class(TBaseSQLGenerator)
  public
    function GetLastInsertIdSQL: string; override;
    function GetLimitSQL(const ASQL: string; AFetch, AOffset: Integer): string; override;
  end;

implementation

uses
  System.SysUtils;

{ TMySQLGenerator }

function TMySQLGenerator.GetLastInsertIdSQL: string;
begin
  Result := 'SELECT LAST_INSERT_ID() AS ID';
end;

function TMySQLGenerator.GetLimitSQL(const ASQL: string; AFetch, AOffset: Integer): string;
begin
  // MySQL syntax: LIMIT fetch OFFSET offset
  Result := Format('%s LIMIT %d OFFSET %d', [ASQL, AFetch, AOffset]);
end;

end.
