using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class NestedObjectsCustomer
{
	public String Name = new .() ~ delete _;

	public NestedObjectsCustomerAddress Address = new .() ~ delete _;

}
