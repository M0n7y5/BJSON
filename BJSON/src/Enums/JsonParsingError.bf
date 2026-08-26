using System;
namespace BJSON.Enums
{
	/// Failure reported by JsonReader.Parse and by the Json and Deserializer entry points above it.
	/// On the cases that carry them, line and column are the reader's 1-based position when the
	/// fault was detected; column restarts at 1 after each line break.
	enum JsonParsingError
	{
		/// Parse was handed a null stream.
		case InputStreamIsNull;
		/// The parse produced no root value for the handler to hand back, or a generated
		/// JsonDeserialize rejected the tree that was parsed.
		case InvalidDocument;
		/// Object or array nesting passed JsonReader.MaximumDepth of 200. Carries no position, so
		/// the offending brace or bracket has to be found from the document itself.
		case MaximumDepthReached;
		/// A number literal did not fit the reader's 1024 character buffer.
		/// line and column locate the character that no longer fit.
		case NumberTooLong(uint line, uint column);
		/// A peek or read on the stream failed: truncated input, or an I/O error.
		/// line and column locate the cursor at the failed read.
		case UnableToRead(uint line, uint column);
		/// A complete value was refused: the handler returned false from Bool, String, Key or
		/// Number, or the accumulated number text failed double.Parse.
		/// line and column locate the value; for a number, column is where the literal started.
		case InvalidValue(uint line, uint column);
		/// The character read here is not allowed by the grammar at this point, or a structural
		/// handler callback (StartObject, EndObject, StartArray, EndArray, Null) returned false.
		/// line and column locate the cursor. expected is the text the reader would have accepted,
		/// such as "end of document", ", or }" or "exponent value", and stays empty when a handler
		/// refusal leaves no token to name; ToString then drops the expected clause.
		case UnexpectedToken(uint line, uint column, StringView expected);
		/// A \u escape was not followed by four hexadecimal digits.
		/// line and column locate the character that is not a hex digit.
		case InvalidUnicodeHexEscape(uint line, uint column);
		/// A \u escape yielded a lone surrogate: a high surrogate with no \u low surrogate behind
		/// it, or a low surrogate on its own.
		/// line and column locate the escape that broke the pair.
		case InvalidStringSurrogate(uint line, uint column);
		/// A backslash was followed by a character that is neither 'u' nor an escape letter that
		/// JsonEscapes.Escape accepts.
		/// line and column locate the character behind the backslash.
		case InvalidEscapeToken(uint line, uint column);
		/// Raw input is not valid UTF-8: a value starting on a byte >= 0x80, a broken continuation
		/// byte, an overlong form, an encoded surrogate half, or a code point above U+10FFFF.
		/// line and column locate the start of the sequence.
		case InvalidEncoding(uint line, uint column);

		public override void ToString(String string)
		{
			switch (this)
			{
			case InputStreamIsNull:
				string.Append("Provided Stream is null!");
			case InvalidDocument:
				string.Append("Parsed document is not valid!");
		case MaximumDepthReached:
			string.Append("Reached maximum supported depth for nested structures! More than 200 levels.");
		case NumberTooLong(let line, let column):
			string.AppendF("Number exceeds maximum length of 1024 characters! Line {}, Column {}.", line, column);
			case UnableToRead(let line, let column):
				string.AppendF("Unable to read from Stream! Line {}, Column {}.", line, column);
			case InvalidValue(let line, let column):
				string.AppendF("Invalid value! Line {}, Column {}.", line, column);
			case UnexpectedToken(let line, let column, let expected):
				if (expected.IsEmpty)
					string.AppendF("Unexpected token! Line {}, Column {}.", line, column);
				else
					string.AppendF("Unexpected token! Expected {}, Line {}, Column {}.", expected.QuoteString(.. scope String()), line, column);
			case InvalidUnicodeHexEscape(let line, let column):
				string.AppendF("Invalid Unicode Hex Escape! Line {}, Column {}.", line, column);
			case InvalidStringSurrogate(let line, let column):
				string.AppendF("Invalid String Surrogate! Line {}, Column {}.", line, column);
			case InvalidEscapeToken(let line, let column):
				string.AppendF("Invalid Escape Token! Line {}, Column {}.", line, column);
			case InvalidEncoding(let line, let column):
				string.AppendF("Invalid UTF-8 encoding! Line {}, Column {}.", line, column);
			}
		}
	}
}

