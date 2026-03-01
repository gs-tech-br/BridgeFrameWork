program ManualValidation;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.TypInfo,
  Data.DB,
  FireDAC.Comp.Client,
  Bridge.Controller.Interfaces in '..\..\Controller\Bridge.Controller.Interfaces.pas',
  Bridge.Base.Controller in '..\..\Controller\Bridge.Base.Controller.pas',
  Bridge.Controller.Registry in '..\..\Controller\Bridge.Controller.Registry.pas',
  Bridge.Lazy in '..\..\Classes\Bridge.Lazy.pas',
  Bridge.Connection.Data in '..\..\Connection\Bridge.Connection.Data.pas',
  Bridge.Connection.Factory in '..\..\Connection\Bridge.Connection.Factory.pas',
  Bridge.Connection.Firebird in '..\..\Connection\Bridge.Connection.Firebird.pas',
  Bridge.Connection.Interfaces in '..\..\Connection\Bridge.Connection.Interfaces.pas',
  Bridge.Connection.Log.Manager in '..\..\Connection\Bridge.Connection.Log.Manager.pas',
  Bridge.Connection.Log.Provider in '..\..\Connection\Bridge.Connection.Log.Provider.pas',
  Bridge.Connection.MySQL in '..\..\Connection\Bridge.Connection.MySQL.pas',
  //Bridge.Connection.Oracle in '..\..\Connection\Bridge.Connection.Oracle.pas',
  Bridge.Connection.Pool in '..\..\Connection\Bridge.Connection.Pool.pas',
  Bridge.Connection.Postgres in '..\..\Connection\Bridge.Connection.Postgres.pas',
  Bridge.Connection.Singleton in '..\..\Connection\Bridge.Connection.Singleton.pas',
  Bridge.Connection.SQLite in '..\..\Connection\Bridge.Connection.SQLite.pas',
  //Bridge.Connection.SQLServer in '..\..\Connection\Bridge.Connection.SQLServer.pas',
  Bridge.Connection.Types in '..\..\Connection\Bridge.Connection.Types.pas',
  Bridge.Connection.Utils in '..\..\Connection\Bridge.Connection.Utils.pas',
  Bridge.Driver.Config in '..\..\Connection\Bridge.Driver.Config.pas',
  Bridge.FastRtti in '..\..\Classes\Bridge.FastRtti.pas',
  Bridge.MetaData.Attributes in '..\..\MetaData\Bridge.MetaData.Attributes.pas',
  Bridge.MetaData.Manager in '..\..\MetaData\Bridge.MetaData.Manager.pas',
  Bridge.MetaData.ScriptGenerator in '..\..\MetaData\Bridge.MetaData.ScriptGenerator.pas',
  Bridge.MetaData.Validation.Helper in '..\..\MetaData\Bridge.MetaData.Validation.Helper.pas',
  Bridge.RttiHelper in '..\..\Classes\Bridge.RttiHelper.pas',
  Bridge.MetaData.EntityInitializer in '..\..\MetaData\Bridge.MetaData.EntityInitializer.pas',
  Bridge.Base.Model in '..\..\Model\Bridge.Base.Model.pas',
  Bridge.Model.Interfaces in '..\..\Model\Bridge.Model.Interfaces.pas',
  Tests.Shared in 'Tests.Shared.pas',
  Tests.Write in 'Tests.Write.pas',
  Tests.Read in 'Tests.Read.pas',
  Tests.Performance in 'Tests.Performance.pas',
  Tests.Infrastructure in 'Tests.Infrastructure.pas',
  Tests.Features in 'Tests.Features.pas',
  Tests.Lazy in 'Tests.Lazy.pas',
  Bridge.MetaData.Mapper in '..\..\MetaData\Bridge.MetaData.Mapper.pas',
  Bridge.Connection.Base in '..\..\Connection\Bridge.Connection.Base.pas',
  Bridge.Connection.Generator.Interfaces in '..\..\Connection\Bridge.Connection.Generator.Interfaces.pas',
  Bridge.Connection.Generator.Base in '..\..\Connection\Bridge.Connection.Generator.Base.pas',
  Bridge.Connection.Generator.MySQL in '..\..\Connection\Bridge.Connection.Generator.MySQL.pas',
  Bridge.Connection.Generator.Firebird in '..\..\Connection\Bridge.Connection.Generator.Firebird.pas',
  Bridge.Connection.Generator.Postgres in '..\..\Connection\Bridge.Connection.Generator.Postgres.pas',
  //Bridge.Connection.Generator.Oracle in '..\..\Connection\Bridge.Connection.Generator.Oracle.pas',
  Bridge.Connection.Generator.SQLite in '..\..\Connection\Bridge.Connection.Generator.SQLite.pas',
  //Bridge.Connection.Generator.SQLServer in '..\..\Connection\Bridge.Connection.Generator.SQLServer.pas',
  Bridge.Controller.Helper in '..\..\Controller\Bridge.Controller.Helper.pas',
  Bridge.MetaData.Consts in '..\..\MetaData\Bridge.MetaData.Consts.pas',
  Bridge.MetaData.Types in '..\..\MetaData\Bridge.MetaData.Types.pas',
  Bridge.Model.Errors in '..\..\Model\Bridge.Model.Errors.pas',
  Bridge.Controller.Errors in '..\..\Controller\Bridge.Controller.Errors.pas',
  Bridge.Async.Controller in '..\..\Controller\Bridge.Async.Controller.pas',
  Tests.MasterDetail in 'Tests.MasterDetail.pas',
  Tests.CursorPagination in 'Tests.CursorPagination.pas',
  Tests.DebugCursor in 'Tests.DebugCursor.pas',
  Tests.CursorTieBreaking in 'Tests.CursorTieBreaking.pas',
  Tests.Async in 'Tests.Async.pas',
  Tests.Patch in 'Tests.Patch.pas',
  Bridge.Rest.Controller in '..\..\Controller\Bridge.Rest.Controller.pas',
  Bridge.Neon.Config in '..\..\Classes\Bridge.Neon.Config.pas',
  Bridge.Audit in '..\..\Audit\Bridge.Audit.pas',
  Bridge.Audit.Model in '..\..\Audit\Bridge.Audit.Model.pas',
  Bridge.Audit.Controller in '..\..\Audit\Bridge.Audit.Controller.pas',
  Tests.Audit in 'Tests.Audit.pas',
  Bridge.Audit.Entity in '..\..\Audit\Bridge.Audit.Entity.pas',
  Tests.QueryBuilder in 'Tests.QueryBuilder.pas',
  Bridge.Controller.QueryBuilder in '..\..\Controller\Bridge.Controller.QueryBuilder.pas',
  Bridge.Horse.Pagination in '..\..\Classes\Bridge.Horse.Pagination.pas';

