using System;
using BJSON.Enums;
namespace BJSON.Attributes;

/// Skips a field in the code [JsonObject] generates, under the condition held in Condition.
/// The struct declares no constructor, so a bare [JsonIgnore] leaves Condition at its zero value,
/// JsonIgnoreCondition.Never, which skips nothing at all: dropping a field takes
/// [JsonIgnore(Condition = .Always)].
/// [JsonIgnore(Condition = .WhenWritingNull)] guards Nullable<T> fields and reference fields
/// alike, and only on the write side; the generated JsonDeserialize still fills the field.
[AttributeUsage(.Field)]
public struct JsonIgnoreAttribute : Attribute
{
	/// When to skip the field. Stays at Never unless the attribute sets it.
	public JsonIgnoreCondition Condition;
}