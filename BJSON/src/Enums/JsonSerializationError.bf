using System;

namespace BJSON.Enums
{
	enum JsonSerializationError
	{
		case InvalidNumber;
		case NaNNotAllowed;
		case InfinityNotAllowed;
		case UnknownType;

		public void ToString(String string)
		{
			switch (this)
			{
			case InvalidNumber:
				string.Append("Invalid number value!");
			case NaNNotAllowed:
				string.Append("NaN is not a valid JSON number value!");
			case InfinityNotAllowed:
				string.Append("Infinity is not a valid JSON number value!");
			case UnknownType:
				string.Append("Unknown JSON type encountered!");
			}
		}
	}
}
