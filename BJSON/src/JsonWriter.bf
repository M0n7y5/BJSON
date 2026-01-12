using BJSON.Models;
using System;
using System.IO;
using BJSON.Constants;
using BJSON.Enums;
namespace BJSON
{
	class JsonWriter
	{
		private JsonWriterOptions options;
		private int depth = 0;
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
					// Handle other control characters with \uXXXX
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

		public Result<void, JsonSerializationError> Write(JsonValue json, Stream stream)
		{
			return Write(json, stream, this.options);
		}

		public Result<void, JsonSerializationError> Write(JsonValue json, Stream stream, JsonWriterOptions options)
		{
			this.options = options;
			this.depth = 0;
			this.stream = stream;

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
		private void WriteIndent()
		{
			if (!options.Indented)
				return;

			for (int i = 0; i < depth; i++)
			{
				stream.WriteStrUnsized(options.IndentString);
			}
		}

		[Inline]
		private void WriteNewLine()
		{
			if (!options.Indented)
				return;

			stream.WriteStrUnsized(options.NewLine);
		}

		Result<void, JsonSerializationError> WriteNull(JsonValue value)
		{
			stream.WriteStrUnsized(NullLiteral);

			return .Ok;
		}

		Result<void, JsonSerializationError> WriteBoolean(JsonValue value)
		{
			bool boolean = value;

			stream.WriteStrUnsized(boolean ? TrueLiteral : FalseLiteral);

			return .Ok;
		}

		Result<void, JsonSerializationError> WriteNumber(JsonValue value)
		{
			switch (value.type)
			{
			case .NUMBER_UNSIGNED:
				stream.WriteStrUnsized(value.data.unsignedNumber.ToString(.. scope .()));
			case .NUMBER_SIGNED:
				stream.WriteStrUnsized(value.data.signedNumber.ToString(.. scope .()));
			case .NUMBER:
				let number = value.data.number;

				if (number.IsNaN)
				{
					return .Err(.NaNNotAllowed);
				}

				if (number.IsInfinity)
				{
					return .Err(.InfinityNotAllowed);
				}

				char8[25] buff;
				BJSON.Internal.dtoa(value.data.number, &buff);
				// Write null-terminated char8 array as string
				stream.WriteStrUnsized(StringView(&buff));
			default:
				return .Err(.InvalidNumber);
			}

			return .Ok;
		}

		/// Writes a JSON string with proper escaping (without surrounding quotes).
		/// Used for both string values and object keys.
		[Inline]
		private void WriteEscapedString(StringView string)
		{
			int spanStart = 0;
			int i = 0;
			
			for (let c in string)
			{
				let escapeChar = JsonEscapes.GetEscapeChar(c);
				
				if (escapeChar != 0)
				{
					// Write any non-escaped characters before this one
					if (i > spanStart)
					{
						stream.WriteStrUnsized(string.Substring(spanStart, i - spanStart));
					}
					
					// Write the escape sequence
					stream.Write<char8>('\\');
					stream.Write<char8>(escapeChar);
					spanStart = i + 1;
				}
				else if ((uint8)c < 0x20)
				{
					// Handle other control characters with \uXXXX
					if (i > spanStart)
					{
						stream.WriteStrUnsized(string.Substring(spanStart, i - spanStart));
					}
					
					stream.Write<char8>('\\');
					stream.Write<char8>('u');
					stream.Write<char8>('0');
					stream.Write<char8>('0');
					let highNibble = ((uint8)c >> 4) & 0x0F;
					let lowNibble = (uint8)c & 0x0F;
					stream.Write<char8>(highNibble < 10 ? (char8)('0' + highNibble) : (char8)('a' + highNibble - 10));
					stream.Write<char8>(lowNibble < 10 ? (char8)('0' + lowNibble) : (char8)('a' + lowNibble - 10));
					spanStart = i + 1;
				}
				
				i++;
			}
			
			// Write any remaining non-escaped characters
			if (i > spanStart)
			{
				stream.WriteStrUnsized(string.Substring(spanStart, i - spanStart));
			}
		}

		Result<void, JsonSerializationError> WriteString(JsonValue value)
		{
			StringView string = value;
			
			stream.Write<char8>('"');
			WriteEscapedString(string);
			stream.Write<char8>('"');
			return .Ok;
		}

		Result<void, JsonSerializationError> WriteArray(JsonValue value)
		{
			let array = value.AsArray().Value;

			stream.Write<char8>((char8)JsonToken.LEFT_SQUARE_BRACKET);

			if (array.Count > 0 && options.Indented)
			{
				WriteNewLine();
				depth++;
			}

			bool first = true;
			for (let item in array)
			{
				if (!first)
				{
					stream.Write<char8>((char8)JsonToken.COMMA);
					if (options.Indented)
						WriteNewLine();
				}
				first = false;

				if (options.Indented)
					WriteIndent();

				if (WriteInternal(item) case .Err(let err))
					return .Err(err);
			}

			if (array.Count > 0 && options.Indented)
			{
				WriteNewLine();
				depth--;
				WriteIndent();
			}

			stream.Write<char8>((char8)JsonToken.RIGHT_SQUARE_BRACKET);

			return .Ok;
		}

		Result<void, JsonSerializationError> WriteObject(JsonValue value)
		{
			let obj = value.AsObject().Value;

			stream.Write<char8>((char8)JsonToken.LEFT_CURLY_BRACKET);

			if (obj.Count > 0 && options.Indented)
			{
				WriteNewLine();
				depth++;
			}

			bool first = true;
			for (let item in obj)
			{
				if (!first)
				{
					stream.Write<char8>((char8)JsonToken.COMMA);
					if (options.Indented)
						WriteNewLine();
				}
				first = false;

				if (options.Indented)
					WriteIndent();

				stream.Write<char8>('"');
				WriteEscapedString(item.key);
				stream.WriteStrUnsized(options.Indented ? "\": " : "\":");

				if (WriteInternal(item.value) case .Err(let err))
					return .Err(err);
			}

			if (obj.Count > 0 && options.Indented)
			{
				WriteNewLine();
				depth--;
				WriteIndent();
			}

			stream.Write<char8>((char8)JsonToken.RIGHT_CURLY_BRACKET);

			return .Ok;
		}
	}
}
