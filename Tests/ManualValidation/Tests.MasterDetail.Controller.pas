unit Tests.MasterDetail.Controller;

interface

uses
  System.Generics.Collections,
  Bridge.Base.Controller,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Tests.MasterDetail.Model,
  Tests.MasterDetail.Entities;

type
  TMasterController = class(TBaseController)
  public
    procedure SetConnection(AConnection: IConnection); override;
    function LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean; override;
  end;

  TDetailController = class(TBaseController)
  public
    procedure SetConnection(AConnection: IConnection); override;
    function LoadList(AList: TObject; ACriteria: TList<TCriterion>): Boolean; override;
  end;

implementation

{ TMasterController }

procedure TMasterController.SetConnection(AConnection: IConnection);
begin
  FModel := TMasterModel.Create(AConnection);
  FEntityClass := Tests.MasterDetail.Entities.TMaster;
end;

function TMasterController.LoadList(AList: TObject;
  ACriteria: TList<TCriterion>): Boolean;
begin
  if AList is TObjectList<TMaster> then
    Result := Self.LoadAll<TMaster>(TObjectList<TMaster>(AList), ACriteria)
  else
    Result := False;
end;

{ TDetailController }

procedure TDetailController.SetConnection(AConnection: IConnection);
begin
  FModel := TDetailModel.Create(AConnection);
  FEntityClass := Tests.MasterDetail.Entities.TDetail;
end;

function TDetailController.LoadList(AList: TObject;
  ACriteria: TList<TCriterion>): Boolean;
begin
  if AList is TObjectList<TDetail> then
    Result := Self.LoadAll<TDetail>(TObjectList<TDetail>(AList), ACriteria)
  else
    Result := False;
end;

end.
