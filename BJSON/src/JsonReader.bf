using System;
using System.IO;
using BJSON.Constants;
using BJSON.Enums;
using System.Text;
using BJSON.Models;
namespace BJSON
{
	class JsonReader
	{
		IHandler _handler;

		uint column = 1;
		uint line = 1;
		uint currentDepth = 0;

		public const uint MaximumDepth = 900;
		private const int MaxNumberBufferSize = 4096;

		public this(IHandler handler)
		{
			this._handler = handler;
		}

		public Result<void, JsonParsingError> Parse(Stream stream)
		{
			if (stream == null)
				return .Err(.InputStreamIsNull);

			SkipWhitespace(stream);

			if (stream.Peek<char8>() case .Ok)
			{
				let res = ParseValue(stream);

				SkipWhitespace(stream);

				let pos = stream.Position;
				let len = stream.Length;

				if (pos != len)
				{
					TrySilent!(stream.Peek<char8>());

					return .Err(.UnexpectedToken(line + 1, column, "} or ]"));
				}

				return res;
			}
			else
				return .Err(.UnableToRead(line, column)); // Document empty
		}

		void SkipWhitespace(Stream stream)
		{
			SKIP:while (stream.Peek<char8>() case .Ok(let c))
			{
				switch (c)
				{
				case '\n':
					stream.Skip(1);
					line++;
					column = 1;
				case ' ','\t','\r':
					stream.Skip(1);
					column++;
				default: break SKIP;
				}
			}
		}

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
				default: return ParseNumber(stream);
				}
			}
		}

		Result<void, JsonParsingError> ParseNull(Stream stream)
		{
			Try!(Consume(stream, "null"));

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
					Try!(Consume(stream, "true"));

					if (!_handler.Bool(true))
						return .Err(.InvalidValue(line, column));
					return .Ok;

				case 'f':
					Try!(Consume(stream, "false"));

					if (!_handler.Bool(false))
						return .Err(.InvalidValue(line, column));

					return .Ok;
				}

			return .Err(.UnexpectedToken(line, column, "")); // unexpected token, Error Termination
		}

		Result<uint32, JsonParsingError> ParseHex4(Stream stream)
		{
			uint32 codepoint = 0;

			for (let i in 0...3)
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

					stream.Skip(1); // if we can peek, we can skip
					column++;
				}
			}

			return .Ok(codepoint);
		}


		Result<void, JsonParsingError> ParseString(Stream stream, bool isKey = false)
		{
			String str = scope .();

			if (let c = stream.Peek<char8>())
			{
				if (c == '"')
				{
					stream.Skip(1);
					column++;
				}
				else
					return .Err(.UnexpectedToken(line, column, "\"")); // unexpected token, Error Termination
			}
			else
				return .Err(.UnableToRead(line, column)); //Peek error

			for (;;)
			{
				if (let c = stream.Peek<char8>())
				{
					if (c == '\\') // handle escaping
					{
						stream.Skip(1);
						if (let e = stream.Peek<char8>())
						{
							if (e == 'u')
							{
								stream.Skip(1);
								column++;

								var codepoint = Try!(ParseHex4(stream));
								if (codepoint >= 0xD800 && codepoint <= 0xDFFF)
								{
									// high surrogate, check if followed by valid low surrogate
									if (codepoint <= 0xDBFF)
									{
										if (Consume(stream, '\\') case .Err)
											return .Err(.InvalidStringSurrogate(line, column));

										if (Consume(stream, 'u') case .Err)
											return .Err(.InvalidStringSurrogate(line, column));

										let codepoint2 =  Try!(ParseHex4(stream));
										if (codepoint2 < 0xDC00 || codepoint2 > 0xDFFF)
										{
											return .Err(.InvalidStringSurrogate(line, column)); // Parse Error String Unicode Surrogate Invalid
										}
										codepoint = (((codepoint - 0xD800) << 10) | (codepoint2 - 0xDC00)) + 0x10000;
									}
									else
									{
										return .Err(.InvalidStringSurrogate(line, column)); // Parse Error String Unicode Surrogate Invalid
									}
								}

								str.Append((char32)codepoint);
							}
							else if (let e2 = JsonEscapes.Escape(e))
							{
								str.Append(e2);
								stream.Skip(1);
								column += 2;
							}
							else
								return .Err(.InvalidEscapeToken(line, column)); // Error String Escape Invalid
						}
						else
							return .Err(.UnableToRead(line, column)); // peek error
					}
					else if (c == '"') // Closing double quote
					{
						bool res = false;

						if (isKey)
							res = _handler.Key(str, true);
						else
							res = _handler.String(str, true);

						stream.Skip(1);
						column++;

						return res ? .Ok : .Err(.InvalidValue(line, column)); // OK or Parse Error Termination
					}
					else if (c < (.)0x20)
					{
						if (c == '\0')
							return .Err(.MissingQuotationMark(line, column)); // String Miss Quotation Mark
						else
							return .Err(.InvalidEncoding(line, column)); // invalid encoding
					}
					else
					{
						str.Append(c);
						stream.Skip(1);
						column++;
					}
				}
				else
					return .Err(.UnableToRead(line, column)); // peek error
			}
		}

		Result<void, JsonParsingError> ParseObject(Stream stream)
		{
			stream.Skip(1); //skip {
			column++;

			if (!_handler.StartObject())
			{
				return .Err(.UnexpectedToken(line, column, "")); // Parse Error Termination
			}

			currentDepth++;

			if (currentDepth > MaximumDepth)
			{
				return .Err(.MaximumDepthReached);
			}

			if (Consume(stream, '}') case .Ok)
			{
				if (!_handler.EndObject())
					return .Err(.UnexpectedToken(line, column, "")); // Error Termination

				return .Ok; // empty object
			}

			for (;;)
			{
				if (let c = stream.Peek<char8>())
				{
					if (c != '"')
						return .Err(.UnexpectedToken(line, column, "\"")); // MISSING OBJECT NAME

					Try!(ParseString(stream, true));

					Try!(Consume(stream, ':'));

					SkipWhitespace(stream);
					Try!(ParseValue(stream));

					SkipWhitespace(stream);

					if (let nextC = stream.Peek<char8>())
					{
						switch (nextC)
						{
						case ',':
							stream.Skip(1);
							column++;
							SkipWhitespace(stream);
						case '}':
							stream.Skip(1);
							column++;
							if (!_handler.EndObject())
								return .Err(.UnexpectedToken(line, column, "")); //Parse error termination

							currentDepth--;

							return .Ok;
						default:
							return .Err(.UnexpectedToken(line, column, ", or }")); // Object Miss Comma Or Curly Bracket

						}
					}
				}
				else
					return .Err(.UnexpectedToken(line, column, ", or }")); // peek error
			}
		}

		Result<void, JsonParsingError> ParseArray(Stream stream)
		{
			stream.Skip(1); //skip [
			column++;

			if (!_handler.StartArray())
			{
				return .Err(.UnexpectedToken(line, column, "")); // Parse Error Termination
			}

			currentDepth++;

			if (currentDepth > MaximumDepth)
			{
				return .Err(.MaximumDepthReached);
			}

			if (Consume(stream, ']') case .Ok)
			{
				if (!_handler.EndArray())
					return .Err(.UnexpectedToken(line, column, "")); // Error termination
				else
					return .Ok; // empty array
			}

			for (;;)
			{
				Try!(ParseValue(stream));

				if (Consume(stream, ',') case .Ok)
				{
					SkipWhitespace(stream);
				}
				else if (Consume(stream, ']') case .Ok)
				{
					if (!_handler.EndArray())
						return .Err(.UnexpectedToken(line, column, "")); // Error termination

					currentDepth--;
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, ", or ]")); // Array Miss Comma Or Square Bracket
			}
		}

		/// Parsed number state containing the components of a JSON number.
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

		/// Main entry point for number parsing - refactored from ParseNumberEx.
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

			// Parse the minus sign if present
			Try!(ParseNumberSign(stream, ref num));

			// Parse the integer part (required)
			Try!(ParseIntegerPart(stream, ref num));

			// Convert and report the number
			return ReportNumber(ref num);
		}

		/// Parses an optional leading minus sign.
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

		/// Parses the integer part of a number, including optional fraction and exponent.
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

					// Check for leading zero followed by digit
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

					// Calculate integer value for fast path
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
					break; // End of number
				}
			}

			if (!hasDigit)
			{
				return .Err(.UnexpectedToken(line, column, "digit"));
			}

			return .Ok;
		}

		/// Parses the fractional part of a number (after the decimal point).
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

		/// Parses the exponent part of a number (after 'e' or 'E').
		Result<void, JsonParsingError> ParseExponentPart(Stream stream, ref ParsedNumber num)
		{
			// Append the 'e' or 'E' that was already peeked
			if (stream.Peek<char8>() case .Ok(let expChar))
			{
				num.hasExpPart = true;
				if (!TryAppendToBuffer(ref num, expChar))
					return .Err(.NumberTooLong(line, column));
				stream.Skip(1);
				column++;
			}

			// Check for +/- sign
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

			// Parse exponent digits
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

		/// Attempts to append a character to the buffer, returning false if buffer is full.
		[Inline]
		bool TryAppendToBuffer(ref ParsedNumber num, char8 c)
		{
			if (num.bufIdx >= MaxNumberBufferSize)
				return false;
			num.buffer[num.bufIdx++] = c;
			return true;
		}

		/// Accumulates the integer value for the fast path (avoiding string parsing).
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

		/// Reports the parsed number to the handler.
		Result<void, JsonParsingError> ReportNumber(ref ParsedNumber num)
		{
			// For floating-point or overflow cases, use the built-in parser
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
				// For integers, use the fast path
				if (num.isNegative)
				{
					if (num.intVal > (uint64)int64.MaxValue + 1)
					{
						// Overflowed int64 range (negative), fall back to double
						StringView strNum = StringView(&num.buffer, num.bufIdx);
						if (let value = double.Parse(strNum))
						{
							if (!_handler.Number(value))
								return .Err(.InvalidValue(line, num.startColumn));
						}
						else
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

		Result<void, JsonParsingError> Consume(Stream stream, StringView expected)
		{
			let buffer = scope uint8[expected.Length];

			SkipWhitespace(stream);

			if (let readBytes = stream.TryRead(buffer))
			{

				if (readBytes == expected.Length && StringView(buffer) == expected)
				{
					column += (.)expected.Length;
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, scope $"{expected}"));
			}

			return .Err(.UnableToRead(line, column));
		}

		Result<void, JsonParsingError> Consume(Stream stream, char8 expected)
		{
			SkipWhitespace(stream);

			if (let c = stream.Peek<char8>())
			{
				if (c == expected)
				{
					stream.Skip(1);
					column++;
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, scope $"{expected}"));
			}

			return .Err(.UnableToRead(line, column));
		}

	}
}
