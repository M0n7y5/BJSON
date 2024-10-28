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
		public bool Serialize(JsonValue json, String outText, bool isRoot = false)
		{
			switch (json.type)
			{
			case .NULL:
				return SerializeNull(json, outText, isRoot);
			case .BOOL:
				return SerializeBoolean(json, outText, isRoot);
			case .NUMBER:
				return SerializeNumber(json, outText, isRoot);
			case .NUMBER_FLOAT:
				return SerializeNumber(json, outText, isRoot);
			case .NUMBER_SIGNED:
				return SerializeNumber(json, outText, isRoot);
			case .NUMBER_UNSIGNED:
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

		bool SerializeNull(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			str.Append(NullLiteral);

			return true;
		}

		bool SerializeBoolean(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			bool boolean = value;

			str.Append(boolean ? TrueLiteral : FalseLiteral);

			return true;
		}

		bool SerializeNumber(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			switch (value.type)
			{
			case .NUMBER_UNSIGNED:
				str.Append(value.data.unsignedNumber.ToString(.. scope .()));
			case .NUMBER_SIGNED:
				str.Append(value.data.signedNumber.ToString(.. scope .()));
			case .NUMBER_FLOAT:
				str.Append(value.data.numberFloat.ToString(.. scope .()));
			case .NUMBER:
				str.Append(value.data.number.ToString(.. scope .(), "R", null));
			default:
				return false;
			}

			return true;
		}

		bool SerializeString(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			StringView string = value;
			let quoted = string.QuoteString(.. scope String());

			str.Append(quoted);

			return true;
		}

		bool SerializeArray(JsonValue value, String str, bool isRoot)
		{
			let array = value.AsArray().Value;

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

		bool SerializeObject(JsonValue value, String str, bool isRoot)
		{
			let obj = value.AsObject().Value;

			str.Append((char8)JsonToken.LEFT_CURLY_BRACKET);

			for (let item in obj)
			{
				let key = item.key.Quote(.. scope .());
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
				str.Append((char8)JsonToken.RIGHT_CURLY_BRACKET);

			return true;
		}
	}
}
