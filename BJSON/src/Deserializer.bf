using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;
using System.Diagnostics;
namespace BJSON
{
	public class Deserializer : IHandler
	{
		JsonVariant jsonRes = .();

		public bool Deserialize(StringView jsonText, out JsonVariant json, bool isRoot = false)
		{
			let reader = scope Reader(this);
			reader.Parse(scope StringStream(jsonText, .Reference));

			json = this.jsonRes;

			return true;
		}

		void Log(String msg)
		{
			Console.WriteLine(msg);
		}

		public bool Null()
		{
			Log("Null value");
			return true;
		}

		public bool Bool(bool b)
		{
			Log(scope $"Bool value: {b}");
			return true;
		}

		public bool Double(double d)
		{
			Log(scope $"Double value: {d}");
			return true;
		}

		public bool String(StringView str, bool copy)
		{
			Log(scope $"String value: {str}");
			return true;
		}

		public bool StartObject()
		{
			Log("Start Object");
			return true;
		}

		public bool Key(StringView str, bool copy)
		{
			Log(scope $"Key value: {str}");
			return true;
		}

		public bool EndObject()
		{
			Log("End Object");
			return true;
		}

		public bool StartArray()
		{
			Log("Start Array");
			return true;
		}

		public bool EndArray()
		{
			Log("End Array");
			return true;
		}
	}
}
