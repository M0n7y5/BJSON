using System;
using System.Reflection;
using BJSON.Enums;
using BJSON.Attributes;

namespace BJSON.CodeGen;

/// Handles JSON serialization code generation at compile time.
public class JsonSerializerCodeGen
{
	[Comptime]
	public static void EmitSerializeMethod(Type type)
	{
		let code = scope String();

		bool needsNewKeyword = type.BaseType != null && type.BaseType != typeof(Object)
			&& type.BaseType.HasCustomAttribute<JsonObjectAttribute>();

		let newKeyword = needsNewKeyword ? "new " : "";

		// Generate the simple overload that delegates to the options version
		code.AppendF($"""
			public {newKeyword}Result<void> JsonSerialize(System.IO.Stream stream)
			{{
				return JsonSerialize(stream, .());
			}}

			public {newKeyword}Result<void> JsonSerialize(System.IO.Stream stream, BJSON.JsonWriterOptions _options)
			{{
				int _depth = 0;
				Try!(BJSON.JsonWriter.WriteChar(stream, '{{'));

			""");

		EmitAllFieldsWithOptions(code, type);

		code.Append("""
				if (_options.Indented && !_firstField)
				{
					Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine));
				}
				Try!(BJSON.JsonWriter.WriteChar(stream, '}'));
				return .Ok;
			}\n
			""");

		Compiler.EmitTypeBody(type, code);
	}

	[Comptime]
	private static void EmitAllFieldsWithOptions(String code, Type type)
	{
		code.Append("\t\tbool _firstField = true;\n");

		if (type.BaseType != null && type.BaseType != typeof(Object))
		{
			EmitAllFieldsWithOptionsRecursive(code, type.BaseType);
		}

		for (let field in type.GetFields())
		{
			if (field.DeclaringType != type)
				continue;

			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			EmitFieldSerializationWithOptions(code, field, type);
		}
	}

	[Comptime]
	private static void EmitAllFieldsWithOptionsRecursive(String code, Type type)
	{
		if (type.BaseType != null && type.BaseType != typeof(Object))
		{
			EmitAllFieldsWithOptionsRecursive(code, type.BaseType);
		}

		for (let field in type.GetFields())
		{
			if (field.DeclaringType != type)
				continue;

			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			EmitFieldSerializationWithOptions(code, field, type);
		}
	}

	[Comptime]
	private static void EmitFieldSerializationWithOptions(String code, FieldInfo field, Type ownerType)
	{
		let jsonName = scope String();
		JsonCodeGenHelper.GetJsonLiteralName(field, jsonName);

		var fieldType = field.FieldType;
		let isNullable = fieldType.IsNullable;

		if (isNullable)
			fieldType = JsonCodeGenHelper.UnwrapNullable(fieldType);

		if (let ignoreAttr = field.GetCustomAttribute<JsonIgnoreAttribute>())
		{
			if (ignoreAttr.Condition == .WhenWritingNull && (isNullable || fieldType.IsObject))
			{
				let presence = isNullable ? scope $"{field.Name}.HasValue" : scope $"{field.Name} != null";
				code.AppendF($"\t\tif ({presence})\n");
				code.Append("\t\t{\n");
				EmitFieldValueSerializationWithOptions(code, field, fieldType, jsonName, "\t\t\t", true, isNullable);
				code.Append("\t\t}\n");
				return;
			}
			else if (ignoreAttr.Condition == .WhenWritingDefault)
			{
				code.AppendF($"\t\tif ({field.Name} != default)\n");
				code.Append("\t\t{\n");
				EmitFieldValueSerializationWithOptions(code, field, fieldType, jsonName, "\t\t\t", true, false);
				code.Append("\t\t}\n");
				return;
			}
		}

		if (isNullable)
		{
			code.AppendF($"\t\tif ({field.Name}.HasValue)\n");
			code.Append("\t\t{\n");
			EmitFieldValueSerializationWithOptions(code, field, fieldType, jsonName, "\t\t\t", true, isNullable);
			code.Append("\t\t}\n");
		}
		else
		{
			EmitFieldValueSerializationWithOptions(code, field, fieldType, jsonName, "\t\t", true, false);
		}
	}

