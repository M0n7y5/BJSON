using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Inventory
{
	public List<int64> Ids = new .() ~ delete _;

	public List<InventoryItemsItem> Items = new .() ~ DeleteContainerAndItems!(_);

}
