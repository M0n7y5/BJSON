using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Employee : EmployeeBase0
{
	[JsonRequired]
	[JsonPropertyName("employee_id")]
	public int64 EmployeeId;

	[JsonPropertyName("department")]
	public String Department = new .() ~ delete _;

}
