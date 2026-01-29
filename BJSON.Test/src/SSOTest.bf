using System;
using BJSON;
using BJSON.Models;
using System.Diagnostics;

namespace BJSON.Test;

class SSOTest
{
	[Test(Name = "Small String Optimization")]
	public static void T_SmallStringOptimization()
	{
		Debug.WriteLine("Small String Optimization tests ...");

		// Test 1: Very short string (1 char) should use SSO
		{
			let json = JsonString("a");
			defer json.Dispose();

			Test.Assert(json.smallString == true, "1-char string should use SSO");
			StringView str = json;
			Test.Assert(str == "a", scope $"Expected 'a', got '{str}'");
			Debug.WriteLine("  Test 1 (1-char SSO): PASSED");
		}

		// Test 2: String exactly at SSO limit (14 chars) should use SSO
		{
			let json = JsonString("12345678901234"); // 14 chars
			defer json.Dispose();

			Test.Assert(json.smallString == true, "14-char string should use SSO");
			StringView str = json;
			Test.Assert(str == "12345678901234", scope $"Expected '12345678901234', got '{str}'");
			Test.Assert(str.Length == 14, scope $"Expected length 14, got {str.Length}");
			Debug.WriteLine("  Test 2 (14-char SSO): PASSED");
		}

		// Test 3: String just over SSO limit (15 chars) should NOT use SSO
		{
			let json = JsonString("123456789012345"); // 15 chars
			defer json.Dispose();

			Test.Assert(json.smallString == false, "15-char string should NOT use SSO");
			StringView str = json;
			Test.Assert(str == "123456789012345", scope $"Expected '123456789012345', got '{str}'");
			Test.Assert(str.Length == 15, scope $"Expected length 15, got {str.Length}");
			Debug.WriteLine("  Test 3 (15-char no SSO): PASSED");
		}

		// Test 4: Long string should NOT use SSO
		{
			let json = JsonString("This is a much longer string that definitely exceeds the SSO limit");
			defer json.Dispose();

			Test.Assert(json.smallString == false, "Long string should NOT use SSO");
			StringView str = json;
			Test.Assert(str == "This is a much longer string that definitely exceeds the SSO limit");
			Debug.WriteLine("  Test 4 (long string no SSO): PASSED");
		}

		// Test 5: Empty string should use SSO
		{
			let json = JsonString("");
			defer json.Dispose();

			Test.Assert(json.smallString == true, "Empty string should use SSO");
			StringView str = json;
			Test.Assert(str == "", "Empty string should be empty");
			Test.Assert(str.Length == 0, "Empty string length should be 0");
			Debug.WriteLine("  Test 5 (empty string SSO): PASSED");
		}

		// Test 6: Parsing short strings should use SSO
		{
			var result = Json.Deserialize("{\"id\":\"abc\",\"name\":\"test\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Should parse successfully");
			if (result case .Ok(let json))
			{
				StringView id = json["id"];
				StringView name = json["name"];
				Test.Assert(id == "abc", scope $"Expected 'abc', got '{id}'");
				Test.Assert(name == "test", scope $"Expected 'test', got '{name}'");
			}
			Debug.WriteLine("  Test 6 (parsed short strings): PASSED");
		}

		// Test 7: Round-trip with SSO strings
		{
			let json = JsonObject()
				{
					("id", "123"),
					("type", "user"),
					("status", "active")
				};
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);
			Test.Assert(result case .Ok, "Serialization should succeed");

			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, "Re-parsing should succeed");
			
			if (parseResult case .Ok(let reparsed))
			{
				StringView id = reparsed["id"];
				StringView type = reparsed["type"];
				StringView status = reparsed["status"];
				Test.Assert(id == "123", scope $"Expected '123', got '{id}'");
				Test.Assert(type == "user", scope $"Expected 'user', got '{type}'");
				Test.Assert(status == "active", scope $"Expected 'active', got '{status}'");
			}
			Debug.WriteLine("  Test 7 (round-trip SSO): PASSED");
		}

		// Test 8: SSO with special characters
		{
			let json = JsonString("hello\nworld");
			defer json.Dispose();

			Test.Assert(json.smallString == true, "11-char string with escape should use SSO");
			StringView str = json;
			Test.Assert(str == "hello\nworld", "String with newline should match");
			Test.Assert(str.Length == 11, scope $"Expected length 11, got {str.Length}");
			Debug.WriteLine("  Test 8 (SSO with special chars): PASSED");
		}

		// Test 9: SSO boundary - exactly MaxSmallStringLength
		{
			Test.Assert(JsonString.MaxSmallStringLength == 14, "MaxSmallStringLength should be 14");
			Debug.WriteLine("  Test 9 (MaxSmallStringLength constant): PASSED");
		}

		// Test 10: Multiple SSO strings in array
		{
			let json = JsonArray()
				{
					JsonString("a"),
					JsonString("bb"),
					JsonString("ccc"),
					JsonString("dddd"),
					JsonString("12345678901234") // 14 chars
				};
			defer json.Dispose();

			Test.Assert(json.Count == 5, "Array should have 5 elements");
			
			StringView s0 = json[0];
			StringView s1 = json[1];
			StringView s2 = json[2];
			StringView s3 = json[3];
			StringView s4 = json[4];
			
			Test.Assert(s0 == "a", scope $"s0: expected 'a', got '{s0}'");
			Test.Assert(s1 == "bb", scope $"s1: expected 'bb', got '{s1}'");
			Test.Assert(s2 == "ccc", scope $"s2: expected 'ccc', got '{s2}'");
			Test.Assert(s3 == "dddd", scope $"s3: expected 'dddd', got '{s3}'");
			Test.Assert(s4 == "12345678901234", scope $"s4: expected '12345678901234', got '{s4}'");
			Debug.WriteLine("  Test 10 (SSO array): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
