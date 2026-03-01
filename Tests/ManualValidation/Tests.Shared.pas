unit Tests.Shared;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  Bridge.Connection.Interfaces,
  Bridge.Connection.Types,
  Bridge.Connection.SQLite,
  Bridge.Base.Controller,
  Bridge.MetaData.Attributes,
  Bridge.Connection.Data;

type
  /// <summary>
  /// Provider de credenciais para SQLite em memória
  /// </summary>
  TMemoryCredentialsProvider = class(TInterfacedObject, IConnectionCredentialsProvider)
  public
    function GetDriverID: string;
    function GetServer: string;
    function GetPort: string;
    function GetDatabase: string;
    function GetUserName: string;
    function GetPassword: string;
    function GetDataBaseConnection: TDataBaseConnection;
  end;

  /// <summary>
  /// Entidade de teste
  /// </summary>
  [Entity('PERSON')]
  TPerson = class
  private
    [Id(True)]
    [Column('ID')]
    FId: Integer;
    
    [Column('NAME')]
    FName: String;
    
    [Column('AGE')]
    FAge: Integer;
  public
    property Id: Integer read FId write FId;
    property Name: String read FName write FName;
    property Age: Integer read FAge write FAge;
  end;

  /// <summary>
  /// Entidade de teste com SoftDelete
  /// </summary>
  [Entity('PERSON_SOFT')]
  TSoftDeletePerson = class
  private
    [Id(True)]
    [Column('ID')]
    FId: Integer;

    [Column('NAME')]
    FName: String;

    [Column('IS_DELETED')]
    [SoftDelete(1, 0)]
    FIsDeleted: Integer;
  public
    property Id: Integer read FId write FId;
    property Name: String read FName write FName;
    property IsDeleted: Integer read FIsDeleted write FIsDeleted;
  end;

/// <summary>
/// Cria uma conexão SQLite em memória para testes
/// </summary>
function CreateTestConnection: IConnection;

/// <summary>
/// Cria um controller com conexão de teste
/// </summary>
function CreateTestController: TBaseController; overload;
function CreateTestController(AConnection: IConnection): TBaseController; overload;

/// <summary>
/// Cria a tabela PERSON para testes
/// </summary>
procedure CreatePersonTable(AConnection: IConnection);

/// <summary>
/// Cria a tabela PERSON_SOFT para testes
/// </summary>
procedure CreateSoftDeletePersonTable(AConnection: IConnection);

implementation

{ TMemoryCredentialsProvider }

function TMemoryCredentialsProvider.GetDriverID: string;
begin
  Result := 'SQLite';
end;

function TMemoryCredentialsProvider.GetServer: string;
begin
  Result := '';
end;

function TMemoryCredentialsProvider.GetPort: string;
begin
  Result := '';
end;

function TMemoryCredentialsProvider.GetDatabase: string;
begin
  Result := ':memory:';
end;

function TMemoryCredentialsProvider.GetUserName: string;
begin
  Result := '';
end;

function TMemoryCredentialsProvider.GetPassword: string;
begin
  Result := '';
end;

function TMemoryCredentialsProvider.GetDataBaseConnection: TDataBaseConnection;
begin
  Result := dbSQLite;
end;

{ Helper Functions }

function CreateTestConnection: IConnection;
var
  LCredentials: IConnectionCredentialsProvider;
begin
  LCredentials := TMemoryCredentialsProvider.Create;
  Result := TConnectionSQLite.Create(LCredentials);
end;

function CreateTestController: TBaseController;
begin
  Result := TBaseController.Create(CreateTestConnection);
end;

function CreateTestController(AConnection: IConnection): TBaseController;
begin
  Result := TBaseController.Create(AConnection);
end;

procedure CreatePersonTable(AConnection: IConnection);
begin
  AConnection.Execute('CREATE TABLE PERSON (ID INTEGER PRIMARY KEY AUTOINCREMENT, NAME TEXT, AGE INTEGER)');
end;

procedure CreateSoftDeletePersonTable(AConnection: IConnection);
begin
  AConnection.Execute('CREATE TABLE PERSON_SOFT (ID INTEGER PRIMARY KEY AUTOINCREMENT, NAME TEXT, IS_DELETED INTEGER DEFAULT 0)');
end;

end.
