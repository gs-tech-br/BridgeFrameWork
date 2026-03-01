unit Bridge.Audit.Entity;

interface

uses
  Bridge.MetaData.Attributes;

type
  /// <summary>
  /// Entity that represents an audit log record in the AUDIT_LOG table.
  /// Kept in a separate unit to avoid circular references between
  /// Bridge.Audit, Bridge.Audit.Controller and Bridge.Audit.Model.
  /// </summary>
  [Entity('AUDIT_LOG')]
  TAuditLog = class
  private
    FId: Int64;
    FTableName: string;
    FRecordId: string;
    FAction: string;
    FOldValue: string;
    FNewValue: string;
    FUserId: string;
    FUserName: string;
    FCreatedAt: TDateTime;
  public
    [Id, Column('ID')]
    property Id: Int64 read FId write FId;

    [Column('TABLE_NAME', 100)]
    property TableName: string read FTableName write FTableName;

    [Column('RECORD_ID', 100)]
    property RecordId: string read FRecordId write FRecordId;

    [Column('ACTION', 10)]
    property Action: string read FAction write FAction;

    [Column('OLD_VALUE', 0)] // 0 = Max/Text
    property OldValue: string read FOldValue write FOldValue;

    [Column('NEW_VALUE', 0)]
    property NewValue: string read FNewValue write FNewValue;

    [Column('USER_ID', 100)]
    property UserId: string read FUserId write FUserId;

    [Column('USER_NAME', 100)]
    property UserName: string read FUserName write FUserName;

    [Column('CREATED_AT')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

implementation

end.
