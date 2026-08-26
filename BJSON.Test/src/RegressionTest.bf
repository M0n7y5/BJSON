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
}
