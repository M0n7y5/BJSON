using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Catalog
{
	[JsonRequired]
	public Product PrimaryProduct = new .() ~ delete _;

	public List<String> Tags = new .() ~ DeleteContainerAndItems!(_);

}
