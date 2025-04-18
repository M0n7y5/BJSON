using System;
using System.Collections;
using BJSON.Enums;
using System.Diagnostics;
using System.IO;

namespace BJSON.Models
{
	[Union]
	public struct JsonData
	{
		// values
		public bool boolean;

		public uint64 unsignedNumber;
		public int64 signedNumber;
		//public double numberFloat;
		public double number;

		public String string;

		// containers
		public Dictionary<String, JsonValue> object;
		public List<JsonValue> array;

		public char8[15] reserved;
	}

	public struct JsonValue : IDisposable
	{
		const int sizeCheck = sizeof(JsonValue);
		const int sizeCheckData = sizeof(JsonData);

		/*
		Since we are 
		*/


		public const JsonValue Empty = .();

		[Bitfield<JsonType>(.Public, .Bits(4), "type")]
		[Bitfield<bool>(.Public, .Bits(1), "smallString")]
		private uint8 mBitfield;

		public JsonData data = default;

		public this()
		{
			this = default;
		}

		public this(JsonValue value)
		{
			this.data = value.data;
			this.mBitfield = value.mBitfield;
		}

		[Inline]
		public T As<T>() where T : JsonValue
		{
			T val = default;
			val.data = this.data;
			val.mBitfield = this.mBitfield;
			return val;
		}

		public bool IsNull() => type == .NULL;
		public bool IsBool() => type == .BOOL;
		public bool IsNumber() => type == .NUMBER || type == .NUMBER_SIGNED || type == .NUMBER_UNSIGNED;
		public bool IsString() => type == .STRING;
		public bool IsObject() => type == .OBJECT;
		public bool IsArray() => type == .ARRAY;

		public void Dispose()
		{
			switch (type)
			{
			case .OBJECT:
				this.As<JsonObject>().Dispose();
			case .ARRAY:
				this.As<JsonArray>().Dispose();
			case .STRING:
				this.As<JsonString>().Dispose();
			default: return;
			}
		}

		public Result<JsonObject> AsObject()
		{
			if (type != .OBJECT)
				return .Err;

			return this.As<JsonObject>();
		}

		public Result<JsonArray> AsArray()
		{
			if (type != .ARRAY)
				return .Err;

			return this.As<JsonArray>();
		}

		public static Result<JsonValue> Parse(StringView val)
		{
			return .Err;
		}

		public static Result<JsonValue, JsonParsingError> Parse(Stream stream)
		{
			return .Err(.DocumentIsEmpty);
		}

		public JsonValue this[String key]
		{
			get
			{
				Runtime.Assert(type == .OBJECT, "JsonValue is not an object!");

				return this.As<JsonObject>()[key];
			}
			set
			{
				Runtime.Assert(type == .OBJECT, "JsonValue is not an object!");

				this.As<JsonObject>()[key] = value;
			}
		}

		// Access array
		public  JsonValue this[int index]
		{
			get
			{
				Runtime.Assert(type == .ARRAY, "JsonValue is not an array!");

				return this.As<JsonArray>()[index];
			}
			set
			{
				Runtime.Assert(type == .ARRAY, "JsonValue is not an array!");

				this.As<JsonArray>()[index] = value;
			}
		}

		[Inline]
		public static implicit operator uint(Self self)
		{
			switch (self.type)
			{
			case .NUMBER:
				return uint(self.data.number);
			case .NUMBER_SIGNED:
				return uint(self.data.signedNumber);
			case .NUMBER_UNSIGNED:
				return self.data.unsignedNumber;
			default:
				return default;

			}
		}

		[Inline]
		public static implicit operator int(Self self)
		{
			switch (self.type)
			{
			case .NUMBER:
				return int(self.data.number);
			case .NUMBER_SIGNED:
				return self.data.signedNumber;
			case .NUMBER_UNSIGNED:
				return int(self.data.unsignedNumber);
			default:
				return default;

			}
		}

		[Inline]
		public static implicit operator float(Self self)
		{
			switch (self.type)
			{
			case .NUMBER:
				return float(self.data.number);
			case .NUMBER_SIGNED:
				return float(self.data.signedNumber);
			case .NUMBER_UNSIGNED:
				return float(self.data.unsignedNumber);
			default:
				return default;

			}
		}

		[Inline]
		public static implicit operator double(Self self)
		{
			switch (self.type)
			{
			case .NUMBER:
				return self.data.number;
			case .NUMBER_SIGNED:
				return double(self.data.signedNumber);
			case .NUMBER_UNSIGNED:
				return double(self.data.unsignedNumber);
			default:
				return default;

			}
		}

		[Inline]
		public static implicit operator StringView(Self self)
		{
			if (self.type != .STRING)
				return default;

			return .(self.data.string);
		}

		/*[Inline]
		public static implicit operator String(Self self)
		{
			if (self.type != .STRING)
				return default;

			return new .(self.data.string);
		}*/

		[Inline]
		public static implicit operator bool(Self self)
		{
			if (self.type != .BOOL)
				return default;

			return self.data.boolean;
		}

