using System;
using BJSON.Models;

namespace BJSON
{
	static class Json
	{
		public static JsonVariant Deserialize(String json)
		{
			return default;
		}

		public static bool Serialize(JsonVariant json, String outText)
		{
			let serializer = scope Serializer();

			return serializer.Serialize(json, outText, true);
		}


	}
}
