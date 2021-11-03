using System;
using System.Collections;
using BJSON.Enums;
namespace BJSON.Models
{
	struct JsonVariant : ICollection<Self>
	{
		JsonType JType = .NULL;
		Variant Value = .();

		public this()
		{
		}

		this(Variant value, JsonType type)
		{
			this.Value = value;
			this.JType = type;
		}

		public this(Variant value) : this(value, .NULL)
		{
		}

		public this(JsonArray value) : this(.Create(value, true), .ARRAY)
		{
		}

		public this(String key, Self value) : this(new JsonObject() { (new String(key), value) })
		{
		}

		public this(JsonObject value) : this(.Create(value, true), .OBJECT)
		{
		}

		public this(double value) : this(.Create(value), .NUMBER)
		{
		}

		public this(String value) : this(.Create(new String(value), true), .STRING)
		{
		}

		public this(bool value) : this(.Create(value), .BOOL)
		{
		}


		[Inline]
		void SetType(JsonType type) mut
		{
			this.JType = type;
		}


		public static operator Self(bool value)
		{
			return JsonVariant(value);
		}

		public static operator Self(int value)
		{
			// json supports only double
			return (double)value;
		}

		public static operator Self(uint value)
		{
			// json supports only double
			return (double)value;
		}

		public static operator Self(double value)
		{
			// json supports only double
			return JsonVariant(value);
		}

		public static operator Self(String value)
		{
			return JsonVariant(value);
		}

		public static operator Self(Variant value)
		{
			return JsonVariant(value);
		}

		public static operator Self((String, int) value)
		{
			return JsonVariant(value.0, value.1);
		}

		public static operator Self((String, double) value)
		{
			return JsonVariant(value.0, value.1);
		}

		public static operator Self((String, String) value)
		{
			return JsonVariant(value.0, value.1);
		}

		public static operator Self((String, Self) value)
		{
			return JsonVariant(value.0, value.1);
		}

		public static operator Self((String, bool) value)
		{
			return JsonVariant(value.0, value.1);
		}

		public static operator int(Self self)
		{
			// json supports only double
			//WARN: Allocating
			return (.)GetTypedValue<double>(self);
		}

		public static operator String(Self self)
		{
			// json supports only double
			//WARN: Allocating
			return (.)GetTypedValue<String>(self);
		}

		public Self this[String key]
		{
			get => GetChildByName(key);
			set mut => SetChildByName(key, value);
		}

		// Access array
		public Self this[uint index]
		{
			get => GetChildFromIndex(index);
			set mut => SetChildByIndex(index, value);
		}

		// Object
		void SetChildByName(String key, JsonVariant value) mut
		{
			if (!this.Value.HasValue)
			{
				// if we dont have a value, create new object with the key and
				// provided value and replace itself with it
				//Create(new JsonObject() { (new String(key), value) }, true);
				this = JsonVariant(key, value);
			}
			else
			{
				if (this.Value.VariantType != typeof(JsonObject))
				{
					// if we are not JsonObject, create new JsonObject and
					// replace current variant value
					this.Dispose();
					this = JsonVariant(key, value);
					//Create(new JsonObject() { (new String(key), value) }, true);
				}
				else
				{
					let obj = this.Value.Get<JsonObject>();
					if (obj.ContainsKey(key))// if key exists, replace it with new value
					{
						obj[key].Dispose();// dispose old value

						obj[key] = value;
					}
				}
			}
		}

		// Object
		Self GetChildByName(String str)
		{
			return default;
		}

		// Array
		void SetChildByIndex(uint param, Self variant)
		{
		}

		// Array
		Self GetChildFromIndex(uint param)
		{
			return default;
		}


		public void Add(JsonVariant item)
		{
		}

		public void Clear()
		{
		}

		public bool Contains(JsonVariant item)
		{
			return default;
		}

		public void CopyTo(Span<JsonVariant> span)
		{
		}

		public bool Remove(JsonVariant item)
		{
			return default;
		}

		static T GetTypedValue<T>(Self self) where T : class
		{
			if (self.Value.VariantType == typeof(T))
				return self.Value.Get<T>();
			return default;// fail silently
		}

		static T GetTypedValue<T>(Self self) where T : struct
		{
			if (self.Value.VariantType == typeof(T))
				return self.Value.Get<T>();
			return default;// fail silently
		}

		void Dispose() mut
		{
			PreDispose();
			this.Value.Dispose();
		}

		void PreDispose()
		{
			switch (this.Value.VariantType)
			{
			case typeof(JsonArray):
				let array = Value.Get<JsonArray>();
				for (var item in array)
				{
					/*item.PreDispose();*/
					item.Dispose();
				}
				break;
			case typeof(JsonObject):
				let array = Value.Get<JsonObject>();
				for (var item in array)
				{
					delete item.key;
					/*item.value.PreDispose();*/
					item.value.Dispose();
				}
				break;
			}
		}
	}
}
