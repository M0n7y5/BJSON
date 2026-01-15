using System;
using System.IO;
using System.Collections;
using BJSON;
using BJSON.Models;
using BJSON.Attributes;
using BJSON.Enums;

namespace BJSON.Example
{
	// Define a class with [JsonObject] for automatic serialization/deserialization
	[JsonObject]
	class Person
	{
		public String Name = new .() ~ delete _;
		public int Age;
		public bool IsActive;

		[JsonPropertyName("email_address")]  // Custom JSON property name
		public String Email = new .() ~ delete _;

		public List<String> Tags = new .() ~ DeleteContainerAndItems!(_);

	[JsonIgnore(Condition = .Always)]  // This field won't be serialized
	public int InternalId;
	}

	class Program
	{
		public static int Main(String[] args)
		{
			// ============================================
			// Attribute-based Serialization/Deserialization
			// ============================================
			Console.WriteLine("=== Attribute-based JSON ===\n");
			{
				// Create and populate a Person object
				let person = scope Person();
				person.Name.Set("John Doe");
				person.Age = 30;
				person.IsActive = true;
				person.Email.Set("john@example.com");
				person.Tags.Add(new String("developer"));
				person.Tags.Add(new String("beef"));
				person.InternalId = 12345;  // This won't be serialized

				// Serialize to string using Json.Serialize<T>
				let output = scope String();
				Json.Serialize(person, output);
				Console.WriteLine("Serialized:");
				Console.WriteLine(output);
				Console.WriteLine();

				// Deserialize back using Json.Deserialize<T> with pre-allocated object
				let jsonInput = """
					{
						"Name": "Jane Smith",
						"Age": 25,
						"IsActive": false,
						"email_address": "jane@example.com",
						"Tags": ["designer", "artist"]
					}
					""";

				let stream = scope StringStream(jsonInput, .Reference);
				let restored = scope Person();

				if (Json.Deserialize<Person>(stream, restored) case .Ok)
				{
					Console.WriteLine("Deserialized:");
					Console.WriteLine(scope $"  Name: {restored.Name}");
					Console.WriteLine(scope $"  Age: {restored.Age}");
					Console.WriteLine(scope $"  IsActive: {restored.IsActive}");
					Console.WriteLine(scope $"  Email: {restored.Email}");
					Console.Write("  Tags: ");
					for (let tag in restored.Tags)
						Console.Write(scope $"{tag} ");
					Console.WriteLine("\n");
				}

				// Or use the allocating API (returns new object, caller must delete)
				let stream2 = scope StringStream(jsonInput, .Reference);
				if (Json.Deserialize<Person>(stream2) case .Ok(let newPerson))
				{
					defer delete newPerson;
					Console.WriteLine(scope $"Allocated Person: {newPerson.Name}, {newPerson.Age}");
				}
			}

			Console.WriteLine("\n=== JsonValue API ===\n");
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

				using (JsonValue json = Json.Deserialize(jsonString))
				{
					// Direct path access with GetByPointer
					if (StringView storeName = json.GetByPointer("/store/name"))
						Console.WriteLine(scope $"Store name: {storeName}");

					// Access array elements
					if (StringView productName = json.GetByPointer("/store/products/0/name"))
						Console.WriteLine(scope $"First product: {productName}");

					if (double price = json.GetByPointer("/store/products/1/price"))
						Console.WriteLine(scope $"Second product price: {price}");

					// GetByPointerOrDefault<T> - returns primitive default on failure (no allocation!)
					let addr = json.GetByPointerOrDefault<StringView>("/store/address", "N/A");
					Console.WriteLine(scope $"Address: {addr}");

					// Error handling
					if (json.GetByPointer("/invalid/path") case .Err(let err))
					{
						Console.WriteLine(scope $"Expected error: {err}");
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


			{

				// Serialize to JSON
				let person = scope Person();
				person.Name.Set("John Doe");
				person.Age = 30;

				let output = scope String();
				Json.Serialize(person, output);
				// Output: {"Name":"John Doe","Age":30,"IsActive":false,"email_address":"","Tags":[]}

				// Deserialize from JSON (pre-allocated object)
				let json = "{\"Name\":\"Jane\",\"Age\":25}";
				let stream = scope StringStream(json, .Reference);
				let restored = scope Person();
				Json.Deserialize<Person>(stream, restored);

				// Or use allocating API (caller must delete)
				let stream2 = scope StringStream(json, .Reference);
				if (Json.Deserialize<Person>(stream2) case .Ok(let newPerson))
				{
				    defer delete newPerson;
				    // use newPerson...
				}
			}

			return 0;
		}
	}
}