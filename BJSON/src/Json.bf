using System;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON
{
	static class Json
	{
		public static Result<JsonValue, JsonParsingError> Deserialize(StringView json)
		{
			let deserializer = scope Deserializer();

			return deserializer.Deserialize(json);
		}

		public static bool Serialize(JsonValue json, String outText)
		{
			let serializer = scope Serializer();

			return serializer.Serialize(json, outText, true);
		}


	}
}
