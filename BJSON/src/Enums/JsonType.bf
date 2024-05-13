using System;
using BJSON.Models;
using System.Collections;
namespace BJSON.Enums
{
	enum JsonType : uint8
	{
		NULL = 0,

		// Simple Data
		BOOL = 1,
		NUMBER = 2,
		STRING = 4,
		//Complex data
		OBJECT = 8,
		ARRAY = 16,
		/*public Type GetType
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
		}*/
	}
}
