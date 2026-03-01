unit Bridge.Audit.Model;

interface

uses
  Bridge.Base.Model,
  Bridge.Connection.Interfaces;

type
  TAuditModel = class(TBaseModel)
  public
    constructor Create; overload; override;
    constructor Create(AConnection: IConnection); overload; override;
  end;

implementation

{ TAuditModel }

constructor TAuditModel.Create;
begin
  inherited Create;
end;

constructor TAuditModel.Create(AConnection: IConnection);
begin
  inherited Create(AConnection);
end;

end.
