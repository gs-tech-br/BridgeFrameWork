unit Bridge.Async.Controller;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Threading,
  System.Variants,
  Bridge.MetaData.Types,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.MetaData.Attributes,
  Bridge.MetaData.Manager,
  Bridge.Base.Controller,
  Bridge.Controller.Errors;

type
  /// <summary>
  /// Async Controller that inherits from TBaseController.
  /// Provides non-blocking methods for data access using Connection Pool.
  /// </summary>
  TAsyncController = class(TBaseController)
  public
    class var OnAcquireConnection: TFunc<IConnection>;
    class var OnReleaseConnection: TProc<IConnection>;

    /// <summary>
    /// loads a list of entities asynchronously.
    /// </summary>
    procedure LoadAllAsync<T: class, constructor>(
      const ACriteria: TList<TCriterion> = nil;
      const AOnSuccess: TProc<TObjectList<T>> = nil;
      const AOnError: TProc<string> = nil);

    /// <summary>
    /// Saves an entity asynchronously (Insert or Update based on PK state).
    /// </summary>
    procedure SaveAsync(
      Sender: TObject;
      const AOnSuccess: TProc<TValidate> = nil;
      const AOnError: TProc<string> = nil);

    /// <summary>
    /// Deletes an entity asynchronously.
    /// </summary>
    procedure DeleteAsync(
      Sender: TObject;
      const AOnSuccess: TProc<TValidate> = nil;
      const AOnError: TProc<string> = nil);

    /// <summary>
    /// Restores a soft-deleted entity asynchronously.
    /// </summary>
    procedure RestoreAsync(
      Sender: TObject;
      const AOnSuccess: TProc<TValidate> = nil;
      const AOnError: TProc<string> = nil);

    /// <summary>
    /// Finds and loads a single entity by ID asynchronously.
    /// </summary>
    procedure FindAsync<T: class, constructor>(
      const AId: Variant;
      const AOnSuccess: TProc<T> = nil;
      const AOnError: TProc<string> = nil);
  end;

  TAsyncControllerClass = class of TAsyncController;

implementation

uses
  Bridge.Connection.Pool;

{ TAsyncController }

procedure TAsyncController.LoadAllAsync<T>(
  const ACriteria: TList<TCriterion>;
  const AOnSuccess: TProc<TObjectList<T>>;
  const AOnError: TProc<string>);
var
  LCriteriaClone: TList<TCriterion>;
begin
  // Clone the criteria list to ensure thread safety and ownership within the task
  if Assigned(ACriteria) then
  begin
    LCriteriaClone := TList<TCriterion>.Create;
    LCriteriaClone.AddRange(ACriteria);
  end
  else
    LCriteriaClone := nil;

  TTask.Run(procedure
    var
      LConn: IConnection;
      LController: TAsyncController;
      LList: TObjectList<T>;
      LClassType: TClass;
      LSuccess: Boolean;
      LErrorMessage: string;
    begin
      LList := nil;
      LConn := nil;
      LController := nil;
      try
        try

          // 1. Acquire connection
          if Assigned(OnAcquireConnection) then
            LConn := OnAcquireConnection()
          else
            LConn := TConnectionPool.GetInstance.AcquireConnection;

          // 2. Create a new instance of this specific controller class
          // We use the same class type to ensure virtual methods are preserved
          LClassType := Self.ClassType;

          // Ensure we are creating an AsyncController (or descendent)
          if not LClassType.InheritsFrom(TAsyncController) then
             raise EBridgeControllerError.Create(SControllerAsyncInheritance);
          
          LController := TAsyncControllerClass(LClassType).Create(LConn);

          // 3. Perform data loading (Synchronous method from Base)
          LList := TObjectList<T>.Create;
          
          LSuccess := LController.LoadAll<T>(LList, LCriteriaClone);

          if LSuccess then
          begin
            // 4. On Success (Sync with Main Thread)
            if Assigned(AOnSuccess) then
            begin
              TThread.Queue(nil, procedure
                begin
                  AOnSuccess(LList);
                end);
            end
            else
              LList.Free;
          end
          else
          begin
            // Handle "Empty" case
            LList.Free;
            if Assigned(AOnSuccess) then
              TThread.Queue(nil, procedure begin AOnSuccess(nil); end);
          end;

        except
          on E: Exception do
          begin
            if Assigned(LList) then LList.Free;
            LErrorMessage := E.Message;
            
            if Assigned(AOnError) then
            begin
              TThread.Queue(nil, procedure
                begin
                  AOnError(LErrorMessage); 
                end);
            end;
          end;
        end;
      finally
        // 5. Release connection and free controller
        if Assigned(LCriteriaClone) then LCriteriaClone.Free;
        if Assigned(LController) then LController.Free;
        if Assigned(LConn) then
        begin
          if Assigned(OnReleaseConnection) then
            OnReleaseConnection(LConn)
          else
            TConnectionPool.GetInstance.ReleaseConnection(LConn);
        end;
      end;
    end);
