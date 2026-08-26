using System;
using System.Collections;
using BJSON;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON.SchemaCodeGen;

class SchemaParser
{
	/// Node list of the current Parse call, owned by the caller of Parse. Non owning.
	private List<SchemaModel> mNodes;

	/// Parses a JSON Schema document into SchemaModel nodes.
	/// Every node is appended to outNodes, the root first, so the caller frees the whole graph
	/// with one pass over that list, on the error path as well.
	/// @param schemaJson The schema document.
	/// @param rootName Type name for the root schema, already PascalCase.
	/// @param preferTitle When true a `title` keyword replaces the derived name of a schema.
	/// @param outNodes Caller owned list that receives every node this call allocates.
	/// @returns .Ok when the document was parsed, otherwise the first construct that failed.
	public Result<void, SchemaError> Parse(StringView schemaJson, StringView rootName, bool preferTitle, List<SchemaModel> outNodes)
	{
		mNodes = outNodes;

		Result<JsonValue, JsonParsingError> parseResult = BJSON.Json.Deserialize(schemaJson);
		defer parseResult.Dispose();

		if (parseResult case .Err)
		{
			return .Err(.JsonError);
		}

		if (parseResult case .Ok(let jsonValue))
		{
			if (!jsonValue.IsObject())
			{
				return .Err(.InvalidSchema);
			}

			if (ParseSchema(jsonValue, rootName, "#", preferTitle) case .Err(let err))
			{
				return .Err(err);
			}

			return .Ok;
		}

		return .Err(.InvalidSchema);
	}

