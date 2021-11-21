using System;
namespace BJSON.Models
{
	interface IHandler
	{
		bool Null();
		bool Bool(bool b);
		//bool Int(int i);
		//bool Uint(unsigned i);
		//bool Int64(int64_t i);
		//bool Uint64(uint64_t i);
		bool Double(double d);
		//bool RawNumber(const Ch* str, SizeType length, bool copy);
		bool String(StringView str, bool copy);
		bool StartObject();
		bool Key(StringView str, bool copy);
		bool EndObject();
		bool StartArray();
		bool EndArray();
	}
}
