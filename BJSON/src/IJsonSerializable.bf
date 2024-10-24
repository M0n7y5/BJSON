using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;
namespace BJSON;

interface IJsonSerializable
{
	//Result<void> JsonSerialize(String buffer);

	public Result<void> JsonDeserialize(JsonValue value);
}


class Red : IJsonSerializable
{
	bool IsSus = true;

	Int8 Health = (.)100;


	public Result<void> JsonSerialize(String buffer)
	{
		return default;
	}

	public Result<void> JsonDeserialize(JsonValue value)
	{
		if (value.IsObject() == false)
			return .Err;
		// Main Object Part
		let mainObject = Try!(value.AsObject());

		let thisClassObject = Try!(Try!(mainObject.GetValue("Red")).AsObject());

		// Field: IsSus Part

		//Get Obj
		let isSusJsonObj = Try!(thisClassObject.GetValue("IsSus"));

		// Check Type
		if(isSusJsonObj.IsBool() == false)
			return .Err;

		// extract value
		IsSus = isSusJsonObj;
		
		// Field: Health Part

		//Get Obj
		let healthJsonObj = Try!(thisClassObject.GetValue("Health"));

		// Check Type
		if(healthJsonObj.IsNumber() == false)
			return .Err;

		// extract value
		Health = (.)(int)healthJsonObj;
		
		return .Ok;
	}
}