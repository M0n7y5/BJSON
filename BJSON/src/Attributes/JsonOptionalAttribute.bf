using System;

namespace BJSON.Attributes;

/// Lets the generated JsonDeserialize accept a document without this field: the field is skipped
/// and keeps the value it already holds.
/// This carries weight on a type whose [JsonObject] sets DefaultBehavior = .Required; when the
/// type keeps the default .Optional every field is optional already and the attribute only states
/// the intent.
[AttributeUsage(.Field)]
public struct JsonOptionalAttribute : Attribute
{
}
