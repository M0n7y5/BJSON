using System;
using System.Collections;
using System.IO;
using BJSON;
using BJSON.Models;
using BJSON.Enums;
using BJSON.Attributes;

namespace BJSON.Test;

[JsonObject]
class NullableHolder
{
	public String Text = null;
	public List<int> Numbers = null;
	public SerializedPoint Point = null;

	[JsonIgnore(Condition = .WhenWritingNull)]
	public String Skipped = null;
}

[JsonObject]
class AwkwardNames
{
	[JsonPropertyName("quote\"inside")]
	public int First = 1;

	[JsonPropertyName("back\\slash")]
	public int Second = 2;
}

[JsonObject]
class GeneratedBase
{
	[JsonRequired]
	[JsonPropertyName("name")]
	public String Name = new .() ~ delete _;

	[JsonPropertyName("age")]
	public int64 Age;
}

[JsonObject]
class GeneratedDerived : GeneratedBase
{
	[JsonRequired]
	[JsonPropertyName("employee_id")]
	public int64 EmployeeId;
}

/// Regressions in the comptime [JsonObject] emitters.
class RegressionTest
{
	[Test(Name = "Regression: null reference fields serialize as null")]
	public static void T_NullReferenceFields()
	{
		let holder = scope NullableHolder();

		let output = scope String();
		Test.Assert(Json.Serialize(holder, output) case .Ok, "a null field must not fail serialization");
		Test.Assert(output == "{\"Text\":null,\"Numbers\":null,\"Point\":null}", scope $"got '{output}'");

		let restored = scope NullableHolder();
		var stream = scope StringStream(output, .Reference);
		Test.Assert(Json.Deserialize<NullableHolder>(stream, restored) case .Ok, "a null valued document must deserialize");
	}

	[Test(Name = "Regression: property names with quotes and backslashes round-trip")]
	public static void T_AwkwardPropertyNames()
	{
		let names = scope AwkwardNames();

		let output = scope String();
		Test.Assert(Json.Serialize(names, output) case .Ok, "serialize must succeed");
		Test.Assert(output == "{\"quote\\\"inside\":1,\"back\\\\slash\":2}", scope $"got '{output}'");

		var parsed = Json.Deserialize(output);
		defer parsed.Dispose();
		Test.Assert(parsed case .Ok(let doc), "the emitted keys must be valid JSON");

		var root = doc;
		Test.Assert(root.TryGet("quote\"inside") case .Ok, "the quoted key must survive escaping");

		let restored = scope AwkwardNames();
		restored.First = 0;
		var stream = scope StringStream(output, .Reference);
		Test.Assert(Json.Deserialize<AwkwardNames>(stream, restored) case .Ok, "the emitted keys must read back");
		Test.Assert(restored.First == 1, scope $"expected 1 got {restored.First}");
	}

	[Test(Name = "Regression: inherited fields appear once and required base fields are enforced")]
	public static void T_GeneratedInheritanceShape()
	{
		let derived = scope GeneratedDerived();
		derived.Name.Set("Ada");
		derived.Age = 36;
		derived.EmployeeId = 7;

		let output = scope String();
		Test.Assert(Json.Serialize(derived, output) case .Ok, "serialize must succeed");
		let firstName = output.IndexOf("\"name\"");
		Test.Assert(firstName >= 0, scope $"name missing: '{output}'");
		Test.Assert(output.IndexOf("\"name\"", firstName + 1) == -1, scope $"name emitted twice: '{output}'");

		let restored = scope GeneratedDerived();
		var stream = scope StringStream(output, .Reference);
		Test.Assert(Json.Deserialize<GeneratedDerived>(stream, restored) case .Ok, "round-trip must succeed");
		Test.Assert(restored.Name == "Ada", scope $"got '{restored.Name}'");
		Test.Assert(restored.EmployeeId == 7, scope $"got {restored.EmployeeId}");

		let missingBase = scope GeneratedDerived();
		var missingStream = scope StringStream("{\"employee_id\":7}", .Reference);
		Test.Assert(Json.Deserialize<GeneratedDerived>(missingStream, missingBase) case .Err, "a missing required base field must fail");
	}
}
