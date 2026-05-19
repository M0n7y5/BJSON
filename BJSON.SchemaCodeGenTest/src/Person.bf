using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Person
{
	[JsonRequired]
	public String Name = new .() ~ delete _;

	public int64 Age;

	[JsonRequired]
	public Address Address = new .() ~ delete _;

}
