using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Inheritance : InheritanceBase0
{
	public String Name = new .() ~ delete _;

	public int64 Age;

	[JsonPropertyName("employee_id")]
	public int64 EmployeeId;

	public String Department = new .() ~ delete _;

}
