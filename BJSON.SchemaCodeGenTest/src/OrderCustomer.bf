using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class OrderCustomer
{
	[JsonPropertyName("name")]
	public String Name = new .() ~ delete _;

	[JsonPropertyName("address")]
	public OrderCustomerAddress Address = new .() ~ delete _;

}
