using System;
namespace BJSON.Attributes;

[AttributeUsage(.Field)]
public struct JsonPropertyNameAttribute :
	Attribute , this(String name);