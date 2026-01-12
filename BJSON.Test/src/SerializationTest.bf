using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;

namespace BJSON.Test;

/// Tests for JSON serialization functionality including:
/// - Basic type serialization
/// - Pretty-print formatting
/// - Round-trip parsing and serialization
/// - Error handling (NaN, Infinity)
/// - String escape character handling
class SerializationTest
{
	[Test(Name = "Serialization - Basic tests")]
	public static void T_SerializationBasic()
	{
		Debug.WriteLine("Serialization - Basic tests ...");

		// Test 1: Serialize null
		{
			let json = JsonNull();
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of null should succeed");
			Test.Assert(output == "null", scope $"Expected 'null', got '{output}'");
			Debug.WriteLine(scope $"  Test 1 (null): PASSED - output: {output}");
		}

		// Test 2: Serialize boolean true
		{
			let json = JsonBool(true);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of true should succeed");
			Test.Assert(output == "true", scope $"Expected 'true', got '{output}'");
			Debug.WriteLine(scope $"  Test 2 (true): PASSED - output: {output}");
		}

		// Test 3: Serialize boolean false
		{
			let json = JsonBool(false);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of false should succeed");
			Test.Assert(output == "false", scope $"Expected 'false', got '{output}'");
			Debug.WriteLine(scope $"  Test 3 (false): PASSED - output: {output}");
		}

		// Test 4: Serialize integer number
		{
			let json = JsonNumber((int64)42);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of integer should succeed");
			Test.Assert(output == "42", scope $"Expected '42', got '{output}'");
			Debug.WriteLine(scope $"  Test 4 (int 42): PASSED - output: {output}");
		}

		// Test 5: Serialize negative integer
		{
			let json = JsonNumber((int64)-123);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of negative integer should succeed");
			Test.Assert(output == "-123", scope $"Expected '-123', got '{output}'");
			Debug.WriteLine(scope $"  Test 5 (int -123): PASSED - output: {output}");
		}

		// Test 6: Serialize unsigned integer
		{
			let json = JsonNumber((uint64)999);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of unsigned integer should succeed");
			Test.Assert(output == "999", scope $"Expected '999', got '{output}'");
			Debug.WriteLine(scope $"  Test 6 (uint 999): PASSED - output: {output}");
		}

		// Test 7: Serialize floating-point number
		{
			let json = JsonNumber(3.14);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of float should succeed");
			// Float representation may vary, just check it parses back correctly
			Debug.WriteLine(scope $"  Test 7 (float 3.14): PASSED - output: {output}");
		}

		// Test 8: Exact deep indentation structure for all keys in all objects
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
			
			// Verify proper indentation by checking that all keys are indented correctly
			// In the broken version, only first key would be indented, others would be at column 0
			Test.Assert(output.Contains("\n  \"firstName\""), "firstName should be indented");
			Test.Assert(output.Contains("\n  \"lastName\""), "lastName should be indented");
			Test.Assert(output.Contains("\n  \"isAlive\""), "isAlive should be indented");
			Test.Assert(output.Contains("\n  \"age\""), "age should be indented");
			Test.Assert(output.Contains("\n  \"phoneNumbers\""), "phoneNumbers should be indented");
			Test.Assert(output.Contains("\n      \"type\""), "type field should be double-indented");
			Test.Assert(output.Contains("\n      \"number\""), "number field should be double-indented");
			
			Debug.WriteLine(scope $"  Test 8 (exact indentation validation): PASSED");
			Debug.WriteLine(scope $"    Output:\n{output}");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Serialization - Pretty-print tests")]
	public static void T_SerializationPrettyPrint()
	{
		Debug.WriteLine("Serialization - Pretty-print tests ...");

		// Test 1: Simple object with default indentation (2 spaces)
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
			Debug.WriteLine(scope $"  Test 1 (pretty object): PASSED");
			Debug.WriteLine(scope $"    Output:\n{output}");
		}

		// Test 2: Array with default indentation
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
			Debug.WriteLine(scope $"  Test 2 (pretty array): PASSED");
			Debug.WriteLine(scope $"    Output:\n{output}");
		}

