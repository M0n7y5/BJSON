using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;

namespace BJSON.Test;

/// Tests for safe access methods (TryGet, GetOrDefault):
/// - JsonObject.TryGet and GetOrDefault
/// - JsonArray.TryGet and GetOrDefault
/// - JsonValue base class TryGet
/// - Type mismatch handling
/// - Nested safe access
class SafeAccessTest
{
	[Test(Name = "Safe Access Methods")]
	public static void T_SafeAccessMethods()
	{
		Debug.WriteLine("Safe Access Methods tests ...");

		// Test 1: JsonObject.TryGet - existing key
		{
			let json = JsonObject() { ("name", "test"), ("value", 42) };
			defer json.Dispose();

			let result = json.TryGet("name");
			Test.Assert(result case .Ok, "TryGet should succeed for existing key");
			if (result case .Ok(let val))
			{
				StringView str = val;
				Test.Assert(str == "test", scope $"Value mismatch. Got: {str}");
			}

			Debug.WriteLine("  Test 1 (JsonObject.TryGet existing): PASSED");
		}

		// Test 2: JsonObject.TryGet - missing key
		{
			let json = JsonObject() { ("name", "test") };
			defer json.Dispose();

			let result = json.TryGet("missing");
			Test.Assert(result case .Err, "TryGet should fail for missing key");

			Debug.WriteLine("  Test 2 (JsonObject.TryGet missing): PASSED");
		}

		// Test 3: JsonObject.GetOrDefault - existing key
		{
			let json = JsonObject() { ("value", 42) };
			defer json.Dispose();

			let val = json.GetOrDefault("value");
			int num = val;
			Test.Assert(num == 42, scope $"Value mismatch. Got: {num}");

			Debug.WriteLine("  Test 3 (JsonObject.GetOrDefault existing): PASSED");
		}

		// Test 4: JsonObject.GetOrDefault - missing key returns default
		{
			let json = JsonObject() { ("name", "test") };
			defer json.Dispose();

			let val = json.GetOrDefault("missing");
			Test.Assert(val.IsNull() || val.type == .NULL, "Missing key should return null default");

			// Test with custom default (cast to JsonValue to use non-generic overload)
			JsonValue defaultVal = JsonNumber((int64)99);
			let val2 = json.GetOrDefault("missing", defaultVal);
			int num = val2;
			Test.Assert(num == 99, scope $"Should return custom default. Got: {num}");

			Debug.WriteLine("  Test 4 (JsonObject.GetOrDefault missing): PASSED");
		}

		// Test 5: JsonArray.TryGet - valid index
		{
			var json = JsonArray();
			json.Add(JsonString("first"));
			json.Add(JsonString("second"));
			json.Add(JsonString("third"));
			defer json.Dispose();

			let result = json.TryGet(1);
			Test.Assert(result case .Ok, "TryGet should succeed for valid index");
			if (result case .Ok(let val))
			{
				StringView str = val;
				Test.Assert(str == "second", scope $"Value mismatch. Got: {str}");
			}

			Debug.WriteLine("  Test 5 (JsonArray.TryGet valid): PASSED");
		}

		// Test 6: JsonArray.TryGet - out of bounds
		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			defer json.Dispose();

			Test.Assert(json.TryGet(-1) case .Err, "TryGet should fail for negative index");
			Test.Assert(json.TryGet(1) case .Err, "TryGet should fail for index >= Count");
			Test.Assert(json.TryGet(100) case .Err, "TryGet should fail for large index");

			Debug.WriteLine("  Test 6 (JsonArray.TryGet out of bounds): PASSED");
		}

