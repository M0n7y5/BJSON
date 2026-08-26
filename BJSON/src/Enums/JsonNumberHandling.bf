namespace BJSON.Enums;

/// How a generated serializer writes an enum field, set through [JsonNumberHandling] on the field
/// or on the enum type. Deserialization ignores this enum: the generated readers take a case name
/// or a number for any enum field, whatever the handling says.
enum JsonNumberHandling
{
	/// Write the underlying integer (0, 1, 2...). This is the only case that turns off name output.
	AsNumber,
	
	/// Write the case name ("Active", "Inactive"...). This is what the generators emit when no
	/// [JsonNumberHandling] is present, so it is the effective default.
	AsString,
	
	/// Reading accepts both forms already, so this case changes writing only, where it produces
	/// case names: the writer switches to integers for AsNumber alone.
	AllowBoth
}
