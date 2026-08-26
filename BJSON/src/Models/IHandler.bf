using System;
namespace BJSON.Models
{
	/// SAX style contract that JsonReader drives: the reader walks the document once and reports
	/// every value, key and structural boundary in document order, holding no tree of its own.
	/// Deserializer is the implementation that assembles a JsonValue tree from these calls.
	/// Returning false from any callback aborts the parse at once: the reader stops reading and
	/// reports .InvalidValue for a refused scalar or key, .UnexpectedToken for a refused null or
	/// structural boundary.
	public interface IHandler
	{
		/// Called for the literal null.
		bool Null();
		/// Called for the literal true or false; b says which.
		bool Bool(bool b);
		/// Called for a number that needs a double: it carries a fraction or an exponent, its
		/// integer part does not fit 64 bits, or it is a bare -0.
		bool Number(double n);
		/// Called for an integer literal that fits int64, negative or not.
		bool Number(int64 n);
		/// Called for an integer literal above int64.MaxValue.
		bool Number(uint64 n);
		/// Called for a finished string value, once the closing quote is reached; keys go to Key
		/// instead.
		/// str views the reader's scratch buffer, which dies when this call returns, so a handler
		/// that keeps the text must copy it. copy states that need and the reader always passes
		/// true.
		bool String(StringView str, bool copy);
		/// Called on '{', before any member.
		bool StartObject();
		/// Called for a member name, ahead of the callbacks for its value. str has the same
		/// scratch buffer lifetime as in String.
		bool Key(StringView str, bool copy);
		/// Called on '}', after the last member of that object. Objects nest, so start and end
		/// calls pair up and the handler tracks its own position.
		bool EndObject();
		/// Called on '[', before any element.
		bool StartArray();
		/// Called on ']', after the last element of that array.
		bool EndArray();
	}
}
