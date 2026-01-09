using BJSON.Attributes;
using BJSON;
using System;
using BJSON.Models;
namespace BJSON.Test;

class ReflectTest
{
	/*[JsonObject("red")]
	class Bar
	{
		public float Damage = 25.f;
	}*/

	[JsonObject("red")]
	class Foo
	{
		//public bool? IsSus = true;

		[JsonIgnore(Condition = .Never)]
		[JsonPropertyName("health")]
		//public float Health = (.)100;

		//[AttributeUsage(.Field)]
		public BingBong SomeRandomName = new .() ~ delete _;

		//public int[] numbers;

	}

	[JsonObject]
	class BingBong
	{

	};

	class Test
	{
		Result<BingBong> bb = new BingBong() ~ delete _.Value;
	}
}