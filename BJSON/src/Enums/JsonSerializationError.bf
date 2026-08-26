using System;

namespace BJSON.Enums
{
	/// Failure reported by JsonWriter and by the JsonSerialize methods generated for [JsonObject]
	/// types. No case carries a payload: the writer walks values, so there is no text position.
	enum JsonSerializationError
	{
		/// A JsonValue reached the number writer without one of the three number tags.
		case InvalidNumber;
		/// The float or double being written is NaN, which RFC 8259 has no literal for.
		case NaNNotAllowed;
		/// The float or double being written is positive or negative infinity, which RFC 8259 has
		/// no literal for.
		case InfinityNotAllowed;
		/// The JsonValue carries a type tag the writer has no branch for.
		case UnknownType;
		/// The destination stream refused the bytes: Stream.Write or WriteStrUnsized returned Err.
		case StreamWriteFailed;
		/// Object or array nesting passed JsonWriter's 200 level limit, so a tree that contains
		/// itself fails here instead of overflowing the stack. Only the JsonValue tree writer
		/// counts depth; the generated JsonSerialize methods do not.
		case MaximumDepthReached;

		public override void ToString(String string)
		{
			switch (this)
			{
			case InvalidNumber:
				string.Append("Invalid number value!");
			case NaNNotAllowed:
				string.Append("NaN is not a valid JSON number value!");
			case InfinityNotAllowed:
				string.Append("Infinity is not a valid JSON number value!");
			case UnknownType:
				string.Append("Unknown JSON type encountered!");
			case StreamWriteFailed:
				string.Append("Writing to the stream failed!");
			case MaximumDepthReached:
				string.Append("Maximum nesting depth reached!");
			}
		}
	}
}
