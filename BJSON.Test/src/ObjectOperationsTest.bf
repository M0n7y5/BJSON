using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;

namespace BJSON.Test;

/// Tests for JSON object and array operations:
/// - Object key escaping
/// - Duplicate key handling behaviors
/// - Remove methods for objects and arrays
class ObjectOperationsTest
{
	[Test(Name = "Object Key Escaping")]
	public static void T_ObjectKeyEscaping()
	{
		Debug.WriteLine("Object Key Escaping tests ...");

		// Test 1: Key with double quote
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
			Debug.WriteLine(scope $"  Test 1 (key with quotes): output: {output}");

			// Verify round-trip: parse the output and check it works
			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		// Test 2: Key with backslash
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
			Debug.WriteLine(scope $"  Test 2 (key with backslash): output: {output}");

			// Verify round-trip
			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		// Test 3: Key with newline
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
			Debug.WriteLine(scope $"  Test 3 (key with newline): output: {output}");

			// Verify round-trip
			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		// Test 4: Key with tab
		{
			var json = JsonObject();
			json.Add("col1\tcol2", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with tab should succeed");
			Test.Assert(output.Contains("\"col1\\tcol2\""), 
				scope $"Key with tab should be escaped. Got: {output}");
			Debug.WriteLine(scope $"  Test 4 (key with tab): output: {output}");

			// Verify round-trip
			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		// Test 5: Key with control character (NUL)
		{
			var json = JsonObject();
			json.Add(scope String()..Append("key")..Append('\0')..Append("end"), JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with NUL should succeed");
			Test.Assert(output.Contains("\\u0000"), 
				scope $"Key with NUL should be escaped as \\u0000. Got: {output}");
			Debug.WriteLine(scope $"  Test 5 (key with NUL): output: {output}");

			// Verify round-trip
			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
		}

		// Test 6: Key with multiple escape characters
		{
			var json = JsonObject();
			json.Add("\"quoted\"\nand\\slashed", JsonString("value"));
			defer json.Dispose();

			let output = scope String();
			let result = Json.Serialize(json, output);

			Test.Assert(result case .Ok, "Serialization of key with multiple escapes should succeed");
			Debug.WriteLine(scope $"  Test 6 (key with multiple escapes): output: {output}");

			// Verify round-trip - this is the most important test
			var parseResult = Json.Deserialize(output);
			defer parseResult.Dispose();
			Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
			
			if (parseResult case .Ok(let parsed))
			{
				// Verify the key was preserved correctly
				let obj = parsed.AsObject().Value;
				Test.Assert(obj.Count == 1, "Should have exactly one key");
				for (let item in obj)
				{
					Test.Assert(item.key == "\"quoted\"\nand\\slashed", 
						scope $"Key should round-trip correctly. Got: {item.key}");
				}
			}
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Duplicate Key Ignore Behavior")]
	public static void T_DuplicateKeyIgnoreBehavior()
	{
		Debug.WriteLine("Duplicate Key Ignore Behavior tests ...");

		// Test 1: Duplicate key with object value - should ignore the duplicate
		{
			let jsonWithDuplicates = "{\"key\":{\"original\":true},\"key\":{\"duplicate\":true}}";

			var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithDuplicates);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parsing with duplicate object keys should succeed with Ignore behavior");
			if (result case .Ok(let json))
			{
				let obj = json.AsObject().Value;
				let keyValue = obj["key"];
				Test.Assert(keyValue.type == .OBJECT, "key should be an object");
				
				// Should have the FIRST value, not the duplicate
				let innerObj = keyValue.AsObject().Value;
				Test.Assert(innerObj.ContainsKey("original"), 
					scope $"Should keep original value, not duplicate. Keys: {innerObj.Count}");
				Test.Assert(!innerObj.ContainsKey("duplicate"), 
					"Should NOT have duplicate value");
			}
			Debug.WriteLine("  Test 1 (duplicate object value - ignore): PASSED");
		}

		// Test 2: Duplicate key with array value - should ignore the duplicate
		{
			let jsonWithDuplicates = "{\"items\":[1,2,3],\"items\":[4,5,6]}";

			var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithDuplicates);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parsing with duplicate array keys should succeed with Ignore behavior");
			if (result case .Ok(let json))
			{
				let obj = json.AsObject().Value;
				let itemsValue = obj["items"];
				Test.Assert(itemsValue.type == .ARRAY, "items should be an array");
				
				// Should have the FIRST array [1, 2, 3], not [4, 5, 6]
				let arr = itemsValue.AsArray().Value;
				Test.Assert(arr.Count == 3, scope $"Should have 3 items from original array. Got: {arr.Count}");
				
				int64 firstItem = arr[0];
				Test.Assert(firstItem == 1, 
					scope $"First item should be 1 (from original), got: {firstItem}");
			}
			Debug.WriteLine("  Test 2 (duplicate array value - ignore): PASSED");
		}

		// Test 3: Duplicate key with nested array containing objects
		{
			let jsonWithDuplicates = "{\"data\":[{\"id\":1},{\"id\":2}],\"data\":[{\"id\":99}]}";

			var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithDuplicates);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parsing nested duplicate array should succeed");
			if (result case .Ok(let json))
			{
				let obj = json.AsObject().Value;
				let dataValue = obj["data"];
				let arr = dataValue.AsArray().Value;
				
				// Should have 2 items from original array, not 1 from duplicate
				Test.Assert(arr.Count == 2, 
					scope $"Should have 2 items from original array. Got: {arr.Count}");
			}
			Debug.WriteLine("  Test 3 (nested array with objects - ignore): PASSED");
		}

		// Test 4: Duplicate key with primitive value (for comparison)
		{
			let jsonWithDuplicates = "{\"value\":100,\"value\":999}";

			var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithDuplicates);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parsing with duplicate primitive should succeed");
			if (result case .Ok(let json))
			{
				int64 val = json["value"];
				Test.Assert(val == 100, scope $"Should keep original value 100, got: {val}");
			}
			Debug.WriteLine("  Test 4 (duplicate primitive - ignore): PASSED");
		}

		// Test 5: ThrowError behavior with array duplicate
		{
			let jsonWithDuplicates = "{\"items\":[1,2],\"items\":[3,4]}";

			var config = DeserializerConfig() { DuplicateBehavior = .ThrowError };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithDuplicates);
			defer result.Dispose();

			Test.Assert(result case .Err, "Parsing with duplicate should fail with ThrowError behavior");
			Debug.WriteLine("  Test 5 (duplicate array - throw error): PASSED");
		}

		// Test 6: AlwaysRewrite behavior with array duplicate
		{
			let jsonWithDuplicates = "{\"items\":[1,2,3],\"items\":[7,8,9]}";

			var config = DeserializerConfig() { DuplicateBehavior = .AlwaysRewrite };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithDuplicates);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parsing with AlwaysRewrite should succeed");
			if (result case .Ok(let json))
			{
				let arr = json["items"].AsArray().Value;
				// Should have the SECOND (rewritten) array [7, 8, 9]
				Test.Assert(arr.Count == 3, scope $"Should have 3 items. Got: {arr.Count}");
				
				int64 firstItem = arr[0];
				Test.Assert(firstItem == 7, 
					scope $"First item should be 7 (from rewrite), got: {firstItem}");
			}
			Debug.WriteLine("  Test 6 (duplicate array - always rewrite): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "Remove Methods")]
	public static void T_RemoveMethods()
	{
		Debug.WriteLine("Remove Methods tests ...");

		// Test 1: JsonObject.Remove - existing key
		{
			var json = JsonObject();
			json.Add("key1", JsonString("value1"));
			json.Add("key2", JsonString("value2"));
			json.Add("key3", JsonString("value3"));
			defer json.Dispose();

			Test.Assert(json.Count == 3, "Should have 3 keys initially");
			
			let removed = json.Remove("key2");
			Test.Assert(removed, "Remove should return true for existing key");
			Test.Assert(json.Count == 2, scope $"Should have 2 keys after removal. Got: {json.Count}");
			Test.Assert(!json.ContainsKey("key2"), "key2 should no longer exist");
			Test.Assert(json.ContainsKey("key1"), "key1 should still exist");
			Test.Assert(json.ContainsKey("key3"), "key3 should still exist");
			
			Debug.WriteLine("  Test 1 (JsonObject.Remove existing): PASSED");
		}

		// Test 2: JsonObject.Remove - non-existing key
		{
			var json = JsonObject();
			json.Add("key1", JsonString("value1"));
			defer json.Dispose();

			let removed = json.Remove("nonexistent");
			Test.Assert(!removed, "Remove should return false for non-existing key");
			Test.Assert(json.Count == 1, "Count should remain unchanged");
			
			Debug.WriteLine("  Test 2 (JsonObject.Remove non-existing): PASSED");
		}

		// Test 3: JsonObject.Remove - nested object (ensure proper disposal)
		{
			var json = JsonObject();
			json.Add("nested", JsonObject() { ("inner", "data") });
			json.Add("other", JsonString("value"));
			defer json.Dispose();

			Test.Assert(json.Count == 2, "Should have 2 keys initially");
			
			let removed = json.Remove("nested");
			Test.Assert(removed, "Remove should return true");
			Test.Assert(json.Count == 1, "Should have 1 key after removal");
			Test.Assert(!json.ContainsKey("nested"), "nested should be removed");
			
			Debug.WriteLine("  Test 3 (JsonObject.Remove nested): PASSED");
		}

		// Test 4: JsonArray.RemoveAt - valid index
		{
			var json = JsonArray();
			json.Add(JsonString("first"));
			json.Add(JsonString("second"));
			json.Add(JsonString("third"));
			defer json.Dispose();

			Test.Assert(json.Count == 3, "Should have 3 items initially");
			
			json.RemoveAt(1); // Remove "second"
			Test.Assert(json.Count == 2, scope $"Should have 2 items after removal. Got: {json.Count}");
			
			StringView first = json[0];
			StringView second = json[1];
			Test.Assert(first == "first", scope $"First item should be 'first'. Got: {first}");
			Test.Assert(second == "third", scope $"Second item should be 'third'. Got: {second}");
			
			Debug.WriteLine("  Test 4 (JsonArray.RemoveAt valid): PASSED");
		}

		// Test 5: JsonArray.RemoveAt - first and last elements
		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			json.Add(JsonNumber((int64)2));
			json.Add(JsonNumber((int64)3));
			defer json.Dispose();

			// Remove first
			json.RemoveAt(0);
			Test.Assert(json.Count == 2, "Should have 2 items");
			int64 val = json[0];
			Test.Assert(val == 2, scope $"First item should be 2. Got: {val}");

			// Remove last
			json.RemoveAt(1);
			Test.Assert(json.Count == 1, "Should have 1 item");
			val = json[0];
			Test.Assert(val == 2, scope $"Remaining item should be 2. Got: {val}");
			
			Debug.WriteLine("  Test 5 (JsonArray.RemoveAt first/last): PASSED");
		}

		// Test 6: JsonArray.Remove - by value
		{
			var json = JsonArray();
			let target = JsonString("target");
			json.Add(JsonString("other1"));
			json.Add(target);
			json.Add(JsonString("other2"));
			defer json.Dispose();

			Test.Assert(json.Count == 3, "Should have 3 items initially");
			
			let removed = json.Remove(target);
			Test.Assert(removed, "Remove should return true for existing value");
			Test.Assert(json.Count == 2, scope $"Should have 2 items after removal. Got: {json.Count}");
			
			Debug.WriteLine("  Test 6 (JsonArray.Remove by value): PASSED");
		}

		// Test 7: JsonArray.Remove - non-existing value
		{
			var json = JsonArray();
			json.Add(JsonString("item1"));
			json.Add(JsonString("item2"));
			let notInArray = JsonString("not in array");
			defer json.Dispose();
			defer notInArray.Dispose();

			let removed = json.Remove(notInArray);
			Test.Assert(!removed, "Remove should return false for non-existing value");
			Test.Assert(json.Count == 2, "Count should remain unchanged");
			
			Debug.WriteLine("  Test 7 (JsonArray.Remove non-existing): PASSED");
		}

		// Test 8: JsonArray.RemoveAt - nested array (ensure proper disposal)
		{
			var json = JsonArray();
			json.Add(JsonArray() { JsonNumber((int64)1), JsonNumber((int64)2) });
			json.Add(JsonString("keep"));
			defer json.Dispose();

			Test.Assert(json.Count == 2, "Should have 2 items initially");
			
			json.RemoveAt(0); // Remove nested array
			Test.Assert(json.Count == 1, "Should have 1 item after removal");
			
			StringView remaining = json[0];
			Test.Assert(remaining == "keep", scope $"Remaining item should be 'keep'. Got: {remaining}");
			
			Debug.WriteLine("  Test 8 (JsonArray.RemoveAt nested): PASSED");
		}

		// Test 9: Multiple removes on same object
		{
			var json = JsonObject();
			json.Add("a", JsonNumber((int64)1));
			json.Add("b", JsonNumber((int64)2));
			json.Add("c", JsonNumber((int64)3));
			json.Add("d", JsonNumber((int64)4));
			defer json.Dispose();

			json.Remove("b");
			json.Remove("d");
			Test.Assert(json.Count == 2, scope $"Should have 2 keys. Got: {json.Count}");
			Test.Assert(json.ContainsKey("a"), "Should have 'a'");
			Test.Assert(json.ContainsKey("c"), "Should have 'c'");
			
			Debug.WriteLine("  Test 9 (multiple removes): PASSED");
		}

		// Test 10: Remove all items from array
		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			json.Add(JsonNumber((int64)2));
			json.Add(JsonNumber((int64)3));
			defer json.Dispose();

			while (json.Count > 0)
			{
				json.RemoveAt(0);
			}
			Test.Assert(json.Count == 0, "Array should be empty");
			
			Debug.WriteLine("  Test 10 (remove all from array): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
