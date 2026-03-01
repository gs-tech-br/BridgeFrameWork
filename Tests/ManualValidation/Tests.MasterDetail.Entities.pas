unit Tests.MasterDetail.Entities;

interface

uses
  System.Generics.Collections,
  Bridge.MetaData.Attributes;

type
  TMaster = class;
  TDetail = class;

  [Entity('TEST_MASTER')]
  TMaster = class
  private
    [Id(True)]
    [Column('ID')]
    FId: Integer;
    
    [Column('DESCRIPTION', 100)]
    FDescription: String;
    
    [HasMany('MASTER_ID')]
    FDetails: TObjectList<TDetail>;
  public
    constructor Create;
    destructor Destroy; override;

    property Id: Integer read FId write FId;
    property Description: String read FDescription write FDescription;
    property Details: TObjectList<TDetail> read FDetails;
  end;

  [Entity('TEST_DETAIL')]
  TDetail = class
  private
    [Id(True)]
    [Column('ID')]
    FId: Integer;
    
    [Column('MASTER_ID')]
    FMasterId: Integer;
    
    [Column('DESCRIPTION', 200)]
    FDescription: String;
    
    [BelongsTo('MASTER_ID')]
    FMaster: TMaster;
  public
    property Id: Integer read FId write FId;
    property MasterId: Integer read FMasterId write FMasterId;
    property Description: String read FDescription write FDescription;
    property Master: TMaster read FMaster write FMaster;
  end;

implementation

{ TMaster }

constructor TMaster.Create;
begin
  FDetails := TObjectList<TDetail>.Create;
end;

destructor TMaster.Destroy;
begin
  FDetails.Free;
  inherited;
end;

end.
