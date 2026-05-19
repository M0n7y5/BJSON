using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Address
{
	public String Street = new .() ~ delete _;

	[JsonRequired]
	public String City = new .() ~ delete _;

}
