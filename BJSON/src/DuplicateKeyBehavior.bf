namespace BJSON;

/// Specifies how duplicate keys in JSON objects should be handled during parsing.
public enum DuplicateKeyBehavior
{
	/// Return error if duplicate key is found.
	/// NOTE: RFC 8259 only says names SHOULD be unique, so this rejects documents that other
	/// parsers accept.
	ThrowError,
	/// Skip the duplicate and keep the first occurrence.
	Ignore,
	/// Overwrite the previous value with the duplicate key's value.
	AlwaysRewrite
}
