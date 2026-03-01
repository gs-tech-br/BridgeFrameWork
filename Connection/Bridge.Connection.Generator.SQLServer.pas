unit Bridge.Connection.Generator.SQLServer;

interface

uses
  System.SysUtils,
  Bridge.Connection.Types,
  Bridge.Connection.Generator.Base,
  Bridge.MetaData.ScriptGenerator,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Attributes;

type
  TSQLServerGenerator = class(TBaseSQLGenerator)
  protected
    function GetQuotedTableName(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): string; override;
  public
    function GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand; override;
  end;

implementation

{ TSQLServerGenerator }

function TSQLServerGenerator.GetQuotedTableName(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): string;
begin
  Result := '[' + inherited GetQuotedTableName(AObject, AMetaDataGenerator) + ']';
end;

function TSQLServerGenerator.GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;
const
  LInsertWithResult = 'INSERT INTO %s (%s) OUTPUT INSERTED.%s VALUES (%s);';
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
    if not Assigned(LMetaData.PrimaryKeyField) then
      raise Exception.CreateFmt('A classe %s does not have a primary key defined ([Id]).', [AObject.ClassName]);
      
    LTableName := GetQuotedTableName(AObject, AMetaDataGenerator);
    LScript := AMetaDataGenerator.GenerateInsertScript(AObject);
    
    LPkFieldName := LMetaData.PrimaryKeyField.Name.Substring(1);
    LPrimaryKey := TMetaDataManager.Instance.GetColumnName(AObject, LPkFieldName);

    Result.SQL := Format(LInsertWithResult, [LTableName, LScript.Fields, LPrimaryKey, LScript.Params]);
    Result.Params := LScript.ParamValues;
  end
  else
  begin
    Result := inherited GenerateInsert(AObject, AMetaDataGenerator);
  end;
end;

end.
