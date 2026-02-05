using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class InheritanceBase0
{
	public String Name = new .() ~ delete _;

	public int64 Age;

}