	[Comptime]
	private static void EmitFieldValueSerializationWithOptions(String code, FieldInfo field, Type fieldType, StringView jsonName, StringView indent, bool handleComma, bool isNullable)
	{
		if (handleComma)
		{
			code.AppendF($"{indent}if (!_firstField) Try!(BJSON.JsonWriter.WriteChar(stream, ','));\n");
			code.AppendF($"{indent}_firstField = false;\n");
			code.AppendF($"{indent}if (_options.Indented) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _i = 0; _i <= _depth; _i++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");
		}

		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteRaw(stream, \"{jsonName}\"));\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteRaw(stream, _options.Indented ? \"\\\": \" : \"\\\":\"));\n");

		let fieldExpr = isNullable ? scope $"{field.Name}.Value" : scope $"{field.Name}";

		if (let converterAttr = field.GetCustomAttribute<JsonConverterAttribute>())
		{
			String converterTypeName = scope .();
			converterAttr.ConverterType.GetFullName(converterTypeName);
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
			code.AppendF($"{indent}\tdefer delete _converter;\n");
			code.AppendF($"{indent}\tTry!(_converter.WriteJson(stream, {fieldExpr}));\n");
			code.AppendF($"{indent}}}\n");
			return;
		}

		let isReference = fieldType.IsObject && !isNullable;
		var bodyIndent = scope String(indent);

		if (isReference)
		{
			code.AppendF($"{indent}if ({fieldExpr} == null)\n");
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteRaw(stream, \"null\"));\n");
			code.AppendF($"{indent}}}\n");
			code.AppendF($"{indent}else\n");
			code.AppendF($"{indent}{{\n");
			bodyIndent.Append('\t');
		}

		if (fieldType == typeof(bool))
		{
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteBool(stream, {fieldExpr}));\n");
		}
		else if (fieldType.IsInteger)
		{
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteInt(stream, {fieldExpr}));\n");
		}
		else if (fieldType.IsFloatingPoint)
		{
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteFloat(stream, {fieldExpr}));\n");
		}
		else if (fieldType == typeof(String))
		{
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteString(stream, {fieldExpr}));\n");
		}
		else if (fieldType.IsEnum)
		{
			bool useNumber = false;

			if (let attr = field.GetCustomAttribute<JsonNumberHandlingAttribute>())
			{
				useNumber = attr.Handling == .AsNumber;
			}
			else if (let typeAttr = fieldType.GetCustomAttribute<JsonNumberHandlingAttribute>())
			{
				useNumber = typeAttr.Handling == .AsNumber;
			}

			if (useNumber)
			{
				code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteInt(stream, (int){fieldExpr}));\n");
			}
			else
			{
				code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
				code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteRaw(stream, {fieldExpr}.ToString(.. scope .())));\n");
				code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
			}
		}
		else if (JsonCodeGenHelper.IsList(fieldType))
		{
			EmitListSerializationWithOptions(code, field, fieldType, bodyIndent);
		}
		else if (JsonCodeGenHelper.IsDictionary(fieldType))
		{
			EmitDictionarySerializationWithOptions(code, field, fieldType, bodyIndent);
		}
		else if (fieldType.IsSizedArray)
		{
			EmitSizedArraySerializationWithOptions(code, field, fieldType, bodyIndent);
		}
		else if (fieldType.IsObject || fieldType.IsStruct)
		{
			code.AppendF($"{bodyIndent}Try!({fieldExpr}.JsonSerialize(stream, _options));\n");
		}

		if (isReference)
		{
			code.AppendF($"{indent}}}\n");
		}
	}

	[Comptime]
	private static void EmitListSerializationWithOptions(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		let elementType = JsonCodeGenHelper.GetElementType(fieldType);
		if (elementType == null)
			return;

		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '['));\n");
		code.AppendF($"{indent}_depth++;\n");
		code.AppendF($"{indent}bool _first{field.Name} = true;\n");
		code.AppendF($"{indent}for (let _item in {field.Name})\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (!_first{field.Name}) Try!(BJSON.JsonWriter.WriteChar(stream, ','));\n");
		code.AppendF($"{indent}\t_first{field.Name} = false;\n");
		code.AppendF($"{indent}\tif (_options.Indented) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _i = 0; _i < _depth; _i++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");

		EmitValueSerializationWithOptions(code, elementType, "_item", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}_depth--;\n");
		code.AppendF($"{indent}if (_options.Indented && !_first{field.Name}) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _i = 0; _i < _depth; _i++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, ']'));\n");
	}

	[Comptime]
	private static void EmitDictionarySerializationWithOptions(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		Type keyType, valueType;
		JsonCodeGenHelper.GetDictionaryTypes(fieldType, out keyType, out valueType);
		if (keyType == null || valueType == null)
			return;

		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '{{'));\n");
		code.AppendF($"{indent}_depth++;\n");
		code.AppendF($"{indent}bool _first{field.Name} = true;\n");
		code.AppendF($"{indent}for (let _kv in {field.Name})\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (!_first{field.Name}) Try!(BJSON.JsonWriter.WriteChar(stream, ','));\n");
		code.AppendF($"{indent}\t_first{field.Name} = false;\n");
		code.AppendF($"{indent}\tif (_options.Indented) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _i = 0; _i < _depth; _i++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");
		code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
		code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteEscaped(stream, _kv.key));\n");
		code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteRaw(stream, _options.Indented ? \"\\\": \" : \"\\\":\"));\n");

		EmitValueSerializationWithOptions(code, valueType, "_kv.value", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}_depth--;\n");
		code.AppendF($"{indent}if (_options.Indented && !_first{field.Name}) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _i = 0; _i < _depth; _i++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '}}'));\n");
	}

	[Comptime]
	private static void EmitSizedArraySerializationWithOptions(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		let elementType = fieldType.UnderlyingType;
		let sizedArrayType = fieldType as SizedArrayType;
		let arraySize = sizedArrayType != null ? sizedArrayType.ElementCount : 0;

		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '['));\n");
		code.AppendF($"{indent}_depth++;\n");
		code.AppendF($"{indent}for (int _i = 0; _i < {arraySize}; _i++)\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (_i > 0) Try!(BJSON.JsonWriter.WriteChar(stream, ','));\n");
		code.AppendF($"{indent}\tif (_options.Indented) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _j = 0; _j < _depth; _j++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");

		EmitValueSerializationWithOptions(code, elementType, scope $"{field.Name}[_i]", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}_depth--;\n");
		code.AppendF($"{indent}if (_options.Indented && {arraySize} > 0) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _j = 0; _j < _depth; _j++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, ']'));\n");
	}

	[Comptime]
	private static void EmitValueSerializationWithOptions(String code, Type valueType, StringView valueExpr, StringView indent)
	{
		if (let converterAttr = valueType.GetCustomAttribute<JsonConverterAttribute>())
		{
			String converterTypeName = scope .();
			converterAttr.ConverterType.GetFullName(converterTypeName);
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
			code.AppendF($"{indent}\tdefer delete _converter;\n");
			code.AppendF($"{indent}\tTry!(_converter.WriteJson(stream, {valueExpr}));\n");
			code.AppendF($"{indent}}}\n");
			return;
		}

		if (valueType == typeof(bool))
		{
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteBool(stream, {valueExpr}));\n");
		}
		else if (valueType.IsInteger)
		{
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteInt(stream, {valueExpr}));\n");
		}
		else if (valueType.IsFloatingPoint)
		{
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteFloat(stream, {valueExpr}));\n");
		}
		else if (valueType == typeof(String))
		{
			code.AppendF($"{indent}if ({valueExpr} == null)\n");
			code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteRaw(stream, \"null\"));\n");
			code.AppendF($"{indent}else\n");
			code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteString(stream, {valueExpr}));\n");
		}
		else if (valueType.IsEnum)
		{
			bool useNumber = false;
			if (let attr = valueType.GetCustomAttribute<JsonNumberHandlingAttribute>())
			{
				useNumber = attr.Handling == .AsNumber;
			}
			
			if (useNumber)
			{
				code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteInt(stream, (int){valueExpr}));\n");
			}
			else
			{
				code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
				code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteRaw(stream, {valueExpr}.ToString(.. scope .())));\n");
				code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
			}
		}
		else if (valueType.HasCustomAttribute<JsonObjectAttribute>())
		{
			if (valueType.IsObject)
			{
				code.AppendF($"{indent}if ({valueExpr} == null)\n");
				code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteRaw(stream, \"null\"));\n");
				code.AppendF($"{indent}else\n");
				code.AppendF($"{indent}\tTry!({valueExpr}.JsonSerialize(stream, _options));\n");
			}
			else
			{
				code.AppendF($"{indent}Try!({valueExpr}.JsonSerialize(stream, _options));\n");
			}
		}
		else
		{
			let typeName = scope String();
			valueType.GetFullName(typeName);
			Runtime.FatalError(scope $"BJSON cannot serialize '{typeName}' as a collection element or value. Supported: bool, integer, floating point, String, enum, and [JsonObject] types.");
		}
	}
}
