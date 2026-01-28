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

	// ============================================
	// Examples of new features
	// ============================================

	// Base class for inheritance example
	[JsonObject]
	class Entity
	{
		public int Id;
		public bool Active;
	}

	// Derived class - inherits Id and Active from Entity
	[JsonObject]
	class Player : Entity
	{
		public String Name = new .() ~ delete _;
		public int Score;
	}

	// Enum that serializes as string by default
	[JsonObject]
	class DefaultStatus
	{
		public enum Status { Inactive, Active, Suspended }
		public Status State;
	}

	// Enum with [JsonNumberHandling] to serialize as number
	[JsonNumberHandling(.AsNumber)]
	public enum NumericStatus { Inactive, Active, Suspended }

	[JsonObject]
	class NumericStatusHolder
	{
		public NumericStatus State;
	}

	// Simple CustomDateTime struct for custom converter example
	struct CustomDateTime
	{
		public int Year;
		public int Month;
		public int Day;
		public int Hour;
		public int Minute;
		public int Second;

		public this(int year, int month, int day, int hour = 0, int minute = 0, int second = 0)
		{
			Year = year;
			Month = month;
			Day = day;
			Hour = hour;
			Minute = minute;
			Second = second;
		}

		public override void ToString(String str)
		{
			str.AppendF($"{Year:D4}-{Month:D2}-{Day:D2}T{Hour:D2}:{Minute:D2}:{Second:D2}");
		}

		public static Result<CustomDateTime> Parse(StringView str)
		{
			// Simple ISO 8601 parser: YYYY-MM-DDTHH:MM:SS
			if (str.Length < 19)
				return .Err;

			var dt = CustomDateTime(0, 0, 0);
			if (int.Parse(str.Substring(0, 4)) case .Ok(let year))
				dt.Year = year;
			else
				return .Err;

			if (int.Parse(str.Substring(5, 2)) case .Ok(let month))
				dt.Month = month;
			else
				return .Err;

			if (int.Parse(str.Substring(8, 2)) case .Ok(let day))
				dt.Day = day;
			else
				return .Err;

			if (int.Parse(str.Substring(11, 2)) case .Ok(let hour))
				dt.Hour = hour;
			else
				return .Err;

			if (int.Parse(str.Substring(14, 2)) case .Ok(let minute))
				dt.Minute = minute;
			else
				return .Err;

			if (int.Parse(str.Substring(17, 2)) case .Ok(let second))
				dt.Second = second;
			else
				return .Err;

			return .Ok(dt);
		}
	}

	// Custom converter that serializes CustomDateTime as ISO 8601 string
	class DateTimeConverter : IJsonConverter<CustomDateTime>
	{
		public Result<void> WriteJson(Stream stream, CustomDateTime value)
		{
			let str = scope String();
			value.ToString(str);
			BJSON.JsonWriter.WriteString(stream, str);
			return .Ok;
		}

		public Result<CustomDateTime> ReadJson(JsonValue value)
		{
			if (!value.IsString())
				return .Err;

			if (CustomDateTime.Parse((StringView)value) case .Ok(let dt))
				return .Ok(dt);

			return .Err;
		}
	}

	[JsonObject]
	class CalendarEvent
	{
		public String Title = new .() ~ delete _;
		
		[JsonConverter(typeof(DateTimeConverter))]
		public CustomDateTime Timestamp;
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
				person.Email = "john@example.com";
				person.Tags.Add(new String("developer"));
				person.Tags.Add(new String("beef"));
				person.InternalId = 12345;  // This won't be serialized

				// Serialize to string using Json.Serialize<T>
				let output = Json.Serialize(person, .. scope .());
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

			Console.WriteLine("\n=== Inheritance Support ===\n");
			{
				let player = scope Player();
				player.Id = 42;           // Inherited field
				player.Active = true;     // Inherited field
				player.Name.Set("Alice");
				player.Score = 1000;

				// Serialize - includes all fields from both base and derived classes
				let json = Json.Serialize(player, .. scope .());
				Console.WriteLine("Player with inheritance:");
				Console.WriteLine(json);
				Console.WriteLine();

				// Deserialize - works seamlessly with inherited fields
				let inputJson = """
					{
						"Id": 99,
						"Active": false,
						"Name": "Bob",
						"Score": 500
					}
					"""
					;

				let stream = scope StringStream(inputJson, .Reference);
				let restored = scope Player();
				if (Json.Deserialize<Player>(stream, restored) case .Ok)
				{
					Console.WriteLine("Deserialized Player:");
					Console.WriteLine(scope $"  Id (from Entity): {restored.Id}");
					Console.WriteLine(scope $"  Active (from Entity): {restored.Active}");
					Console.WriteLine(scope $"  Name (from Player): {restored.Name}");
					Console.WriteLine(scope $"  Score (from Player): {restored.Score}");
				}
			}

			Console.WriteLine("\n=== Enum Serialization as Number ===\n");
			{
				// Default behavior: serializes as string
				let defaultHolder = scope DefaultStatus();
				defaultHolder.State = .Active;
				let defaultJson = Json.Serialize(defaultHolder, .. scope .());
				Console.WriteLine("Default enum (as string):");
				Console.WriteLine(defaultJson);

				// With attribute: serializes as number
				let numericHolder = scope NumericStatusHolder();
				numericHolder.State = .Active;
				let numericJson = Json.Serialize(numericHolder, .. scope .());
				Console.WriteLine("\nWith [JsonNumberHandling(.AsNumber)]:");
				Console.WriteLine(numericJson);

				// Deserialization accepts both formats by default
				let input1 = """
					{"State":"Suspended"}
					""";  // String format
				let input2 = """
					{"State":2}
					""";  // Number format

				let stream1 = scope StringStream(input1, .Reference);
				let result1 = scope NumericStatusHolder();
				if (Json.Deserialize<NumericStatusHolder>(stream1, result1) case .Ok)
				{
					Console.WriteLine(scope $"\nDeserialized from string: {result1.State}");
				}

				let stream2 = scope StringStream(input2, .Reference);
				let result2 = scope NumericStatusHolder();
				if (Json.Deserialize<NumericStatusHolder>(stream2, result2) case .Ok)
				{
					Console.WriteLine(scope $"Deserialized from number: {result2.State}");
				}
			}

			Console.WriteLine("\n=== Custom Converters ===\n");
			{
				// Custom converter that serializes CustomDateTime as ISO 8601 string
				let eventObj = scope CalendarEvent();
				eventObj.Title.Set("Meeting");
				eventObj.Timestamp = CustomDateTime(2025, 1, 28, 14, 30, 0);

				let json = Json.Serialize(eventObj, .. scope .());
				Console.WriteLine("Event with custom CustomDateTime converter:");
				Console.WriteLine(json);

				// Deserialize using the custom converter
				let input = """
					{"Title":"Conference","Timestamp":"2025-06-15T09:00:00"}
					""";

				let stream = scope StringStream(input, .Reference);
				let restored = scope CalendarEvent();
				if (Json.Deserialize<CalendarEvent>(stream, restored) case .Ok)
				{
					Console.WriteLine("\nDeserialized Event:");
					Console.WriteLine(scope $"  Title: {restored.Title}");
					Console.WriteLine(scope $"  Timestamp: {restored.Timestamp}");
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

			return 0;
		}
	}
}