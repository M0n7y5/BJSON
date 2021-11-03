using System;
using BJSON.Models;

namespace BJSON.Example
{
	class Program
	{
		public static int Main(String[] args)
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

			//JsonVariant testsss = default;

			var json = JsonVariant();// root

			int test = json["name"];
			String testStr = json["name"];


			json["name"] = "lmao";
			var lmao = json["name"];

			json["name"]["phoneNumber"] = 999999;
			json["name"]["phoneNumber2"] = 132456;

			var lmao2 = json["name"];
			var number = json["name"]["phoneNumber"];
			var number2 = json["name"]["phoneNumber2"];
			//json["name"]["phoneNumber2"] = 999999;

			json.Dispose();

			/*json["array"][5] = "Hello";

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
					("phoneNumbers", JsonVariant()
						{
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

			String officeNumber = json3["phoneNumbers"][1]["number"];*/


			return 0;
		}
	}
}