using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class OrderCustomerAddress
{
	[JsonPropertyName("street")]
	public String Street = new .() ~ delete _;

	[JsonPropertyName("city")]
	public String City = new .() ~ delete _;

}
