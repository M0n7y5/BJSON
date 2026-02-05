using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class NestedObjects
{
	[JsonRequired]
	public int64 Id;

	public NestedObjectsCustomer Customer = new .() ~ delete _;

	[JsonRequired]
	public List<NestedObjectsItemsItem> Items = new .() ~ DeleteContainerAndItems!(_);

}
