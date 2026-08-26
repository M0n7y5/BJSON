using System;
using BJSON.Models;
using System.IO;

namespace BJSON.Test;

class SerializationTest
{
	[Test(Name = "Serialization - Basic tests")]
	public static void T_SerializationBasic()
	{
		{
			let json = JsonNull();
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of null should succeed");
			Test.Assert(output == "null", scope $"Expected 'null', got '{output}'");
		}

		{
			let json = JsonBool(true);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of true should succeed");
			Test.Assert(output == "true", scope $"Expected 'true', got '{output}'");
		}

		{
			let json = JsonBool(false);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of false should succeed");
			Test.Assert(output == "false", scope $"Expected 'false', got '{output}'");
		}

		{
			let json = JsonNumber((int64)42);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of integer should succeed");
			Test.Assert(output == "42", scope $"Expected '42', got '{output}'");
		}

		{
			let json = JsonNumber((int64)-123);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of negative integer should succeed");
			Test.Assert(output == "-123", scope $"Expected '-123', got '{output}'");
		}

		{
			let json = JsonNumber((uint64)999);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of unsigned integer should succeed");
			Test.Assert(output == "999", scope $"Expected '999', got '{output}'");
		}

		{
			let json = JsonNumber(3.14);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of float should succeed");
		}

		{
			let json = JsonObject()
				{
					("firstName", "John"),
					("lastName", "Smith"),
					("isAlive", true),
					("age", 27),
					("phoneNumbers", JsonArray()
						{
							JsonObject()
								{
									("type", "home"),
									("number", "212 555-1234")
								},
							JsonObject()
								{
									("type", "office"),
									("number", "646 555-4567")
								}
						})
				};
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Complex nested structure should serialize without error");
			
			// In the broken version, only first key would be indented, others would be at column 0
			Test.Assert(output.Contains("\n  \"firstName\""), "firstName should be indented");
			Test.Assert(output.Contains("\n  \"lastName\""), "lastName should be indented");
			Test.Assert(output.Contains("\n  \"isAlive\""), "isAlive should be indented");
			Test.Assert(output.Contains("\n  \"age\""), "age should be indented");
			Test.Assert(output.Contains("\n  \"phoneNumbers\""), "phoneNumbers should be indented");
			Test.Assert(output.Contains("\n      \"type\""), "type field should be double-indented");
			Test.Assert(output.Contains("\n      \"number\""), "number field should be double-indented");
		}
	}

	[Test(Name = "Serialization - Pretty-print tests")]
	public static void T_SerializationPrettyPrint()
	{
		{
			var json = JsonObject();
			json.Add("name", JsonString("test"));
			json.Add("value", JsonNumber((int64)42));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Pretty-print serialization should succeed");
			Test.Assert(output.Contains("\n"), "Output should contain newlines");
			Test.Assert(output.Contains("  "), "Output should contain indentation");
		}

		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			json.Add(JsonNumber((int64)2));
			json.Add(JsonNumber((int64)3));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Pretty-print array serialization should succeed");
			Test.Assert(output.Contains("\n"), "Output should contain newlines");
		}

		{
			var json = JsonObject();
			json.Add("key", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true, IndentString = "\t" };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Tab-indented serialization should succeed");
			Test.Assert(output.Contains("\t"), "Output should contain tabs");
		}

