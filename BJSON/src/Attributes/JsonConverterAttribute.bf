using System;

namespace BJSON.Attributes;

/// Routes a value through custom code instead of the generated field handling. The converter must
/// implement IJsonConverter<T> for the converted type and expose a parameterless constructor: the
/// emitters allocate one converter per value with new and delete it right after.
/// On a field the converter handles that field on both sides, and on a collection field it takes
/// the whole collection, before any element handling.
/// On a class or struct the converter is only picked up for collection members of that type:
/// writing uses it for List elements, sized array elements and Dictionary values, reading for List
/// elements and Dictionary values. A field whose own type carries the attribute still goes down the
/// [JsonObject] path, so converting a plain field takes the attribute on the field.
[AttributeUsage(.Field | .Class | .Struct)]
public struct JsonConverterAttribute : Attribute
{
	/// The converter type, instantiated once per converted value. Must implement IJsonConverter<T>.
	public Type ConverterType;
	
	public this(Type converterType)
	{
		ConverterType = converterType;
	}
}
