using System;
using System.Reflection;
using System.Collections;
using BJSON.Attributes;
using BJSON.Enums;

namespace BJSON.CodeGen;

/// Handles JSON deserialization code generation at compile time.
public class JsonDeserializerCodeGen
{
	[Comptime]
	public static void EmitDeserializeMethod(Type type)
	{
		let code = scope String();

		bool needsNewKeyword = type.BaseType != null && type.BaseType != typeof(Object)
			&& type.BaseType.HasCustomAttribute<JsonObjectAttribute>();

		let newKeyword = needsNewKeyword ? "new " : "";

		code.AppendF($"""
			public {newKeyword}Result<void> JsonDeserialize(BJSON.Models.JsonValue value)
			{{
				if (!value.IsObject())
					return .Err;
				
				let root = value.AsObject().Value;

			""");

		// Process all fields including inherited ones
		EmitAllFields(code, type);

		code.Append("""
				return .Ok;
			}\n
			""");

		Compiler.EmitTypeBody(type, code);
	}

	[Comptime]
	private static void EmitAllFields(String code, Type type)
	{
		if (type.BaseType != null && type.BaseType != typeof(Object))
		{
			EmitAllFields(code, type.BaseType);
		}

		for (let field in type.GetFields())
		{
			if (field.DeclaringType != type)
				continue;

			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			EmitFieldDeserialization(code, field, type);
		}
	}

	[Comptime]
	private static void EmitFieldDeserialization(String code, FieldInfo field, Type ownerType)
	{
		let jsonName = scope String();
		JsonCodeGenHelper.GetJsonPropertyName(field, jsonName);

		var fieldType = field.FieldType;
		let isNullable = fieldType.IsNullable;
		let isRequired = field.HasCustomAttribute<JsonRequiredAttribute>();
		let isOptional = field.HasCustomAttribute<JsonOptionalAttribute>();

		if (isNullable)
			fieldType = JsonCodeGenHelper.UnwrapNullable(fieldType);

		// Get the default behavior from the owner's JsonObjectAttribute
		JsonFieldDefaultBehavior defaultBehavior = .Optional;
		if (let objAttr = ownerType.GetCustomAttribute<JsonObjectAttribute>())
		{
			defaultBehavior = objAttr.DefaultBehavior;
		}

		// Determine if field is required based on default behavior and attributes
		bool isFieldRequired;
		if (defaultBehavior == .Required)
		{
			// Default is required, unless marked [JsonOptional]
			isFieldRequired = !isOptional;
		}
		else
		{
			// Default is optional, unless marked [JsonRequired]
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
			Runtime.FatalError(scope $"Sized arrays of String are not supported. Use List<String> instead for field '{field.Name}'.");
		}
	}
}
