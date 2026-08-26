using System;
using System.IO;
using BJSON.Constants;
using BJSON.Enums;
using System.Text;
using BJSON.Models;
namespace BJSON
{
	/// Reads JSON text from a Stream and reports the parse events to an IHandler.
	/// Input must be valid UTF-8: RFC 8259 section 8.1 requires it, so malformed sequences are
	/// rejected with InvalidEncoding instead of reaching the handler.
	/// Line and column travel in the error payloads; \n, \r\n, and a lone \r each end a line.
	class JsonReader
	{
		IHandler _handler;
		DeserializerConfig _config;

		uint column = 1;
		uint line = 1;
		uint currentDepth = 0;

		/// Deepest object and array nesting accepted. Parsing recurses once per level, so deeper
		/// input reports MaximumDepthReached rather than overflowing the stack.
		public const uint MaximumDepth = 200;
		// A number token is buffered whole so double.Parse sees one contiguous view. 1024 chars
		// bounds the ParsedNumber stack frame; a longer token reports NumberTooLong.
		private const int MaxNumberBufferSize = 1024;
		private const int DefaultStringBufferSize = 256;

		/// Creates a reader that reports parse events to a handler.
		/// @param handler The event sink. A Deserializer also supplies its DeserializerConfig, which
		/// is copied here, so config changes after this point do not reach the parse.
		public this(IHandler handler)
		{
			this._handler = handler;
			
			if (handler is Deserializer)
			{
				this._config = ((Deserializer)handler).Config;
			}
		}

		/// Parses one JSON document and reports it to the handler.
		/// @param stream The stream to read; null reports InputStreamIsNull.
		/// @returns Ok once the whole document is consumed, or the first error encountered. Anything
		/// but whitespace after the document reports UnexpectedToken expecting "end of document".
		public Result<void, JsonParsingError> Parse(Stream stream)
		{
			if (stream == null)
				return .Err(.InputStreamIsNull);

			Try!(SkipWhitespace(stream));

			if (stream.Peek<char8>() case .Ok)
			{
				let res = ParseValue(stream);

				if (res case .Err)
					return res;

				Try!(SkipWhitespace(stream));

				let pos = stream.Position;
				let len = stream.Length;

				if (pos != len)
					return .Err(.UnexpectedToken(line, column, "end of document"));

				return res;
			}
			else
				return .Err(.UnableToRead(line, column));
		}

		// Returns a Result because comment scanning can fail on an unterminated block comment, and
		// that error has to reach the caller instead of passing for end of input.
		[Inline]
		Result<void, JsonParsingError> SkipWhitespace(Stream stream)
		{
			SKIP:while (stream.Peek<char8>() case .Ok(let c))
			{
				switch (c)
				{
				case '\n':
					stream.Skip(1);
					line++;
					column = 1;
				case '\r':
					stream.Skip(1);
					if (stream.Peek<char8>() case .Ok('\n'))
						stream.Skip(1);
					line++;
					column = 1;
				case ' ', '\t':
					stream.Skip(1);
					column++;
				case '/':
					if (_config.EnableComments)
					{
						Try!(SkipComment(stream));
						continue SKIP;
					}
					else
						break SKIP;
				default:
					break SKIP;
				}
			}

			return .Ok;
		}

