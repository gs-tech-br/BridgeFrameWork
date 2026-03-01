unit Tests.DebugCursor;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Variants,
  Bridge.Connection.Types,
  Bridge.MetaData.Manager,
  Bridge.MetaData.Attributes,
  Bridge.FastRtti,
  Tests.Shared;

procedure TestDebugMetadata;

implementation

procedure TestDebugMetadata;
var
  LPerson: TPerson;
  LMetaData: TEntityMetaData;
  LValue: Variant;
begin
  WriteLn('=== Debug Metadata ===');
  
  LPerson := TPerson.Create;
  try
    LPerson.Id := 5;
    LPerson.Name := 'Test Person';
    LPerson.Age := 25;
    
    LMetaData := TMetaDataManager.Instance.GetMetaData(TPerson);
    
    WriteLn('Primary Key Info:');
    WriteLn('  Column: ', LMetaData.PrimaryKeyColumn);
    WriteLn('  Offset: ', LMetaData.PrimaryKeyOffset);
    WriteLn('  TypeKind: ', Ord(LMetaData.PrimaryKeyTypeKind));
    WriteLn('  IsAutoIncrement: ', LMetaData.IsAutoIncrement);
    
    WriteLn;
    WriteLn('Reading value using PK metadata:');
    LValue := TFastField.GetAsVariant(LPerson, LMetaData.PrimaryKeyOffset, LMetaData.PrimaryKeyTypeKind);
    WriteLn('  Value: ', LValue);
    WriteLn('  VarType: ', VarType(LValue));
    
    WriteLn;
    WriteLn('All Properties:');
    var I: Integer;
    for I := 0 to High(LMetaData.AllProperties) do
    begin
      WriteLn(Format('  [%d] Field: %s, Column: %s, Offset: %d, TypeKind: %d', [
        I,
        LMetaData.AllProperties[I].RttiField.Name,
        LMetaData.AllProperties[I].ColumnName,
        LMetaData.AllProperties[I].Offset,
        Ord(LMetaData.AllProperties[I].TypeKind)
      ]));
      
      LValue := TFastField.GetAsVariant(
        LPerson, 
        LMetaData.AllProperties[I].Offset, 
        LMetaData.AllProperties[I].TypeKind);
      WriteLn(Format('    Value: %s', [VarToStr(LValue)]));
    end;
    
  finally
    LPerson.Free;
  end;
  
  WriteLn;
  WriteLn('=== Debug Complete ===');
end;

end.
