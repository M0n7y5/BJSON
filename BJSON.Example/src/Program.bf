using System;
using BJSON.Models;

namespace BJSON.Example
{
	class Program
	{
		public static int Main(String[] args)
		{
			/*var json2 = JsonVariant() { 2, 44, 65 };
			defer json2.Dispose();*/


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

			/*var json = JsonVariant();// root
			defer json.Dispose();

			json[42] = "Eyyyyyyy lmao";
			json[99] = "Sheesh";
			json[100] = 1345;
			json[142] = 999999;

			String noTruth = json[155]["entry"];

			json[155]["entry"] = "Is it working?";


			int array = json[142];
			String truth = json[155]["entry"];

			json["array"][5] = "Hello";

			let brr = json["lmao"][2];
			json["window"][2]["position"]["x"] = 500;
			json["window"][2]["position"]["y"] = 600;
			json["window"][2]["name"] = "Amogus";*/

			// initialize as array
			/*var json2 = JsonVariant() { 2, 44, 65 };
			defer json2.Dispose();

			let str2 = scope String();
			Json.Serialize(json2, str2);



			var json22 = JsonVariant()
				{
					("firstName", "John"),
					("lastName", "Smith"),
					("isAlive", true),
					("age", 27)
				};
			defer json22.Dispose();
			let str22 = scope String();
			Json.Serialize(json22, str22);*/



			//initialize as object
			var json3 = JsonVariant()
				{
					("firstName", "John"),
					("lastName", "Smith"),
					("isAlive", true),
					("age", 27),
					("phoneNumbers", .()
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
						}
					)
				};
			defer json3.Dispose();

			let str3 = scope String();
			Json.Serialize(json3, str3);



			String firstName = json3["firstName"];
			String lastName = json3["lastName"];

			int age = json3["age"];
			bool isAlive = json3["isAlive"];


			String numberType = json3["phoneNumbers"][1]["type"];
			String officeNumber = json3["phoneNumbers"][1]["number"];


			return 0;
		}
	}
}