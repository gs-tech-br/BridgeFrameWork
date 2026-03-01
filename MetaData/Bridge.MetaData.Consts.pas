unit Bridge.MetaData.Consts;

interface

type
  TMetaDataConsts = class
  public
    const
      // Validation Messages
      REQUIRED_FIELD = 'The field %s is required.';
      MAX_LENGTH_EXCEEDED = 'The field %s exceeds the maximum length of %d characters (current: %d).';
      OUT_OF_RANGE = 'The field %s must be between %s and %s.';
      NULL_OBJECT = 'The object cannot be null.';
      PROPERTY_NOT_FOUND = 'Property not found: %s';
      
      // Metadata tags
      TAG_ID_MISSING = 'Tag %s used, but class %s does not have [Id] attribute';
      TAG_COMPOSITE_KEY_MISSING = 'Tag %s used, but class %s does not have [CompositeKey] attribute';
      
      // Cache info
      CACHE_INFO = 'Cache contains metadata for %d classes';
      
      // Error Codes
      ERR_REQUIRED = 'REQUIRED_FIELD';
      ERR_MAX_LENGTH = 'MAX_LENGTH_EXCEEDED';
      ERR_RANGE = 'OUT_OF_RANGE';
      ERR_NULL_OBJ = 'NULL_OBJECT';
      ERR_PROP_NOT_FOUND = 'PROPERTY_NOT_FOUND';
  end;

implementation

end.
