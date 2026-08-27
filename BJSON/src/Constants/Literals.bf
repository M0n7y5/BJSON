using System;
namespace BJSON.Constants
{
	/// The three JSON keywords, in the lowercase spelling RFC 8259 fixes. JsonWriter writes them
	/// verbatim and JsonReader matches them character by character, so the spelling has one home.
	static {
		public const StringView TrueLiteral = "true";
		public const StringView FalseLiteral = "false";
		public const StringView NullLiteral = "null";

		
	}
}
