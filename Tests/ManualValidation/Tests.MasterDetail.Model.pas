unit Tests.MasterDetail.Model;

interface

uses
  Bridge.Base.Model,
  Bridge.Connection.Interfaces;

type
  TMasterModel = class(TBaseModel)
  public
    constructor Create(AConnection: IConnection); reintroduce;
    destructor Destroy; override;
  end;

  TDetailModel = class(TBaseModel)
  public
    constructor Create(AConnection: IConnection); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TMasterModel }

constructor TMasterModel.Create(AConnection: IConnection);
begin
  inherited Create(AConnection);
end;

destructor TMasterModel.Destroy;
begin
  inherited;
end;

{ TDetailModel }

constructor TDetailModel.Create(AConnection: IConnection);
begin
  inherited Create(AConnection);
end;

destructor TDetailModel.Destroy;
begin
  inherited;
end;

end.
