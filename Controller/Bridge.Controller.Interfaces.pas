unit Bridge.Controller.Interfaces;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Variants,
  FireDAC.Comp.Client,
  System.Rtti,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.MetaData.Types,
  Bridge.MetaData.Manager,
  Bridge.Model.Interfaces;

type
  /// <summary>
  /// Interface for fluent query building.
  /// Obtained via TBaseController.Find.
  /// </summary>
  IQueryBuilder = interface
    ['{5E8F3A2B-1C4D-4E5F-9A0B-6C7D8E9F0A1B}']
    function Where(const AField: string; AValue: Variant): IQueryBuilder; overload;
    function Where(const AField, AOperator: string; AValue: Variant): IQueryBuilder; overload;
    function And_: IQueryBuilder;
    function Or_: IQueryBuilder;
    function BeginGroup: IQueryBuilder;
    function EndGroup: IQueryBuilder;
    function OrderBy(const AField: string; ADescending: Boolean = False): IQueryBuilder;
    function Limit(ALimit: Integer): IQueryBuilder;
    function Execute: TFDQuery;
  end;

  /// <summary>
  /// Interface for framework controllers.
  /// Defines methods for CRUD operations, validation and transaction control.
  /// The Controller acts as an intermediary between the View and the Model.
  /// </summary>
  IController = interface
    ['{D4E5F6A1-B2C3-4567-89AB-CDEF01234567}']

    /// <summary>
    /// Loads an object by its ID (Integer).
    /// </summary>
    /// <param name="Sender">Object to be populated with data</param>
    /// <param name="AId">Record ID</param>
    /// <returns>True if the record was found and loaded</returns>
    function Load(Sender: TObject; AId: Integer): Boolean; overload;

    /// <summary>
    /// Loads an object by its ID (Int64).
    /// </summary>
    /// <param name="Sender">Object to be populated with data</param>
    /// <param name="AId">Record ID</param>
    /// <returns>True if the record was found and loaded</returns>
    function Load(Sender: TObject; AId: Int64): Boolean; overload;

    /// <summary>
    /// Loads an object by its ID (String).
    /// </summary>
    /// <param name="Sender">Object to be populated with data</param>
    /// <param name="AId">Record ID</param>
    /// <returns>True if the record was found and loaded</returns>
    function Load(Sender: TObject; AId: String): Boolean; overload;

    /// <summary>
    /// Loads an object by its ID and Company ID (Integer).
    /// </summary>
    /// <param name="Sender">Object to be populated with data</param>
    /// <param name="AId">Record ID</param>
    /// <param name="ACompanyId">Company ID for multi-tenant filter</param>
    /// <returns>True if the record was found and loaded</returns>
    function Load(Sender: TObject; AId: Integer; ACompositeKeyValue: Integer): Boolean; overload;

    /// <summary>
    /// Loads an object by its ID and Company ID (Int64).
    /// </summary>
    /// <param name="Sender">Object to be populated with data</param>
    /// <param name="AId">Record ID</param>
    /// <param name="ACompanyId">Company ID for multi-tenant filter</param>
    /// <returns>True if the record was found and loaded</returns>
    function Load(Sender: TObject; AId: Int64; ACompositeKeyValue: Integer): Boolean; overload;

    /// <summary>
    /// Loads an object by its ID and Company ID (String).
    /// </summary>
    /// <param name="Sender">Object to be populated with data</param>
    /// <param name="AId">Record ID</param>
    /// <param name="ACompanyId">Company ID for multi-tenant filter</param>
    /// <returns>True if the record was found and loaded</returns>
    function Load(Sender: TObject; AId: String; ACompositeKeyValue: Integer): Boolean; overload;

    /// <summary>
    /// Finds a record by ID (Integer).
    /// </summary>
    /// <param name="AId">Record ID</param>
    /// <returns>Query with the found record</returns>
    function Find(AId: Integer): TFDQuery; overload;

    /// <summary>
    /// Finds a record by ID (Int64).
    /// </summary>
    /// <param name="AId">Record ID</param>
    /// <returns>Query with the found record</returns>
    function Find(AId: Int64): TFDQuery; overload;

    /// <summary>
    /// Finds a record by ID (String).
    /// </summary>
    /// <param name="AId">Record ID</param>
    /// <returns>Query with the found record</returns>
    function Find(AId: String): TFDQuery; overload;

    /// <summary>
    /// Finds a record by ID and Company ID (Integer).
    /// </summary>
    /// <param name="AId">Record ID</param>
    /// <param name="ACompanyId">Company ID for multi-tenant filter</param>
    /// <returns>Query with the found record</returns>
    function Find(AId: Integer; ACompositeKeyValue: Integer): TFDQuery; overload;

    /// <summary>
    /// Finds a record by ID and Company ID (Int64).
    /// </summary>
    /// <param name="AId">Record ID</param>
    /// <param name="ACompanyId">Company ID for multi-tenant filter</param>
    /// <returns>Query with the found record</returns>
    function Find(AId: Int64; ACompositeKeyValue: Integer): TFDQuery; overload;

    /// <summary>
    /// Finds a record by ID and Company ID (String).
    /// </summary>
    /// <param name="AId">Record ID</param>
    /// <param name="ACompanyId">Company ID for multi-tenant filter</param>
    /// <returns>Query with the found record</returns>
    function Find(AId: String; ACompositeKeyValue: Integer): TFDQuery; overload;

    /// <summary>
    /// Finds all records matching the specified criteria.
    /// </summary>
    /// <param name="ACriteria">List of filter criteria</param>
    /// <returns>Query with filtered records</returns>
    function FindAll(ACriteria: TList<TCriterion>): TFDQuery; overload;

    /// <summary>
    /// Finds all records of a specific class matching the filters.
    /// </summary>
    /// <param name="AClass">Object class to determine the table</param>
    /// <param name="ACriteria">List of filter criteria</param>
    /// <returns>Query with filtered records</returns>
    function FindAll(AClass: TClass; ACriteria: TList<TCriterion>): TFDQuery; overload;

    /// <summary>
    /// Returns a fluent query builder for the entity managed by this controller.
    /// </summary>
    function Find: IQueryBuilder; overload;

    /// <summary>
    /// Validates if an object can be inserted into the database.
    /// </summary>
    /// <param name="Sender">Object to validate</param>
    /// <returns>Validation result (Success and Message)</returns>
    function allowsInsert(Sender: TObject): TValidate;

    /// <summary>
    /// Validates if an object can be updated in the database.
    /// </summary>
    /// <param name="Sender">Object to validate</param>
    /// <returns>Validation result (Success and Message)</returns>
    function allowsUpdate(Sender: TObject): TValidate;

    /// <summary>
    /// Validates if an object can be deleted from the database.
    /// </summary>
    /// <param name="Sender">Object to validate</param>
    /// <returns>Validation result (Success and Message)</returns>
    function allowsDelete(Sender: TObject): TValidate;

    /// <summary>
    /// Inserts a new record into the database after validation.
    /// </summary>
    /// <param name="Sender">Object to insert</param>
    /// <returns>Operation result (Success and Message)</returns>
    function Insert(Sender: TObject): TValidate;

    /// <summary>
    /// Updates an existing record in the database after validation.
    /// </summary>
    /// <param name="Sender">Object with updated data</param>
    /// <returns>Operation result (Success and Message)</returns>
    function Update(Sender: TObject): TValidate;

    /// <summary>
    /// Updates specific fields of an existing record after validation.
    /// Only the fields specified in AFieldsToUpdate will be modified.
    /// </summary>
    /// <param name="Sender">Object with updated data</param>
    /// <param name="AFieldsToUpdate">Array of property names to update</param>
    /// <returns>Operation result (Success and Message)</returns>
    function UpdatePartial(Sender: TObject; const AFieldsToUpdate: TArray<string>): TValidate;

    /// <summary>
    /// Removes a record from the database after validation.
    /// </summary>
    /// <param name="Sender">Object to remove</param>
    /// <returns>Operation result (Success and Message)</returns>
    function Delete(Sender: TObject): TValidate;

    /// <summary>
    /// Restores a soft-deleted record in the database.
    /// </summary>
    /// <param name="Sender">Object to restore</param>
    /// <returns>Operation result (Success and Message)</returns>
    function Restore(Sender: TObject): TValidate;

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
    /// Returns the last ID generated by the Insert operation.
    /// </summary>
    /// <returns>Last inserted ID</returns>
    function GetLastId: Variant;

    /// <summary>
    /// Loads a list of entities matching the specified filters.
    /// Used internally by lazy loading for HasMany relationships.
    /// </summary>
    /// <param name="AList">TObjectList to populate with entities</param>
    /// <param name="AParams">Filter conditions</param>
    /// <returns>True if entities were loaded</returns>
    function LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean;
    
    // Accessors for Helper support
    function GetModel: IModel;
    function GetContext: TRttiContext;

    /// <summary>
    /// Sets the connection used by the controller.
    /// Useful for injecting a specific connection/transaction context (e.g. Lazy Loading).
    /// </summary>
    procedure SetConnection(AConnection: IConnection);

    /// <summary>
    /// Sets the user context for audit logging.
    /// </summary>
    /// <param name="AUserId">User ID</param>
    /// <param name="AUserName">User Name</param>
    procedure SetAuditUser(const AUserId: string; const AUserName: string);
  end;

implementation

end.
