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

		struct NodeInfo : this(
			String key, JsonVariant value, // use parent index
			int parentIdx, NodeState state)
		{
		}

		Queue<NodeInfo> treeStack = new .(1024) ~ delete _;
		String currentKey = null;

		BumpAllocator keyAlloc = new .() ~ delete _;

		public Result<JsonVariant, JsonParsingError> Deserialize(StringView jsonText)
		{
			let reader = scope Reader(this);

			let result = reader.Parse(scope StringStream(jsonText, .Reference));

			switch (result)
			{
			case .Ok:
				return this.treeStack.Front.value;
			case .Err(let err):
				for (var item in treeStack)
					item.value.Dispose();
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

			if (treeStack.Count == 0) return false;

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = Variant();
				break;
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document[currentKey] = Variant();
				currentKey = null;
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

			if (treeStack.Count == 0) return false;

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = value;
				break;
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document[currentKey] = value;
				currentKey = null;
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

			if (treeStack.Count == 0) return false;

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = value;
				break;
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document[currentKey] = value;
				currentKey = null;
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

			if (treeStack.Count == 0) return false;

			let state = treeStack.Back.state;
			var document = ref treeStack.Back.value;

			switch (state)
			{
			case .VALUE:
				document = value;
				break;
			case .OBJECT:
				if (currentKey == null)
					return false; //TODO: notify invalid key error

				document[currentKey] = value;
				currentKey = null;
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
			if (currentKey == null)
			{
				treeStack.Add(.(null, .(), -1, .OBJECT));
			}
			else
			{
				let parrentIdx = treeStack.Count - 1;

				if (parrentIdx == -1)
					return false; // this should not happen

				treeStack.Add(.(currentKey, .(), parrentIdx, .OBJECT));
				currentKey = null;
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

			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				treeStack[val.parentIdx].value[val.key] = val.value;
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

			if (currentKey == null)
			{
				treeStack.Add(.(null, .(), -1, .ARRAY));
			}
			else
			{
				let parrentIdx = treeStack.Count - 1;

				if (parrentIdx == -1)
					return false;

				treeStack.Add(.(currentKey, .(), parrentIdx, .ARRAY));
				currentKey = null;
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
				treeStack[val.parentIdx].value[val.key] = val.value;
			}
			else
			{
				return false;
			}

			return true;
		}
	}
}
