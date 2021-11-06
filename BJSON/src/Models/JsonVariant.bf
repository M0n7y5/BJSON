using System;
using System.Collections;
using BJSON.Enums;
using System.Diagnostics;

namespace BJSON.Models
{
	struct JsonVariant : IDisposable
	{
		JsonType JType = .NULL;
		Variant Value = .();

		public this()
		{
			//Debug.WriteLine("Test Test");
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

		/*public static operator Self((String, int) value)
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
		}*/

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

		public static operator bool(Self self)
		{
			// json supports only double
			//WARN: Allocating
			return (.)GetTypedValue<bool>(self);
		}

		public ref Self this[String key]
		{
			get mut => ref GetChildByName(key);
			set mut => SetChildByName(key, value);
		}

		// Access array
		public ref Self this[uint index]
		{
			get mut => ref GetChildFromIndex(index);
			set mut => SetChildByIndex(index, value);
		}

		// Object
		void SetChildByName(String key, JsonVariant value) mut
		{
			switch (JType)
			{
			case .NULL: this = JsonVariant(key, value); return;
			case .OBJECT:
				{
					let obj = this.Value.Get<JsonObject>();
					if (obj.ContainsKey(key))// if key exists, replace its value with new value
					{
						obj[key].Dispose();// dispose old value

						obj[key] = value;
					}
					else
					{
						// if key doesnt exist add new entry
						obj.Add(new .(key), value);
					}
				}
				return;

			default:
				{
					this.Dispose();
					this = JsonVariant(key, value);
				}
				return;

			}
		}

		// Object
		ref Self GetChildByName(String key) mut
		{
			switch (JType)
			{
			case .NULL: this = JsonVariant(key, .()); return ref this;
			case .OBJECT:
				{
					let obj = this.Value.Get<JsonObject>();
					if (obj.ContainsKey(key))
					{
						return ref obj[key];
					}
					else
					{
						Debug.FatalError("This should not happen ...");
						return ref JsonVariant();
					}
				}

			default:
				{
					this.Dispose();
					this = JsonVariant(key, .());
					return ref this;
				}
			}
		}

		// Array
		void SetChildByIndex(uint key, Self value) mut
		{
			switch (JType)
			{
			case .NULL:
				{
					let array = new JsonArray();
					ResizeArray(array, (.)key);
					array.Insert((.)key, value);
					this = JsonVariant(array);
					return;
				}
			case .ARRAY:
				{
					let array = this.Value.Get<JsonArray>();

					if (array.Count - 1 < (.)key)
					{
						ResizeArray(array, (.)key);
						array.Insert((.)key, value);
					}
					else
					{
						array[(.)key].Dispose();
						array[(.)key] = value;
					}
				}
				return;

			default:
				{
					this.Dispose();// replace current value with array
					let array = new JsonArray();
					ResizeArray(array, (.)key);
					array.Insert((.)key, value);
					this = JsonVariant(array);
					return;
				}
			}
		}

		// Array
		ref Self GetChildFromIndex(uint key) mut
		{
			switch (JType)
			{
			case .NULL:
				{
					this = JsonVariant(new JsonArray((.)key + 1));
					return ref this;
				}
			case .ARRAY:
				{
					let array = this.Value.Get<JsonArray>();

					if (array.Count - 1 >= (.)key)
					{
						return ref array[(.)key];
					}
					else
					{
						ResizeArray(array, (.)key);
						array.Insert((.)key, default(JsonVariant));
						return ref array[(.)key];
					}
				}
			default:
				{
					this.Dispose();
					this = JsonVariant(new JsonArray());
					return ref this;
				}
			}
		}

		// Array
		public void Add(JsonVariant item) mut
		{
			switch (JType)
			{
			case .ARRAY:
				{
					let array = this.Value.Get<JsonArray>();
					array.Add(item);
					return;
				}
			default:
				{
					this.Dispose();
					let array = new JsonArray();
					array.Add(item);
					this = JsonVariant(array);
					return;
				}

			}
		}

		public void Add((String key, JsonVariant value) item) mut
		{
			switch (JType)
			{
			case .OBJECT:
				{
					let obj = this.Value.Get<JsonObject>();
					obj.Add(new String(item.key), item.value);
					return;
				}
			default:
				{
					this.Dispose();
					let obj = new JsonObject();
					obj.Add(new String(item.key), item.value);
					this = JsonVariant(obj);
					return;
				}

			}
		}


		public void ResizeArray(JsonArray array, int newSize, bool autoFree = true)
		{
			if (newSize > array.Count)
			{
				// just grow array
				for (int i in 0 ... newSize - array.Count)
					array.Add(default);
				return;
			}
			/*else
			{
				var nItemsTofree = array.Count - newSize;

				for (var item in array[... ^nItemsTofree])
				{
					item.Dispose();
				}

				array.RemoveRange(newSize, nItemsTofree);
			}*/
		}



		static T GetTypedValue<T>(Self self) where T : class
		{
			if (self.JType == .NULL)
				return default;// fail silently

			if (self.Value.VariantType == typeof(T))
				return self.Value.Get<T>();
			else
				return default;// fail silently
		}

		static T GetTypedValue<T>(Self self) where T : struct
		{
			if (self.JType == .NULL)
				return default;// fail silently

			if (self.Value.VariantType == typeof(T))
				return self.Value.Get<T>();
			else
				return default;// fail silently
		}

		public void Dispose() mut
		{
			if (this.Value.HasValue)
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
					delete array;
					break;
				case typeof(JsonObject):
					let obj = Value.Get<JsonObject>();
					for (var item in obj)
					{
						delete item.key;
						/*item.value.PreDispose();*/
						item.value.Dispose();
					}
					delete obj;
					break;
				default:
					Value.Dispose();
					break;
				}
			}

			SetType(.NULL);
		}
	}
}
