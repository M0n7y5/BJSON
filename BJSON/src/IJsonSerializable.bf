using System;
using System.IO;
using BJSON.Models;

namespace BJSON;

/// JSON entry points for a type. [JsonObject] adds this interface and emits all three method
/// bodies at comptime, so a type either gets them generated or writes them by hand.
/// All three return a bare Result<void>: the JsonSerializationError detail the writer produces
/// does not reach the caller.
interface IJsonSerializable
{
	/// Serializes this object to a stream with default options, which means compact output.
	/// @param stream The stream to write JSON to.
	/// @returns Ok on success, Err on serialization failure.
	public Result<void> JsonSerialize(Stream stream);

	/// Serializes this object to a stream with formatting options.
	/// @param stream The stream to write JSON to.
	/// @param options Formatting options (indentation, newlines).
	/// @returns Ok on success, Err on serialization failure.
	public Result<void> JsonSerialize(Stream stream, JsonWriterOptions options);

	/// Deserializes a JSON value into this object, assigning the fields of this instance in place.
	/// A key that is absent leaves its field untouched, and an error stops at the offending field,
	/// so the fields read before it keep their new values.
	/// @param value The JsonValue to deserialize from.
	/// @returns Ok on success, Err on deserialization failure.
	public Result<void> JsonDeserialize(JsonValue value);
}