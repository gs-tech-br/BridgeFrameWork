unit Bridge.LazyObjectList;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults;

type
  TDataLoadProc<T: class> = reference to procedure(AList: TObjectList<T>);

  TLazyObjectList<T: class, constructor> = class(TObjectList<T>)
  private
    FLocker: TObject;
    FLoaded: Boolean;
    FLoader: TDataLoadProc<T>;
    procedure CheckAndLoad;
  protected
    function GetCount: Integer; override;
    function GetItem(Index: Integer): T; override;
    procedure SetItem(Index: Integer; const Value: T); override;
    function GetOwnsObjects: Boolean; override;
    procedure SetOwnsObjects(const Value: Boolean); override;

    function GetEnumerator: TEnumerator<T>; override;
  public
    constructor Create(const ALoader: TDataLoadProc<T>);
    destructor Destroy; override;

    function Add(const Value: T): Integer; override;
    procedure AddRange(const C: IEnumerable<T>); overload; override;
    procedure AddRange(const Values: array of T); overload; override;
    procedure Clear; override;
    function Contains(const Value: T): Boolean; override;
    procedure Delete(Index: Integer); override;
    procedure DeleteRange(AIndex, ACount: Integer); override;
    function Extract(const Value: T): T; override;
    function Remove(const Value: T): Integer; override;
    procedure RemoveAt(AIndex: Integer); override;
    procedure Exchange(Index1, Index2: Integer); override;
    procedure Move(AIndex, ANewIndex: Integer); override;
    function First: T; override;
    function Last: T; override;
    procedure Insert(Index: Integer; const Value: T); override;
    procedure InsertRange(Index: Integer; const C: IEnumerable<T>); overload; override;
    procedure InsertRange(Index: Integer; const Values: array of T); overload; override;
    function IndexOf(const Value: T): Integer; override;
    function LastIndexOf(const Value: T): Integer; override;
    procedure Reverse; override;
    procedure Sort; overload; override;
    procedure Sort(const AComparer: IComparer<T>); overload; override;
    function BinarySearch(const AValue: T; out AIndex: Integer): Boolean; overload; override;
    function BinarySearch(const AValue: T; out AIndex: Integer; const AComparer: IComparer<T>): Boolean; overload; override;
    function ToArray: TArray<T>; override;
    procedure TrimExcess; override;
    procedure Pack; override;
  end;

implementation

{ TLazyObjectList<T> }

constructor TLazyObjectList<T>.Create(const ALoader: TDataLoadProc<T>);
begin
  inherited Create;
  FLocker := TObject.Create;
  FLoaded := False;
  FLoader := ALoader;
end;

destructor TLazyObjectList<T>.Destroy;
begin
  FLocker.Free;
  inherited;
end;

procedure TLazyObjectList<T>.CheckAndLoad;
begin
  if FLoaded then
    Exit;

  TMonitor.Enter(FLocker);
  try
    if not FLoaded then
    begin
      if Assigned(FLoader) then
        FLoader(Self);
      FLoaded := True;
    end;
  finally
    TMonitor.Exit(FLocker);
  end;
end;

function TLazyObjectList<T>.Add(const Value: T): Integer;
begin
  CheckAndLoad;
  Result := inherited Add(Value);
end;

procedure TLazyObjectList<T>.AddRange(const C: IEnumerable<T>);
begin
  CheckAndLoad;
  inherited AddRange(C);
end;

procedure TLazyObjectList<T>.AddRange(const Values: array of T);
begin
  CheckAndLoad;
  inherited AddRange(Values);
end;

function TLazyObjectList<T>.BinarySearch(const AValue: T; out AIndex: Integer): Boolean;
begin
  CheckAndLoad;
  Result := inherited BinarySearch(AValue, AIndex);
end;

function TLazyObjectList<T>.BinarySearch(const AValue: T; out AIndex: Integer; const AComparer: IComparer<T>): Boolean;
begin
  CheckAndLoad;
  Result := inherited BinarySearch(AValue, AIndex, AComparer);
end;

procedure TLazyObjectList<T>.Clear;
begin
  CheckAndLoad;
  inherited Clear;
end;