end;

procedure TAsyncController.SaveAsync(
  Sender: TObject;
  const AOnSuccess: TProc<TValidate>;
  const AOnError: TProc<string>);
begin
  TTask.Run(procedure
    var
      LConn: IConnection;
      LController: TAsyncController;
      LClassType: TClass;
      LResult: TValidate;
      LErrorMessage: string;
    begin
      LConn := nil;
      LController := nil;
      try
        try
          // 1. Acquire connection
          if Assigned(OnAcquireConnection) then
            LConn := OnAcquireConnection()
          else
            LConn := TConnectionPool.GetInstance.AcquireConnection;

          // 2. Create a new instance of this specific controller class
          LClassType := Self.ClassType;

          if not LClassType.InheritsFrom(TAsyncController) then
             raise EBridgeControllerError.Create(SControllerAsyncInheritance);
          
          LController := TAsyncControllerClass(LClassType).Create(LConn);

          // 3. Perform save operation (Synchronous method from Base)
          LResult := LController.Save(Sender);

          // 4. On Success/Failure
          if Assigned(AOnSuccess) then
            AOnSuccess(LResult);

        except
          on E: Exception do
          begin
            LErrorMessage := E.Message;
            
            if Assigned(AOnError) then
            begin
              TThread.Queue(nil, procedure
                begin
                  AOnError(LErrorMessage); 
                end);
            end;
          end;
        end;
      finally
        // 5. Release connection and free controller
        if Assigned(LController) then LController.Free;
        if Assigned(LConn) then
        begin
          if Assigned(OnReleaseConnection) then
            OnReleaseConnection(LConn)
          else
            TConnectionPool.GetInstance.ReleaseConnection(LConn);
        end;
      end;
    end);
end;

procedure TAsyncController.DeleteAsync(
  Sender: TObject;
  const AOnSuccess: TProc<TValidate>;
  const AOnError: TProc<string>);
begin
  TTask.Run(procedure
    var
      LConn: IConnection;
      LController: TAsyncController;
      LClassType: TClass;
      LResult: TValidate;
      LErrorMessage: string;
    begin
      LConn := nil;
      LController := nil;
      try
        try
          // 1. Acquire connection
          if Assigned(OnAcquireConnection) then
            LConn := OnAcquireConnection()
          else
            LConn := TConnectionPool.GetInstance.AcquireConnection;

          // 2. Create a new instance of this specific controller class
          LClassType := Self.ClassType;

          if not LClassType.InheritsFrom(TAsyncController) then
             raise EBridgeControllerError.Create(SControllerAsyncInheritance);
          
          LController := TAsyncControllerClass(LClassType).Create(LConn);

          // 3. Perform delete operation (Synchronous method from Base)
          LResult := LController.Delete(Sender);

          // 4. On Success/Failure
          if Assigned(AOnSuccess) then
            AOnSuccess(LResult);

        except
          on E: Exception do
          begin
            LErrorMessage := E.Message;
            
            if Assigned(AOnError) then
              AOnError(LErrorMessage);
          end;
        end;
      finally
        // 5. Release connection and free controller
        if Assigned(LController) then LController.Free;
        if Assigned(LConn) then
        begin
          if Assigned(OnReleaseConnection) then
            OnReleaseConnection(LConn)
          else
            TConnectionPool.GetInstance.ReleaseConnection(LConn);
        end;
      end;
    end);
