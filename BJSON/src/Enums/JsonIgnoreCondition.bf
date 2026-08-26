namespace BJSON.Enums;

/// Value of [JsonIgnore].Condition, which decides what the code generators emit for a field.
/// Only Always drops the field; the two WhenWriting cases guard serialization and leave
/// deserialization untouched.
public enum JsonIgnoreCondition
{
	/// Field is serialized and deserialized as usual. This is value 0, so [JsonIgnore] without an
	/// explicit Condition skips nothing.
	Never,
	/// Field is dropped by both generators: it is neither written nor read.
	Always,
	/// Field is written only when it differs from default: the generated writer guards it with
	/// `if (field != default)`. Deserialization still fills the field.
	WhenWritingDefault,
	/// Field is written only when it carries a value: HasValue for a Nullable<T> field, non-null
	/// for a reference field. On a plain value-type field the condition does nothing, and
	/// deserialization still fills the field.
	WhenWritingNull
}