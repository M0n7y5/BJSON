using System;
using System.IO;
using BJSON.Models;

namespace BJSON;

/// Interface for types that can be serialized to and deserialized from JSON.
/// Types annotated with [JsonObject] will have these methods auto-generated at comptime.
interface IJsonSerializable
{
	/// Serializes this object to a stream.
	/// @param stream The stream to write JSON to.
	/// @returns Ok on success, Err on serialization failure.
	public Result<void> JsonSerialize(Stream stream);

	/// Serializes this object to a stream with formatting options.
	/// @param stream The stream to write JSON to.
	/// @param options Formatting options (indentation, newlines).
	/// @returns Ok on success, Err on serialization failure.
	public Result<void> JsonSerialize(Stream stream, JsonWriterOptions options);

	/// Deserializes a JSON value into this object.
	/// @param value The JsonValue to deserialize from.
	/// @returns Ok on success, Err on deserialization failure.
	public Result<void> JsonDeserialize(JsonValue value);
}