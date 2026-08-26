using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;

namespace BJSON
{
	/// The public entry points for parsing and serializing JSON.
	static class Json
	{
		/// Parses JSON text into a JsonValue tree.
		/// @param json The document text.
		/// @returns The parsed tree, which the caller owns and must Dispose, or the first parse error.
		public static Result<JsonValue, JsonParsingError> Deserialize(StringView json)
		{
			var deserializer = scope Deserializer();

			return deserializer.Deserialize(json);
		}

		/// Parses a JSON stream into a JsonValue tree, reading it to the end.
		/// @param stream The stream to read.
		/// @returns The parsed tree, which the caller owns and must Dispose, or the first parse error.
		public static Result<JsonValue, JsonParsingError> Deserialize(Stream stream)
		{
			var deserializer = scope Deserializer();

			return deserializer.Deserialize(stream);
		}

		/// Parses a JSON stream into an existing object through its emitted deserializer.
		/// The intermediate tree is disposed before returning, so nothing aliases the document.
		/// @param stream The stream to read.
		/// @param obj The object to fill. Pre construct its nested class and container fields.
		/// @returns Ok, the parse error wrapped in ParseError, or the binding error the emitted
		/// deserializer reported.
		public static Result<void, JsonDeserializationError> Deserialize<T>(Stream stream, T obj) where T : IJsonSerializable
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize(stream);
			defer result.Dispose();

			if (result case .Err(let parseErr))
				return .Err(.ParseError(parseErr));

			return obj.JsonDeserialize(result.Value);
		}

		/// Parses a JSON stream into a newly allocated object.
		/// @param stream The stream to read.
		/// @returns The new object, which the caller owns and must delete, the parse error wrapped
		/// in ParseError, or the binding error the emitted deserializer reported.
		public static Result<T, JsonDeserializationError> Deserialize<T>(Stream stream) where T : IJsonSerializable, new, class, delete
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize(stream);
			defer result.Dispose();

			if (result case .Err(let parseErr))
				return .Err(.ParseError(parseErr));

			let obj = new T();
			if (obj.JsonDeserialize(result.Value) case .Err(let bindErr))
			{
				delete obj;
				return .Err(bindErr);
			}

			return .Ok(obj);
		}

		/// Parses JSON text into an existing object through its emitted deserializer.
		/// The intermediate tree is disposed before returning, so nothing aliases the document.
		/// @param json The document text.
		/// @param obj The object to fill. Pre construct its nested class and container fields.
		/// @returns Ok, the parse error wrapped in ParseError, or the binding error the emitted
		/// deserializer reported.
		public static Result<void, JsonDeserializationError> Deserialize<T>(StringView json, T obj) where T : IJsonSerializable
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize(json);
			defer result.Dispose();

			if (result case .Err(let parseErr))
				return .Err(.ParseError(parseErr));

			return obj.JsonDeserialize(result.Value);
		}

		/// Parses JSON text into a newly allocated object.
		/// @param json The document text.
		/// @returns The new object, which the caller owns and must delete, the parse error wrapped
		/// in ParseError, or the binding error the emitted deserializer reported.
		public static Result<T, JsonDeserializationError> Deserialize<T>(StringView json) where T : IJsonSerializable, new, class, delete
		{
			var deserializer = scope Deserializer();
			var result = deserializer.Deserialize(json);
			defer result.Dispose();

			if (result case .Err(let parseErr))
				return .Err(.ParseError(parseErr));

			let obj = new T();
			if (obj.JsonDeserialize(result.Value) case .Err(let bindErr))
			{
				delete obj;
				return .Err(bindErr);
			}

			return .Ok(obj);
		}

		/// Serializes a JsonValue tree, appending the text to a caller owned String.
		/// @param json The tree to write.
		/// @param outText The buffer to append to. Existing content is kept.
		/// @returns Ok, or the first write or structure error.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, String outText)
		{
			var stream = scope StringStream(outText, .Reference);
			stream.Position = outText.Length;
			var serializer = scope JsonWriter();

			return serializer.Write(json, stream);
		}

		/// Serializes a JsonValue tree with formatting options, appending to a caller owned String.
		/// @param json The tree to write.
		/// @param outText The buffer to append to. Existing content is kept.
		/// @param options Indentation and newline settings.
		/// @returns Ok, or the first write or structure error.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, String outText, JsonWriterOptions options)
		{
			var stream = scope StringStream(outText, .Reference);
			stream.Position = outText.Length;
			var serializer = scope JsonWriter(options);

			return serializer.Write(json, stream, options);
		}

		/// Serializes a JsonValue tree to a stream.
		/// @param json The tree to write.
		/// @param stream The destination. A failed or short write ends the document with an error.
		/// @returns Ok, or the first write or structure error.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, Stream stream)
		{
			var serializer = scope JsonWriter();

			return serializer.Write(json, stream);
		}

		/// Serializes a JsonValue tree to a stream with formatting options.
		/// @param json The tree to write.
		/// @param stream The destination. A failed or short write ends the document with an error.
		/// @param options Indentation and newline settings.
		/// @returns Ok, or the first write or structure error.
		public static Result<void, JsonSerializationError> Serialize(JsonValue json, Stream stream, JsonWriterOptions options)
		{
			var serializer = scope JsonWriter(options);

			return serializer.Write(json, stream, options);
		}

		/// Serializes a typed object to a stream through its emitted serializer.
		/// @param obj The object to write.
		/// @param stream The destination. A failed or short write ends the document with an error.
		/// @returns Ok, or the error the emitted serializer reported.
		public static Result<void, JsonSerializationError> Serialize<T>(T obj, Stream stream) where T : IJsonSerializable
		{
			return obj.JsonSerialize(stream);
		}

		/// Serializes a typed object to a stream with formatting options.
		/// @param obj The object to write.
		/// @param stream The destination. A failed or short write ends the document with an error.
		/// @param options Indentation and newline settings.
		/// @returns Ok, or the error the emitted serializer reported.
		public static Result<void, JsonSerializationError> Serialize<T>(T obj, Stream stream, JsonWriterOptions options) where T : IJsonSerializable
		{
			return obj.JsonSerialize(stream, options);
		}

		/// Serializes a typed object, appending the text to a caller owned String.
		/// @param obj The object to write.
		/// @param outText The buffer to append to. Existing content is kept.
		/// @returns Ok, or the error the emitted serializer reported.
		public static Result<void, JsonSerializationError> Serialize<T>(T obj, String outText) where T : IJsonSerializable
		{
			var stream = scope StringStream(outText, .Reference);
			stream.Position = outText.Length;

			return Serialize<T>(obj, stream);
		}

		/// Serializes a typed object with formatting options, appending to a caller owned String.
		/// @param obj The object to write.
		/// @param outText The buffer to append to. Existing content is kept.
		/// @param options Indentation and newline settings.
		/// @returns Ok, or the error the emitted serializer reported.
		public static Result<void, JsonSerializationError> Serialize<T>(T obj, String outText, JsonWriterOptions options) where T : IJsonSerializable
		{
			var stream = scope StringStream(outText, .Reference);
			stream.Position = outText.Length;

			return Serialize<T>(obj, stream, options);
		}
	}
}
