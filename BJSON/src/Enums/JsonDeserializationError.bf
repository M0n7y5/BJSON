using System;

namespace BJSON.Enums;

/// Rich deserialization error with JSON path information.
/// Provides detailed error messages including the JSON path where the error occurred.
enum JsonDeserializationError
{
	/// JSON type doesn't match expected field type.
	case TypeMismatch(StringView path, StringView expected, StringView actual);
	
	/// Required field missing from JSON.
	case MissingRequiredField(StringView path, StringView fieldName);
	
	/// Invalid enum value (string doesn't match any enum member).
	case InvalidEnumValue(StringView path, StringView value, StringView enumType);
	
	/// Null value for non-nullable field.
	case NullNotAllowed(StringView path, StringView fieldName);
	
	/// Custom converter failed.
	case ConverterFailed(StringView path, StringView message);
	
	/// Underlying parsing error from JsonReader.
	case ParseError(JsonParsingError inner);
	
	/// Unknown field and IgnoreUnknownFields is false.
	case UnknownField(StringView path, StringView fieldName);
	
	public override void ToString(String str)
	{
		switch (this)
		{
		case TypeMismatch(let path, let expected, let actual):
			str.AppendF("Type mismatch at {0}: expected {1}, got {2}", path, expected, actual);
		case MissingRequiredField(let path, let fieldName):
			str.AppendF("Missing required field '{0}' at {1}", fieldName, path);
		case InvalidEnumValue(let path, let value, let enumType):
			str.AppendF("Invalid enum value '{0}' for type {1} at {2}", value, enumType, path);
		case NullNotAllowed(let path, let fieldName):
			str.AppendF("Null value not allowed for field '{0}' at {1}", fieldName, path);
		case ConverterFailed(let path, let message):
			str.AppendF("Custom converter failed at {0}: {1}", path, message);
		case ParseError(let inner):
			str.Append("Parse error: ");
			inner.ToString(str);
		case UnknownField(let path, let fieldName):
			str.AppendF("Unknown field '{0}' at {1}", fieldName, path);
		}
	}
}
