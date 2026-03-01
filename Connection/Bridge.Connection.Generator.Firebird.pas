unit Bridge.Connection.Generator.Firebird;

interface

uses
  System.SysUtils,
  Bridge.Connection.Types,
  Bridge.Connection.Generator.Base,
  Bridge.Connection.Generator.Interfaces,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.ScriptGenerator,
  Bridge.MetaData.Manager;

type
  TFirebirdGenerator = class(TBaseSQLGenerator)
  public
    function GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand; override;
    function GetLimitSQL(const ASQL: string; AFetch, AOffset: Integer): string; override;
  end;

implementation

{ TFirebirdGenerator }

function TFirebirdGenerator.GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;
const
  LInsertWithReturn = 'INSERT INTO %s (%s) VALUES (%s) RETURNING %s';
var
  LScript: TScriptInsert;
  LPrimaryKey: string;
  LPkFieldName: string;
  LMetaData: TEntityMetaData;
  LTableName: string;
begin
  LMetaData := TMetaDataManager.Instance.GetMetaData(AObject);
  
  if TMetaDataManager.Instance.IsAutoIncrement(AObject) then
  begin
    LTableName := GetQuotedTableName(AObject, AMetaDataGenerator);
    LScript := AMetaDataGenerator.GenerateInsertScript(AObject);
    
    LPkFieldName := LMetaData.PrimaryKeyField.Name.Substring(1);
    LPrimaryKey := TMetaDataManager.Instance.GetColumnName(AObject, LPkFieldName);
    
    Result.SQL := Format(LInsertWithReturn, [LTableName, LScript.Fields, LScript.Params, LPrimaryKey]);
    Result.Params := LScript.ParamValues;
  end
  else
  begin
    Result := inherited GenerateInsert(AObject, AMetaDataGenerator);
  end;
end;

function TFirebirdGenerator.GetLimitSQL(const ASQL: string; AFetch, AOffset: Integer): string;
begin
  // Firebird syntax: ROWS offset+1 TO offset+fetch
  // Or since FB 2.5/3.0: OFFSET x ROWS FETCH NEXT y ROWS ONLY
  // Using generic LIMIT compatible approach if driver supports it, strictly standard FB is:
  Result := Format('%s ROWS %d TO %d', [ASQL, AOffset + 1, AOffset + AFetch]);
end;

end.
