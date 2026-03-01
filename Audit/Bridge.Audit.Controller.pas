unit Bridge.Audit.Controller;

interface

uses
  System.Generics.Collections,
  Bridge.MetaData.Types,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Base.Controller,
  Bridge.Audit.Model,
  Bridge.Audit.Entity;

type
  TAuditController = class(TController<TAuditModel>)
  public
    constructor Create; override;
    constructor Create(AConnection: IConnection); override;
    function LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean; override;
  end;

implementation

{ TAuditController }

constructor TAuditController.Create;
begin
  inherited Create;
  FEntityClass := TAuditLog;
end;

constructor TAuditController.Create(AConnection: IConnection);
begin
  inherited Create(AConnection);
  FEntityClass := TAuditLog;
end;

function TAuditController.LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean;
begin
  if AList is TObjectList<TAuditLog> then
    Result := Self.LoadAll<TAuditLog>(TObjectList<TAuditLog>(AList), ACriteria)
  else
    Result := False;
end;

end.
