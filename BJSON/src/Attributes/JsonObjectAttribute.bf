using System;
using System.Reflection;
using System.Collections;
using BJSON.Enums;

namespace BJSON.Attributes;

/// Attribute that marks a class or struct for automatic JSON serialization/deserialization.
/// The comptime code generator will implement IJsonSerializable for the annotated type.
/// 
/// Example usage:
/// ```
/// [JsonObject]
/// class Player
/// {
///     public String Name = new .() ~ delete _;
///     public int Health;
///     public List<String> Items = new .() ~ delete _;
/// }
/// ```
[AttributeUsage(.Class | .Struct)]
public struct JsonObjectAttribute : Attribute, IComptimeTypeApply
{
	/// Optional custom name for the JSON object (not commonly used).
	public String Name;

	public this(String name = "")
	{
		this.Name = name;
	}

	[Comptime]
	public void ApplyToType(Type type)
	{
		// Validate fields at comptime
		ValidateFields(type);

		// Add the IJsonSerializable interface
		Compiler.EmitAddInterface(type, typeof(IJsonSerializable));

		// Generate both serialization and deserialization methods
		EmitDeserializeMethod(type);
		EmitSerializeMethod(type);
	}

	/// Validates that all serializable fields are properly configured.
	[Comptime]
	private void ValidateFields(Type type)
	{
		for (let field in type.GetFields())
		{
			if (!ShouldSerializeField(field, type))
				continue;

			var fieldType = UnwrapNullable(field.FieldType);

			// Skip validation for built-in types and collections
			if (IsPrimitiveOrBuiltin(fieldType))
				continue;
			if (IsCollection(fieldType))
				continue;
			if (fieldType.IsEnum)
				continue;

			// Check if object/struct fields have [JsonObject] attribute
			if (fieldType.IsObject || fieldType.IsStruct)
			{
				if (!fieldType.HasCustomAttribute<JsonObjectAttribute>())
				{
					String typeName = scope .();
					fieldType.GetFullName(typeName);
					Runtime.FatalError(scope $"Field '{field.Name}' is of type '{typeName}' which does not have [JsonObject] attribute. Add [JsonObject] to the type or [JsonIgnore] to the field.");
				}
			}
		}
	}

	/// Generates the JsonDeserialize method.
	[Comptime]
	private void EmitDeserializeMethod(Type type)
	{
		let code = scope String();
		code.Append("""
			public Result<void> JsonDeserialize(BJSON.Models.JsonValue value)
			{
				if (!value.IsObject())
					return .Err;
				
				let root = value.AsObject().Value;

			""");

		for (let field in type.GetFields())
		{
			if (!ShouldSerializeField(field, type))
				continue;

			EmitFieldDeserialization(code, field, type);
		}

		code.Append("""
				return .Ok;
			}\n
			""");

		Compiler.EmitTypeBody(type, code);
	}

	/// Generates the JsonSerialize method.
	[Comptime]
	private void EmitSerializeMethod(Type type)
	{
		let code = scope String();
		code.Append("""
			public Result<void> JsonSerialize(String buffer)
			{
				buffer.Append('{');
				bool _firstField = true;

			""");

		for (let field in type.GetFields())
		{
			if (!ShouldSerializeField(field, type))
				continue;

			EmitFieldSerialization(code, field, type);
		}

		code.Append("""
				buffer.Append('}');
				return .Ok;
			}\n
			""");

		Compiler.EmitTypeBody(type, code);
	}

	/// Gets the JSON property name for a field (uses [JsonPropertyName] if present).
	[Comptime]
	private void GetJsonPropertyName(FieldInfo field, String outName)
	{
		if (let attr = field.GetCustomAttribute<JsonPropertyNameAttribute>())
		{
			outName.Append(attr.name);
		}
		else
		{
			outName.Append(field.Name);
		}
	}

