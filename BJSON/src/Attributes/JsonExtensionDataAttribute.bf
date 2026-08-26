using System;
namespace BJSON.Attributes;

/// Makes one Dictionary<String, V> field carry the properties no other field claims: the
/// generated reader puts every JSON property that matches no field name into it, and the
/// generated writer emits one property per entry once the declared fields are written.
/// The field itself has no property name, so a JSON property named after it is unknown data
/// like any other, and an entry keyed after a declared property is dropped on write, because
/// the field already wrote that property.
/// A type carries at most one such field, and its key type must be String, since that is the
/// only key type a JSON object can round trip. Both rules abort the build when broken.
[AttributeUsage(.Field)]
public struct JsonExtensionDataAttribute : Attribute
{
}
