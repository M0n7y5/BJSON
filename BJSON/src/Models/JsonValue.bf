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

		public SmallString smallStr;
	}

	/// Represents any JSON value (null, boolean, number, string, object, or array).
	/// This is the primary type returned by JSON parsing operations.
	/// A JsonValue is bitwise copyable and every copy shares the same heap pointers, so exactly
	/// one holder may Dispose it. Containers dispose their children.
	public struct JsonValue : IDisposable
	{
		/// An empty/default JSON value.
		public const JsonValue Empty = .();

		[Bitfield<JsonType>(.Public, .Bits(4), "type")]
		[Bitfield<bool>(.Public, .Bits(1), "smallString")]
		private uint8 mBitfield;

		/// The payload, which only the matching `type` tag makes meaningful.
		public JsonData data = default;

		public this()
		{
			this = default;
		}

		/// Copies a value bitwise. The copy shares the original's heap pointers.
		public this(JsonValue value)
		{
			this.data = value.data;
			this.mBitfield = value.mBitfield;
		}

		/// Reinterprets this value as one of the JsonValue subtypes without copying the payload.
		/// The result aliases the same heap pointers, so only one of the two may be disposed.
		[Inline]
		public T As<T>() where T : JsonValue
		{
			T val = default;
			val.data = this.data;
			val.mBitfield = this.mBitfield;

			return val;
		}

		[Inline]
		public bool IsNull() => type == .NULL;
		[Inline]
		public bool IsBool() => type == .BOOL;
		/// True for all three number tags: double, signed, and unsigned.
		[Inline]
		public bool IsNumber() => type == .NUMBER || type == .NUMBER_SIGNED || type == .NUMBER_UNSIGNED;
		[Inline]
		public bool IsString() => type == .STRING;
		[Inline]
		public bool IsObject() => type == .OBJECT;
		[Inline]
		public bool IsArray() => type == .ARRAY;

		/// Names the JSON type this value holds, for the actual side of a type mismatch report.
		/// @returns One of null, bool, number, string, object, array.
		[Inline]
		public StringView TypeName()
		{
			switch (type)
			{
			case .NULL:
				return "null";
			case .BOOL:
				return "bool";
			case .NUMBER, .NUMBER_SIGNED, .NUMBER_UNSIGNED:
				return "number";
			case .STRING:
				return "string";
			case .OBJECT:
				return "object";
			case .ARRAY:
				return "array";
			}
		}

		/// Frees the heap memory this value owns, including every child of an object or array.
		/// Disposing two copies of the same value is a double free.
		public void Dispose()
		{
			DisposeChild(this);
		}

		/// Disposes a value that a container holds. Objects and arrays call this for each child.
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

		/// Attempts to read this value as a string.
		/// The view aliases this value, so an SSO string requires the value to outlive the view.
		/// @returns The string contents, or an error if not a string type.
		public Result<StringView> AsString() mut
		{
			if (type != .STRING)
				return .Err;

			if (smallString)
				return StringView(&data.smallStr.data, data.smallStr.length);

			return StringView(data.string);
		}

		/// Attempts to read this value as a boolean.
		/// @returns The boolean, or an error if not a boolean type.
		public Result<bool> AsBool()
		{
			if (type != .BOOL)
				return .Err;

			return data.boolean;
		}

		/// Attempts to read this value as a number.
		/// @returns The number as a double, or an error if not a number type.
		public Result<double> AsNumber()
		{
			switch (type)
			{
			case .NUMBER:
				return data.number;
			case .NUMBER_SIGNED:
				return (double)data.signedNumber;
			case .NUMBER_UNSIGNED:
				return (double)data.unsignedNumber;
			default:
				return .Err;
			}
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

		/// Tries to get a pointer to the stored value for a key (for objects).
		/// Prefer this over TryGet when the result feeds a StringView: SSO strings live inline
		/// in the stored JsonValue, so a copy would leave the view dangling.
		/// @param key The key to look up.
		/// @returns A pointer to the stored value, or .Err if this is not an object or the key is absent.
		public Result<JsonValue*> TryGetRef(StringView key)
		{
			if (type != .OBJECT)
				return .Err;

			return this.As<JsonObject>().TryGetRef(key);
		}

		/// Tries to get a pointer to the stored value at an index (for arrays).
		/// @param index The index to look up.
		/// @returns A pointer to the stored value, or .Err if this is not an array or the index is out of bounds.
		public Result<JsonValue*> TryGetRef(int index)
		{
			if (type != .ARRAY)
				return .Err;

			if (index < 0 || index >= data.array.Count)
				return .Err;

			return .Ok(&data.array[index]);
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
		/// @remarks A StringView result aliases the document. The empty pointer is the exception:
		/// it names this value, which reaches JsonPointer only as a copy, so request the whole
		/// document with the non-generic overload instead.
		public T GetByPointerOrDefault<T>(StringView pointer, T defaultValue) where T : var
		{
			return JsonPointer.ResolveOrDefault<T>(this, pointer, defaultValue);
		}

		/// Reads a number as an unsigned integer, or zero when this value is not a number.
		/// Use AsNumber to tell a zero apart from a type mismatch.
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

		/// Reads a number as a signed integer, or zero when this value is not a number.
		/// Use AsNumber to tell a zero apart from a type mismatch.
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

		/// Reads a number as a float, or zero when this value is not a number.
		/// Use AsNumber to tell a zero apart from a type mismatch.
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

		/// Reads a number as a double, or zero when this value is not a number.
		/// Use AsNumber to tell a zero apart from a type mismatch.
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

		/// Reads a string, or an empty view when this value is not a string. Use AsString to tell
		/// an empty string apart from a type mismatch. An SSO string lives inline in the value, so
		/// the view stays valid only while this value does.
		[Inline]
		public static implicit operator StringView(ref Self self)
		{
			if (self.type != .STRING)
				return default;

			if (self.smallString)
				return StringView(&self.data.smallStr.data, self.data.smallStr.length);
			else
				return StringView(self.data.string);
		}

		/// Reads a boolean, or false when this value is not a boolean. Use AsBool to tell a false
		/// apart from a type mismatch.
		[Inline]
		public static implicit operator bool(Self self)
		{
			if (self.type != .BOOL)
				return default;

			return self.data.boolean;
		}

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

	/// Represents a JSON number value. The constructor picks the double, signed, or unsigned tag,
	/// and the reading conversions widen between them.
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
	/// Strings of up to MaxSmallStringLength characters live inline in the value (SSO); longer ones
	/// heap allocate, and only those need Dispose.
	public struct JsonString : JsonValue, IDisposable
	{
		/// The longest string that still fits inline, with no heap allocation.
		public const int MaxSmallStringLength = 14;

		/// Copies the text into this value. The argument stays owned by the caller.
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

		/// Copies the text into this value. The argument stays owned by the caller.
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

		/// Reads the text. An inline string lives in this value, so the view stays valid only while
		/// this value does.
		[Inline]
		public StringView AsStringView() mut
		{
			if (smallString)
				return StringView(&data.smallStr.data, data.smallStr.length);
			else
				return StringView(data.string);
		}

		/// Frees the heap buffer of a long string. An inline string owns nothing.
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
			data.object = new Dictionary<String, JsonValue>();
		}

		/// Frees every value and every key the object owns.
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

		/// Reads or writes a value by key. The object copies the key and owns the copy,
		/// and a write disposes the value it replaces. Reading a key the object does not hold
		/// is a fatal error, so use TryGet or GetOrDefault on untrusted input.
		public JsonValue this[String key]
		{
			get
			{
				return data.object[key];
			}

			set
			{
				if (data.object.TryGetRefAlt(StringView(key), ?, let valPtr))
				{
					JsonValue.DisposeChild(*valPtr);
					*valPtr = value;
					return;
				}

				data.object.Add(new String(key), value);
			}
		}

		/// The object's own values. They stay owned by the object.
		public Dictionary<String, JsonValue>.ValueEnumerator Values
			=> data.object.Values;

		/// The object's own keys. They stay owned by the object.
		public Dictionary<String, JsonValue>.KeyEnumerator Keys
			=> data.object.Keys;

		/// Enumerates the key and value pairs the object owns.
		public Dictionary<String, JsonValue>.Enumerator GetEnumerator()
			=> data.object.GetEnumerator();

		public int Count => data.object.Count;

		/// Adds a key and value, copying the key. Fatal errors if the key is already present:
		/// assign through the indexer to overwrite.
		/// @param key The key to add.
		/// @param value The value to add. The object takes ownership.
		public void Add(StringView key, JsonValue value)
		{
			data.object.Add(new String(key), value);
		}

		/// Adds a key and value pair, copying the key. Fatal errors if the key is already present.
		/// @param kv The pair to add. The object takes ownership of the value.
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
		/// The result is a copy that shares the stored value's heap pointers, so the object still
		/// owns it. Use TryGetRef when the result feeds a StringView.
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

		/// Gets a value by key from the object, named for symmetry with the JsonValue accessors.
		/// @param key The key to look up.
		/// @returns The JsonValue if found, or an error if the key doesn't exist.
		[Inline]
		public new Result<JsonValue> TryGet(StringView key)
		{
			return GetValue(key);
		}

		/// Gets a pointer to the stored value for a key from the object.
		/// Prefer this over GetValue when the result feeds a StringView: SSO strings live inline
		/// in the stored JsonValue, so a copy would leave the view dangling.
		/// @param key The key to look up.
		/// @returns A pointer to the stored value, or .Err if the key is absent.
		public new Result<JsonValue*> TryGetRef(StringView key)
		{
			if (data.object.TryGetRefAlt(key, ?, let valPtr))
				return .Ok(valPtr);

			return .Err;
		}

		/// Gets a value by key, or returns a default value if not found.
		/// @param key The key to look up.
		/// @param defaultValue The value to return if key doesn't exist.
		/// @returns The JsonValue if found, or defaultValue otherwise.
		public new JsonValue GetOrDefault(StringView key, JsonValue defaultValue = default)
		{
			if (GetValue(key) case .Ok(let val))
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
			// SSO strings live inline in the JsonValue, so the conversion must reference the
			// stored value. A local copy dies on return and leaves the StringView dangling.
			if (data.object.TryGetRefAlt(key, ?, let valPtr))
			{
				return (T)(*valPtr);
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
			data.array = new List<JsonValue>();
		}

		/// Frees every element the array owns.
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

		/// Reads or writes a value by index. A write past the end grows the array with nulls,
		/// and a write over an existing element disposes it. Reading an index outside the array
		/// is a fatal error, so use TryGet or GetOrDefault on untrusted input.
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
				else
					JsonValue.DisposeChild(data.array[index]);

				data.array[index] = value;
			}
		}

		/// Enumerates the values the array owns.
		public List<JsonValue>.Enumerator GetEnumerator()
		{
			return data.array.GetEnumerator();
		}

		public int Count => data.array.Count;

		/// Appends a value. The array takes ownership.
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
