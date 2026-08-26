using System;
namespace BJSON.Attributes;

/// Opts a non-public instance field into the generated serializer and deserializer, which
/// otherwise emit public fields only.
/// Static fields are never emitted, whatever attributes they carry.
[AttributeUsage(.Field)]
public struct JsonIncludeAttribute : Attribute
{
	public this()
	{
	}
}