using System;
namespace BJSON.Models
{
	/// Interface for handling JSON parsing events in a SAX-style manner.
	/// Implement this interface to receive callbacks during JSON parsing.
	interface IHandler
	{
		/// Called when a null value is encountered.
		bool Null();
		/// Called when a boolean value is encountered.
		bool Bool(bool b);
		/// Called when a floating-point number is encountered.
		bool Number(double n);
		/// Called when a signed integer number is encountered.
		bool Number(int64 n);
		/// Called when an unsigned integer number is encountered.
		bool Number(uint64 n);
		/// Called when a string value is encountered.
		bool String(StringView str, bool copy);
		/// Called when an object begins.
		bool StartObject();
		/// Called when an object key is encountered.
		bool Key(StringView str, bool copy);
		/// Called when an object ends.
		bool EndObject();
		/// Called when an array begins.
		bool StartArray();
		/// Called when an array ends.
		bool EndArray();
	}
}
