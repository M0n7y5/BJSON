using System;
using BJSON.Models;

namespace BJSON;

/// Interface for types that can be serialized to and deserialized from JSON.
/// Types annotated with [JsonObject] will have these methods auto-generated at comptime.
interface IJsonSerializable
{
	/// Serializes this object to a JSON string.
	/// @param buffer The string buffer to write JSON to.
	/// @returns Ok on success, Err on serialization failure.
	public Result<void> JsonSerialize(String buffer);

	/// Deserializes a JSON value into this object.
	/// @param value The JsonValue to deserialize from.
	/// @returns Ok on success, Err on deserialization failure.
	public Result<void> JsonDeserialize(JsonValue value);
}