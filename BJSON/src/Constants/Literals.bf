using System;
namespace BJSON.Constants
{
	/// The three JSON keywords, in the lowercase spelling RFC 8259 fixes; JsonWriter writes them
	/// verbatim. The reader does not read these: it matches the same words with its own literals.
	static {
		public const StringView TrueLiteral = "true";
		public const StringView FalseLiteral = "false";
		public const StringView NullLiteral = "null";

		
	}
}
