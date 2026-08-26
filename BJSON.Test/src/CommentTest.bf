using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;

namespace BJSON.Test;

/// Tests for JSONC comment support:
/// - Single-line comments (//)
/// - Multi-line comments (/* */)
/// - Comments in various positions
/// - Error cases (unterminated, disabled)
class CommentTest
{
	[Test(Name = "JSON Comment Support")]
	public static void T_CommentSupport()
	{
		static Result<JsonValue, JsonParsingError> ParseWithComments(StringView json)
		{
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);

			return deserializer.Deserialize(json);
		}

		{
			var result = ParseWithComments("// comment at start\n{\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok(let val), "Single-line comment before JSON should succeed");
			if (result case .Ok(let json))
			{
				Test.Assert(json.type == .OBJECT, "Should parse as object");
				StringView str = json["key"];
				Test.Assert(str == "value", scope $"Expected 'value', got '{str}'");
			}
		}

		{
			var result = ParseWithComments("{\"key\": \"value\"} // comment at end");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Single-line comment after JSON should succeed");
		}

		{
			var result = ParseWithComments("/* multi\n   line */\n{\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Multi-line comment before JSON should succeed");
		}

		{
			var result = ParseWithComments("{\"key\": \"value\"} /* comment */");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Multi-line comment after JSON should succeed");
		}

		{
			var result = ParseWithComments("""
[ 
  1, // first element 
  2, /* second element */
  3 
]
""");
			defer result.Dispose();

			Test.Assert(result case .Ok(let json), "Comments in arrays should succeed");
			if (result case .Ok(let arr))
			{
				Test.Assert(arr.type == .ARRAY, "Should parse as array");
				Test.Assert(arr.As<JsonArray>().Count == 3, scope $"Expected 3 elements, got {arr.As<JsonArray>().Count}");
			}
		}

		{
			var result = ParseWithComments("""
{
  // property
  "name": "test", /* inline */
  "value": 42
}
""");
			defer result.Dispose();

			Test.Assert(result case .Ok(let json), "Comments in objects should succeed");
			if (result case .Ok(let obj))
			{
				Test.Assert(obj.type == .OBJECT, "Should parse as object");
				StringView str = obj["name"];
				Test.Assert(str == "test", scope $"Expected 'test', got '{str}'");
				int64 num = obj["value"];
				Test.Assert(num == 42, scope $"Expected 42, got {num}");
			}
		}

		{
			var result = ParseWithComments("""
// Start comment
/* Multi-line
   comment */
{
  // Key comment
  "key": /* value comment */ "value"
}
// End comment
""");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Multiple comments should succeed");
		}

		{
			var result = ParseWithComments("// comment\r\n{\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Comment with CRLF should succeed");
		}

		{
			var config = DeserializerConfig() { EnableComments = false };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize("// comment\n{\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Comments should fail when disabled");
		}

		{
			var result = ParseWithComments("/* unterminated comment\n{\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Unterminated multi-line comment should fail");
		}

		{
			var result = ParseWithComments("// just a comment");
			defer result.Dispose();

			Test.Assert(result case .Err, "Only comment, no JSON should fail");
		}

		{
			var result = ParseWithComments("""
{
  "key" /* comment */ : "value"
}
""");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Comment between key and colon should succeed");
		}

		{
			var result = ParseWithComments("""
{
  "key": /* comment */ "value"
}
""");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Comment between colon and value should succeed");
		}

		// /* /* */ treats the first */ as the end: multi-line comments do not nest
		{
			var result = ParseWithComments("/* outer /* inner */ {\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Non-nested comment handling should succeed");
		}

		{
			var result = ParseWithComments("//\n{\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Empty single-line comment should succeed");
		}

		{
			var result = ParseWithComments("/**/{\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Empty multi-line comment should succeed");
		}

		{
			var result = ParseWithComments("/ {\"key\": \"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Err, "Single / should fail");
		}

		{
			var result = ParseWithComments("""
// Root comment
{
  // Array field
  "items": [ // inline
    1, // first
    /* multi-line
       comment */
    2,
    {
      "nested": /* comment */ "value"
    }
  ], /* after array */
  "flag": true // boolean
}
// Trailing comment
""");
			defer result.Dispose();

			Test.Assert(result case .Ok(let json), "Complex nested structure with comments should succeed");
			if (result case .Ok(let obj))
			{
				Test.Assert(obj.type == .OBJECT, "Should parse as object");
				Test.Assert(obj["items"].type == .ARRAY, "items should be array");
				let itemsArray = obj["items"].As<JsonArray>();
				Test.Assert(itemsArray.Count == 3, scope $"Expected 3 items, got {itemsArray.Count}");
			}
		}

		{
			var result = ParseWithComments("/* x");
			defer result.Dispose();

			if (result case .Err(let err))
			{
				if (err case .UnexpectedToken(let errLine, let errColumn, let expected))
				{
					Test.Assert(expected == "closing */", scope $"Expected 'closing */', got '{expected}'");
					Test.Assert(errLine == 1, scope $"Expected line 1, got {errLine}");
					Test.Assert(errColumn == 5, scope $"Expected column 5, got {errColumn}");
				}
				else
					Test.Assert(false, scope $"Unterminated comment should report the missing closing, got {err}");
			}
			else
				Test.Assert(false, "Unterminated multi-line comment should fail");
		}
	}
}
