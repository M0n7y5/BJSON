using System;
using BJSON.Models;
using System.IO;
using BJSON.Attributes;

namespace BJSON.Example
{
	class Program
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

		public static int Main(String[] args)
		{
			{
				// Basic serialization
				let json = JsonObject()
					{
						("firstName", "John"),
						("lastName", "Smith"),
						("isAlive", true),
						("age", 27)
					};
				defer json.Dispose();

				let output = scope String();
				Json.Serialize(json, output);
				Console.WriteLine(output);
			}

			Console.WriteLine();
			{
				// More complex JSON object with pretty print enabled
				let json = JsonObject()
					{
						("firstName", "John"),
						("lastName", "Smith"),
						("isAlive", true),
						("age", 27),
						("phoneNumbers", JsonArray()
							{
								JsonObject()
									{
										("type", "home"),
										("number", "212 555-1234")
									},

								JsonObject()
									{
										("type", "office"),
										("number", "646 555-4567")
									}
							})
					};
				defer json.Dispose();
				let output = scope String();
				let options = JsonWriterOptions() { Indented = true };
				Json.Serialize(json, output, options);
				Console.WriteLine(output);
			}

			return 0;
		}
	}
}