end;

procedure TAsyncController.RestoreAsync(
  Sender: TObject;
  const AOnSuccess: TProc<TValidate>;
  const AOnError: TProc<string>);
begin
  TTask.Run(procedure
    var
      LConn: IConnection;
      LController: TAsyncController;
      LClassType: TClass;
      LResult: TValidate;
      LErrorMessage: string;
    begin
      LConn := nil;
      LController := nil;
      try
        try
          // 1. Acquire connection
          if Assigned(OnAcquireConnection) then
            LConn := OnAcquireConnection()
          else
            LConn := TConnectionPool.GetInstance.AcquireConnection;

          // 2. Create a new instance of this specific controller class
          LClassType := Self.ClassType;

          if not LClassType.InheritsFrom(TAsyncController) then
             raise EBridgeControllerError.Create(SControllerAsyncInheritance);
          
          LController := TAsyncControllerClass(LClassType).Create(LConn);

          // 3. Perform restore operation (Synchronous method from Base)
          LResult := LController.Restore(Sender);

          // 4. On Success/Failure
          if Assigned(AOnSuccess) then
            AOnSuccess(LResult);

        except
          on E: Exception do
          begin
            LErrorMessage := E.Message;
            
            if Assigned(AOnError) then
              AOnError(LErrorMessage);
          end;
        end;
      finally
        // 5. Release connection and free controller
        if Assigned(LController) then LController.Free;
        if Assigned(LConn) then
        begin
          if Assigned(OnReleaseConnection) then
            OnReleaseConnection(LConn)
          else
            TConnectionPool.GetInstance.ReleaseConnection(LConn);
        end;
      end;
    end);
end;

procedure TAsyncController.FindAsync<T>(
  const AId: Variant;
  const AOnSuccess: TProc<T>;
  const AOnError: TProc<string>);
begin
  TTask.Run(procedure
    var
      LConn: IConnection;
      LController: TAsyncController;
      LClassType: TClass;
      LEntity: T;
      LSuccess: Boolean;
      LErrorMessage: string;
    begin
      LEntity := nil;
      LConn := nil;
      LController := nil;
      try
        try
          // 1. Acquire connection
          if Assigned(OnAcquireConnection) then
            LConn := OnAcquireConnection()
          else
            LConn := TConnectionPool.GetInstance.AcquireConnection;

          // 2. Create a new instance of this specific controller class
          LClassType := Self.ClassType;

          if not LClassType.InheritsFrom(TAsyncController) then
             raise EBridgeControllerError.Create(SControllerAsyncInheritance);
          
          LController := TAsyncControllerClass(LClassType).Create(LConn);

          // 3. Create entity and load data
          LEntity := T.Create;
          
          // Handle Variant type - try different overloads based on VarType
          case VarType(AId) of
            varInteger, varSmallint, varByte:
              LSuccess := LController.Load(LEntity, Integer(AId));
            varInt64:
              LSuccess := LController.Load(LEntity, Int64(AId));
            varString, varUString, varOleStr:
              LSuccess := LController.Load(LEntity, string(AId));
          else
            // Default to Integer for other types
            LSuccess := LController.Load(LEntity, Integer(AId));
          end;

          if LSuccess then
          begin
            // 4. On Success
            if Assigned(AOnSuccess) then
              AOnSuccess(LEntity)
            else
              LEntity.Free;
          end
          else
          begin
            // Record not found
            LEntity.Free;
            if Assigned(AOnSuccess) then
              AOnSuccess(nil);
          end;

        except
          on E: Exception do
          begin
            if Assigned(LEntity) then LEntity.Free;
            LErrorMessage := E.Message;
            
            if Assigned(AOnError) then
              AOnError(LErrorMessage);
          end;
        end;
      finally
        // 5. Release connection and free controller
        if Assigned(LController) then LController.Free;
        if Assigned(LConn) then
        begin
          if Assigned(OnReleaseConnection) then
            OnReleaseConnection(LConn)
          else
            TConnectionPool.GetInstance.ReleaseConnection(LConn);
        end;
      end;
    end);
end;

end.
