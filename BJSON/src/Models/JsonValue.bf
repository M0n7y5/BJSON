using System;
using System.Collections;
using BJSON;
using BJSON.Enums;
using System.Diagnostics;
using System.IO;

namespace BJSON.Models
{
	/// Small string storage for SSO (Small String Optimization).
	/// Stores length in first byte, data in remaining 14 bytes.
	[CRepr]
	public struct SmallString
	{
		public uint8 length;
		public char8[14] data;
	}

	/// Union type that holds the actual data for a JSON value.
	[Union]
	public struct JsonData
	{
		public bool boolean;

		public uint64 unsignedNumber;
		public int64 signedNumber;
		public double number;

		public String string;

		public Dictionary<String, JsonValue> object;
		public List<JsonValue> array;

		/// Small string storage - strings up to 14 chars are stored inline without heap allocation.
		public SmallString smallStr;
	}

	/// Represents any JSON value (null, boolean, number, string, object, or array).
	/// This is the primary type returned by JSON parsing operations.
	public struct JsonValue : IDisposable
	{
		const int sizeCheck = sizeof(JsonValue);
		const int sizeCheckData = sizeof(JsonData);

		/// An empty/default JSON value.
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

		/// Checks if this value is a JSON null.
		[Inline]
		public bool IsNull() => type == .NULL;
		/// Checks if this value is a JSON boolean.
		[Inline]
		public bool IsBool() => type == .BOOL;
		/// Checks if this value is a JSON number (integer or floating-point).
		[Inline]
		public bool IsNumber() => type == .NUMBER || type == .NUMBER_SIGNED || type == .NUMBER_UNSIGNED;
		/// Checks if this value is a JSON string.
		[Inline]
		public bool IsString() => type == .STRING;
		/// Checks if this value is a JSON object.
		[Inline]
		public bool IsObject() => type == .OBJECT;
		/// Checks if this value is a JSON array.
		[Inline]
		public bool IsArray() => type == .ARRAY;

		/// Disposes of any heap-allocated resources held by this JSON value.
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

		/// Helper method to dispose a child JSON value's resources.
		/// Used to avoid code duplication in container disposal.
		[Inline]
		public static void DisposeChild(JsonValue item)
		{
			switch (item.type)
			{
			case .OBJECT:
				item.As<JsonObject>().Dispose();
			case .ARRAY:
				item.As<JsonArray>().Dispose();
			case .STRING:
				item.As<JsonString>().Dispose();
			default:
				return;
			}
		}

		/// Attempts to convert this value to a JsonObject.
		/// @returns The value as JsonObject, or an error if not an object type.
		public Result<JsonObject> AsObject()
		{
			if (type != .OBJECT)
				return .Err;

			return this.As<JsonObject>();
		}

