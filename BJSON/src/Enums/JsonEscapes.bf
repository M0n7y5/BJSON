using System;
namespace BJSON.Enums
{
	enum JsonEscapes : char8
	{
		case QUOTATION_MARK = '"';
		case REVERSE_SOLIDUS = '\\';
		case SOLIDUS = '/';
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
			case QUOTATION_MARK: return true;
			case REVERSE_SOLIDUS: return true;
			case SOLIDUS: return true;
			case BACKSPACE: return true;
			case FORM_FEED: return true;
			case LINE_FEED: return true;
			case CARRIAGE_RETURN: return true;
			case TABULATOR: return true;
			default: return false;
			}
		}

	}
}
