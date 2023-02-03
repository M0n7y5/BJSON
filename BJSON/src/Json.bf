using System;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON
{
	static class Json
	{
		public static Result<JsonVariant, JsonParsingError> Deserialize(StringView json)
		{
			let deserializer = scope Deserializer();

			return deserializer.Deserialize(json);
		}

		public static bool Serialize(JsonVariant json, String outText)
		{
			let serializer = scope Serializer();

			return serializer.Serialize(json, outText, true);
		}


	}
}
