unit Bridge.Connection.Singleton;

interface

uses
  Bridge.Connection.Interfaces,
  Bridge.Connection.Factory;

type
  TConnectionSingleton = class
  private
    class var FInstance: TConnectionSingleton;
    class var FConnection: IConnection;

    constructor Create;
  public
    class function GetInstance: IConnection;
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils;

{ TConnectionSingleton }

constructor TConnectionSingleton.Create;
begin
  inherited Create;
end;

destructor TConnectionSingleton.Destroy;
begin
  FConnection := nil;
  inherited;
end;

class function TConnectionSingleton.GetInstance: IConnection;
begin
  if not Assigned(FInstance) then
    FInstance := TConnectionSingleton.Create;

  if not Assigned(FConnection) then
    FConnection := TConnectionFactory.New.CreateDataAccessObject;

  Result := FConnection;
end;

initialization

finalization
  FreeAndNil(TConnectionSingleton.FInstance);

end.
