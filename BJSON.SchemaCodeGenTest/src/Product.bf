using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Product
{
	[JsonRequired]
	public String Sku = new .() ~ delete _;

	public double Price;

}
