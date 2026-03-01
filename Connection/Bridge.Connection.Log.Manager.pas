unit Bridge.Connection.Log.Manager;

interface

uses
  System.Classes, System.SysUtils, FireDAC.Comp.Client, FireDAC.Stan.Param,
  System.Generics.Collections, System.Generics.Defaults, Data.DB,
  Bridge.Connection.Log.Provider;

type
  TLogManager = class
  private
    class var FInstance: TLogManager;
    FLogProvider: ILogProvider;

    function ExtractQueryLog(AQuery: TFDQuery): string;
    function FormatLogMessage(const AMessage, APrefix: string): string;
    procedure InternalLog(const ALogText: string);
    function GetLogProvider: ILogProvider;

  public
    constructor Create;
    destructor Destroy; override;

    class function GetInstance: TLogManager;
    class procedure FreeInstance; reintroduce;

    /// <summary>
    /// Registers a custom log provider.
    /// </summary>
    /// <param name="AProvider">ILogProvider interface implementation</param>
    procedure SetLogProvider(AProvider: ILogProvider);

    /// <summary>
    /// Returns the current log provider.
    /// </summary>
    property LogProvider: ILogProvider read GetLogProvider;

    // Main methods with overload
    procedure WriteLog(AQuery: TFDQuery); overload;
    procedure WriteLog(const ASQL: string); overload;
    procedure WriteLog(AQuery: TFDQuery; const APrefix: string); overload;
    procedure WriteLog(const ASQL: string; const APrefix: string); overload;
    procedure WriteLog(const ASQL: string; const APrefix: string; const ASuffix: string); overload;

    // Specific methods for different scenarios
    procedure WriteLogInsert(AQuery: TFDQuery; const ATableName: string = '');
    procedure WriteLogUpdate(AQuery: TFDQuery; const ATableName: string = '');
    procedure WriteLogDelete(AQuery: TFDQuery; const ATableName: string = '');
    procedure WriteLogSelect(AQuery: TFDQuery; const AContext: string = '');
    procedure WriteLogCustom(const AMessage: string);
    procedure WriteLogError(const AErro: string; const AContext: string = '');
    procedure WriteLogInfo(const AInfo: string);
    procedure WriteLogDebug(const ADebug: string);

    procedure SendMessageToConsole(Sender: TObject; const AMessage: string);
    procedure SendDoneToConsole(Sender: TObject);
  end;

implementation

uses
  System.StrUtils;

{ TLogManager }

constructor TLogManager.Create;
begin
  inherited Create;
  FLogProvider := nil;
end;

destructor TLogManager.Destroy;
begin
  FLogProvider := nil;
  inherited Destroy;
end;

class function TLogManager.GetInstance: TLogManager;
begin
  if FInstance = nil then
    FInstance := TLogManager.Create;
  Result := FInstance;
end;

class procedure TLogManager.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

function TLogManager.GetLogProvider: ILogProvider;
begin
  if FLogProvider = nil then
    FLogProvider := TNullLogProvider.Create;
  Result := FLogProvider;
end;

procedure TLogManager.SetLogProvider(AProvider: ILogProvider);
begin
  FLogProvider := AProvider;
end;

function TLogManager.ExtractQueryLog(AQuery: TFDQuery): string;
var
  I: Integer;
  vParams: TList<TFDParam>;
  vParam: TFDParam;
  vParamValue: string;
begin
  if (AQuery = nil) or (AQuery.SQL.Count = 0) then
  begin
    Result := '';
    Exit;
  end;

  Result := AQuery.SQL.Text;

  if AQuery.Params.Count = 0 then
    Exit;

  // Cria lista ordenada de parametros (maior nome primeiro para evitar substituicoes parciais)
  vParams := TList<TFDParam>.Create;
  try
    for I := 0 to AQuery.Params.Count - 1 do
      vParams.Add(AQuery.Params[I]);

    // Ordena por tamanho do nome (decrescente)
    vParams.Sort(TComparer<TFDParam>.Construct(
      function(const Left, Right: TFDParam): Integer
      begin
        Result := -CompareText(Left.Name, Right.Name);
      end));

    // Substitui parametros pelos valores
    for I := 0 to vParams.Count - 1 do
    begin
      vParam := vParams[I];

      if vParam.IsNull then
        vParamValue := 'NULL'
      else
        case vParam.DataType of
          ftString, ftWideString, ftDate, ftTime, ftDateTime:
            vParamValue := QuotedStr(vParam.AsString);
          ftFloat, ftCurrency, ftExtended:
            vParamValue := vParam.AsString.Replace(',', '.');
          ftBlob:
            vParamValue := '[BlobData]';
        else
          vParamValue := vParam.AsString;
        end;

      Result := ReplaceText(Result, ':' + vParam.Name, vParamValue);
    end;

  finally
    vParams.Free;
  end;
end;

function TLogManager.FormatLogMessage(const AMessage, APrefix: string): string;
begin
  Result := AMessage;

  if not APrefix.IsEmpty then
    Result := APrefix + sLineBreak + Result;
