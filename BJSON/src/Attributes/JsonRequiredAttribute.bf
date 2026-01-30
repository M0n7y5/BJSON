using System;

namespace BJSON.Attributes;

/// Indicates that a field is required during JSON deserialization.
/// When present, the field must be present in the JSON document.
/// Without this attribute, fields are optional by default.
[AttributeUsage(.Field)]
public struct JsonRequiredAttribute : Attribute
{
}
