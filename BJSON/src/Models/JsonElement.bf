using System;
using System.Collections;
using BJSON.Enums;
using BJSON.Models;
namespace BJSON
{
	struct JsonElement
	{
		// if its root then
		// key is empty
		/*public String Key;
		public Variant Value;*/

		//Content can be JSON Object, JSON Array or single value
		public Variant Content;// = .();
		/*int Hash;*/


		// we are adding value to array
		/*public this(JsonVariant value)
		{
			type = .ARRAY;
			let array = new JsonArray();
			array.Add(value);
			Content = .Create(array);
		}*/

		// we are adding value to object
		/*private this(String key, JsonVariant value)
		{
			//Children.Add(key, value);

			/*this.Key = key;
			this.Value = value;*/
		}*/

		/*public ~this()
		{
			/*if (Key != null)
				delete Key;

			Value.Dispose();*/
		}*/



		// Access object
		public JsonVariant this[String key]
		{
			get;
			set => SetChildByName(key, value);
		}

		// Access array
		public JsonVariant this[uint index]
		{
			get => GetChildFromIndex(index);
			set => SetChildByIndex(index, value);
		}

		public void AddChild(String key, JsonElement child)
		{
		}

		public void AddChildren(String key, JsonElement[] children)
		{
		}

		/*private T GetTypedContent<T>(JsonType type) where T: JsonType
		{
			return Content.Get<T>();

		}*/


		private JsonVariant GetChildFromIndex(uint index)
		{
			// for now fail silently

			//let res = Children.TryGet();

			/*if (!this.Value.HasValue)
			{
				return null;
			}
			else if (this.Value.VariantType != typeof(JsonElement[]))
			{
				// we want
				// to be array ... otherwise we cant use numeric indexer
				return null;
			}

			let array = this.Value.Get<List<JsonElement>>();

			// handle bounds
			if (index + 1 > (.)array.Count)
			{
				return null;
			}*/

			return default ;//array[(.)index];
		}

		void SetChildByIndex(uint index, JsonVariant self)
		{
			/*let val = self.Value;
			self.Value = .();//rewrite with empty variant
			// value from temp self

			delete self;// remove temp

			let child = GetChildFromIndex(index);

			if (child == null)// create new if fail
			{
				return;
			}

			child.Value = val;// assign our value*/
		}

		Self GetChildByName(String key, Self self)
		{
			// if child
			// doesn't exist we create one
			/*if (this.Value.VariantType.IsArray)
			{
				var entries = this.Value.Get<Self[]>();
				var keyHash = key.GetHashCode();

				for (let entry in entries)
				{
					if (entry.Hash == keyHash)
					{
					}
				}
			}
			else
			{
				// single value
			}*/

			return default;
		}

		void SetChildByName(String key, JsonVariant value)
		{
			// if child
			// doesn't exist we create one
			/*if (this.Value.VariantType.IsArray)
			{
				var entries = this.Value.Get<Self[]>();
				var keyHash = key.GetHashCode();

				for (let entry in entries)
				{
					if (entry.Hash == keyHash)
					{
					}
				}
			}
			else
			{
				// single value
			}*/
		}

		/*[Warn("We are allocating memory")]
		public static operator Self(int value)
		{
			// json supports only double
			//WARN: Allocating
			return new JsonElement(null, .Create((double)value));
		}

		[Warn("We are allocating memory")]
		public static operator Self(String value)
		{
			//WARN: Allocating

			if (value.IsDynAlloc)
				return new JsonElement(null, .Create(value, true));
			else
				return new JsonElement(null, .Create(value));
		}

		public static operator Self(StringView value)
		{
			//WARN: Allocating
			return new JsonElement(null, .Create(value));
		}*/

		public static operator int(Self element)
		{
			return (.)GetValue<double>(element);
		}

		public static operator double(Self element)
		{
			return GetValue<double>(element);
		}

		public static operator String(Self element)
		{
			return GetValue<String>(element);
		}

		private static T GetValue<T>(Self element)
		{
			/*if (element == null || !element.Value.HasValue)// fail silently
				return default;

			if (element.Value.VariantType == typeof(T))
			{
				return element.Value.Get<T>();
			}

			return default;
		}

		private T GetValue<T>()
		{
			if (!this.Value.HasValue)// fail silently
				return default;

			if (this.Value.VariantType is T)
			{
				return this.Value.Get<T>();
			}*/

			return default;
		}

		public int GetHashCode()
		{
			return default;
		}
	}
}
