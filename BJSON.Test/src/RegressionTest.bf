using System;
using System.Collections;
using System.IO;
using BJSON;
using BJSON.Models;
using BJSON.Enums;
using BJSON.Attributes;

namespace BJSON.Test;

/// Accepts a fixed number of bytes and fails every write after that,
/// standing in for a full disk or a closed pipe.
class ShortStream : Stream
{
	private int mRemaining;

	public this(int capacity)
	{
		mRemaining = capacity;
	}

	public override int64 Position
	{
		get
		{
			return 0;
		}

		set
		{
		}
	}

	public override int64 Length => 0;

	public override bool CanRead => false;

	public override bool CanWrite => true;

	public override Result<int> TryRead(Span<uint8> data) => .Err;

	public override Result<int> TryWrite(Span<uint8> data)
	{
		if (mRemaining <= 0)
			return .Err;

		let written = Math.Min(data.Length, mRemaining);
		mRemaining -= written;

		return .Ok(written);
	}

	public override Result<void> Close() => .Ok;
}

[JsonObject]
class SerializedPoint
{
	public int X = 1;
	public String Label = new .() ~ delete _;
}

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

class RegressionTest
{
	[Test(Name = "Regression: shortest round-trip for a 17 digit negative double")]
	public static void T_DtoaWorstCaseBuffer()
	{
		let value = -1.2551272886980567e-06;
		var json = JsonNumber(value);
		defer json.Dispose();

		let output = scope String();
		Test.Assert(Json.Serialize(json, output) case .Ok, "serialize must succeed");
		Test.Assert(output == "-0.0000012551272886980567", scope $"got '{output}'");

		let reparsed = Json.Deserialize(output);
		Test.Assert(reparsed case .Ok(let val), "round-trip parse must succeed");
		Test.Assert((double)val == value, scope $"round-trip changed the value: {(double)val}");
	}

	[Test(Name = "Regression: flat document with 200 empty containers parses")]
	public static void T_FlatEmptyContainers()
	{
		let doc = scope String("[");
		for (int i < 200)
		{
			if (i > 0)
				doc.Append(',');
			doc.Append("{}");
		}
		doc.Append(']');

		var result = Json.Deserialize(doc);
		defer result.Dispose();

		Test.Assert(result case .Ok, "200 empty siblings must parse");
	}

	[Test(Name = "Regression: serialize appends to a non empty buffer")]
	public static void T_SerializeIntoUsedBuffer()
	{
		var json = JsonObject();
		json.Add("a", JsonNumber((int64)1));
		defer json.Dispose();

		let output = scope String("prefix:");
		Test.Assert(Json.Serialize(json, output) case .Ok, "serialize must succeed");
		Test.Assert(output == "prefix:{\"a\":1}", scope $"got '{output}'");
	}

	[Test(Name = "Regression: parse error text names the expected token")]
	public static void T_ErrorPayloadOutlivesReader()
	{
		var result = Json.Deserialize("{\"key\" \"value\"}");
		defer result.Dispose();

		Test.Assert(result case .Err(let err), "missing colon must fail");

		let text = scope String();
		err.ToString(text);
		Test.Assert(text.Contains(':'), scope $"error text lost the expected token: '{text}'");
	}

	[Test(Name = "Regression: object indexer copies the key it stores")]
	public static void T_IndexerKeyOwnership()
	{
		var json = JsonObject();
		json[scope String("a")] = JsonNumber((int64)1);

		let output = scope String();
		Test.Assert(Json.Serialize(json, output) case .Ok, "serialize must succeed");
		Test.Assert(output == "{\"a\":1}", scope $"got '{output}'");

		json.Dispose();
	}

	[Test(Name = "Regression: DOM serialize reports a failing stream")]
	public static void T_DomSerializeReportsWriteFailure()
	{
		var json = JsonObject();
		json.Add("key", JsonString("a value long enough to need a second write"));
		defer json.Dispose();

		let stream = scope ShortStream(4);

		Test.Assert(Json.Serialize(json, stream) case .Err, "a truncated write must not report success");
	}

	[Test(Name = "Regression: typed serialize reports a failing stream")]
	public static void T_TypedSerializeReportsWriteFailure()
	{
		let point = scope SerializedPoint();
		point.Label.Set("a label long enough to need a second write");

		let stream = scope ShortStream(4);

		Test.Assert(Json.Serialize(point, stream) case .Err, "a truncated write must not report success");
	}

	[Test(Name = "Regression: emitted serializer reports a failing stream without the facade")]
	public static void T_EmittedSerializeReportsWriteFailure()
	{
		let point = scope SerializedPoint();
		point.Label.Set("a label long enough to need a second write");

		let stream = scope ShortStream(4);

		Test.Assert(point.JsonSerialize(stream) case .Err, "a truncated write must not report success");
	}

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

	[Test(Name = "Regression: writing a deeply nested tree reports the depth cap")]
	public static void T_WriterDepthCap()
	{
		var root = JsonArray();
		defer root.Dispose();

		var current = root;
		for (int i < 250)
		{
			var child = JsonArray();
			current.Add(child);
			current = child;
		}

		let output = scope String();
		Test.Assert(Json.Serialize(root, output) case .Err, "a tree deeper than the cap must not overflow the stack");
	}

	[Test(Name = "Regression: typed accessors reject the wrong type")]
	public static void T_TypedAccessors()
	{
		var result = Json.Deserialize("{\"text\":\"hello\",\"flag\":true,\"count\":7}");
		defer result.Dispose();

		Test.Assert(result case .Ok(let doc), "parse must succeed");

		var root = doc;
		var text = root.TryGetRef("text").Value;
		Test.Assert(text.AsString() case .Ok(let str), "text must read as a string");
		Test.Assert(str == "hello", scope $"got '{str}'");
		Test.Assert(text.AsNumber() case .Err, "a string must not read as a number");

		var flag = root.TryGetRef("flag").Value;
		Test.Assert(flag.AsBool() case .Ok(let boolean) && boolean, "flag must read as true");
		Test.Assert(flag.AsString() case .Err, "a bool must not read as a string");

		var count = root.TryGetRef("count").Value;
		Test.Assert(count.AsNumber() case .Ok(let number) && (number == 7), "count must read as 7");
		Test.Assert(count.AsBool() case .Err, "a number must not read as a bool");
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
