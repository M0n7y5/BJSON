using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;

namespace BJSON
{
	static class Json
	{
		public static Result<JsonValue, JsonParsingError> Deserialize(StringView json)
		{
			let deserializer = scope Deserializer();
			return deserializer.Deserialize(json);
		}

		public static Result<JsonValue, JsonParsingError> Deserialize<T>(StringView json) where T : IJsonSerializable
		{
			let deserializer = scope Deserializer();
			return deserializer.Deserialize(json);
		}

		public static Result<JsonValue, JsonParsingError> Deserialize(Stream stream)
		{
			let deserializer = scope Deserializer();
			return deserializer.Deserialize(stream);
		}

		public static bool Serialize(JsonValue json, String outText)
		{
			let serializer = scope JsonWriter();
			return serializer.Write(json, outText, true);
		}

		public static bool Stringify(String outText)
		{
			let stringifier = scope Stringifier();
			return stringifier.Stringify(outText);
		}

	}
}
