using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class NestedObjectsItemsItem
{
	[JsonPropertyName("product_id")]
	public int64 ProductId;

	public int64 Quantity;

}
