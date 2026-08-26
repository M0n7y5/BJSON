using System;
using System.Collections;
using BJSON.Models;

namespace BJSON
{
	/// Represents a compiled JSON Schema document that can be used to validate JSON values.
	/// Owns the schema tree it was built from and every external document loaded through $ref, and
	/// disposes them all when deleted.
	public class JsonSchema
	{
		// SchemaValidator, in Schema/SchemaValidator.bf, is the only other reader of the members
		// marked internal here.
		internal SchemaDocument mRootDocument;
		private Dictionary<String, SchemaDocument> mDocuments = new .();
		private ISchemaResolver mResolver;
		private bool mOwnsResolver = false;
		private String mErrorRef = new .() ~ delete _;

		/// Builds a schema from a parsed tree, indexing the $id and $anchor declarations it finds.
		/// @param schemaRoot The schema tree. This JsonSchema takes ownership and disposes it.
		/// @param baseUri Base URI that $refs resolve against; the fragment is stripped and the
		/// text is copied.
		/// @param resolver Loader for external documents, still owned by the caller. When null, a
		/// FileSchemaResolver is created and owned by this JsonSchema.
		public this(JsonValue schemaRoot, StringView baseUri = default, ISchemaResolver resolver = null)
		{
			if (resolver == null)
			{
				mResolver = new FileSchemaResolver();
				mOwnsResolver = true;
			}
			else
			{
				mResolver = resolver;
			}

			let normalizedBase = scope String();
			SchemaUri.NormalizeBaseUri(baseUri, normalizedBase);
			mRootDocument = new SchemaDocument(normalizedBase, schemaRoot);
		}

		/// Checks that the tree has a schema shape and wraps it in a JsonSchema. `baseUri` and
		/// `resolver` behave as in the constructor.
		/// @param schemaRoot The schema tree. On success ownership passes to the returned schema;
		/// on failure the caller still owns it and must dispose it.
		/// @returns A JsonSchema the caller must delete, or InvalidSchema when the root is neither
		/// an object nor a boolean.
		public static Result<JsonSchema, JsonSchemaError> FromRoot(JsonValue schemaRoot, StringView baseUri = default, ISchemaResolver resolver = null)
		{
			if (!schemaRoot.IsObject() && !schemaRoot.IsBool())
				return .Err(.InvalidSchema("Schema must be an object or boolean."));

			return .Ok(new JsonSchema(schemaRoot, baseUri, resolver));
		}

		/// Parses schema JSON text into a JsonSchema. `baseUri` and `resolver` behave as in the
		/// constructor.
		/// @returns A JsonSchema the caller must delete. On failure the tree parsed here is
		/// disposed, and the error is ParseError or InvalidSchema.
		public static Result<JsonSchema, JsonSchemaError> Parse(StringView schemaJson, StringView baseUri = default, ISchemaResolver resolver = null)
		{
			let parseResult = Json.Deserialize(schemaJson);
			if (parseResult case .Err(let err))
				return .Err(.ParseError(err));

			let result = FromRoot(parseResult.Value, baseUri, resolver);
			if (result case .Err)
				parseResult.Value.Dispose();
			return result;
		}

		/// Validates a JSON instance against this schema.
		/// @param instance The value to validate. Ownership stays with the caller.
		/// @param options Error collection limits.
		/// @returns A result that owns its collected errors. The caller MUST Dispose it.
		public Result<SchemaValidationResult, JsonSchemaError> Validate(JsonValue instance, SchemaValidationOptions options = default)
		{
			let validator = scope SchemaValidator(this, options);
			return validator.Validate(instance);
		}

		/// Copies the reference an error carries into storage this schema owns. Callers must anchor
		/// before returning, while the buffer that built the reference is still alive.
		/// @returns The same error, reading a reference that stays valid until the next Validate.
		internal JsonSchemaError AnchorRef(JsonSchemaError err)
		{
			switch (err)
			{
			case .RefNotFound(let reference):
				mErrorRef.Set(reference);
				return .RefNotFound(mErrorRef);
			case .RefCycleDetected(let reference):
				mErrorRef.Set(reference);
				return .RefCycleDetected(mErrorRef);
			case .ExternalSchemaNotFound(let reference):
				mErrorRef.Set(reference);
				return .ExternalSchemaNotFound(mErrorRef);
			case .ExternalSchemaParseError(let reference, let inner):
				mErrorRef.Set(reference);
				return .ExternalSchemaParseError(mErrorRef, inner);
			default:
				return err;
			}
		}

