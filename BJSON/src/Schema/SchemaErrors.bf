using System;
using System.Collections;
using BJSON.Enums;

namespace BJSON;

/// Options for JSON Schema validation.
public struct SchemaValidationOptions
{
	/// Maximum number of errors to collect. Set to 0 to disable collection; the result still
	/// reports IsValid. Once this many errors exist, error-collecting validation stops early.
	public int MaxErrors = 16;
}

/// Represents a single JSON Schema validation error.
/// Owned by the SchemaValidationResult that collected it, which deletes it on Dispose.
public class SchemaValidationError
{
	/// Reason the instance failed, owned by this error.
	public String Message = new .() ~ delete _;
	/// JSON Pointer to the rejected instance location, owned by this error.
	public String InstancePointer = new .() ~ delete _;
	/// JSON Pointer to the schema keyword that rejected the instance, owned by this error.
	public String SchemaPointer = new .() ~ delete _;

	/// Copies each view into storage this error owns; the views need not outlive the call.
	public this(StringView message, StringView instancePointer, StringView schemaPointer)
	{
		Message.Set(message);
		InstancePointer.Set(instancePointer);
		SchemaPointer.Set(schemaPointer);
	}
}

/// Validation result for JSON Schema evaluation.
/// Owns Errors and every error inside it. The caller MUST Dispose the result exactly once.
/// Copies of this struct share one list, so only one copy may be disposed.
public struct SchemaValidationResult : IDisposable
{
	/// False when any keyword rejected the instance, even when MaxErrors turned collection off.
	public bool IsValid = true;
	/// Errors collected during validation, owned by this result. Null when none was recorded.
	public List<SchemaValidationError> Errors = null;

	/// Frees the error list and the errors it holds.
	public void Dispose()
	{
		DeleteContainerAndItems!(Errors);
	}
}

/// Errors that can occur during schema parsing or reference resolution.
/// An error does not own its payload views. A reference an error from Validate carries reads
/// storage the JsonSchema owns and stays valid until the next Validate call on that schema.
public enum JsonSchemaError
{
	/// A schema is unusable: a node is neither an object nor a boolean, or the root document is
	/// missing. `message` names the failed check.
	case InvalidSchema(StringView message);
	/// A $ref keyword holds a non-string value; the payload carries the reason, not a reference.
	case InvalidRef(StringView reference);
	/// The referenced document loaded, but no JSON Pointer, $anchor, or $id in it matched.
	case RefNotFound(StringView reference);
	/// The same reference was already applied at this instance location, so following it again
	/// cannot terminate. Meeting it at a deeper instance location is recursion and is allowed.
	case RefCycleDetected(StringView reference);
	/// The document a $ref names could not be loaded: no resolver is set, the URI maps to no
	/// path, or the file could not be opened.
	case ExternalSchemaNotFound(StringView reference);
	/// The referenced document was read but its JSON did not parse; `inner` is the parse error.
	case ExternalSchemaParseError(StringView reference, JsonParsingError inner);
	/// The schema text passed to Parse did not parse as JSON.
	case ParseError(JsonParsingError inner);

	/// Appends a human readable description of this error to `str`.
	public override void ToString(String str)
	{
		switch (this)
		{
		case InvalidSchema(let message):
			str.AppendF("Invalid schema: {0}", message);
		case InvalidRef(let reference):
			str.AppendF("Invalid $ref: {0}", reference);
		case RefNotFound(let reference):
			str.AppendF("$ref not found: {0}", reference);
		case RefCycleDetected(let reference):
			str.AppendF("$ref cycle detected: {0}", reference);
		case ExternalSchemaNotFound(let reference):
			str.AppendF("External schema not found: {0}", reference);
		case ExternalSchemaParseError(let reference, let inner):
			str.AppendF("Failed to parse external schema {0}: ", reference);
			inner.ToString(str);
		case ParseError(let inner):
			str.Append("Schema parse error: ");
			inner.ToString(str);
		}
	}
}
