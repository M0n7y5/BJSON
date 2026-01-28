using System;
using BJSON.Enums;

namespace BJSON.Attributes;

/// Specifies how to handle enum or number serialization for a specific field or type.
[AttributeUsage(.Field | .Enum)]
public struct JsonNumberHandlingAttribute : Attribute
{
	public JsonNumberHandling Handling;
	
	public this(JsonNumberHandling handling)
	{
		Handling = handling;
	}
}
