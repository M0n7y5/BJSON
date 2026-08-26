using System;
using BJSON.Enums;

namespace BJSON.Attributes;

/// Chooses whether an enum is written as its case name or as its underlying integer.
/// Enum fields only: integer and floating point fields are always written as numbers, and reading
/// ignores this attribute entirely, because the generated deserializers accept a case name or a
/// number for every enum field.
/// On a field it overrides the same attribute on the enum type. For enums inside a List, a sized
/// array or a Dictionary value, only the attribute on the enum type is read; putting it on the
/// collection field itself has no effect.
[AttributeUsage(.Field | .Enum)]
public struct JsonNumberHandlingAttribute : Attribute
{
	/// The chosen write form for the annotated enum or enum field.
	public JsonNumberHandling Handling;
	
	public this(JsonNumberHandling handling)
	{
		Handling = handling;
	}
}
