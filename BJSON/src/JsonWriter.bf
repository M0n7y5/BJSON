using BJSON.Models;
using System;
using System.IO;
using BJSON.Constants;
using BJSON.Enums;
namespace BJSON
{
	class JsonWriter
	{
		private const int cMaximumDepth = 200;

		private JsonWriterOptions options;
		private int depth = 0;
		private int nesting = 0;
		private Stream stream;

		public this()
		{
			this.options = .();
		}

		public this(JsonWriterOptions options)
		{
			this.options = options;
		}

		/// Appends a string to the buffer with proper JSON escaping.
		/// Used by comptime-generated serialization code.
		/// @param buffer The string buffer to append to.
		/// @param str The string to escape and append.
		public static void AppendEscaped(String buffer, StringView str)
		{
			for (let c in str)
			{
				let escapeChar = JsonEscapes.GetEscapeChar(c);

				if (escapeChar != 0)
				{
					buffer.Append('\\');
					buffer.Append(escapeChar);
				}
				else if ((uint8)c < 0x20)
				{
					buffer.Append('\\');
					buffer.Append('u');
					buffer.Append('0');
					buffer.Append('0');
					let highNibble = ((uint8)c >> 4) & 0x0F;
					let lowNibble = (uint8)c & 0x0F;
					buffer.Append(highNibble < 10 ? (char8)('0' + highNibble) : (char8)('a' + highNibble - 10));
					buffer.Append(lowNibble < 10 ? (char8)('0' + lowNibble) : (char8)('a' + lowNibble - 10));
				}
				else
				{
					buffer.Append(c);
				}
			}
		}

		/// Writes text to a stream verbatim.
		/// Used by comptime-generated serialization code for structural output.
		/// @param stream The stream to write to.
		/// @param text The text to write.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		[Inline]
		public static Result<void, JsonSerializationError> WriteRaw(Stream stream, StringView text)
		{
			if (stream.WriteStrUnsized(text) case .Err)
				return .Err(.StreamWriteFailed);

			return .Ok;
		}

		/// Writes a single character to a stream verbatim.
		/// Used by comptime-generated serialization code for structural output.
		/// @param stream The stream to write to.
		/// @param c The character to write.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		[Inline]
		public static Result<void, JsonSerializationError> WriteChar(Stream stream, char8 c)
		{
			if (stream.Write<char8>(c) case .Err)
				return .Err(.StreamWriteFailed);

			return .Ok;
		}

		/// Writes a string to a stream with proper JSON escaping (without quotes).
		/// Used by comptime-generated serialization code.
		/// @param stream The stream to write to.
		/// @param str The string to escape and write.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteEscaped(Stream stream, StringView str)
		{
			int spanStart = 0;
			int i = 0;

			for (let c in str)
			{
				let escapeChar = JsonEscapes.GetEscapeChar(c);

				if (escapeChar != 0)
				{
					if (i > spanStart)
					{
						Try!(WriteRaw(stream, str.Substring(spanStart, i - spanStart)));
					}

					Try!(WriteChar(stream, '\\'));
					Try!(WriteChar(stream, escapeChar));
					spanStart = i + 1;
				}
				else if ((uint8)c < 0x20)
				{
					if (i > spanStart)
					{
						Try!(WriteRaw(stream, str.Substring(spanStart, i - spanStart)));
					}

					Try!(WriteRaw(stream, "\\u00"));
					let highNibble = ((uint8)c >> 4) & 0x0F;
					let lowNibble = (uint8)c & 0x0F;
					Try!(WriteChar(stream, highNibble < 10 ? (char8)('0' + highNibble) : (char8)('a' + highNibble - 10)));
					Try!(WriteChar(stream, lowNibble < 10 ? (char8)('0' + lowNibble) : (char8)('a' + lowNibble - 10)));
					spanStart = i + 1;
				}

				i++;
			}

			if (i > spanStart)
			{
				Try!(WriteRaw(stream, str.Substring(spanStart, i - spanStart)));
			}

			return .Ok;
		}

		/// Writes a JSON string value to a stream (with surrounding quotes).
		/// Used by comptime-generated serialization code.
		/// @param stream The stream to write to.
		/// @param str The string value to write.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteString(Stream stream, StringView str)
		{
			Try!(WriteChar(stream, '"'));
			Try!(WriteEscaped(stream, str));
			Try!(WriteChar(stream, '"'));

			return .Ok;
		}

		/// Writes a boolean value to a stream.
		/// @param stream The stream to write to.
		/// @param value The boolean value.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteBool(Stream stream, bool value)
		{
			return WriteRaw(stream, value ? TrueLiteral : FalseLiteral);
		}

		/// Writes an integer value to a stream.
		/// @param stream The stream to write to.
		/// @param value The integer value.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteInt(Stream stream, int64 value)
		{
			return WriteRaw(stream, value.ToString(.. scope .()));
		}

		/// Writes an unsigned integer value to a stream.
		/// @param stream The stream to write to.
		/// @param value The unsigned integer value.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteUInt(Stream stream, uint64 value)
		{
			return WriteRaw(stream, value.ToString(.. scope .()));
		}

