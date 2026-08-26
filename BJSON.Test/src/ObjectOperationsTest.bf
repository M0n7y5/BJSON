using System;
using BJSON.Models;
using System.IO;

namespace BJSON.Test;

/// Tests for JSON object and array operations:
/// - Duplicate key handling behaviors
/// - Remove methods for objects and arrays
/// - Key and value enumeration
/// - Typed accessors and the key a container stores
class ObjectOperationsTest
{
	[Test(Name = "Duplicate Key Ignore Behavior")]
	public static void T_DuplicateKeyIgnoreBehavior()
	{
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
				
				let innerObj = keyValue.AsObject().Value;
				Test.Assert(innerObj.ContainsKey("original"), 
					scope $"Should keep original value, not duplicate. Keys: {innerObj.Count}");
				Test.Assert(!innerObj.ContainsKey("duplicate"), 
					"Should NOT have duplicate value");
			}
		}

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
				
				let arr = itemsValue.AsArray().Value;
				Test.Assert(arr.Count == 3, scope $"Should have 3 items from original array. Got: {arr.Count}");
				
				int64 firstItem = arr[0];
				Test.Assert(firstItem == 1, 
					scope $"First item should be 1 (from original), got: {firstItem}");
			}
		}

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
				
				Test.Assert(arr.Count == 2, 
					scope $"Should have 2 items from original array. Got: {arr.Count}");
			}
		}

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
		}

		{
			let jsonWithDuplicates = "{\"items\":[1,2],\"items\":[3,4]}";

			var config = DeserializerConfig() { DuplicateBehavior = .ThrowError };
			var deserializer = scope Deserializer(config);
			var result = deserializer.Deserialize(jsonWithDuplicates);
			defer result.Dispose();

			Test.Assert(result case .Err, "Parsing with duplicate should fail with ThrowError behavior");
		}

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
				Test.Assert(arr.Count == 3, scope $"Should have 3 items. Got: {arr.Count}");
				
				int64 firstItem = arr[0];
				Test.Assert(firstItem == 7, 
					scope $"First item should be 7 (from rewrite), got: {firstItem}");
			}
		}
	}

	[Test(Name = "Remove Methods")]
	public static void T_RemoveMethods()
	{
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
		}

		{
			var json = JsonObject();
			json.Add("key1", JsonString("value1"));
			defer json.Dispose();

			let removed = json.Remove("nonexistent");
			Test.Assert(!removed, "Remove should return false for non-existing key");
			Test.Assert(json.Count == 1, "Count should remain unchanged");
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
		}

		{
			var json = JsonArray();
			json.Add(JsonString("first"));
			json.Add(JsonString("second"));
			json.Add(JsonString("third"));
			defer json.Dispose();

			Test.Assert(json.Count == 3, "Should have 3 items initially");
			
			json.RemoveAt(1);
			Test.Assert(json.Count == 2, scope $"Should have 2 items after removal. Got: {json.Count}");
			
			StringView first = json[0];
			StringView second = json[1];
			Test.Assert(first == "first", scope $"First item should be 'first'. Got: {first}");
			Test.Assert(second == "third", scope $"Second item should be 'third'. Got: {second}");
		}

		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			json.Add(JsonNumber((int64)2));
			json.Add(JsonNumber((int64)3));
			defer json.Dispose();

			json.RemoveAt(0);
			Test.Assert(json.Count == 2, "Should have 2 items");
			int64 val = json[0];
			Test.Assert(val == 2, scope $"First item should be 2. Got: {val}");

			json.RemoveAt(1);
			Test.Assert(json.Count == 1, "Should have 1 item");
			val = json[0];
			Test.Assert(val == 2, scope $"Remaining item should be 2. Got: {val}");
		}

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
		}

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
		}

		// Test 8: JsonArray.RemoveAt - nested array (ensure proper disposal)
		{
			var json = JsonArray();
			json.Add(JsonArray() { JsonNumber((int64)1), JsonNumber((int64)2) });
			json.Add(JsonString("keep"));
			defer json.Dispose();

			Test.Assert(json.Count == 2, "Should have 2 items initially");
			
			json.RemoveAt(0);
			Test.Assert(json.Count == 1, "Should have 1 item after removal");
			
			StringView remaining = json[0];
			Test.Assert(remaining == "keep", scope $"Remaining item should be 'keep'. Got: {remaining}");
		}

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
		}

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
		}
	}

	[Test(Name = "Regression: object indexer copies the key it stores")]
	public static void T_IndexerKeyOwnership()
	{
		var json = JsonObject();
		json[scope String("a")] = JsonNumber((int64)1);

		let output = scope String();
		Test.Assert(Json.Serialize(json, output) case .Ok, "serialize must succeed");
		Test.Assert(output == "{\"a\":1}", scope $"got '{output}'");

		json.Dispose();
	}

	[Test(Name = "Regression: typed accessors reject the wrong type")]
	public static void T_TypedAccessors()
	{
		var result = Json.Deserialize("{\"text\":\"hello\",\"flag\":true,\"count\":7}");
		defer result.Dispose();

		Test.Assert(result case .Ok(let doc), "parse must succeed");

		var root = doc;
		var text = root.TryGetRef("text").Value;
		Test.Assert(text.AsString() case .Ok(let str), "text must read as a string");
		Test.Assert(str == "hello", scope $"got '{str}'");
		Test.Assert(text.AsNumber() case .Err, "a string must not read as a number");

		var flag = root.TryGetRef("flag").Value;
		Test.Assert(flag.AsBool() case .Ok(let boolean) && boolean, "flag must read as true");
		Test.Assert(flag.AsString() case .Err, "a bool must not read as a string");

		var count = root.TryGetRef("count").Value;
		Test.Assert(count.AsNumber() case .Ok(let number) && (number == 7), "count must read as 7");
		Test.Assert(count.AsBool() case .Err, "a number must not read as a bool");
	}

	[Test(Name = "JsonObject Keys and Values enumerate every stored entry")]
	public static void T_ObjectKeysAndValues()
	{
		var json = JsonObject();
		json.Add("alpha", JsonNumber((int64)1));
		json.Add("beta", JsonNumber((int64)2));
		json.Add("gamma", JsonNumber((int64)3));
		defer json.Dispose();

		int keyCount = 0;
		bool sawBeta = false;
		for (let key in json.Keys)
		{
			keyCount++;
			if (key == "beta")
				sawBeta = true;
		}

		Test.Assert(keyCount == 3, scope $"Keys should yield 3 entries, got {keyCount}");
		Test.Assert(sawBeta, "Keys should include 'beta'");

		int valueCount = 0;
		int64 total = 0;
		for (let value in json.Values)
		{
			int64 number = value;
			total += number;
			valueCount++;
		}

		Test.Assert(valueCount == 3, scope $"Values should yield 3 entries, got {valueCount}");
		Test.Assert(total == 6, scope $"Values should total 6, got {total}");
	}
}
