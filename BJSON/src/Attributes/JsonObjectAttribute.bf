using System;
using System.Reflection;
namespace BJSON.Attributes;

/*[AttributeUsage(.Method)]
public struct JsonDesImplGenAttribute : Attribute, IOnMethodInit
{
	Type type = null;

	String ObjectName = "";

	public this(Type type, String customObjName)
	{
		this.type = type;
		this.ObjectName = customObjName;
	}


	[Comptime]
	public void OnMethodInit(System.Reflection.MethodInfo methodInfo, Self* prev)
	{
		Compiler.EmitMethodEntry(methodInfo, """
	if (value.IsObject() == false)
		return .Err;

	// Main Object Part
	let mainObject = Try!(value.AsObject());\n
	""");

		/*if(CustomObjectName.IsEmpty)
		{
			Compiler.EmitTypeBody(type,scope  $"let thisClassObject = Try!(Try!(mainObject.GetValue(\"{type.GetName(.. scope .())}\")).AsObject());\n");
		}
		else
		{
			Compiler.EmitTypeBody(type,scope  $"let thisClassObject = Try!(Try!(mainObject.GetValue(\"{CustomObjectName}\")).AsObject());\n");
		}*/
	}
}*/


[AttributeUsage(.Class | .Struct, false, false)]
public struct JsonObjectAttribute : Attribute, IOnTypeInit, IOnTypeDone, IOnMethodInit
{
	String Name = "";

	public this(String name = "")
	{
		this.Name = name;
	}

	[Comptime]
	private void GenerateFieldAssigment(Type type, FieldInfo field)
	{
	}

	[Comptime]
	public void OnTypeInit(Type type, Self* prev)
	{
		Compiler.EmitAddInterface(type, typeof(IJsonSerializable));

		//Compiler.EmitTypeBody(type, scope $"[JsonDesImplGen({type.GetName(.. scope .())}, \"{Name}\")]\n");

		Compiler.EmitTypeBody(type, """
    public System.Result<void> BJSON.IJsonSerializable.JsonDeserialize(JsonValue value)
    {
    	if (value.IsObject() == false)
    		return .Err;

    	// Main Object Part
    	let mainObject = Try!(value.AsObject());\n
    """);

		Compiler.EmitTypeBody(type, scope $"\tlet thisClassObject = Try!(Try!(mainObject.GetValue(\"{type.GetName(.. scope .())}\")).AsObject());\n\n");


		for (let field in type.GetFields())
		{
			if (!field.IsInstanceField || field.DeclaringType != type || field.IsPublic == false)
				continue;

			Compiler.EmitTypeBody(type, scope $"\tlet {field.Name}JsonObj = Try!(thisClassObject.GetValue(\"{field.Name}\"));\n");

			let isCheck = scope $"\tif({field.Name}JsonObj";
			var isValidObject = false;
			let fType = field.FieldType;

			/*let IsOptional = fType.IsNullable;

			if(IsOptional)
			{
				let lol = fType.UnderlyingType;
			}*/

			

			if (fType.[Friend]mTypeCode == .Boolean)
			{
				isCheck.Append(".IsBool()");
			}
			else if (fType.IsInteger || fType.IsFloatingPoint)
			{
				isCheck.Append(".IsNumber()");
			}
			else if (fType == typeof(String))
			{
				isCheck.Append(".IsString()");
			}
			/*else if (fType is Object || fType.IsStruct)
			{
				if (fType.HasCustomAttribute<JsonObjectAttribute>())
				{
					isCheck.Append(".IsObject()");
					isValidObject = true;
				}
			}*/



			isCheck.Append(" == false)\n");

			if (fType.IsNullable)
			{
				isCheck.Append("\t{\n\t");
			}
			else
			{
				isCheck.Append("\t\treturn .Err;\n\n");
			}

			if (fType.IsInteger || fType.IsFloatingPoint)
			{
				isCheck.Append(scope $"\t{field.Name} = (.){field.Name}JsonObj; \n");
			}
			else
			{
				if (isValidObject)
				{
					isCheck.Append(scope $"\t((IJsonSerializable){field.Name}).JsonDeserialize(value); \n");
				}
				else
				{
					isCheck.Append(scope $"\t{field.Name} = {field.Name}JsonObj; \n");
				}
			}

			if (fType.IsNullable)
			{
				isCheck.Append("\t}\n");
			}

			Compiler.EmitTypeBody(type, isCheck);

			Compiler.EmitTypeBody(type, "\n");

			//Compiler.EmitTypeBody(type, scope $"\tserializer.Store(\"{field.Name}\", {field.Name});\n");
		}

		//Compiler.EmitTypeBody(type, scope $"\tserializer.StartType(typeof({type.GetName(.. scope .())}));\n");
		/*for (let field in type.GetFields())
		{
			if (!field.IsInstanceField || field.DeclaringType != type)
				continue;

			//Compiler.EmitTypeBody(type, scope $"\tserializer.Store(\"{field.Name}\", {field.Name});\n");
		}*/
		Compiler.EmitTypeBody(type, "	return .Ok;\n}");
	}



	[Comptime]
	public void OnTypeDone(Type type, Self* prev)
	{
	}

	[Comptime]
	public void OnMethodInit(System.Reflection.MethodInfo methodInfo, Self* prev)
	{
		/*if(methodInfo.Name == "JsonDeserialize")
		{
			Compiler.EmitMethodEntry(methodInfo, "");
		}*/
	}
}