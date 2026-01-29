using System;
using System.Collections;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON
{
	/// JSON Pointer error types per RFC 6901.
	enum JsonPointerError
	{
		case InvalidPointer;
		case InvalidEscapeSequence;
		case KeyNotFound(StringView key);
		case IndexOutOfBounds(int index);
		case InvalidArrayIndex(StringView token);
		case TypeMismatch(StringView expected, JsonType actual);

		public override void ToString(String str)
		{
			switch (this)
			{
			case InvalidPointer:
				str.Append("Invalid JSON Pointer syntax. Must be empty or start with '/'.");
			case InvalidEscapeSequence:
				str.Append("Invalid escape sequence in JSON Pointer. Use ~0 for ~ and ~1 for /.");
			case KeyNotFound(let key):
				str.AppendF("Key '{}' not found in object.", key);
			case IndexOutOfBounds(let index):
				str.AppendF("Array index {} is out of bounds.", index);
			case InvalidArrayIndex(let token):
				str.AppendF("Invalid array index '{}'. Must be a non-negative integer or '-'.", token);
			case TypeMismatch(let expected, let actual):
				str.AppendF("Type mismatch: expected {}, got {}.", expected, actual);
			}
		}
	}

	/// Provides JSON Pointer (RFC 6901) functionality for navigating JSON structures.
	/// 
	/// JSON Pointer defines a string syntax for identifying a specific value within a JSON document.
	/// Examples:
	///   - "" (empty string) - references the whole document
	///   - "/foo" - references the "foo" member of the root object
	///   - "/foo/0" - references the first element of the "foo" array
	///   - "/a~1b" - references the "a/b" member (/ is escaped as ~1)
	///   - "/m~0n" - references the "m~n" member (~ is escaped as ~0)
	static class JsonPointer
	{
		public static Result<JsonValue, JsonPointerError> Resolve(JsonValue root, StringView pointer)
		{
			if (pointer.IsEmpty)
				return .Ok(root);

			if (pointer[0] != '/')
				return .Err(.InvalidPointer);

			var current = root;
			var remaining = pointer.Substring(1);

			while (!remaining.IsEmpty)
			{
				int nextSlash = remaining.IndexOf('/');
				StringView token;

				if (nextSlash == -1)
				{
					token = remaining;
					remaining = "";
				}
				else
				{
					token = remaining.Substring(0, nextSlash);
					remaining = remaining.Substring(nextSlash + 1);
				}

				let unescaped = scope String();
				if (Unescape(token, unescaped) case .Err)
					return .Err(.InvalidEscapeSequence);

				if (current.IsObject())
				{
					if (current.TryGet(unescaped) case .Ok(let val))
						current = val;
					else
						return .Err(.KeyNotFound(token));
				}
				else if (current.IsArray())
				{
					if (token == "-")
						return .Err(.IndexOutOfBounds(-1));

					let index = ParseArrayIndex(token);
					if (index case .Err)
						return .Err(.InvalidArrayIndex(token));

					if (current.TryGet(index.Value) case .Ok(let val))
						current = val;
					else
						return .Err(.IndexOutOfBounds(index.Value));
				}
				else
				{
					return .Err(.TypeMismatch("object or array", current.type));
				}
			}

			return .Ok(current);
		}

		public static JsonValue ResolveOrDefault(JsonValue root, StringView pointer, JsonValue defaultValue = default)
		{
			if (Resolve(root, pointer) case .Ok(let val))
				return val;
			return defaultValue;
		}

		public static T ResolveOrDefault<T>(JsonValue root, StringView pointer, T defaultValue) where T : var
		{
			if (Resolve(root, pointer) case .Ok(let val))
				return (T)val;
			return defaultValue;
		}

		private static Result<void> Unescape(StringView token, String output)
		{
			var i = 0;
			while (i < token.Length)
			{
				let c = token[i];
				if (c == '~')
				{
					if (i + 1 >= token.Length)
						return .Err;

					let next = token[i + 1];
					if (next == '1')
					{
						output.Append('/');
						i += 2;
					}
					else if (next == '0')
					{
						output.Append('~');
						i += 2;
					}
					else
					{
						return .Err;
					}
				}
				else
				{
					output.Append(c);
					i++;
				}
			}
			return .Ok;
		}

		public static void Escape(StringView input, String output)
		{
			for (let c in input)
			{
				if (c == '~')
					output.Append("~0");
				else if (c == '/')
					output.Append("~1");
				else
					output.Append(c);
			}
		}

		private static Result<int> ParseArrayIndex(StringView token)
		{
			if (token.IsEmpty)
				return .Err;

			if (token.Length > 1 && token[0] == '0')
				return .Err;

			for (let c in token)
			{
				if (c < '0' || c > '9')
					return .Err;
			}

			if (Int32.Parse(token) case .Ok(let val))
				return .Ok(val);

			return .Err;
		}

		private static StringView GetTypeName(JsonValue value)
		{
			switch (value.type)
			{
			case .NULL: return "null";
			case .BOOL: return "boolean";
			case .NUMBER, .NUMBER_SIGNED, .NUMBER_UNSIGNED: return "number";
			case .STRING: return "string";
			case .OBJECT: return "object";
			case .ARRAY: return "array";
			default: return "unknown";
			}
		}

		public static void Build(Span<StringView> segments, String output)
		{
			for (let segment in segments)
			{
				output.Append('/');
				Escape(segment, output);
			}
		}

		public static void Build(StringView segment, String output)
		{
			output.Append('/');
			Escape(segment, output);
		}
	}
}
