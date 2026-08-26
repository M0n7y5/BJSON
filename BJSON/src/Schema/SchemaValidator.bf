using System;
using System.Collections;
using BJSON.Models;
// Reaches the root document, $ref resolution, and error anchoring JsonSchema keeps internal.
using internal BJSON;

namespace BJSON;

/// One frame of the $ref guard: a resolved reference plus the instance location it was
/// applied at. A recursive schema meets the same reference at a deeper instance location,
/// while a true cycle meets it at the same one.
class SchemaRefFrame
{
	public String Reference = new .() ~ delete _;
	public String InstancePointer = new .() ~ delete _;

	public this(StringView reference, StringView instancePointer)
	{
		Reference.Set(reference);
		InstancePointer.Set(instancePointer);
	}
}

/// One validation pass over an instance, owned by the JsonSchema.Validate call that made it.
/// Namespace internal: JsonSchema.Validate is the only entry point.
class SchemaValidator
{
	private JsonSchema mSchema;
	private SchemaValidationOptions mOptions;
	private SchemaValidationResult mResult = .();
	private bool mStop = false;
	private List<SchemaRefFrame> mRefStack = new .() ~ DeleteContainerAndItems!(_);

	public this(JsonSchema schema, SchemaValidationOptions options)
	{
		mSchema = schema;
		mOptions = options;
	}

	/// Runs validation and hands ownership of the collected errors to the caller.
	/// @param instance The value to validate.
	/// @returns A result that owns its collected errors. The caller MUST Dispose it.
	public Result<SchemaValidationResult, JsonSchemaError> Validate(JsonValue instance)
	{
		if (mSchema.mRootDocument == null)
			return .Err(.InvalidSchema("Schema document is not available."));

		if (ValidateSchema(mSchema.mRootDocument, mSchema.mRootDocument.Root, "", instance, "", true) case .Err(let err))
			return .Err(err);

		let result = mResult;
		mResult = .();
		return .Ok(result);
	}

	/// Frees errors of a run whose result never reached the caller, which is the error
	/// path of Validate.
	public ~this()
	{
		mResult.Dispose();
	}

	/// Records that `keyword` rejected the instance, pointing the error at the keyword inside
	/// `schemaPointer`. AddError applies MaxErrors and the early stop.
	/// @returns False always, so a caller writes `valid = Fail(...)` or `return Fail(...)`.
	private bool Fail(StringView keyword, StringView schemaPointer, StringView instancePointer, StringView message, bool collectErrors)
	{
		let keywordPointer = scope String();
		SchemaUri.BuildPointer(schemaPointer, keyword, keywordPointer);
		AddError(message, instancePointer, keywordPointer, collectErrors);
		return false;
	}

	/// Appends an array index to `parent` as one pointer token, rendering the number first
	/// because a pointer token is text.
	private void BuildIndexPointer(StringView parent, int index, String output)
	{
		let indexStr = scope String();
		indexStr.AppendF("{}", index);
		SchemaUri.BuildPointer(parent, indexStr, output);
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
			if (IsRefOnStack(resolvedRef, instancePointer))
				return .Err(mSchema.AnchorRef(.RefCycleDetected(resolvedRef)));

			mRefStack.Add(new SchemaRefFrame(resolvedRef, instancePointer));
			defer
			{
				let last = mRefStack.Back;
				mRefStack.PopBack();
				delete last;
			}

			let refPointer = scope String();
			SchemaDocument refDoc = null;
			let refSchema = Try!(mSchema.ResolveRefSchema(refStr, baseUri, refPointer, out refDoc));
			valid &= Try!(ValidateSchema(refDoc, refSchema, refPointer, instance, instancePointer, collectErrors));
		}

		if (schemaObj.TryGet("type") case .Ok(let typeVal))
			valid &= ValidateType(typeVal, instance, instancePointer, schemaPointer, collectErrors);

