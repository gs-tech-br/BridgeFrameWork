unit Bridge.Connection.Generator.Postgres;

interface

uses
  System.SysUtils,
  Bridge.Connection.Types,
  Bridge.Connection.Generator.Base,
  Bridge.MetaData.ScriptGenerator,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Attributes;

type
  TPostgresGenerator = class(TBaseSQLGenerator)
  public
    function GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand; override;
  end;

implementation

{ TPostgresGenerator }

function TPostgresGenerator.GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;
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
    LTableName := AMetaDataGenerator.GetTableName(AObject);
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

end.
