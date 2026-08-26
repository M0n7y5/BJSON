using System;
namespace BJSON.Attributes;

/// Renames one field in JSON: the generated writer emits name as the key and the generated reader
/// looks the value up under name instead of under the Beef field name.
/// The name is baked into the emitted source at comptime with JSON escaping and Beef string
/// escaping applied, so a quote or a backslash in it stays intact, while a control character
/// below 0x20 aborts the build.
/// Nothing checks that two fields of a type avoid claiming the same name.
[AttributeUsage(.Field)]
public struct JsonPropertyNameAttribute :
	Attribute , this(String name);