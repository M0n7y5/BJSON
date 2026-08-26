using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Order
{
	[JsonRequired]
	[JsonPropertyName("id")]
	public int64 Id;

	[JsonPropertyName("customer")]
	public OrderCustomer Customer = new .() ~ delete _;

	[JsonRequired]
	[JsonPropertyName("items")]
	public List<OrderItemsItem> Items = new .() ~ DeleteContainerAndItems!(_);

}