		/// Writes a floating-point value to a stream.
		/// @param stream The stream to write to.
		/// @param value The floating-point value.
		/// @returns Ok, Err if value is NaN or Infinity, or Err if the write failed.
		public static Result<void, JsonSerializationError> WriteFloat(Stream stream, double value)
		{
			if (value.IsNaN)
				return .Err(.NaNNotAllowed);
			if (value.IsInfinity)
				return .Err(.InfinityNotAllowed);

			char8[32] buff;
			let end = BJSON.Internal.dtoa(value, &buff);

			return WriteRaw(stream, StringView(&buff, end - &buff));
		}

		public Result<void, JsonSerializationError> Write(JsonValue json, Stream stream)
		{
			return Write(json, stream, this.options);
		}

		public Result<void, JsonSerializationError> Write(JsonValue json, Stream stream, JsonWriterOptions options)
		{
			this.options = options;
			this.depth = 0;
			this.nesting = 0;
			this.stream = stream;
			defer { this.stream = null; }

			return WriteInternal(json);
		}

		private Result<void, JsonSerializationError> WriteInternal(JsonValue json)
		{
			switch (json.type)
			{
			case .NULL:
				return WriteNull(json);
			case .BOOL:
				return WriteBoolean(json);
			case .NUMBER:
				return WriteNumber(json);
			case .NUMBER_SIGNED:
				return WriteNumber(json);
			case .NUMBER_UNSIGNED:
				return WriteNumber(json);
			case .STRING:
				return WriteString(json);
			case .ARRAY:
				return WriteArray(json);
			case .OBJECT:
				return WriteObject(json);

			default:
				return .Err(.UnknownType);

			}
		}

		[Inline]
		private Result<void, JsonSerializationError> WriteIndent()
		{
			if (!options.Indented)
				return .Ok;

			for (int i = 0; i < depth; i++)
			{
				Try!(WriteRaw(stream, options.IndentString));
			}

			return .Ok;
		}

		[Inline]
		private Result<void, JsonSerializationError> WriteNewLine()
		{
			if (!options.Indented)
				return .Ok;

			return WriteRaw(stream, options.NewLine);
		}

		Result<void, JsonSerializationError> WriteNull(JsonValue value)
		{
			return WriteRaw(stream, NullLiteral);
		}

		Result<void, JsonSerializationError> WriteBoolean(JsonValue value)
		{
			bool boolean = value;

			return WriteRaw(stream, boolean ? TrueLiteral : FalseLiteral);
		}

		Result<void, JsonSerializationError> WriteNumber(JsonValue value)
		{
			switch (value.type)
			{
			case .NUMBER_UNSIGNED:
				return WriteRaw(stream, value.data.unsignedNumber.ToString(.. scope .()));
			case .NUMBER_SIGNED:
				return WriteRaw(stream, value.data.signedNumber.ToString(.. scope .()));
			case .NUMBER:
				return WriteFloat(stream, value.data.number);
			default:
				return .Err(.InvalidNumber);
			}
		}

		Result<void, JsonSerializationError> WriteString(JsonValue value)
		{
			StringView string = value;

			return WriteString(stream, string);
		}

		Result<void, JsonSerializationError> WriteArray(JsonValue value)
		{
			nesting++;
			defer { nesting--; }

			if (nesting > cMaximumDepth)
				return .Err(.MaximumDepthReached);

			let array = value.AsArray().Value;

			Try!(WriteChar(stream, (char8)JsonToken.LEFT_SQUARE_BRACKET));

			if (array.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
				depth++;
			}

			bool first = true;
			for (let item in array)
			{
				if (!first)
				{
					Try!(WriteChar(stream, (char8)JsonToken.COMMA));
					Try!(WriteNewLine());
				}
				first = false;

				Try!(WriteIndent());
				Try!(WriteInternal(item));
			}

			if (array.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
				depth--;
				Try!(WriteIndent());
			}

			return WriteChar(stream, (char8)JsonToken.RIGHT_SQUARE_BRACKET);
		}

		Result<void, JsonSerializationError> WriteObject(JsonValue value)
		{
			nesting++;
			defer { nesting--; }

			if (nesting > cMaximumDepth)
				return .Err(.MaximumDepthReached);

			let obj = value.AsObject().Value;

			Try!(WriteChar(stream, (char8)JsonToken.LEFT_CURLY_BRACKET));

			if (obj.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
				depth++;
			}

			bool first = true;
			for (let item in obj)
			{
				if (!first)
				{
					Try!(WriteChar(stream, (char8)JsonToken.COMMA));
					Try!(WriteNewLine());
				}
				first = false;

				Try!(WriteIndent());

				Try!(WriteChar(stream, '"'));
				Try!(WriteEscaped(stream, item.key));
				Try!(WriteRaw(stream, options.Indented ? "\": " : "\":"));

				Try!(WriteInternal(item.value));
			}

			if (obj.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
				depth--;
				Try!(WriteIndent());
			}

			return WriteChar(stream, (char8)JsonToken.RIGHT_CURLY_BRACKET);
		}
	}
}
