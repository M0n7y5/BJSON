using System;
using BJSON.Models;

namespace BJSON;

interface IJsonSerializable
{
	//Result<void> JsonSerialize(String buffer);

	public Result<void> JsonDeserialize(JsonValue value);
}