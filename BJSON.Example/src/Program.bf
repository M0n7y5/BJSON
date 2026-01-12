using System;
using BJSON.Models;
using System.IO;
using BJSON.Attributes;

namespace BJSON.Example
{
	class Program
	{
		public static int Main(String[] args)
		{
			{
				let jsonString = "{\"name\":\"BJSON\",\"version\":1.0}";
				var result = Json.Deserialize(jsonString);
				defer result.Dispose();

				if (result case .Ok(let jsonValue))
				{
					// we expect object
				    if (let root = jsonValue.AsObject())
				    {
				        if (StringView name = root.GetValue("name"))
				            Console.WriteLine(name);
				    }
				}
				else if (result case .Err(let error))
				{
				    Console.WriteLine("Error: {}", error);
				}
				//Note: You can also use switch case statement as well
			}

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

			Console.WriteLine();
			{
				// JSON Pointer (RFC 6901) - Navigate nested structures by path
				let jsonString = """
				{
				  "store": {
				    "name": "My Shop",
				    "products": [
				      {"id": 1, "name": "Apple", "price": 1.50},
				      {"id": 2, "name": "Banana", "price": 0.75}
				    ]
				  }
				}
				""";

				var result = Json.Deserialize(jsonString);
				defer result.Dispose();

				if (result case .Ok(let json))
				{
					// Direct path access with GetByPointer
					if (let storeName = json.GetByPointer("/store/name"))
						Console.WriteLine(scope $"Store name: {(StringView)storeName}");

					// Access array elements
					if (let productName = json.GetByPointer("/store/products/0/name"))
						Console.WriteLine(scope $"First product: {(StringView)productName}");

					if (let price = json.GetByPointer("/store/products/1/price"))
						Console.WriteLine(scope $"Second product price: {(double)price}");

					// GetByPointerOrDefault - returns default on failure
					let missing = json.GetByPointerOrDefault("/store/address", "N/A");
					Console.WriteLine(scope $"Address: {(StringView)missing}");

					// Error handling
					if (json.GetByPointer("/invalid/path") case .Err(let err))
					{
						let errStr = scope String();
						err.ToString(errStr);
						Console.WriteLine(scope $"Expected error: {errStr}");
					}
				}
			}

			Console.WriteLine();
			{
				// JSONC (JSON with Comments)
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);

				let jsonWithComments = """
				{
				  // Single-line comment
				  "setting": "bing bong",
				  /* Multi-line comment */
				  "enabled": true
				}
				""";

				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				if (result case .Ok(let val))
				{
					/* YOLO Errors
					StringView settings = val["setting"];
					Console.WriteLine(scope $"Settings value: {settings}");
					*/

					// or safer way
					if (let root = val.AsObject())
					{
						if (StringView test = root.GetValue("setting"))
						{
							Console.WriteLine(test);
						}
					}
				}
				else if (result case .Err(let err))
				{
					Console.WriteLine(err);
				}
			}

			return 0;
		}
	}
}