using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

[JsonObject]
class Settings
{
	public int64 Id;

	[JsonExtensionData]
	public Dictionary<String, String> AdditionalProperties = new .() ~ DeleteDictionaryAndKeysAndValues!(_);

}
