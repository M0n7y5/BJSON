using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;

namespace BJSON
{
	/// Provides static methods for JSON parsing and serialization.
	static class Json
	{
		//==========================================================================
		// DESERIALIZATION - JsonValue API
		//==========================================================================

		/// Parses a JSON string into a JsonValue tree.
		/// @param json The JSON string to parse.
		/// @returns A Result containing the parsed JsonValue or a JsonParsingError on failure.
		public static Result<JsonValue, JsonParsingError> Deserialize(StringView json)
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

		//==========================================================================
		// DESERIALIZATION - Generic API (for types with [JsonObject])
		//==========================================================================

		/// Deserializes JSON from a stream into a pre-allocated object.
		/// The object type must have [JsonObject] attribute or implement IJsonSerializable.
		/// @param stream The stream containing JSON data to parse.
		/// @param obj The pre-allocated object to populate.
		/// @returns A Result indicating success or a JsonParsingError on failure.
		public static Result<void, JsonParsingError> Deserialize<T>(Stream stream, T obj) where T : IJsonSerializable
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize(stream);
			defer result.Dispose();

			if (result case .Err(let err))
				return .Err(err);

			if (obj.JsonDeserialize(result.Value) case .Err)
				return .Err(.InvalidDocument);

			return .Ok;
		}

		/// Deserializes JSON from a stream, allocating a new object.
		/// The object type must have [JsonObject] attribute or implement IJsonSerializable.
		/// Caller is responsible for deleting the returned object.
		/// @param stream The stream containing JSON data to parse.
		/// @returns A Result containing the new object or a JsonParsingError on failure.
		public static Result<T, JsonParsingError> Deserialize<T>(Stream stream) where T : IJsonSerializable, new, class, delete
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize(stream);
			defer result.Dispose();

			if (result case .Err(let err))
				return .Err(err);

			let obj = new T();
			if (obj.JsonDeserialize(result.Value) case .Err)
			{
				delete obj;
				return .Err(.InvalidDocument);
			}

			return .Ok(obj);
		}

		//==========================================================================
		// SERIALIZATION - JsonValue API
		//==========================================================================

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

		//==========================================================================
		// SERIALIZATION - Generic API (for types with [JsonObject])
		//==========================================================================

		/// Serializes an object with [JsonObject] attribute to a stream.
		/// @param obj The object to serialize.
		/// @param stream The stream to write JSON to.
		/// @returns A Result indicating success or failure.
		public static Result<void> Serialize<T>(T obj, Stream stream) where T : IJsonSerializable
		{
			return obj.JsonSerialize(stream);
		}

		/// Serializes an object with [JsonObject] attribute to a string.
		/// @param obj The object to serialize.
		/// @param outText The string to append the serialized JSON to.
		/// @returns A Result indicating success or failure.
		public static Result<void> Serialize<T>(T obj, String outText) where T : IJsonSerializable
		{
			var stream = scope StringStream(outText, .Reference);
			return obj.JsonSerialize(stream);
		}
	}
}
