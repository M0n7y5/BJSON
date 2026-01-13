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

	/// Deserializes a JSON value into this object.
	/// @param value The JsonValue to deserialize from.
	/// @returns Ok on success, Err on deserialization failure.
	public Result<void> JsonDeserialize(JsonValue value);
}