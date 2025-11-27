namespace BJSON.Enums;

public enum JsonIgnoreCondition
{
	/// Property is always serialized and deserialized, regardless of IgnoreNullValues configuration.
	Never,
	/// Property is always ignored.
	Always,
	/// Property is ignored only if it equals the default value for its type.
	WhenWritingDefault,
	/// Property is ignored if its value is null. This is applied only to reference-type properties and fields.
	WhenWritingNull
}