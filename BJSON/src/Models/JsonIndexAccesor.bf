using System;
namespace BJSON.Models
{
	public struct JsonIndexAccesor
	{
		public Variant Value;
		public JsonElement root;

		/*// Access object
		public JsonElement this[String key]
		{
			get;
			set => SetChildByName(key, value);
		}

		// Access array
		public JsonElement this[uint index]
		{
			get => GetChildFromIndex(index);
			set => SetChildByIndex(index, value);
		}*/


		public this()
		{
			this = default;
		}

		public static operator Self(int number)
		{
			return default;
		}

		public static operator Self(String number)
		{
			return default;
		}


		public static operator int(Self element)
		{
			if (element == null)// fail silently
				return default;



			return default;
		}
	}
}
