using System;
using System.Reflection;
using System.Collections;
using BJSON.Enums;
using BJSON.Attributes;

namespace BJSON.CodeGen;

/// How BJSON must handle one field, collection element or dictionary value. Both emitters and
/// JsonObjectAttribute.ValidateFields branch on this, so what BJSON supports is decided in
/// exactly one place, JsonCodeGenHelper.Classify.
public enum JsonFieldKind
{
	/// A bool, written and read as a JSON boolean.
	Bool,
	/// Any integer type, written and read as a JSON number.
	Integer,
	/// Any floating point type, written and read as a JSON number.
	Float,
	/// System.String. Never StringView, which cannot own the text a read produces.
	String,
	/// An enum, written as a string unless [JsonNumberHandling(.AsNumber)] says otherwise, and
	/// read from either a string or a number.
	Enum,
	/// List<T>, written and read as a JSON array.
	List,
	/// Dictionary<String, V>, written and read as a JSON object.
	Dictionary,
	/// A sized array T[N], written and read as a JSON array.
	SizedArray,
	/// A class or struct carrying [JsonObject], handled by the methods emitted into it.
	JsonObject,
	/// A [JsonConverter] on the field or on the type supplies both directions.
	Converter,
	/// No emitter can handle it, so the caller MUST fail generation.
	Unsupported
}

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

	/// Gets the [JsonConverter] converter type for a field, a collection element or a dictionary
	/// value. The attribute on the field wins over the attribute on the type, so a field can
	/// override the conversion its own type declares.
	/// @param field The field being emitted. Element and value sites pass the owning field, whose
	/// own converter has already been applied to the whole collection by then.
	/// @param fieldType The type being converted: the field type, or an element or value type.
	/// @returns The converter type, or null when neither the field nor the type carries the
	/// attribute.
	[Comptime]
	public static Type GetConverterType(FieldInfo field, Type fieldType)
	{
		if (let fieldAttr = field.GetCustomAttribute<JsonConverterAttribute>())
			return fieldAttr.ConverterType;

		if (let typeAttr = fieldType.GetCustomAttribute<JsonConverterAttribute>())
			return typeAttr.ConverterType;

		return null;
	}

	/// Decides how one field, element or value must be handled. The order of these tests is the
	/// single definition of what BJSON supports: validation rejects what comes back Unsupported,
	/// and both emitters switch on the result.
	/// A converter wins over everything else, which is what lets it stand in for the [JsonObject]
	/// a type does not carry.
	/// @param field The field being emitted, consulted for a field level [JsonConverter].
	/// @param fieldType The type to classify, with Nullable<T> already unwrapped.
	/// @returns The kind, or Unsupported when nothing can handle the type.
	[Comptime]
	public static JsonFieldKind Classify(FieldInfo field, Type fieldType)
	{
		if (GetConverterType(field, fieldType) != null)
			return .Converter;
		if (fieldType == typeof(bool))
			return .Bool;
		if (fieldType.IsInteger)
			return .Integer;
		if (fieldType.IsFloatingPoint)
			return .Float;
		if (fieldType == typeof(String))
			return .String;
		if (fieldType.IsEnum)
			return .Enum;
		if (IsList(fieldType))
			return .List;
		if (IsDictionary(fieldType))
			return .Dictionary;
		if (fieldType.IsSizedArray)
			return .SizedArray;
		if (fieldType.HasCustomAttribute<JsonObjectAttribute>())
			return .JsonObject;

		// StringView and char types land here on purpose: a view owns no text, and a character
		// has no JSON form the reader could give back.
		return .Unsupported;
	}

	/// Gets the keyword the emitted methods need in front of their signature. A base type with
	/// [JsonObject] already had JsonSerialize and JsonDeserialize emitted into it, so the derived
	/// emission has to shadow the inherited pair.
	/// @param type The type receiving the emitted methods.
	/// @returns "new " when a base type already carries the methods, otherwise the empty string.
	[Comptime]
	public static StringView GetNewKeyword(Type type)
	{
		if (type.BaseType == null || type.BaseType == typeof(Object))
			return "";

		return type.BaseType.HasCustomAttribute<JsonObjectAttribute>() ? "new " : "";
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
