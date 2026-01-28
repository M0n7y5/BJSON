namespace BJSON.Enums;

/// How to handle enum serialization and deserialization.
enum JsonNumberHandling
{
	/// Serialize enums as numbers (0, 1, 2...). This is the default.
	/// When deserializing, accept both numbers and strings.
	AsNumber,
	
	/// Serialize enums as strings ("Active", "Inactive"...).
	/// When deserializing, accept strings only.
	AsString,
	
	/// When reading: accept either number or string.
	/// When writing: use AsNumber.
	AllowBoth
}
