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
		public static Result<JsonValue, JsonParsingError> Deserialize(StringView json)
		{
			var deserializer = scope Deserializer();

			return deserializer.Deserialize(json);
		}

		public static Result<JsonValue, JsonParsingError> Deserialize(Stream stream)
		{
			var deserializer = scope Deserializer();

			return deserializer.Deserialize(stream);
		}

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

		public static Result<void, JsonSerializationError> Serialize(JsonValue json, String outText)
		{
			var stream = scope StringStream(outText, .Reference);
			var serializer = scope JsonWriter();

			return serializer.Write(json, stream);
		}

		public static Result<void, JsonSerializationError> Serialize(JsonValue json, String outText, JsonWriterOptions options)
		{
			var stream = scope StringStream(outText, .Reference);
			var serializer = scope JsonWriter(options);

			return serializer.Write(json, stream, options);
		}

		public static Result<void, JsonSerializationError> Serialize(JsonValue json, Stream stream)
		{
			var serializer = scope JsonWriter();

			return serializer.Write(json, stream);
		}

		public static Result<void, JsonSerializationError> Serialize(JsonValue json, Stream stream, JsonWriterOptions options)
		{
			var serializer = scope JsonWriter(options);

			return serializer.Write(json, stream, options);
		}

		public static Result<void> Serialize<T>(T obj, Stream stream) where T : IJsonSerializable
		{
			return obj.JsonSerialize(stream);
		}

		public static Result<void> Serialize<T>(T obj, Stream stream, JsonWriterOptions options) where T : IJsonSerializable
		{
			return obj.JsonSerialize(stream, options);
		}

		public static Result<void> Serialize<T>(T obj, String outText) where T : IJsonSerializable
		{
			var stream = scope StringStream(outText, .Reference);
			return obj.JsonSerialize(stream);
		}

		public static Result<void> Serialize<T>(T obj, String outText, JsonWriterOptions options) where T : IJsonSerializable
		{
			var stream = scope StringStream(outText, .Reference);
			return obj.JsonSerialize(stream, options);
		}
	}
}
