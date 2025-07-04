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
public struct JsonObjectAttribute :
	Attribute, IComptimeTypeApply
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
	void EmmitBody(Type type, Self* _)
	{
		Compiler.EmitTypeBody(type, """
		    public System.Result<void> JsonDeserialize(JsonValue value)
		    {
		    	if (value.IsObject() == false)
		    		return .Err;
		
		    	let scopeObject = Try!(value.AsObject());\n
		    """);

		let thisObjectName = this.Name.Length == 0 ? type.GetName(.. scope .()) : this.Name;

		Compiler.EmitTypeBody(type, scope $"\tlet thisClassObject = Try!(Try!(scopeObject.GetValue(\"{thisObjectName}\")).AsObject());\n\n");


		for (let field in type.GetFields())
		{
			if (!field.IsInstanceField || field.DeclaringType != type || field.IsPublic == false)
				continue;

			let isCheck = scope $"\tif({field.Name}JsonField";
			var isValidObject = false;

			var fieldType = field.FieldType;
			let IsOptional = fieldType.IsNullable;

			if (IsOptional)
			{
				// we need to extract the actual field type
				let nullType = (SpecializedGenericType)fieldType.TypeDeclaration.ResolvedType;
				let genType = nullType.GetGenericArg(0);
				fieldType = genType;
				Compiler.EmitTypeBody(type, scope $"\tif(let {field.Name}JsonField = thisClassObject.GetValue(\"");

				//shitcode before formatter is fixed
				Compiler.EmitTypeBody(type, scope $"{field.Name}\"))\n");

				Compiler.EmitTypeBody(type, "\t{\n\t");
			}
			else
			{
				Compiler.EmitTypeBody(type, scope $"\tlet {field.Name}JsonField = Try!(thisClassObject.GetValue(\"");
				//shitcode before formatter is fixed
				Compiler.EmitTypeBody(type, scope $"{field.Name}\"));\n");
			}

			if (fieldType.[Friend]mTypeCode == .Boolean)
			{
				isCheck.Append(".IsBool()");
			}
			else if (fieldType.IsInteger || fieldType.IsFloatingPoint)
			{
				isCheck.Append(".IsNumber()");
			}
			else if (fieldType == typeof(String))
			{
				isCheck.Append(".IsString()");
			}
			else if (fieldType.IsObject  || fieldType.IsStruct)
			{
				isCheck.Append(".IsObject()");
				isValidObject = true;
			}

			if (IsOptional)
			{
				isCheck.Append(")\n");
				isCheck.Append("\t\t{\n\t\t");
			}
			else
			{
				isCheck.Append(" == false)\n");
				isCheck.Append("\t\treturn .Err;\n\n");
			}

			if (fieldType.IsInteger || fieldType.IsFloatingPoint)
			{
				isCheck.Append(scope $"\t{field.Name} = (.) {field.Name}JsonField; \n");
			}
			else
			{
				if (isValidObject)
				{
					isCheck.Append(scope $"\t{field.Name}.JsonDeserialize(value); \n");
				}
				else
				{
					isCheck.Append(scope $"\t{field.Name} = {field.Name}JsonField; \n");
				}
			}

			if (IsOptional)
			{
				isCheck.Append("\t\t}\n\t}\n");
			}

			Compiler.EmitTypeBody(type, isCheck);

			Compiler.EmitTypeBody(type, "\n");
		}

		Compiler.EmitTypeBody(type, "	return .Ok;\n}");
	}


	[Comptime]
	void CheckSerializableFields(Type type)
	{
		for (let field in type.GetFields())
		{
			if (!field.IsPublic)
				continue;

			var fieldType = field.FieldType;

			if(fieldType.IsNullable)
			{
				let nullType = (SpecializedGenericType)fieldType.TypeDeclaration.ResolvedType;
				let genType = nullType.GetGenericArg(0);
				fieldType = genType;
			}

			if (!fieldType.IsObject)
				continue;

			if (fieldType.HasCustomAttribute<JsonObjectAttribute>())
				continue;

			let errMsg = scope String();
			errMsg.Append(scope $"Serializable field '{field.Name}' is type of '{fieldType.GetFullName(.. scope .())}' that does not have JsonObject Attribute.\n");
			errMsg.Append("See https://github.com/M0n7y5/BJSON/wiki\n\n");

			Runtime.FatalError(errMsg);
		}
	}

	[Comptime]
	public void ApplyToType(Type type)
	{
		CheckSerializableFields(type);

		Compiler.EmitAddInterface(type, typeof(IJsonSerializable));
		EmmitBody(type, null);
	}
}