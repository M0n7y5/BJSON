using BJSON.Models;
using System;
using BJSON.Constants;
using BJSON.Enums;
namespace BJSON
{
	class JsonWriter
	{
		private JsonWriterOptions options;
		private int depth = 0;

		public this()
		{
			this.options = .();
		}

		public this(JsonWriterOptions options)
		{
			this.options = options;
		}

		public Result<void, JsonSerializationError> Write(JsonValue json, String outText)
		{
			return Write(json, outText, this.options);
		}

		public Result<void, JsonSerializationError> Write(JsonValue json, String outText, JsonWriterOptions options)
		{
			this.options = options;
			this.depth = 0;

			return WriteInternal(json, outText);
		}

		private Result<void, JsonSerializationError> WriteInternal(JsonValue json, String outText)
		{
			switch (json.type)
			{
			case .NULL:
				return WriteNull(json, outText);
			case .BOOL:
				return WriteBoolean(json, outText);
			case .NUMBER:
				return WriteNumber(json, outText);
			case .NUMBER_SIGNED:
				return WriteNumber(json, outText);
			case .NUMBER_UNSIGNED:
				return WriteNumber(json, outText);
			case .STRING:
				return WriteString(json, outText);
			case .ARRAY:
				return WriteArray(json, outText);
			case .OBJECT:
				return WriteObject(json, outText);

			default:
				return .Err(.UnknownType);

			}
		}

		[Inline]
		private void WriteIndent(String str)
		{
			if (!options.Indented)
				return;

			for (int i = 0; i < depth; i++)
			{
				str.Append(options.IndentString);
			}
		}

		[Inline]
		private void WriteNewLine(String str)
		{
			if (!options.Indented)
				return;

			str.Append(options.NewLine);
		}

		Result<void, JsonSerializationError> WriteNull(JsonValue value, String str)
		{
			str.Append(NullLiteral);

			return .Ok;
		}

		Result<void, JsonSerializationError> WriteBoolean(JsonValue value, String str)
		{
			bool boolean = value;

			str.Append(boolean ? TrueLiteral : FalseLiteral);

			return .Ok;
		}

		Result<void, JsonSerializationError> WriteNumber(JsonValue value, String str)
		{
			switch (value.type)
			{
			case .NUMBER_UNSIGNED:
				str.Append(value.data.unsignedNumber.ToString(.. scope .()));
			case .NUMBER_SIGNED:
				str.Append(value.data.signedNumber.ToString(.. scope .()));
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
				str.Append(&buff);
			default:
				return .Err(.InvalidNumber);
			}

			return .Ok;
		}

		Result<void, JsonSerializationError> WriteString(JsonValue value, String str)
		{
			StringView string = value;
			
			// Cache string length at start
			let strLen = string.Length;
			
			// Pre-allocate capacity: original length + 2 quotes + ~12.5% for escapes (using bit shift)
			str.Reserve(str.Length + strLen + 2 + (strLen >> 3));
			
			str.Append('"');
			
			int spanStart = 0;
			int i = 0;
			
			for (let c in string)
			{
				let escapeChar = JsonEscapes.GetEscapeChar(c);
				
				if (escapeChar != 0)
				{
					// Append any non-escaped characters before this one
					if (i > spanStart)
					{
						str.Append(string.Substring(spanStart, i - spanStart));
					}
					
					// Write the escape sequence
					str.Append('\\');
					str.Append(escapeChar);
					spanStart = i + 1;
				}
				else if ((uint8)c < 0x20)
				{
					// Handle other control characters with \uXXXX
					if (i > spanStart)
					{
						str.Append(string.Substring(spanStart, i - spanStart));
					}
					
					str.Append('\\');
					str.Append('u');
					str.Append('0');
					str.Append('0');
					let highNibble = ((uint8)c >> 4) & 0x0F;
					let lowNibble = (uint8)c & 0x0F;
					str.Append(highNibble < 10 ? (char8)('0' + highNibble) : (char8)('a' + highNibble - 10));
					str.Append(lowNibble < 10 ? (char8)('0' + lowNibble) : (char8)('a' + lowNibble - 10));
					spanStart = i + 1;
				}
				
				i++;
			}
			
			// Append any remaining non-escaped characters
			if (i > spanStart)
			{
				str.Append(string.Substring(spanStart, i - spanStart));
			}
			
			str.Append('"');
			return .Ok;
		}

		Result<void, JsonSerializationError> WriteArray(JsonValue value, String str)
		{
			let array = value.AsArray().Value;

			str.Append((char8)JsonToken.LEFT_SQUARE_BRACKET);

			if (array.Count > 0 && options.Indented)
			{
				WriteNewLine(str);
				depth++;
			}

			bool first = true;
			for (let item in array)
			{
				if (!first)
				{
					str.Append((char8)JsonToken.COMMA);
					if (options.Indented)
						WriteNewLine(str);
				}
				first = false;

				if (options.Indented)
					WriteIndent(str);

				if (WriteInternal(item, str) case .Err(let err))
					return .Err(err);
			}

			if (array.Count > 0 && options.Indented)
			{
				WriteNewLine(str);
				depth--;
				WriteIndent(str);
			}

			str.Append((char8)JsonToken.RIGHT_SQUARE_BRACKET);

			return .Ok;
		}

		Result<void, JsonSerializationError> WriteObject(JsonValue value, String str)
		{
			let obj = value.AsObject().Value;

			str.Append((char8)JsonToken.LEFT_CURLY_BRACKET);

			if (obj.Count > 0 && options.Indented)
			{
				WriteNewLine(str);
				depth++;
			}

			bool first = true;
			for (let item in obj)
			{
				if (!first)
				{
					str.Append((char8)JsonToken.COMMA);
					if (options.Indented)
						WriteNewLine(str);
				}
				first = false;

				if (options.Indented)
					WriteIndent(str);

				str.Append('"');
				str.Append(item.key);
				str.Append(options.Indented ? "\": " : "\":");

				if (WriteInternal(item.value, str) case .Err(let err))
					return .Err(err);
			}

			if (obj.Count > 0 && options.Indented)
			{
				WriteNewLine(str);
				depth--;
				WriteIndent(str);
			}

			str.Append((char8)JsonToken.RIGHT_CURLY_BRACKET);

			return .Ok;
		}
	}
}
