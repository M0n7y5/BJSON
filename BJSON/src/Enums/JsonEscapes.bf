using System;
namespace BJSON.Enums
{
	/// The two escape tables JsonReader and JsonWriter share, one per direction.
	/// Both are built from character literals: RFC 8259 fixes the eight escapes JSON allows, so a
	/// named constant per escape would only restate a table entry that cannot be built from it.
	static class JsonEscapes
	{
		/// Comptime built table mapping the byte value of the character that follows a
		/// backslash to the character it decodes to, so JsonReader unescapes in one indexed
		/// load. A 0 entry means the byte is not a legal JSON escape.
		private const char8[256] sEscapeLookup = InitEscapeLookup();

		/// Comptime built table mapping a character that must be escaped on output to the
		/// letter written after the backslash ('\n' -> 'n'). A 0 entry means the character is
		/// emitted verbatim, which also covers control characters below 0x20: they have no
		/// escape letter and the caller must emit them as \u00XX.
		private const char8[256] sSerializeLookup = InitSerializeLookup();

		[Comptime]
		private static char8[256] InitEscapeLookup()
		{
			char8[256] table = .();
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
		/// @returns The escape letter (e.g. 'n' for '\n'), or 0 when no escape letter exists.
		/// Control characters below 0x20 also return 0 and must be written as \u00XX.
		[Inline]
		public static char8 GetEscapeChar(char8 c)
		{
			return sSerializeLookup[(uint8)c];
		}
	}
}
