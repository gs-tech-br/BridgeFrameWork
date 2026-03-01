# BridgeFrameWork

![Delphi](https://img.shields.io/badge/Delphi-10.4%2B-red)
![FireDAC](https://img.shields.io/badge/FireDAC-Enabled-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

**BridgeFrameWork** é um framework backend robusto e flexível para **Delphi**, desenhado para simplificar o desenvolvimento de aplicações empresariais. Ele implementa uma arquitetura **MVC (Model-View-Controller)** limpa, integrada a um **ORM customizado** baseado em **RTTI** e **Atributos**, permitindo persistência de dados ágil e desacoplada.

---

## 🚀 Funcionalidades Principais

*   **ORM Inteligente:** Mapeie suas classes Delphi diretamente para tabelas do banco de dados usando Atributos customizados (`[Table]`, `[Column]`, `[PrimaryKey]`), eliminando SQL repetitivo.
*   **Arquitetura MVC:** Separação clara de responsabilidades com `Controllers` para regras de negócio e `Models` para persistência.
*   **Multi-Database:** Suporte a SQL Server, SQLite, MySQL, PostgreSQL, Oracle e Firebird via FireDAC.
*   **Multiplataforma:** Suporte a Windows e Linux com configuração automática de drivers.
*   **Injeção de Dependência:** Interface `IConnectionCredentialsProvider` para credenciais customizadas ou leitura automática do `.ini`.
*   **Configuração Flexível de Drivers:** Interface `IDriverConfigProvider` para customização de caminhos de bibliotecas.
*   **Generics Power:** Controllers e Models genéricos (`TController<T>`) para operações CRUD padronizadas e tipadas.
*   **Validação Automática:** Validações de campos obrigatórios e tamanhos de string baseadas em metadados antes da persistência.
*   **Lazy Loading:** Carregamento sob demanda de relacionamentos (`[BelongsTo]`, `[HasMany]`) transparentemente.
*   **Suporte a Transações:** Controle transacional simplificado (`Begin`, `Commit`, `Rollback`).
*   **Batch Insert Otimizado:** Método `InsertBatch` para inserções em massa com prepared statements, até 27x mais rápido que insert individual.
*   **Suporte Assíncrono:** Operações de banco de dados não bloqueantes via `TAsyncController` e Connection Pooling.
*   **Query Builder:** Construção fluente de consultas SQL diretamente no código Delphi, com suporte a filtros complexos, ordenação e paginação.
*   **REST API Ready:** Base `TRestController` integrada ao **Horse** para criação rápida de APIs JSON com suporte completo a **GET, POST, PUT, DELETE** e **PATCH** (atualizações parciais).

---

## 🏗️ Arquitetura

O framework é organizado em camadas lógicas para garantir manutenibilidade e escalabilidade:

### 1. MetaData (ORM Core)
O coração do framework. Utiliza RTTI para ler atributos das classes (`TEntity`) e gerar comandos SQL dinamicamente.
*   `TMetaDataManager`: Gerenciador de metadados singleton.
*   `Attributes`: Definem o mapeamento (`[Table('CLIENTES')]`, `[Column('ID', True)]`).

### 2. Controller
A porta de entrada para a lógica de negócios.
*   `TController`: Classe base que oferece métodos CRUD (`Insert`, `Update`, `UpdatePartial`, `Delete`, `Load`, `Find`).
*   Gerencia o ciclo de vida das transações e validações de regras de negócio.

### 3. Model
Responsável pela comunicação direta com o banco de dados.
*   Abstrai a execução de SQL e manuseio de `TDataSet`/`TFDQuery`.

### 4. Connection
Gerencia conexões de banco de dados através de um padrão **Factory** com suporte a injeção de dependência:
*   `IConnectionCredentialsProvider`: Interface para fornecer credenciais de conexão.
*   `IDriverConfigProvider`: Interface para configuração de drivers (VendorLib, VendorHome).
*   `TConnectionData`: Implementação padrão que lê do arquivo `.ini`.
*   `TConnectionFactory`: Factory inteligente que detecta provider registrado ou usa `.ini`.
*   **Drivers suportados:** SQL Server, SQLite, MySQL, PostgreSQL, Oracle, Firebird.

---

## 📦 Instalação

### Pré-requisitos
*   Delphi 10.4 ou superior (Recomendado).
*   Componentes FireDAC instalados.

### Passos
1.  Clone este repositório:
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

## 🛠️ Como Usar

### 1. Definindo uma Entidade
Decore sua classe com os atributos do framework:

```delphi
type
  [Table('TB_CLIENTE')]
  TCliente = class
  private
    // IMPORTANTE: Para o motor de Alta Performance (FastRTTI),
    // os campos privados DEVEM seguir o padrão 'F' + NomeDaPropriedade.
    // Ex: property Nome -> field FNome
    
    [Column('ID', True, True)] // Nome, PrimaryKey, AutoInc
    FId: Integer;
    
    [Column('NOME')]
    [Required('O nome é obrigatório')]
    FNome: String;

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
> **Convenção de Nomenclatura Obrigatória**: O framework utiliza acesso direto à memória para máxima performance. Para que isso funcione, é **obrigatório** que cada propriedade persistida tenha um campo privado correspondente com o prefixo 'F'. Ex: `property Endereco` deve ter um campo `FEndereco`. Se não houver correspondência, o campo será ignorado pelo ORM.

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
    LCliente.Nome := 'João Silva';
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

### 3. Mapeamento Híbrido (SQL Customizado + ORM)
Para cenários complexos onde você precisa de SQL puro, mas quer trabalhar com objetos:

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
    // Nota: Como interfaces Delphi não suportam métodos genéricos, 
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

### 4. Operações Assíncronas (Novo)
Para não travar a interface do usuário durante operações pesadas, utilize o `TAsyncController`:

```delphi
uses Bridge.Async.Controller;

// ...
  LController.LoadAllAsync<TCliente>(
    nil, // params
    procedure(AList: TObjectList<TCliente>)
    begin
      // Sucesso: executado na Thread Principal
      ShowMessage('Carregados ' + AList.Count.ToString + ' clientes');
      // A lista agora pertence a você, não esqueça de liberar!
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
Para inserções em massa, utilize o `InsertBatch` com transação para máxima performance (~27x mais rápido):

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
> O `InsertBatch` usa prepared statements para executar o SQL apenas uma vez e fazer bind de parâmetros a cada iteração.

---

## 📚 Documentação

A documentação completa do framework (incluindo guias e referência de API) pode ser gerada localmente:

1.  Execute o script `build_docs.bat` na raiz do projeto.
2.  Abra o arquivo `site/index.html` no seu navegador.

---

## 📂 Estrutura de Diretórios

*   `/Classes` - Classes utilitárias e helpers (ex: Listas Genéricas).
*   `/Connection` - Factories e classes de conexão com banco de dados.
*   `/Controller` - Lógica de negócio e orquestração.
*   `/MetaData` - Atributos de mapeamento e gerenciador de RTTI.
*   `/Model` - Implementação de acesso a dados (DAO).

### 5. Criando APIs REST (Novo)
Crie endpoints poderosos herdando de `TRestController` (requer **Horse**):

```delphi
uses Bridge.Rest.Controller;

type
  // O Controller herda de TRestController<TEntity, TModel>
  // Automaticamente ganha: GET, POST, PUT, PATCH, DELETE com suporte a JSON
  TCategoriaController = class(TRestController<TCategoria, TCategoriaModel>)
  protected
     // Validar inserção
     function allowsInsert(Sender: TObject): TValidate; override;
  end;

// No seu servidor Horse (dpr):
begin
  // Registra as rotas padrão: /categorias, /categorias/paged, /categorias/:id
  TCategoriaController.Create.RegisterRoutes(Horse, 'categorias');
  Horse.Listen(9000);
end;
```

### 6. Paginação por Cursor Nativamente no Banco (Novo)

O framework agora expõe nativamente o mecanismo de **Keyset Pagination** por meio de um middleware para Horse. Isso significa que apenas os registros estritamente necessários são consultados no banco de dados via `LIMIT`, sem trafegar tabelas inteiras para a memória.

Ao usar `TRestController.RegisterRoutes`, a rota paginada `/paged` é injetada automaticamente.

**Como consumir a API:**
1. Primeira página: chamada GET padrão definindo o tamanho da página.
   `GET /categorias/paged?page_size=5`
2. Próxima página: repasse o token retornado na propriedade `next_cursor`.
   `GET /categorias/paged?page_size=5&cursor=<TOKEN_BASE64>`

Opcionalmente é possível alterar a ordenação via `order_by=NOME_PROPRIEDADE` e `order_desc=true`.

**Envelope de Resposta JSON:**
```json
{
  "data": [
    { "Id": 11, "Descricao": "Aço Inox" },
    { "Id": 12, "Descricao": "Alumínio" }
  ],
  "pagination": {
    "page_size": 5,
    "next_cursor": "eyJJZCI6MTJ9",
    "has_more": true
  }
}
```

---

## 🤝 Contribuição

Contribuições são bem-vindas!
1.  Faça um **Fork** do projeto.
2.  Execute `install_hooks.bat` para configurar os hooks de git (opcional, mas recomendado).
3.  Crie uma **Feature Branch** (`git checkout -b feature/MinhaFeature`).
4.  Faça o **Commit** (`git commit -m 'Adiciona MinhaFeature'`).
5.  Faça o **Push** (`git push origin feature/MinhaFeature`).
6.  Abra um **Merge Request**.

---

## 📄 Licença

Distribuído sob a licença **MIT**. Veja `LICENSE` para mais informações.