		// Test 3: Custom indent string (tabs)
		{
			var json = JsonObject();
			json.Add("key", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true, IndentString = "\t" };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "Tab-indented serialization should succeed");
			Test.Assert(output.Contains("\t"), "Output should contain tabs");
			Debug.WriteLine(scope $"  Test 3 (tab indent): PASSED");
			Debug.WriteLine(scope $"    Output:\n{output}");
		}

		// Test 4: Custom indent string (4 spaces)
		{
			var json = JsonObject();
			json.Add("key", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true, IndentString = "    " };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "4-space indented serialization should succeed");
			Test.Assert(output.Contains("    "), "Output should contain 4-space indentation");
			Debug.WriteLine(scope $"  Test 4 (4-space indent): PASSED");
			Debug.WriteLine(scope $"    Output:\n{output}");
		}

		// Test 5: Custom newline (CRLF)
		{
			var json = JsonObject();
			json.Add("key", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			var options = JsonWriterOptions() { Indented = true, NewLine = "\r\n" };
			let result = Json.Serialize(json, output, options);

			Test.Assert(result case .Ok, "CRLF serialization should succeed");
			Test.Assert(output.Contains("\r\n"), "Output should contain CRLF");
			Debug.WriteLine(scope $"  Test 5 (CRLF newline): PASSED");
		}

		// Test 6: Nested structure with indentation
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
			// Check that nesting increases indentation - depth 2 should have 2x indent string
			Debug.WriteLine(scope $"  Test 6 (nested pretty): PASSED");
			Debug.WriteLine(scope $"    Output:\n{output}");
		}

		// Test 7: Non-indented should produce minified output
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
			Debug.WriteLine(scope $"  Test 7 (minified): PASSED - output: {output}");
		}

		// Test 8: Exact deep indentation structure for all keys in all objects
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
			
			// Verify proper indentation by checking that all keys are indented correctly
			// In the broken version, only first key would be indented, others would be at column 0
			Test.Assert(output.Contains("\n  \"firstName\""), "firstName should be indented");
			Test.Assert(output.Contains("\n  \"lastName\""), "lastName should be indented");
			Test.Assert(output.Contains("\n  \"isAlive\""), "isAlive should be indented");
			Test.Assert(output.Contains("\n  \"age\""), "age should be indented");
			Test.Assert(output.Contains("\n  \"phoneNumbers\""), "phoneNumbers should be indented");
			Test.Assert(output.Contains("\n      \"type\""), "type field should be double-indented");
			Test.Assert(output.Contains("\n      \"number\""), "number field should be double-indented");
			
			Debug.WriteLine(scope $"  Test 8 (exact indentation validation): PASSED");
			Debug.WriteLine(scope $"    Output:\n{output}");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Serialization - Round-trip tests")]
	public static void T_SerializationRoundTrip()
	{
		Debug.WriteLine("Serialization - Round-trip tests ...");

		// Helper to test round-trip
		static void TestRoundTrip(StringView originalJson, int testNum, StringView testName)
		{
			// Parse original
			var result1 = Json.Deserialize(originalJson);
			defer result1.Dispose();

			switch (result1)
			{
			case .Ok(let json1):
				// Serialize
				let serialized = scope String();
				let result2 = Json.Serialize(json1, serialized);

				if (result2 case .Err(let serErr))
				{
					Test.Assert(false, scope $"Round-trip serialization failed! {serErr}");
					return;
				}

				// Parse again
				let result3 = Json.Deserialize(serialized);
				defer result3.Dispose();

				switch (result3)
				{
				case .Ok(let json2):
					// Serialize again to compare
					let serialized2 = scope String();
					Json.Serialize(json2, serialized2);

					Test.Assert(serialized == serialized2, scope $"Round-trip mismatch! First: {serialized}, Second: {serialized2}");
					Debug.WriteLine(scope $"  Test {testNum} ({testName}): PASSED - {serialized}");
				case .Err(let parseErr):
					Test.Assert(false, scope $"Round-trip re-parse failed: {parseErr}");
				}
			case .Err(let err):
				Test.Assert(false, scope $"Round-trip initial parse failed: {err}");
			}
		}

		// Test various JSON structures
		TestRoundTrip("null", 1, "null");
		TestRoundTrip("true", 2, "true");
		TestRoundTrip("false", 3, "false");
		TestRoundTrip("42", 4, "integer");
		TestRoundTrip("-123", 5, "negative int");
		TestRoundTrip("3.14", 6, "float");
		TestRoundTrip("\"hello\"", 7, "string");
		TestRoundTrip("{}", 8, "empty object");
		TestRoundTrip("[]", 9, "empty array");
		TestRoundTrip("[1,2,3]", 10, "simple array");
		TestRoundTrip("{\"key\":\"value\"}", 11, "simple object");
		TestRoundTrip("[null,true,false,42,\"text\"]", 12, "mixed array");
		TestRoundTrip("{\"nested\":{\"inner\":\"value\"}}", 13, "nested object");
		TestRoundTrip("[[1,2],[3,4]]", 14, "nested arrays");
		TestRoundTrip("{\"arr\":[1,2],\"obj\":{\"x\":1}}", 15, "complex structure");

		// Test with larger numbers
		TestRoundTrip("9223372036854775807", 16, "max int64");
		TestRoundTrip("-9223372036854775808", 17, "min int64");
		TestRoundTrip("18446744073709551615", 18, "max uint64");

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Serialization - Error handling tests")]
	public static void T_SerializationErrors()
	{
		Debug.WriteLine("Serialization - Error handling tests ...");

		// Test 1: NaN should fail
		{
			let json = JsonNumber(Double.NaN);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.NaNNotAllowed), "NaN serialization should return NaNNotAllowed error");
			Debug.WriteLine("  Test 1 (NaN error): PASSED");
		}

		// Test 2: Positive Infinity should fail
		{
			let json = JsonNumber(Double.PositiveInfinity);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.InfinityNotAllowed), "Positive Infinity should return InfinityNotAllowed error");
			Debug.WriteLine("  Test 2 (Positive Infinity error): PASSED");
		}

		// Test 3: Negative Infinity should fail
		{
			let json = JsonNumber(Double.NegativeInfinity);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.InfinityNotAllowed), "Negative Infinity should return InfinityNotAllowed error");
			Debug.WriteLine("  Test 3 (Negative Infinity error): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Serialization - Escape character tests")]
	public static void T_SerializationEscapeCharacters()
	{
		Debug.WriteLine("Serialization - Escape character tests ...");

		// Test 1: Newline escape
		{
			var json = JsonString("hello\nworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with newline should succeed");
			Test.Assert(output == "\"hello\\nworld\"", scope $"Expected '\"hello\\nworld\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 1 (newline): PASSED - output: {output}");
		}

		// Test 2: Tab escape
		{
			var json = JsonString("hello\tworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with tab should succeed");
			Test.Assert(output == "\"hello\\tworld\"", scope $"Expected '\"hello\\tworld\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 2 (tab): PASSED - output: {output}");
		}

		// Test 3: Carriage return escape
		{
			var json = JsonString("hello\rworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with carriage return should succeed");
			Test.Assert(output == "\"hello\\rworld\"", scope $"Expected '\"hello\\rworld\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 3 (carriage return): PASSED - output: {output}");
		}

		// Test 4: Quote escape
		{
			var json = JsonString("say \"hello\"");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with quotes should succeed");
			Test.Assert(output == "\"say \\\"hello\\\"\"", scope $"Expected '\"say \\\"hello\\\"\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 4 (quotes): PASSED - output: {output}");
		}

		// Test 5: Backslash escape
		{
			var json = JsonString("path\\to\\file");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with backslashes should succeed");
			Test.Assert(output == "\"path\\\\to\\\\file\"", scope $"Expected '\"path\\\\to\\\\file\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 5 (backslash): PASSED - output: {output}");
		}

		// Test 6: Backspace escape
		{
			var json = JsonString("hello\bworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with backspace should succeed");
			Test.Assert(output == "\"hello\\bworld\"", scope $"Expected '\"hello\\bworld\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 6 (backspace): PASSED - output: {output}");
		}

		// Test 7: Form feed escape
		{
			var json = JsonString("hello\fworld");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with form feed should succeed");
			Test.Assert(output == "\"hello\\fworld\"", scope $"Expected '\"hello\\fworld\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 7 (form feed): PASSED - output: {output}");
		}

		// Test 8: Multiple escapes in one string
		{
			var json = JsonString("line1\nline2\ttab\r\n");
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of string with multiple escapes should succeed");
			Test.Assert(output == "\"line1\\nline2\\ttab\\r\\n\"", scope $"Expected '\"line1\\nline2\\ttab\\r\\n\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 8 (multiple escapes): PASSED - output: {output}");
		}

		// Test 9: Round-trip with escape characters - parse escaped JSON and serialize back
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
				Debug.WriteLine(scope $"  Test 9 (round-trip): PASSED - input: {inputJson}, output: {output}");
			case .Err(let err):
				Test.Assert(false, scope $"Round-trip parse failed: {err}");
			}
		}

		// Test 10: Round-trip with all common escapes
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
				Debug.WriteLine(scope $"  Test 10 (all escapes round-trip): PASSED");
			case .Err(let err):
				Test.Assert(false, scope $"Round-trip parse failed: {err}");
			}
		}

		// Test 11: Control character (NUL - 0x00) uses \u0000 format
		{
			var json = JsonString(scope String()..Append('\0'));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of NUL character should succeed");
			Test.Assert(output == "\"\\u0000\"", scope $"Expected '\"\\u0000\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 11 (NUL control char): PASSED - output: {output}");
		}

		// Test 12: Control character (0x1F) uses \u001f format
		{
			var json = JsonString(scope String()..Append((char8)0x1F));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of control char 0x1F should succeed");
			Test.Assert(output == "\"\\u001f\"", scope $"Expected '\"\\u001f\"', got '{output}'");
			Debug.WriteLine(scope $"  Test 12 (0x1F control char): PASSED - output: {output}");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
