using BJSON.Models;
using System;
using BJSON.Constants;
using BJSON.Enums;
namespace BJSON
{
	class JsonWriter
	{
		public this()
		{
		}

		//TODO: Return a result with ErrorEnum
		public bool Write(JsonValue json, String outText, bool isRoot = false)
		{
			switch (json.type)
			{
			case .NULL:
				return WriteNull(json, outText, isRoot);
			case .BOOL:
				return WriteBoolean(json, outText, isRoot);
			case .NUMBER:
				return WriteNumber(json, outText, isRoot);
			/*case .NUMBER_FLOAT:
				return SerializeNumber(json, outText, isRoot);*/
			case .NUMBER_SIGNED:
				return WriteNumber(json, outText, isRoot);
			case .NUMBER_UNSIGNED:
				return WriteNumber(json, outText, isRoot);
			case .STRING:
				return WriteString(json, outText, isRoot);
			case .ARRAY:
				return WriteArray(json, outText, isRoot);
			case .OBJECT:
				return WriteObject(json, outText, isRoot);

			default:
				return false;

			}
		}

		bool WriteNull(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			str.Append(NullLiteral);

			return true;
		}

		bool WriteBoolean(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			bool boolean = value;

			str.Append(boolean ? TrueLiteral : FalseLiteral);

			return true;
		}

		bool WriteNumber(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			switch (value.type)
			{
			case .NUMBER_UNSIGNED:
				str.Append(value.data.unsignedNumber.ToString(.. scope .()));
			case .NUMBER_SIGNED:
				str.Append(value.data.signedNumber.ToString(.. scope .()));
			/*case .NUMBER_FLOAT:
				str.Append(value.data.numberFloat.ToString(.. scope .()));*/
			case .NUMBER:
				let number = value.data.number;

				if(number.IsNaN || number.IsInfinity)
				{
					//for now return false
					return false;
				}

				char8[25] buff;
				BJSON.Internal.dtoa(value.data.number, &buff);
				str.Append(&buff);
			default:
				return false;
			}

			return true;
		}

		bool WriteString(JsonValue value, String str, bool isRoot)
		{
			if (isRoot)
				return false;

			StringView string = value;
			let quoted = string.QuoteString(.. scope String());

			str.Append(quoted);

			return true;
		}

		bool WriteArray(JsonValue value, String str, bool isRoot)
		{
			let array = value.AsArray().Value;

			str.Append((char8)JsonToken.LEFT_SQUARE_BRACKET);

			for (let item in array)
			{
				if (!Write(item, str))
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

		bool WriteObject(JsonValue value, String str, bool isRoot)
		{
			let obj = value.AsObject().Value;

			str.Append((char8)JsonToken.LEFT_CURLY_BRACKET);

			for (let item in obj)
			{
				let key = item.key.Quote(.. scope .());
				key.Append(":");

				str.Append(key);

				if (!Write(item.value, str))
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
