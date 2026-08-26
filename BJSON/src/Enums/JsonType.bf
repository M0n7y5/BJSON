using System;
using BJSON.Models;
using System.Collections;
namespace BJSON.Enums
{
	/// Tag that says which member of the JsonData union a JsonValue holds. JsonValue keeps this
	/// tag in a 4 bit bitfield, so no case may exceed 15.
	enum JsonType : uint8
	{
		/// Holds nothing. Value 0, so a default-constructed JsonValue is a JSON null.
		NULL = 0,

		/// Holds data.boolean.
		BOOL = 1,

		/// Holds data.number. The reader picks this tag for a literal with a fraction or an
		/// exponent, for an integer too large for 64 bits, and for a bare -0.
		NUMBER,
		/// Holds data.signedNumber, the tag for an integer that fits int64.
		NUMBER_SIGNED,
		/// Holds data.unsignedNumber, the tag for an integer above int64.MaxValue.
		NUMBER_UNSIGNED,

		/// Holds data.string, or data.smallStr when the smallString bit is set.
		STRING,

		/// Holds data.object, a Dictionary of key to JsonValue.
		OBJECT,
		/// Holds data.array, a List of JsonValue.
		ARRAY,

	}
}
