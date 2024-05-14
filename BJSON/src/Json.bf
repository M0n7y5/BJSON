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

		public static Result<JsonValue, JsonParsingError> Deserialize(Stream stream)
		{
			let deserializer = scope Deserializer();

			return deserializer.Deserialize(stream);
		}

		public static bool Serialize(JsonValue json, String outText)
		{
			let serializer = scope Serializer();

			return serializer.Serialize(json, outText, true);
		}


	}
}
