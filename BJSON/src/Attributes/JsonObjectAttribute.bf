using System;
using System.Reflection;
using System.Collections;
using BJSON.Enums;
using BJSON.CodeGen;

namespace BJSON.Attributes;

[AttributeUsage(.Class | .Struct)]
public struct JsonObjectAttribute : Attribute, IComptimeTypeApply
{
	public String Name;
	public JsonFieldDefaultBehavior DefaultBehavior;

	public this(String name = "", JsonFieldDefaultBehavior defaultBehavior = .Optional)
	{
		this.Name = name;
		this.DefaultBehavior = defaultBehavior;
	}

	[Comptime]
	public void ApplyToType(Type type)
	{
		ValidateFields(type);
		Compiler.EmitAddInterface(type, typeof(IJsonSerializable));
		JsonDeserializerCodeGen.EmitDeserializeMethod(type);
		JsonSerializerCodeGen.EmitSerializeMethod(type);
	}

	[Comptime]
	private void ValidateFields(Type type)
	{
		for (let field in type.GetFields())
		{
			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			var fieldType = JsonCodeGenHelper.UnwrapNullable(field.FieldType);

			if (JsonCodeGenHelper.IsPrimitiveOrBuiltin(fieldType))
				continue;
			if (JsonCodeGenHelper.IsCollection(fieldType))
				continue;
			if (fieldType.IsEnum)
				continue;

		if (fieldType.IsObject || fieldType.IsStruct)
			{
				// If field has a custom converter, it's valid
				if (field.HasCustomAttribute<JsonConverterAttribute>())
					continue;

				// If the type itself has a custom converter, it's valid
				if (fieldType.HasCustomAttribute<JsonConverterAttribute>())
					continue;

				if (!fieldType.HasCustomAttribute<JsonObjectAttribute>())
				{
					String typeName = scope .();
					fieldType.GetFullName(typeName);
					Runtime.FatalError(scope $"Field '{field.Name}' is of type '{typeName}' which does not have [JsonObject] attribute. Add [JsonObject] to the type or [JsonIgnore] to the field.");
				}
			}
		}
	}
}
