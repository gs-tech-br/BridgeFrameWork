unit Bridge.Connection.Generator.SQLite;

interface

uses
  Bridge.Connection.Generator.Base;

type
  TSQLiteGenerator = class(TBaseSQLGenerator)
  public
    function GetLastInsertIdSQL: string; override;
  end;

implementation

{ TSQLiteGenerator }

function TSQLiteGenerator.GetLastInsertIdSQL: string;
begin
  Result := 'SELECT last_insert_rowid() AS ID';
end;

end.
