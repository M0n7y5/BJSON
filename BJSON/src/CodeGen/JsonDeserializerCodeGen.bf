using System;
using System.Reflection;
using System.Collections;
using BJSON.Attributes;
using BJSON.Enums;

namespace BJSON.CodeGen;

/// Handles JSON deserialization code generation at compile time.
/// Every method here only appends Beef source text that JsonObjectAttribute.ApplyToType
/// hands to the compiler; nothing in this class runs at runtime.
public class JsonDeserializerCodeGen
{
	/// Emits JsonDeserialize into type: it rejects a non object JsonValue, then reads one
	/// property per included field, including the fields of every base type.
	/// @param type The [JsonObject] type receiving the method body.
	[Comptime]
	public static void EmitDeserializeMethod(Type type)
	{
		let code = scope String();

		// A base type with [JsonObject] already had JsonDeserialize emitted into it, so the
		// derived emission has to say `new` to shadow the inherited method.
		bool needsNewKeyword = type.BaseType != null && type.BaseType != typeof(Object)
			&& type.BaseType.HasCustomAttribute<JsonObjectAttribute>();

		let newKeyword = needsNewKeyword ? "new " : "";

		// The emitted text is parsed in the target type's context, so every name is fully
		// qualified; the target file is not required to have BJSON using directives.
		// Braces of the emitted body are doubled: inside an interpolated template {{ and }}
		// collapse to one literal brace, and a lone { would open an interpolation hole.
		code.AppendF($"""
			public {newKeyword}Result<void> JsonDeserialize(BJSON.Models.JsonValue value)
			{{
				if (!value.IsObject())
					return .Err;
				
				let root = value.AsObject().Value;

			""");

		EmitAllFields(code, type);

		// Append, not AppendF: this tail is not interpolated, so its brace stays single.
		code.Append("""
				return .Ok;
			}\n
			""");

		Compiler.EmitTypeBody(type, code);
	}

	/// Emits the field reads for type and for every base type up to Object, base fields first.
	[Comptime]
	private static void EmitAllFields(String code, Type type)
	{
		if (type.BaseType != null && type.BaseType != typeof(Object))
		{
			EmitAllFields(code, type.BaseType);
		}

		for (let field in type.GetFields())
		{
			// GetFields() also returns inherited fields, down to inaccessible System.Object
			// internals. Base types are walked separately above, so only own fields pass.
			if (field.DeclaringType != type)
				continue;

			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			EmitFieldDeserialization(code, field, type);
		}
	}

	/// Emits the read of one field into code. A required field makes JsonDeserialize fail when
	/// the property is absent; an optional one is skipped. Requiredness comes from the owner's
	/// [JsonObject] DefaultBehavior, overridden per field by [JsonRequired] or [JsonOptional].
	[Comptime]
	private static void EmitFieldDeserialization(String code, FieldInfo field, Type ownerType)
	{
		// GetSourceLiteralName applies the source literal escape only. The emitted GetValue
		// call matches against the key the parser already decoded, so JSON escaping the name
		// here would look up a key that never arrives.
		let jsonName = scope String();
		JsonCodeGenHelper.GetSourceLiteralName(field, jsonName);

		var fieldType = field.FieldType;
		let isNullable = fieldType.IsNullable;
		let isRequired = field.HasCustomAttribute<JsonRequiredAttribute>();
		let isOptional = field.HasCustomAttribute<JsonOptionalAttribute>();

		if (isNullable)
			fieldType = JsonCodeGenHelper.UnwrapNullable(fieldType);

		JsonFieldDefaultBehavior defaultBehavior = .Optional;
		if (let objAttr = ownerType.GetCustomAttribute<JsonObjectAttribute>())
		{
			defaultBehavior = objAttr.DefaultBehavior;
		}

		bool isFieldRequired;
		if (defaultBehavior == .Required)
		{
			isFieldRequired = !isOptional;
		}
		else
		{
			isFieldRequired = isRequired;
		}

		if (isFieldRequired)
		{
			code.AppendF($"\tlet _{field.Name}Json = Try!(root.GetValue(\"{jsonName}\"));\n");
			EmitFieldValueDeserialization(code, field, fieldType, scope $"_{field.Name}Json", "\t");
			code.Append("\n");
		}
		else
		{
			code.AppendF($"\tif (root.GetValue(\"{jsonName}\") case .Ok(let _{field.Name}Json))\n");
			code.Append("\t{\n");
			EmitFieldValueDeserialization(code, field, fieldType, scope $"_{field.Name}Json", "\t\t");
			code.Append("\t}\n\n");
		}
	}

