using System;
using BJSON.Models;
namespace BJSON.Test
{
	class MainTest
	{
		[Test]
		public static void TestMe()
		{
			/*var jsonString = @"""
{
  "firstName": "John",
  "lastName": "Smith",
  "isAlive": true,
  "age": 27
}
""";

			var person = Json.Deserialize(jsonString);
			int age = person["age"];*/

			var json = JsonVariant(); // root

			json["name"] = "lmao"; // create key-pair value
			json[3] = "Hello";

			let brr = json["lmao"][2];
			json["window"][2]["position"]["x"] = 500;
			json["window"][2]["position"]["y"] = 600;
			json["window"][2]["name"] = "Amogus";

			// initialize as array
			let json2 = JsonVariant() { 2, 44, 65 };

			//initialize as object
			let json3 = JsonVariant()
				{
					("firstName", "John"),
					("lastName", "Smith"),
					("isAlive", true),
					("age", 27),
					("phoneNumbers", JsonVariant() {
						JsonVariant()
						{
							("type", "home"),
							("number", "212 555-1234")
						},
						JsonVariant()
						{
							("type", "office"),
							("number", "646 555-4567")
						}
					})
				};
			String officeNumber = json3["phoneNumbers"][1]["number"];

			Test.Assert(false);
		}

		/*{
		  "firstName": "John",
		  "lastName": "Smith",
		  "isAlive": true,
		  "age": 27,
		  "address": {
			"streetAddress": "21 2nd Street",
			"city": "New York",
			"state": "NY",
			"postalCode": "10021-3100"
		  },
		  "phoneNumbers": [
			{
			  "type": "home",
			  "number": "212 555-1234"
			},
			{
			  "type": "office",
			  "number": "646 555-4567"
			}
		  ],
		  "children": [],
		  "spouse": null
		}*/

	}
}
