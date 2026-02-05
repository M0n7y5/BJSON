using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class InheritanceBase1
{
	[JsonPropertyName("employee_id")]
	public int64 EmployeeId;

	public String Department = new .() ~ delete _;

}