	/// Checks if a field should be serialized based on attributes and visibility.
	[Comptime]
	private bool ShouldSerializeField(FieldInfo field, Type ownerType)
	{
		// Must be instance field
		if (!field.IsInstanceField)
			return false;

		// Must be declared in this type (not inherited)
		if (field.DeclaringType != ownerType)
			return false;

		// Check JsonIgnore attribute
		if (let ignoreAttr = field.GetCustomAttribute<JsonIgnoreAttribute>())
		{
			if (ignoreAttr.Condition == .Always)
				return false;
		}

		// Public fields are always included
		if (field.IsPublic)
			return true;

		// Non-public fields need [JsonInclude]
		if (field.HasCustomAttribute<JsonIncludeAttribute>())
			return true;

		return false;
	}

	/// Unwraps Nullable<T> to get the underlying type T.
	[Comptime]
	private Type UnwrapNullable(Type fieldType)
	{
		if (fieldType.IsNullable)
		{
			if (let specializedType = fieldType as SpecializedGenericType)
			{
				return specializedType.GetGenericArg(0);
			}
		}
		return fieldType;
	}

	/// Checks if a type is a primitive or built-in type that doesn't need [JsonObject].
	[Comptime]
	private bool IsPrimitiveOrBuiltin(Type t)
	{
		if (t.IsPrimitive)
			return true;
		if (t.IsInteger || t.IsFloatingPoint)
			return true;
		if (t == typeof(String) || t == typeof(StringView))
			return true;
		if (t == typeof(bool))
			return true;
		return false;
	}

	/// Checks if a type is a supported collection type.
	[Comptime]
	private bool IsCollection(Type t)
	{
		if (let specialized = t as SpecializedGenericType)
		{
			let unspecialized = specialized.UnspecializedType;
			if (unspecialized == typeof(List<>))
				return true;
			if (unspecialized == typeof(Dictionary<,>))
				return true;
		}
		// Check for sized arrays
		if (t.IsSizedArray)
			return true;
		return false;
	}

	/// Checks if a type is List<T>.
	[Comptime]
	private bool IsList(Type t)
	{
		if (let specialized = t as SpecializedGenericType)
		{
			return specialized.UnspecializedType == typeof(List<>);
		}
		return false;
	}

	/// Checks if a type is Dictionary<K,V>.
	[Comptime]
	private bool IsDictionary(Type t)
	{
		if (let specialized = t as SpecializedGenericType)
		{
			return specialized.UnspecializedType == typeof(Dictionary<,>);
		}
		return false;
	}

	/// Gets the element type of a List<T> or sized array.
	[Comptime]
	private Type GetElementType(Type t)
	{
		if (let specialized = t as SpecializedGenericType)
		{
			if (specialized.UnspecializedType == typeof(List<>))
				return specialized.GetGenericArg(0);
		}
		if (t.IsSizedArray)
			return t.UnderlyingType;
		return null;
	}

	/// Gets the key and value types of a Dictionary<K,V>.
	[Comptime]
	private void GetDictionaryTypes(Type t, out Type keyType, out Type valueType)
	{
		keyType = null;
		valueType = null;
		if (let specialized = t as SpecializedGenericType)
		{
			if (specialized.UnspecializedType == typeof(Dictionary<,>))
			{
				keyType = specialized.GetGenericArg(0);
				valueType = specialized.GetGenericArg(1);
			}
		}
	}

	//==========================================================================
	// DESERIALIZATION CODE GENERATION
	//==========================================================================

	/// Emits deserialization code for a single field.
	[Comptime]
	private void EmitFieldDeserialization(String code, FieldInfo field, Type ownerType)
	{
		let jsonName = scope String();
		GetJsonPropertyName(field, jsonName);

		var fieldType = field.FieldType;
		let isNullable = fieldType.IsNullable;

		if (isNullable)
			fieldType = UnwrapNullable(fieldType);

		// For nullable/optional fields, use if-let pattern
		if (isNullable)
		{
			code.AppendF($"\tif (root.GetValue(\"{jsonName}\") case .Ok(let _{field.Name}Json))\n");
			code.Append("\t{\n");
			EmitFieldValueDeserialization(code, field, fieldType, scope $"_{field.Name}Json", "\t\t");
			code.Append("\t}\n\n");
		}
		else
		{
			// Required field - use Try! for error propagation
			code.AppendF($"\tlet _{field.Name}Json = Try!(root.GetValue(\"{jsonName}\"));\n");
			EmitFieldValueDeserialization(code, field, fieldType, scope $"_{field.Name}Json", "\t");
			code.Append("\n");
		}
	}

