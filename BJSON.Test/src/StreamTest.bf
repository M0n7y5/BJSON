using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;

namespace BJSON.Test;

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
		Debug.WriteLine("Stream Serialization tests ...");

		// Test 1: Basic stream serialization
		{
			let json = JsonObject() { ("name", "test"), ("value", 42) };
			defer json.Dispose();

			let stream = scope MemoryStream();
			let result = Json.Serialize(json, stream);
			
			Test.Assert(result case .Ok, "Stream serialization should succeed");
			
			// Read back and verify
			stream.Position = 0;
			let reader = scope StreamReader(stream);
			let output = reader.ReadToEnd(.. scope .());
			
			Test.Assert(output == "{\"name\":\"test\",\"value\":42}", 
				scope $"Output mismatch. Got: {output}");
			
			Debug.WriteLine("  Test 1 (basic stream): PASSED");
		}

		// Test 2: Stream serialization with options (pretty print)
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
			
			Debug.WriteLine("  Test 2 (stream with options): PASSED");
		}

		// Test 3: Round-trip stream serialization/deserialization
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

			// Serialize to stream
			let stream = scope MemoryStream();
			let serResult = Json.Serialize(original, stream);
			Test.Assert(serResult case .Ok, "Serialization should succeed");

			// Deserialize from stream
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
			
			Debug.WriteLine("  Test 3 (round-trip): PASSED");
		}

		// Test 4: Large JSON to stream
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
			
			Debug.WriteLine(scope $"  Test 4 (large JSON): PASSED - wrote {stream.Length} bytes");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
