using System;
using BJSON.Models;

namespace BJSON
{
	static class Json
	{
		public static JsonVariant Deserialize(String json)
		{
			let deserializer = scope Deserializer();
			JsonVariant jsonVariant;

			//TODO: return bool or result
			deserializer.Deserialize(json, out jsonVariant, true);
			return jsonVariant;
		}

		public static bool Serialize(JsonVariant json, String outText)
		{
			let serializer = scope Serializer();

			return serializer.Serialize(json, outText, true);
		}


	}
}
