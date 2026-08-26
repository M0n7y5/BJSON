using System;
using BJSON;
using BJSON.Models;

namespace BJSON.Test;

class SSOTest
{
	[Test(Name = "Small String Optimization")]
	public static void T_SmallStringOptimization()
	{
		{
			let json = JsonString("a");
			defer json.Dispose();

			Test.Assert(json.smallString == true, "1-char string should use SSO");
			StringView str = json;
			Test.Assert(str == "a", scope $"Expected 'a', got '{str}'");
		}

		{
			let json = JsonString("12345678901234");
			defer json.Dispose();

			Test.Assert(json.smallString == true, "14-char string should use SSO");
			StringView str = json;
			Test.Assert(str == "12345678901234", scope $"Expected '12345678901234', got '{str}'");
			Test.Assert(str.Length == 14, scope $"Expected length 14, got {str.Length}");
		}

		{
			let json = JsonString("123456789012345");
			defer json.Dispose();

			Test.Assert(json.smallString == false, "15-char string should NOT use SSO");
			StringView str = json;
			Test.Assert(str == "123456789012345", scope $"Expected '123456789012345', got '{str}'");
			Test.Assert(str.Length == 15, scope $"Expected length 15, got {str.Length}");
		}

		{
			let json = JsonString("This is a much longer string that definitely exceeds the SSO limit");
			defer json.Dispose();

			Test.Assert(json.smallString == false, "Long string should NOT use SSO");
			StringView str = json;
			Test.Assert(str == "This is a much longer string that definitely exceeds the SSO limit");
		}

		{
			let json = JsonString("");
			defer json.Dispose();

			Test.Assert(json.smallString == true, "Empty string should use SSO");
			StringView str = json;
			Test.Assert(str == "", "Empty string should be empty");
			Test.Assert(str.Length == 0, "Empty string length should be 0");
		}

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
		}

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
		}

		{
			let json = JsonString("hello\nworld");
			defer json.Dispose();

			Test.Assert(json.smallString == true, "11-char string with escape should use SSO");
			StringView str = json;
			Test.Assert(str == "hello\nworld", "String with newline should match");
			Test.Assert(str.Length == 11, scope $"Expected length 11, got {str.Length}");
		}

		{
			Test.Assert(JsonString.MaxSmallStringLength == 14, "MaxSmallStringLength should be 14");
		}

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
		}
	}

	[Test(Name = "Small String Optimization: AsStringView")]
	public static void T_AsStringView()
	{
		{
			var json = JsonString("12345678901234");
			defer json.Dispose();

			let view = json.AsStringView();
			Test.Assert(view == "12345678901234", scope $"Expected '12345678901234', got '{view}'");
			Test.Assert(view.Length == 14, scope $"Expected length 14, got {view.Length}");
			// An inline view has to address the value's own bytes; a view taken from a copy of
			// the value dangles as soon as that copy dies.
			Test.Assert(view.Ptr == &json.data.smallStr.data[0], "Inline view should point into the stored value");
		}

		{
			var json = JsonString("123456789012345");
			defer json.Dispose();

			let view = json.AsStringView();
			Test.Assert(view == "123456789012345", scope $"Expected '123456789012345', got '{view}'");
			Test.Assert(view.Length == 15, scope $"Expected length 15, got {view.Length}");
			Test.Assert(view.Ptr == json.data.string.Ptr, "Heap view should point into the owned String");
		}
	}
}
