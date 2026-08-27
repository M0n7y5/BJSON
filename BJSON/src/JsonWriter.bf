using BJSON.Models;
using System;
using System.IO;
using BJSON.Constants;
using BJSON.Enums;
namespace BJSON
{
	/// Writes a JsonValue tree to a Stream as JSON text.
	/// The static Write helpers are also the output layer of the serializers comptime emits, which
	/// is why they are public: their signatures are part of the generated code contract, and
	/// changing one silently breaks every already generated serializer until it is regenerated.
	class JsonWriter
	{
		// WriteArray and WriteObject recurse once per level, so an unbounded tree would overflow the
		// stack. Matches JsonReader.MaximumDepth, so any document this library parses can be written back.
		private const int cMaximumDepth = 200;

		private JsonWriterOptions options;
		// One level per open array or object: it bounds the recursion and sets the indent width.
		private int mDepth = 0;
		private Stream stream;

		/// Creates a writer with default, unindented formatting.
		public this()
		{
			this.options = .();
		}

		/// Creates a writer with the given formatting options.
		/// @param options The formatting options used by writes that do not pass their own.
		public this(JsonWriterOptions options)
		{
			this.options = options;
		}

		/// Writes text to a stream verbatim.
		/// Emitted serializers call this for structural output.
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
		/// Emitted serializers call this for punctuation and quotes.
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
		/// Emitted serializers call this for object keys.
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
		/// Emitted serializers call this for String and StringView fields.
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
		/// Emitted serializers call this for bool fields.
		/// @param stream The stream to write to.
		/// @param value The boolean value.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteBool(Stream stream, bool value)
		{
			return WriteRaw(stream, value ? TrueLiteral : FalseLiteral);
		}

		/// Writes an integer value to a stream.
		/// Emitted serializers call this for every integer field and for enums written as numbers.
		/// @param stream The stream to write to.
		/// @param value The integer value.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteInt(Stream stream, int64 value)
		{
			return WriteRaw(stream, value.ToString(.. scope .()));
		}

		/// Writes an unsigned integer value to a stream.
		/// Emitted code routes integers through WriteInt; this overload covers values that exceed
		/// int64.MaxValue.
		/// @param stream The stream to write to.
		/// @param value The unsigned integer value.
		/// @returns Ok, or Err if the stream rejected or truncated the write.
		public static Result<void, JsonSerializationError> WriteUInt(Stream stream, uint64 value)
		{
			return WriteRaw(stream, value.ToString(.. scope .()));
		}

		/// Writes a floating-point value to a stream.
		/// Emitted serializers call this for floating-point fields. Conversion runs in the Beef
		/// runtime (Zmij, shortest round-trip); the text is then shaped for JSON.
		/// @param stream The stream to write to.
		/// @param value The floating-point value.
		/// @returns Ok, Err if value is NaN or Infinity, or Err if the write failed.
		public static Result<void, JsonSerializationError> WriteFloat(Stream stream, double value)
		{
			if (value.IsNaN)
				return .Err(.NaNNotAllowed);
			if (value.IsInfinity)
				return .Err(.InfinityNotAllowed);

			var text = scope String(32);
			value.ToString(text);
			NormalizeNumberText(text);

			return WriteRaw(stream, text);
		}

		/// Shapes the runtime's shortest round-trip text for JSON: a bare integer gains ".0" so a
		/// re-parse keeps the double tag, and an exponent loses the '+' the runtime writes.
		private static void NormalizeNumberText(String text)
		{
			char8* ptr = text.Ptr;
			let length = text.Length;
			bool hasDotOrExp = false;

			for (int i = 0; i < length; i++)
			{
				let c = ptr[i];
				if (c == '.')
				{
					hasDotOrExp = true;
				}
				else if (c == 'e' || c == 'E')
				{
					hasDotOrExp = true;
					if (i + 1 < length && ptr[i + 1] == '+')
						text.Remove(i + 1);
					break;
				}
			}

			if (!hasDotOrExp)
				text.Append(".0");
		}

		/// Writes a JsonValue tree to a stream using this writer's options.
		/// @param json The value to write.
		/// @param stream The stream to write to.
		/// @returns Ok, Err(.MaximumDepthReached) past 200 levels of nesting, or Err if a write failed.
		public Result<void, JsonSerializationError> Write(JsonValue json, Stream stream)
		{
			return Write(json, stream, this.options);
		}

		/// Writes a JsonValue tree to a stream using the given options, which replace the options
		/// this writer holds. Depth state is reset per call, so one instance can write repeatedly.
		/// @param json The value to write.
		/// @param stream The stream to write to.
		/// @param options The formatting options to apply and to keep on this writer.
		/// @returns Ok, Err(.MaximumDepthReached) past 200 levels of nesting, or Err if a write failed.
		public Result<void, JsonSerializationError> Write(JsonValue json, Stream stream, JsonWriterOptions options)
		{
			this.options = options;
			this.mDepth = 0;
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
				return WriteFloat(stream, json.data.number);
			case .NUMBER_SIGNED:
				return WriteRaw(stream, json.data.signedNumber.ToString(.. scope .()));
			case .NUMBER_UNSIGNED:
				return WriteRaw(stream, json.data.unsignedNumber.ToString(.. scope .()));
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
		private Result<void, JsonSerializationError> WriteIndent(int level)
		{
			if (!options.Indented)
				return .Ok;

			for (int i = 0; i < level; i++)
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

		Result<void, JsonSerializationError> WriteString(JsonValue value)
		{
			StringView string = value;

			return WriteString(stream, string);
		}

		Result<void, JsonSerializationError> WriteArray(JsonValue value)
		{
			mDepth++;
			defer { mDepth--; }

			if (mDepth > cMaximumDepth)
				return .Err(.MaximumDepthReached);

			let array = value.AsArray().Value;

			Try!(WriteChar(stream, (char8)JsonToken.LEFT_SQUARE_BRACKET));

			if (array.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
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

				Try!(WriteIndent(mDepth));
				Try!(WriteInternal(item));
			}

			if (array.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
				Try!(WriteIndent(mDepth - 1));
			}

			return WriteChar(stream, (char8)JsonToken.RIGHT_SQUARE_BRACKET);
		}

		Result<void, JsonSerializationError> WriteObject(JsonValue value)
		{
			mDepth++;
			defer { mDepth--; }

			if (mDepth > cMaximumDepth)
				return .Err(.MaximumDepthReached);

			let obj = value.AsObject().Value;

			Try!(WriteChar(stream, (char8)JsonToken.LEFT_CURLY_BRACKET));

			if (obj.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
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

				Try!(WriteIndent(mDepth));

				Try!(WriteChar(stream, '"'));
				Try!(WriteEscaped(stream, item.key));
				Try!(WriteRaw(stream, options.Indented ? "\": " : "\":"));

				Try!(WriteInternal(item.value));
			}

			if (obj.Count > 0 && options.Indented)
			{
				Try!(WriteNewLine());
				Try!(WriteIndent(mDepth - 1));
			}

			return WriteChar(stream, (char8)JsonToken.RIGHT_CURLY_BRACKET);
		}
	}
}
