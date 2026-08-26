namespace BJSON.Enums
{
	/// The structural characters of RFC 8259, named so the writer emits punctuation without bare
	/// character literals. Each case's value is the character itself, so casting a case to char8
	/// yields the byte to write.
	enum JsonToken : char8
	{
		/// Opens an array.
		LEFT_SQUARE_BRACKET = '[',
		/// Opens an object.
		LEFT_CURLY_BRACKET = '{',
		/// Closes an array.
		RIGHT_SQUARE_BRACKET = ']',
		/// Closes an object.
		RIGHT_CURLY_BRACKET = '}',
		/// Separates an object key from its value.
		COLON = ':',
		/// Separates object members and array elements.
		COMMA = ',',
	}
}
