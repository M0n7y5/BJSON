using System;
namespace BJSON.Enums
{
	enum JsonParsingError
	{
		case InputStreamIsNull;
		case DocumentIsEmpty;
		case InvalidDocument;
		case UnableToRead(uint line, uint column);
		case InvalidValue(uint line, uint column);
		case UnexpectedToken(uint line, uint column, StringView expected);
		case InvalidUnicodeHexEscape(uint line, uint column);
		case InvalidStringSurrogate(uint line, uint column);
		case InvalidEscapeToken(uint line, uint column);
		case MissingQuotationMark(uint line, uint column);
		case InvalidEncoding(uint line, uint column);

		public void ToString(String string)
		{
			switch (this)
			{
			case InputStreamIsNull:
				string.Append("Provided Stream is null!");
			case InvalidDocument:
				string.Append("Parsed document is not valid!");
			case DocumentIsEmpty:
				string.Append("Attempt to parse empty string!");
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
			case MissingQuotationMark(let line, let column):
				string.AppendF("Missing Quotation Mark! Line {}, Column {}.", line, column);
			case InvalidEncoding(let line, let column):
				string.AppendF("Invalid Encoding! Line {}, Column {}.", line, column);
			}
		}
	}
}

