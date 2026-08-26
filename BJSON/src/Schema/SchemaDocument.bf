using System;
using System.Collections;
using BJSON.Models;

namespace BJSON;

/// A parsed schema document plus the base URI, $anchor, and $id indexes built from it.
/// Owns Root and disposes it, which is how a JsonSchema owns the tree handed to it.
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

	/// Base URI in effect at `pointer`, viewing this document's storage; falls back to BaseUri
	/// for pointers that were not indexed.
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
