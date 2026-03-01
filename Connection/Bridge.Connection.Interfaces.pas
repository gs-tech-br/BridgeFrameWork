unit Bridge.Connection.Interfaces;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  Bridge.Connection.Types;

type
  /// <summary>
  /// Interface for SQL execution operations.
  /// </summary>
  ISQLExecutor = interface
    ['{A1B2C3D4-E5F6-4789-8012-34567890ABCD}']
    /// <summary>
    /// Creates and returns a dataset configured with the specified SQL.
    /// </summary>
    /// <param name="ASQLValue">SQL command to execute</param>
    /// <returns>TFDQuery configured and ready for use</returns>
    function CreateDataSet(const ASQLValue: string): TFDQuery;

    /// <summary>
    /// Creates an in-memory temporary table from a dataset.
    /// </summary>
    /// <param name="Sender">Source query for data</param>
    /// <returns>TFDMemTable containing query data</returns>
    function CreateTempTable(Sender: TFDQuery): TFDMemTable;

    /// <summary>
    /// Executes a SQL command without returning data.
    /// </summary>
    /// <param name="ASQLValue">SQL command to execute</param>
    procedure Execute(const ASQLValue: String); overload;

    /// <summary>
    /// Executes a SQL command and returns a scalar value.
    /// </summary>
    /// <param name="ASQLValue">SQL command to execute</param>
    /// <param name="AValue">Value returned by execution</param>
    procedure Execute(const ASQLValue: String; out AValue: Variant); overload;

    /// <summary>
    /// Executes a parameterized SQL command without returning data.
    /// </summary>
    /// <param name="ACommand">Command with SQL and parameters</param>
    procedure Execute(const ACommand: TDBCommand); overload;

    /// <summary>
    /// Executes a parameterized SQL command and returns a scalar value.
    /// </summary>
    /// <param name="ACommand">Command with SQL and parameters</param>
    /// <param name="AValue">Value returned by execution</param>
    procedure Execute(const ACommand: TDBCommand; out AValue: Variant); overload;
  end;

  /// <summary>
  /// Interface for database transaction management.
  /// </summary>
  IDbTransaction = interface
    ['{B2C3D4E5-F678-4901-9123-4567890ABCDE}']
    /// <summary>
    /// Starts a transaction in the database.
    /// </summary>
    procedure StartTransaction;

    /// <summary>
    /// Commits the current transaction.
    /// </summary>
    procedure Commit;

    /// <summary>
    /// Rolls back the current transaction.
    /// </summary>
    procedure Rollback;

    /// <summary>
    /// Checks if there is an active transaction.
    /// </summary>
    /// <returns>True if there is an active transaction</returns>
    function InTransaction: Boolean;
  end;

  /// <summary>
  /// Interface for metadata retrieval.
  /// </summary>
  IMetaDataProvider = interface
    ['{C3D4E5F6-7890-4A12-B234-567890ABCDEF}']
    /// <summary>
    /// Gets the next sequence value for a specific column.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <param name="AColumnName">Sequence column name</param>
    /// <returns>Next sequence value</returns>
    function getSeq(const ATable, AColumnName: string): Variant;

    /// <summary>
    /// Gets the next available ID for a table.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <returns>Next available ID</returns>
    function getId(const ATable: string): Integer;

    /// <summary>
    /// Returns the primary key column name of a table.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <returns>Primary key column name</returns>
    function GetPrimaryKey(const ATable: string): string; overload;

    /// <summary>
    /// Returns o Primary key column name baseado nos atributos do objeto.
    /// </summary>
    /// <param name="AObject">Object with mapping attributes</param>
    /// <returns>Primary key column name</returns>
    function GetPrimaryKey(const AObject: TObject): string; overload;

    /// <summary>
    /// Returns the list of columns of a table.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <returns>List of column names</returns>
    function getColumns(const ATable: string): TStringList;
  end;

  /// <summary>
  /// Interface for CRUD operations.
  /// </summary>
  ICrudOperations = interface
    ['{72F00EDC-DF24-4D57-B718-697B3130E98C}']
    /// <summary>
    /// Inserts a new record in the database.
    /// </summary>
    /// <param name="AObject">Object to insert</param>
    /// <param name="AId">Returns the generated ID for the new record</param>
    procedure Insert(const AObject: TObject; out AId: Variant);

    /// <summary>
    /// Updates an existing record in the database.
    /// </summary>
    /// <param name="AObject">Object with updated data</param>
    procedure Update(const AObject: TObject);

    /// <summary>
    /// Updates specific fields of an existing record in the database.
    /// Only the fields specified in AFieldsToUpdate will be modified.
    /// </summary>
    /// <param name="AObject">Object with updated data</param>
    /// <param name="AFieldsToUpdate">Array of property names to update</param>
    procedure UpdatePartial(const AObject: TObject; const AFieldsToUpdate: TArray<string>);

    /// <summary>
    /// Removes a record from the database.
    /// </summary>
    /// <param name="AObject">Object to remove</param>
    procedure Delete(const AObject: TObject);

    /// <summary>
    /// Searches records in a table applying filters.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <param name="Params">Dictionary of filter conditions</param>
    /// <returns>Query with filtered results</returns>
    function Find(const ATable: string;
      ACriteria: TList<TCriterion>): TFDQuery;

    // Batch operations
    /// <summary>
    /// Executes a batch insert using prepared statements for optimal performance.
    /// </summary>
    /// <param name="AList">List of objects to insert</param>
    /// <param name="AClassType">Class type of the objects</param>
    procedure InsertBatch(const AList: TObject; AClassType: TClass);

    /// <summary>
    /// Executes a batch update using prepared statements for optimal performance.
    /// </summary>
    /// <param name="AList">List of objects to update</param>
    /// <param name="AClassType">Class type of the objects</param>
    procedure UpdateBatch(const AList: TObject; AClassType: TClass);

    /// <summary>
    /// Executes a batch delete using prepared statements for optimal performance.
    /// </summary>
    /// <param name="AList">List of objects to delete</param>
    /// <param name="AClassType">Class type of the objects</param>
    procedure DeleteBatch(const AList: TObject; AClassType: TClass);
  end;

  /// <summary>
  /// Main interface for database connection operations.
  /// Aggregates specialized interfaces for backward compatibility.
  /// </summary>
  IConnection = interface(ISQLExecutor)
    ['{3ECC844C-7BF5-45E4-BEAF-DDEC9AAB3440}']

    /// <summary>
    /// Returns the active FireDAC connection.
    /// </summary>
    /// <returns>Configured and connected TFDConnection instance</returns>
    function getConnection: TFDConnection;

    /// <summary>
    /// Creates a new FireDAC connection instance.
    /// </summary>
    /// <returns>New TFDConnection instance</returns>
    function CreateConnection: TFDConnection; // Might be deprecated in future

    // Aggregate other interfaces methods (explicitly listed for clarity/delphi interface inheritance limitations)
    // IDbTransaction
    /// <summary>
    /// Starts a transaction in the database.
    /// </summary>
    procedure StartTransaction;

    /// <summary>
    /// Commits the current transaction.
    /// </summary>
    procedure Commit;

    /// <summary>
    /// Rolls back the current transaction.
    /// </summary>
    procedure Rollback;

    /// <summary>
    /// Checks if there is an active transaction.
    /// </summary>
    /// <returns>True if there is an active transaction</returns>
    function InTransaction: Boolean;

    // IMetaDataProvider
    /// <summary>
    /// Gets the next sequence value for a specific column.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <param name="AColumnName">Sequence column name</param>
    /// <returns>Next sequence value</returns>
    function getSeq(const ATable, AColumnName: string): Variant;

    /// <summary>
    /// Gets the next available ID for a table.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <returns>Next available ID</returns>
    function getId(const ATable: string): Integer;

    /// <summary>
    /// Returns the primary key column name of a table.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <returns>Primary key column name</returns>
    function GetPrimaryKey(const ATable: string): string; overload;

    /// <summary>
    /// Returns o Primary key column name baseado nos atributos do objeto.
    /// </summary>
    /// <param name="AObject">Object with mapping attributes</param>
    /// <returns>Primary key column name</returns>
    function GetPrimaryKey(const AObject: TObject): string; overload;

    /// <summary>
    /// Returns the list of columns of a table.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <returns>List of column names</returns>
    function getColumns(const ATable: string): TStringList;

    // ICrudOperations
    /// <summary>
    /// Inserts a new record in the database.
    /// </summary>
    /// <param name="AObject">Object to insert</param>
    /// <param name="AId">Returns the generated ID for the new record</param>
    procedure Insert(const AObject: TObject; out AId: Variant);

    /// <summary>
    /// Updates an existing record in the database.
    /// </summary>
    /// <param name="AObject">Object with updated data</param>
    procedure Update(const AObject: TObject);

    /// <summary>
    /// Updates specific fields of an existing record in the database.
    /// Only the fields specified in AFieldsToUpdate will be modified.
    /// </summary>
    /// <param name="AObject">Object with updated data</param>
    /// <param name="AFieldsToUpdate">Array of property names to update</param>
    procedure UpdatePartial(const AObject: TObject; const AFieldsToUpdate: TArray<string>);

    /// <summary>
    /// Removes a record from the database.
    /// </summary>
    /// <param name="AObject">Object to remove</param>
    procedure Delete(const AObject: TObject);

    /// <summary>
    /// Searches records in a table applying filters.
    /// </summary>
    /// <param name="ATable">Table name</param>
    /// <param name="Params">Dictionary of filter conditions</param>
    /// <returns>Query with filtered results</returns>
    function Find(const ATable: string;
      ACriteria: TList<TCriterion>): TFDQuery;

    /// <summary>
    /// Executes a batch insert using prepared statements for optimal performance.
    /// </summary>
    /// <param name="AList">List of objects to insert</param>
    /// <param name="AClassType">Class type of the objects</param>
    procedure InsertBatch(const AList: TObject; AClassType: TClass);

    /// <summary>
    /// Executes a batch update using prepared statements for optimal performance.
    /// </summary>
    /// <param name="AList">List of objects to update</param>
    /// <param name="AClassType">Class type of the objects</param>
    procedure UpdateBatch(const AList: TObject; AClassType: TClass);

    /// <summary>
    /// Executes a batch delete using prepared statements for optimal performance.
    /// </summary>
    /// <param name="AList">List of objects to delete</param>
    /// <param name="AClassType">Class type of the objects</param>
    procedure DeleteBatch(const AList: TObject; AClassType: TClass);

    /// <summary>
    /// Returns a database-specific LIMIT/TOP clause for the given page size.
    /// Used by SQL generators to ensure portability across different databases.
    /// Example: ' LIMIT 10' for SQLite/PostgreSQL, ' FETCH FIRST 10 ROWS ONLY' for SQL Server 2012+.
    /// </summary>
    /// <param name="ALimit">Maximum number of records to return</param>
    /// <returns>Database-specific SQL fragment for limiting results</returns>
    function GetLimitClause(const ALimit: Integer): string;

    // Command Generation (To be deprecated/moved to Generator)
    /// <summary>
    /// Generates the SQL INSERT command for an object.
    /// </summary>
    /// <param name="AObject">Object to generate the command</param>
    /// <returns>SQL INSERT command with parameters</returns>
    function GetInsertCommand(const AObject: TObject): TDBCommand;

    /// <summary>
    /// Generates the SQL UPDATE command for an object.
    /// </summary>
    /// <param name="AObject">Object to generate the command</param>
    /// <returns>SQL UPDATE command with parameters</returns>
    function GetUpdateCommand(const AObject: TObject): TDBCommand;

    /// <summary>
    /// Generates the SQL UPDATE command for specific fields of an object.
    /// </summary>
    /// <param name="AObject">Object to generate the command</param>
    /// <param name="AFieldsToUpdate">Array of property names to include in UPDATE</param>
    /// <returns>SQL UPDATE command with parameters for specified fields only</returns>
    function GetUpdatePartialCommand(const AObject: TObject; const AFieldsToUpdate: TArray<string>): TDBCommand;

    /// <summary>
    /// Generates the SQL DELETE command for an object.
    /// </summary>
    /// <param name="AObject">Object to generate the command</param>
    /// <returns>SQL DELETE command with parameters</returns>
    function GetDeleteCommand(const AObject: TObject): TDBCommand;
  end;

implementation

end.
