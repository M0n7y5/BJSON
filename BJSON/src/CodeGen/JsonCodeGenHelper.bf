using System;
using System.Reflection;
using System.Collections;
using BJSON.Enums;
using BJSON.Attributes;

namespace BJSON.CodeGen;

/// Shared helper methods for JSON code generation.
public class JsonCodeGenHelper
{
	/// Checks if a field should be serialized: instance fields that are public or carry
	/// [JsonInclude], minus fields marked [JsonIgnore(.Always)].
	/// @param field The candidate field.
	/// @param ownerType The type being emitted. The current rules do not consult it.
	/// @returns True when both emitters must handle the field.
	[Comptime]
	public static bool ShouldSerializeField(FieldInfo field, Type ownerType)
	{
		if (!field.IsInstanceField)
			return false;

		if (let ignoreAttr = field.GetCustomAttribute<JsonIgnoreAttribute>())
		{
			if (ignoreAttr.Condition == .Always)
				return false;
		}

		if (field.IsPublic)
			return true;

		if (field.HasCustomAttribute<JsonIncludeAttribute>())
			return true;

		return false;
	}

	/// Gets the JSON property name for a field (uses [JsonPropertyName] if present).
	/// The name is raw: callers MUST pass it through GetSourceLiteralName or
	/// GetJsonLiteralName before it reaches emitted source.
	[Comptime]
	public static void GetJsonPropertyName(FieldInfo field, String outName)
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

	/// Appends a property name escaped once for the emitted Beef source literal, so a name
	/// carrying a quote or a backslash cannot break or alter the emitted code.
	/// Used by the deserializer emitter, whose generated code looks the key up at runtime
	/// against the already decoded JSON key, so the name must NOT also be JSON escaped.
	/// @param field The field whose name is emitted.
	/// @param outName Receives the escaped name.
	[Comptime]
	public static void GetSourceLiteralName(FieldInfo field, String outName)
	{
		let name = scope String();
		GetJsonPropertyName(field, name);
		AppendSourceEscaped(name, outName);
	}

	/// Appends a property name escaped twice, in this order: once for JSON output, then once
	/// for the emitted Beef source literal. Used by the serializer emitter, whose generated
	/// code writes the key with WriteRaw and therefore performs no escaping at runtime.
	/// The two layers stay separate on purpose: collapsing them either emits an unescapable
	/// source literal or writes a raw quote into the JSON stream.
	/// @param field The field whose name is emitted.
	/// @param outName Receives the escaped name.
	[Comptime]
	public static void GetJsonLiteralName(FieldInfo field, String outName)
	{
		let name = scope String();
		GetJsonPropertyName(field, name);

		let jsonEscaped = scope String();
		for (let c in StringView(name))
		{
			switch (c)
			{
			case '"': jsonEscaped.Append("\\\"");
			case '\\': jsonEscaped.Append("\\\\");
			case '\b': jsonEscaped.Append("\\b");
			case '\f': jsonEscaped.Append("\\f");
			case '\n': jsonEscaped.Append("\\n");
			case '\r': jsonEscaped.Append("\\r");
			case '\t': jsonEscaped.Append("\\t");
			default:
				if ((uint8)c < 0x20)
					jsonEscaped.AppendF("\\u{:X4}", (int)(uint8)c);
				else
					jsonEscaped.Append(c);
			}
		}

		AppendSourceEscaped(jsonEscaped, outName);
	}

	/// Escapes text for a Beef source string literal, the layer both public name getters end
	/// with. Tab, newline and carriage return have literal escapes; any other control
	/// character has no representation here and fails generation.
	/// Names arriving from GetJsonLiteralName cannot trip that guard: the JSON layer has
	/// already replaced every control character with \u00XX.
	[Comptime]
	private static void AppendSourceEscaped(StringView text, String outText)
	{
		for (let c in text)
		{
			switch (c)
			{
			case '"': outText.Append("\\\"");
			case '\\': outText.Append("\\\\");
			case '\n': outText.Append("\\n");
			case '\r': outText.Append("\\r");
			case '\t': outText.Append("\\t");
			default:
				// A comptime method cannot return an error, so an unrepresentable name has to
				// abort the build instead of emitting a literal the compiler would reject.
				if ((uint8)c < 0x20)
					Runtime.FatalError(scope $"BJSON cannot emit a property name containing the control character 0x{(int)(uint8)c:X2}.");

				outText.Append(c);
			}
		}
	}

	/// Unwraps Nullable<T> to get the underlying type T.
	[Comptime]
	public static Type UnwrapNullable(Type fieldType)
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
	public static bool IsPrimitiveOrBuiltin(Type t)
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
	public static bool IsCollection(Type t)
	{
		if (let specialized = t as SpecializedGenericType)
		{
			let unspecialized = specialized.UnspecializedType;
			if (unspecialized == typeof(List<>))
				return true;
			if (unspecialized == typeof(Dictionary<,>))
				return true;
		}
		if (t.IsSizedArray)
			return true;
		return false;
	}

	/// Checks if a type is List<T>.
	[Comptime]
	public static bool IsList(Type t)
	{
		if (let specialized = t as SpecializedGenericType)
		{
			return specialized.UnspecializedType == typeof(List<>);
		}
		return false;
	}

	/// Checks if a type is Dictionary<K,V>.
	[Comptime]
	public static bool IsDictionary(Type t)
	{
		if (let specialized = t as SpecializedGenericType)
		{
			return specialized.UnspecializedType == typeof(Dictionary<,>);
		}
		return false;
	}

	/// Gets the element type of a List<T> or sized array.
	/// @returns The element type, or null when t is neither; callers treat null as
	/// unsupported and emit nothing for the field.
	[Comptime]
	public static Type GetElementType(Type t)
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
	/// Both out params come back null when t is not a Dictionary, which callers treat as
	/// unsupported.
	[Comptime]
	public static void GetDictionaryTypes(Type t, out Type keyType, out Type valueType)
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
}