	[Comptime]
	private static void EmitFieldValueDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		// field.FieldType, not fieldType: the null test has to see the declared Nullable<T>,
		// which the caller unwrapped before getting here.
		if (fieldType.IsObject || field.FieldType.IsNullable)
		{
			code.AppendF($"{indent}if (!{jsonVar}.IsNull())\n");
			code.AppendF($"{indent}{{\n");
			EmitFieldValueDeserializationBody(code, field, fieldType, jsonVar, scope $"{indent}\t");
			code.AppendF($"{indent}}}\n");
			return;
		}

		EmitFieldValueDeserializationBody(code, field, fieldType, jsonVar, indent);
	}

	[Comptime]
	private static void EmitFieldValueDeserializationBody(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		if (let converterAttr = field.GetCustomAttribute<JsonConverterAttribute>())
		{
			String typeName = scope .();
			fieldType.GetFullName(typeName);
			String converterTypeName = scope .();
			converterAttr.ConverterType.GetFullName(converterTypeName);
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
			code.AppendF($"{indent}\tdefer delete _converter;\n");
			code.AppendF($"{indent}\tif (_converter.ReadJson({jsonVar}) case .Ok(let _convertedValue))\n");
			code.AppendF($"{indent}\t\t{field.Name} = _convertedValue;\n");
			code.AppendF($"{indent}\telse\n");
			code.AppendF($"{indent}\t\treturn .Err;\n");
			code.AppendF($"{indent}}}\n");
			return;
		}

		if (fieldType == typeof(bool))
		{
			code.AppendF($"{indent}if (!{jsonVar}.IsBool()) return .Err;\n");
			code.AppendF($"{indent}{field.Name} = {jsonVar};\n");
		}
		else if (fieldType.IsInteger || fieldType.IsFloatingPoint)
		{
			code.AppendF($"{indent}if (!{jsonVar}.IsNumber()) return .Err;\n");
			code.AppendF($"{indent}{field.Name} = (.) {jsonVar};\n");
		}
		else if (fieldType == typeof(String))
		{
			code.AppendF($"{indent}if (!{jsonVar}.IsString()) return .Err;\n");
			code.AppendF($"{indent}if ({field.Name} == null) {field.Name} = new String();\n");
			code.AppendF($"{indent}{field.Name}.Set((StringView){jsonVar});\n");
		}
		else if (fieldType.IsEnum)
		{
			EmitEnumDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (JsonCodeGenHelper.IsList(fieldType))
		{
			EmitListDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (JsonCodeGenHelper.IsDictionary(fieldType))
		{
			EmitDictionaryDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (fieldType.IsSizedArray)
		{
			EmitSizedArrayDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (fieldType.IsObject || fieldType.IsStruct)
		{
			code.AppendF($"{indent}if (!{jsonVar}.IsObject()) return .Err;\n");
			code.AppendF($"{indent}Try!({field.Name}.JsonDeserialize({jsonVar}));\n");
		}
	}

	[Comptime]
	private static void EmitEnumDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		String typeName = scope .();
		fieldType.GetFullName(typeName);

		code.AppendF($"{indent}if ({jsonVar}.IsString())\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (Enum.Parse<{typeName}>((StringView){jsonVar}) case .Ok(let enumVal))\n");
		code.AppendF($"{indent}\t\t{field.Name} = enumVal;\n");
		code.AppendF($"{indent}\telse\n");
		code.AppendF($"{indent}\t\treturn .Err;\n");
		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}else if ({jsonVar}.IsNumber())\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\t{field.Name} = ({typeName})(int){jsonVar};\n");
		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}else\n");
		code.AppendF($"{indent}\treturn .Err;\n");
	}

	[Comptime]
	private static void EmitListDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		let elementType = JsonCodeGenHelper.GetElementType(fieldType);
		if (elementType == null)
			return;

		code.AppendF($"{indent}if (!{jsonVar}.IsArray()) return .Err;\n");
		code.AppendF($"{indent}let _{field.Name}Arr = {jsonVar}.AsArray().Value;\n");
		code.AppendF($"{indent}for (let _item in _{field.Name}Arr)\n");
		code.AppendF($"{indent}{{\n");

		EmitListItemDeserialization(code, field, elementType, "_item", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
	}

	/// Emits the read of one list element into code, honouring a [JsonConverter] on the
	/// element type.
	/// An element type outside the supported set emits nothing here, and generation still
	/// fails: the serializer emitter runs for the same type and rejects that element by name.
	[Comptime]
	private static void EmitListItemDeserialization(String code, FieldInfo field, Type elementType, StringView itemVar, StringView indent)
	{
		if (let converterAttr = elementType.GetCustomAttribute<JsonConverterAttribute>())
		{
			String typeName = scope .();
			elementType.GetFullName(typeName);
			String converterTypeName = scope .();
			converterAttr.ConverterType.GetFullName(converterTypeName);
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
			code.AppendF($"{indent}\tdefer delete _converter;\n");
			code.AppendF($"{indent}\tif (_converter.ReadJson({itemVar}) case .Ok(let _convertedValue))\n");
			code.AppendF($"{indent}\t\t{field.Name}.Add(_convertedValue);\n");
			code.AppendF($"{indent}\telse\n");
			code.AppendF($"{indent}\t\treturn .Err;\n");
			code.AppendF($"{indent}}}\n");
			return;
		}

		if (elementType == typeof(bool))
		{
			code.AppendF($"{indent}if (!{itemVar}.IsBool()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.Add((bool){itemVar});\n");
		}
		else if (elementType.IsInteger || elementType.IsFloatingPoint)
		{
			String typeName = scope .();
			elementType.GetFullName(typeName);
			code.AppendF($"{indent}if (!{itemVar}.IsNumber()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.Add(({typeName}){itemVar});\n");
		}
		else if (elementType == typeof(String))
		{
			code.AppendF($"{indent}if (!{itemVar}.IsString()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.Add(new String((StringView){itemVar}));\n");
		}
		else if (elementType.IsEnum)
		{
			String typeName = scope .();
			elementType.GetFullName(typeName);
			code.AppendF($"{indent}if ({itemVar}.IsString())\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tif (Enum.Parse<{typeName}>((StringView){itemVar}) case .Ok(let enumVal))\n");
			code.AppendF($"{indent}\t\t{field.Name}.Add(enumVal);\n");
			code.AppendF($"{indent}\telse\n");
			code.AppendF($"{indent}\t\treturn .Err;\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}else if ({itemVar}.IsNumber())\n");
			code.AppendF($"{indent}\t{field.Name}.Add(({typeName})(int){itemVar});\n");
			code.AppendF($"{indent}else\n");
			code.AppendF($"{indent}\treturn .Err;\n");
		}
		else if (elementType.HasCustomAttribute<JsonObjectAttribute>())
		{
			String typeName = scope .();
			elementType.GetFullName(typeName);
			code.AppendF($"{indent}if (!{itemVar}.IsObject()) return .Err;\n");
			code.AppendF($"{indent}let _newItem = new {typeName}();\n");
			code.AppendF($"{indent}if (_newItem.JsonDeserialize({itemVar}) case .Err)\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tdelete _newItem;\n");
			code.AppendF($"{indent}\treturn .Err;\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}{field.Name}.Add(_newItem);\n");
		}
	}

	[Comptime]
	private static void EmitDictionaryDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		Type keyType, valueType;
		JsonCodeGenHelper.GetDictionaryTypes(fieldType, out keyType, out valueType);
		if (keyType == null || valueType == null)
			return;

		// JSON object keys are always strings, so a non String key cannot round trip. A
		// comptime method cannot return an error, so this has to be fatal.
		if (keyType != typeof(String))
		{
			Runtime.FatalError(scope $"Dictionary field '{field.Name}' must have String keys for JSON serialization.");
		}

		code.AppendF($"{indent}if (!{jsonVar}.IsObject()) return .Err;\n");
		code.AppendF($"{indent}let _{field.Name}Obj = {jsonVar}.AsObject().Value;\n");
		code.AppendF($"{indent}for (let _kv in _{field.Name}Obj)\n");
		code.AppendF($"{indent}{{\n");

		EmitDictionaryValueDeserialization(code, field, valueType, "_kv.key", "_kv.value", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
	}

	/// Emits the read of one dictionary entry into code, honouring a [JsonConverter] on the
	/// value type. Keys are copied into new Strings that the dictionary owns.
	/// Enum values are not handled: they are skipped silently here while the serializer writes
	/// them, so such a dictionary comes back empty.
	[Comptime]
	private static void EmitDictionaryValueDeserialization(String code, FieldInfo field, Type valueType, StringView keyVar, StringView valueVar, StringView indent)
	{
		if (let converterAttr = valueType.GetCustomAttribute<JsonConverterAttribute>())
		{
			String typeName = scope .();
			valueType.GetFullName(typeName);
			String converterTypeName = scope .();
			converterAttr.ConverterType.GetFullName(converterTypeName);
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
			code.AppendF($"{indent}\tdefer delete _converter;\n");
			code.AppendF($"{indent}\tif (_converter.ReadJson({valueVar}) case .Ok(let _convertedValue))\n");
			code.AppendF($"{indent}\t\t{field.Name}.Add(new String({keyVar}), _convertedValue);\n");
			code.AppendF($"{indent}\telse\n");
			code.AppendF($"{indent}\t\treturn .Err;\n");
			code.AppendF($"{indent}}}\n");
			return;
		}

		if (valueType == typeof(bool))
		{
			code.AppendF($"{indent}if (!{valueVar}.IsBool()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), (bool){valueVar});\n");
		}
		else if (valueType.IsInteger || valueType.IsFloatingPoint)
		{
			String typeName = scope .();
			valueType.GetFullName(typeName);
			code.AppendF($"{indent}if (!{valueVar}.IsNumber()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), ({typeName}){valueVar});\n");
		}
		else if (valueType == typeof(String))
		{
			code.AppendF($"{indent}if (!{valueVar}.IsString()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), new String((StringView){valueVar}));\n");
		}
		else if (valueType.HasCustomAttribute<JsonObjectAttribute>())
		{
			String typeName = scope .();
			valueType.GetFullName(typeName);
			code.AppendF($"{indent}if (!{valueVar}.IsObject()) return .Err;\n");
			code.AppendF($"{indent}let _newVal = new {typeName}();\n");
			code.AppendF($"{indent}if (_newVal.JsonDeserialize({valueVar}) case .Err)\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tdelete _newVal;\n");
			code.AppendF($"{indent}\treturn .Err;\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), _newVal);\n");
		}
	}

	[Comptime]
	private static void EmitSizedArrayDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		let elementType = fieldType.UnderlyingType;
		let sizedArrayType = fieldType as SizedArrayType;
		let arraySize = sizedArrayType != null ? sizedArrayType.ElementCount : 0;

		code.AppendF($"{indent}if (!{jsonVar}.IsArray()) return .Err;\n");
		code.AppendF($"{indent}let _{field.Name}Arr = {jsonVar}.AsArray().Value;\n");
		code.AppendF($"{indent}let _arrLen = Math.Min(_{field.Name}Arr.Count, {arraySize});\n");
		code.AppendF($"{indent}for (int _i = 0; _i < _arrLen; _i++)\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tlet _item = _{field.Name}Arr[_i];\n");

		EmitSizedArrayItemDeserialization(code, field, elementType, "_item", "_i", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
	}

	/// Emits the read of one sized array element into code.
	/// Only bool and numeric elements are handled: String fails generation, and any other
	/// element type is skipped silently, leaving those slots at their default value.
	[Comptime]
	private static void EmitSizedArrayItemDeserialization(String code, FieldInfo field, Type elementType, StringView itemVar, StringView indexVar, StringView indent)
	{
		if (elementType == typeof(bool))
		{
			code.AppendF($"{indent}if (!{itemVar}.IsBool()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}[{indexVar}] = (bool){itemVar};\n");
		}
		else if (elementType.IsInteger || elementType.IsFloatingPoint)
		{
			String typeName = scope .();
			elementType.GetFullName(typeName);
			code.AppendF($"{indent}if (!{itemVar}.IsNumber()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}[{indexVar}] = ({typeName}){itemVar};\n");
		}
		else if (elementType == typeof(String))
		{
			// Emitting `new String` into a fixed slot would allocate with nothing to free it.
			// A comptime method cannot return an error, so this has to be fatal.
			Runtime.FatalError(scope $"Sized arrays of String are not supported. Use List<String> instead for field '{field.Name}'.");
		}
	}
}