		{
			var json = JsonObject();
			json.Add("key", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true, IndentString = "    " };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "4-space indented serialization should succeed");
			Test.Assert(output.Contains("    "), "Output should contain 4-space indentation");
		}

		{
			var json = JsonObject();
			json.Add("key", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true, NewLine = "\r\n" };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "CRLF serialization should succeed");
			Test.Assert(output.Contains("\r\n"), "Output should contain CRLF");
		}

		{
			var innerObj = JsonObject();
			innerObj.Add("nested", JsonString("data"));

			var innerArr = JsonArray();
			innerArr.Add(JsonNumber((int64)1));
			innerArr.Add(JsonNumber((int64)2));

			var json = JsonObject();
			json.Add("object", innerObj);
			json.Add("array", innerArr);
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Nested pretty-print should succeed");
		}

		{
			var json = JsonObject();
			json.Add("key", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = false };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Non-indented serialization should succeed");
			Test.Assert(!output.Contains("\n"), "Minified output should not contain newlines");
			Test.Assert(output == "{\"key\":\"value\"}", scope $"Minified output mismatch, got '{output}'");
		}

		{
			let json = JsonObject()
				{
					("firstName", "John"),
					("lastName", "Smith"),
					("isAlive", true),
					("age", 27),
					("phoneNumbers", JsonArray()
						{
							JsonObject()
								{
									("type", "home"),
									("number", "212 555-1234")
								},
							JsonObject()
								{
									("type", "office"),
									("number", "646 555-4567")
								}
						})
				};
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Complex nested structure should serialize without error");
			
			// In the broken version, only first key would be indented, others would be at column 0
			Test.Assert(output.Contains("\n  \"firstName\""), "firstName should be indented");
			Test.Assert(output.Contains("\n  \"lastName\""), "lastName should be indented");
			Test.Assert(output.Contains("\n  \"isAlive\""), "isAlive should be indented");
			Test.Assert(output.Contains("\n  \"age\""), "age should be indented");
			Test.Assert(output.Contains("\n  \"phoneNumbers\""), "phoneNumbers should be indented");
			Test.Assert(output.Contains("\n      \"type\""), "type field should be double-indented");
			Test.Assert(output.Contains("\n      \"number\""), "number field should be double-indented");
		}
	}

	[Test(Name = "Serialization - Round-trip tests")]
	public static void T_SerializationRoundTrip()
	{
		static void TestRoundTrip(StringView originalJson, StringView testName)
		{
			var result1 = Json.Deserialize(originalJson);
			defer result1.Dispose();

			switch (result1)
			{
			case .Ok(let json1):
				let serialized = scope String();
				let result2 = Json.Serialize(json1, serialized);

				if (result2 case .Err(let serErr))
				{
					Test.Assert(false, scope $"Round-trip serialization failed for {testName}! {serErr}");
					return;
				}

				let result3 = Json.Deserialize(serialized);
				defer result3.Dispose();

				switch (result3)
				{
				case .Ok(let json2):
					let serialized2 = scope String();
					Json.Serialize(json2, serialized2);

					Test.Assert(serialized == serialized2, scope $"Round-trip mismatch for {testName}! First: {serialized}, Second: {serialized2}");
				case .Err(let parseErr):
					Test.Assert(false, scope $"Round-trip re-parse failed for {testName}: {parseErr}");
				}
			case .Err(let err):
				Test.Assert(false, scope $"Round-trip initial parse failed for {testName}: {err}");
			}
		}

		TestRoundTrip("null", "null");
		TestRoundTrip("true", "true");
		TestRoundTrip("false", "false");
		TestRoundTrip("42", "integer");
		TestRoundTrip("-123", "negative int");
		TestRoundTrip("3.14", "float");
		TestRoundTrip("\"hello\"", "string");
		TestRoundTrip("{}", "empty object");
		TestRoundTrip("[]", "empty array");
		TestRoundTrip("[1,2,3]", "simple array");
		TestRoundTrip("{\"key\":\"value\"}", "simple object");
		TestRoundTrip("[null,true,false,42,\"text\"]", "mixed array");
		TestRoundTrip("{\"nested\":{\"inner\":\"value\"}}", "nested object");
		TestRoundTrip("[[1,2],[3,4]]", "nested arrays");
		TestRoundTrip("{\"arr\":[1,2],\"obj\":{\"x\":1}}", "complex structure");

		TestRoundTrip("9223372036854775807", "max int64");
		TestRoundTrip("-9223372036854775808", "min int64");
		TestRoundTrip("18446744073709551615", "max uint64");
	}

	[Test(Name = "Serialization - Error handling tests")]
	public static void T_SerializationErrors()
	{
		{
			let json = JsonNumber(Double.NaN);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.NaNNotAllowed), "NaN serialization should return NaNNotAllowed error");
		}

		{
			let json = JsonNumber(Double.PositiveInfinity);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.InfinityNotAllowed), "Positive Infinity should return InfinityNotAllowed error");
		}

		{
			let json = JsonNumber(Double.NegativeInfinity);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.InfinityNotAllowed), "Negative Infinity should return InfinityNotAllowed error");
		}
	}

	[Test(Name = "Serialization - Escape character tests")]
	public static void T_SerializationEscapeCharacters()
	{
		{
			var json = JsonString("hello\nworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with newline should succeed");
			Test.Assert(output == "\"hello\\nworld\"", scope $"Expected '\"hello\\nworld\"', got '{output}'");
		}

		{
			var json = JsonString("hello\tworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with tab should succeed");
			Test.Assert(output == "\"hello\\tworld\"", scope $"Expected '\"hello\\tworld\"', got '{output}'");
		}

		{
			var json = JsonString("hello\rworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with carriage return should succeed");
			Test.Assert(output == "\"hello\\rworld\"", scope $"Expected '\"hello\\rworld\"', got '{output}'");
		}

		{
			var json = JsonString("say \"hello\"");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with quotes should succeed");
			Test.Assert(output == "\"say \\\"hello\\\"\"", scope $"Expected '\"say \\\"hello\\\"\"', got '{output}'");
		}

		{
			var json = JsonString("path\\to\\file");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with backslashes should succeed");
			Test.Assert(output == "\"path\\\\to\\\\file\"", scope $"Expected '\"path\\\\to\\\\file\"', got '{output}'");
		}

		{
			var json = JsonString("hello\bworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with backspace should succeed");
			Test.Assert(output == "\"hello\\bworld\"", scope $"Expected '\"hello\\bworld\"', got '{output}'");
		}

		{
			var json = JsonString("hello\fworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with form feed should succeed");
			Test.Assert(output == "\"hello\\fworld\"", scope $"Expected '\"hello\\fworld\"', got '{output}'");
		}

		{
			var json = JsonString("line1\nline2\ttab\r\n");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with multiple escapes should succeed");
			Test.Assert(output == "\"line1\\nline2\\ttab\\r\\n\"", scope $"Expected '\"line1\\nline2\\ttab\\r\\n\"', got '{output}'");
		}

		{
			let inputJson = "\"hello\\nworld\\t!\"";
			var result1 = Json.Deserialize(inputJson);
			defer result1.Dispose();

			switch (result1)
			{
			case .Ok(let parsed):
				let output = scope String();
				let result2 = Json.Serialize(parsed, output);

				Test.Assert(result2 case .Ok, "Round-trip serialization should succeed");
				Test.Assert(output == inputJson, scope $"Round-trip mismatch! Expected: {inputJson}, Got: {output}");
			case .Err(let err):
				Test.Assert(false, scope $"Round-trip parse failed: {err}");
			}
		}

		{
			let inputJson = "\"\\\"\\\\\\b\\f\\n\\r\\t\"";
			var result1 = Json.Deserialize(inputJson);
			defer result1.Dispose();

			switch (result1)
			{
			case .Ok(let parsed):
				let output = scope String();
				let result2 = Json.Serialize(parsed, output);

				Test.Assert(result2 case .Ok, "Round-trip with all escapes should succeed");
				Test.Assert(output == inputJson, scope $"Round-trip mismatch! Expected: {inputJson}, Got: {output}");
			case .Err(let err):
				Test.Assert(false, scope $"Round-trip parse failed: {err}");
			}
		}

		{
			var json = JsonString(scope String()..Append('\0'));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of NUL character should succeed");
			Test.Assert(output == "\"\\u0000\"", scope $"Expected '\"\\u0000\"', got '{output}'");
		}

		{
			var json = JsonString(scope String()..Append((char8)0x1F));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of control char 0x1F should succeed");
			Test.Assert(output == "\"\\u001f\"", scope $"Expected '\"\\u001f\"', got '{output}'");
		}
	}

	[Test(Name = "Object Key Escaping")]
	public static void T_ObjectKeyEscaping()
	{
		{
			var json = JsonObject();
			json.Add("key\"with\"quotes", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with quotes should succeed");
			// The key should be escaped: "key\"with\"quotes"
			Test.Assert(output.Contains("\"key\\\"with\\\"quotes\""), 
				scope $"Key with quotes should be escaped. Got: {output}");

			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		{
			var json = JsonObject();
			json.Add("path\\to\\file", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with backslash should succeed");
			// The key should be escaped: "path\\to\\file"
			Test.Assert(output.Contains("\"path\\\\to\\\\file\""), 
				scope $"Key with backslash should be escaped. Got: {output}");

			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		{
			var json = JsonObject();
			json.Add("line1\nline2", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with newline should succeed");
			// The key should be escaped: "line1\nline2"
			Test.Assert(output.Contains("\"line1\\nline2\""), 
				scope $"Key with newline should be escaped. Got: {output}");

			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		{
			var json = JsonObject();
			json.Add("col1\tcol2", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with tab should succeed");
			Test.Assert(output.Contains("\"col1\\tcol2\""), 
				scope $"Key with tab should be escaped. Got: {output}");

			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		{
			var json = JsonObject();
			json.Add(scope String()..Append("key")..Append('\0')..Append("end"), JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with NUL should succeed");
			Test.Assert(output.Contains("\\u0000"), 
				scope $"Key with NUL should be escaped as \\u0000. Got: {output}");

			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		{
			var json = JsonObject();
			json.Add("\"quoted\"\nand\\slashed", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with multiple escapes should succeed");

			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
			
			if (parseResult case .Ok(let parsed))
			{
				let obj = parsed.AsObject().Value;
				Test.Assert(obj.Count == 1, "Should have exactly one key");
				for (let item in obj)
				{
					Test.Assert(item.key == "\"quoted\"\nand\\slashed", 
						scope $"Key should round-trip correctly. Got: {item.key}");
				}
			}
		}
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
}
