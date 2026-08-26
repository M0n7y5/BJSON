using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class OrderItemsItem
{
	[JsonPropertyName("product_id")]
	public int64 ProductId;

	[JsonPropertyName("quantity")]
	public int64 Quantity;

}
