unit Bridge.Connection.Generator.Interfaces;

interface

uses
  Data.DB,
  Bridge.Connection.Types,
  Bridge.MetaData.ScriptGenerator;

type
  /// <summary>
  /// Interface for SQL generation strategy.
  /// Decouples SQL syntax details from the connection logic.
  /// </summary>
  ISQLGenerator = interface
    ['{4B9F1D8E-3C2A-4F5B-9E6D-7A8B9C0D1E2F}']
    
    /// <summary>
    /// Generates an INSERT command.
    /// </summary>
    function GenerateInsert(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;

    /// <summary>
    /// Generates an UPDATE command.
    /// </summary>
    function GenerateUpdate(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;

    /// <summary>
    /// Generates a partial UPDATE command for specific fields only.
    /// </summary>
    /// <param name="AObject">Object to generate the command</param>
    /// <param name="AMetaDataGenerator">Metadata generator for table/column information</param>
    /// <param name="AFieldsToUpdate">Array of property names to include in the UPDATE</param>
    function GenerateUpdatePartial(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator; const AFieldsToUpdate: TArray<string>): TDBCommand;

    /// <summary>
    /// Generates a DELETE command.
    /// </summary>
    function GenerateDelete(const AObject: TObject; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;

    /// <summary>
    /// Generates a SELECT command to find a record by ID.
    /// </summary>
    function GenerateSelect(const ATable: string; const AId: Variant; const AMetaDataGenerator: TMetaDataScriptGenerator): TDBCommand;

    /// <summary>
    /// Returns the syntax for retrieving the last inserted ID (if supported) or an empty string.
    /// </summary>
    function GetLastInsertIdSQL: string;

    /// <summary>
    /// Returns the syntax for paging/limiting results (e.g., LIMIT, TOP, FETCH NEXT).
    /// </summary>
    function GetLimitSQL(const ASQL: string; AFetch, AOffset: Integer): string;
  end;

implementation

end.
