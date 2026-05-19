using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class OrderCustomer
{
	public String Name = new .() ~ delete _;

	public OrderCustomerAddress Address = new .() ~ delete _;

}
