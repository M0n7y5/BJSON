using System;
using System.Collections;
using System.IO;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON
{
	/// Options for JSON Schema validation.
	public struct SchemaValidationOptions
	{
		/// Maximum number of errors to collect. Set to 0 to disable error collection.
		public int MaxErrors = 16;
	}

	/// Represents a single JSON Schema validation error.
	public class SchemaValidationError
	{
		public String Message = new .() ~ delete _;
		public String InstancePointer = new .() ~ delete _;
		public String SchemaPointer = new .() ~ delete _;

		public this(StringView message, StringView instancePointer, StringView schemaPointer)
		{
			Message.Set(message);
			InstancePointer.Set(instancePointer);
			SchemaPointer.Set(schemaPointer);
		}
	}

	/// Validation result for JSON Schema evaluation.
	public struct SchemaValidationResult
	{
		public bool IsValid = true;
		public List<SchemaValidationError> Errors = null;
	}

	/// Errors that can occur during schema parsing or reference resolution.
	public enum JsonSchemaError
	{
		case InvalidSchema(StringView message);
		case InvalidRef(StringView reference);
		case RefNotFound(StringView reference);
		case RefCycleDetected(StringView reference);
		case ExternalSchemaNotFound(StringView reference);
		case ExternalSchemaParseError(StringView reference, JsonParsingError inner);
		case ParseError(JsonParsingError inner);

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

	/// Interface for resolving external JSON Schemas referenced by $ref.
	public interface ISchemaResolver
	{
		Result<JsonValue, JsonSchemaError> Resolve(StringView uri);
	}

	/// Default schema resolver that loads schemas from the file system.
	public class FileSchemaResolver : ISchemaResolver
	{
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

	/// Represents a compiled JSON Schema document that can be used to validate JSON values.
	public class JsonSchema
	{
		private SchemaDocument mRootDocument;
		private Dictionary<String, SchemaDocument> mDocuments = new .();
		private ISchemaResolver mResolver;
		private bool mOwnsResolver = false;

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

		/// Parses a JsonValue schema tree into a JsonSchema. Ownership is transferred on success.
		public static Result<JsonSchema, JsonSchemaError> FromRoot(JsonValue schemaRoot, StringView baseUri = default, ISchemaResolver resolver = null)
		{
			if (!schemaRoot.IsObject() && !schemaRoot.IsBool())
				return .Err(.InvalidSchema("Schema must be an object or boolean."));

			return .Ok(new JsonSchema(schemaRoot, baseUri, resolver));
		}

		/// Parses schema JSON text into a JsonSchema. Ownership is transferred on success.
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
		public Result<SchemaValidationResult, JsonSchemaError> Validate(JsonValue instance, SchemaValidationOptions options = default)
		{
			let validator = scope SchemaValidator(this, options);
			return validator.Validate(instance);
		}

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

			if (mResolver == null)
				return .Err(.ExternalSchemaNotFound(uri));

			let resolved = mResolver.Resolve(normalized);
			if (resolved case .Err(let err))
				return .Err(err);

			let newDoc = new SchemaDocument(normalized, resolved.Value);
			mDocuments.Add(new String(normalized), newDoc);
			return .Ok(newDoc);
		}

		private Result<JsonValue, JsonSchemaError> ResolveRefSchema(StringView reference, StringView baseUri, String outSchemaPointer, out SchemaDocument outDoc)
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
						return .Err(.RefNotFound(resolvedRef));
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
				return .Err(.RefNotFound(resolvedRef));
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
			return .Err(.RefNotFound(resolvedRef));
		}

		private class SchemaValidator
		{
			private JsonSchema mSchema;
			private SchemaValidationOptions mOptions;
			private SchemaValidationResult mResult = .();
			private bool mStop = false;
			private List<String> mRefStack = new .() ~ DeleteContainerAndItems!(_);

			public this(JsonSchema schema, SchemaValidationOptions options)
			{
				mSchema = schema;
				mOptions = options;
			}

			public Result<SchemaValidationResult, JsonSchemaError> Validate(JsonValue instance)
			{
				if (mSchema.mRootDocument == null)
					return .Err(.InvalidSchema("Schema document is not available."));

				if (ValidateSchema(mSchema.mRootDocument, mSchema.mRootDocument.Root, "", instance, "", true) case .Err(let err))
					return .Err(err);

				return .Ok(mResult);
			}

			private Result<bool, JsonSchemaError> ValidateSchema(SchemaDocument doc, JsonValue schemaNode, StringView schemaPointer, JsonValue instance, StringView instancePointer, bool collectErrors)
			{
				if (collectErrors && mStop)
					return .Ok(false);

				if (schemaNode.IsBool())
				{
					if ((bool)schemaNode)
						return .Ok(true);

					AddError("Schema is false", instancePointer, schemaPointer, collectErrors);
					return .Ok(false);
				}

				if (!schemaNode.IsObject())
					return .Err(.InvalidSchema("Schema must be an object or boolean."));

				bool valid = true;
				let schemaObj = schemaNode.As<JsonObject>();
				let baseUri = doc.GetBaseUri(schemaPointer);

			if (schemaObj.TryGet("$ref") case .Ok(let refVal))
				{
					if (!refVal.IsString())
						return .Err(.InvalidRef("$ref must be a string"));

					let refStr = (StringView)refVal;
					let resolvedRef = scope String();
					SchemaUri.ResolveUri(baseUri, refStr, resolvedRef);
					if (IsRefOnStack(resolvedRef))
						return .Err(.RefCycleDetected(resolvedRef));

					mRefStack.Add(new String(resolvedRef));
					defer
					{
						let last = mRefStack.Back;
						mRefStack.PopBack();
						delete last;
					}

					let refPointer = scope String();
					SchemaDocument refDoc = null;
					let refResolved = mSchema.ResolveRefSchema(refStr, baseUri, refPointer, out refDoc);
					if (refResolved case .Err(let refErr))
						return .Err(refErr);

					let refResult = ValidateSchema(refDoc, refResolved.Value, refPointer, instance, instancePointer, collectErrors);
					if (refResult case .Err(let refValidationErr))
						return .Err(refValidationErr);
					if (refResult case .Ok(let refOk) && !refOk)
						valid = false;
				}

				if (schemaObj.TryGet("type") case .Ok(let typeVal))
					valid &= ValidateType(typeVal, instance, instancePointer, schemaPointer, collectErrors);

				if (schemaObj.TryGet("enum") case .Ok(let enumVal))
					valid &= ValidateEnum(enumVal, instance, instancePointer, schemaPointer, collectErrors);

				if (schemaObj.TryGet("const") case .Ok(let constVal))
					valid &= ValidateConst(constVal, instance, instancePointer, schemaPointer, collectErrors);

				valid &= ValidateNumeric(schemaObj, instance, instancePointer, schemaPointer, collectErrors);
				valid &= ValidateString(schemaObj, instance, instancePointer, schemaPointer, collectErrors);

				let arrayResult = ValidateArray(schemaObj, doc, instance, instancePointer, schemaPointer, collectErrors);
				if (arrayResult case .Err(let arrayErr))
					return .Err(arrayErr);
				if (arrayResult case .Ok(let arrayOk) && !arrayOk)
					valid = false;

				let objectResult = ValidateObject(schemaObj, doc, instance, instancePointer, schemaPointer, collectErrors);
				if (objectResult case .Err(let objectErr))
					return .Err(objectErr);
				if (objectResult case .Ok(let objectOk) && !objectOk)
					valid = false;

				let combineResult = ValidateCombining(schemaObj, doc, instance, instancePointer, schemaPointer, collectErrors);
				if (combineResult case .Err(let combineErr))
					return .Err(combineErr);
				if (combineResult case .Ok(let combineOk) && !combineOk)
					valid = false;

				return .Ok(valid);
			}

			private bool ValidateType(JsonValue typeVal, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				bool matches = false;
				if (typeVal.IsString())
				{
					matches = TypeMatches((StringView)typeVal, instance);
				}
				else if (typeVal.IsArray())
				{
					for (var item in typeVal.As<JsonArray>())
					{
						if (item.IsString() && TypeMatches((StringView)item, instance))
						{
							matches = true;
							break;
						}
					}
				}

				if (!matches)
				{
					let keywordPointer = scope String();
					SchemaUri.BuildPointer(schemaPointer, "type", keywordPointer);
					AddError("Type mismatch", instancePointer, keywordPointer, collectErrors);
				}
				return matches;
			}

			private bool ValidateEnum(JsonValue enumVal, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				if (!enumVal.IsArray())
					return true;

				for (var item in enumVal.As<JsonArray>())
				{
					if (JsonEquals(item, instance))
						return true;
				}

				let keywordPointer = scope String();
				SchemaUri.BuildPointer(schemaPointer, "enum", keywordPointer);
				AddError("Value not in enum", instancePointer, keywordPointer, collectErrors);
				return false;
			}

			private bool ValidateConst(JsonValue constVal, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				if (JsonEquals(constVal, instance))
					return true;

				let keywordPointer = scope String();
				SchemaUri.BuildPointer(schemaPointer, "const", keywordPointer);
				AddError("Value does not match const", instancePointer, keywordPointer, collectErrors);
				return false;
			}

			private bool ValidateNumeric(JsonObject schemaObj, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				if (!instance.IsNumber())
					return true;

				bool valid = true;
				double value = (double)instance;

				if (schemaObj.TryGet("minimum") case .Ok(let minVal))
				{
					if (minVal.IsNumber())
					{
						double min = (double)minVal;
						if (value < min)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "minimum", keywordPointer);
							AddError("Number is less than minimum", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("maximum") case .Ok(let maxVal))
				{
					if (maxVal.IsNumber())
					{
						double max = (double)maxVal;
						if (value > max)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "maximum", keywordPointer);
							AddError("Number is greater than maximum", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("exclusiveMinimum") case .Ok(let exMinVal))
				{
					if (exMinVal.IsNumber())
					{
						double exMin = (double)exMinVal;
						if (value <= exMin)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "exclusiveMinimum", keywordPointer);
							AddError("Number is not greater than exclusiveMinimum", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("exclusiveMaximum") case .Ok(let exMaxVal))
				{
					if (exMaxVal.IsNumber())
					{
						double exMax = (double)exMaxVal;
						if (value >= exMax)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "exclusiveMaximum", keywordPointer);
							AddError("Number is not less than exclusiveMaximum", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				return valid;
			}

			private bool ValidateString(JsonObject schemaObj, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				if (!instance.IsString())
					return true;

				bool valid = true;
				let strView = (StringView)instance;
				let length = strView.Length;

				if (schemaObj.TryGet("minLength") case .Ok(let minVal))
				{
					if (minVal.IsNumber())
					{
						int minLen = (int)(double)minVal;
						if (length < minLen)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "minLength", keywordPointer);
							AddError("String is shorter than minLength", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("maxLength") case .Ok(let maxVal))
				{
					if (maxVal.IsNumber())
					{
						int maxLen = (int)(double)maxVal;
						if (length > maxLen)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "maxLength", keywordPointer);
							AddError("String is longer than maxLength", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				return valid;
			}

			private Result<bool, JsonSchemaError> ValidateArray(JsonObject schemaObj, SchemaDocument doc, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				if (!instance.IsArray())
					return .Ok(true);

				bool valid = true;
				let arr = instance.As<JsonArray>();
				let count = arr.Count;

				if (schemaObj.TryGet("minItems") case .Ok(let minVal))
				{
					if (minVal.IsNumber())
					{
						int minItems = (int)(double)minVal;
						if (count < minItems)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "minItems", keywordPointer);
							AddError("Array has fewer items than minItems", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("maxItems") case .Ok(let maxVal))
				{
					if (maxVal.IsNumber())
					{
						int maxItems = (int)(double)maxVal;
						if (count > maxItems)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "maxItems", keywordPointer);
							AddError("Array has more items than maxItems", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("uniqueItems") case .Ok(let uniqueVal))
				{
					if (uniqueVal.IsBool() && (bool)uniqueVal)
					{
						if (!ArrayItemsUnique(arr))
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "uniqueItems", keywordPointer);
							AddError("Array items are not unique", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				int prefixCount = 0;
				if (schemaObj.TryGet("prefixItems") case .Ok(let prefixVal))
				{
					if (prefixVal.IsArray())
					{
						let prefixArr = prefixVal.As<JsonArray>();
						prefixCount = prefixArr.Count;
						for (int i = 0; i < prefixArr.Count && i < count; i++)
						{
							let indexStr = scope String();
							indexStr.AppendF("{}", i);
							let childInstancePtr = scope String();
							SchemaUri.BuildPointer(instancePointer, indexStr, childInstancePtr);
							let baseSchemaPtr = scope String();
							SchemaUri.BuildPointer(schemaPointer, "prefixItems", baseSchemaPtr);
							let childSchemaPtr = scope String();
							SchemaUri.BuildPointer(baseSchemaPtr, indexStr, childSchemaPtr);
							let result = ValidateSchema(doc, prefixArr[i], childSchemaPtr, arr[i], childInstancePtr, collectErrors);
							if (result case .Err(let err))
								return .Err(err);
							if (result case .Ok(let ok) && !ok)
								valid = false;
						}
					}
				}

				JsonValue itemsSchema = default;
				bool hasItems = false;
				if (schemaObj.TryGet("items") case .Ok(let itemsVal))
				{
					itemsSchema = itemsVal;
					hasItems = true;
				}

				if (hasItems)
				{
					if (itemsSchema.IsObject() || itemsSchema.IsBool())
					{
						let itemsSchemaPtr = scope String();
						SchemaUri.BuildPointer(schemaPointer, "items", itemsSchemaPtr);
						for (int i = prefixCount; i < count; i++)
						{
							let indexStr = scope String();
							indexStr.AppendF("{}", i);
						let childInstancePtr = scope String();
						SchemaUri.BuildPointer(instancePointer, indexStr, childInstancePtr);
						let result = ValidateSchema(doc, itemsSchema, itemsSchemaPtr, arr[i], childInstancePtr, collectErrors);
						if (result case .Err(let err))
							return .Err(err);
						if (result case .Ok(let ok) && !ok)
							valid = false;
					}
				}
				else if (itemsSchema.IsArray())
				{
						let itemsArr = itemsSchema.As<JsonArray>();
						for (int i = 0; i < itemsArr.Count && i < count; i++)
						{
							let indexStr = scope String();
							indexStr.AppendF("{}", i);
							let childInstancePtr = scope String();
							SchemaUri.BuildPointer(instancePointer, indexStr, childInstancePtr);
						let baseSchemaPtr = scope String();
						SchemaUri.BuildPointer(schemaPointer, "items", baseSchemaPtr);
						let childSchemaPtr = scope String();
						SchemaUri.BuildPointer(baseSchemaPtr, indexStr, childSchemaPtr);
						let result = ValidateSchema(doc, itemsArr[i], childSchemaPtr, arr[i], childInstancePtr, collectErrors);
						if (result case .Err(let err))
							return .Err(err);
						if (result case .Ok(let ok) && !ok)
							valid = false;
					}

						if (schemaObj.TryGet("additionalItems") case .Ok(let additionalVal))
						{
							if (additionalVal.IsBool() && !(bool)additionalVal)
							{
								if (count > itemsArr.Count)
								{
									let keywordPointer = scope String();
									SchemaUri.BuildPointer(schemaPointer, "additionalItems", keywordPointer);
									AddError("Array has additional items not allowed", instancePointer, keywordPointer, collectErrors);
									valid = false;
								}
							}
							else if (additionalVal.IsObject() || additionalVal.IsBool())
							{
								let additionalSchemaPtr = scope String();
								SchemaUri.BuildPointer(schemaPointer, "additionalItems", additionalSchemaPtr);
								for (int i = itemsArr.Count; i < count; i++)
								{
									let indexStr = scope String();
									indexStr.AppendF("{}", i);
								let childInstancePtr = scope String();
								SchemaUri.BuildPointer(instancePointer, indexStr, childInstancePtr);
								let result = ValidateSchema(doc, additionalVal, additionalSchemaPtr, arr[i], childInstancePtr, collectErrors);
								if (result case .Err(let err))
									return .Err(err);
								if (result case .Ok(let ok) && !ok)
									valid = false;
							}
						}
					}
				}
				}

				return .Ok(valid);
			}

			private Result<bool, JsonSchemaError> ValidateObject(JsonObject schemaObj, SchemaDocument doc, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				if (!instance.IsObject())
					return .Ok(true);

				bool valid = true;
				let obj = instance.As<JsonObject>();
				let count = obj.Count;

				if (schemaObj.TryGet("minProperties") case .Ok(let minVal))
				{
					if (minVal.IsNumber())
					{
						int minProps = (int)(double)minVal;
						if (count < minProps)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "minProperties", keywordPointer);
							AddError("Object has fewer properties than minProperties", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("maxProperties") case .Ok(let maxVal))
				{
					if (maxVal.IsNumber())
					{
						int maxProps = (int)(double)maxVal;
						if (count > maxProps)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "maxProperties", keywordPointer);
							AddError("Object has more properties than maxProperties", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				JsonValue propertiesSchema = default;
				bool hasProperties = false;
				if (schemaObj.TryGet("properties") case .Ok(let propsVal))
				{
					propertiesSchema = propsVal;
					hasProperties = propsVal.IsObject();
				}

				JsonValue additionalSchema = default;
				bool hasAdditional = false;
				if (schemaObj.TryGet("additionalProperties") case .Ok(let addVal))
				{
					additionalSchema = addVal;
					hasAdditional = true;
				}

				if (schemaObj.TryGet("required") case .Ok(let reqVal))
				{
					if (reqVal.IsArray())
					{
						for (var reqItem in reqVal.As<JsonArray>())
						{
							if (reqItem.IsString())
							{
								let key = (StringView)reqItem;
								if (!obj.ContainsKey(key))
								{
									let keywordPointer = scope String();
									SchemaUri.BuildPointer(schemaPointer, "required", keywordPointer);
									let childInstancePtr = scope String();
									SchemaUri.BuildPointer(instancePointer, key, childInstancePtr);
									AddError("Required property is missing", childInstancePtr, keywordPointer, collectErrors);
									valid = false;
								}
							}
						}
					}
				}

				for (var kv in obj)
				{
					let key = kv.key;
					let value = kv.value;
					bool handled = false;
					if (hasProperties)
					{
						if (propertiesSchema.TryGet(key) case .Ok(let propSchema))
						{
							let childInstancePtr = scope String();
							SchemaUri.BuildPointer(instancePointer, key, childInstancePtr);
						let baseSchemaPtr = scope String();
						SchemaUri.BuildPointer(schemaPointer, "properties", baseSchemaPtr);
						let childSchemaPtr = scope String();
						SchemaUri.BuildPointer(baseSchemaPtr, key, childSchemaPtr);
						let result = ValidateSchema(doc, propSchema, childSchemaPtr, value, childInstancePtr, collectErrors);
						if (result case .Err(let err))
							return .Err(err);
						if (result case .Ok(let ok) && !ok)
							valid = false;
						handled = true;
					}
				}

					if (!handled && hasAdditional)
					{
						if (additionalSchema.IsBool())
						{
							if (!(bool)additionalSchema)
							{
								let keywordPointer = scope String();
								SchemaUri.BuildPointer(schemaPointer, "additionalProperties", keywordPointer);
								let childInstancePtr = scope String();
								SchemaUri.BuildPointer(instancePointer, key, childInstancePtr);
								AddError("Additional properties not allowed", childInstancePtr, keywordPointer, collectErrors);
								valid = false;
							}
						}
						else if (additionalSchema.IsObject())
						{
						let childInstancePtr = scope String();
						SchemaUri.BuildPointer(instancePointer, key, childInstancePtr);
						let childSchemaPtr = scope String();
						SchemaUri.BuildPointer(schemaPointer, "additionalProperties", childSchemaPtr);
						let result = ValidateSchema(doc, additionalSchema, childSchemaPtr, value, childInstancePtr, collectErrors);
						if (result case .Err(let err))
							return .Err(err);
						if (result case .Ok(let ok) && !ok)
							valid = false;
					}
				}
			}

				return .Ok(valid);
			}

			private Result<bool, JsonSchemaError> ValidateCombining(JsonObject schemaObj, SchemaDocument doc, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				bool valid = true;

				if (schemaObj.TryGet("allOf") case .Ok(let allOfVal))
				{
					if (allOfVal.IsArray())
					{
						let allOfArr = allOfVal.As<JsonArray>();
						for (int i = 0; i < allOfArr.Count; i++)
						{
							let indexStr = scope String();
							indexStr.AppendF("{}", i);
						let baseSchemaPtr = scope String();
						SchemaUri.BuildPointer(schemaPointer, "allOf", baseSchemaPtr);
						let childSchemaPtr = scope String();
						SchemaUri.BuildPointer(baseSchemaPtr, indexStr, childSchemaPtr);
						let result = ValidateSchema(doc, allOfArr[i], childSchemaPtr, instance, instancePointer, collectErrors);
						if (result case .Err(let err))
							return .Err(err);
						if (result case .Ok(let ok) && !ok)
							valid = false;
					}
				}
			}

				if (schemaObj.TryGet("anyOf") case .Ok(let anyOfVal))
				{
					if (anyOfVal.IsArray())
					{
						bool matched = false;
						let anyOfArr = anyOfVal.As<JsonArray>();
						for (int i = 0; i < anyOfArr.Count; i++)
						{
							let indexStr = scope String();
							indexStr.AppendF("{}", i);
							let baseSchemaPtr = scope String();
							SchemaUri.BuildPointer(schemaPointer, "anyOf", baseSchemaPtr);
							let childSchemaPtr = scope String();
							SchemaUri.BuildPointer(baseSchemaPtr, indexStr, childSchemaPtr);
							let result = ValidateSchema(doc, anyOfArr[i], childSchemaPtr, instance, instancePointer, false);
							if (result case .Err(let err))
								return .Err(err);
							if (result case .Ok(let ok) && ok)
							{
								matched = true;
								break;
							}
						}
						if (!matched)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "anyOf", keywordPointer);
							AddError("anyOf did not match any subschema", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("oneOf") case .Ok(let oneOfVal))
				{
					if (oneOfVal.IsArray())
					{
						int matches = 0;
						let oneOfArr = oneOfVal.As<JsonArray>();
						for (int i = 0; i < oneOfArr.Count; i++)
						{
							let indexStr = scope String();
							indexStr.AppendF("{}", i);
							let baseSchemaPtr = scope String();
							SchemaUri.BuildPointer(schemaPointer, "oneOf", baseSchemaPtr);
							let childSchemaPtr = scope String();
							SchemaUri.BuildPointer(baseSchemaPtr, indexStr, childSchemaPtr);
							let result = ValidateSchema(doc, oneOfArr[i], childSchemaPtr, instance, instancePointer, false);
							if (result case .Err(let err))
								return .Err(err);
							if (result case .Ok(let ok) && ok)
								matches++;
						}
						if (matches != 1)
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "oneOf", keywordPointer);
							AddError("oneOf did not match exactly one subschema", instancePointer, keywordPointer, collectErrors);
							valid = false;
						}
					}
				}

				if (schemaObj.TryGet("not") case .Ok(let notVal))
				{
					let result = ValidateSchema(doc, notVal, schemaPointer, instance, instancePointer, false);
					if (result case .Err(let err))
						return .Err(err);
					if (result case .Ok(let ok) && ok)
					{
						let keywordPointer = scope String();
						SchemaUri.BuildPointer(schemaPointer, "not", keywordPointer);
						AddError("not schema matched", instancePointer, keywordPointer, collectErrors);
						valid = false;
					}
				}

				if (schemaObj.TryGet("if") case .Ok(let ifVal))
				{
					bool ifMatched = false;
					let ifResult = ValidateSchema(doc, ifVal, schemaPointer, instance, instancePointer, false);
					if (ifResult case .Err(let ifErr))
						return .Err(ifErr);
					if (ifResult case .Ok(let ifOk))
						ifMatched = ifOk;

					if (ifMatched)
					{
						if (schemaObj.TryGet("then") case .Ok(let thenVal))
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "then", keywordPointer);
							let thenResult = ValidateSchema(doc, thenVal, keywordPointer, instance, instancePointer, collectErrors);
							if (thenResult case .Err(let thenErr))
								return .Err(thenErr);
							if (thenResult case .Ok(let thenOk) && !thenOk)
								valid = false;
						}
					}
					else
					{
						if (schemaObj.TryGet("else") case .Ok(let elseVal))
						{
							let keywordPointer = scope String();
							SchemaUri.BuildPointer(schemaPointer, "else", keywordPointer);
							let elseResult = ValidateSchema(doc, elseVal, keywordPointer, instance, instancePointer, collectErrors);
							if (elseResult case .Err(let elseErr))
								return .Err(elseErr);
							if (elseResult case .Ok(let elseOk) && !elseOk)
								valid = false;
						}
					}
				}

				return .Ok(valid);
			}

			private bool TypeMatches(StringView typeName, JsonValue instance)
			{
				switch (typeName)
				{
				case "null":
					return instance.IsNull();
				case "boolean":
					return instance.IsBool();
				case "number":
					return instance.IsNumber();
				case "integer":
					return IsInteger(instance);
				case "string":
					return instance.IsString();
				case "object":
					return instance.IsObject();
				case "array":
					return instance.IsArray();
				default:
					return false;
				}
			}

			private bool IsInteger(JsonValue value)
			{
				if (value.type == .NUMBER_SIGNED || value.type == .NUMBER_UNSIGNED)
					return true;
				if (value.type == .NUMBER)
				{
					double number = (double)value;
					return number == (double)(int64)number;
				}
				return false;
			}

			private bool ArrayItemsUnique(JsonArray array)
			{
				for (int i = 0; i < array.Count; i++)
				{
					for (int j = i + 1; j < array.Count; j++)
					{
						if (JsonEquals(array[i], array[j]))
							return false;
					}
				}
				return true;
			}

			private bool JsonEquals(JsonValue a, JsonValue b)
			{
				if (a.IsNumber() && b.IsNumber())
					return (double)a == (double)b;

				if (a.type != b.type)
					return false;

				switch (a.type)
				{
				case .NULL:
					return true;
				case .BOOL:
					return (bool)a == (bool)b;
				case .STRING:
					return (StringView)a == (StringView)b;
				case .NUMBER, .NUMBER_SIGNED, .NUMBER_UNSIGNED:
					return (double)a == (double)b;
				case .ARRAY:
					{
						let arrA = a.As<JsonArray>();
						let arrB = b.As<JsonArray>();
						if (arrA.Count != arrB.Count)
							return false;
						for (int i = 0; i < arrA.Count; i++)
						{
							if (!JsonEquals(arrA[i], arrB[i]))
								return false;
						}
						return true;
					}
				case .OBJECT:
					{
						let objA = a.As<JsonObject>();
						let objB = b.As<JsonObject>();
						if (objA.Count != objB.Count)
							return false;
						for (var kv in objA)
						{
							if (objB.TryGet(kv.key) case .Ok(let valB))
							{
								if (!JsonEquals(kv.value, valB))
									return false;
							}
							else
								return false;
						}
						return true;
					}
				default:
					return false;
				}
			}

			private bool IsRefOnStack(StringView resolvedRef)
			{
				for (var item in mRefStack)
				{
					if (item == resolvedRef)
						return true;
				}
				return false;
			}

			private void AddError(StringView message, StringView instancePointer, StringView schemaPointer, bool collectErrors)
			{
				if (!collectErrors)
					return;

				mResult.IsValid = false;
				if (mOptions.MaxErrors <= 0)
					return;

				if (mResult.Errors == null)
					mResult.Errors = new .(4);

				mResult.Errors.Add(new SchemaValidationError(message, instancePointer, schemaPointer));
				if (mResult.Errors.Count >= mOptions.MaxErrors)
					mStop = true;
			}
		}
	}

	class SchemaDocument
	{
		public String BaseUri = new .() ~ delete _;
		public JsonValue Root;
		public Dictionary<String, String> BaseUriByPointer = new .();
		public Dictionary<String, String> AnchorIndex = new .();
		public Dictionary<String, String> IdIndex = new .();

		public this(StringView baseUri, JsonValue root)
		{
			BaseUri.Set(baseUri);
			Root = root;
			if (!BaseUri.IsEmpty)
				AddId(BaseUri, "");
			BuildIndexes();
		}

		public ~this()
		{
			Root.Dispose();
			DeleteStringDictionary(BaseUriByPointer);
			DeleteStringDictionary(AnchorIndex);
			DeleteStringDictionary(IdIndex);
		}

		public StringView GetBaseUri(StringView pointer)
		{
			if (BaseUriByPointer.TryGetValueAlt(pointer, let value))
				return value;
			return BaseUri;
		}

		private void BuildIndexes()
		{
			IndexSchema(Root, "", BaseUri);
		}

		private void IndexSchema(JsonValue schemaNode, StringView pointer, StringView baseUri)
		{
			if (!schemaNode.IsObject() && !schemaNode.IsBool())
				return;

			if (schemaNode.IsObject())
			{
				let obj = schemaNode.As<JsonObject>();
				StringView nextBase = baseUri;
				if (obj.TryGet("$id") case .Ok(let idVal))
				{
					if (idVal.IsString())
					{
						let resolved = scope String();
						SchemaUri.ResolveUri(baseUri, (StringView)idVal, resolved);
						nextBase = resolved;
						AddId(nextBase, pointer);
					}
				}

				AddBase(pointer, nextBase);

				if (obj.TryGet("$anchor") case .Ok(let anchorVal))
				{
					if (anchorVal.IsString())
					{
						let anchorKey = scope String();
						SchemaUri.BuildAnchorKey(nextBase, (StringView)anchorVal, anchorKey);
						AddAnchor(anchorKey, pointer);
					}
				}

				IndexSubschemas(obj, pointer, nextBase);
			}
			else
			{
				AddBase(pointer, baseUri);
			}
		}

		private void IndexSubschemas(JsonObject schemaObj, StringView pointer, StringView baseUri)
		{
			IndexSchemaObjectMap(schemaObj, "properties", pointer, baseUri);
			IndexSchemaObjectMap(schemaObj, "$defs", pointer, baseUri);
			IndexSchemaObjectMap(schemaObj, "definitions", pointer, baseUri);
			IndexSchemaObjectMap(schemaObj, "patternProperties", pointer, baseUri);
			IndexSchemaObjectMap(schemaObj, "dependentSchemas", pointer, baseUri);

			IndexSchemaValue(schemaObj, "additionalProperties", pointer, baseUri);
			IndexSchemaValue(schemaObj, "propertyNames", pointer, baseUri);
			IndexSchemaValue(schemaObj, "contains", pointer, baseUri);
			IndexSchemaValue(schemaObj, "not", pointer, baseUri);
			IndexSchemaValue(schemaObj, "if", pointer, baseUri);
			IndexSchemaValue(schemaObj, "then", pointer, baseUri);
			IndexSchemaValue(schemaObj, "else", pointer, baseUri);

			IndexSchemaArray(schemaObj, "allOf", pointer, baseUri);
			IndexSchemaArray(schemaObj, "anyOf", pointer, baseUri);
			IndexSchemaArray(schemaObj, "oneOf", pointer, baseUri);

			if (schemaObj.TryGet("items") case .Ok(let itemsVal))
			{
				if (itemsVal.IsObject() || itemsVal.IsBool())
					IndexSchemaValue(schemaObj, "items", pointer, baseUri);
				else if (itemsVal.IsArray())
					IndexSchemaArray(schemaObj, "items", pointer, baseUri);
			}

			IndexSchemaArray(schemaObj, "prefixItems", pointer, baseUri);
			IndexSchemaValue(schemaObj, "additionalItems", pointer, baseUri);
		}

		private void IndexSchemaObjectMap(JsonObject schemaObj, StringView keyword, StringView pointer, StringView baseUri)
		{
			if (schemaObj.TryGet(keyword) case .Ok(let mapVal))
			{
				if (!mapVal.IsObject())
					return;

				let mapObj = mapVal.As<JsonObject>();
				for (var kv in mapObj)
				{
					let basePtr = scope String();
					SchemaUri.BuildPointer(pointer, keyword, basePtr);
					let childPtr = scope String();
					SchemaUri.BuildPointer(basePtr, kv.key, childPtr);
					IndexSchema(kv.value, childPtr, baseUri);
				}
			}
		}

		private void IndexSchemaArray(JsonObject schemaObj, StringView keyword, StringView pointer, StringView baseUri)
		{
			if (schemaObj.TryGet(keyword) case .Ok(let arrVal))
			{
				if (!arrVal.IsArray())
					return;

				let arr = arrVal.As<JsonArray>();
				for (int i = 0; i < arr.Count; i++)
				{
					let indexStr = scope String();
					indexStr.AppendF("{}", i);
					let basePtr = scope String();
					SchemaUri.BuildPointer(pointer, keyword, basePtr);
					let childPtr = scope String();
					SchemaUri.BuildPointer(basePtr, indexStr, childPtr);
					IndexSchema(arr[i], childPtr, baseUri);
				}
			}
		}

		private void IndexSchemaValue(JsonObject schemaObj, StringView keyword, StringView pointer, StringView baseUri)
		{
			if (schemaObj.TryGet(keyword) case .Ok(let val))
			{
				if (val.IsObject() || val.IsBool())
				{
					let childPtr = scope String();
					SchemaUri.BuildPointer(pointer, keyword, childPtr);
					IndexSchema(val, childPtr, baseUri);
				}
			}
		}

		private void AddBase(StringView pointer, StringView baseUri)
		{
			if (BaseUriByPointer.TryGetValueAlt(pointer, let existing))
				return;
			BaseUriByPointer.Add(new String(pointer), new String(baseUri));
		}

		private void AddAnchor(StringView anchorKey, StringView pointer)
		{
			if (AnchorIndex.TryGetValueAlt(anchorKey, let existing))
				return;
			AnchorIndex.Add(new String(anchorKey), new String(pointer));
		}

		private void AddId(StringView id, StringView pointer)
		{
			if (IdIndex.TryGetValueAlt(id, let existing))
				return;
			IdIndex.Add(new String(id), new String(pointer));
		}

		private static void DeleteStringDictionary(Dictionary<String, String> dict)
		{
			if (dict == null)
				return;

			for (var entry in dict)
			{
				delete entry.key;
				delete entry.value;
			}
			delete dict;
		}
	}

	static class SchemaUri
	{
		public static void NormalizeBaseUri(StringView uri, String output)
		{
			output.Clear();
			if (uri.IsEmpty)
				return;

			int hashIndex = uri.IndexOf('#');
			if (hashIndex == -1)
				output.Append(uri);
			else
				output.Append(uri.Substring(0, hashIndex));
		}

		public static void ResolveUri(StringView baseUri, StringView reference, String output)
		{
			output.Clear();
			if (reference.IsEmpty)
			{
				output.Append(baseUri);
				return;
			}

			if (StartsWith(reference, "#"))
			{
				output.Append(baseUri);
				output.Append(reference);
				return;
			}

			if (IsAbsoluteUri(reference) || StartsWith(reference, "/") || StartsWith(reference, "\\"))
			{
				output.Append(reference);
				return;
			}

			if (baseUri.IsEmpty)
			{
				output.Append(reference);
				return;
			}

			let baseNoFrag = scope String();
			NormalizeBaseUri(baseUri, baseNoFrag);
			let dir = scope String();
			GetDirectory(baseNoFrag, dir);
			if (!dir.IsEmpty)
				AppendPath(dir, reference, output);
			else
				output.Append(reference);
		}

		public static void SplitRef(StringView reference, out StringView docUri, out StringView fragment)
		{
			int hashIndex = reference.IndexOf('#');
			if (hashIndex == -1)
			{
				docUri = reference;
				fragment = "";
				return;
			}

			docUri = reference.Substring(0, hashIndex);
			fragment = reference.Substring(hashIndex + 1);
		}

		public static void BuildAnchorKey(StringView baseUri, StringView anchor, String output)
		{
			output.Clear();
			output.Append(baseUri);
			output.Append('#');
			output.Append(anchor);
		}

		public static void BuildPointer(StringView basePointer, StringView segment, String output)
		{
			output.Clear();
			output.Append(basePointer);
			output.Append('/');
			JsonPointer.Escape(segment, output);
		}

		public static void UriToPath(StringView uri, String output)
		{
			output.Clear();
			if (StartsWith(uri, "file://"))
			{
				var path = uri.Substring(7);
				if (path.Length >= 3 && path[0] == '/' && path[2] == ':')
					path = path.Substring(1);
				output.Append(path);
				return;
			}
			output.Append(uri);
		}

		private static bool IsAbsoluteUri(StringView uri)
		{
			for (int i = 0; i < uri.Length; i++)
			{
				let c = uri[i];
				if (c == ':')
					return true;
				if (c == '/' || c == '\\')
					break;
			}
			return false;
		}

		private static void GetDirectory(StringView path, String output)
		{
			output.Clear();
			int lastIndex = -1;
			for (int i = 0; i < path.Length; i++)
			{
				let c = path[i];
				if (c == '/' || c == '\\')
					lastIndex = i;
			}
			if (lastIndex > 0)
				output.Append(path.Substring(0, lastIndex));
		}

		private static void AppendPath(StringView dir, StringView relative, String output)
		{
			output.Clear();
			output.Append(dir);
			if (!dir.IsEmpty)
			{
				let last = dir[dir.Length - 1];
				if (last != '/' && last != '\\')
				{
					char8 separator = '/';
					for (let c in dir)
					{
						if (c == '\\')
						{
							separator = '\\';
							break;
						}
					}
					output.Append(separator);
				}
			}
			output.Append(relative);
		}

		private static bool StartsWith(StringView text, StringView prefix)
		{
			if (prefix.Length > text.Length)
				return false;
			for (int i = 0; i < prefix.Length; i++)
			{
				if (text[i] != prefix[i])
					return false;
			}
			return true;
		}
	}
}
