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
		enum NodeState
		{
			VALUE,
			OBJECT,
			ARRAY
		}

		Queue<(StringView key, JsonVariant value, JsonVariant* parrent, NodeState state)> treeStack = new .() ~ delete _;

		StringView currentKey = .();

		public bool Deserialize(StringView jsonText, out JsonVariant json, bool isRoot = false)
		{
			let reader = scope Reader(this);

			reader.Parse(scope StringStream(jsonText, .Reference));

			if (treeStack.Count != 1) // we should have only one root object at the end of parsing
			{
				json = .();
				return false;
			}

			json = this.treeStack.Front.value;

			return true;
		}

		void Log(String msg)
		{
			Console.WriteLine(msg);
		}

		public bool Null()
		{
			Log("Null value");

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = Variant();
				break;
			case .OBJECT:
				if (currentKey.IsEmpty)
					return false; //TODO: notify invalid key error

				document[currentKey.ToString(.. scope .())] = Variant();

				currentKey.Clear();
				break;
			case .ARRAY:
				document.Add(Variant());
				break;
			}

			return true;
		}

		public bool Bool(bool value)
		{
			Log(scope $"Bool value: {value}");

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = value;
				break;
			case .OBJECT:
				if (currentKey.IsEmpty)
					return false; //TODO: notify invalid key error

				document[currentKey.ToString(.. scope .())] = value;
				currentKey.Clear();
				break;
			case .ARRAY:
				document.Add(value);
				break;
			}

			return true;
		}

		public bool Double(double value)
		{
			Log(scope $"Double value: {value}");

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = value;
				break;
			case .OBJECT:
				if (currentKey.IsEmpty)
					return false; //TODO: notify invalid key error

				document[currentKey.ToString(.. scope .())] = value;
				currentKey.Clear();
				break;
			case .ARRAY:
				document.Add(value);
				break;
			}

			return true;
		}

		public bool String(StringView value, bool copy)
		{
			Log(scope $"String value: {value}");

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = value;
				break;
			case .OBJECT:
				if (currentKey.IsEmpty)
					return false; //TODO: notify invalid key error

				document[currentKey.ToString(.. scope .())] = value;
				currentKey.Clear();
				break;
			case .ARRAY:
				document.Add(value);
				break;
			}

			return true;
		}

		public bool StartObject()
		{
			Log("Start Object");

			// we are (g)root
			if (currentKey.IsEmpty)
			{
				treeStack.Add((null, .(), null, .OBJECT));
			}
			else
			{
				let parrent = &treeStack.Back.value;

				if (parrent == null)
					return false; // this should not happen

				treeStack.Add((currentKey, .(), parrent, .OBJECT));
				currentKey.Clear();
			}

			return true;
		}

		public bool Key(StringView str, bool copy)
		{
			Log(scope $"Key value: {str}");

			currentKey = str;

			return true;
		}

		public bool EndObject()
		{
			Log("End Object");

			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				let key = val.key;
				(*val.parrent)[key.ToString(.. scope .())] = val.value;
			}
			else
			{
				return false;
			}


			return true;
		}

		public bool StartArray()
		{
			Log("Start Array");

			if (currentKey.IsEmpty)
			{
				treeStack.Add((null, .(), null, .ARRAY));
			}
			else
			{
				let parrent = &treeStack.Back.value;

				if (parrent == null)
					return false; // this should not happen

				treeStack.Add((currentKey, .(), parrent, .ARRAY));
				currentKey.Clear();
			}

			return true;
		}

		public bool EndArray()
		{
			Log("End Array");

			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				let key = val.key;
				(*val.parrent)[key.ToString(.. scope .())] = val.value;
			}
			else
			{
				return false;
			}

			return true;
		}
	}
}
