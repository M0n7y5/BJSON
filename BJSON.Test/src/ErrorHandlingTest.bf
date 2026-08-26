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

		{
			var result = Json.Deserialize("{\"key\": \"value\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unclosed object should fail");
			Debug.WriteLine("  Test 3 (unclosed object): PASSED");
		}

		{
			var result = Json.Deserialize("[1, 2, 3");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unclosed array should fail");
			Debug.WriteLine("  Test 4 (unclosed array): PASSED");
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
			Debug.WriteLine("  Test 5 (missing colon): PASSED");
		}

		{
			var result = Json.Deserialize("{\"key\": \"value\",}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Trailing comma in object should fail");
			Debug.WriteLine("  Test 6 (trailing comma object): PASSED");
		}

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

		{
			var result = Json.Deserialize("{key: \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unquoted key should fail");
			Debug.WriteLine("  Test 9 (unquoted key): PASSED");
		}

		{
			var result = Json.Deserialize("{'key': 'value'}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Single quotes should fail");
			Debug.WriteLine("  Test 10 (single quotes): PASSED");
		}

		{
			var result = Json.Deserialize("\"hello\\xworld\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Invalid escape \\x should fail");
			Debug.WriteLine("  Test 11 (invalid escape): PASSED");
		}

		{
			var result = Json.Deserialize("\"hello");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unterminated string should fail");
			Debug.WriteLine("  Test 12 (unterminated string): PASSED");
		}

		{
			var result = Json.Deserialize("\"\\u00\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Invalid unicode escape (too short) should fail");
			Debug.WriteLine("  Test 13 (invalid unicode escape): PASSED");
		}

		{
			var result = Json.Deserialize("\"\\uGGGG\"");
			defer result.Dispose();

			Test.Assert(result case .Err, "Non-hex unicode escape should fail");
			Debug.WriteLine("  Test 14 (non-hex unicode): PASSED");
		}

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

		{
			var result = Json.Deserialize("01234");
			defer result.Dispose();

			Test.Assert(result case .Err, "Leading zeros should fail");
			Debug.WriteLine("  Test 16 (leading zeros): PASSED");
		}

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

		{
			let json = JsonNumber(Double.NaN);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.NaNNotAllowed), "NaN should return NaNNotAllowed error");
			Debug.WriteLine("  Test 1 (NaN): PASSED");
		}

		{
			let json = JsonNumber(Double.PositiveInfinity);
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Err(.InfinityNotAllowed), "Positive Infinity should return InfinityNotAllowed error");
			Debug.WriteLine("  Test 2 (positive infinity): PASSED");
		}

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

		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize((Stream)null);
			defer result.Dispose();

			Test.Assert(result case .Err(.InputStreamIsNull), "Null stream should return InputStreamIsNull error");
			Debug.WriteLine("  Test 1 (null stream): PASSED");
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
			Debug.WriteLine("  Test 2 (empty stream): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Number Parsing - int64 Minimum")]
	public static void T_Int64MinimumBoundary()
	{
		Debug.WriteLine("Number Parsing - int64 minimum ...");

		var result = Json.Deserialize("-9223372036854775808");
		defer result.Dispose();

		if (result case .Ok(let json))
		{
			Test.Assert(json.type == .NUMBER_SIGNED, scope $"Expected a signed integer, got {json.type}");

			int64 value = json;
			Test.Assert(value == int64.MinValue, scope $"Expected {int64.MinValue}, got {value}");
		}
		else
		{
			Test.Assert(false, "int64 minimum should parse");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Number Parsing - Negative Zero")]
	public static void T_NegativeZeroKeepsSign()
	{
		Debug.WriteLine("Number Parsing - negative zero ...");

		var result = Json.Deserialize("-0");
		defer result.Dispose();

		if (result case .Ok(let json))
		{
			double value = json;
			Test.Assert(value == 0.0, scope $"Expected zero, got {value}");
			Test.Assert(value.IsNegative, "Bare -0 should keep its sign");
		}
		else
		{
			Test.Assert(false, "-0 should parse");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