		if (schemaObj.TryGet("enum") case .Ok(let enumVal))
			valid &= ValidateEnum(enumVal, instance, instancePointer, schemaPointer, collectErrors);

		if (schemaObj.TryGet("const") case .Ok(let constVal))
			valid &= ValidateConst(constVal, instance, instancePointer, schemaPointer, collectErrors);

		valid &= ValidateNumeric(schemaObj, instance, instancePointer, schemaPointer, collectErrors);
		valid &= ValidateString(schemaObj, instance, instancePointer, schemaPointer, collectErrors);
		valid &= Try!(ValidateArray(schemaObj, doc, instance, instancePointer, schemaPointer, collectErrors));
		valid &= Try!(ValidateObject(schemaObj, doc, instance, instancePointer, schemaPointer, collectErrors));
		valid &= Try!(ValidateCombining(schemaObj, doc, instance, instancePointer, schemaPointer, collectErrors));

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
			return Fail("type", schemaPointer, instancePointer, "Type mismatch", collectErrors);

		return true;
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

		return Fail("enum", schemaPointer, instancePointer, "Value not in enum", collectErrors);
	}

	private bool ValidateConst(JsonValue constVal, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
	{
		if (JsonEquals(constVal, instance))
			return true;

		return Fail("const", schemaPointer, instancePointer, "Value does not match const", collectErrors);
	}

	private bool ValidateNumeric(JsonObject schemaObj, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
	{
		if (!instance.IsNumber())
			return true;

		bool valid = true;
		double value = (double)instance;

		if (schemaObj.TryGet("minimum") case .Ok(let minVal))
		{
			if (minVal.IsNumber() && (value < (double)minVal))
				valid = Fail("minimum", schemaPointer, instancePointer, "Number is less than minimum", collectErrors);
		}

		if (schemaObj.TryGet("maximum") case .Ok(let maxVal))
		{
			if (maxVal.IsNumber() && (value > (double)maxVal))
				valid = Fail("maximum", schemaPointer, instancePointer, "Number is greater than maximum", collectErrors);
		}

		if (schemaObj.TryGet("exclusiveMinimum") case .Ok(let exMinVal))
		{
			if (exMinVal.IsNumber() && (value <= (double)exMinVal))
				valid = Fail("exclusiveMinimum", schemaPointer, instancePointer, "Number is not greater than exclusiveMinimum", collectErrors);
		}

		if (schemaObj.TryGet("exclusiveMaximum") case .Ok(let exMaxVal))
		{
			if (exMaxVal.IsNumber() && (value >= (double)exMaxVal))
				valid = Fail("exclusiveMaximum", schemaPointer, instancePointer, "Number is not less than exclusiveMaximum", collectErrors);
		}

		if (schemaObj.TryGet("multipleOf") case .Ok(let multipleVal))
		{
			if (multipleVal.IsNumber())
			{
				double divisor = (double)multipleVal;
				if (divisor <= 0)
					valid = Fail("multipleOf", schemaPointer, instancePointer, "multipleOf must be greater than zero", collectErrors);
				else if (!IsMultipleOf(value, divisor))
					valid = Fail("multipleOf", schemaPointer, instancePointer, "Number is not a multiple of multipleOf", collectErrors);
			}
		}

		return valid;
	}

	private bool ValidateString(JsonObject schemaObj, JsonValue instance, StringView instancePointer, StringView schemaPointer, bool collectErrors)
	{
		if (!instance.IsString())
			return true;

		bool valid = true;
		let length = CountCodePoints((StringView)instance);

		if (schemaObj.TryGet("minLength") case .Ok(let minVal))
		{
			if (minVal.IsNumber() && (length < (int)(double)minVal))
				valid = Fail("minLength", schemaPointer, instancePointer, "String is shorter than minLength", collectErrors);
		}

		if (schemaObj.TryGet("maxLength") case .Ok(let maxVal))
		{
			if (maxVal.IsNumber() && (length > (int)(double)maxVal))
				valid = Fail("maxLength", schemaPointer, instancePointer, "String is longer than maxLength", collectErrors);
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
			if (minVal.IsNumber() && (count < (int)(double)minVal))
				valid = Fail("minItems", schemaPointer, instancePointer, "Array has fewer items than minItems", collectErrors);
		}

		if (schemaObj.TryGet("maxItems") case .Ok(let maxVal))
		{
			if (maxVal.IsNumber() && (count > (int)(double)maxVal))
				valid = Fail("maxItems", schemaPointer, instancePointer, "Array has more items than maxItems", collectErrors);
		}

		if (schemaObj.TryGet("uniqueItems") case .Ok(let uniqueVal))
		{
			if (uniqueVal.IsBool() && (bool)uniqueVal && !ArrayItemsUnique(arr))
				valid = Fail("uniqueItems", schemaPointer, instancePointer, "Array items are not unique", collectErrors);
		}

		if (schemaObj.TryGet("contains") case .Ok(let containsVal))
		{
			if (containsVal.IsObject() || containsVal.IsBool())
				valid &= Try!(ValidateContains(schemaObj, doc, containsVal, arr, instancePointer, schemaPointer, collectErrors));
		}

		int prefixCount = 0;
		if (schemaObj.TryGet("prefixItems") case .Ok(let prefixVal))
		{
			if (prefixVal.IsArray())
			{
				let prefixArr = prefixVal.As<JsonArray>();
				prefixCount = prefixArr.Count;
				let baseSchemaPtr = scope String();
				SchemaUri.BuildPointer(schemaPointer, "prefixItems", baseSchemaPtr);
				for (int i = 0; i < prefixArr.Count && i < count; i++)
				{
					let childInstancePtr = scope String();
					BuildIndexPointer(instancePointer, i, childInstancePtr);
					let childSchemaPtr = scope String();
					BuildIndexPointer(baseSchemaPtr, i, childSchemaPtr);
					valid &= Try!(ValidateSchema(doc, prefixArr[i], childSchemaPtr, arr[i], childInstancePtr, collectErrors));
				}
			}
		}

		if (schemaObj.TryGet("items") case .Ok(let itemsVal))
		{
			if (itemsVal.IsObject() || itemsVal.IsBool())
			{
				let itemsSchemaPtr = scope String();
				SchemaUri.BuildPointer(schemaPointer, "items", itemsSchemaPtr);
				for (int i = prefixCount; i < count; i++)
				{
					let childInstancePtr = scope String();
					BuildIndexPointer(instancePointer, i, childInstancePtr);
					valid &= Try!(ValidateSchema(doc, itemsVal, itemsSchemaPtr, arr[i], childInstancePtr, collectErrors));
				}
			}
			else if (itemsVal.IsArray())
			{
				let itemsArr = itemsVal.As<JsonArray>();
				let baseSchemaPtr = scope String();
				SchemaUri.BuildPointer(schemaPointer, "items", baseSchemaPtr);
				for (int i = 0; i < itemsArr.Count && i < count; i++)
				{
					let childInstancePtr = scope String();
					BuildIndexPointer(instancePointer, i, childInstancePtr);
					let childSchemaPtr = scope String();
					BuildIndexPointer(baseSchemaPtr, i, childSchemaPtr);
					valid &= Try!(ValidateSchema(doc, itemsArr[i], childSchemaPtr, arr[i], childInstancePtr, collectErrors));
				}

				// additionalItems only has a meaning beside an items array: it covers the tail
				// the tuple form left unvalidated.
				if (schemaObj.TryGet("additionalItems") case .Ok(let additionalVal))
				{
					if (additionalVal.IsBool() && !(bool)additionalVal)
					{
						if (count > itemsArr.Count)
							valid = Fail("additionalItems", schemaPointer, instancePointer, "Array has additional items not allowed", collectErrors);
					}
					else if (additionalVal.IsObject() || additionalVal.IsBool())
					{
						let additionalSchemaPtr = scope String();
						SchemaUri.BuildPointer(schemaPointer, "additionalItems", additionalSchemaPtr);
						for (int i = itemsArr.Count; i < count; i++)
						{
							let childInstancePtr = scope String();
							BuildIndexPointer(instancePointer, i, childInstancePtr);
							valid &= Try!(ValidateSchema(doc, additionalVal, additionalSchemaPtr, arr[i], childInstancePtr, collectErrors));
						}
					}
				}
			}
		}

		return .Ok(valid);
	}

	/// contains, minContains, and maxContains all read the same match count, so one pass over
	/// the array serves all three. The count is taken without collecting errors: a non-matching
	/// item is not a failure by itself.
	private Result<bool, JsonSchemaError> ValidateContains(JsonObject schemaObj, SchemaDocument doc, JsonValue containsVal, JsonArray arr, StringView instancePointer, StringView schemaPointer, bool collectErrors)
	{
		bool valid = true;
		let containsSchemaPtr = scope String();
		SchemaUri.BuildPointer(schemaPointer, "contains", containsSchemaPtr);

		int matchCount = 0;
		for (int i = 0; i < arr.Count; i++)
		{
			let childInstancePtr = scope String();
			BuildIndexPointer(instancePointer, i, childInstancePtr);
			if (Try!(ValidateSchema(doc, containsVal, containsSchemaPtr, arr[i], childInstancePtr, false)))
				matchCount++;
		}

		int minContains = 1;
		bool hasMinContains = false;
		if (schemaObj.TryGet("minContains") case .Ok(let minContainsVal))
		{
			if (minContainsVal.IsNumber())
			{
				minContains = (int)(double)minContainsVal;
				hasMinContains = true;
			}
		}

		if (matchCount < minContains)
		{
			if (hasMinContains)
				valid = Fail("minContains", schemaPointer, instancePointer, "Array has fewer matching items than minContains", collectErrors);
			else
				valid = Fail("contains", schemaPointer, instancePointer, "Array does not contain a matching item", collectErrors);
		}

		if (schemaObj.TryGet("maxContains") case .Ok(let maxContainsVal))
		{
			if (maxContainsVal.IsNumber() && (matchCount > (int)(double)maxContainsVal))
				valid = Fail("maxContains", schemaPointer, instancePointer, "Array has more matching items than maxContains", collectErrors);
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
			if (minVal.IsNumber() && (count < (int)(double)minVal))
				valid = Fail("minProperties", schemaPointer, instancePointer, "Object has fewer properties than minProperties", collectErrors);
		}

		if (schemaObj.TryGet("maxProperties") case .Ok(let maxVal))
		{
			if (maxVal.IsNumber() && (count > (int)(double)maxVal))
				valid = Fail("maxProperties", schemaPointer, instancePointer, "Object has more properties than maxProperties", collectErrors);
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
					if (!reqItem.IsString())
						continue;

					let key = (StringView)reqItem;
					if (!obj.ContainsKey(key))
					{
						// The error points at the missing member, not at the object.
						let childInstancePtr = scope String();
						SchemaUri.BuildPointer(instancePointer, key, childInstancePtr);
						valid = Fail("required", schemaPointer, childInstancePtr, "Required property is missing", collectErrors);
					}
				}
			}
		}

		if (schemaObj.TryGet("propertyNames") case .Ok(let propNamesVal))
		{
			if (propNamesVal.IsObject() || propNamesVal.IsBool())
			{
				let propNamesSchemaPtr = scope String();
				SchemaUri.BuildPointer(schemaPointer, "propertyNames", propNamesSchemaPtr);
				for (var kv in obj)
				{
					let childInstancePtr = scope String();
					SchemaUri.BuildPointer(instancePointer, kv.key, childInstancePtr);
					var nameValue = JsonString(kv.key);
					let result = ValidateSchema(doc, propNamesVal, propNamesSchemaPtr, nameValue, childInstancePtr, collectErrors);
					nameValue.Dispose();
					valid &= Try!(result);
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
					valid &= Try!(ValidateSchema(doc, propSchema, childSchemaPtr, value, childInstancePtr, collectErrors));
					handled = true;
				}
			}

			if (!handled && hasAdditional)
			{
				if (additionalSchema.IsBool())
				{
					if (!(bool)additionalSchema)
					{
						let childInstancePtr = scope String();
						SchemaUri.BuildPointer(instancePointer, key, childInstancePtr);
						valid = Fail("additionalProperties", schemaPointer, childInstancePtr, "Additional properties not allowed", collectErrors);
					}
				}
				else if (additionalSchema.IsObject())
				{
					let childInstancePtr = scope String();
					SchemaUri.BuildPointer(instancePointer, key, childInstancePtr);
					let childSchemaPtr = scope String();
					SchemaUri.BuildPointer(schemaPointer, "additionalProperties", childSchemaPtr);
					valid &= Try!(ValidateSchema(doc, additionalSchema, childSchemaPtr, value, childInstancePtr, collectErrors));
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
				let baseSchemaPtr = scope String();
				SchemaUri.BuildPointer(schemaPointer, "allOf", baseSchemaPtr);
				for (int i = 0; i < allOfArr.Count; i++)
				{
					let childSchemaPtr = scope String();
					BuildIndexPointer(baseSchemaPtr, i, childSchemaPtr);
					valid &= Try!(ValidateSchema(doc, allOfArr[i], childSchemaPtr, instance, instancePointer, collectErrors));
				}
			}
		}

		if (schemaObj.TryGet("anyOf") case .Ok(let anyOfVal))
		{
			if (anyOfVal.IsArray())
			{
				bool matched = false;
				let anyOfArr = anyOfVal.As<JsonArray>();
				let baseSchemaPtr = scope String();
				SchemaUri.BuildPointer(schemaPointer, "anyOf", baseSchemaPtr);
				for (int i = 0; i < anyOfArr.Count; i++)
				{
					let childSchemaPtr = scope String();
					BuildIndexPointer(baseSchemaPtr, i, childSchemaPtr);
					if (Try!(ValidateSchema(doc, anyOfArr[i], childSchemaPtr, instance, instancePointer, false)))
					{
						matched = true;
						break;
					}
				}

				if (!matched)
					valid = Fail("anyOf", schemaPointer, instancePointer, "anyOf did not match any subschema", collectErrors);
			}
		}

		if (schemaObj.TryGet("oneOf") case .Ok(let oneOfVal))
		{
			if (oneOfVal.IsArray())
			{
				int matches = 0;
				let oneOfArr = oneOfVal.As<JsonArray>();
				let baseSchemaPtr = scope String();
				SchemaUri.BuildPointer(schemaPointer, "oneOf", baseSchemaPtr);
				for (int i = 0; i < oneOfArr.Count; i++)
				{
					let childSchemaPtr = scope String();
					BuildIndexPointer(baseSchemaPtr, i, childSchemaPtr);
					if (Try!(ValidateSchema(doc, oneOfArr[i], childSchemaPtr, instance, instancePointer, false)))
						matches++;
				}

				if (matches != 1)
					valid = Fail("oneOf", schemaPointer, instancePointer, "oneOf did not match exactly one subschema", collectErrors);
			}
		}

		// not and if recurse with the keyword-extended pointer, like then, else, and allOf, so a
		// nested $id under /not or /if resolves against the base URI indexed for that location.
		if (schemaObj.TryGet("not") case .Ok(let notVal))
		{
			let notSchemaPtr = scope String();
			SchemaUri.BuildPointer(schemaPointer, "not", notSchemaPtr);
			if (Try!(ValidateSchema(doc, notVal, notSchemaPtr, instance, instancePointer, false)))
				valid = Fail("not", schemaPointer, instancePointer, "not schema matched", collectErrors);
		}

		if (schemaObj.TryGet("if") case .Ok(let ifVal))
		{
			let ifSchemaPtr = scope String();
			SchemaUri.BuildPointer(schemaPointer, "if", ifSchemaPtr);
			let ifMatched = Try!(ValidateSchema(doc, ifVal, ifSchemaPtr, instance, instancePointer, false));

			if (ifMatched)
			{
				if (schemaObj.TryGet("then") case .Ok(let thenVal))
				{
					let thenSchemaPtr = scope String();
					SchemaUri.BuildPointer(schemaPointer, "then", thenSchemaPtr);
					valid &= Try!(ValidateSchema(doc, thenVal, thenSchemaPtr, instance, instancePointer, collectErrors));
				}
			}
			else
			{
				if (schemaObj.TryGet("else") case .Ok(let elseVal))
				{
					let elseSchemaPtr = scope String();
					SchemaUri.BuildPointer(schemaPointer, "else", elseSchemaPtr);
					valid &= Try!(ValidateSchema(doc, elseVal, elseSchemaPtr, instance, instancePointer, collectErrors));
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
			return IsIntegerForTypeKeyword(instance);
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

	/// The type keyword counts an exact integral double as an integer, so 1.0 satisfies "integer".
	private bool IsIntegerForTypeKeyword(JsonValue value)
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

	/// A double cannot hold divisors such as 0.1 exactly, so the quotient is measured
	/// against the nearest integer within a relative tolerance rather than by remainder.
	private bool IsMultipleOf(double value, double divisor)
	{
		if (value == 0)
			return true;

		let quotient = value / divisor;
		let nearest = Math.Round(quotient);
		let tolerance = (1e-9 * Math.Abs(quotient)) + 1e-12;
		return Math.Abs(quotient - nearest) <= tolerance;
	}

	/// minLength and maxLength are defined over code points, while StringView.Length
	/// counts UTF-8 bytes.
	private int CountCodePoints(StringView text)
	{
		int count = 0;
		var chars = text.DecodedChars;
		while (chars.MoveNext())
			count++;
		return count;
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
			return NumberEquals(a, b);

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
			return NumberEquals(a, b);
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

	/// Two integer typed numbers compare as integers so that values above 2^53 stay
	/// distinct. A mixed integer and double pair falls back to double comparison, which
	/// is what keeps 1 equal to 1.0 as the spec requires.
	private bool NumberEquals(JsonValue a, JsonValue b)
	{
		if (a.type == .NUMBER_UNSIGNED && b.type == .NUMBER_UNSIGNED)
			return (uint)a == (uint)b;

		if (HasIntegerTag(a) && HasIntegerTag(b))
		{
			if (a.type == .NUMBER_UNSIGNED && (uint)a > (uint)int.MaxValue)
				return false;
			if (b.type == .NUMBER_UNSIGNED && (uint)b > (uint)int.MaxValue)
				return false;
			return (int)a == (int)b;
		}

		return (double)a == (double)b;
	}

	/// NumberEquals needs the storage tag, not the value: only tagged integers compare as int64,
	/// which is what keeps values above 2^53 distinct.
	private bool HasIntegerTag(JsonValue value)
	{
		return value.type == .NUMBER_SIGNED || value.type == .NUMBER_UNSIGNED;
	}

	/// The guard is keyed on the reference paired with the instance location: a recursive
	/// $ref descends into nested instances, while a $ref that reaches itself without
	/// consuming instance is a real cycle.
	private bool IsRefOnStack(StringView resolvedRef, StringView instancePointer)
	{
		for (var frame in mRefStack)
		{
			if (frame.Reference == resolvedRef && frame.InstancePointer == instancePointer)
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
