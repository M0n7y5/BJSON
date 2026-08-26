using System;
using System.Reflection;
using BJSON.Enums;
using BJSON.Attributes;

namespace BJSON.CodeGen;

/// Handles JSON serialization code generation at compile time.
/// Every method here only appends Beef source text that JsonObjectAttribute.ApplyToType
/// hands to the compiler; nothing in this class runs at runtime.
public class JsonSerializerCodeGen
{
	/// Emits both JsonSerialize overloads into type: the stream only overload that delegates
	/// to the JsonWriterOptions overload, and that overload, which writes the object braces,
	/// one property per included field, and then one property per entry of the
	/// [JsonExtensionData] field when the type has one.
	/// @param type The [JsonObject] type receiving the method bodies.
	[Comptime]
	public static void EmitSerializeMethod(Type type)
	{
		let code = scope String();

		let newKeyword = JsonCodeGenHelper.GetNewKeyword(type);

		// The emitted text is parsed in the target type's context, so every name is fully
		// qualified; the target file is not required to have BJSON using directives.
		// Braces of the emitted body are doubled: inside an interpolated template {{ and }}
		// collapse to one literal brace, and a lone { would open an interpolation hole.
		code.AppendF($"""
			public {newKeyword}Result<void, BJSON.Enums.JsonSerializationError> JsonSerialize(System.IO.Stream stream)
			{{
				return JsonSerialize(stream, .());
			}}

			public {newKeyword}Result<void, BJSON.Enums.JsonSerializationError> JsonSerialize(System.IO.Stream stream, BJSON.JsonWriterOptions _options)
			{{
				int _depth = 0;
				bool _firstField = true;
				Try!(BJSON.JsonWriter.WriteChar(stream, '{{'));

			""");

		EmitAllFieldsWithOptions(code, type);
		EmitExtensionDataSerializationWithOptions(code, type);

		// Append, not AppendF: this tail is not interpolated, so its braces stay single.
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

	/// Emits the field writes for type and for every base type up to Object, base fields first.
	/// The extension data field is not one of them: it carries no property name, so its entries
	/// are written by EmitExtensionDataSerializationWithOptions after every declared property.
	[Comptime]
	private static void EmitAllFieldsWithOptions(String code, Type type)
	{
		if (type.BaseType != null && type.BaseType != typeof(Object))
		{
			EmitAllFieldsWithOptions(code, type.BaseType);
		}

		for (let field in type.GetFields())
		{
			// GetFields() also returns inherited fields, down to inaccessible System.Object
			// internals. Base types are walked separately above, so only own fields pass.
			if (field.DeclaringType != type)
				continue;

			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			if (JsonCodeGenHelper.IsExtensionDataField(field))
				continue;

			EmitFieldSerializationWithOptions(code, field, type);
		}
	}

	/// Emits the write of every entry of the [JsonExtensionData] field, when type has one.
	/// GetFields() reports inherited fields too, so an extension data field a base type declares
	/// is written here as well; ValidateFields already rejected a second one, so this loop emits
	/// at most one walk.
	/// An entry whose key names a declared property is dropped: the field already wrote that
	/// property, and JSON has no room for it twice.
	/// @param code Receives the emitted source.
	/// @param type The type being emitted, which also supplies the known property names.
	[Comptime]
	private static void EmitExtensionDataSerializationWithOptions(String code, Type type)
	{
		for (let field in type.GetFields())
		{
			if (!JsonCodeGenHelper.ShouldSerializeField(field, type))
				continue;

			if (!JsonCodeGenHelper.IsExtensionDataField(field))
				continue;

			Type keyType, valueType;
			JsonCodeGenHelper.GetDictionaryTypes(field.FieldType, out keyType, out valueType);
			// ValidateExtensionDataField already required Dictionary<String, V>, so missing key
			// or value types are a generator fault. Bailing would drop every captured property
			// without a word, so it has to be fatal.
			if (keyType == null || valueType == null)
				Runtime.FatalError(scope $"BJSON found no key and value types for extension data field '{field.Name}'.");

			// A dictionary that was never allocated contributes no properties. Every other
			// reference this emitter writes is tested the same way before it is read.
			code.AppendF($"\t\tif ({field.Name} != null)\n");
			code.Append("\t\t{\n");
			code.AppendF($"\t\t\tfor (let _kv in {field.Name})\n");
			code.Append("\t\t\t{\n");

			let knownNameCheck = scope String();
			if (JsonCodeGenHelper.AppendKnownJsonNameCheck(knownNameCheck, type, "_kv.key"))
			{
				code.AppendF($"\t\t\t\tif ({knownNameCheck})\n");
				code.Append("\t\t\t\t\tcontinue;\n");
			}

			// The same comma, depth and separator protocol every declared property follows, so a
			// captured entry is indistinguishable from a field in the output.
			code.Append("\t\t\t\tif (!_firstField) Try!(BJSON.JsonWriter.WriteChar(stream, ','));\n");
			code.Append("\t\t\t\t_firstField = false;\n");
			code.Append("\t\t\t\tif (_options.Indented) { Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _i = 0; _i <= _depth; _i++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }\n");
			// The key is runtime text, unlike a declared property name, so it is escaped as it
			// is written instead of at generation time.
			code.Append("\t\t\t\tTry!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
			code.Append("\t\t\t\tTry!(BJSON.JsonWriter.WriteEscaped(stream, _kv.key));\n");
			code.Append("\t\t\t\tTry!(BJSON.JsonWriter.WriteRaw(stream, _options.Indented ? \"\\\": \" : \"\\\":\"));\n");

			EmitValueSerializationWithOptions(code, field, valueType, "_kv.value", "\t\t\t\t");

			code.Append("\t\t\t}\n");
			code.Append("\t\t}\n");
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

		// jsonName came from GetJsonLiteralName, already escaped for JSON output and then for
		// this source literal, which is why the key goes out with WriteRaw and the emitted
		// code never escapes it at runtime.
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '\"'));\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteRaw(stream, \"{jsonName}\"));\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteRaw(stream, _options.Indented ? \"\\\": \" : \"\\\":\"));\n");

		let fieldExpr = isNullable ? scope $"{field.Name}.Value" : scope $"{field.Name}";

		let kind = JsonCodeGenHelper.Classify(field, fieldType);

		if (kind == .Converter)
		{
			// A converter owns the whole field, a collection field included, so it runs before
			// the null handling the other kinds get.
			String converterTypeName = scope .();
			JsonCodeGenHelper.GetConverterType(field, fieldType).GetFullName(converterTypeName);
			code.AppendF($"{indent}{{\n");
			code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
			code.AppendF($"{indent}\tdefer delete _converter;\n");
			// WriteJson returns a bare Result<void>, so Try! has no error to widen: the refusal
			// becomes ConverterFailed here.
			code.AppendF($"{indent}\tif (_converter.WriteJson(stream, {fieldExpr}) case .Err) return .Err(.ConverterFailed);\n");
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

		switch (kind)
		{
		case .Bool:
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteBool(stream, {fieldExpr}));\n");
		case .Integer:
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteInt(stream, {fieldExpr}));\n");
		case .Float:
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteFloat(stream, {fieldExpr}));\n");
		case .String:
			code.AppendF($"{bodyIndent}Try!(BJSON.JsonWriter.WriteString(stream, {fieldExpr}));\n");
		case .Enum:
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
		case .List:
			EmitListSerializationWithOptions(code, field, fieldType, bodyIndent);
		case .Dictionary:
			EmitDictionarySerializationWithOptions(code, field, fieldType, bodyIndent);
		case .SizedArray:
			EmitSizedArraySerializationWithOptions(code, field, fieldType, bodyIndent);
		case .JsonObject:
			code.AppendF($"{bodyIndent}Try!({fieldExpr}.JsonSerialize(stream, _options));\n");
		case .Converter, .Unsupported:
			// Converter left through the early return above, and ValidateFields already
			// rejected Unsupported, so reaching here means Classify grew a kind this ladder
			// does not write. FatalError is the only exit a comptime method has.
			let typeName = scope String();
			fieldType.GetFullName(typeName);
			Runtime.FatalError(scope $"BJSON cannot serialize field '{field.Name}' of type '{typeName}'.");
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
		// Classify already said List, so a missing element type is a generator fault. Bailing
		// would leave a key with no value in the JSON, so it has to be fatal.
		if (elementType == null)
			Runtime.FatalError(scope $"BJSON found no element type for list field '{field.Name}'.");

		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '['));\n");
		code.AppendF($"{indent}_depth++;\n");
		code.AppendF($"{indent}bool _first{field.Name} = true;\n");
		code.AppendF($"{indent}for (let _item in {field.Name})\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (!_first{field.Name}) Try!(BJSON.JsonWriter.WriteChar(stream, ','));\n");
		code.AppendF($"{indent}\t_first{field.Name} = false;\n");
		code.AppendF($"{indent}\tif (_options.Indented) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _i = 0; _i < _depth; _i++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");

		EmitValueSerializationWithOptions(code, field, elementType, "_item", scope $"{indent}\t");

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
		// Classify already said Dictionary, so missing key or value types are a generator fault.
		// Bailing would leave a key with no value in the JSON, so it has to be fatal.
		if (keyType == null || valueType == null)
			Runtime.FatalError(scope $"BJSON found no key and value types for dictionary field '{field.Name}'.");

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

		EmitValueSerializationWithOptions(code, field, valueType, "_kv.value", scope $"{indent}\t");

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

		// A class element carrying [JsonObject] writes fine and can never be read back: a fixed
		// slot has no owner for the object the reader would have to allocate. Both emitters
		// reject it, so the two sides describe the same field.
		if (elementType.IsObject && elementType.HasCustomAttribute<JsonObjectAttribute>())
		{
			let elementTypeName = scope String();
			elementType.GetFullName(elementTypeName);
			Runtime.FatalError(scope $"Sized array field '{field.Name}' has class elements of type '{elementTypeName}', which BJSON cannot read back into fixed slots. Use List<{elementTypeName}> instead.");
		}

		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, '['));\n");
		code.AppendF($"{indent}_depth++;\n");
		code.AppendF($"{indent}for (int _i = 0; _i < {arraySize}; _i++)\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (_i > 0) Try!(BJSON.JsonWriter.WriteChar(stream, ','));\n");
		code.AppendF($"{indent}\tif (_options.Indented) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _j = 0; _j < _depth; _j++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");

		EmitValueSerializationWithOptions(code, field, elementType, scope $"{field.Name}[_i]", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}_depth--;\n");
		code.AppendF($"{indent}if (_options.Indented && {arraySize} > 0) {{ Try!(BJSON.JsonWriter.WriteRaw(stream, _options.NewLine)); for (int _j = 0; _j < _depth; _j++) Try!(BJSON.JsonWriter.WriteRaw(stream, _options.IndentString)); }}\n");
		code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteChar(stream, ']'));\n");
	}

	/// Emits the write of one list element, dictionary value or sized array element into code.
	/// The kind comes from JsonCodeGenHelper.Classify, the same classification the field path and
	/// the deserializer emitter use, so a type outside the supported set fails generation and
	/// names itself instead of leaving a value shaped hole in the JSON stream.
	/// @param code Receives the emitted source.
	/// @param field The field being written. Only its [JsonConverter] lookup and its name in a
	/// generation error come from it; a converter on the field itself took the whole collection
	/// before this call.
	/// @param valueType The element or value type being written.
	/// @param valueExpr The emitted expression that yields the value.
	/// @param indent Leading whitespace for the emitted lines.
	[Comptime]
	private static void EmitValueSerializationWithOptions(String code, FieldInfo field, Type valueType, StringView valueExpr, StringView indent)
	{
		switch (JsonCodeGenHelper.Classify(field, valueType))
		{
		case .Converter:
			{
				String converterTypeName = scope .();
				JsonCodeGenHelper.GetConverterType(field, valueType).GetFullName(converterTypeName);
				code.AppendF($"{indent}{{\n");
				code.AppendF($"{indent}\tlet _converter = new {converterTypeName}();\n");
				code.AppendF($"{indent}\tdefer delete _converter;\n");
				code.AppendF($"{indent}\tif (_converter.WriteJson(stream, {valueExpr}) case .Err) return .Err(.ConverterFailed);\n");
				code.AppendF($"{indent}}}\n");
			}
		case .Bool:
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteBool(stream, {valueExpr}));\n");
		case .Integer:
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteInt(stream, {valueExpr}));\n");
		case .Float:
			code.AppendF($"{indent}Try!(BJSON.JsonWriter.WriteFloat(stream, {valueExpr}));\n");
		case .String:
			code.AppendF($"{indent}if ({valueExpr} == null)\n");
			code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteRaw(stream, \"null\"));\n");
			code.AppendF($"{indent}else\n");
			code.AppendF($"{indent}\tTry!(BJSON.JsonWriter.WriteString(stream, {valueExpr}));\n");
		case .Enum:
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
		case .JsonObject:
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
		case .List, .Dictionary, .SizedArray, .Unsupported:
			// Nested collections land here too: JSON would take them, but no reader path exists.
			// FatalError is the only exit a comptime method has: it cannot return an error.
			let typeName = scope String();
			valueType.GetFullName(typeName);
			Runtime.FatalError(scope $"BJSON cannot serialize '{typeName}' as an element or value of field '{field.Name}'. Supported: bool, integer, floating point, String, enum, [JsonObject] types, and types with [JsonConverter].");
		}
	}
}