end;

procedure TLogManager.InternalLog(const ALogText: string);
begin
  if ALogText.IsEmpty then
    Exit;

  try
    if LogProvider.IsEnabled then
      LogProvider.Log(ALogText);
  except
    // in case of exception at this point, do nothing so the application can continue
  end;
end;

procedure TLogManager.SendDoneToConsole(Sender: TObject);
begin
  if LogProvider.SendSqlMessagesEnabled then
    LogProvider.SendDone(Sender);
end;

procedure TLogManager.SendMessageToConsole(Sender: TObject; const AMessage: string);
begin
  if LogProvider.SendSqlMessagesEnabled then
    LogProvider.SendMessage(Sender, AMessage);
end;

procedure TLogManager.WriteLog(AQuery: TFDQuery);
var
  vLogText: string;
begin
  if AQuery = nil then
    Exit;

  try
    vLogText := ExtractQueryLog(AQuery);
    InternalLog(vLogText);
  except
    on E: Exception do
      InternalLog('Error generating query log: ' + E.Message);
  end;
end;

procedure TLogManager.WriteLog(const ASQL: string);
begin
  if ASQL.IsEmpty then
    Exit;

  try
    InternalLog(ASQL);
  except
    on E: Exception do
      InternalLog('Error generating SQL log: ' + E.Message);
  end;
end;

procedure TLogManager.WriteLog(AQuery: TFDQuery; const APrefix: string);
var
  vLogText: string;
begin
  if AQuery = nil then
    Exit;

  try
    vLogText := ExtractQueryLog(AQuery);
    vLogText := FormatLogMessage(vLogText, APrefix);
    InternalLog(vLogText);
  except
    on E: Exception do
      InternalLog('Error generating query log with prefix: ' + E.Message);
  end;
end;

procedure TLogManager.WriteLog(const ASQL: string; const APrefix: string);
var
  vLogText: string;
begin
  if ASQL.IsEmpty then
    Exit;

  try
    vLogText := FormatLogMessage(ASQL, APrefix);
    InternalLog(vLogText);
  except
    on E: Exception do
      InternalLog('Error generating SQL log with prefix: ' + E.Message);
  end;
end;

procedure TLogManager.WriteLog(const ASQL: string; const APrefix: string; const ASuffix: string);
var
  vLogText: string;
begin
  if ASQL.IsEmpty then
    Exit;

  try
    vLogText := FormatLogMessage(ASQL, APrefix);

    if not ASuffix.IsEmpty then
      vLogText := vLogText + sLineBreak + ASuffix;

    InternalLog(vLogText);
  except
    on E: Exception do
      InternalLog('Error generating complete SQL log: ' + E.Message);
  end;
end;

procedure TLogManager.WriteLogInsert(AQuery: TFDQuery; const ATableName: string);
var
  vPrefix: string;
begin
  if ATableName.IsEmpty then
    vPrefix := '[INSERT]'
  else
    vPrefix := '[INSERT] Tabela: ' + ATableName;

  WriteLog(AQuery, vPrefix);
end;

procedure TLogManager.WriteLogUpdate(AQuery: TFDQuery; const ATableName: string);
var
  vPrefix: string;
begin
  if ATableName.IsEmpty then
    vPrefix := '[UPDATE]'
  else
    vPrefix := '[UPDATE] Tabela: ' + ATableName;

  WriteLog(AQuery, vPrefix);
end;

procedure TLogManager.WriteLogDelete(AQuery: TFDQuery; const ATableName: string);
var
  vPrefix: string;
begin
  if ATableName.IsEmpty then
    vPrefix := '[DELETE]'
  else
    vPrefix := '[DELETE] Tabela: ' + ATableName;

  WriteLog(AQuery, vPrefix);
end;

procedure TLogManager.WriteLogSelect(AQuery: TFDQuery; const AContext: string);
var
  vPrefix: string;
begin
  if AContext.IsEmpty then
    vPrefix := '[SELECT]'
  else
    vPrefix := '[SELECT] Contexto: ' + AContext;

  WriteLog(AQuery, vPrefix);
end;

procedure TLogManager.WriteLogCustom(const AMessage: string);
begin
  WriteLog(AMessage, '[CUSTOM]');
end;

procedure TLogManager.WriteLogError(const AErro: string; const AContext: string);
var
  vPrefix: string;
begin
  if AContext.IsEmpty then
    vPrefix := '[ERRO]'
  else
    vPrefix := '[ERRO] ' + AContext;

  WriteLog(AErro, vPrefix);
end;

procedure TLogManager.WriteLogInfo(const AInfo: string);
begin
  WriteLog(AInfo, '[INFO]');
end;

procedure TLogManager.WriteLogDebug(const ADebug: string);
begin
  WriteLog(ADebug, '[DEBUG]');
end;

initialization

finalization
  TLogManager.FreeInstance;

end.