	/// Emits the actual value assignment for a field.
	[Comptime]
	private void EmitFieldValueDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		// Handle different field types
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
			// Copy into existing pre-allocated string
			code.AppendF($"{indent}if (!{jsonVar}.IsString()) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.Set((StringView){jsonVar});\n");
		}
		else if (fieldType.IsEnum)
		{
			EmitEnumDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (IsList(fieldType))
		{
			EmitListDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (IsDictionary(fieldType))
		{
			EmitDictionaryDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (fieldType.IsSizedArray)
		{
			EmitSizedArrayDeserialization(code, field, fieldType, jsonVar, indent);
		}
		else if (fieldType.IsObject || fieldType.IsStruct)
		{
			// Nested object with [JsonObject] - call JsonDeserialize on pre-allocated instance
			code.AppendF($"{indent}if (!{jsonVar}.IsObject()) return .Err;\n");
			code.AppendF($"{indent}Try!({field.Name}.JsonDeserialize({jsonVar}));\n");
		}
	}

	/// Emits deserialization for enum fields.
	[Comptime]
	private void EmitEnumDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		String typeName = scope .();
		fieldType.GetFullName(typeName);

		// Support both string and number enum values
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

	/// Emits deserialization for List<T> fields.
	[Comptime]
	private void EmitListDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		let elementType = GetElementType(fieldType);
		if (elementType == null)
			return;

		code.AppendF($"{indent}if (!{jsonVar}.IsArray()) return .Err;\n");
		code.AppendF($"{indent}let _{field.Name}Arr = {jsonVar}.AsArray().Value;\n");
		code.AppendF($"{indent}for (let _item in _{field.Name}Arr)\n");
		code.AppendF($"{indent}{{\n");

		EmitListItemDeserialization(code, field, elementType, "_item", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
	}

	/// Emits deserialization for a single list item.
	[Comptime]
	private void EmitListItemDeserialization(String code, FieldInfo field, Type elementType, StringView itemVar, StringView indent)
	{
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
			// Object with [JsonObject] - auto-create with new
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

	/// Emits deserialization for Dictionary<K,V> fields.
	[Comptime]
	private void EmitDictionaryDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
	{
		Type keyType, valueType;
		GetDictionaryTypes(fieldType, out keyType, out valueType);
		if (keyType == null || valueType == null)
			return;

		// JSON only supports string keys
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

	/// Emits deserialization for a dictionary value.
	[Comptime]
	private void EmitDictionaryValueDeserialization(String code, FieldInfo field, Type valueType, StringView keyVar, StringView valueVar, StringView indent)
	{
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

	/// Emits deserialization for sized array fields (T[N]).
	[Comptime]
	private void EmitSizedArrayDeserialization(String code, FieldInfo field, Type fieldType, StringView jsonVar, StringView indent)
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

	/// Emits deserialization for a single sized array item.
	[Comptime]
	private void EmitSizedArrayItemDeserialization(String code, FieldInfo field, Type elementType, StringView itemVar, StringView indexVar, StringView indent)
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
			// For sized arrays of strings, we'd need pre-allocated strings
			// This is a limitation - emit an error
			Runtime.FatalError(scope $"Sized arrays of String are not supported. Use List<String> instead for field '{field.Name}'.");
		}
	}

	//==========================================================================
	// SERIALIZATION CODE GENERATION
	//==========================================================================

	/// Emits serialization code for a single field.
	[Comptime]
	private void EmitFieldSerialization(String code, FieldInfo field, Type ownerType)
	{
		let jsonName = scope String();
		GetJsonPropertyName(field, jsonName);

		var fieldType = field.FieldType;
		let isNullable = fieldType.IsNullable;

		if (isNullable)
			fieldType = UnwrapNullable(fieldType);

		// Check JsonIgnore conditions for serialization
		if (let ignoreAttr = field.GetCustomAttribute<JsonIgnoreAttribute>())
		{
			if (ignoreAttr.Condition == .WhenWritingNull && isNullable)
			{
				code.AppendF($"\tif ({field.Name}.HasValue)\n");
				code.Append("\t{\n");
				EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t\t", true);
				code.Append("\t}\n");
				return;
			}
			else if (ignoreAttr.Condition == .WhenWritingDefault)
			{
				code.AppendF($"\tif ({field.Name} != default)\n");
				code.Append("\t{\n");
				EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t\t", true);
				code.Append("\t}\n");
				return;
			}
		}

		// Handle nullable types
		if (isNullable)
		{
			code.AppendF($"\tif ({field.Name}.HasValue)\n");
			code.Append("\t{\n");
			EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t\t", true);
			code.Append("\t}\n");
		}
		else
		{
			EmitFieldValueSerialization(code, field, fieldType, jsonName, "\t", true);
		}
	}

	/// Emits the actual value serialization for a field.
	[Comptime]
	private void EmitFieldValueSerialization(String code, FieldInfo field, Type fieldType, StringView jsonName, StringView indent, bool handleComma)
	{
		if (handleComma)
		{
			code.AppendF($"{indent}if (!_firstField) buffer.Append(',');\n");
			code.AppendF($"{indent}_firstField = false;\n");
		}

		// Write the key
		code.AppendF($"{indent}buffer.Append('\"');\n");
		code.AppendF($"{indent}buffer.Append(\"{jsonName}\");\n");
		code.AppendF($"{indent}buffer.Append(\"\\\":\");\n");

		// Write the value
		if (fieldType == typeof(bool))
		{
			code.AppendF($"{indent}buffer.Append({field.Name} ? \"true\" : \"false\");\n");
		}
		else if (fieldType.IsInteger)
		{
			code.AppendF($"{indent}{field.Name}.ToString(buffer);\n");
		}
		else if (fieldType.IsFloatingPoint)
		{
			code.AppendF($"{indent}if ({field.Name}.IsNaN || {field.Name}.IsInfinity) return .Err;\n");
			code.AppendF($"{indent}{field.Name}.ToString(buffer);\n");
		}
		else if (fieldType == typeof(String))
		{
			code.AppendF($"{indent}buffer.Append('\"');\n");
			code.AppendF($"{indent}BJSON.JsonWriter.AppendEscaped(buffer, {field.Name});\n");
			code.AppendF($"{indent}buffer.Append('\"');\n");
		}
		else if (fieldType.IsEnum)
		{
			// Serialize enums as strings
			code.AppendF($"{indent}buffer.Append('\"');\n");
			code.AppendF($"{indent}{field.Name}.ToString(buffer);\n");
			code.AppendF($"{indent}buffer.Append('\"');\n");
		}
		else if (IsList(fieldType))
		{
			EmitListSerialization(code, field, fieldType, indent);
		}
		else if (IsDictionary(fieldType))
		{
			EmitDictionarySerialization(code, field, fieldType, indent);
		}
		else if (fieldType.IsSizedArray)
		{
			EmitSizedArraySerialization(code, field, fieldType, indent);
		}
		else if (fieldType.IsObject || fieldType.IsStruct)
		{
			// Nested object with [JsonObject]
			code.AppendF($"{indent}Try!({field.Name}.JsonSerialize(buffer));\n");
		}
	}

	/// Emits serialization for List<T> fields.
	[Comptime]
	private void EmitListSerialization(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		let elementType = GetElementType(fieldType);
		if (elementType == null)
			return;

		code.AppendF($"{indent}buffer.Append('[');\n");
		code.AppendF($"{indent}bool _first{field.Name} = true;\n");
		code.AppendF($"{indent}for (let _item in {field.Name})\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (!_first{field.Name}) buffer.Append(',');\n");
		code.AppendF($"{indent}\t_first{field.Name} = false;\n");

		EmitValueSerialization(code, elementType, "_item", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}buffer.Append(']');\n");
	}

	/// Emits serialization for Dictionary<K,V> fields.
	[Comptime]
	private void EmitDictionarySerialization(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		Type keyType, valueType;
		GetDictionaryTypes(fieldType, out keyType, out valueType);
		if (keyType == null || valueType == null)
			return;

		code.AppendF($"{indent}buffer.Append('{{');\n");
		code.AppendF($"{indent}bool _first{field.Name} = true;\n");
		code.AppendF($"{indent}for (let _kv in {field.Name})\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (!_first{field.Name}) buffer.Append(',');\n");
		code.AppendF($"{indent}\t_first{field.Name} = false;\n");
		code.AppendF($"{indent}\tbuffer.Append('\"');\n");
		code.AppendF($"{indent}\tBJSON.JsonWriter.AppendEscaped(buffer, _kv.key);\n");
		code.AppendF($"{indent}\tbuffer.Append(\"\\\":\");\n");

		EmitValueSerialization(code, valueType, "_kv.value", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}buffer.Append('}}');\n");
	}

	/// Emits serialization for sized array fields (T[N]).
	[Comptime]
	private void EmitSizedArraySerialization(String code, FieldInfo field, Type fieldType, StringView indent)
	{
		let elementType = fieldType.UnderlyingType;
		let sizedArrayType = fieldType as SizedArrayType;
		let arraySize = sizedArrayType != null ? sizedArrayType.ElementCount : 0;

		code.AppendF($"{indent}buffer.Append('[');\n");
		code.AppendF($"{indent}for (int _i = 0; _i < {arraySize}; _i++)\n");
		code.AppendF($"{indent}{{\n");
		code.AppendF($"{indent}\tif (_i > 0) buffer.Append(',');\n");

		EmitValueSerialization(code, elementType, scope $"{field.Name}[_i]", scope $"{indent}\t");

		code.AppendF($"{indent}}}\n");
		code.AppendF($"{indent}buffer.Append(']');\n");
	}

	/// Emits serialization for a single value (used for list/array/dict elements).
	[Comptime]
	private void EmitValueSerialization(String code, Type valueType, StringView valueExpr, StringView indent)
	{
		if (valueType == typeof(bool))
		{
			code.AppendF($"{indent}buffer.Append({valueExpr} ? \"true\" : \"false\");\n");
		}
		else if (valueType.IsInteger)
		{
			code.AppendF($"{indent}{valueExpr}.ToString(buffer);\n");
		}
		else if (valueType.IsFloatingPoint)
		{
			code.AppendF($"{indent}if ({valueExpr}.IsNaN || {valueExpr}.IsInfinity) return .Err;\n");
			code.AppendF($"{indent}{valueExpr}.ToString(buffer);\n");
		}
		else if (valueType == typeof(String))
		{
			code.AppendF($"{indent}buffer.Append('\"');\n");
			code.AppendF($"{indent}BJSON.JsonWriter.AppendEscaped(buffer, {valueExpr});\n");
			code.AppendF($"{indent}buffer.Append('\"');\n");
		}
		else if (valueType.IsEnum)
		{
			code.AppendF($"{indent}buffer.Append('\"');\n");
			code.AppendF($"{indent}{valueExpr}.ToString(buffer);\n");
			code.AppendF($"{indent}buffer.Append('\"');\n");
		}
		else if (valueType.HasCustomAttribute<JsonObjectAttribute>())
		{
			code.AppendF($"{indent}Try!({valueExpr}.JsonSerialize(buffer));\n");
		}
	}
}