	/// Parses one schema into a new node.
	/// @param json The schema value.
	/// @param name Derived type name for the node.
	/// @param pointer JSON Pointer of this schema, prefixed with '#'.
	/// @param preferTitle When true a `title` keyword replaces name.
	/// @returns The new node, owned by the node list of this Parse call.
	private Result<SchemaModel, SchemaError> ParseSchema(JsonValue json, StringView name, StringView pointer, bool preferTitle)
	{
		var model = NewNode(name, pointer);

		if (preferTitle)
		{
			Result<JsonValue, JsonPointerError> titleResult = json.GetByPointer("/title");
			if (titleResult case .Ok(let title))
			{
				if (title.IsString())
				{
					String titleName = scope String();
					ToPascalCase((StringView)title, titleName);
					if (!titleName.IsEmpty)
					{
						model.Name.Set(titleName);
					}
				}
			}
		}

		Result<JsonValue, JsonPointerError> descResult = json.GetByPointer("/description");
		if (descResult case .Ok(let desc))
		{
			if (desc.IsString())
			{
				model.Description.Set((StringView)desc);
			}
		}

		if (ParseDefinitions(json, "definitions", pointer) case .Err(let definitionsErr))
		{
			return .Err(definitionsErr);
		}

		if (ParseDefinitions(json, "$defs", pointer) case .Err(let defsErr))
		{
			return .Err(defsErr);
		}

		Result<JsonValue, JsonPointerError> refResult = json.GetByPointer("/$ref");
		if (refResult case .Ok(let refVal))
		{
			if (refVal.IsString())
			{
				model.Type = .Ref;
				model.RefPath.Set((StringView)refVal);
				return .Ok(model);
			}
		}

		Result<JsonValue, JsonPointerError> typeResult = json.GetByPointer("/type");
		if (typeResult case .Ok(let typeVal))
		{
			Try!(ParseType(typeVal, model));
		}
		else
		{
			model.Type = .Any;
		}

		Result<JsonValue, JsonPointerError> enumResult = json.GetByPointer("/enum");
		if (enumResult case .Ok(let enumVal))
		{
			if (!enumVal.IsArray())
			{
				return .Err(.UnsupportedKeyword("enum", "must be an array"));
			}

			model.Type = .Enum;
			for (var item in enumVal.As<JsonArray>())
			{
				if (!item.IsString())
				{
					return .Err(.UnsupportedKeyword("enum", "a Beef enum can only carry the string values of an enumeration"));
				}

				model.EnumValues.Add(new String((StringView)item));
			}

			if (model.EnumValues.IsEmpty)
			{
				return .Err(.UnsupportedKeyword("enum", "must list at least one value"));
			}
		}

		Result<JsonValue, JsonPointerError> propsResult = json.GetByPointer("/properties");
		if (propsResult case .Ok(let props))
		{
			if (!props.IsObject())
			{
				return .Err(.UnsupportedKeyword("properties", "must be an object"));
			}

			var dict = props.As<JsonObject>();
			for (var kvp in dict)
			{
				// The property joins its owner before it is filled in, so an error below frees it
				// with the rest of the graph.
				var propModel = new PropertyModel();
				model.Properties.Add(new String(kvp.key), propModel);

				propModel.JsonName.Set(kvp.key);
				ToPascalCase(kvp.key, propModel.Name);

				if (propModel.Name.IsEmpty)
				{
					return .Err(.UnsupportedKeyword("properties", "a property name needs a letter or a digit to become a field name"));
				}

				String propPointer = scope String(pointer);
				propPointer.Append("/properties/");
				AppendPointerToken(kvp.key, propPointer);

				String nestedName = scope String();
				nestedName.Append(model.Name);
				nestedName.Append(propModel.Name);

				if (kvp.value.IsObject())
				{
					var nestedResult = ParseSchema(kvp.value, nestedName, propPointer, true);
					if (nestedResult case .Err(let nestedErr))
					{
						return .Err(nestedErr);
					}

					if (nestedResult case .Ok(let nestedSchema))
					{
						propModel.Schema = nestedSchema;
					}
				}
				else if (kvp.value.IsBool())
				{
					// A boolean schema: `true` accepts every value, `false` accepts none.
					if (!(bool)kvp.value)
					{
						return .Err(.UnsupportedKeyword("properties", "a `false` schema accepts no value, so the property cannot be generated"));
					}

					var anySchema = NewNode(nestedName, propPointer);
					anySchema.Type = .Any;
					propModel.Schema = anySchema;
				}
				else
				{
					return .Err(.UnsupportedKeyword("properties", "a property schema must be an object or a boolean"));
				}

				Result<JsonValue, JsonPointerError> propDescResult = kvp.value.GetByPointer("/description");
				if (propDescResult case .Ok(let propDesc))
				{
					if (propDesc.IsString())
					{
						propModel.Description.Set((StringView)propDesc);
					}
				}
			}
		}

		Result<JsonValue, JsonPointerError> reqResult = json.GetByPointer("/required");
		if (reqResult case .Ok(let reqVal))
		{
			if (!reqVal.IsArray())
			{
				return .Err(.UnsupportedKeyword("required", "must be an array"));
			}

			// TypeResolver applies these names once `allOf` members have been merged in, so a name
			// that only an inherited property carries still reaches the generated field.
			for (var item in reqVal.As<JsonArray>())
			{
				if (!item.IsString())
				{
					return .Err(.UnsupportedKeyword("required", "must list property names as strings"));
				}

				model.Required.Add(new String((StringView)item));
			}
		}

		Result<JsonValue, JsonPointerError> itemsResult = json.GetByPointer("/items");
		if (itemsResult case .Ok(let items))
		{
			if (!items.IsObject())
			{
				return .Err(.UnsupportedKeyword("items", "only a single object schema is supported, not a tuple of schemas or a boolean"));
			}

			String itemName = scope String();
			itemName.Append(model.Name);
			itemName.Append("Item");

			String itemPointer = scope String(pointer);
			itemPointer.Append("/items");

			model.Items = Try!(ParseSchema(items, itemName, itemPointer, true));
		}

		Result<JsonValue, JsonPointerError> allOfResult = json.GetByPointer("/allOf");
		if (allOfResult case .Ok(let allOfVal))
		{
			if (!allOfVal.IsArray())
			{
				return .Err(.UnsupportedKeyword("allOf", "must be an array"));
			}

			int i = 0;
			for (var item in allOfVal.As<JsonArray>())
			{
				if (!item.IsObject())
				{
					return .Err(.UnsupportedKeyword("allOf", "every member must be an object schema"));
				}

				String subName = scope String();
				subName.Append(model.Name);
				subName.Append("Base");
				subName.Append(i);

				String subPointer = scope String(pointer);
				subPointer.Append("/allOf/");
				subPointer.Append(i);

				var subSchema = Try!(ParseSchema(item, subName, subPointer, true));
				model.AllOf.Add(subSchema);
				i++;
			}
		}

		// A schema that carries members but no `type` still describes a class or a list.
		if (model.Type == .Any)
		{
			if (!model.Properties.IsEmpty || !model.AllOf.IsEmpty)
			{
				model.Type = .Object;
			}
			else if (model.Items != null)
			{
				model.Type = .Array;
			}
		}

		return .Ok(model);
	}

	/// Parses the members of `definitions` or `$defs` so that `$ref` can reach them.
	/// @param json The schema that declares the keyword.
	/// @param keyword The keyword to read. MUST be a string literal: it reaches SchemaError
	///                payloads, which outlive this call.
	/// @param pointer JSON Pointer of json, prefixed with '#'.
	private Result<void, SchemaError> ParseDefinitions(JsonValue json, StringView keyword, StringView pointer)
	{
		String keywordPointer = scope String("/");
		keywordPointer.Append(keyword);

		Result<JsonValue, JsonPointerError> defsResult = json.GetByPointer(keywordPointer);
		if (defsResult case .Ok(let defs))
		{
			if (!defs.IsObject())
			{
				return .Err(.UnsupportedKeyword(keyword, "must be an object"));
			}

			for (var kvp in defs.As<JsonObject>())
			{
				if (!kvp.value.IsObject())
				{
					return .Err(.UnsupportedKeyword(keyword, "every member must be an object schema"));
				}

				String defName = scope String();
				ToPascalCase(kvp.key, defName);

				String defPointer = scope String(pointer);
				defPointer.Append('/');
				defPointer.Append(keyword);
				defPointer.Append('/');
				AppendPointerToken(kvp.key, defPointer);

				if (ParseSchema(kvp.value, defName, defPointer, true) case .Err(let err))
				{
					return .Err(err);
				}
			}
		}

		return .Ok;
	}

