using System;
using BJSON;
using BJSON.Models;
using BJSON.Enums;
using System.IO;
using System.Diagnostics;

namespace BJSON.Test;

class ErrorHandlingTest
{
	[Test(Name = "Error Handling - Parsing Errors")]
	public static void T_ParsingErrors()
	{
		Debug.WriteLine("Error Handling - Parsing Errors ...");

		// Test 1: Empty document
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
			Debug.WriteLine("  Test 1 (empty document): PASSED");
		}

		// Test 2: Whitespace only
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
			Debug.WriteLine("  Test 2 (whitespace only): PASSED");
		}

		// Test 3: Unclosed object
		{
			var result = Json.Deserialize("{\"key\": \"value\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unclosed object should fail");
			Debug.WriteLine("  Test 3 (unclosed object): PASSED");
		}

		// Test 4: Unclosed array
		{
			var result = Json.Deserialize("[1, 2, 3");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unclosed array should fail");
			Debug.WriteLine("  Test 4 (unclosed array): PASSED");
		}

		// Test 5: Missing colon in object
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
			Debug.WriteLine("  Test 5 (missing colon): PASSED");
		}

		// Test 6: Trailing comma in object
		{
			var result = Json.Deserialize("{\"key\": \"value\",}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Trailing comma in object should fail");
			Debug.WriteLine("  Test 6 (trailing comma object): PASSED");
		}

		// Test 7: Trailing comma in array
		{
			var result = Json.Deserialize("[1, 2, 3,]");
			defer result.Dispose();

			Test.Assert(result case .Err, "Trailing comma in array should fail");
			Debug.WriteLine("  Test 7 (trailing comma array): PASSED");
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
			Debug.WriteLine("  Test 8 (invalid value): PASSED");
		}

		// Test 9: Unquoted key
		{
			var result = Json.Deserialize("{key: \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unquoted key should fail");
			Debug.WriteLine("  Test 9 (unquoted key): PASSED");
		}

		// Test 10: Single quotes
		{
			var result = Json.Deserialize("{'key': 'value'}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Single quotes should fail");
			Debug.WriteLine("  Test 10 (single quotes): PASSED");
		}

		// Test 11: Invalid escape sequence
		{
			var result = Json.Deserialize("\"hello\\xworld\"");
			defer result.Dispose();

			// \x is not a valid JSON escape - should fail
			Test.Assert(result case .Err, "Invalid escape \\x should fail");
			Debug.WriteLine("  Test 11 (invalid escape): PASSED");
		}

		// Test 12: Unterminated string
		{
			var result = Json.Deserialize("\"hello");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unterminated string should fail");
			Debug.WriteLine("  Test 12 (unterminated string): PASSED");
		}

		// Test 13: Invalid unicode escape - not enough digits
		{
			var result = Json.Deserialize("\"\\u00\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Invalid unicode escape (too short) should fail");
			Debug.WriteLine("  Test 13 (invalid unicode escape): PASSED");
		}

		// Test 14: Invalid unicode escape - non-hex chars
		{
			var result = Json.Deserialize("\"\\uGGGG\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Non-hex unicode escape should fail");
			Debug.WriteLine("  Test 14 (non-hex unicode): PASSED");
		}

		// Test 15: Control character in string
		{
			let jsonWithControl = scope String();
			jsonWithControl.Append("\"hello");
			jsonWithControl.Append((char8)0x01);
			jsonWithControl.Append("world\"");
			
			var result = Json.Deserialize(jsonWithControl);
			defer result.Dispose();

			Test.Assert(result case .Err, "Control character in string should fail");
			Debug.WriteLine("  Test 15 (control character): PASSED");
		}

		// Test 16: Leading zeros in numbers
		{
			var result = Json.Deserialize("01234");
			defer result.Dispose();

			Test.Assert(result case .Err, "Leading zeros should fail");
			Debug.WriteLine("  Test 16 (leading zeros): PASSED");
		}

		// Test 17: Plus sign prefix (not allowed in JSON)
		{
			var result = Json.Deserialize("+123");
			defer result.Dispose();

			Test.Assert(result case .Err, "Plus sign prefix should fail");
			Debug.WriteLine("  Test 17 (plus prefix): PASSED");
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
			Debug.WriteLine("  Test 18 (max depth): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Error Handling - Serialization Errors")]
	public static void T_SerializationErrors()
	{
		Debug.WriteLine("Error Handling - Serialization Errors ...");

		// Test 1: NaN value
		{
			let json = JsonNumber(Double.NaN);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.NaNNotAllowed), "NaN should return NaNNotAllowed error");
			Debug.WriteLine("  Test 1 (NaN): PASSED");
		}

		// Test 2: Positive Infinity
		{
			let json = JsonNumber(Double.PositiveInfinity);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.InfinityNotAllowed), "Positive Infinity should return InfinityNotAllowed error");
			Debug.WriteLine("  Test 2 (positive infinity): PASSED");
		}

		// Test 3: Negative Infinity
		{
			let json = JsonNumber(Double.NegativeInfinity);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.InfinityNotAllowed), "Negative Infinity should return InfinityNotAllowed error");
			Debug.WriteLine("  Test 3 (negative infinity): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Error Handling - Stream Errors")]
	public static void T_StreamErrors()
	{
		Debug.WriteLine("Error Handling - Stream Errors ...");

		// Test 1: Null stream
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize((Stream)null);
			defer result.Dispose();

			Test.Assert(result case .Err(.InputStreamIsNull), "Null stream should return InputStreamIsNull error");
			Debug.WriteLine("  Test 1 (null stream): PASSED");
		}

		// Test 2: Empty stream
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
			Debug.WriteLine("  Test 2 (empty stream): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
