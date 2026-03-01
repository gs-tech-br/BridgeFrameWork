unit Bridge.Model.Errors;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Base exception for Model layer errors.
  /// </summary>
  EBridgeModelError = class(Exception);

  /// <summary>
  /// Exception raised when a record is not found.
  /// </summary>
  EBridgeRecordNotFound = class(EBridgeModelError);

  /// <summary>
  /// Exception raised when a transaction error occurs.
  /// </summary>
  EBridgeTransactionError = class(EBridgeModelError);

const
  SModelTransactionAlreadyActive = 'Transaction is already active';
  SModelNoActiveTransaction = 'No active transaction to commit';
  SModelTransactionRolledBack = 'Operation "%s" not allowed: transaction was rolled back';
  SModelTransactionCommitted = 'Operation "%s" not allowed: transaction was already committed';
  SModelErrorCommitting = 'Error committing transaction: %s';
  SModelRecordNotFound = 'Record not found for deletion';
  SModelConnectionCallbackRequired = 'Connection callback is required for this operation';
  SModelFindCustomError = '[TModel.FindCustom] Failed to execute custom select. Details: %s';
  SModelConnectionNull = 'Connection cannot be null';

implementation

end.
