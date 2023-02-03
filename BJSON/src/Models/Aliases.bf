using System.Collections;
using System;
namespace BJSON.Models
{
	public typealias JsonObject = Dictionary<String, JsonVariant>;
	public typealias JsonArray = List<JsonVariant>;
	public typealias JsonKeyPair = (StringView key, JsonVariant value);
}
