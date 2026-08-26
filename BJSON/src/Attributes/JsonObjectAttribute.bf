using System;
using System.Reflection;
using System.Collections;
using BJSON.Enums;
using BJSON.CodeGen;

namespace BJSON.Attributes;

/// Marks a class or struct for compile time JSON codegen: ApplyToType validates the fields,
/// adds IJsonSerializable to the annotated type, and emits the JsonDeserialize and
/// JsonSerialize bodies into it.
[AttributeUsage(.Class | .Struct)]
public struct JsonObjectAttribute : Attribute, IComptimeTypeApply
{
	/// Object name recorded at the attribute call site. No emitter reads it today.
	public String Name;
	/// Required or optional default for fields carrying neither [JsonRequired] nor
	/// [JsonOptional]. Only the deserializer emitter reads it; serialization always writes
	/// every included field.
	public JsonFieldDefaultBehavior DefaultBehavior;

	/// @param name Object name, see the Name field.
	/// @param defaultBehavior Default required or optional handling for this type's fields.
	public this(String name = "", JsonFieldDefaultBehavior defaultBehavior = .Optional)
	{
		this.Name = name;
		this.DefaultBehavior = defaultBehavior;
	}

	/// Emits the JSON plumbing into the annotated type: the IJsonSerializable interface plus
	/// the JsonDeserialize and JsonSerialize method bodies.
	/// Validation runs first so an unsupported field aborts the build before any method body
	/// lands in type.
	/// @param type The type carrying this attribute.
	[Comptime]
	public void ApplyToType(Type type)
	{
		ValidateFields(type);
		Compiler.EmitAddInterface(type, typeof(IJsonSerializable));
		JsonDeserializerCodeGen.EmitDeserializeMethod(type);
		JsonSerializerCodeGen.EmitSerializeMethod(type);
	}

	/// Rejects fields no emitter can handle. A class or struct field is only accepted when the
	/// field or its type carries [JsonConverter], or when the type carries [JsonObject];
	/// primitives, builtins, enums and supported collections always pass.
	/// Collection element types are not checked here: the serializer emitter is what rejects
	/// an unsupported element type.
	/// @param type The type being emitted.
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
				// A converter supplies the serialization the missing [JsonObject] would have
				// generated, on the field or on the type.
				if (field.HasCustomAttribute<JsonConverterAttribute>())
					continue;

				if (fieldType.HasCustomAttribute<JsonConverterAttribute>())
					continue;

				if (!fieldType.HasCustomAttribute<JsonObjectAttribute>())
				{
					String typeName = scope .();
					fieldType.GetFullName(typeName);
					// Generation errors are raised with Runtime.FatalError because a comptime
					// method cannot return an error to the compiler.
					Runtime.FatalError(scope $"Field '{field.Name}' is of type '{typeName}' which does not have [JsonObject] attribute. Add [JsonObject] to the type or [JsonIgnore] to the field.");
				}
			}
		}
	}
}
