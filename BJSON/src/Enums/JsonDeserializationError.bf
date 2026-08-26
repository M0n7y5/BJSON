using System;

namespace BJSON.Enums;

/// Rich deserialization error carrying the JSON path of the value that failed.
/// Every case but ParseError takes path, the location of the offending value inside the document.
/// The generated JsonDeserialize methods return a plain Result<void>, so these cases only reach a
/// caller through code that builds them explicitly.
enum JsonDeserializationError
{
	/// The JSON value has the wrong shape for the field: expected and actual name the two types.
	case TypeMismatch(StringView path, StringView expected, StringView actual);
	
	/// A field the caller demands is absent; fieldName is the JSON name that was looked up.
	case MissingRequiredField(StringView path, StringView fieldName);
	
	/// A string does not match any case of the target enum: value is the text read, enumType the
	/// enum that rejected it.
	case InvalidEnumValue(StringView path, StringView value, StringView enumType);
	
	/// JSON null arrived for a field that cannot hold null; fieldName is the JSON name.
	case NullNotAllowed(StringView path, StringView fieldName);
	
	/// An IJsonConverter refused the value; message is the converter's explanation.
	case ConverterFailed(StringView path, StringView message);
	
	/// The reader failed before binding could start; inner is the parsing failure it reported.
	case ParseError(JsonParsingError inner);
	
	/// The document holds a field the target type does not declare and the caller treats extra
	/// fields as an error; fieldName is that JSON name.
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