		// Test 7: JsonArray.GetOrDefault - valid index
		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)10));
			json.Add(JsonNumber((int64)20));
			defer json.Dispose();

			let val = json.GetOrDefault(1);
			int num = val;
			Test.Assert(num == 20, scope $"Value mismatch. Got: {num}");

			Debug.WriteLine("  Test 7 (JsonArray.GetOrDefault valid): PASSED");
		}

		// Test 8: JsonArray.GetOrDefault - out of bounds returns default
		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			defer json.Dispose();

			let val = json.GetOrDefault(5);
			Test.Assert(val.IsNull() || val.type == .NULL, "Out of bounds should return null default");

			// Test with custom default (cast to JsonValue to use non-generic overload)
			JsonValue defaultVal = JsonNumber((int64)999);
			let val2 = json.GetOrDefault(-1, defaultVal);
			int num = val2;
			Test.Assert(num == 999, scope $"Should return custom default. Got: {num}");

			Debug.WriteLine("  Test 8 (JsonArray.GetOrDefault out of bounds): PASSED");
		}

		// Test 9: Base JsonValue.TryGet for objects
		{
			var result = Json.Deserialize("{\"key\":\"value\"}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parse should succeed");
			if (result case .Ok(let json))
			{
				let tryResult = json.TryGet("key");
				Test.Assert(tryResult case .Ok, "TryGet on parsed object should succeed");

				let missingResult = json.TryGet("missing");
				Test.Assert(missingResult case .Err, "TryGet for missing key should fail");
			}

			Debug.WriteLine("  Test 9 (JsonValue.TryGet for objects): PASSED");
		}

		// Test 10: Base JsonValue.TryGet for arrays
		{
			var result = Json.Deserialize("[1, 2, 3]");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parse should succeed");
			if (result case .Ok(let json))
			{
				let tryResult = json.TryGet(0);
				Test.Assert(tryResult case .Ok, "TryGet on parsed array should succeed");

				let outOfBounds = json.TryGet(10);
				Test.Assert(outOfBounds case .Err, "TryGet for out of bounds should fail");
			}

			Debug.WriteLine("  Test 10 (JsonValue.TryGet for arrays): PASSED");
		}

		// Test 11: Type mismatch - TryGet string key on array
		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			defer json.Dispose();

			// Cast to JsonValue to use base class TryGet
			JsonValue val = json;
			let tryResult = val.TryGet("key");
			Test.Assert(tryResult case .Err, "TryGet string on array should fail");

			Debug.WriteLine("  Test 11 (type mismatch array): PASSED");
		}

		// Test 12: Type mismatch - TryGet int index on object
		{
			let json = JsonObject() { ("name", "test") };
			defer json.Dispose();

			// Cast to JsonValue to use base class TryGet
			JsonValue val = json;
			let tryResult = val.TryGet(0);
			Test.Assert(tryResult case .Err, "TryGet int on object should fail");

			Debug.WriteLine("  Test 12 (type mismatch object): PASSED");
		}

		// Test 13: GetOrDefault with type mismatch returns default
		{
			var arr = JsonArray();
			arr.Add(JsonNumber((int64)1));
			defer arr.Dispose();

			JsonValue val = arr;
			var defaultObj = JsonObject() { ("default", true) };
			defer defaultObj.Dispose();
			let result = val.GetOrDefault("key", (JsonValue)defaultObj);
			
			// Should return the default because arr is not an object
			Test.Assert(result.IsObject(), "Should return default object on type mismatch");

			Debug.WriteLine("  Test 13 (GetOrDefault type mismatch): PASSED");
		}

		// Test 14: Nested safe access
		{
			var result = Json.Deserialize("{\"outer\":{\"inner\":{\"value\":42}}}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parse should succeed");
			if (result case .Ok(let json))
			{
				// Chain TryGet calls safely
				if (json.TryGet("outer") case .Ok(let outer))
				{
					if (outer.TryGet("inner") case .Ok(let inner))
					{
						if (inner.TryGet("value") case .Ok(let val))
						{
							int num = val;
							Test.Assert(num == 42, scope $"Nested value mismatch. Got: {num}");
						}
					}
				}

				// Missing nested path should fail gracefully
				let outerResult = json.TryGet("outer");
				if (outerResult case .Ok(let outerVal))
				{
					let innerMissing = outerVal.TryGet("nonexistent");
					Test.Assert(innerMissing case .Err, "Missing nested key should fail");
				}
			}

			Debug.WriteLine("  Test 14 (nested safe access): PASSED");
		}

		// Test 15: Generic GetOrDefault<T> - no allocation for primitives
		{
			let json = JsonObject() { ("name", "Alice"), ("age", 30), ("active", true) };
			defer json.Dispose();

			// String access without allocation
			StringView name = json.GetOrDefault<StringView>("name", "Unknown");
			Test.Assert(name == "Alice", scope $"Name mismatch. Got: {name}");

			// Missing key returns primitive default (no allocation)
			StringView missing = json.GetOrDefault<StringView>("nonexistent", "Default");
			Test.Assert(missing == "Default", scope $"Should return default. Got: {missing}");

			// Number access
			int age = json.GetOrDefault<int>("age", 0);
			Test.Assert(age == 30, scope $"Age mismatch. Got: {age}");

			int missingAge = json.GetOrDefault<int>("unknown", 99);
			Test.Assert(missingAge == 99, scope $"Should return default. Got: {missingAge}");

			// Bool access
			bool active = json.GetOrDefault<bool>("active", false);
			Test.Assert(active == true, "Active should be true");

			Debug.WriteLine("  Test 15 (Generic GetOrDefault<T>): PASSED");
		}

		// Test 16: Generic GetOrDefault<T> for arrays
		{
			var json = JsonArray();
			json.Add(JsonString("first"));
			json.Add(JsonNumber((int64)42));
			defer json.Dispose();

			StringView first = json.GetOrDefault<StringView>(0, "none");
			Test.Assert(first == "first", scope $"First mismatch. Got: {first}");

			int num = json.GetOrDefault<int>(1, 0);
			Test.Assert(num == 42, scope $"Number mismatch. Got: {num}");

			// Out of bounds returns default
			StringView oob = json.GetOrDefault<StringView>(99, "default");
			Test.Assert(oob == "default", scope $"Should return default. Got: {oob}");

			Debug.WriteLine("  Test 16 (Generic GetOrDefault<T> for arrays): PASSED");
		}

		// Test 17: Generic GetByPointerOrDefault<T>
		{
			var result = Json.Deserialize("{\"user\":{\"name\":\"Bob\",\"score\":100}}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parse should succeed");
			if (result case .Ok(let json))
			{
				// Successful path access
				StringView name = json.GetByPointerOrDefault<StringView>("/user/name", "Unknown");
				Test.Assert(name == "Bob", scope $"Name mismatch. Got: {name}");

				int score = json.GetByPointerOrDefault<int>("/user/score", 0);
				Test.Assert(score == 100, scope $"Score mismatch. Got: {score}");

				// Missing path returns default (no allocation!)
				StringView missing = json.GetByPointerOrDefault<StringView>("/user/email", "N/A");
				Test.Assert(missing == "N/A", scope $"Should return default. Got: {missing}");

				int missingScore = json.GetByPointerOrDefault<int>("/invalid/path", -1);
				Test.Assert(missingScore == -1, scope $"Should return default. Got: {missingScore}");
			}

			Debug.WriteLine("  Test 17 (Generic GetByPointerOrDefault<T>): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