		Result<void, JsonParsingError> SkipComment(Stream stream)
		{
			let pos = stream.Position;
			stream.Skip(1);
			column++;

			if (stream.Peek<char8>() case .Ok(let nextChar))
			{
				if (nextChar == '/')
				{
					stream.Skip(1);
					column++;

					while (stream.Peek<char8>() case .Ok(let c))
					{
						stream.Skip(1);
						if (c == '\n')
						{
							line++;
							column = 1;
							break;
						}
						else if (c == '\r')
						{
							column++;
							if (stream.Peek<char8>() case .Ok('\n'))
							{
								stream.Skip(1);
								line++;
								column = 1;
								break;
							}
							else
							{
								line++;
								column = 1;
								break;
							}
						}
						else
						{
							column++;
						}
					}
					return .Ok;
				}
				else if (nextChar == '*')
				{
					stream.Skip(1);
					column++;

					bool foundClosing = false;
					while (stream.Peek<char8>() case .Ok(let c))
					{
						stream.Skip(1);

						if (c == '\n')
						{
							line++;
							column = 1;
						}
						else if (c == '\r')
						{
							column++;
							if (stream.Peek<char8>() case .Ok('\n'))
							{
								stream.Skip(1);
								line++;
								column = 1;
							}
							else
							{
								line++;
								column = 1;
							}
							continue;
						}
						else if (c == '*')
						{
							column++;
							if (stream.Peek<char8>() case .Ok('/'))
							{
								stream.Skip(1);
								column++;
								foundClosing = true;
								break;
							}
						}
						else
						{
							column++;
						}
					}

					if (!foundClosing)
					{
						return .Err(.UnexpectedToken(line, column, "closing */"));
					}

					return .Ok;
				}
				else
				{
					stream.Position = pos;
					column--;
					return .Err(.UnexpectedToken(line, column, "// or /* to start comment"));
				}
			}
			else
			{
				stream.Position = pos;
				column--;
				return .Err(.UnableToRead(line, column));
			}
		}

		[Inline]
		Result<void, JsonParsingError> ParseValue(Stream stream)
		{
			switch (stream.Peek<char8>())
			{
			case .Err:
				return .Err(.UnableToRead(line, column));
			case .Ok(let val):
				switch (val)
				{
				case 'n': return ParseNull(stream);
				case 't': return ParseBool(stream);
				case 'f': return ParseBool(stream);
				case '"': return ParseString(stream);
				case '{': return ParseObject(stream);
				case '[': return ParseArray(stream);
				default:
					if ((uint8)val >= 0x80)
						return .Err(.InvalidEncoding(line, column));

					return ParseNumber(stream);
				}
			}
		}

		Result<void, JsonParsingError> ParseNull(Stream stream)
		{
			Try!(ConsumeLiteral(stream, "null"));

			if (!_handler.Null())
				return .Err(.UnexpectedToken(line, column, "null"));

			return .Ok;
		}


		Result<void, JsonParsingError> ParseBool(Stream stream)
		{
			if (let c = stream.Peek<char8>())
				switch (c)
				{
				case 't':
					Try!(ConsumeLiteral(stream, "true"));

					if (!_handler.Bool(true))
						return .Err(.InvalidValue(line, column));
					return .Ok;

				case 'f':
					Try!(ConsumeLiteral(stream, "false"));

					if (!_handler.Bool(false))
						return .Err(.InvalidValue(line, column));

					return .Ok;
				}

			return .Err(.UnexpectedToken(line, column, ""));
		}

		/// Parses 4 hex digits for unicode escape sequences.
		[Inline]
		Result<uint32, JsonParsingError> ParseHex4(Stream stream)
		{
			uint32 codepoint = 0;

			for (let i in 0 ... 3)
			{
				if (let c = stream.Peek<char8>())
				{
					codepoint <<= 4;
					codepoint += (.)c;

					if (c >= '0' && c <= '9')
						codepoint -= (.)'0';
					else if (c >= 'A' && c <= 'F')
						codepoint -= (.)'A' - 10;
					else if (c >= 'a' && c <= 'f')
						codepoint -= (.)'a' - 10;
					else
						return .Err(.InvalidUnicodeHexEscape(line, column));

					stream.Skip(1);
					column++;
				}
				else
					return .Err(.UnableToRead(line, column));
			}

			return .Ok(codepoint);
		}