	/// Allocates a node and hands it to the node list of this Parse call, which owns it.
	private SchemaModel NewNode(StringView name, StringView pointer)
	{
		var model = new SchemaModel();
		mNodes.Add(model);
		model.Name.Set(name);
		model.Pointer.Set(pointer);

		return model;
	}

	private Result<void, SchemaError> ParseType(JsonValue typeVal, SchemaModel model)
	{
		if (typeVal.IsString())
		{
			return MapTypeName((StringView)typeVal, model);
		}

		if (typeVal.IsArray())
		{
			bool hasNull = false;
			bool hasFirstType = false;
			// An SSO string lives inside the JsonValue, so the name has to be copied out before
			// the loop variable goes away.
			String firstType = scope String();

			for (var item in typeVal.As<JsonArray>())
			{
				if (!item.IsString())
				{
					return .Err(.UnsupportedKeyword("type", "must name types as strings"));
				}

				StringView s = (StringView)item;
				if (s == "null")
				{
					hasNull = true;
				}
				else if (!hasFirstType)
				{
					firstType.Set(s);
					hasFirstType = true;
				}
				else
				{
					return .Err(.UnsupportedKeyword("type", "a union of more than one non null type has no single Beef type"));
				}
			}

			model.IsNullable = hasNull;

			if (!hasFirstType)
			{
				model.Type = .Any;
				return .Ok;
			}

			return MapTypeName(firstType, model);
		}

		return .Err(.UnsupportedKeyword("type", "must be a string or an array of strings"));
	}

	private Result<void, SchemaError> MapTypeName(StringView typeName, SchemaModel model)
	{
		switch (typeName)
		{
		case "string": model.Type = .String;
		case "integer": model.Type = .Integer;
		case "number": model.Type = .Number;
		case "boolean": model.Type = .Boolean;
		case "array": model.Type = .Array;
		case "object": model.Type = .Object;
		case "null": model.Type = .Any;
		default:
			return .Err(.UnsupportedKeyword("type", "names no JSON Schema type"));
		}

		return .Ok;
	}

	/// Appends one RFC 6901 reference token, escaping '~' as "~0" and '/' as "~1".
	private void AppendPointerToken(StringView token, String output)
	{
		for (int i = 0; i < token.Length; i++)
		{
			char8 c = token[i];
			if (c == '~')
			{
				output.Append("~0");
			}
			else if (c == '/')
			{
				output.Append("~1");
			}
			else
			{
				output.Append(c);
			}
		}
	}

	/// Turns a JSON name into a Beef identifier: every character that cannot appear in one acts as
	/// a word separator, and a leading digit gets an underscore in front of it.
	/// The result is empty when the name carries no letter and no digit.
	private void ToPascalCase(StringView input, String output)
	{
		bool nextUpper = true;
		for (int i = 0; i < input.Length; i++)
		{
			char8 c = input[i];
			bool isLetter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
			bool isDigit = c >= '0' && c <= '9';
			if (!isLetter && !isDigit)
			{
				nextUpper = true;
			}
			else if (nextUpper)
			{
				if (output.IsEmpty && isDigit)
				{
					output.Append('_');
				}
				
				if (c >= 'a' && c <= 'z')
				{
					output.Append((char8)(c - 32));
				}
				else
				{
					output.Append(c);
				}
				nextUpper = false;
			}
			else
			{
				output.Append(c);
			}
		}
	}
}

enum SchemaError
{
	/// The document is not valid JSON.
	case JsonError;
	/// The document is not a schema object.
	case InvalidSchema;
	/// A `$ref` names a target the document does not define.
	case UnresolvedRef;
	/// `allOf` inheritance forms a cycle.
	case CircularRef;
	/// A keyword the generator cannot represent. Both payloads MUST be static text, string
	/// literals in practice: an error outlives the call that produced it.
	case UnsupportedKeyword(StringView keyword, StringView reason);
	/// A generated type has no usable name.
	case UnnamedType;

	public override void ToString(String string)
	{
		switch (this)
		{
		case JsonError:
			string.Append("Schema document is not valid JSON.");
		case InvalidSchema:
			string.Append("Schema document is not a JSON object.");
		case UnresolvedRef:
			string.Append("A $ref names a target that the document does not define.");
		case CircularRef:
			string.Append("A $ref chain or allOf inheritance forms a cycle.");
		case UnsupportedKeyword(let keyword, let reason):
			string.AppendF("Unsupported schema keyword '{}': {}.", keyword, reason);
		case UnnamedType:
			string.Append("A generated type has no name: add a title to the schema or pass -c.");
		}
	}
}
