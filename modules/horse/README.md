<p align="center">
  <a href="https://github.com/HashLoad/horse/blob/master/img/horse.png">
    <img alt="Horse" height="150" src="https://github.com/HashLoad/horse/blob/master/img/horse.png">
  </a>  
</p><br>
<p align="center">
  <b>Horse</b> is an <a href="https://github.com/expressjs/express">Express</a> inspired <b>web framework</b> for Delphi and Lazarus.<br>Designed to <b>ease</b> things up for <b>fast</b> development in a <b>minimalist</b> way and with high <b>performance</b>.
</p><br>
<p align="center">
  <a href="https://t.me/hashload">
    <img src="https://img.shields.io/badge/telegram-join%20channel-7289DA?style=flat-square">
  </a>
</p>

## \\u2699 Installation
Installation is done using the [`boss install`](https://github.com/HashLoad/boss) command:
``` sh
boss install horse
```
* (Optional) Install [**wizard**](https://github.com/HashLoad/horse-wizard)

## \\u26A1 Quickstart Delphi
```delphi
uses Horse;

begin
  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('pong');
    end);

  THorse.Listen(9000);
end.
```

## \\u26A1 Quickstart Lazarus
```delphi
{$MODE DELPHI}{$H+}

uses Horse;

procedure GetPing(Req: THorseRequest; Res: THorseResponse);
begin
  Res.Send('Pong');
end;

begin
  THorse.Get('/ping', GetPing);
  THorse.Listen(9000);
end. 
```

## \\u1F9EC Official Middlewares

For a more _maintainable_ middleware _ecosystem_, we've put official middlewares into separate repositories:

| Middleware | Delphi | Lazarus |
| ------------------------------------------------------------------- | -------------------- | --------------------------- |
|  [horse/json](https://github.com/HashLoad/jhonson)                  | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [horse/basic-auth](https://github.com/HashLoad/horse-basic-auth)   | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [horse/cors](https://github.com/HashLoad/horse-cors)               | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [horse/stream](https://github.com/HashLoad/horse-octet-stream)     | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [horse/jwt](https://github.com/HashLoad/horse-jwt)                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [horse/exception](https://github.com/HashLoad/handle-exception)    | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [horse/logger](https://github.com/HashLoad/horse-logger)           | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [horse/compression](https://github.com/HashLoad/horse-compression) | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |

## \\u1F331 Third Party Middlewares

This is a list of middlewares that are created by the Horse community, please create a PR if you want to see yours!

| Middleware | Delphi | Lazarus |
| ---------------------------------------------------------------------------------------------------------- | -------------------- | --------------------------- |
|  [bittencourtthulio/etag](https://github.com/bittencourtthulio/Horse-ETag)                                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [bittencourtthulio/paginate](https://github.com/bittencourtthulio/Horse-Paginate)                         | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [bittencourtthulio/cachecontrol](https://github.com/bittencourtthulio/horse-cachecontrol)                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [gabrielbaltazar/gbswagger](https://github.com/gabrielbaltazar/gbswagger)                                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [willhubner/socketIO](https://github.com/WillHubner/Horse-SocketIO)                                       | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [dliocode/ratelimit](https://github.com/dliocode/horse-ratelimit)                                         | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [dliocode/slowdown](https://github.com/dliocode/horse-slowdown)                                           | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [giorgiobazzo/upload](https://github.com/giorgiobazzo/horse-upload)                                       | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [dliocode/query](https://github.com/dliocode/horse-query)                                                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [CarlosHe/healthcheck](https://github.com/CarlosHe/horse-healthcheck)                                     | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [CarlosHe/staticfiles](https://github.com/CarlosHe/horse-staticfiles)                                     | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [CachopaWeb/horse-server-static](https://github.com/CachopaWeb/horse-server-static)                       | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [arvanus/horse-exception-logger](https://github.com/arvanus/horse-exception-logger)                       | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [claudneysessa/Horse-CSResponsePagination](https://github.com/claudneysessa/Horse-CSResponsePagination)   | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [claudneysessa/Horse-XSuperObjects](https://github.com/claudneysessa/Horse-XSuperObjects)                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [andre-djsystem/horse-bearer-auth](https://github.com/andre-djsystem/horse-bearer-auth)                   | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [andre-djsystem/horse-manipulate-request](https://github.com/andre-djsystem/horse-manipulate-request)     | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [andre-djsystem/horse-manipulate-response](https://github.com/andre-djsystem/horse-manipulate-response)   | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u2714 |
|  [antoniojmsjr/Horse-IPGeoLocation](https://github.com/antoniojmsjr/Horse-IPGeoLocation)                   | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [antoniojmsjr/Horse-XMLDoc](https://github.com/antoniojmsjr/Horse-XMLDoc)                                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [isaquepinheiro/horse-jsonbr](https://github.com/HashLoad/JSONBr)                                         | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [IagooCesaar/Horse-JsonInterceptor](https://github.com/IagooCesaar/Horse-JsonInterceptor)                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [dliocode/horse-datalogger](https://github.com/dliocode/horse-datalogger)                                 | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |
|  [marcobreveglieri/horse-prometheus-metrics](https://github.com/marcobreveglieri/horse-prometheus-metrics) | &nbsp;&nbsp;&nbsp;\\u2714 | &nbsp;&nbsp;&nbsp;&nbsp;\\u274C |

## Delphi Versions
`Horse` works with Delphi 13 Florence, Delphi 12 Athens, Delphi 11 Alexandria, Delphi 10.4 Sydney, Delphi 10.3 Rio, Delphi 10.2 Tokyo, Delphi 10.1 Berlin, Delphi 10 Seattle, Delphi XE8 and Delphi XE7.

## \\u1F4BB Code Contributors

<a href="https://github.com/Hashload/horse/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Hashload/horse" />
</a>

## \\u26A0 License

`Horse` is free and open-source software licensed under the [MIT License](https://github.com/HashLoad/horse/blob/master/LICENSE). 

## \\u1F4D0 Tests

![tests](https://github.com/GlerystonMatos/horse/workflows/tests/badge.svg) ![Console Coverage ](https://img.shields.io/badge/console%20coverage-45%25-blue) ![VCL Coverage ](https://img.shields.io/badge/vcl%20coverage-43%25-blue)
