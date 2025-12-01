using System;
using BJSON.Enums;
namespace BJSON.Attributes;

[AttributeUsage(.Field)]
public struct JsonIgnoreAttribute : Attribute
{
	public JsonIgnoreCondition Condition;
}