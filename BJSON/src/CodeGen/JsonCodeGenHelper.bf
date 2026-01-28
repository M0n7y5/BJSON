using System;
using System.Reflection;
using System.Collections;
using BJSON.Enums;
using BJSON.Attributes;

namespace BJSON.CodeGen;

/// Shared helper methods for JSON code generation.
public class JsonCodeGenHelper
{
	/// Checks if a field should be serialized based on attributes and visibility.
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
