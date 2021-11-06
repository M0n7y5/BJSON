using System;
using BJSON.Models;
namespace BJSON.Test
{
	class MainTest
	{
		[Test]
		public static void Array_T()
		{
			var json2 = JsonVariant() { 2, 44, 65 };
			defer json2.Dispose();


			var json = JsonVariant();// root
			defer json.Dispose();

			json[42] = "Eyyyyyyy lmao";
			json[99] = "Sheesh";
			json[100] = 1345;
			json[142] = 999999;

			// should be null
			String noTruth = json[155]["entry"];
			Test.Assert(noTruth == null);

			json[155]["entry"] = "Is it working?";

			Test.Assert(json[42] == "Eyyyyyyy lmao");
			Test.Assert(json[99] == "Sheesh");
			Test.Assert(json[100] == 1345);
			Test.Assert(json[142] == 999999);
		}


		/*[Test]
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
			var json3 = JsonVariant()
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
		}*/

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