begin
  try
    Writeln('');
    Writeln('###############################################');
    Writeln('#     BridgeFrameWork - Manual Validation    #');
    Writeln('###############################################');
    
    // ========================================
    // WRITE TESTS
    // ========================================
    Writeln('');
    Writeln('>>> WRITE OPERATIONS <<<');
    RunBasicInsertTest;
    RunUpdateTest;
    RunDeleteTest;
    RunSqlInjectionTest;
    
    // ========================================
    // READ TESTS
    // ========================================
    Writeln('');
    Writeln('>>> READ OPERATIONS <<<');
    RunLoadAllTest;
    RunLoadFromDataSetTest;
    
    // ========================================
    // PERFORMANCE TESTS
    // ========================================
    Writeln('');
    // Run stress tests and capture times from output
    RunStressTest;
    RunStressTestWithTransaction;
    RunStressTestWithInsertBatch;
    RunStressTestWithUpdateBatch;
    RunStressTestWithDeleteBatch;


    Writeln('--------------------------------------------------');
    Writeln('RESULTS SUMMARY:');
    Writeln('--------------------------------------------------');
    Writeln('Method                    | Time');
    Writeln('--------------------------|-----------');
    Writeln(Format('Insert (no transaction)   | %8.2f ms', [GTimeNoTransaction]));
    Writeln(Format('Insert (with transaction) | %8.2f ms', [GTimeWithTransaction]));
    Writeln(Format('InsertBatch + Transaction | %8.2f ms', [GTimeWithInsertBatch]));
    Writeln(Format('UpdateBatch + Transaction | %8.2f ms', [GTimeWithUpdateBatch]));
    Writeln(Format('DeleteBatch + Transaction | %8.2f ms', [GTimeWithDeleteBatch]));
    Writeln('');
    
    if GTimeWithTransaction > 0 then
      Writeln(Format('Speedup vs Transaction   : %8.1fx faster', [GTimeWithTransaction / GTimeWithInsertBatch]));
    
    if GTimeNoTransaction > 0 then
      Writeln(Format('Speedup vs No Transaction: %8.1fx faster', [GTimeNoTransaction / GTimeWithInsertBatch]));

    
    // ========================================
    // INFRASTRUCTURE TESTS
    // ========================================
    Writeln('');
    Writeln('>>> INFRASTRUCTURE TESTS <<<');
    RunControllerRegistryTest;
    RunConnectionPoolTest;
    
    // ========================================
    // FEATURE TESTS
    // ========================================
    Writeln('');
    Writeln('>>> FEATURE TESTS <<<');
    RunSoftDeleteTest;
    RunAsyncTest;
    RunLazyTest;
    RunMasterDetailTest;
    TestDebugMetadata;
    TestCursorPagination;
    TestCursorTieBreaking;
    RunAllAsyncTests;
    RunAllAsyncTests;
    RunAllPatchTests;
    RunAllPatchTests;
    RunAuditTest;
    
    Writeln('');
    Writeln('>>> QUERY BUILDER TESTS <<<');
    TestQueryBuilder(CreateTestConnection);
    
    Writeln('');
    Writeln('###############################################');
    Writeln('#          ALL TESTS COMPLETED!              #');
    Writeln('###############################################');
    
  except
    on E: Exception do
    begin
      Writeln('');
      Writeln('EXCEPTION: ', E.ClassName);
      Writeln('MESSAGE:   ', E.Message);
    end;
  end;
  
  Writeln('');
  Writeln('Press Enter to exit...');
  Readln;
end.
