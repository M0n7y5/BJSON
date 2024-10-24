using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;
namespace BJSON.Test
{
	class MainTest
	{
		[Test]
		public static void T_TestSuite1()
		{
			// https://github.com/nst/JSONTestSuite

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "Suite1");

			let files = Directory.EnumerateFiles(currentPath);
			int idx = 0;
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());

				let fileName = file.GetFileName(.. scope .());

				bool ignoreResult = fileName[0] == 'i';
				bool shouldFail = fileName[0] == 'n';

				let stream = scope FileStream();

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					Console.WriteLine(scope $"---> {fileName}");
					Debug.WriteLine(scope $"---> {idx++} {fileName}");

					var result = Json.Deserialize(stream);

					Console.WriteLine();

					result.Dispose();

					if (ignoreResult == false)
					{
						if (result case .Ok)
						{
							Test.Assert(shouldFail == false, scope $"This file should not be successfully parsed! {fileName}");
						}
						else
						{
							Test.Assert(shouldFail, scope $"This file should not fail to parse! {fileName}");
						}
					}

					Debug.WriteLine(scope $"{idx} Done testing file: {fileName} Result: {result case .Ok ? "Ok" : "Err"}");
				}
				else
				{
					Test.Assert(false, scope $"Unable to open file {fileName}");
				}
			}

			Debug.WriteLine("ALL TEST COMPLETED SUCESSFULLY!");
		}

		[Test]
		public static void T_TestSuite2()
		{
			// https://json.org/JSON_checker/

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "Suite2");

			let files = Directory.EnumerateFiles(currentPath);
			int idx = 0;
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());

				let fileName = file.GetFileName(.. scope .());

				if(fileName.StartsWith("fail1"))
				{
					//this test is not RFC 8259 compliant
					continue;
				}

				bool shouldFail = fileName.StartsWith("fail");

				let stream = scope FileStream();

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					Console.WriteLine(scope $"---> {fileName}");
					Debug.WriteLine(scope $"---> {idx++} {fileName}");

					var result = Json.Deserialize(stream);
					defer result.Dispose();

					Console.WriteLine();

					if (result case .Ok)
					{
						Test.Assert(shouldFail == false, scope $"This file should not be successfully parsed! {fileName}");
					}
					else
					{
						Test.Assert(shouldFail, scope $"This file should not fail to parse! {fileName}");
					}

					Debug.WriteLine(scope $"{idx} Done testing file: {fileName} Result: {result case .Ok ? "Ok" : "Err"}");
				}
				else
				{
					Test.Assert(false, scope $"Unable to open file {fileName}");
				}
			}

			Debug.WriteLine("ALL TEST COMPLETED SUCESSFULLY!");
		}


		//[Test]
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

			var json = JsonObject(); // root

			json["name"] = "lmao"; // create key-pair value
			json[3] = "Hello";

			let brr = json["lmao"][2];
			json["window"][2]["position"]["x"] = 500;
			json["window"][2]["position"]["y"] = 600;
			json["window"][2]["name"] = "Amogus";

			// initialize as array
			let json2 = JsonArray() { 2, 44, 65 };

			//initialize as object
			var json3 = JsonObject()
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
			StringView officeNumber = json3["phoneNumbers"][1]["number"];

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