		Result<void, JsonParsingError> ParseString(Stream stream, bool isKey = false)
		{
			String str = scope .(DefaultStringBufferSize);

			if (let c = stream.Peek<char8>())
			{
				if (c == '"')
				{
					stream.Skip(1);
					column++;
				}
				else
					return .Err(.UnexpectedToken(line, column, "\""));
			}
			else
				return .Err(.UnableToRead(line, column));

			for (;;)
			{
				if (let c = stream.Peek<char8>())
				{
					if (c == '\\')
					{
						stream.Skip(1);
						column++;
						if (let e = stream.Peek<char8>())
						{
							if (e == 'u')
							{
								stream.Skip(1);
								column++;

								var codepoint = Try!(ParseHex4(stream));
								if (codepoint >= 0xD800 && codepoint <= 0xDFFF)
								{
									// D800 to DBFF is a high surrogate: a low surrogate escape must follow it.
									if (codepoint <= 0xDBFF)
									{
										if (ConsumeChar(stream, '\\') case .Err)
											return .Err(.InvalidStringSurrogate(line, column));

										if (ConsumeChar(stream, 'u') case .Err)
											return .Err(.InvalidStringSurrogate(line, column));

										let codepoint2 = Try!(ParseHex4(stream));
										if (codepoint2 < 0xDC00 || codepoint2 > 0xDFFF)
										{
							return .Err(.InvalidStringSurrogate(line, column));
										}
										codepoint = (((codepoint - 0xD800) << 10) | (codepoint2 - 0xDC00)) + 0x10000;
									}
									else
									{
										return .Err(.InvalidStringSurrogate(line, column));
									}
								}

								str.Append((char32)codepoint);
							}
							else if (let e2 = JsonEscapes.Escape(e))
							{
								str.Append(e2);
								stream.Skip(1);
								column++;
							}
							else
								return .Err(.InvalidEscapeToken(line, column));
						}
						else
							return .Err(.UnableToRead(line, column));
					}
					else if (c == '"')
					{
						bool res = false;

						if (isKey)
							res = _handler.Key(str, true);
						else
							res = _handler.String(str, true);

						stream.Skip(1);
						column++;

						return res ? .Ok : .Err(.InvalidValue(line, column));
					}
					else if (c < (.)0x20)
						return .Err(.UnexpectedToken(line, column, "escaped control character"));
					else if ((uint8)c >= 0x80)
					{
						Try!(AppendUtf8Sequence(stream, c, str));
					}
					else
					{
						str.Append(c);
						stream.Skip(1);
						column++;
					}
				}
				else
					return .Err(.UnableToRead(line, column));
			}
		}

		/// Consumes one UTF-8 sequence and appends its bytes to str.
		/// RFC 8259 section 8.1 requires valid UTF-8, so overlong forms, surrogate halves and
		/// code points above U+10FFFF are rejected here instead of being copied into the DOM.
		Result<void, JsonParsingError> AppendUtf8Sequence(Stream stream, char8 lead, String str)
		{
			let leadByte = (uint32)(uint8)lead;

			int continuationCount = 0;
			uint32 codepoint = 0;
			uint32 minCodepoint = 0;

			if ((leadByte & 0xE0) == 0xC0)
			{
				continuationCount = 1;
				codepoint = leadByte & 0x1F;
				minCodepoint = 0x80;
			}
			else if ((leadByte & 0xF0) == 0xE0)
			{
				continuationCount = 2;
				codepoint = leadByte & 0x0F;
				minCodepoint = 0x800;
			}
			else if ((leadByte & 0xF8) == 0xF0)
			{
				continuationCount = 3;
				codepoint = leadByte & 0x07;
				minCodepoint = 0x10000;
			}
			else
				return .Err(.InvalidEncoding(line, column));

			str.Append(lead);
			stream.Skip(1);

			for (int i = 0; i < continuationCount; i++)
			{
				if (let c = stream.Peek<char8>())
				{
					let continuation = (uint32)(uint8)c;

					if ((continuation & 0xC0) != 0x80)
						return .Err(.InvalidEncoding(line, column));

					codepoint = (codepoint << 6) | (continuation & 0x3F);
					str.Append(c);
					stream.Skip(1);
				}
				else
					return .Err(.InvalidEncoding(line, column));
			}

			if (codepoint < minCodepoint || codepoint > 0x10FFFF)
				return .Err(.InvalidEncoding(line, column));

			if (codepoint >= 0xD800 && codepoint <= 0xDFFF)
				return .Err(.InvalidEncoding(line, column));

			column++;

			return .Ok;
		}

