using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;
using System.Diagnostics;
using System.Collections;
namespace BJSON
{
	public class Deserializer : IHandler
	{
		// this will gonna contain only container types
		Queue<JsonValue> treeStack = new .(32) ~ delete _;

		String currentKey = null;
		BumpAllocator keyAlloc = new .() ~ delete _;

		public Result<JsonValue, JsonParsingError> Deserialize(StringView jsonText)
		{
			let reader = scope Reader(this);

			let result = reader.Parse(scope StringStream(jsonText, .Reference));

			switch (result)
			{
			case .Ok:
				return this.treeStack.Front;
			case .Err(let err):
				for (var item in treeStack)
					item.Dispose();
				return .Err(err);
			}
		}

		//[SkipCall]
		void Log(String msg)
		{
			Console.WriteLine(msg);
		}

		public bool Null()
		{
			Log("Null value");

			let jVal = JsonNull();

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(jVal);
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document.As<JsonObject>()[currentKey] = jVal;
				currentKey = null;
				break;
			case .ARRAY:
				document.As<JsonArray>().Add(jVal);
				break;
			default: return false;
			}

			return true;
		}

		public bool Bool(bool value)
		{
			Log(scope $"Bool value: {value}");

			let jVal = JsonBool(value);

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(jVal);
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document.As<JsonObject>()[currentKey] = jVal;
				currentKey = null;
				break;
			case .ARRAY:
				document.As<JsonArray>().Add(jVal);
				break;
			default: return false;
			}

			return true;
		}

		public bool Double(double value)
		{
			Log(scope $"Double value: {value}");

			let jVal = JsonNumber(value);

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(jVal);
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document.As<JsonObject>()[currentKey] = jVal;
				currentKey = null;
				break;
			case .ARRAY:
				document.As<JsonArray>().Add(jVal);
				break;
			default: return false;
			}

			return true;
		}

		public bool String(StringView value, bool copy)
		{
			Log(scope $"String value: {value}");

			let jVal = JsonString(value);

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(jVal);
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document.As<JsonObject>()[currentKey] = jVal;
				currentKey = null;
				break;
			case .ARRAY:
				document.As<JsonArray>().Add(jVal);
				break;
			default: return false;
			}

			return true;
		}

		public bool StartObject()
		{
			Log("Start Object");

			if (treeStack.Count == 0)
			{
				// we are root here
				// root cant have key
				if (currentKey != null)
					return false;

				treeStack.Add(JsonObject());
			}
			else
			{
				var document = ref treeStack.Back;

				let jVal = JsonObject();

				switch (document.type)
				{
				case .OBJECT:
					if (currentKey == null)
						return false; //TODO: notify invalid key error

					document.As<JsonObject>()[currentKey] = jVal;
					currentKey = null;
					break;
				case .ARRAY:
					document.As<JsonArray>().Add(jVal);
					break;
				default: return false;
				}

				// add it to stack as current container
				treeStack.Add(jVal);
			}

			return true;
		}

		public bool Key(StringView str, bool copy)
		{
			Log(scope $"Key value: {str}");

			currentKey = new:keyAlloc String(str);

			return true;
		}

		public bool EndObject()
		{
			Log("End Object");

			if (treeStack.Count == 0)
				return false;

			//we dont pop root container
			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				// if the latest container we want to pop is not
				// an object then its a bad input
				if (val.type != .OBJECT)
					return false;
			}

			return true;
		}

		public bool StartArray()
		{
			Log("Start Array");

			if (treeStack.Count == 0)
			{
				// we are root here
				// root cant have key
				if (currentKey != null)
					return false;

				treeStack.Add(JsonArray());
			}
			else
			{
				var document = ref treeStack.Back;

				let jVal = JsonArray();

				switch (document.type)
				{
				case .OBJECT:
					if (currentKey == null)
						return false; //TODO: notify invalid key error

					document.As<JsonObject>()[currentKey] = jVal;
					currentKey = null;
					break;
				case .ARRAY:
					document.As<JsonArray>().Add(jVal);
					break;
				default: return false;
				}

				// add it to stack as current container
				treeStack.Add(jVal);
			}

			return true;
		}

		public bool EndArray()
		{
			Log("End Array");

			if (treeStack.Count == 0)
				return false;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				// if the latest container we want to pop is not
				// an object then its a bad input
				if (val.type != .ARRAY)
					return false;
			}

			return true;
		}
	}
}
