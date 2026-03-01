unit Bridge.Controller.Errors;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Base exception for Controller layer errors.
  /// </summary>
  EBridgeControllerError = class(Exception);

const
  // Bridge.Base.Controller.pas
  SControllerModelNull = 'Model cannot be null';
  SControllerEntityNotDefined = 'Entity Class not defined. Override FindAll or set FEntityClass.';
  SControllerEntityNotDefinedFind = 'Entity Class not defined. Override Find or set FEntityClass.';
  SControllerPKRequired = 'Field %s (PK) is required';
  
  // Bridge.Async.Controller.pas
  SControllerAsyncInheritance = 'Controller must inherit from TAsyncController';

  // Bridge.Rest.Controller.pas
  SControllerInvalidJson = 'Invalid JSON Body';
  SControllerJsonRequired = 'JSON Body required';
  
  // Bridge.Controller.Registry.pas
  SControllerNotInterface = 'Controller %s does not implement IController';
  SControllerNotRegistered = 'No controller registered for entity type: %s';

  // Bridge.Controller.Helper.pas
  SControllerSoftDeleteNotFound = 'Property %s not found for SoftDelete';
  SControllerRestoreNotFound = 'Property %s not found for Restore';
  SControllerSoftDeleteDisabled = 'Entity does not have [SoftDelete] attribute';

implementation

end.
