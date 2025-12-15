using System;
namespace BJSON.Enums
{
	enum JsonEscapes : char8
	{
		case QUOTATION_MARK = '"';
		case SOLIDUS = '/';
		case REVERSE_SOLIDUS = '\\';
		case BACKSPACE = '\b';
		case FORM_FEED = '\f';
		case LINE_FEED = '\n';
		case CARRIAGE_RETURN = '\r';
		case TABULATOR = '\t';

		[Inline]
		public static bool IsEscape(char8 c)
		{
			switch ((Self)c)
			{
				case QUOTATION_MARK: return false;
				case SOLIDUS: return false;
				case REVERSE_SOLIDUS: return false;
				case BACKSPACE: return true;
				case FORM_FEED: return true;
				case LINE_FEED: return true;
				case CARRIAGE_RETURN: return true;
				case TABULATOR: return true;
				default: return false;
			}
		}

		[Inline]
		public static Result<char8> Escape(char8 c)
		{
			switch ((Self)c)
			{
				case QUOTATION_MARK: return '\"';
				case SOLIDUS: return '/';
				case REVERSE_SOLIDUS: return '\\';
				case 'b': return BACKSPACE.Underlying;
				case 'f': return FORM_FEED.Underlying;
				case 'n': return LINE_FEED.Underlying;
				case 'r': return CARRIAGE_RETURN.Underlying;
				case 't':
					return TABULATOR.Underlying;

				default: return .Err;
			}
		}
	}
}
