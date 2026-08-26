using System;

namespace BJSON.Enums;

/// Rich deserialization error carrying the JSON path of the value that failed.
/// Every case but ParseError takes path, and every payload the generated JsonDeserialize methods
/// build is a compile time literal: path names the field on the type that reported the error
/// ("/jsonName", never a runtime index), and an empty path means the value handed to
/// JsonDeserialize was not an object at all.
/// An error raised inside a nested [JsonObject] field propagates unchanged, so its path is
/// relative to that nested type, not to the document root.
enum JsonDeserializationError
{
	/// The JSON value has the wrong shape for the field: expected and actual name the two types.
	case TypeMismatch(StringView path, StringView expected, StringView actual);
	
	/// A field the caller demands is absent; fieldName is the JSON name that was looked up.
	case MissingRequiredField(StringView path, StringView fieldName);
	
	/// A string matches no case of the target enum; enumType is the enum that rejected it.
	case InvalidEnumValue(StringView path, StringView enumType);
	
	/// An IJsonConverter refused the value. ReadJson reports no reason, so neither does this.
	case ConverterFailed(StringView path);
	
	/// The reader failed before binding could start; inner is the parsing failure it reported.
	case ParseError(JsonParsingError inner);
	
	public override void ToString(String str)
	{
		switch (this)
		{
		case TypeMismatch(let path, let expected, let actual):
			str.AppendF("Type mismatch at {0}: expected {1}, got {2}", path, expected, actual);
		case MissingRequiredField(let path, let fieldName):
			str.AppendF("Missing required field '{0}' at {1}", fieldName, path);
		case InvalidEnumValue(let path, let enumType):
			str.AppendF("Invalid value for enum {0} at {1}", enumType, path);
		case ConverterFailed(let path):
			str.AppendF("Custom converter failed at {0}", path);
		case ParseError(let inner):
			str.Append("Parse error: ");
			inner.ToString(str);
		}
	}
}
