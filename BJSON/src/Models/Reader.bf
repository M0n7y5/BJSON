using System;
using System.IO;
using BJSON.Constants;
using BJSON.Enums;
using System.Text;
namespace BJSON.Models
{
	class Reader
	{
		IHandler _handler;

		uint column = 1;
		uint line = 1;

		public this(IHandler handler)
		{
			this._handler = handler;
		}

		public Result<void, JsonParsingError> Parse(Stream stream)
		{
			if (stream == null)
				return .Err(.InputStreamIsNull);

			SkipWhitespace(stream);

			if (let c = stream.Peek<char8>())
			{
				return ParseValue(stream);

				/*switch (c)
				{
				case '[','{':
					return ParseValue(stream);
				case 0:
					return .Err(.DocumentIsEmpty); // Document empty
				default: return .Err(.UnexpectedToken(line, column, "{ or ["));
				}*/
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
			Try!(Consume(stream, 'n'));
			Try!(Consume(stream, 'u'));
			Try!(Consume(stream, 'l'));
			Try!(Consume(stream, 'l'));

			if (!_handler.Null())
				return .Err(.InvalidValue(line, column)); //invalid value

			return .Ok;
		}

		Result<void, JsonParsingError> ParseBool(Stream stream)
		{
			if (let c = stream.Peek<char8>()) // TODO: use read
				switch (c)
				{
				case 't': // parse true
					Try!(Consume(stream, 't'));
					Try!(Consume(stream, 'r'));
					Try!(Consume(stream, 'u'));
					Try!(Consume(stream, 'e'));

					if (!_handler.Bool(true))
						return .Err(.InvalidValue(line, column)); //invalid value
					return .Ok;

				case 'f': // parse true
					Try!(Consume(stream, 'f'));
					Try!(Consume(stream, 'a'));
					Try!(Consume(stream, 'l'));
					Try!(Consume(stream, 's'));
					Try!(Consume(stream, 'e'));

					if (!_handler.Bool(false))
						return .Err(.InvalidValue(line, column)); //invalid value

					return .Ok;
				}

			return .Err(.UnexpectedToken(line, column, "")); // unexpected token, Error Termination
		}

		Result<uint32, JsonParsingError> ParseHex4(Stream stream)
		{
			uint32 codepoint = 0; //BUG! cant sum char32, report to Beefy

			for (let i in ...3)
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
			String str = scope .(); // TODO: make it StringView instead

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
							if (JsonEscapes.IsEscape(e))
							{
								str.Append(e);
								stream.Skip(1);
								column++;
							}
							else if (e == 'u')
							{
								stream.Skip(1);
								column++;

								var codepoint = Try!(ParseHex4(stream));
								if (codepoint >= 0xD800 && codepoint <= 0xDFFF)
								{
									// high surrogate, check if followed by valid low surrogate
									if (codepoint <= 0xDBFF)
									{
										if (Consume(stream, '\\') case .Ok)
											return .Err(.InvalidStringSurrogate(line, column));

										if (Consume(stream, '\\') case .Ok)
											return .Err(.InvalidStringSurrogate(line, column));

										/*if (!Consume(stream, '\\') || !Consume(stream, 'u'))
										{
											return .Err(.InvalidStringSurrogate(line, column)); // Parse Error String Unicode Surrogate Invalid
										}*/

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

			SkipWhitespace(stream);

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
					SkipWhitespace(stream);

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

			SkipWhitespace(stream);

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
				SkipWhitespace(stream);

				if (Consume(stream, ',') case .Ok)
				{
					SkipWhitespace(stream);
				}
				else if (Consume(stream, ']') case .Ok)
				{
					if (!_handler.EndArray())
						return .Err(.UnexpectedToken(line, column, "")); // Error termination
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, ", or ]")); // Array Miss Comma Or Square Bracket
			}
		}

		Result<void, JsonParsingError> ParseNumber(Stream stream)
		{
			//TODO: can be avoided
			String strNumber = scope .();

			// Lazy way ... for testing
			// TODO: Properly handle numbers
			GETCHAR:while (stream.Peek<char8>() case .Ok(let c))
			{
				switch (c)
				{
				case '0': fallthrough;
				case '1': fallthrough;
				case '2': fallthrough;
				case '3': fallthrough;
				case '4': fallthrough;
				case '5': fallthrough;
				case '6': fallthrough;
				case '7': fallthrough;
				case '8': fallthrough;
				case '9': fallthrough;
				case '.': fallthrough;
				case 'E': fallthrough;
				case 'e': fallthrough;
				case '+': fallthrough;
				case '-':
					strNumber.Append(c);
					stream.Skip(1);
					column++;

				default: break GETCHAR;
				}
			}

			if (let number = double.Parse(strNumber))
			{
				if (!_handler.Double(number))
					return .Err(.InvalidValue(line, column)); // parse error termination
			}
			else
			{
				return .Err(.InvalidValue(line, column));
			}

			return .Ok;
		}

		Result<void, JsonParsingError> Consume(Stream stream, char32 expected)
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
					return .Err(.UnexpectedToken(line, column, scope $"{expected}"));
			}

			return .Err(.UnableToRead(line, column));
		}
	}
}