		Result<void, JsonParsingError> ParseObject(Stream stream)
		{
			stream.Skip(1);
			column++;

			if (!_handler.StartObject())
			{
				return .Err(.UnexpectedToken(line, column, ""));
			}

			currentDepth++;

			if (currentDepth > MaximumDepth)
			{
				return .Err(.MaximumDepthReached);
			}

			Try!(SkipWhitespace(stream));

			if (ConsumeChar(stream, '}') case .Ok)
			{
				if (!_handler.EndObject())
					return .Err(.UnexpectedToken(line, column, ""));

				currentDepth--;

				return .Ok;
			}

			for (;;)
			{
				if (let c = stream.Peek<char8>())
				{
					if (c != '"')
						return .Err(.UnexpectedToken(line, column, "\""));

					Try!(ParseString(stream, true));

					Try!(ConsumeCharWithWhitespace(stream, ':'));

					Try!(SkipWhitespace(stream));
					Try!(ParseValue(stream));

					Try!(SkipWhitespace(stream));

					if (let nextC = stream.Peek<char8>())
					{
						switch (nextC)
						{
						case ',':
							stream.Skip(1);
							column++;
							Try!(SkipWhitespace(stream));
						case '}':
							stream.Skip(1);
							column++;
						if (!_handler.EndObject())
							return .Err(.UnexpectedToken(line, column, ""));

							currentDepth--;

							return .Ok;
						default:
							return .Err(.UnexpectedToken(line, column, ", or }"));

						}
					}
				}
				else
					return .Err(.UnexpectedToken(line, column, ", or }"));
			}
		}

		Result<void, JsonParsingError> ParseArray(Stream stream)
		{
			stream.Skip(1);
			column++;

			if (!_handler.StartArray())
			{
				return .Err(.UnexpectedToken(line, column, ""));
			}

			currentDepth++;

			if (currentDepth > MaximumDepth)
			{
				return .Err(.MaximumDepthReached);
			}

			Try!(SkipWhitespace(stream));

			if (ConsumeChar(stream, ']') case .Ok)
			{
				if (!_handler.EndArray())
					return .Err(.UnexpectedToken(line, column, ""));

				currentDepth--;

				return .Ok;
			}

			for (;;)
			{
				Try!(ParseValue(stream));

				Try!(SkipWhitespace(stream));

				if (ConsumeChar(stream, ',') case .Ok)
				{
					Try!(SkipWhitespace(stream));
				}
				else if (ConsumeChar(stream, ']') case .Ok)
				{
					if (!_handler.EndArray())
						return .Err(.UnexpectedToken(line, column, ""));

					currentDepth--;
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, ", or ]"));
			}
		}

		/// Raw number token plus the integer fast path: ReportNumber hands intVal to the handler when
		/// the token has no fraction, exponent, or overflow, and otherwise parses buffer as a double.
		struct ParsedNumber
		{
			public char8[MaxNumberBufferSize] buffer;
			public int bufIdx;
			public bool isNegative;
			public bool hasFracPart;
			public bool hasExpPart;
			public bool intOverflow;
			public uint64 intVal;
			public uint startColumn;
		}

		Result<void, JsonParsingError> ParseNumber(Stream stream)
		{
			ParsedNumber num = .();
			num.bufIdx = 0;
			num.isNegative = false;
			num.hasFracPart = false;
			num.hasExpPart = false;
			num.intOverflow = false;
			num.intVal = 0;
			num.startColumn = column;

			Try!(ParseNumberSign(stream, ref num));

			Try!(ParseIntegerPart(stream, ref num));

			return ReportNumber(ref num);
		}

		[Inline]
		Result<void, JsonParsingError> ParseNumberSign(Stream stream, ref ParsedNumber num)
		{
			if (stream.Peek<char8>() case .Ok(let c))
			{
				if (c == '-')
				{
					num.isNegative = true;
					if (!TryAppendToBuffer(ref num, '-'))
						return .Err(.NumberTooLong(line, column));
					stream.Skip(1);
					column++;
				}
			}
			else
			{
				return .Err(.UnableToRead(line, column));
			}
			return .Ok;
		}

