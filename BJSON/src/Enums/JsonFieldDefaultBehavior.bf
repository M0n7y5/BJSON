namespace BJSON.Enums;

/// Specifies the default behavior for fields in a JSON object during deserialization.
public enum JsonFieldDefaultBehavior
{
	/// All fields are optional by default (can be missing from JSON).
	/// Use [JsonRequired] to mark specific fields as required.
	Optional,

	/// All fields are required by default (must be present in JSON).
	/// Use [JsonOptional] to mark specific fields as optional.
	Required
}