		// types to json value
		[Inline]
		public static implicit operator Self(uint value)
		{
			return JsonNumber(value);
		}

		[Inline]
		public static implicit operator Self(int value)
		{
			return JsonNumber(value);
		}

		[Inline]
		public static implicit operator Self(float value)
		{
			return JsonNumber(value);
		}

		[Inline]
		public static implicit operator Self(double value)
		{
			return JsonNumber(value);
		}

		[Inline]
		public static implicit operator Self(String value)
		{
			return JsonString(value);
		}

		[Inline]
		public static implicit operator Self(StringView value)
		{
			return JsonString(value);
		}

		[Inline]
		public static implicit operator Self(bool value)
		{
			return JsonBool(value);
		}

		[Inline]
		public static implicit operator Self((String key, String value) value)
		{
			return .();
		}
	}

	public struct JsonNull : JsonValue, IParseable<JsonNull>
	{
		public this()
		{
			type = .NULL;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.Append("null");
		}

		public new static Result<JsonNull> Parse(StringView val)
		{
			return val == "null" ? JsonNull() : .Err;
		}

		public new static Result<JsonNull> Parse(Stream stream)
		{
			let toParse = stream.ReadStrSized32(4, .. scope .());

			return Parse(toParse);
		}
	}

	public struct JsonBool : JsonValue
	{
		public this(bool value)
		{
			type = .BOOL;
			data.boolean = value;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.Append(data.boolean ? "true" : "false");
		}
	}

	public struct JsonNumber : JsonValue
	{
		public this(double value)
		{
			type = .NUMBER;
			data.number = value;
		}

		public this(uint64 value)
		{
			type = .NUMBER_UNSIGNED;
			data.unsignedNumber = value;
		}

		public this(int64 value)
		{
			type = .NUMBER_SIGNED;
			data.signedNumber = value;
		}
	}

	public struct JsonString : JsonValue, IDisposable
	{
		public this(String value)
		{
			type = .STRING;
			data.string = new String(value);
		}

		public this(StringView value)
		{
			type = .STRING;
			data.string = new String(value);
		}

		public new void Dispose()
		{
			if (data.string != null)
			{
				delete data.string;
			}
		}
	}

	public struct JsonObject : JsonValue, IDisposable,
		IEnumerable<(String key, JsonValue value)>
	{
		public this()
		{
			type = .OBJECT;
			data.object = new Dictionary<String, JsonValue>();
		}

		public new void Dispose()
		{
			if (data.object != null)
			{
				for (var item in data.object.Values)
				{
					switch (item.type)
					{
					case .OBJECT:
						item.As<JsonObject>().Dispose();
					case .ARRAY:
						item.As<JsonArray>().Dispose();
					case .STRING:
						item.As<JsonString>().Dispose();
					default: continue;
					}
				}

				DeleteDictionaryAndKeys!(data.object);
			}
		}

		public JsonValue this[String key]
		{
			get
			{
				return data.object[key];
			}

			set
			{
				data.object[key] = value;
			}
		}

		public Dictionary<String, JsonValue>.ValueEnumerator Values
			=> data.object.Values;

		public Dictionary<String, JsonValue>.KeyEnumerator Keys
			=> data.object.Keys;

		public Dictionary<String, JsonValue>.Enumerator GetEnumerator()
			=> data.object.GetEnumerator();

		public int Count => data.object.Count;

		public void Add(StringView key, JsonValue value)
		{
			data.object.Add(new String(key), value);
		}

		public void Add((StringView key, JsonValue value) kv)
		{
			data.object.Add(new String(kv.key), kv.value);
		}

		public bool ContainsKey(StringView key)
		{
			return data.object.ContainsKeyAlt(key);
		}

		public void Remove(String key)
		{
			data.object.Remove(key);
		}

		public Result<JsonValue> GetValue(StringView key)
		{
			if (data.object.TryGetValueAlt(key, let val))
			{
				return val;
			}

			return .Err;
		}
	}

	public struct JsonArray : JsonValue, IDisposable, IEnumerable<JsonValue>
	{
		public this()
		{
			type = .ARRAY;
			data.array = new List<JsonValue>();
		}

		public new void Dispose()
		{
			if (data.array != null)
			{
				for (var item in data.array)
				{
					switch (item.type)
					{
					case .OBJECT:
						item.As<JsonObject>().Dispose();
					case .ARRAY:
						item.As<JsonArray>().Dispose();
					case .STRING:
						item.As<JsonString>().Dispose();
					default: continue;
					}
				}

				delete data.array;
			}
		}

		public JsonValue this[int index]
		{
			get
			{
				return data.array[index];
			}

			set
			{
				data.array.Reserve(index + 1);

				data.array[index] = value;
			}
		}

		public List<JsonValue>.Enumerator GetEnumerator()
		{
			return data.array.GetEnumerator();
		}

		public int Count => data.array.Count;

		public void Add(JsonValue value)
		{
			data.array.Add(value);
		}

		public void Remove(JsonValue value)
		{
			data.array.Remove(value);
		}

		public void RemoveAt(int index)
		{
			data.array.RemoveAt(index);
		}
	}
}