		Result<void, JsonParsingError> ParseIntegerPart(Stream stream, ref ParsedNumber num)
		{
			bool hasDigit = false;
			bool leadingZero = false;
			int digitCount = 0;

			while (stream.Peek<char8>() case .Ok(let digitC))
			{
				if (digitC >= '0' && digitC <= '9')
				{
					hasDigit = true;

					if (digitCount == 0 && digitC == '0')
					{
						leadingZero = true;
					}
					else if (leadingZero)
					{
						return .Err(.UnexpectedToken(line, column, "fraction or exponent"));
					}

					if (!TryAppendToBuffer(ref num, digitC))
						return .Err(.NumberTooLong(line, column));

					if (!num.intOverflow && !num.hasFracPart && !num.hasExpPart)
					{
						AccumulateIntValue(ref num, digitC, digitCount);
					}
					digitCount++;

					stream.Skip(1);
					column++;
				}
				else if (digitC == '.')
				{
					Try!(ParseFractionalPart(stream, ref num));
					break;
				}
				else if (digitC == 'e' || digitC == 'E')
				{
					Try!(ParseExponentPart(stream, ref num));
					break;
				}
				else
				{
					break; // Any other character ends the token; the caller validates what follows it.
				}
			}

			if (!hasDigit)
			{
				return .Err(.UnexpectedToken(line, column, "digit"));
			}

			return .Ok;
		}

		Result<void, JsonParsingError> ParseFractionalPart(Stream stream, ref ParsedNumber num)
		{
			num.hasFracPart = true;
			if (!TryAppendToBuffer(ref num, '.'))
				return .Err(.NumberTooLong(line, column));
			stream.Skip(1);
			column++;

			bool hasFracDigit = false;

			while (stream.Peek<char8>() case .Ok(let fracC))
			{
				if (fracC >= '0' && fracC <= '9')
				{
					hasFracDigit = true;
					if (!TryAppendToBuffer(ref num, fracC))
						return .Err(.NumberTooLong(line, column));
					stream.Skip(1);
					column++;
				}
				else if (fracC == 'e' || fracC == 'E')
				{
					Try!(ParseExponentPart(stream, ref num));
					break;
				}
				else
				{
					break;
				}
			}

			if (!hasFracDigit)
			{
				return .Err(.UnexpectedToken(line, column, "digit after decimal point"));
			}

			return .Ok;
		}

		Result<void, JsonParsingError> ParseExponentPart(Stream stream, ref ParsedNumber num)
		{
			if (stream.Peek<char8>() case .Ok(let expChar))
			{
				num.hasExpPart = true;
				if (!TryAppendToBuffer(ref num, expChar))
					return .Err(.NumberTooLong(line, column));
				stream.Skip(1);
				column++;
			}

			if (stream.Peek<char8>() case .Ok(let sign))
			{
				if (sign == '-' || sign == '+')
				{
					if (!TryAppendToBuffer(ref num, sign))
						return .Err(.NumberTooLong(line, column));
					stream.Skip(1);
					column++;
				}
			}

			bool hasExpDigit = false;

			while (stream.Peek<char8>() case .Ok(let expC))
			{
				if (expC >= '0' && expC <= '9')
				{
					hasExpDigit = true;
					if (!TryAppendToBuffer(ref num, expC))
						return .Err(.NumberTooLong(line, column));
					stream.Skip(1);
					column++;
				}
				else
				{
					break;
				}
			}

			if (!hasExpDigit)
			{
				return .Err(.UnexpectedToken(line, column, "exponent value"));
			}

			return .Ok;
		}

		[Inline]
		bool TryAppendToBuffer(ref ParsedNumber num, char8 c)
		{
			if (num.bufIdx >= MaxNumberBufferSize)
				return false;
			num.buffer[num.bufIdx++] = c;
			return true;
		}

