using System;
using BJSON;
using BJSON.Models;
using BJSON.Enums;
using BJSON.Attributes;
using System.IO;

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

class ErrorHandlingTest
{
	[Test(Name = "Error Handling - Parsing Errors")]
	public static void T_ParsingErrors()
	{
		{
			var result = Json.Deserialize("");
			defer result.Dispose();

			if (result case .Err(let err))
			{
				Test.Assert(err case .UnableToRead, "Empty string should return UnableToRead error");
			}
			else
			{
				Test.Assert(false, "Empty string should fail");
			}
		}

		{
			var result = Json.Deserialize("   \n\t  ");
			defer result.Dispose();

			if (result case .Err(let err))
			{
				Test.Assert(err case .UnableToRead, "Whitespace-only should return UnableToRead error");
			}
			else
			{
				Test.Assert(false, "Whitespace-only should fail");
			}
		}

		{
			var result = Json.Deserialize("{\"key\": \"value\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unclosed object should fail");
		}

		{
			var result = Json.Deserialize("[1, 2, 3");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unclosed array should fail");
		}

		{
			var result = Json.Deserialize("{\"key\" \"value\"}");
			defer result.Dispose();

			if (result case .Err(let err))
			{
				Test.Assert(err case .UnexpectedToken, "Missing colon should return UnexpectedToken error");
			}
			else
			{
				Test.Assert(false, "Should have failed");
			}
		}

		{
			var result = Json.Deserialize("{\"key\": \"value\",}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Trailing comma in object should fail");
		}

		{
			var result = Json.Deserialize("[1, 2, 3,]");
			defer result.Dispose();

			Test.Assert(result case .Err, "Trailing comma in array should fail");
		}

		// Test 8: Invalid value - "undefined" is parsed as a number attempt, which fails
		{
			var result = Json.Deserialize("undefined");
			defer result.Dispose();

			if (result case .Err(let err))
			{
				Test.Assert(err case .UnexpectedToken, "Invalid value 'undefined' should return UnexpectedToken error");
			}
			else
			{
				Test.Assert(false, "Should have failed");
			}
		}

		{
			var result = Json.Deserialize("{key: \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unquoted key should fail");
		}

		{
			var result = Json.Deserialize("{'key': 'value'}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Single quotes should fail");
		}

		{
			var result = Json.Deserialize("\"hello\\xworld\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Invalid escape \\x should fail");
		}

		{
			var result = Json.Deserialize("\"hello");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unterminated string should fail");
		}

		{
			var result = Json.Deserialize("\"\\u00\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Invalid unicode escape (too short) should fail");
		}

		{
			var result = Json.Deserialize("\"\\uGGGG\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Non-hex unicode escape should fail");
		}

		{
			let jsonWithControl = scope String();
			jsonWithControl.Append("\"hello");
			jsonWithControl.Append((char8)0x01);
			jsonWithControl.Append("world\"");
			
			var result = Json.Deserialize(jsonWithControl);
			defer result.Dispose();

			Test.Assert(result case .Err, "Control character in string should fail");
		}

		{
			var result = Json.Deserialize("01234");
			defer result.Dispose();

			Test.Assert(result case .Err, "Leading zeros should fail");
		}

		{
			var result = Json.Deserialize("+123");
			defer result.Dispose();

			Test.Assert(result case .Err, "Plus sign prefix should fail");
		}

		// Test 18: Maximum depth exceeded (max is 200)
		{
			let deepJson = scope String();
			for (int i = 0; i < 250; i++)
				deepJson.Append("[");
			deepJson.Append("1");
			for (int i = 0; i < 250; i++)
				deepJson.Append("]");
			
			var result = Json.Deserialize(deepJson);
			defer result.Dispose();

			Test.Assert(result case .Err, "Deep nesting (250 levels) should fail");
		}
	}

	[Test(Name = "Error Handling - Stream Errors")]
	public static void T_StreamErrors()
	{
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize((Stream)null);
			defer result.Dispose();

			Test.Assert(result case .Err(.InputStreamIsNull), "Null stream should return InputStreamIsNull error");
		}

		{
			let emptyStream = scope MemoryStream();
			var result = Json.Deserialize(emptyStream);
			defer result.Dispose();

			if (result case .Err(let err))
			{
				Test.Assert(err case .UnableToRead, "Empty stream should return UnableToRead error");
			}
			else
			{
				Test.Assert(false, "Empty stream should fail");
			}
		}
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

		Test.Assert(Json.Serialize(point, stream) case .Err(.StreamWriteFailed), "a truncated write must report StreamWriteFailed");
	}

	[Test(Name = "Regression: emitted serializer reports a failing stream without the facade")]
	public static void T_EmittedSerializeReportsWriteFailure()
	{
		let point = scope SerializedPoint();
		point.Label.Set("a label long enough to need a second write");

		let stream = scope ShortStream(4);

		Test.Assert(point.JsonSerialize(stream) case .Err(.StreamWriteFailed), "a truncated write must report StreamWriteFailed");
	}
}
