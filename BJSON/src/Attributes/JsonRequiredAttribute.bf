using System;

namespace BJSON.Attributes;

/// Demands the field in the document: the generated JsonDeserialize returns Err as soon as the key
/// is absent, instead of leaving the field at its current value.
/// This carries weight on a type whose [JsonObject] keeps the default DefaultBehavior of .Optional;
/// with DefaultBehavior = .Required every field is required already and [JsonOptional] is the way
/// to exempt one.
[AttributeUsage(.Field)]
public struct JsonRequiredAttribute : Attribute
{
}
