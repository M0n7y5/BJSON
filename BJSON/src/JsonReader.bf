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
				default: return ParseNumberEx(stream);
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
			uint32 codepoint = 0;

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
							else if (JsonEscapes.AllowedToEscape(e))
							{
								str.Append(e);
								stream.Skip(1);
								column++;
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

					currentDepth--;
					return .Ok;
				}
				else
					return .Err(.UnexpectedToken(line, column, ", or ]")); // Array Miss Comma Or Square Bracket
			}
		}

		Result<void, JsonParsingError> ParseNumberEx(Stream stream)
		{
			String strNumber = scope .(8);
			bool isNegative = false;
			bool hasFracPart = false;
			bool hasExpPart = false;
			uint startColumn = column;

			{
				// Check for minus sign
				if (stream.Peek<char8>() case .Ok(let c)) {
				    if (c == '-') {
				        isNegative = true;
				        strNumber.Append('-');
				        stream.Skip(1);
				        column++;
				    }
				} else {
				    return .Err(.UnableToRead(line, column));
				}
			}


			// Parse integer part
			bool hasDigit = false;
			bool leadingZero = false;

			while (stream.Peek<char8>() case .Ok(let c)) {
			    if (c >= '0' && c <= '9') {
			        hasDigit = true;
			        
			        // Check for leading zero followed by digit
			        if (strNumber.Length == (isNegative ? 1 : 0) && c == '0') {
			            leadingZero = true;
			        } else if (leadingZero && c >= '0' && c <= '9') {
			            return .Err(.UnexpectedToken(line, column, "fraction or exponent"));
			        }
			        
			        strNumber.Append(c);
			        stream.Skip(1);
			        column++;
			    } else if (c == '.') {
			        hasFracPart = true;
			        strNumber.Append('.');
			        stream.Skip(1);
			        column++;
			        
			        // Parse fractional part
			        bool hasFracDigit = false;
			        
			        while (stream.Peek<char8>() case .Ok(let fracC)) {
			            if (fracC >= '0' && fracC <= '9') {
			                hasFracDigit = true;
			                strNumber.Append(fracC);
			                stream.Skip(1);
			                column++;
			            } else if (fracC == 'e' || fracC == 'E') {
			                hasExpPart = true;
			                strNumber.Append(fracC);
			                stream.Skip(1);
			                column++;
			                break;
			            } else {
			                break;
			            }
			        }
			        
			        if (!hasFracDigit) {
			            return .Err(.UnexpectedToken(line, column, "digit after decimal point"));
			        }
			        
			        if (hasExpPart) {
			            // Handle exponent part
			            if (!ParseExponentToString(stream, strNumber)) {
			                return .Err(.UnexpectedToken(line, column, "exponent value"));
			            }
			        }
			        
			        break;
			    } else if (c == 'e' || c == 'E') {
			        hasExpPart = true;
			        strNumber.Append(c);
			        stream.Skip(1);
			        column++;
			        
			        // Handle exponent part
			        if (!ParseExponentToString(stream, strNumber)) {
			            return .Err(.UnexpectedToken(line, column, "exponent value"));
			        }
			        
			        break;
			    } else {
			        break; // End of number
			    }
			}

			if (!hasDigit) {
			    return .Err(.UnexpectedToken(line, column, "digit"));
			}

			// Determine if we're dealing with an extreme case that needs precise handling
			bool isExtreme = hasExpPart && strNumber.Contains('e');

			// For extreme cases or floating point numbers, use the built-in parser
			if (isExtreme || hasFracPart || hasExpPart) {
			    if (let value = double.Parse(strNumber)) {
			        if (!_handler.Number(value)) {
			            return .Err(.InvalidValue(line, startColumn));
			        }
			    } else {
			        return .Err(.InvalidValue(line, startColumn));
			    }
			} else {
			    // For integers, parse directly
			    if (isNegative) {
			        if (let value = int64.Parse(strNumber)) {
			            if (!_handler.Number(value)) {
			                return .Err(.InvalidValue(line, startColumn));
			            }
			        } else {
			            // Try as double if int64 parsing fails (overflow)
			            if (let value = double.Parse(strNumber)) {
			                if (!_handler.Number(value)) {
			                    return .Err(.InvalidValue(line, startColumn));
			                }
			            } else {
			                return .Err(.InvalidValue(line, startColumn));
			            }
			        }
			    } else {
			        if (let value = uint64.Parse(strNumber)) {
			            if (!_handler.Number(value)) {
			                return .Err(.InvalidValue(line, startColumn));
			            }
			        } else {
			            // Try as double if uint64 parsing fails (overflow)
			            if (let value = double.Parse(strNumber)) {
			                if (!_handler.Number(value)) {
			                    return .Err(.InvalidValue(line, startColumn));
			                }
			            } else {
			                return .Err(.InvalidValue(line, startColumn));
			            }
			        }
			    }
			}

			return .Ok;
		}

		// Helper method to parse exponent into the string representation
		bool ParseExponentToString(Stream stream, String strNumber)
		{
		    // Check for +/- sign
		    if (stream.Peek<char8>() case .Ok(let sign)) {
		        if (sign == '-' || sign == '+') {
		            strNumber.Append(sign);
		            stream.Skip(1);
		            column++;
		        }
		    }
		    
		    // Parse exponent digits
		    bool hasExpDigit = false;
		    
		    while (stream.Peek<char8>() case .Ok(let expC)) {
		        if (expC >= '0' && expC <= '9') {
		            hasExpDigit = true;
		            strNumber.Append(expC);
		            stream.Skip(1);
		            column++;
		        } else {
		            break;
		        }
		    }
		    
		    return hasExpDigit;
		}

		// Helper method to parse the exponent part of a number
		bool ParseExponent(Stream stream, ref int16 exp, ref bool expNegative)
		{
			// Check for +/- sign
			if (stream.Peek<char8>() case .Ok(let sign))
			{
				if (sign == '-')
				{
					expNegative = true;
					stream.Skip(1);
					column++;
				} else if (sign == '+')
				{
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

					// Check for exponent overflow
					if (exp > int16.MaxValue / 10)
					{
						// Exponent too large, clamp to maximum
						exp = expNegative ? int16.MinValue : int16.MaxValue;
						stream.Skip(1);
						column++;

						// Skip remaining digits
						while (stream.Peek<char8>() case .Ok(let skipC))
						{
							if (skipC >= '0' && skipC <= '9')
							{
								stream.Skip(1);
								column++;
							} else
							{
								break;
							}
						}

						return true;
					}

					exp = (int16)(exp * 10 + (expC - '0'));
					stream.Skip(1);
					column++;
				} else
				{
					break;
				}
			}

			return hasExpDigit;
		}

		// Helper method to continue parsing a number as double after integer overflow
		Result<void, JsonParsingError> ParseNumberAsDouble(Stream stream, double currentValue, bool isNegative)
		{
			var currentValue;
			bool hasFracPart = false;
			bool hasExpPart = false;
			int16 exp = 0;
			bool expNegative = false;

			// Continue parsing digits for the integer part
			while (stream.Peek<char8>() case .Ok(let c))
			{
				if (c >= '0' && c <= '9')
				{
					currentValue = currentValue * 10 + (c - '0');
					stream.Skip(1);
					column++;
				} else if (c == '.')
				{
					hasFracPart = true;
					stream.Skip(1);
					column++;
					break;
				} else if (c == 'e' || c == 'E')
				{
					hasExpPart = true;
					stream.Skip(1);
					column++;
					if (!ParseExponent(stream, ref exp, ref expNegative))
					{
						return .Err(.UnexpectedToken(line, column, "exponent value"));
					}
					break;
				} else
				{
					break; // End of number
				}
			}

			// Parse fractional part if present
			if (hasFracPart)
			{
				double div = 0.1;
				bool hasFracDigit = false;

				while (stream.Peek<char8>() case .Ok(let fracC))
				{
					if (fracC >= '0' && fracC <= '9')
					{
						hasFracDigit = true;
						currentValue += (fracC - '0') * div;
						div *= 0.1;
						stream.Skip(1);
						column++;
					} else if (fracC == 'e' || fracC == 'E')
					{
						hasExpPart = true;
						stream.Skip(1);
						column++;
						if (!ParseExponent(stream, ref exp, ref expNegative))
						{
							return .Err(.UnexpectedToken(line, column, "exponent value"));
						}
						break;
					} else
					{
						break;
					}
				}

				if (!hasFracDigit)
				{
					return .Err(.UnexpectedToken(line, column, "digit after decimal point"));
				}
			}

			// Parse exponent if not already parsed
			if (hasExpPart && exp == 0 && !expNegative)
			{
				if (!ParseExponent(stream, ref exp, ref expNegative))
				{
					return .Err(.UnexpectedToken(line, column, "exponent value"));
				}
			}

			// Apply exponent
			if (hasExpPart)
			{
				if (expNegative)
				{
					for (int16 i = 0; i < exp; i++)
					{
						currentValue *= 0.1;
					}
				} else
				{
					for (int16 i = 0; i < exp; i++)
					{
						currentValue *= 10;
					}
				}
			}

			// Apply sign
			if (isNegative)
			{
				currentValue = -currentValue;
			}

			// Hand off to handler
			if (!_handler.Number(currentValue))
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
