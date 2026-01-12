using System;
namespace BJSON.Attributes;

/// Attribute that forces a non-public field to be included in JSON serialization.
[AttributeUsage(.Field)]
public struct JsonIncludeAttribute : Attribute
{
	public this()
	{
	}
}