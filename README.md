# BridgeFrameWork

![Delphi](https://img.shields.io/badge/Delphi-10.4%2B-red)
![FireDAC](https://img.shields.io/badge/FireDAC-Enabled-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

**BridgeFrameWork** e um framework backend robusto e flexivel para **Delphi**, desenhado para simplificar o desenvolvimento de aplicacoes empresariais. Ele implementa uma arquitetura **MVC (Model-View-Controller)** limpa, integrada a um **ORM customizado** baseado em **RTTI** e **Atributos**, permitindo persistencia de dados agil e desacoplada.

---

## \\u1F680 Funcionalidades Principais

*   **ORM Inteligente:** Mapeie suas classes Delphi diretamente para tabelas do banco de dados usando Atributos customizados (`[Entity]`, `[Column]`, `[PrimaryKey]`), eliminando SQL repetitivo.
*   **Arquitetura MVC:** Separacao clara de responsabilidades com `Controllers` para regras de negocio e `Models` para persistencia.
*   **Multi-Database:** Suporte a SQL Server, SQLite, MySQL, PostgreSQL, Oracle e Firebird via FireDAC.
*   **Multiplataforma:** Suporte a Windows e Linux com configuracao automatica de drivers.
*   **Injecao de Dependencia:** Interface `IConnectionCredentialsProvider` para credenciais customizadas ou leitura automatica do `.ini`.
*   **Configuracao Flexivel de Drivers:** Interface `IDriverConfigProvider` para customizacao de caminhos de bibliotecas.
*   **Generics Power:** Controllers e Models genericos (`TController<T>`) para operacoes CRUD padronizadas e tipadas.
*   **Validacao Automatica:** Validacoes de campos obrigatorios e tamanhos de string baseadas em metadados antes da persistencia.
*   **Lazy Loading:** Carregamento sob demanda de relacionamentos (`[BelongsTo]`, `[HasMany]`) transparentemente.
*   **Suporte a Transacoes:** Controle transacional simplificado (`Begin`, `Commit`, `Rollback`).
*   **Batch Insert Otimizado:** Metodo `InsertBatch` para insercoes em massa com prepared statements, ate 27x mais rapido que insert individual.
*   **Suporte Assincrono:** Operacoes de banco de dados nao bloqueantes via `TAsyncController` e Connection Pooling.
*   **Query Builder:** Construcao fluente de consultas SQL diretamente no codigo Delphi, com suporte a filtros complexos, ordenacao e paginacao.
*   **REST API Ready:** Base `TRestController` integrada ao **Horse** para criacao rapida de APIs JSON com suporte completo a **GET, POST, PUT, DELETE** e **PATCH** (atualizacoes parciais).

---

## \\u1F3D7 Arquitetura

O framework e organizado em camadas logicas para garantir manutenibilidade e escalabilidade:

### 1. MetaData (ORM Core)
O coracao do framework. Utiliza RTTI para ler atributos das classes (`TEntity`) e gerar comandos SQL dinamicamente.
*   `TMetaDataManager`: Gerenciador de metadados singleton.
*   `Attributes`: Definem o mapeamento (`[Table('CLIENTES')]`, `[Column('ID', True)]`).

### 2. Controller
A porta de entrada para a logica de negocios.
*   `TController`: Classe base que oferece metodos CRUD (`Insert`, `Update`, `UpdatePartial`, `Delete`, `Load`, `Find`).
*   Gerencia o ciclo de vida das transacoes e validacoes de regras de negocio.

### 3. Model
Responsavel pela comunicacao direta com o banco de dados.
*   Abstrai a execucao de SQL e manuseio de `TDataSet`/`TFDQuery`.

### 4. Connection
Gerencia conexoes de banco de dados atraves de um padrao **Factory** com suporte a injecao de dependencia:
*   `IConnectionCredentialsProvider`: Interface para fornecer credenciais de conexao.
*   `IDriverConfigProvider`: Interface para configuracao de drivers (VendorLib, VendorHome).
*   `TConnectionData`: Implementacao padrao que le do arquivo `.ini`.
*   `TConnectionFactory`: Factory inteligente que detecta provider registrado ou usa `.ini`.
*   **Drivers suportados:** SQL Server, SQLite, MySQL, PostgreSQL, Oracle, Firebird.

---

## \\u1F4E6 Instalacao

### Pre-requisitos
*   Delphi 10.4 ou superior (Recomendado).
*   Componentes FireDAC instalados.

### Passos
1.  Clone este repositorio:
    ```bash
    git clone https://gitlab.com/jvictor_gs/bridgeframework.git
    ```
2.  Adicione as pastas `Classes`, `Connection`, `Controller`, `MetaData` e `Model` ao `Library Path` do seu Delphi ou ao `Search Path` do seu projeto.

### Requisitos para Linux
Para uso em Linux, instale as bibliotecas cliente do banco de dados:

```bash
# PostgreSQL
sudo apt install libpq5

# MySQL
sudo apt install libmysqlclient21

# SQLite
sudo apt install libsqlite3-0

# Firebird
sudo apt install libfbclient2

# SQL Server (ODBC)
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo apt install msodbcsql17 unixodbc

# Oracle - Baixe o Oracle Instant Client e configure LD_LIBRARY_PATH
```

---

## \\u1F6E0 Como Usar

### 1. Definindo uma Entidade
Decore sua classe com os atributos do framework:

```delphi
type
  [Entity('TB_CLIENTE')]
  TCliente = class
  private
    // IMPORTANTE: Para o motor de Alta Performance (FastRTTI),
    // os campos privados DEVEM seguir o padrao 'F' + NomeDaPropriedade.
    // Ex: property Nome -> field FNome
    [Id(True)] //Define a coluna como chave primaria autoincremento
    [Column('ID', 0, False)] // Nome, Size, Nullable
    FId: Integer;
    
    [Column('NOME', 100, False)]
    FNome: String;
'    
    [BelongsTo('ID_GRUPO')]
    FGrupo: TLazy<TGrupo>;

    [HasMany('ID_CLIENTE')]
    FPedidos: TLazyList<TPedido>;
  public
    property Id: Integer read FId write FId;
    property Nome: String read FNome write FNome;
    property Grupo: TLazy<TGrupo> read FGrupo write FGrupo;
    property Pedidos: TLazyList<TPedido> read FPedidos write FPedidos;
  end;
```

> [!IMPORTANT]
> **Convencao de Nomenclatura Obrigatoria**: O framework utiliza acesso direto a memoria para maxima performance. Para que isso funcione, e **obrigatorio** que cada propriedade persistida tenha um campo privado correspondente com o prefixo 'F'. Ex: `property Endereco` deve ter um campo `FEndereco`. Se nao houver correspondencia, o campo sera ignorado pelo ORM.

### 2. Usando o Controller
Utilize o `TController` para manipular seus dados:

```delphi
var
  LController: TController;
  LCliente: TCliente;
begin
  LController := TController.Create;
  LCliente := TCliente.Create;
  try
    // Inserir
    LCliente.Nome := 'Joao Silva';
    LController.Insert(LCliente);
    
    // Buscar
    if LController.Load(LCliente, 1) then
      ShowMessage('Cliente encontrado: ' + LCliente.Nome);
      
  finally
    LCliente.Free;
    LController.Free;
  finally
    LCliente.Free;
    LController.Free;
  end;
end;

### 3. Mapeamento Hibrido (SQL Customizado + ORM)
Para cenarios complexos onde voce precisa de SQL puro, mas quer trabalhar com objetos:

```delphi
// No Model (encapsulando a query complexa)
function TClienteModel.BuscarInativosComPendencia: TFDQuery;
begin
  Result := Self.FConnection.CreateQuery;
  Result.SQL.Text := 'SELECT * FROM TB_CLIENTE c JOIN ... WHERE ...';
  Result.Open;
end;

// No Controller/View (consumindo)
var
  LLista: TObjectList<TCliente>;
  LQuery: TFDQuery;
  LController: IController;
begin
  LLista := TObjectList<TCliente>.Create;
  LController := TControllerRegistry.Instance.Get<TCliente>;
  LQuery := (LController as TBaseController).Model.FindAll('TB_CLIENTES', nil); // Exemplo simplificado
  try
    // Mapeia o DataSet resultante para a Lista de Objetos
    // Nota: Como interfaces Delphi nao suportam metodos genericos, 
    // precisamos fazer cast para TBaseController ou TController<T>
    (LController as TBaseController).LoadFromDataSet<TCliente>(LLista, LQuery);
    
    // Use seus objetos normalmente
  finally
    LLista.Free;
    LQuery.Free;
  end;
end;
```
```

### 4. Operacoes Assincronas (Novo)
Para nao travar a interface do usuario durante operacoes pesadas, utilize o `TAsyncController`:

```delphi
uses Bridge.Async.Controller;

// ...
  LController.LoadAllAsync<TCliente>(
    nil, // params
    procedure(AList: TObjectList<TCliente>)
    begin
      // Sucesso: executado na Thread Principal
      ShowMessage('Carregados ' + AList.Count.ToString + ' clientes');
      // A lista agora pertence a voce, nao esqueca de liberar!
      AList.Free;
    end,
    procedure(AMessage: string)
    begin
      // Erro: executado na Thread Principal
      ShowMessage('Erro: ' + AMessage);
    end
  );
```

### 5. Batch Insert para Alto Desempenho
Para insercoes em massa, utilize o `InsertBatch` com transacao para maxima performance (~27x mais rapido):

```delphi
var
  LController: TBaseController;
  LClientes: TObjectList<TCliente>;
  I: Integer;
begin
  LController := TBaseController.Create(FConnection);
  LClientes := TObjectList<TCliente>.Create(True);
  try
    // Prepara a lista de objetos
    for I := 1 to 1000 do
    begin
      var LCliente := TCliente.Create;
      LCliente.Nome := 'Cliente ' + I.ToString;
      LClientes.Add(LCliente);
    end;
    
    // Insere em batch (prepared statement otimizado)
    LController.BeginTransaction;
    try
      LController.InsertBatch<TCliente>(LClientes);
      LController.CommitTransaction;
    except
      LController.RollbackTransaction;
      raise;
    end;
  finally
    LClientes.Free;
    LController.Free;
  end;
end;
```

> [!TIP]
> O `InsertBatch` usa prepared statements para executar o SQL apenas uma vez e fazer bind de parametros a cada iteracao.

---

## \\u1F4DA Documentacao

A documentacao completa do framework (incluindo guias e referencia de API) pode ser gerada localmente:

1.  Execute o script `build_docs.bat` na raiz do projeto.
2.  Abra o arquivo `site/index.html` no seu navegador.

---

## \\u1F4C2 Estrutura de Diretorios

*   `/Classes` - Classes utilitarias e helpers (ex: Listas Genericas).
*   `/Connection` - Factories e classes de conexao com banco de dados.
*   `/Controller` - Logica de negocio e orquestracao.
*   `/MetaData` - Atributos de mapeamento e gerenciador de RTTI.
*   `/Model` - Implementacao de acesso a dados (DAO).

### 5. Criando APIs REST (Novo)
Crie endpoints poderosos herdando de `TRestController` (requer **Horse**):

```delphi
uses Bridge.Rest.Controller;

type
  // O Controller herda de TRestController<TEntity, TModel>
  // Automaticamente ganha: GET, POST, PUT, PATCH, DELETE com suporte a JSON
  TCategoriaController = class(TRestController<TCategoria, TCategoriaModel>)
  protected
     // Validar insercao
     function allowsInsert(Sender: TObject): TValidate; override;
  end;

// No seu servidor Horse (dpr):
begin
  // Registra as rotas padrao: /categorias, /categorias/paged, /categorias/:id
  TCategoriaController.Create.RegisterRoutes(Horse, 'categorias');
  Horse.Listen(9000);
end;
```

### 6. Paginacao por Cursor Nativamente no Banco (Novo)

O framework agora expoe nativamente o mecanismo de **Keyset Pagination** por meio de um middleware para Horse. Isso significa que apenas os registros estritamente necessarios sao consultados no banco de dados via `LIMIT`, sem trafegar tabelas inteiras para a memoria.

Ao usar `TRestController.RegisterRoutes`, a rota paginada `/paged` e injetada automaticamente.

**Como consumir a API:**
1. Primeira pagina: chamada GET padrao definindo o tamanho da pagina.
   `GET /categorias/paged?page_size=5`
2. Proxima pagina: repasse o token retornado na propriedade `next_cursor`.
   `GET /categorias/paged?page_size=5&cursor=<TOKEN_BASE64>`

Opcionalmente e possivel alterar a ordenacao via `order_by=NOME_PROPRIEDADE` e `order_desc=true`.

**Envelope de Resposta JSON:**
```json
{
  "data": [
    { "Id": 11, "Descricao": "Aco Inox" },
    { "Id": 12, "Descricao": "Aluminio" }
  ],
  "pagination": {
    "page_size": 5,
    "next_cursor": "eyJJZCI6MTJ9",
    "has_more": true
  }
}
```

---

## \\u1F91D Contribuicao

Contribuicoes sao bem-vindas!
1.  Faca um **Fork** do projeto.
2.  Execute `install_hooks.bat` para configurar os hooks de git (opcional, mas recomendado).
3.  Crie uma **Feature Branch** (`git checkout -b feature/MinhaFeature`).
4.  Faca o **Commit** (`git commit -m 'Adiciona MinhaFeature'`).
5.  Faca o **Push** (`git push origin feature/MinhaFeature`).
6.  Abra um **Merge Request**.

---

## \\u1F4C4 Licenca

Distribuido sob a licenca **MIT**. Veja `LICENSE` para mais informacoes.
