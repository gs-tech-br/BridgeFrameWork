program SimpleServer;

{$APPTYPE CONSOLE}

uses
  Horse,
  Horse.Jhonson,
  System.SysUtils,
  Bridge.Controller.Categoria;

begin
  // Middleware
  Horse.Use(Jhonson);

  // Register Routes
  // This will create routes:
  // GET /categorias
  // GET /categorias/:id
  // POST /categorias
  // PUT /categorias/:id
  // DELETE /categorias/:id
  TCategoriaController.Create.RegisterRoutes(Horse, 'categorias');

  Writeln('Server running on port 9000...');
  Horse.Listen(9000);
end.
