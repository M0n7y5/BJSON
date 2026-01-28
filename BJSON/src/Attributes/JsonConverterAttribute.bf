using System;

namespace BJSON.Attributes;

/// Specifies a custom converter for a field or type.
/// The converter type must implement IJsonConverter<T>.
[AttributeUsage(.Field | .Class | .Struct)]
public struct JsonConverterAttribute : Attribute
{
	/// The converter type. Must implement IJsonConverter<T>.
	public Type ConverterType;
	
	public this(Type converterType)
	{
		ConverterType = converterType;
	}
}
