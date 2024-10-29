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
		NUMBER,
		NUMBER_SIGNED,
		NUMBER_UNSIGNED,

		// String
		STRING,

		//Complex data
		OBJECT,
		ARRAY,

	}
}