function TLazyObjectList<T>.Contains(const Value: T): Boolean;
begin
  CheckAndLoad;
  Result := inherited Contains(Value);
end;

procedure TLazyObjectList<T>.Delete(Index: Integer);
begin
  CheckAndLoad;
  inherited Delete(Index);
end;

procedure TLazyObjectList<T>.DeleteRange(AIndex, ACount: Integer);
begin
  CheckAndLoad;
  inherited DeleteRange(AIndex, ACount);
end;

procedure TLazyObjectList<T>.Exchange(Index1, Index2: Integer);
begin
  CheckAndLoad;
  inherited Exchange(Index1, Index2);
end;

function TLazyObjectList<T>.Extract(const Value: T): T;
begin
  CheckAndLoad;
  Result := inherited Extract(Value);
end;

function TLazyObjectList<T>.First: T;
begin
  CheckAndLoad;
  Result := inherited First;
end;

function TLazyObjectList<T>.GetCount: Integer;
begin
  CheckAndLoad;
  Result := inherited GetCount;
end;

function TLazyObjectList<T>.GetEnumerator: TEnumerator<T>;
begin
  CheckAndLoad;
  Result := inherited GetEnumerator;
end;

function TLazyObjectList<T>.GetItem(Index: Integer): T;
begin
  CheckAndLoad;
  Result := inherited GetItem(Index);
end;

function TLazyObjectList<T>.GetOwnsObjects: Boolean;
begin
  CheckAndLoad;
  Result := inherited GetOwnsObjects;
end;

function TLazyObjectList<T>.IndexOf(const Value: T): Integer;
begin
  CheckAndLoad;
  Result := inherited IndexOf(Value);
end;

procedure TLazyObjectList<T>.Insert(Index: Integer; const Value: T);
begin
  CheckAndLoad;
  inherited Insert(Index, Value);
end;

procedure TLazyObjectList<T>.InsertRange(Index: Integer; const C: IEnumerable<T>);
begin
  CheckAndLoad;
  inherited InsertRange(Index, C);
end;

procedure TLazyObjectList<T>.InsertRange(Index: Integer; const Values: array of T);
begin
  CheckAndLoad;
  inherited InsertRange(Index, Values);
end;

function TLazyObjectList<T>.Last: T;
begin
  CheckAndLoad;
  Result := inherited Last;
end;

function TLazyObjectList<T>.LastIndexOf(const Value: T): Integer;
begin
  CheckAndLoad;
  Result := inherited LastIndexOf(Value);
end;

procedure TLazyObjectList<T>.Move(AIndex, ANewIndex: Integer);
begin
  CheckAndLoad;
  inherited Move(AIndex, ANewIndex);
end;

procedure TLazyObjectList<T>.Pack;
begin
  CheckAndLoad;
  inherited Pack;
end;

function TLazyObjectList<T>.Remove(const Value: T): Integer;
begin
  CheckAndLoad;
  Result := inherited Remove(Value);
end;

procedure TLazyObjectList<T>.RemoveAt(AIndex: Integer);
begin
  CheckAndLoad;
  inherited RemoveAt(AIndex);
end;

procedure TLazyObjectList<T>.Reverse;
begin
  CheckAndLoad;
  inherited Reverse;
end;

procedure TLazyObjectList<T>.SetItem(Index: Integer; const Value: T);
begin
  CheckAndLoad;
  inherited SetItem(Index, Value);
end;

procedure TLazyObjectList<T>.SetOwnsObjects(const Value: Boolean);
begin
  CheckAndLoad;
  inherited SetOwnsObjects(Value);
end;

procedure TLazyObjectList<T>.Sort;
begin
  CheckAndLoad;
  inherited Sort;
end;

procedure TLazyObjectList<T>.Sort(const AComparer: IComparer<T>);
begin
  CheckAndLoad;
  inherited Sort(AComparer);
end;

function TLazyObjectList<T>.ToArray: TArray<T>;
begin
  CheckAndLoad;
  Result := inherited ToArray;
end;

procedure TLazyObjectList<T>.TrimExcess;
begin
  CheckAndLoad;
  inherited TrimExcess;
end;

end.
