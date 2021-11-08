using BJSON.Models;
using System;
using BJSON.Constants;
using BJSON.Enums;
namespace BJSON
{
	class Serializer
	{
		public this()
		{
		}

		//TODO: Return a result with ErrorEnum
		public bool Serialize(JsonVariant json, String outText, bool isRoot = false)
		{
			switch (json.JType)
			{
			case .NULL:
				return SerializeNull(json, outText, isRoot);
			case .BOOL:
				return SerializeBoolean(json, outText, isRoot);
			case .NUMBER:
				return SerializeNumber(json, outText, isRoot);
			case .STRING:
				return SerializeString(json, outText, isRoot);
			case .ARRAY:
				return SerializeArray(json, outText, isRoot);
			case .OBJECT:
				return SerializeObject(json, outText, isRoot);

			default:
				return false;

			}
		}

		bool SerializeNull(JsonVariant jsonVariant, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			str.Append(NullLiteral);

			return true;
		}

		bool SerializeBoolean(JsonVariant jsonVariant, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			let boolean = jsonVariant;

			str.Append(boolean ? TrueLiteral : FalseLiteral);

			return true;
		}

		bool SerializeNumber(JsonVariant jsonVariant, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			double number = jsonVariant;

			str.Append(number.ToString(.. scope .()));

			return true;
		}

		bool SerializeString(JsonVariant jsonVariant, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			String string = jsonVariant;
			let quoted = string.QuoteString(.. scope String());

			str.Append(quoted);

			return true;
		}


		bool SerializeArray(JsonVariant jsonVariant, String str, bool isRoot)
		{
			JsonArray array = jsonVariant;
			if (array == null)
				return false;

			str.Append((char8)JsonToken.LEFT_SQUARE_BRACKET);

			for (let item in array)
			{
				if (!Serialize(item, str))
					return false;

				//WARN: for now this will create trailing comma
				str.Append((char8)JsonToken.COMMA);
			}

			// handle trailing comma
			if (str[str.Length - 1] == ',')
				str[str.Length - 1] = (char8)JsonToken.RIGHT_SQUARE_BRACKET;
			else
				str.Append((char8)JsonToken.RIGHT_SQUARE_BRACKET);

			return true;
		}

		bool SerializeObject(JsonVariant jsonVariant, String str, bool isRoot)
		{
			JsonObject obj = jsonVariant;
			if (obj == null)
				return false;

			str.Append((char8)JsonToken.LEFT_CURLY_BRACKET);

			for (let item in obj)
			{
				let key = item.key.QuoteString(.. scope .());
				key.Append(":");

				str.Append(key);

				if (!Serialize(item.value, str))
					return false;

				str.Append((char8)JsonToken.COMMA);
			}

			// handle trailing comma
			if (str[str.Length - 1] == ',')
				str[str.Length - 1] = (char8)JsonToken.RIGHT_CURLY_BRACKET;
			else
				str.Append((char8)JsonToken.LEFT_CURLY_BRACKET);

			return true;
		}
	}
}