		[Inline]
		void AccumulateIntValue(ref ParsedNumber num, char8 digitC, int digitCount)
		{
			if (digitCount < 18)
			{
				num.intVal = num.intVal * 10 + (uint64)(digitC - '0');
			}
			else if (digitCount == 18)
			{
				uint64 limit = uint64.MaxValue / 10;
				if (num.intVal > limit || (num.intVal == limit && (digitC - '0') > 5))
				{
					num.intOverflow = true;
				}
				else
				{
					num.intVal = num.intVal * 10 + (uint64)(digitC - '0');
				}
			}
			else
			{
				num.intOverflow = true;
			}
		}

		Result<void, JsonParsingError> ReportNumber(ref ParsedNumber num)
		{
			if (num.hasFracPart || num.hasExpPart || num.intOverflow)
			{
				StringView strNum = StringView(&num.buffer, num.bufIdx);
				if (let value = double.Parse(strNum))
				{
					if (!_handler.Number(value))
					{
						return .Err(.InvalidValue(line, num.startColumn));
					}
				}
				else
				{
					return .Err(.InvalidValue(line, num.startColumn));
				}
			}
			else
			{
				if (num.isNegative)
				{
					if (num.intVal > (uint64)int64.MaxValue + 1)
					{
						StringView strNum = StringView(&num.buffer, num.bufIdx);
						if (let value = double.Parse(strNum))
						{
							if (!_handler.Number(value))
								return .Err(.InvalidValue(line, num.startColumn));
						}
						else
							return .Err(.InvalidValue(line, num.startColumn));
					}
					else if (num.intVal == 0)
					{
						// A bare -0 has no integer form, only the double keeps the sign.
						if (!_handler.Number(-0.0))
							return .Err(.InvalidValue(line, num.startColumn));
					}
					else if (num.intVal == (uint64)int64.MaxValue + 1)
					{
						// -(int64)9223372036854775808 overflows int64 and traps where arithmetic checks
						// are enabled, so MinValue is reported directly.
						if (!_handler.Number(int64.MinValue))
							return .Err(.InvalidValue(line, num.startColumn));
					}
					else
					{
						int64 val = -(int64)num.intVal;
						if (!_handler.Number(val))
							return .Err(.InvalidValue(line, num.startColumn));
					}
				}
				else
				{
					if (num.intVal > (uint64)int64.MaxValue)
					{
						if (!_handler.Number(num.intVal))
							return .Err(.InvalidValue(line, num.startColumn));
					}
					else
					{
						if (!_handler.Number((int64)num.intVal))
							return .Err(.InvalidValue(line, num.startColumn));
					}
				}
			}

			return .Ok;
		}

		/// Maps an expected character to static text, so the StringView in an UnexpectedToken payload
		/// stays valid after the parse returns. A view of a scope allocation would dangle by the time
		/// the caller formats the error.
		[Inline]
		static StringView ExpectedText(char8 expected)
		{
			switch (expected)
			{
			case '"': return "\"";
			case ':': return ":";
			case ',': return ",";
			case '{': return "{";
			case '}': return "}";
			case '[': return "[";
			case ']': return "]";
			default: return "";
			}
		}

		[Inline]
		Result<void, JsonParsingError> ConsumeLiteral(Stream stream, StringView expected)
		{
			for (int i = 0; i < expected.Length; i++)
			{
				if (stream.Peek<char8>() case .Ok(let c))
				{
					if (c != expected[i])
						return .Err(.UnexpectedToken(line, column, expected));
					stream.Skip(1);
					column++;
				}
				else
					return .Err(.UnableToRead(line, column));
			}
			return .Ok;
		}

		[Inline]
		Result<void, JsonParsingError> ConsumeChar(Stream stream, char8 expected)
		{
			if (let c = stream.Peek<char8>())
			{
				if (c == expected)
				{
					stream.Skip(1);
					column++;
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, ExpectedText(expected)));
			}

			return .Err(.UnableToRead(line, column));
		}

		[Inline]
		Result<void, JsonParsingError> ConsumeCharWithWhitespace(Stream stream, char8 expected)
		{
			Try!(SkipWhitespace(stream));

			if (let c = stream.Peek<char8>())
			{
				if (c == expected)
				{
					stream.Skip(1);
					column++;
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, ExpectedText(expected)));
			}

			return .Err(.UnableToRead(line, column));
		}

	}
}
