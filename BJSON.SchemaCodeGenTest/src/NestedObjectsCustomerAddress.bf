using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class NestedObjectsCustomerAddress
{
	public String Street = new .() ~ delete _;

	public String City = new .() ~ delete _;

}
