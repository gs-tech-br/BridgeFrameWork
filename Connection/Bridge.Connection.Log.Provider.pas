unit Bridge.Connection.Log.Provider;

interface

type
  /// <summary>
  /// Interface for log provider implementations.
  /// Projects using BridgeFrameWork should implement this interface
  /// to integrate their own logging system.
  /// </summary>
  ILogProvider = interface
    ['{A7E3F8C1-5D2B-4A9E-8F6C-1B3D5E7F9A2C}']
    /// <summary>
    /// Records a log message.
    /// </summary>
    /// <param name="AMessage">Message to be recorded</param>
    procedure Log(const AMessage: string);

    /// <summary>
    /// Sends a message to the console/output.
    /// </summary>
    /// <param name="Sender">Object sending the message</param>
    /// <param name="AMessage">Message to be sent</param>
    procedure SendMessage(Sender: TObject; const AMessage: string);

    /// <summary>
    /// Signals completion of an operation.
    /// </summary>
    /// <param name="Sender">Object signaling completion</param>
    procedure SendDone(Sender: TObject);

    /// <summary>
    /// Indicates if the log provider is enabled.
    /// </summary>
    function IsEnabled: Boolean;

    /// <summary>
    /// Indicates if SQL messages should be sent to the console.
    /// </summary>
    function SendSqlMessagesEnabled: Boolean;
  end;

  /// <summary>
  /// Default ILogProvider implementation that does nothing (Null Object Pattern).
  /// Used when no log provider is registered.
  /// </summary>
  TNullLogProvider = class(TInterfacedObject, ILogProvider)
  public
    procedure Log(const AMessage: string);
    procedure SendMessage(Sender: TObject; const AMessage: string);
    procedure SendDone(Sender: TObject);
    function IsEnabled: Boolean;
    function SendSqlMessagesEnabled: Boolean;
  end;

implementation

{ TNullLogProvider }

function TNullLogProvider.IsEnabled: Boolean;
begin
  Result := False;
end;

procedure TNullLogProvider.Log(const AMessage: string);
begin
  // Empty implementation - Null Object Pattern
end;

procedure TNullLogProvider.SendDone(Sender: TObject);
begin
  // Empty implementation - Null Object Pattern
end;

procedure TNullLogProvider.SendMessage(Sender: TObject; const AMessage: string);
begin
  // Empty implementation - Null Object Pattern
end;

function TNullLogProvider.SendSqlMessagesEnabled: Boolean;
begin
  Result := False;
end;

end.
