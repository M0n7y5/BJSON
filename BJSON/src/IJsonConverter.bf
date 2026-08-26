using System;
using System.IO;
using BJSON.Models;

namespace BJSON;

/// Custom handling for one type, selected with [JsonConverter].
/// The generated code creates a converter with new for every value it converts and deletes it
/// straight after, so an implementation needs a parameterless constructor and may keep no state
/// between values.
public interface IJsonConverter<T>
{
	/// Writes value as exactly one complete JSON value: no key, no separators, and the stream stays
	/// open for the rest of the document.
	/// Err aborts the whole serialization.
	Result<void> WriteJson(Stream stream, T value);
	
	/// Builds a value from the already parsed JSON for this field. value belongs to the caller's
	/// JsonValue tree, so it must not be disposed here.
	/// Err aborts the whole deserialization. A reference result is stored into the field or added to
	/// the collection and owned from there on, and the assignment does not delete what the field
	/// held before.
	Result<T> ReadJson(JsonValue value);
}
