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

		code.AppendF($"""
			public {newKeyword}Result<void> JsonSerialize(System.IO.Stream stream)
			{{
				stream.Write<char8>('{{');
				bool _firstField = true;

			""");

		EmitAllFields(code, type);

		code.Append("""
				stream.Write<char8>('}');
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

			EmitFieldSerialization(code, field, type);
		}
	}

	[Comptime]
	private static void EmitFieldSerialization(String code, FieldInfo field, Type ownerType)
	{
		let jsonName = scope String();
		JsonCodeGenHelper.GetJsonPropertyName(field, jsonName);

		var fieldType = field.FieldType;
		let isNullable = fieldType.IsNullable;

		if (isNullable)
			fieldType = JsonCodeGenHelper.UnwrapNullable(fieldType);

		if (let ignoreAttr = field.GetCustomAttribute<JsonIgnoreAttribute>())
		{
			if (ignoreAttr.Condition == .WhenWritingNull && isNullable)
			{
				code.AppendF($"\tif ({field.Name}.HasValue)\n");
				code.Append("\t{\n");
				EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t\t", true, isNullable);
				code.Append("\t}\n");
				return;
			}
			else if (ignoreAttr.Condition == .WhenWritingDefault)
			{
				code.AppendF($"\tif ({field.Name} != default)\n");
				code.Append("\t{\n");
				EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t\t", true, false);
				code.Append("\t}\n");
				return;
			}
		}

		if (isNullable)
		{
			code.AppendF($"\tif ({field.Name}.HasValue)\n");
			code.Append("\t{\n");
			EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t\t", true, isNullable);
			code.Append("\t}\n");
		}
		else
		{
			EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t", true, false);
		}
	}

	[Comptime]
	private static void EmitFieldValueSerialization(String code, FieldInfo field, Type fieldType, StringView jsonName, StringView indent, bool handleComma, bool isNullable)
	{
		if (handleComma)
		{
			code.AppendF($"{indent}if (!_firstField) stream.Write<char8>(',');\n");
			code.AppendF($"{indent}_firstField = false;\n");
		}

		code.AppendF($"{indent}stream.Write<char8>('\"');\n");
		code.AppendF($"{indent}stream.WriteStrUnsized(\"{jsonName}\");\n");
		code.AppendF($"{indent}stream.WriteStrUnsized(\"\\\":\");\n");

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

		if (fieldType == typeof(bool))
		{
			code.AppendF($"{indent}BJSON.JsonWriter.WriteBool(stream, {fieldExpr});\n");
		}
		else if (fieldType.IsInteger)
		{
			code.AppendF($"{indent}BJSON.JsonWriter.WriteInt(stream, {fieldExpr});\n");
		}
		else if (fieldType.IsFloatingPoint)
		{
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteFloat(stream, {fieldExpr}));\n");
		}
		else if (fieldType == typeof(String))
		{
			code.AppendF($"{indent}BJSON.JsonWriter.WriteString(stream, {fieldExpr});\n");
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
				code.AppendF($"{indent}BJSON.JsonWriter.WriteInt(stream, (int){fieldExpr});\n");
			}
			else
			{
				code.AppendF($"{indent}stream.Write<char8>('\"');\n");
				code.AppendF($"{indent}stream.WriteStrUnsized({fieldExpr}.ToString(.. scope .()));\n");
				code.AppendF($"{indent}stream.Write<char8>('\"');\n");
			}
		}
		else if (JsonCodeGenHelper.IsList(fieldType))
		{
			EmitListSerialization(code, field, fieldType, indent);
		}
		else if (JsonCodeGenHelper.IsDictionary(fieldType))
		{
			EmitDictionarySerialization(code, field, fieldType, indent);
		}
		else if (fieldType.IsSizedArray)
		{
			EmitSizedArraySerialization(code, field, fieldType, indent);
		}
		else if (fieldType.IsObject || fieldType.IsStruct)
		{
			code.AppendF($"{indent}Try!({fieldExpr}.JsonSerialize(stream));\n");
		}
	}

	[Comptime]
	private static void EmitListSerialization(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		let elementType = JsonCodeGenHelper.GetElementType(fieldType);
		if (elementType == null)
			return;

		code.AppendF($"{indent}stream.Write<char8>('[');\n");
		code.AppendF($"{indent}bool _first{field.Name} = true;\n");
		code.AppendF($"{indent}for (let _item in {field.Name})\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (!_first{field.Name}) stream.Write<char8>(',');\n");
		code.AppendF($"{indent}\t_first{field.Name} = false;\n");

		EmitValueSerialization(code, elementType, "_item", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}stream.Write<char8>(']');\n");
	}

	[Comptime]
	private static void EmitDictionarySerialization(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		Type keyType, valueType;
		JsonCodeGenHelper.GetDictionaryTypes(fieldType, out keyType, out valueType);
		if (keyType == null || valueType == null)
			return;

		code.AppendF($"{indent}stream.Write<char8>('{{');\n");
		code.AppendF($"{indent}bool _first{field.Name} = true;\n");
		code.AppendF($"{indent}for (let _kv in {field.Name})\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (!_first{field.Name}) stream.Write<char8>(',');\n");
		code.AppendF($"{indent}\t_first{field.Name} = false;\n");
		code.AppendF($"{indent}\tstream.Write<char8>('\"');\n");
		code.AppendF($"{indent}\tBJSON.JsonWriter.WriteEscaped(stream, _kv.key);\n");
		code.AppendF($"{indent}\tstream.WriteStrUnsized(\"\\\":\");\n");

		EmitValueSerialization(code, valueType, "_kv.value", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}stream.Write<char8>('}}');\n");
	}

	[Comptime]
	private static void EmitSizedArraySerialization(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		let elementType = fieldType.UnderlyingType;
		let sizedArrayType = fieldType as SizedArrayType;
		let arraySize = sizedArrayType != null ? sizedArrayType.ElementCount : 0;

		code.AppendF($"{indent}stream.Write<char8>('[');\n");
		code.AppendF($"{indent}for (int _i = 0; _i < {arraySize}; _i++)\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (_i > 0) stream.Write<char8>(',');\n");

		EmitValueSerialization(code, elementType, scope $"{field.Name}[_i]", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}stream.Write<char8>(']');\n");
	}

	[Comptime]
	private static void EmitValueSerialization(String code, Type valueType, StringView valueExpr, StringView indent)
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
			code.AppendF($"{indent}BJSON.JsonWriter.WriteBool(stream, {valueExpr});\n");
		}
		else if (valueType.IsInteger)
		{
			code.AppendF($"{indent}BJSON.JsonWriter.WriteInt(stream, {valueExpr});\n");
		}
		else if (valueType.IsFloatingPoint)
		{
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteFloat(stream, {valueExpr}));\n");
		}
		else if (valueType == typeof(String))
		{
			code.AppendF($"{indent}BJSON.JsonWriter.WriteString(stream, {valueExpr});\n");
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
				code.AppendF($"{indent}BJSON.JsonWriter.WriteInt(stream, (int){valueExpr});\n");
			}
			else
			{
				code.AppendF($"{indent}stream.Write<char8>('\"');\n");
				code.AppendF($"{indent}stream.WriteStrUnsized({valueExpr}.ToString(.. scope .()));\n");
				code.AppendF($"{indent}stream.Write<char8>('\"');\n");
			}
		}
		else if (valueType.HasCustomAttribute<JsonObjectAttribute>())
		{
			code.AppendF($"{indent}Try!({valueExpr}.JsonSerialize(stream));\n");
		}
	}
}
