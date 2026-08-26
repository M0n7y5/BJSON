using System;

namespace BJSON.Attributes;

/// Routes a value through custom code instead of the generated field handling. The converter must
/// implement IJsonConverter<T> for the converted type and expose a parameterless constructor: the
/// emitters allocate one converter per value with new and delete it right after.
/// On a field the converter handles that field on both sides, and on a collection field it takes
/// the whole collection, before any element handling.
/// On a class or struct the converter handles every value of that type either emitter meets: a
/// plain field of that type, a List element, a sized array element and a Dictionary value, in both
/// directions. It is what lets a type without [JsonObject] appear in a serialized type.
/// The attribute on the field wins over the attribute on the field's type.
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
