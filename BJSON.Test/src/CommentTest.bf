using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;

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
		Debug.WriteLine("JSON Comment Support tests ...");

		// Test 1: Single-line comment before JSON
		{
			let jsonWithComments = "// comment at start\n{\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok(let val), "Single-line comment before JSON should succeed");
			if (result case .Ok(let json))
			{
				Test.Assert(json.type == .OBJECT, "Should parse as object");
				StringView str = json["key"];
				Test.Assert(str == "value", scope $"Expected 'value', got '{str}'");
			}
			Debug.WriteLine("  Test 1 (single-line before): PASSED");
		}

		// Test 2: Single-line comment after JSON
		{
			let jsonWithComments = "{\"key\": \"value\"} // comment at end";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Single-line comment after JSON should succeed");
			Debug.WriteLine("  Test 2 (single-line after): PASSED");
		}

		// Test 3: Multi-line comment before JSON
		{
			let jsonWithComments = "/* multi\n   line */\n{\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Multi-line comment before JSON should succeed");
			Debug.WriteLine("  Test 3 (multi-line before): PASSED");
		}

		// Test 4: Multi-line comment after JSON
		{
			let jsonWithComments = "{\"key\": \"value\"} /* comment */";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Multi-line comment after JSON should succeed");
			Debug.WriteLine("  Test 4 (multi-line after): PASSED");
		}

		// Test 5: Comments in arrays
		{
			let jsonWithComments = """
[ 
  1, // first element 
  2, /* second element */
  3 
]
""";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok(let json), "Comments in arrays should succeed");
			if (result case .Ok(let arr))
			{
				Test.Assert(arr.type == .ARRAY, "Should parse as array");
				Test.Assert(arr.As<JsonArray>().Count == 3, scope $"Expected 3 elements, got {arr.As<JsonArray>().Count}");
			}
			Debug.WriteLine("  Test 5 (comments in arrays): PASSED");
		}

		// Test 6: Comments in objects
		{
			let jsonWithComments = """
{
  // property
  "name": "test", /* inline */
  "value": 42
}
""";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
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
			Debug.WriteLine("  Test 6 (comments in objects): PASSED");
		}

		// Test 7: Multiple comments
		{
			let jsonWithComments = """
// Start comment
/* Multi-line
   comment */
{
  // Key comment
  "key": /* value comment */ "value"
}
// End comment
""";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Multiple comments should succeed");
			Debug.WriteLine("  Test 7 (multiple comments): PASSED");
		}

		// Test 8: Comment with CRLF line endings
		{
			let jsonWithComments = "// comment\r\n{\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Comment with CRLF should succeed");
			Debug.WriteLine("  Test 8 (CRLF line ending): PASSED");
		}

		// Test 9: Comments disabled (standard JSON mode) - should fail
		{
			let jsonWithComments = "// comment\n{\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = false };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Err, "Comments should fail when disabled");
			Debug.WriteLine("  Test 9 (comments disabled): PASSED");
		}

		// Test 10: Unterminated multi-line comment - should fail
		{
			let jsonWithComments = "/* unterminated comment\n{\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Err, "Unterminated multi-line comment should fail");
			Debug.WriteLine("  Test 10 (unterminated comment): PASSED");
		}

		// Test 11: Only comment, no JSON - should fail
		{
			let jsonWithComments = "// just a comment";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Err, "Only comment, no JSON should fail");
			Debug.WriteLine("  Test 11 (only comment): PASSED");
		}

		// Test 12: Comment between object key and colon
		{
			let jsonWithComments = """
{
  "key" /* comment */ : "value"
}
""";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Comment between key and colon should succeed");
			Debug.WriteLine("  Test 12 (comment between key and colon): PASSED");
		}

		// Test 13: Comment between colon and value
		{
			let jsonWithComments = """
{
  "key": /* comment */ "value"
}
""";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Comment between colon and value should succeed");
			Debug.WriteLine("  Test 13 (comment between colon and value): PASSED");
		}

		// Test 14: Nested multi-line comment (not nested) - /* /* */ treats first */ as end
		{
			let jsonWithComments = "/* outer /* inner */ {\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			// This should parse successfully since first */ closes the comment
			Test.Assert(result case .Ok, "Non-nested comment handling should succeed");
			Debug.WriteLine("  Test 14 (non-nested comments): PASSED");
		}

		// Test 15: Empty single-line comment
		{
			let jsonWithComments = "//\n{\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Empty single-line comment should succeed");
			Debug.WriteLine("  Test 15 (empty single-line): PASSED");
		}

		// Test 16: Empty multi-line comment
		{
			let jsonWithComments = "/**/{\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Empty multi-line comment should succeed");
			Debug.WriteLine("  Test 16 (empty multi-line): PASSED");
		}

		// Test 17: Single / without second / (not a comment) - should fail
		{
			let jsonWithComments = "/ {\"key\": \"value\"}";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Err, "Single / should fail");
			Debug.WriteLine("  Test 17 (single slash): PASSED");
		}

		// Test 18: Complex nested structure with comments everywhere
		{
			let jsonWithComments = """
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
""";
			
			var config = DeserializerConfig() { EnableComments = true };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithComments);
			defer result.Dispose();

			Test.Assert(result case .Ok(let json), "Complex nested structure with comments should succeed");
			if (result case .Ok(let obj))
			{
				Test.Assert(obj.type == .OBJECT, "Should parse as object");
				Test.Assert(obj["items"].type == .ARRAY, "items should be array");
				let itemsArray = obj["items"].As<JsonArray>();
				Test.Assert(itemsArray.Count == 3, scope $"Expected 3 items, got {itemsArray.Count}");
			}
			Debug.WriteLine("  Test 18 (complex nested): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
