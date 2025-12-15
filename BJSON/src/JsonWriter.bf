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

		private void WriteIndent(String str)
		{
			if (!options.Indented)
				return;

			for (int i = 0; i < depth; i++)
			{
				str.Append(options.IndentString);
			}
		}

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
			str.Append(JsonEscapes.QUOTATION_MARK.Underlying);
			for(let c in string)
			{
				// Handle special escape sequences per RFC 8259
				switch (c)
				{
				case '"':
					str.Append('\\');
					str.Append('"');
				case '\\':
					str.Append('\\');
					str.Append('\\');
				case '\b':
					str.Append('\\');
					str.Append('b');
				case '\f':
					str.Append('\\');
					str.Append('f');
				case '\n':
					str.Append('\\');
					str.Append('n');
				case '\r':
					str.Append('\\');
					str.Append('r');
				case '\t':
					str.Append('\\');
					str.Append('t');
				default:
					// Handle other control characters (0x00-0x1F) with \uXXXX
					if ((uint8)c < 0x20)
					{
						str.Append('\\');
						str.Append('u');
						str.Append('0');
						str.Append('0');
						// Convert to hex (high nibble and low nibble)
						let highNibble = ((uint8)c >> 4) & 0x0F;
						let lowNibble = (uint8)c & 0x0F;
						str.Append(highNibble < 10 ? (char8)('0' + highNibble) : (char8)('a' + highNibble - 10));
						str.Append(lowNibble < 10 ? (char8)('0' + lowNibble) : (char8)('a' + lowNibble - 10));
					}
					else
					{
						str.Append(c);
					}
				}
			}
			str.Append(JsonEscapes.QUOTATION_MARK.Underlying);
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

				if (Write(item, str) case .Err(let err))
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

				let key = item.key.Quote(.. scope .());
				if (options.Indented)
					key.Append(": ");
				else
					key.Append(":");

				str.Append(key);

				if (Write(item.value, str) case .Err(let err))
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
