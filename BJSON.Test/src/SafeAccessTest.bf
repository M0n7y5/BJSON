using System;
using BJSON.Models;
using System.IO;

namespace BJSON.Test;

/// Tests for safe access methods (TryGet, GetOrDefault):
/// - JsonObject.TryGet and GetOrDefault
/// - JsonArray.TryGet and GetOrDefault
/// - JsonValue base class TryGet and TryGetRef
/// - JsonValue.Empty
/// - Type mismatch handling
/// - Nested safe access
class SafeAccessTest
{
	[Test(Name = "Safe Access Methods")]
	public static void T_SafeAccessMethods()
	{
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
		}

		{
			let json = JsonObject() { ("name", "test") };
			defer json.Dispose();

			let result = json.TryGet("missing");
			Test.Assert(result case .Err, "TryGet should fail for missing key");
		}

		{
			let json = JsonObject() { ("value", 42) };
			defer json.Dispose();

			let val = json.GetOrDefault("value");
			int num = val;
			Test.Assert(num == 42, scope $"Value mismatch. Got: {num}");
		}

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
		}

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
		}

		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			defer json.Dispose();

			Test.Assert(json.TryGet(-1) case .Err, "TryGet should fail for negative index");
			Test.Assert(json.TryGet(1) case .Err, "TryGet should fail for index >= Count");
			Test.Assert(json.TryGet(100) case .Err, "TryGet should fail for large index");
		}

		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)10));
			json.Add(JsonNumber((int64)20));
			defer json.Dispose();

			let val = json.GetOrDefault(1);
			int num = val;
			Test.Assert(num == 20, scope $"Value mismatch. Got: {num}");
		}

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
		}

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
		}

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
		}

		{
			var json = JsonArray();
			json.Add(JsonNumber((int64)1));
			defer json.Dispose();

			// Cast to JsonValue to use base class TryGet
			JsonValue val = json;
			let tryResult = val.TryGet("key");
			Test.Assert(tryResult case .Err, "TryGet string on array should fail");
		}

		{
			let json = JsonObject() { ("name", "test") };
			defer json.Dispose();

			// Cast to JsonValue to use base class TryGet
			JsonValue val = json;
			let tryResult = val.TryGet(0);
			Test.Assert(tryResult case .Err, "TryGet int on object should fail");
		}

		{
			var arr = JsonArray();
			arr.Add(JsonNumber((int64)1));
			defer arr.Dispose();

			JsonValue val = arr;
			var defaultObj = JsonObject() { ("default", true) };
			defer defaultObj.Dispose();
			let result = val.GetOrDefault("key", (JsonValue)defaultObj);
			
			Test.Assert(result.IsObject(), "Should return default object on type mismatch");
		}

		{
			var result = Json.Deserialize("{\"outer\":{\"inner\":{\"value\":42}}}");
			defer result.Dispose();

			Test.Assert(result case .Ok, "Parse should succeed");
			if (result case .Ok(let json))
			{
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

				let outerResult = json.TryGet("outer");
				if (outerResult case .Ok(let outerVal))
				{
					let innerMissing = outerVal.TryGet("nonexistent");
					Test.Assert(innerMissing case .Err, "Missing nested key should fail");
				}
			}
		}

		// Test 15: Generic GetOrDefault<T> - no allocation for primitives
		{
			let json = JsonObject() { ("name", "Alice"), ("age", 30), ("active", true) };
			defer json.Dispose();

			StringView name = json.GetOrDefault<StringView>("name", "Unknown");
			Test.Assert(name == "Alice", scope $"Name mismatch. Got: {name}");

			StringView missing = json.GetOrDefault<StringView>("nonexistent", "Default");
			Test.Assert(missing == "Default", scope $"Should return default. Got: {missing}");

			int age = json.GetOrDefault<int>("age", 0);
			Test.Assert(age == 30, scope $"Age mismatch. Got: {age}");

			int missingAge = json.GetOrDefault<int>("unknown", 99);
			Test.Assert(missingAge == 99, scope $"Should return default. Got: {missingAge}");

			bool active = json.GetOrDefault<bool>("active", false);
			Test.Assert(active == true, "Active should be true");
		}

		{
			var json = JsonArray();
			json.Add(JsonString("first"));
			json.Add(JsonNumber((int64)42));
			defer json.Dispose();

			StringView first = json.GetOrDefault<StringView>(0, "none");
			Test.Assert(first == "first", scope $"First mismatch. Got: {first}");

			int num = json.GetOrDefault<int>(1, 0);
			Test.Assert(num == 42, scope $"Number mismatch. Got: {num}");

			StringView oob = json.GetOrDefault<StringView>(99, "default");
			Test.Assert(oob == "default", scope $"Should return default. Got: {oob}");
		}

		{
			var json = JsonArray();
			json.Add(JsonString("first"));
			json.Add(JsonString("second"));
			defer json.Dispose();

			JsonValue val = json;
			Test.Assert(val.TryGetRef(1) case .Ok(let slot), "TryGetRef should resolve an index in range");

			var stored = *slot;
			Test.Assert(stored.AsString() case .Ok(let str), "The stored element should read as a string");
			Test.Assert(str == "second", scope $"Value mismatch. Got: {str}");

			Test.Assert(val.TryGetRef(2) case .Err, "TryGetRef should fail for index >= Count");
			Test.Assert(val.TryGetRef(-1) case .Err, "TryGetRef should fail for a negative index");
		}

		{
			let obj = JsonObject() { ("name", "test") };
			defer obj.Dispose();

			JsonValue val = obj;
			Test.Assert(val.TryGetRef(0) case .Err, "TryGetRef by index should fail on an object");
		}

		{
			var empty = JsonValue.Empty;

			Test.Assert(empty.type == .NULL, scope $"Empty should carry the null tag. Got: {empty.type}");
			Test.Assert(empty.IsNull(), "Empty should report IsNull");
			Test.Assert(empty.TryGet("key") case .Err, "TryGet by key on Empty should fail");
			Test.Assert(empty.TryGet(0) case .Err, "TryGet by index on Empty should fail");
		}
	}
}
