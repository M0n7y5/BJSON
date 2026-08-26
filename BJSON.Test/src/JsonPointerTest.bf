using System;
using System.IO;
using System.Diagnostics;
using BJSON;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON.Test
{
	class JsonPointerTest
	{
		[Test(Name = "JSON Pointer (RFC 6901)")]
		public static void T_JsonPointer()
		{
			// RFC 6901 example document
			let jsonString = "{\"foo\": [\"bar\", \"baz\"], \"\": 0, \"a/b\": 1, \"c%d\": 2, \"e^f\": 3, \"g|h\": 4, \"i\\\\j\": 5, \"k\\\"l\": 6, \" \": 7, \"m~n\": 8, \"nested\": {\"deep\": {\"value\": \"found\"}}, \"users\": [{\"name\": \"Alice\", \"age\": 30}, {\"name\": \"Bob\", \"age\": 25}]}";

			var result = Json.Deserialize(jsonString);
			defer result.Dispose();

			Test.Assert(result case .Ok, "Failed to parse JSON");
			let json = result.Value;

			{
				let ptr = json.GetByPointer("");
				Test.Assert(ptr case .Ok, "Empty pointer should return root");
				Test.Assert(ptr.Value.IsObject(), "Root should be object");
			}

			{
				let ptr = json.GetByPointer("/foo");
				Test.Assert(ptr case .Ok, "'/foo' should resolve");
				Test.Assert(ptr.Value.IsArray(), "'/foo' should be array");
			}

			{
				let ptr = json.GetByPointer("/foo/0");
				Test.Assert(ptr case .Ok, "'/foo/0' should resolve");
				Test.Assert((StringView)ptr.Value == "bar", scope $"'/foo/0' should be 'bar', got '{(StringView)ptr.Value}'");
			}

			{
				let ptr = json.GetByPointer("/foo/1");
				Test.Assert(ptr case .Ok, "'/foo/1' should resolve");
				Test.Assert((StringView)ptr.Value == "baz", "'/foo/1' should be 'baz'");
			}

			{
				let ptr = json.GetByPointer("/");
				Test.Assert(ptr case .Ok, "'/' should resolve to empty key");
				Test.Assert((int)ptr.Value == 0, "'/' should be 0");
			}

			{
				let ptr = json.GetByPointer("/a~1b");
				Test.Assert(ptr case .Ok, "'/a~1b' should resolve to 'a/b' key");
				Test.Assert((int)ptr.Value == 1, "'/a~1b' should be 1");
			}

			{
				let ptr = json.GetByPointer("/m~0n");
				Test.Assert(ptr case .Ok, "'/m~0n' should resolve to 'm~n' key");
				Test.Assert((int)ptr.Value == 8, "'/m~0n' should be 8");
			}

			// Test 7: Special characters (not escaped per RFC 6901)
			{
				let ptr = json.GetByPointer("/c%d");
				Test.Assert(ptr case .Ok, "'/c%d' should resolve");
				Test.Assert((int)ptr.Value == 2, "'/c%d' should be 2");
			}

			{
				let ptr = json.GetByPointer("/e^f");
				Test.Assert(ptr case .Ok, "'/e^f' should resolve");
				Test.Assert((int)ptr.Value == 3, "'/e^f' should be 3");
			}

			{
				let ptr = json.GetByPointer("/g|h");
				Test.Assert(ptr case .Ok, "'/g|h' should resolve");
				Test.Assert((int)ptr.Value == 4, "'/g|h' should be 4");
			}

			{
				let ptr = json.GetByPointer("/i\\j");
				Test.Assert(ptr case .Ok, "'/i\\j' should resolve");
				Test.Assert((int)ptr.Value == 5, "'/i\\j' should be 5");
			}

			{
				let ptr = json.GetByPointer("/k\"l");
				Test.Assert(ptr case .Ok, "'/k\"l' should resolve");
				Test.Assert((int)ptr.Value == 6, "'/k\"l' should be 6");
			}

			{
				let ptr = json.GetByPointer("/ ");
				Test.Assert(ptr case .Ok, "'/ ' should resolve to space key");
				Test.Assert((int)ptr.Value == 7, "'/ ' should be 7");
			}

			{
				let ptr = json.GetByPointer("/nested/deep/value");
				Test.Assert(ptr case .Ok, "'/nested/deep/value' should resolve");
				Test.Assert((StringView)ptr.Value == "found", "'/nested/deep/value' should be 'found'");
			}

			{
				let ptr = json.GetByPointer("/users/0/name");
				Test.Assert(ptr case .Ok, "'/users/0/name' should resolve");
				Test.Assert((StringView)ptr.Value == "Alice", "'/users/0/name' should be 'Alice'");
			}

			{
				let ptr = json.GetByPointer("/users/1/age");
				Test.Assert(ptr case .Ok, "'/users/1/age' should resolve");
				Test.Assert((int)ptr.Value == 25, "'/users/1/age' should be 25");
			}

			{
				let ptr = json.GetByPointer("foo");
				Test.Assert(ptr case .Err(.InvalidPointer), "'foo' should fail (no leading /)");
			}

			{
				let ptr = json.GetByPointer("/nonexistent");
				Test.Assert(ptr case .Err(.KeyNotFound(let key)), "'/nonexistent' should fail");
			}

			{
				let ptr = json.GetByPointer("/foo/99");
				Test.Assert(ptr case .Err(.IndexOutOfBounds(let idx)), "'/foo/99' should fail (out of bounds)");
			}

			{
				let ptr = json.GetByPointer("/foo/abc");
				Test.Assert(ptr case .Err(.InvalidArrayIndex(let tok)), "'/foo/abc' should fail (not a number)");
			}

			{
				let ptr = json.GetByPointer("/foo/01");
				Test.Assert(ptr case .Err(.InvalidArrayIndex(let tok)), "'/foo/01' should fail (leading zero)");
			}

			{
				let ptr = json.GetByPointer("/foo/0/invalid");
				Test.Assert(ptr case .Err(.TypeMismatch(let exp, let act)), "'/foo/0/invalid' should fail (string is not traversable)");
			}

			{
				let ptr = json.GetByPointer("/~2");
				Test.Assert(ptr case .Err(.InvalidEscapeSequence), "'/~2' should fail (invalid escape)");
			}

			{
				let ptr = json.GetByPointer("/~");
				Test.Assert(ptr case .Err(.InvalidEscapeSequence), "'/~' should fail (incomplete escape)");
			}

			{
				let ptr = json.GetByPointer("/foo/-");
				Test.Assert(ptr case .Err(.IndexOutOfBounds(let idx)), "'/foo/-' should fail for read (append reference)");
			}

			{
				let val = json.GetByPointerOrDefault("/users/0/name");
				Test.Assert((StringView)val == "Alice", "GetByPointerOrDefault should return value when found");
			}

			{
				// Use non-generic overload with JsonValue cast
				let val = json.GetByPointerOrDefault("/nonexistent", (JsonValue)JsonNumber(42));
				Test.Assert((int)val == 42, "GetByPointerOrDefault should return default when not found");
			}

			{
				let val = json.GetByPointerOrDefault("invalid-pointer");  // No leading /
				Test.Assert(val.IsNull(), "GetByPointerOrDefault should return default (null) for invalid pointer");
			}
		}

		[Test(Name = "JSON Pointer Escape/Build")]
		public static void T_JsonPointerEscape()
		{
			{
				let output = scope String();
				JsonPointer.Escape("normal", output);
				Test.Assert(output == "normal", "'normal' should not change");
			}

			{
				let output = scope String();
				JsonPointer.Escape("a/b", output);
				Test.Assert(output == "a~1b", "'a/b' should become 'a~1b'");
			}

			{
				let output = scope String();
				JsonPointer.Escape("m~n", output);
				Test.Assert(output == "m~0n", "'m~n' should become 'm~0n'");
			}

			{
				let output = scope String();
				JsonPointer.Escape("~a/b~", output);
				Test.Assert(output == "~0a~1b~0", "'~a/b~' should become '~0a~1b~0'");
			}

			{
				let output = scope String();
				JsonPointer.Build("users", output);
				Test.Assert(output == "/users", "Build single segment should produce '/users'");
			}

			{
				let output = scope String();
				JsonPointer.Build("a/b", output);
				Test.Assert(output == "/a~1b", "Build with slash should escape to '/a~1b'");
			}

			{
				let output = scope String();
				StringView[3] segments = .("users", "0", "name");
				JsonPointer.Build(segments, output);
				Test.Assert(output == "/users/0/name", "Build multiple segments should produce '/users/0/name'");
			}

			{
				let output = scope String();
				StringView[2] segments = .("a/b", "m~n");
				JsonPointer.Build(segments, output);
				Test.Assert(output == "/a~1b/m~0n", "Build with special chars should escape properly");
			}
		}
	}
}
