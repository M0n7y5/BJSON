using System;
using BJSON.Models;
using System.IO;
using BJSON.Attributes;

namespace BJSON.Test;

/// Two-field fixture for the typed writer: one string field, one integer field.
[JsonObject]
class StreamPacket
{
	public String Label = new .() ~ delete _;
	public int Size;
}

/// Tests for stream-based serialization and deserialization:
/// - Basic stream serialization
/// - Stream with options (pretty print)
/// - Round-trip via streams
/// - Large JSON handling
class StreamTest
{
	[Test(Name = "Stream Serialization")]
	public static void T_StreamSerialization()
	{
		{
			let json = JsonObject() { ("name", "test"), ("value", 42) };
			defer json.Dispose();

			let stream = scope MemoryStream();
			let result = Json.Serialize(json, stream);
			
			Test.Assert(result case .Ok, "Stream serialization should succeed");
			
			stream.Position = 0;
			let reader = scope StreamReader(stream);
			let output = reader.ReadToEnd(.. scope .());
			
			Test.Assert(output == "{\"name\":\"test\",\"value\":42}", 
				scope $"Output mismatch. Got: {output}");
		}

		{
			let json = JsonObject() { ("key", "value") };
			defer json.Dispose();

			let stream = scope MemoryStream();
			var options = JsonWriterOptions() { Indented = true };
			let result = Json.Serialize(json, stream, options);
			
			Test.Assert(result case .Ok, "Pretty-print stream serialization should succeed");
			
			stream.Position = 0;
			let reader = scope StreamReader(stream);
			let output = reader.ReadToEnd(.. scope .());
			
			Test.Assert(output.Contains("\n"), "Pretty output should contain newlines");
			Test.Assert(output.Contains("  "), "Pretty output should contain indentation");
		}

		{
			let original = JsonObject() 
			{ 
				("string", "hello"),
				("number", 3.14),
				("bool", true),
				("null", JsonNull()),
				("array", JsonArray() { JsonNumber((int64)1), JsonNumber((int64)2) })
			};
			defer original.Dispose();

			let stream = scope MemoryStream();
			let serResult = Json.Serialize(original, stream);
			Test.Assert(serResult case .Ok, "Serialization should succeed");

			stream.Position = 0;
			var deserResult = Json.Deserialize(stream);
			defer deserResult.Dispose();
			
			Test.Assert(deserResult case .Ok, "Deserialization should succeed");
			if (deserResult case .Ok(let parsed))
			{
				StringView str = parsed["string"];
				Test.Assert(str == "hello", scope $"string mismatch. Got: {str}");
				
				bool boolVal = parsed["bool"];
				Test.Assert(boolVal == true, "bool mismatch");
				
				Test.Assert(parsed["null"].IsNull(), "null mismatch");
				
				let arr = parsed["array"].AsArray().Value;
				Test.Assert(arr.Count == 2, scope $"array count mismatch. Got: {arr.Count}");
			}
		}

		{
			var json = JsonArray();
			for (int i = 0; i < 100; i++)
			{
				json.Add(JsonObject() { ("index", i), ("data", "item") });
			}
			defer json.Dispose();

			let stream = scope MemoryStream();
			let result = Json.Serialize(json, stream);
			
			Test.Assert(result case .Ok, "Large JSON stream serialization should succeed");
			Test.Assert(stream.Length > 0, "Stream should have content");
		}
	}

	[Test(Name = "Stream Serialization: Typed Writer Options")]
	public static void T_TypedSerializationWithOptions()
	{
		let packet = scope StreamPacket();
		packet.Label.Set("packet");
		packet.Size = 3;

		let expected = "{\n  \"Label\": \"packet\",\n  \"Size\": 3\n}";
		var options = JsonWriterOptions() { Indented = true };

		let text = scope String();
		Test.Assert(Json.Serialize(packet, text, options) case .Ok, "Indented serialization into a String should succeed");
		Test.Assert(text == expected, scope $"String output mismatch. Got: {text}");

		let stream = scope MemoryStream();
		Test.Assert(Json.Serialize(packet, stream, options) case .Ok, "Indented serialization into a Stream should succeed");

		stream.Position = 0;
		let reader = scope StreamReader(stream);
		let output = reader.ReadToEnd(.. scope .());
		Test.Assert(output == expected, scope $"Stream output mismatch. Got: {output}");
	}
}
