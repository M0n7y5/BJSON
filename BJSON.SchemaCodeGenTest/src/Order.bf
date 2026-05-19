using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Order
{
	[JsonRequired]
	public int64 Id;

	public OrderCustomer Customer = new .() ~ delete _;

	[JsonRequired]
	public List<OrderItemsItem> Items = new .() ~ DeleteContainerAndItems!(_);

}