		/// Attempts to convert this value to a JsonArray.
		/// @returns The value as JsonArray, or an error if not an array type.
		public Result<JsonArray> AsArray()
		{
			if (type != .ARRAY)
				return .Err;

			return this.As<JsonArray>();
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
		public JsonValue this[int index]
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

		/// Tries to get a value by key (for objects).
		/// @param key The key to look up.
		/// @returns The JsonValue if this is an object and key exists, or an error otherwise.
		public Result<JsonValue> TryGet(StringView key)
		{
			if (type != .OBJECT)
				return .Err;

			return this.As<JsonObject>().TryGet(key);
		}

		/// Tries to get a value by index (for arrays).
		/// @param index The index to look up.
		/// @returns The JsonValue if this is an array and index is valid, or an error otherwise.
		public Result<JsonValue> TryGet(int index)
		{
			if (type != .ARRAY)
				return .Err;

			return this.As<JsonArray>().TryGet(index);
		}

		/// Gets a value by key, or returns a default value if not found or not an object.
		/// @param key The key to look up.
		/// @param defaultValue The value to return if key doesn't exist or this is not an object.
		/// @returns The JsonValue if found, or defaultValue otherwise.
		public JsonValue GetOrDefault(StringView key, JsonValue defaultValue = default)
		{
			if (type != .OBJECT)
				return defaultValue;

			return this.As<JsonObject>().GetOrDefault(key, defaultValue);
		}

		/// Gets a value by index, or returns a default value if out of bounds or not an array.
		/// @param index The index to look up.
		/// @param defaultValue The value to return if index is invalid or this is not an array.
		/// @returns The JsonValue if found, or defaultValue otherwise.
		public JsonValue GetOrDefault(int index, JsonValue defaultValue = default)
		{
			if (type != .ARRAY)
				return defaultValue;

			return this.As<JsonArray>().GetOrDefault(index, defaultValue);
		}

		/// Gets a value by key and converts to type T, or returns a default value.
		/// This generic overload avoids allocation when using primitive defaults (StringView, int, etc.).
		/// @param key The key to look up.
		/// @param defaultValue The value to return if key doesn't exist or this is not an object.
		/// @returns The value converted to T if found, or defaultValue otherwise.
		public T GetOrDefault<T>(StringView key, T defaultValue) where T : var
		{
			if (type != .OBJECT)
				return defaultValue;

			return this.As<JsonObject>().GetOrDefault<T>(key, defaultValue);
		}

		/// Gets a value by index and converts to type T, or returns a default value.
		/// This generic overload avoids allocation when using primitive defaults.
		/// @param index The index to look up.
		/// @param defaultValue The value to return if index is invalid or this is not an array.
		/// @returns The value converted to T if found, or defaultValue otherwise.
		public T GetOrDefault<T>(int index, T defaultValue) where T : var
		{
			if (type != .ARRAY)
				return defaultValue;

			return this.As<JsonArray>().GetOrDefault<T>(index, defaultValue);
		}

		/// Resolves a JSON Pointer (RFC 6901) against this value.
		/// @param pointer The JSON Pointer string (e.g., "/users/0/name").
		/// @returns The resolved JsonValue or an error if the pointer is invalid or path doesn't exist.
		public Result<JsonValue, JsonPointerError> GetByPointer(StringView pointer)
		{
			return JsonPointer.Resolve(this, pointer);
		}

		/// Resolves a JSON Pointer (RFC 6901), returning a default value on failure.
		/// @param pointer The JSON Pointer string (e.g., "/users/0/name").
		/// @param defaultValue The value to return if resolution fails.
		/// @returns The resolved JsonValue or defaultValue if the pointer is invalid or path doesn't exist.
		public JsonValue GetByPointerOrDefault(StringView pointer, JsonValue defaultValue = default)
		{
			return JsonPointer.ResolveOrDefault(this, pointer, defaultValue);
		}

		/// Resolves a JSON Pointer (RFC 6901) and converts to type T, returning a default value on failure.
		/// This generic overload avoids allocation when using primitive defaults (StringView, int, etc.).
		/// @param pointer The JSON Pointer string (e.g., "/users/0/name").
		/// @param defaultValue The value to return if resolution fails.
		/// @returns The resolved value converted to T, or defaultValue if the pointer is invalid or path doesn't exist.
		public T GetByPointerOrDefault<T>(StringView pointer, T defaultValue) where T : var
		{
			return JsonPointer.ResolveOrDefault<T>(this, pointer, defaultValue);
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

			if (self.smallString)
				return StringView(&self.data.smallStr.data, self.data.smallStr.length);
			else
				return StringView(self.data.string);
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
	}

	/// Represents a JSON null value.
	public struct JsonNull : JsonValue
	{
		public this()
		{
			type = .NULL;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.Append("null");
		}
	}

	/// Represents a JSON boolean value (true or false).
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

	/// Represents a JSON number value (supports signed, unsigned, and floating-point).
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

	/// Represents a JSON string value. Owns its string memory.
	/// Uses Small String Optimization (SSO) for strings up to 14 characters.
	public struct JsonString : JsonValue, IDisposable
	{
		public const int MaxSmallStringLength = 14;

		public this(String value)
		{
			type = .STRING;
			if (value.Length <= MaxSmallStringLength)
			{
				smallString = true;
				data.smallStr.length = (uint8)value.Length;
				Internal.MemCpy(&data.smallStr.data, value.Ptr, value.Length);
			}
			else
			{
				smallString = false;
				data.string = new String(value);
			}
		}

		public this(StringView value)
		{
			type = .STRING;
			if (value.Length <= MaxSmallStringLength)
			{
				smallString = true;
				data.smallStr.length = (uint8)value.Length;
				Internal.MemCpy(&data.smallStr.data, value.Ptr, value.Length);
			}
			else
			{
				smallString = false;
				data.string = new String(value);
			}
		}

		/// Gets the string value as a StringView.
		[Inline]
		public StringView AsStringView() mut
		{
			if (smallString)
				return StringView(&data.smallStr.data, data.smallStr.length);
			else
				return StringView(data.string);
		}

		public new void Dispose()
		{
			if (!smallString && data.string != null)
			{
				delete data.string;
			}
		}
	}

	/// Represents a JSON object (key-value pairs). Owns its dictionary and keys.
	public struct JsonObject : JsonValue, IDisposable,
		IEnumerable<(String key, JsonValue value)>
	{
		public this()
		{
			type = .OBJECT;
			data.object = new Dictionary<String, JsonValue>(32);
		}

		public new void Dispose()
		{
			if (data.object != null)
			{
				for (var item in data.object.Values)
				{
					JsonValue.DisposeChild(item);
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

		/// Removes a key-value pair from the object and disposes the value.
		/// @param key The key to remove.
		/// @returns True if the key was found and removed, false otherwise.
		public bool Remove(StringView key)
		{
			if (data.object.GetAndRemoveAlt(key) case .Ok(let pair))
			{
				delete pair.key;
				JsonValue.DisposeChild(pair.value);
				return true;
			}
			return false;
		}

		/// Gets a value by key from the object.
		/// @param key The key to look up.
		/// @returns The JsonValue if found, or an error if the key doesn't exist.
		public Result<JsonValue> GetValue(StringView key)
		{
			if (data.object.TryGetValueAlt(key, let val))
			{
				return val;
			}

			return .Err;
		}

		/// Tries to get a value by key from the object.
		/// Alias for GetValue for API consistency.
		/// @param key The key to look up.
		/// @returns The JsonValue if found, or an error if the key doesn't exist.
		[Inline]
		public new Result<JsonValue> TryGet(StringView key)
		{
			return GetValue(key);
		}

		/// Gets a value by key, or returns a default value if not found.
		/// @param key The key to look up.
		/// @param defaultValue The value to return if key doesn't exist.
		/// @returns The JsonValue if found, or defaultValue otherwise.
		public new JsonValue GetOrDefault(StringView key, JsonValue defaultValue = default)
		{
			if (data.object.TryGetValueAlt(key, let val))
			{
				return val;
			}

			return defaultValue;
		}

		/// Gets a value by key and converts it to type T, or returns a default value if not found.
		/// This generic overload avoids allocation when using primitive defaults (StringView, int, etc.).
		/// Use this for primitive types only - for JsonValue defaults, use the non-generic overload.
		/// @param key The key to look up.
		/// @param defaultValue The value to return if key doesn't exist.
		/// @returns The value converted to T if found, or defaultValue otherwise.
		public new T GetOrDefault<T>(StringView key, T defaultValue) where T : var
		{
			if (data.object.TryGetValueAlt(key, let val))
			{
				return (T)val;
			}

			return defaultValue;
		}
	}

	/// Represents a JSON array (ordered list of values). Owns its list.
	public struct JsonArray : JsonValue, IDisposable, IEnumerable<JsonValue>
	{
		public this()
		{
			type = .ARRAY;
			data.array = new List<JsonValue>(16);
		}

		public new void Dispose()
		{
			if (data.array != null)
			{
				for (var item in data.array)
				{
					JsonValue.DisposeChild(item);
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
				if (index >= data.array.Count)
					data.array.Resize(index + 1);

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

		/// Removes a value from the array and disposes it.
		/// @param value The value to remove.
		/// @returns True if the value was found and removed, false otherwise.
		public bool Remove(JsonValue value)
		{
			let index = data.array.IndexOf(value);
			if (index >= 0)
			{
				RemoveAt(index);
				return true;
			}
			return false;
		}

		/// Removes a value at the specified index and disposes it.
		/// @param index The index of the value to remove.
		public void RemoveAt(int index)
		{
			let value = data.array[index];
			data.array.RemoveAt(index);
			JsonValue.DisposeChild(value);
		}

		/// Tries to get a value at the specified index.
		/// @param index The index to look up.
		/// @returns The JsonValue if index is valid, or an error if out of bounds.
		public new Result<JsonValue> TryGet(int index)
		{
			if (index >= 0 && index < data.array.Count)
			{
				return data.array[index];
			}

			return .Err;
		}

		/// Gets a value at the specified index, or returns a default value if out of bounds.
		/// @param index The index to look up.
		/// @param defaultValue The value to return if index is invalid.
		/// @returns The JsonValue if index is valid, or defaultValue otherwise.
		public new JsonValue GetOrDefault(int index, JsonValue defaultValue = default)
		{
			if (index >= 0 && index < data.array.Count)
			{
				return data.array[index];
			}

			return defaultValue;
		}

		/// Gets a value at the specified index and converts it to type T, or returns a default value if out of bounds.
		/// This generic overload avoids allocation when using primitive defaults.
		/// Use this for primitive types only - for JsonValue defaults, use the non-generic overload.
		/// @param index The index to look up.
		/// @param defaultValue The value to return if index is invalid.
		/// @returns The value converted to T if index is valid, or defaultValue otherwise.
		public new T GetOrDefault<T>(int index, T defaultValue) where T : var
		{
			if (index >= 0 && index < data.array.Count)
			{
				return (T)data.array[index];
			}

			return defaultValue;
		}
	}
}
