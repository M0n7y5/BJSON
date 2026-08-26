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

		let newKeyword = JsonCodeGenHelper.GetNewKeyword(type);

		// The emitted text is parsed in the target type's context, so every name is fully
		// qualified; the target file is not required to have BJSON using directives.
		// Braces of the emitted body are doubled: inside an interpolated template {{ and }}
		// collapse to one literal brace, and a lone { would open an interpolation hole.
		code.AppendF($"""
			public {newKeyword}Result<void, BJSON.Enums.JsonDeserializationError> JsonDeserialize(BJSON.Models.JsonValue value)
			{{
				if (!value.IsObject())
					return .Err(.TypeMismatch("", "object", value.TypeName()));
				
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

		// The error payloads are literals in the emitted source, so the name they carry goes
		// through the JSON escape first: a control character has no source escape of its own.
		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

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

		code.AppendF($"\tif (root.GetValue(\"{jsonName}\") case .Ok(let _{field.Name}Json))\n");
		code.Append("\t{\n");
		EmitFieldValueDeserialization(code, field, fieldType, scope $"_{field.Name}Json", "\t\t");
		code.Append("\t}\n");

		if (isFieldRequired)
			code.AppendF($"\telse\n\t\treturn .Err(.MissingRequiredField(\"/{errName}\", \"{errName}\"));\n");

		code.Append("\n");
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
		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		switch (JsonCodeGenHelper.Classify(field, fieldType))
		{
		case .Converter:
			{
				String converterTypeName = scope .();
				JsonCodeGenHelper.GetConverterType(field, fieldType).GetFullName(converterTypeName);
				code.AppendF($"{indent}{{\n");
				code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
				code.AppendF($"{indent}\tdefer delete _converter;\n");
				code.AppendF($"{indent}\tif (_converter.ReadJson({jsonVar}) case .Ok(let _convertedValue))\n");
				code.AppendF($"{indent}\t\t{field.Name} = _convertedValue;\n");
				code.AppendF($"{indent}\telse\n");
				code.AppendF($"{indent}\t\treturn .Err(.ConverterFailed(\"/{errName}\"));\n");
				code.AppendF($"{indent}}}\n");
			}
		case .Bool:
			code.AppendF($"{indent}if (!{jsonVar}.IsBool()) return .Err(.TypeMismatch(\"/{errName}\", \"bool\", {jsonVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name} = {jsonVar};\n");
		case .Integer, .Float:
			code.AppendF($"{indent}if (!{jsonVar}.IsNumber()) return .Err(.TypeMismatch(\"/{errName}\", \"number\", {jsonVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name} = (.) {jsonVar};\n");
		case .String:
			code.AppendF($"{indent}if (!{jsonVar}.IsString()) return .Err(.TypeMismatch(\"/{errName}\", \"string\", {jsonVar}.TypeName()));\n");
			code.AppendF($"{indent}if ({field.Name} == null) {field.Name} = new String();\n");
			code.AppendF($"{indent}{field.Name}.Set((StringView){jsonVar});\n");
		case .Enum:
			EmitEnumDeserialization(code, field, fieldType, jsonVar, indent);
		case .List:
			EmitListDeserialization(code, field, fieldType, jsonVar, indent);
		case .Dictionary:
			EmitDictionaryDeserialization(code, field, fieldType, jsonVar, indent);
		case .SizedArray:
			EmitSizedArrayDeserialization(code, field, fieldType, jsonVar, indent);
		case .JsonObject:
			code.AppendF($"{indent}if (!{jsonVar}.IsObject()) return .Err(.TypeMismatch(\"/{errName}\", \"object\", {jsonVar}.TypeName()));\n");
			code.AppendF($"{indent}Try!({field.Name}.JsonDeserialize({jsonVar}));\n");
		case .Unsupported:
			// ValidateFields rejects this before any emission starts, so reaching here means
			// Classify grew a kind this ladder does not read. FatalError is the only exit a
			// comptime method has: it cannot return an error.
			let typeName = scope String();
			fieldType.GetFullName(typeName);
			Runtime.FatalError(scope $"BJSON cannot deserialize field '{field.Name}' of type '{typeName}'.");
		}
	}

	[Comptime]
	private static void EmitEnumDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		String typeName = scope .();
		fieldType.GetFullName(typeName);
		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		code.AppendF($"{indent}if ({jsonVar}.IsString())\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (Enum.Parse<{typeName}>((StringView){jsonVar}) case .Ok(let _enumVal))\n");
		code.AppendF($"{indent}\t\t{field.Name} = _enumVal;\n");
		code.AppendF($"{indent}\telse\n");
		code.AppendF($"{indent}\t\treturn .Err(.InvalidEnumValue(\"/{errName}\", \"{typeName}\"));\n");
		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}else if ({jsonVar}.IsNumber())\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\t{field.Name} = ({typeName})(int){jsonVar};\n");
		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}else\n");
		code.AppendF($"{indent}\treturn .Err(.TypeMismatch(\"/{errName}\", \"string or number\", {jsonVar}.TypeName()));\n");
	}

	[Comptime]
	private static void EmitListDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		let elementType = JsonCodeGenHelper.GetElementType(fieldType);
		// Classify already said List, so a missing element type is a generator fault. Bailing
		// would skip the field without a word, so it has to be fatal.
		if (elementType == null)
			Runtime.FatalError(scope $"BJSON found no element type for list field '{field.Name}'.");

		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		code.AppendF($"{indent}if (!{jsonVar}.IsArray()) return .Err(.TypeMismatch(\"/{errName}\", \"array\", {jsonVar}.TypeName()));\n");
		code.AppendF($"{indent}let _{field.Name}Arr = {jsonVar}.AsArray().Value;\n");
		code.AppendF($"{indent}for (let _item in _{field.Name}Arr)\n");
		code.AppendF($"{indent}{{\n");

		EmitListItemDeserialization(code, field, elementType, "_item", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
	}

	/// Emits the read of one list element into code, honouring a [JsonConverter] on the field or
	/// on the element type.
	/// An element type outside the supported set fails generation and names itself, matching what
	/// the serializer emitter does for the same element.
	[Comptime]
	private static void EmitListItemDeserialization(String code, FieldInfo field, Type elementType, StringView itemVar, StringView indent)
	{
		String typeName = scope .();
		elementType.GetFullName(typeName);
		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		switch (JsonCodeGenHelper.Classify(field, elementType))
		{
		case .Converter:
			{
				String converterTypeName = scope .();
				JsonCodeGenHelper.GetConverterType(field, elementType).GetFullName(converterTypeName);
				code.AppendF($"{indent}{{\n");
				code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
				code.AppendF($"{indent}\tdefer delete _converter;\n");
				code.AppendF($"{indent}\tif (_converter.ReadJson({itemVar}) case .Ok(let _convertedValue))\n");
				code.AppendF($"{indent}\t\t{field.Name}.Add(_convertedValue);\n");
				code.AppendF($"{indent}\telse\n");
				code.AppendF($"{indent}\t\treturn .Err(.ConverterFailed(\"/{errName}\"));\n");
				code.AppendF($"{indent}}}\n");
			}
		case .Bool:
			code.AppendF($"{indent}if (!{itemVar}.IsBool()) return .Err(.TypeMismatch(\"/{errName}\", \"bool\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}.Add((bool){itemVar});\n");
		case .Integer, .Float:
			code.AppendF($"{indent}if (!{itemVar}.IsNumber()) return .Err(.TypeMismatch(\"/{errName}\", \"number\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}.Add(({typeName}){itemVar});\n");
		case .String:
			code.AppendF($"{indent}if (!{itemVar}.IsString()) return .Err(.TypeMismatch(\"/{errName}\", \"string\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}.Add(new String((StringView){itemVar}));\n");
		case .Enum:
			code.AppendF($"{indent}if ({itemVar}.IsString())\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tif (Enum.Parse<{typeName}>((StringView){itemVar}) case .Ok(let _enumVal))\n");
			code.AppendF($"{indent}\t\t{field.Name}.Add(_enumVal);\n");
			code.AppendF($"{indent}\telse\n");
			code.AppendF($"{indent}\t\treturn .Err(.InvalidEnumValue(\"/{errName}\", \"{typeName}\"));\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}else if ({itemVar}.IsNumber())\n");
			code.AppendF($"{indent}\t{field.Name}.Add(({typeName})(int){itemVar});\n");
			code.AppendF($"{indent}else\n");
			code.AppendF($"{indent}\treturn .Err(.TypeMismatch(\"/{errName}\", \"string or number\", {itemVar}.TypeName()));\n");
		case .JsonObject:
			code.AppendF($"{indent}if (!{itemVar}.IsObject()) return .Err(.TypeMismatch(\"/{errName}\", \"object\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}let _newItem = new {typeName}();\n");
			code.AppendF($"{indent}if (_newItem.JsonDeserialize({itemVar}) case .Err(let _err))\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tdelete _newItem;\n");
			code.AppendF($"{indent}\treturn .Err(_err);\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}{field.Name}.Add(_newItem);\n");
		case .List, .Dictionary, .SizedArray, .Unsupported:
			// FatalError is the only exit a comptime method has: it cannot return an error.
			Runtime.FatalError(scope $"BJSON cannot deserialize '{typeName}' as an element of list field '{field.Name}'. Supported: bool, integer, floating point, String, enum, [JsonObject] types, and types with [JsonConverter].");
		}
	}

	[Comptime]
	private static void EmitDictionaryDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		Type keyType, valueType;
		JsonCodeGenHelper.GetDictionaryTypes(fieldType, out keyType, out valueType);
		// Classify already said Dictionary, so missing key or value types are a generator fault.
		// Bailing would skip the field without a word, so it has to be fatal.
		if (keyType == null || valueType == null)
			Runtime.FatalError(scope $"BJSON found no key and value types for dictionary field '{field.Name}'.");

		// JSON object keys are always strings, so a non String key cannot round trip. A
		// comptime method cannot return an error, so this has to be fatal.
		if (keyType != typeof(String))
		{
			Runtime.FatalError(scope $"Dictionary field '{field.Name}' must have String keys for JSON serialization.");
		}

		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		code.AppendF($"{indent}if (!{jsonVar}.IsObject()) return .Err(.TypeMismatch(\"/{errName}\", \"object\", {jsonVar}.TypeName()));\n");
		code.AppendF($"{indent}let _{field.Name}Obj = {jsonVar}.AsObject().Value;\n");
		code.AppendF($"{indent}for (let _kv in _{field.Name}Obj)\n");
		code.AppendF($"{indent}{{\n");

		EmitDictionaryValueDeserialization(code, field, valueType, "_kv.key", "_kv.value", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
	}

	/// Emits the read of one dictionary entry into code, honouring a [JsonConverter] on the field
	/// or on the value type. Keys are copied into new Strings that the dictionary owns.
	/// A value type outside the supported set fails generation and names itself, matching what the
	/// serializer emitter does for the same value.
	[Comptime]
	private static void EmitDictionaryValueDeserialization(String code, FieldInfo field, Type valueType, StringView keyVar, StringView valueVar, StringView indent)
	{
		String typeName = scope .();
		valueType.GetFullName(typeName);
		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		switch (JsonCodeGenHelper.Classify(field, valueType))
		{
		case .Converter:
			{
				String converterTypeName = scope .();
				JsonCodeGenHelper.GetConverterType(field, valueType).GetFullName(converterTypeName);
				code.AppendF($"{indent}{{\n");
				code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
				code.AppendF($"{indent}\tdefer delete _converter;\n");
				code.AppendF($"{indent}\tif (_converter.ReadJson({valueVar}) case .Ok(let _convertedValue))\n");
				code.AppendF($"{indent}\t\t{field.Name}.Add(new String({keyVar}), _convertedValue);\n");
				code.AppendF($"{indent}\telse\n");
				code.AppendF($"{indent}\t\treturn .Err(.ConverterFailed(\"/{errName}\"));\n");
				code.AppendF($"{indent}}}\n");
			}
		case .Bool:
			code.AppendF($"{indent}if (!{valueVar}.IsBool()) return .Err(.TypeMismatch(\"/{errName}\", \"bool\", {valueVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), (bool){valueVar});\n");
		case .Integer, .Float:
			code.AppendF($"{indent}if (!{valueVar}.IsNumber()) return .Err(.TypeMismatch(\"/{errName}\", \"number\", {valueVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), ({typeName}){valueVar});\n");
		case .String:
			code.AppendF($"{indent}if (!{valueVar}.IsString()) return .Err(.TypeMismatch(\"/{errName}\", \"string\", {valueVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), new String((StringView){valueVar}));\n");
		case .Enum:
			code.AppendF($"{indent}if ({valueVar}.IsString())\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tif (Enum.Parse<{typeName}>((StringView){valueVar}) case .Ok(let _enumVal))\n");
			code.AppendF($"{indent}\t\t{field.Name}.Add(new String({keyVar}), _enumVal);\n");
			code.AppendF($"{indent}\telse\n");
			code.AppendF($"{indent}\t\treturn .Err(.InvalidEnumValue(\"/{errName}\", \"{typeName}\"));\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}else if ({valueVar}.IsNumber())\n");
			code.AppendF($"{indent}\t{field.Name}.Add(new String({keyVar}), ({typeName})(int){valueVar});\n");
			code.AppendF($"{indent}else\n");
			code.AppendF($"{indent}\treturn .Err(.TypeMismatch(\"/{errName}\", \"string or number\", {valueVar}.TypeName()));\n");
		case .JsonObject:
			code.AppendF($"{indent}if (!{valueVar}.IsObject()) return .Err(.TypeMismatch(\"/{errName}\", \"object\", {valueVar}.TypeName()));\n");
			code.AppendF($"{indent}let _newVal = new {typeName}();\n");
			code.AppendF($"{indent}if (_newVal.JsonDeserialize({valueVar}) case .Err(let _err))\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tdelete _newVal;\n");
			code.AppendF($"{indent}\treturn .Err(_err);\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}{field.Name}.Add(new String({keyVar}), _newVal);\n");
		case .List, .Dictionary, .SizedArray, .Unsupported:
			// FatalError is the only exit a comptime method has: it cannot return an error.
			Runtime.FatalError(scope $"BJSON cannot deserialize '{typeName}' as a value of dictionary field '{field.Name}'. Supported: bool, integer, floating point, String, enum, [JsonObject] types, and types with [JsonConverter].");
		}
	}

	[Comptime]
	private static void EmitSizedArrayDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		let elementType = fieldType.UnderlyingType;
		let sizedArrayType = fieldType as SizedArrayType;
		let arraySize = sizedArrayType != null ? sizedArrayType.ElementCount : 0;

		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		code.AppendF($"{indent}if (!{jsonVar}.IsArray()) return .Err(.TypeMismatch(\"/{errName}\", \"array\", {jsonVar}.TypeName()));\n");
		code.AppendF($"{indent}let _{field.Name}Arr = {jsonVar}.AsArray().Value;\n");
		code.AppendF($"{indent}let _arrLen = Math.Min(_{field.Name}Arr.Count, {arraySize});\n");
		code.AppendF($"{indent}for (int _i = 0; _i < _arrLen; _i++)\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tlet _item = _{field.Name}Arr[_i];\n");

		EmitSizedArrayItemDeserialization(code, field, elementType, "_item", "_i", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
	}

	/// Emits the read of one sized array element into code, honouring a [JsonConverter] on the
	/// field or on the element type.
	/// A String slot is written in place and allocated only when it is null, the same deal a
	/// String field gets: the owning type still has to free what ends up in the slot.
	/// A class element carrying [JsonObject] is rejected, because a fixed slot has no owner for
	/// the object a read would have to allocate; the serializer emitter rejects it too, so both
	/// sides describe the same field. Any other unsupported element type fails generation and
	/// names itself.
	[Comptime]
	private static void EmitSizedArrayItemDeserialization(String code, FieldInfo field, Type elementType, StringView itemVar, StringView indexVar, StringView indent)
	{
		String typeName = scope .();
		elementType.GetFullName(typeName);
		let errName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, errName);

		switch (JsonCodeGenHelper.Classify(field, elementType))
		{
		case .Converter:
			{
				String converterTypeName = scope .();
				JsonCodeGenHelper.GetConverterType(field, elementType).GetFullName(converterTypeName);
				code.AppendF($"{indent}{{\n");
				code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
				code.AppendF($"{indent}\tdefer delete _converter;\n");
				code.AppendF($"{indent}\tif (_converter.ReadJson({itemVar}) case .Ok(let _convertedValue))\n");
				code.AppendF($"{indent}\t\t{field.Name}[{indexVar}] = _convertedValue;\n");
				code.AppendF($"{indent}\telse\n");
				code.AppendF($"{indent}\t\treturn .Err(.ConverterFailed(\"/{errName}\"));\n");
				code.AppendF($"{indent}}}\n");
			}
		case .Bool:
			code.AppendF($"{indent}if (!{itemVar}.IsBool()) return .Err(.TypeMismatch(\"/{errName}\", \"bool\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}[{indexVar}] = (bool){itemVar};\n");
		case .Integer, .Float:
			code.AppendF($"{indent}if (!{itemVar}.IsNumber()) return .Err(.TypeMismatch(\"/{errName}\", \"number\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}{field.Name}[{indexVar}] = ({typeName}){itemVar};\n");
		case .String:
			code.AppendF($"{indent}if (!{itemVar}.IsString()) return .Err(.TypeMismatch(\"/{errName}\", \"string\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}if ({field.Name}[{indexVar}] == null) {field.Name}[{indexVar}] = new String();\n");
			code.AppendF($"{indent}{field.Name}[{indexVar}].Set((StringView){itemVar});\n");
		case .Enum:
			code.AppendF($"{indent}if ({itemVar}.IsString())\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tif (Enum.Parse<{typeName}>((StringView){itemVar}) case .Ok(let _enumVal))\n");
			code.AppendF($"{indent}\t\t{field.Name}[{indexVar}] = _enumVal;\n");
			code.AppendF($"{indent}\telse\n");
			code.AppendF($"{indent}\t\treturn .Err(.InvalidEnumValue(\"/{errName}\", \"{typeName}\"));\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}else if ({itemVar}.IsNumber())\n");
			code.AppendF($"{indent}\t{field.Name}[{indexVar}] = ({typeName})(int){itemVar};\n");
			code.AppendF($"{indent}else\n");
			code.AppendF($"{indent}\treturn .Err(.TypeMismatch(\"/{errName}\", \"string or number\", {itemVar}.TypeName()));\n");
		case .JsonObject:
			if (elementType.IsObject)
			{
				Runtime.FatalError(scope $"Sized array field '{field.Name}' has class elements of type '{typeName}', which BJSON cannot read back into fixed slots. Use List<{typeName}> instead.");
			}

			code.AppendF($"{indent}if (!{itemVar}.IsObject()) return .Err(.TypeMismatch(\"/{errName}\", \"object\", {itemVar}.TypeName()));\n");
			code.AppendF($"{indent}Try!({field.Name}[{indexVar}].JsonDeserialize({itemVar}));\n");
		case .List, .Dictionary, .SizedArray, .Unsupported:
			// FatalError is the only exit a comptime method has: it cannot return an error.
			Runtime.FatalError(scope $"BJSON cannot deserialize '{typeName}' as an element of sized array field '{field.Name}'. Supported: bool, integer, floating point, String, enum, [JsonObject] structs, and types with [JsonConverter].");
		}
	}
}
