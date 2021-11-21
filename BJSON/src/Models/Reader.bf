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

		public this(IHandler handler)
		{
			this._handler = handler;
		}

		public Result<void> Parse(Stream stream)
		{
			if (stream == null)
				Runtime.FatalError("Stream can not be null!");

			SkipWhitespace(stream);

			if (let c = stream.Peek<char8>())
			{
				if (c == 0)
					return .Err;// Document empty
				else
					return ParseValue(stream);
			}
			else
				return .Err;// Document empty
		}

		void SkipWhitespace(Stream stream)
		{
			while (stream.Peek<char8>() case .Ok(let c))
			{
				if (c.IsWhiteSpace)
					stream.Skip(1);
				else
					break;
			}
		}

		Result<void> ParseValue(Stream stream)
		{
			switch (stream.Peek<char8>())
			{
			case .Err:
				return .Err;
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



		Result<void> ParseNull(Stream stream)
		{
			if (Consume(stream, 'n') &&
				Consume(stream, 'u') &&
				Consume(stream, 'l') &&
				Consume(stream, 'l'))
			{
				if (!_handler.Null())
					return .Err;//invalid value
				return .Ok;
			}

			return .Err;// unexpected token, Error Termination
		}

		Result<void> ParseBool(Stream stream)
		{
			if (let c = stream.Peek<char8>())// TODO: use read
				switch (c)
				{
				case 't':// parse true
					if (Consume(stream, 't') &&// TODO: omit this in future
						Consume(stream, 'r') &&
						Consume(stream, 'u') &&
						Consume(stream, 'e'))
					{
						if (!_handler.Bool(true))
							return .Err;//invalid value
						return .Ok;
					}
				case 'f':// parse true
					if (Consume(stream, 'f') &&
						Consume(stream, 'a') &&
						Consume(stream, 'l') &&
						Consume(stream, 's') &&
						Consume(stream, 'e'))
					{
						if (!_handler.Bool(false))
							return .Err;//invalid value
						return .Ok;
					}
				}

			return .Err;// unexpected token, Error Termination
		}

		uint32 ParseHex4(Stream stream)
		{
			uint32 codepoint = 0;//BUG! cant sum char32, report to Beefy

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
					else//TODO: make it more verbose
						Runtime.FatalError("Invalid Unicode Hex Escape");

					stream.Skip(1);// handle potential exception?
				}
			}

			return codepoint;
		}


		Result<void> ParseString(Stream stream, bool isKey = false)
		{
			String str = scope .();

			if (let c = stream.Peek<char8>())
			{
				if (c == '"')
					stream.Skip(1);
				else
					return .Err;// unexpected token, Error Termination
			}
			else
				return .Err;//Peek error

			for (;;)
			{
				if (let c = stream.Peek<char8>())
				{
					if (c == '\\')// handle escaping
					{
						stream.Skip(1);
						if (let e = stream.Peek<char8>())
						{
							if (JsonEscapes.IsEscape(e))
							{
								str.Append(e);
								stream.Skip(1);
							}
							else if (e == 'u')
							{
								stream.Skip(1);

								uint32 codepoint = (.)ParseHex4(stream);
								if (codepoint >= 0xD800 && codepoint <= 0xDFFF)
								{
									// high surrogate, check if followed by valid low surrogate
									if (codepoint <= 0xDBFF)
									{
										if (!Consume(stream, '\\') || !Consume(stream, 'u'))
										{
											return .Err;// Parse Error String Unicode Surrogate Invalid
										}

										uint32 codepoint2 = ParseHex4(stream);
										if (codepoint2 < 0xDC00 || codepoint2 > 0xDFFF)
										{
											return .Err;// Parse Error String Unicode Surrogate Invalid
										}
										codepoint = (((codepoint - 0xD800) << 10) | (codepoint2 - 0xDC00)) + 0x10000;
									}
									else
									{
										return .Err;// Parse Error String Unicode Surrogate Invalid
									}
								}

								str.Append((char32)codepoint);
							}
							else
								return .Err;// Error String Escape Invalid
						}
						else
							return .Err;// peek error
					}
					else if (c == '"')// Closing double quote
					{
						bool res = false;

						if (isKey)
							res = _handler.Key(str, true);
						else
							res = _handler.String(str, true);

						stream.Skip(1);

						return res ? .Ok : .Err;// OK or Parse Error Termination
					}
					else if (c < (.)0x20)
					{
						if (c == '\0')
							return .Err;// String Miss Quotation Mark
						else
							return .Err;// invalid encoding
					}
					else
					{
						str.Append(c);
						stream.Skip(1);
					}
				}
				else
					return .Err;// peek error
			}
		}

		Result<void> ParseObject(Stream stream)
		{
			stream.Skip(1);//skip {

			if (!_handler.StartObject())
			{
				return .Err;// Parse Error Termination
			}

			SkipWhitespace(stream);

			if (Consume(stream, '}'))
			{
				if (!_handler.EndObject())
					return .Err;// Error Termination

				return .Ok;// empty object
			}

			for (;;)
			{
				if (let c = stream.Peek<char8>())
				{
					if (c != '"')
						return .Err;// MISSING OBJECT NAME

					ParseString(stream, true);
					SkipWhitespace(stream);

					if (!Consume(stream, ':'))
						return .Err;// Error Object Miss Colon

					SkipWhitespace(stream);
					ParseValue(stream);

					SkipWhitespace(stream);

					if (let nextC = stream.Peek<char8>())
					{
						switch (nextC)
						{
						case ',':
							stream.Skip(1);
							SkipWhitespace(stream);
						case '}':
							stream.Skip(1);
							if (!_handler.EndObject())
								return .Err;//Parse error termination
							return .Ok;
						default:
							return .Err;// Object Miss Comma Or Curly Bracket

						}
					}
				}
				else
					return .Err;// peek error
			}
		}

		Result<void> ParseArray(Stream stream)
		{
			stream.Skip(1);//skip [

			if (!_handler.StartArray())
			{
				return .Err;// Parse Error Termination
			}

			SkipWhitespace(stream);

			if (Consume(stream, ']'))
			{
				if (!_handler.EndArray())
					return .Err;// Error termination
				else
					return .Ok;// empty array
			}

			for (;;)
			{
				Try!(ParseValue(stream));
				SkipWhitespace(stream);

				if (Consume(stream, ','))
				{
					SkipWhitespace(stream);
				}
				else if (Consume(stream, ']'))
				{
					if (!_handler.EndArray())
						return .Err;// Error termination
					return .Ok;
				}
				else
					return .Err;// Array Miss Comma Or Square Bracket
			}
		}

		Result<void> ParseNumber(Stream stream)
		{
			//TODO: can be avoided
			String strNumber = scope .();

			// Lazy way ... for testing
			// TODO: Properly handle numbers
			GETCHAR: while (stream.Peek<char8>() case .Ok(let c))
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
				default: break GETCHAR;
				}
			}

			double number = double.Parse(strNumber);
			if (!_handler.Double(number))
				return .Err;// parse error termination

			/*let minus = Consume(stream, '-');
			if (minus)
			{
				strNumber.Append('-');
			}


			if (let c = stream.Peek<char8>())
			{
				if (c == '0')
				{
					strNumber.Append(c);
					stream.Skip(1);
				}
			}
			else if (let c = stream.Peek<char8>())
			{
				if (c >= '1' && c <= '9')
				{
					strNumber.Append(c);
					stream.Skip(1);
				}
			}*/


			return .Ok;
		}

		bool Consume(Stream stream, char8 expected)
		{
			if (let c = stream.Peek<char8>())
				if (c == expected)
				{
					stream.Skip(1);
					return true;
				}

			return false;
		}
	}
}
