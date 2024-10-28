namespace BJSON.Models
{
	class GenericReaderHandler : IHandler
	{
		public bool Null()
		{
			return default;
		}

		public bool Bool(bool b)
		{
			return default;
		}

		public bool String(System.StringView str, bool copy)
		{
			return default;
		}

		public bool StartObject()
		{
			return default;
		}

		public bool Key(System.StringView str, bool copy)
		{
			return default;
		}

		public bool EndObject()
		{
			return default;
		}

		public bool StartArray()
		{
			return default;
		}

		public bool EndArray()
		{
			return default;
		}

		public bool Number(double n)
		{
			return default;
		}

		public bool Number(int64 n)
		{
			return default;
		}

		public bool Number(uint64 n)
		{
			return default;
		}
		public bool Number(float n)
		{
			return default;
		}
	}
}
