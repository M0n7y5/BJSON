using System;

namespace BJSON.Attributes;

/// Indicates that a field is optional during JSON deserialization.
/// When present, the field can be missing from the JSON document.
/// This is the default behavior, but can be used for explicit clarity.
[AttributeUsage(.Field)]
public struct JsonOptionalAttribute : Attribute
{
}
