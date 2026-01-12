using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;

namespace BJSON
{
	/// Provides static methods for JSON parsing and serialization.
	static class Json
	{

		/// Parses a JSON string into a JsonValue tree.
		/// @param json The JSON string to parse.
		/// @returns A Result containing the parsed JsonValue or a JsonParsingError on failure.
		public static Result<JsonValue, JsonParsingError> Deserialize(StringView json)
		{
			var deserializer = scope Deserializer();

			return deserializer.Deserialize(json);
		}

		/// Deserializes a JSON string for types implementing IJsonSerializable.
		/// @param json The JSON string to parse.
		/// @returns A Result containing the parsed JsonValue or a JsonParsingError on failure.
		public static Result<JsonValue, JsonParsingError> Deserialize<T>(StringView json) where T : IJsonSerializable
		{
			var deserializer = scope Deserializer();

			return deserializer.Deserialize(json);
		}

		/// Parses JSON from a stream into a JsonValue tree.
		/// @param stream The stream containing JSON data to parse.
		/// @returns A Result containing the parsed JsonValue or a JsonParsingError on failure.
		public static Result<JsonValue, JsonParsingError> Deserialize(Stream stream)
		{
			var deserializer = scope Deserializer();

			return deserializer.Deserialize(stream);
		}

		/// Converts a JsonValue to a minified JSON string.
		/// @param json The JsonValue to serialize.
		/// @param outText The string to append the serialized JSON to.
		/// @returns A Result indicating success or a JsonSerializationError on failure.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, String outText)
		{
			var stream = scope StringStream(outText, .Reference);
			var serializer = scope JsonWriter();

			return serializer.Write(json, stream);
		}

		/// Converts a JsonValue to a JSON string with formatting options.
		/// @param json The JsonValue to serialize.
		/// @param outText The string to append the serialized JSON to.
		/// @param options Formatting options controlling indentation and newlines.
		/// @returns A Result indicating success or a JsonSerializationError on failure.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, String outText, JsonWriterOptions options)
		{
			var stream = scope StringStream(outText, .Reference);
			var serializer = scope JsonWriter(options);

			return serializer.Write(json, stream, options);
		}

		/// Writes a JsonValue as minified JSON to a stream.
		/// @param json The JsonValue to serialize.
		/// @param stream The stream to write the JSON to.
		/// @returns A Result indicating success or a JsonSerializationError on failure.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, Stream stream)
		{
			var serializer = scope JsonWriter();

			return serializer.Write(json, stream);
		}

		/// Writes a JsonValue as JSON to a stream with formatting options.
		/// @param json The JsonValue to serialize.
		/// @param stream The stream to write the JSON to.
		/// @param options Formatting options controlling indentation and newlines.
		/// @returns A Result indicating success or a JsonSerializationError on failure.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, Stream stream, JsonWriterOptions options)
		{
			var serializer = scope JsonWriter(options);

			return serializer.Write(json, stream, options);
		}
	}
}
