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

		/// Lookup table for parsing: maps escape characters (after backslash) to their actual values.
		/// Index is the ASCII value of the escape character (e.g., 'n' -> '\n').
		/// Value of 0 means invalid escape sequence.
		private const char8[256] sEscapeLookup = InitEscapeLookup();

		/// Lookup table for serialization: maps control characters to their escape sequences.
		/// Index is the control character value. Value of 0 means no special escape needed.
		private const char8[256] sSerializeLookup = InitSerializeLookup();

		[Comptime]
		private static char8[256] InitEscapeLookup()
		{
			char8[256] table = .();
			// All values start as 0 (invalid)
			table['"'] = '"';
			table['/'] = '/';
			table['\\'] = '\\';
			table['b'] = '\b';
			table['f'] = '\f';
			table['n'] = '\n';
			table['r'] = '\r';
			table['t'] = '\t';
			return table;
		}

		[Comptime]
		private static char8[256] InitSerializeLookup()
		{
			char8[256] table = .();
			// Map control characters to their escape letter
			table['"'] = '"';
			table['\\'] = '\\';
			table['\b'] = 'b';
			table['\f'] = 'f';
			table['\n'] = 'n';
			table['\r'] = 'r';
			table['\t'] = 't';
			return table;
		}

		/// Fast O(1) lookup for escape character parsing.
		/// @param c The character after the backslash.
		/// @returns The unescaped character, or error if invalid escape.
		[Inline]
		public static Result<char8> Escape(char8 c)
		{
			let result = sEscapeLookup[(uint8)c];
			return result != 0 ? .Ok(result) : .Err;
		}

		/// Fast O(1) lookup for serialization escape sequences.
		/// @param c The character to check.
		/// @returns The escape letter (e.g., 'n' for '\n'), or 0 if no escape needed.
		[Inline]
		public static char8 GetEscapeChar(char8 c)
		{
			return sSerializeLookup[(uint8)c];
		}

		/// Checks if a character needs escaping during serialization.
		[Inline]
		public static bool NeedsEscape(char8 c)
		{
			return (uint8)c < 0x20 || sSerializeLookup[(uint8)c] != 0;
		}
	}
}
