using System;
using BJSON.Models;
using System.Collections;
namespace BJSON.Enums
{
	enum JsonType
	{
		case NULL;

		//Complex data
		case OBJECT;
		case ARRAY;

		case STRING;

		// Simple Data
		case NUMBER;
		case BOOL;

		public Type GetType
		{
			get
			{
				switch (this)
				{
				case .OBJECT: return typeof(JsonObject);
				case .ARRAY: return typeof(JsonArray);
				case .NUMBER: return typeof(double);
				case .STRING: return typeof(String);
				case .BOOL: return typeof(bool);
				case .NULL: return null;

				}
			}
		}
	}
}
