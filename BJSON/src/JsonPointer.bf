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

		public void ToString(String str)
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
		/// Resolves a JSON Pointer against a JSON value.
		/// @param root The root JSON value to navigate from.
		/// @param pointer The JSON Pointer string (e.g., "/users/0/name").
		/// @returns The resolved JsonValue or an error if the pointer is invalid or path doesn't exist.
		public static Result<JsonValue, JsonPointerError> Resolve(JsonValue root, StringView pointer)
		{
			// Empty pointer references the whole document
			if (pointer.IsEmpty)
				return .Ok(root);

			// Must start with '/'
			if (pointer[0] != '/')
				return .Err(.InvalidPointer);

			var current = root;
			var remaining = pointer.Substring(1); // Skip leading '/'

			while (!remaining.IsEmpty)
			{
				// Find next '/' or end of string
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

				// Unescape the token
				let unescaped = scope String();
				if (Unescape(token, unescaped) case .Err)
					return .Err(.InvalidEscapeSequence);

				// Navigate based on current type
				if (current.IsObject())
				{
					if (current.TryGet(unescaped) case .Ok(let val))
						current = val;
					else
						return .Err(.KeyNotFound(token));
				}
				else if (current.IsArray())
				{
					// Special case: "-" references the (nonexistent) element after the last array element
					// For reading, this is an error (used for appending in JSON Patch)
					if (token == "-")
						return .Err(.IndexOutOfBounds(-1));

					// Parse array index
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
					// Can't navigate into primitives
					return .Err(.TypeMismatch("object or array", current.type));
				}
			}

			return .Ok(current);
		}

		/// Tries to resolve a JSON Pointer, returning a default value on failure.
		/// @param root The root JSON value to navigate from.
		/// @param pointer The JSON Pointer string.
		/// @param defaultValue The value to return if resolution fails.
		/// @returns The resolved JsonValue or defaultValue if the pointer is invalid or path doesn't exist.
		public static JsonValue ResolveOrDefault(JsonValue root, StringView pointer, JsonValue defaultValue = default)
		{
			if (Resolve(root, pointer) case .Ok(let val))
				return val;
			return defaultValue;
		}

		/// Unescapes a JSON Pointer token.
		/// Per RFC 6901: ~1 becomes /, ~0 becomes ~
		/// Order matters: ~1 must be processed before ~0.
		private static Result<void> Unescape(StringView token, String output)
		{
			var i = 0;
			while (i < token.Length)
			{
				let c = token[i];
				if (c == '~')
				{
					if (i + 1 >= token.Length)
						return .Err; // Incomplete escape

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
						return .Err; // Invalid escape sequence
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

		/// Escapes a string for use in a JSON Pointer.
		/// Per RFC 6901: ~ becomes ~0, / becomes ~1
		/// Order matters: ~ must be escaped before /.
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

		/// Parses an array index from a JSON Pointer token.
		/// Per RFC 6901: Index must be "0" or a non-negative integer without leading zeros.
		private static Result<int> ParseArrayIndex(StringView token)
		{
			if (token.IsEmpty)
				return .Err;

			// Leading zeros not allowed (except for "0" itself)
			if (token.Length > 1 && token[0] == '0')
				return .Err;

			// Must be all digits
			for (let c in token)
			{
				if (c < '0' || c > '9')
					return .Err;
			}

			// Parse the integer
			if (Int32.Parse(token) case .Ok(let val))
				return .Ok(val);

			return .Err;
		}

		/// Gets a human-readable type name for error messages.
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

		/// Builds a JSON Pointer string from path segments.
		/// @param segments Array of path segments (keys or indices as strings).
		/// @param output The string to append the pointer to.
		public static void Build(Span<StringView> segments, String output)
		{
			for (let segment in segments)
			{
				output.Append('/');
				Escape(segment, output);
			}
		}

		/// Builds a JSON Pointer string from a single path segment.
		/// @param segment A single path segment.
		/// @param output The string to append the pointer to.
		public static void Build(StringView segment, String output)
		{
			output.Append('/');
			Escape(segment, output);
		}
	}
}
