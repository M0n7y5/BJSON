namespace BJSON;

/// Configuration options for JSON deserialization.
public struct DeserializerConfig
{
	/// Whether `//` line comments and `/* */` block comments are skipped like whitespace.
	/// NOTE: Comments are not part of RFC 8259, so such documents are not portable.
	public bool EnableComments = false;

	/// Behavior when an object repeats a key that is already present.
	public DuplicateKeyBehavior DuplicateBehavior = .AlwaysRewrite;
}
