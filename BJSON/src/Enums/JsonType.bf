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

		//Number types
		NUMBER = 2,
		NUMBER_FLOAT = 3,
		NUMBER_SIGNED = 4,
		NUMBER_UNSIGNED = 5,

		// String
		STRING = 6,

		//Complex data
		OBJECT = 7,
		ARRAY = 8,

	}
}
