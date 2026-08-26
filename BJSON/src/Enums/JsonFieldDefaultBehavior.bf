namespace BJSON.Enums;

/// Value of [JsonObject].DefaultBehavior, which decides whether a field must appear in the JSON
/// document. It shapes the generated JsonDeserialize only; serialization writes every field it
/// emits regardless.
public enum JsonFieldDefaultBehavior
{
	/// A missing field is skipped and keeps whatever value it already holds.
	/// Use [JsonRequired] to make single fields mandatory.
	Optional,

	/// A missing field makes JsonDeserialize return Err.
	/// Use [JsonOptional] to exempt single fields.
	Required
}
