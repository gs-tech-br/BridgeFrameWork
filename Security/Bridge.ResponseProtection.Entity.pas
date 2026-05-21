unit Bridge.ResponseProtection.Entity;

interface

uses
  Bridge.MetaData.Attributes;

type
  [Entity('BRIDGE_ROLE')]
  TBridgeRole = class
  private
    FId: Int64;
    FCode: string;
    FName: string;
    FActive: Integer;
  public
    [Id]
    [Column('ID')]
    property Id: Int64 read FId write FId;

    [Column('CODE', 100, False)]
    property Code: string read FCode write FCode;

    [Column('NAME', 150, False)]
    property Name: string read FName write FName;

    [Column('ACTIVE')]
    property Active: Integer read FActive write FActive;
  end;

  [Entity('BRIDGE_PRIVILEGE')]
  TBridgePrivilege = class
  private
    FId: Int64;
    FCode: string;
    FDescription: string;
    FActive: Integer;
  public
    [Id]
    [Column('ID')]
    property Id: Int64 read FId write FId;

    [Column('CODE', 150, False)]
    property Code: string read FCode write FCode;

    [Column('DESCRIPTION', 250)]
    property Description: string read FDescription write FDescription;

    [Column('ACTIVE')]
    property Active: Integer read FActive write FActive;
  end;

  [Entity('BRIDGE_ROLE_PRIVILEGE')]
  TBridgeRolePrivilege = class
  private
    FId: Int64;
    FRoleId: Int64;
    FPrivilegeId: Int64;
    FEffect: string;
    FActive: Integer;
  public
    [Id]
    [Column('ID')]
    property Id: Int64 read FId write FId;

    [Column('ROLE_ID', 0, False)]
    property RoleId: Int64 read FRoleId write FRoleId;

    [Column('PRIVILEGE_ID', 0, False)]
    property PrivilegeId: Int64 read FPrivilegeId write FPrivilegeId;

    [Column('EFFECT', 10, False)]
    property Effect: string read FEffect write FEffect;

    [Column('ACTIVE')]
    property Active: Integer read FActive write FActive;
  end;

  [Entity('BRIDGE_USER_ROLE')]
  TBridgeUserRole = class
  private
    FId: Int64;
    FUserId: string;
    FRoleId: Int64;
    FTenantId: string;
    FActive: Integer;
  public
    [Id]
    [Column('ID')]
    property Id: Int64 read FId write FId;

    [Column('USER_ID', 100, False)]
    property UserId: string read FUserId write FUserId;

    [Column('ROLE_ID', 0, False)]
    property RoleId: Int64 read FRoleId write FRoleId;

    [Column('TENANT_ID', 100)]
    property TenantId: string read FTenantId write FTenantId;

    [Column('ACTIVE')]
    property Active: Integer read FActive write FActive;
  end;

  [Entity('BRIDGE_FIELD_POLICY')]
  TBridgeFieldPolicy = class
  private
    FId: Int64;
    FEntityName: string;
    FTableName: string;
    FPropertyName: string;
    FJSONName: string;
    FColumnName: string;
    FPrivilegeCode: string;
    FDenyStrategy: string;
    FCategory: string;
    FPurpose: string;
    FActive: Integer;
  public
    [Id]
    [Column('ID')]
    property Id: Int64 read FId write FId;

    [Column('ENTITY_NAME', 150, False)]
    property EntityName: string read FEntityName write FEntityName;

    [Column('TABLE_NAME', 150)]
    property TableName: string read FTableName write FTableName;

    [Column('PROPERTY_NAME', 150, False)]
    property PropertyName: string read FPropertyName write FPropertyName;

    [Column('JSON_NAME', 150)]
    property JSONName: string read FJSONName write FJSONName;

    [Column('COLUMN_NAME', 150)]
    property ColumnName: string read FColumnName write FColumnName;

    [Column('PRIVILEGE_CODE', 150, False)]
    property PrivilegeCode: string read FPrivilegeCode write FPrivilegeCode;

    [Column('DENY_STRATEGY', 20, False)]
    property DenyStrategy: string read FDenyStrategy write FDenyStrategy;

    [Column('CATEGORY', 80)]
    property Category: string read FCategory write FCategory;

    [Column('PURPOSE', 120)]
    property Purpose: string read FPurpose write FPurpose;

    [Column('ACTIVE')]
    property Active: Integer read FActive write FActive;
  end;

  [Entity('BRIDGE_SECURITY_VERSION')]
  TBridgeSecurityVersion = class
  private
    FId: Int64;
    FVersion: Int64;
    FUpdatedAt: TDateTime;
  public
    [Id(False)]
    [Column('ID')]
    property Id: Int64 read FId write FId;

    [Column('VERSION')]
    property Version: Int64 read FVersion write FVersion;

    [Column('UPDATED_AT')]
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

implementation

end.