		/// Disposes the schema tree, every external document loaded through $ref, and the resolver
		/// when this JsonSchema created it.
		public ~this()
		{
			if (mDocuments != null)
			{
				for (var entry in mDocuments)
				{
					delete entry.value;
					delete entry.key;
				}
				delete mDocuments;
			}

			if (mRootDocument != null)
			{
				delete mRootDocument;
			}

			if (mOwnsResolver && mResolver != null)
			{
				delete mResolver;
			}
		}

		private Result<SchemaDocument, JsonSchemaError> GetDocument(StringView uri)
		{
			if (uri.IsEmpty)
				return .Ok(mRootDocument);

			let normalized = scope String();
			SchemaUri.NormalizeBaseUri(uri, normalized);
			if (mRootDocument != null && mRootDocument.BaseUri == normalized)
				return .Ok(mRootDocument);

			if (mDocuments.TryGetValueAlt(normalized, let doc))
				return .Ok(doc);

			// A $ref can name an $id embedded in a document that is already loaded, so the
			// id indexes are searched before the resolver is allowed to touch the file system.
			if (mRootDocument != null && mRootDocument.IdIndex.ContainsKeyAlt(normalized))
				return .Ok(mRootDocument);

			for (var entry in mDocuments)
			{
				if (entry.value.IdIndex.ContainsKeyAlt(normalized))
					return .Ok(entry.value);
			}

			if (mResolver == null)
				return .Err(AnchorRef(.ExternalSchemaNotFound(uri)));

			let resolved = mResolver.Resolve(normalized);
			if (resolved case .Err(let err))
				return .Err(AnchorRef(err));

			let newDoc = new SchemaDocument(normalized, resolved.Value);
			mDocuments.Add(new String(normalized), newDoc);
			return .Ok(newDoc);
		}

		internal Result<JsonValue, JsonSchemaError> ResolveRefSchema(StringView reference, StringView baseUri, String outSchemaPointer, out SchemaDocument outDoc)
		{
			outDoc = null;
			outSchemaPointer.Clear();
			let resolvedRef = scope String();
			SchemaUri.ResolveUri(baseUri, reference, resolvedRef);

			StringView docUri;
			StringView fragment;
			SchemaUri.SplitRef(resolvedRef, out docUri, out fragment);

			let docResult = GetDocument(docUri);
			if (docResult case .Err(let err))
				return .Err(err);

			outDoc = docResult.Value;
			JsonValue baseSchema = outDoc.Root;
			StringView basePointer = "";
			if (!docUri.IsEmpty && outDoc.IdIndex.TryGetValueAlt(docUri, let idPointer))
			{
				basePointer = idPointer;
				if (!basePointer.IsEmpty)
				{
					if (JsonPointer.Resolve(outDoc.Root, basePointer) case .Ok(let val))
						baseSchema = val;
					else
						return .Err(AnchorRef(.RefNotFound(resolvedRef)));
				}
			}

			if (fragment.IsEmpty)
			{
				outSchemaPointer.Append(basePointer);
				return .Ok(baseSchema);
			}

			if (fragment[0] == '/')
			{
				let pointer = fragment;
				if (JsonPointer.Resolve(baseSchema, pointer) case .Ok(let val))
				{
					if (!basePointer.IsEmpty)
					{
						outSchemaPointer.Append(basePointer);
						outSchemaPointer.Append(pointer);
					}
					else
					{
						outSchemaPointer.Append(pointer);
					}
					return .Ok(val);
				}
				return .Err(AnchorRef(.RefNotFound(resolvedRef)));
			}

			let anchorBase = docUri.IsEmpty ? outDoc.BaseUri : docUri;
			let anchorKey = scope String();
			SchemaUri.BuildAnchorKey(anchorBase, fragment, anchorKey);
			if (outDoc.AnchorIndex.TryGetValueAlt(anchorKey, let pointer))
			{
				if (JsonPointer.Resolve(outDoc.Root, pointer) case .Ok(let val))
				{
					outSchemaPointer.Append(pointer);
					return .Ok(val);
				}
			}
			return .Err(AnchorRef(.RefNotFound(resolvedRef)));
		}
	}
}
