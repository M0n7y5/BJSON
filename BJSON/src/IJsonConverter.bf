using System;
using System.IO;
using BJSON.Models;

namespace BJSON;

/// Interface for custom JSON converters.
/// Implement this to provide custom serialization/deserialization logic for a type.
public interface IJsonConverter<T>
{
	/// Serializes a value to JSON and writes it to the stream.
	Result<void> WriteJson(Stream stream, T value);
	
	/// Deserializes a value from a JsonValue.
	Result<T> ReadJson(JsonValue value);
}
