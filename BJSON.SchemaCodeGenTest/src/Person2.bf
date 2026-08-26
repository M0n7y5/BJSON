using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Person2
{
	[JsonPropertyName("name")]
	public String Name = new .() ~ delete _;

	[JsonPropertyName("age")]
	public int64 Age;

}
