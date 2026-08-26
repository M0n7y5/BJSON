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

	/// Rejects fields no emitter can handle, by asking JsonCodeGenHelper.Classify the same
	/// question both emitters ask: anything it calls Unsupported aborts the build here, before a
	/// method body that would silently skip the field lands in type.
	/// Collection element and value types are not checked here: the emitters reject those by name
	/// when they emit the element handling.
	/// @param type The type being emitted.
	[Comptime]
	private void ValidateFields(Type type)
	{
		for (let field in type.GetFields())
		{
			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			let fieldType = JsonCodeGenHelper.UnwrapNullable(field.FieldType);

			if (JsonCodeGenHelper.Classify(field, fieldType) != .Unsupported)
				continue;

			String typeName = scope .();
			fieldType.GetFullName(typeName);

			// Generation errors are raised with Runtime.FatalError because a comptime method
			// cannot return an error to the compiler.
			if (fieldType == typeof(StringView))
				Runtime.FatalError(scope $"Field '{field.Name}' is a StringView, which cannot own the text deserialization produces. Use String.");
			else
				Runtime.FatalError(scope $"Field '{field.Name}' is of type '{typeName}', which BJSON cannot handle. Add [JsonObject] to that type, [JsonConverter] to the field, or [JsonIgnore(Condition = .Always)] to the field.");
		}
	}
}
