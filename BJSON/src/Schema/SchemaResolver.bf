using System;
using System.IO;
using BJSON.Models;

namespace BJSON;

/// Interface for resolving external JSON Schemas referenced by $ref.
public interface ISchemaResolver
{
	/// Loads the schema document `uri` names.
	/// @param uri Document URI with any fragment already stripped, valid only for the call.
	/// @returns The parsed document. Ownership passes to the JsonSchema that asked for it,
	/// which disposes it when the schema is deleted.
	Result<JsonValue, JsonSchemaError> Resolve(StringView uri);
}

/// Default schema resolver that loads schemas from the file system.
public class FileSchemaResolver : ISchemaResolver
{
	/// Reads and parses the file the URI maps to: a `file://` URI is converted to a path and
	/// anything else is treated as a path already.
	/// @returns The parsed document, owned by the caller. ExternalSchemaNotFound when the file
	/// cannot be opened, ExternalSchemaParseError when its JSON is invalid.
	public Result<JsonValue, JsonSchemaError> Resolve(StringView uri)
	{
		let path = scope String();
		SchemaUri.UriToPath(uri, path);
		if (path.IsEmpty)
			return .Err(.ExternalSchemaNotFound(uri));

		let stream = scope FileStream();
		if (stream.Open(path, .Read, .Read) case .Err)
			return .Err(.ExternalSchemaNotFound(uri));

		defer stream.Close();
		let parseResult = Json.Deserialize(stream);
		if (parseResult case .Err(let err))
			return .Err(.ExternalSchemaParseError(uri, err));

		return .Ok(parseResult.Value);
	}
}
