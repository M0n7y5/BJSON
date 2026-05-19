using System;
using System.Collections;
using BJSON;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON.SchemaCodeGen;

class SchemaParser
{
	public List<String> Warnings = new List<String>() ~ DeleteContainerAndItems!(_);
	
	public Result<void, SchemaError> ExtractTitle(StringView schemaJson, String output)
	{
		Result<JsonValue, JsonParsingError> parseResult = BJSON.Json.Deserialize(schemaJson);
		defer parseResult.Dispose();
		
		if (parseResult case .Err)
		{
			return .Err(.JsonError);
		}
		
		if (parseResult case .Ok(let jsonValue))
		{
			if (jsonValue.IsObject())
			{
				let obj = jsonValue.As<JsonObject>();
				if (obj.TryGet("title") case .Ok(let titleVal))
				{
					if (titleVal.IsString())
					{
						ToPascalCase((StringView)titleVal, output);
					}
				}
			}
		}
		
		return .Ok;
	}
	
	public Result<SchemaModel, SchemaError> Parse(StringView schemaJson, StringView rootName)
	{
		ClearAndDeleteItems(Warnings);
		
		Result<JsonValue, JsonParsingError> parseResult = BJSON.Json.Deserialize(schemaJson);
		defer parseResult.Dispose();
		
		if (parseResult case .Err)
		{
			return .Err(.JsonError);
		}
		
		if (parseResult case .Ok(let jsonValue))
		{
			return ParseSchema(jsonValue, rootName);
		}
		
		return .Err(.InvalidSchema);
	}
	
	private Result<SchemaModel, SchemaError> ParseSchema(JsonValue json, StringView name)
	{
		var model = new SchemaModel();
		model.Name.Set(name);
		
		if (!json.IsObject())
		{
			AddWarning(scope $"Schema '{name}' is not an object; using JsonValue fallback.");
			model.Type = .Any;
			return .Ok(model);
		}
		
		let obj = json.As<JsonObject>();
		
		if (obj.TryGet("title") case .Ok(let titleVal))
		{
			if (titleVal.IsString())
			{
				String titleName = scope String();
				ToPascalCase((StringView)titleVal, titleName);
				if (!titleName.IsEmpty)
				{
					model.Name.Set(titleName);
				}
			}
		}
		
		if (obj.TryGet("description") case .Ok(let desc))
		{
			if (desc.IsString())
			{
				model.Description.Set((StringView)desc);
			}
		}
		
		AddUnsupportedWarnings(obj, model.Name);
		
		if (ParseDefinitionMap(obj, "$defs", model.Defs, model.Name) case .Err(let defsErr))
		{
			delete model;
			return .Err(defsErr);
		}
		
		if (ParseDefinitionMap(obj, "definitions", model.Definitions, model.Name) case .Err(let definitionsErr))
		{
			delete model;
			return .Err(definitionsErr);
		}
		
		if (obj.TryGet("$ref") case .Ok(let refVal))
		{
			if (refVal.IsString())
			{
				model.Type = .Ref;
				model.RefPath.Set((StringView)refVal);
				return .Ok(model);
			}
			
			AddWarning(scope $"Schema '{model.Name}' has a non-string $ref; using JsonValue fallback.");
			model.Type = .Any;
			return .Ok(model);
		}
		
		if (obj.TryGet("type") case .Ok(let typeVal))
		{
			ParseType(typeVal, model);
		}
		else
		{
			model.Type = .Any;
		}
		
		if (obj.TryGet("enum") case .Ok(let enumVal))
		{
			if (enumVal.IsArray())
			{
				bool hasStringValues = false;
				for (var item in enumVal.As<JsonArray>())
				{
					if (item.IsString())
					{
						model.EnumValues.Add(new String((StringView)item));
						hasStringValues = true;
					}
					else
					{
						AddWarning(scope $"Schema '{model.Name}' has a non-string enum value; ignoring it.");
					}
				}
				
				if (hasStringValues)
				{
					model.Type = .Enum;
				}
				else
				{
					AddWarning(scope $"Schema '{model.Name}' has no string enum values; using JsonValue fallback.");
				}
			}
			else
			{
				AddWarning(scope $"Schema '{model.Name}' has a non-array enum; using JsonValue fallback.");
			}
		}
		
		if (obj.TryGet("properties") case .Ok(let props))
		{
			if (props.IsObject())
			{
				if (model.Type == .Any)
				{
					model.Type = .Object;
				}
				
				var dict = props.As<JsonObject>();
				for (var kvp in dict)
				{
					StringView propName = kvp.key;
					var propModel = new PropertyModel();
					propModel.JsonName.Set(propName);
					var pascalName = ToPascalCase(propName);
					propModel.Name.Set(pascalName);
					delete pascalName;
					
					String nestedName = scope String();
					nestedName.Append(model.Name);
					nestedName.Append(propModel.Name);
					
					var nestedResult = ParseSchema(kvp.value, nestedName);
					if (nestedResult case .Err(let nestedErr))
					{
						delete propModel;
						delete model;
						return .Err(nestedErr);
					}
					
					if (nestedResult case .Ok(let nestedSchema))
					{
						propModel.Schema = nestedSchema;
						propModel.Description.Set(nestedSchema.Description);
					}
					
					var keyClone = new String(kvp.key);
					model.Properties.Add(keyClone, propModel);
				}
			}
			else
			{
				AddWarning(scope $"Schema '{model.Name}' has non-object properties; ignoring them.");
			}
		}
		
		if (obj.TryGet("required") case .Ok(let reqVal))
		{
			if (reqVal.IsArray())
			{
				for (var item in reqVal.As<JsonArray>())
				{
					if (item.IsString())
					{
						StringView sv = (StringView)item;
						model.Required.Add(new String(sv));
						String matchKey;
						PropertyModel prop;
						if (model.Properties.TryGetAlt(sv, out matchKey, out prop))
						{
							prop.IsRequired = true;
						}
					}
					else
					{
						AddWarning(scope $"Schema '{model.Name}' has a non-string required entry; ignoring it.");
					}
				}
			}
			else
			{
				AddWarning(scope $"Schema '{model.Name}' has non-array required; ignoring it.");
			}
		}
		
		if (obj.TryGet("items") case .Ok(let items))
		{
			if (model.Type == .Any)
			{
				model.Type = .Array;
			}
			
			String itemName = scope String();
			itemName.Append(model.Name);
			itemName.Append("Item");
			
			JsonValue itemSchema = items;
			if (items.IsArray())
			{
				AddWarning(scope $"Schema '{model.Name}' uses tuple array items; using the first item schema only.");
				let itemsArray = items.As<JsonArray>();
				if (itemsArray.Count > 0)
				{
					itemSchema = itemsArray[0];
				}
			}
			
			var itemsParseResult = ParseSchema(itemSchema, itemName);
			if (itemsParseResult case .Err(let itemsErr))
			{
				delete model;
				return .Err(itemsErr);
			}
			
			if (itemsParseResult case .Ok(let itemsModel))
			{
				model.Items = itemsModel;
			}
		}
		
		if (obj.TryGet("allOf") case .Ok(let allOfVal))
		{
			if (allOfVal.IsArray())
			{
				if (model.Type == .Any)
				{
					model.Type = .Object;
				}
				
				int i = 0;
				for (var item in allOfVal.As<JsonArray>())
				{
					String subName = scope String();
					subName.Append(model.Name);
					subName.Append("Base");
					subName.Append(i);
					
					var subResult = ParseSchema(item, subName);
					if (subResult case .Err(let allOfErr))
					{
						delete model;
						return .Err(allOfErr);
					}
					
					if (subResult case .Ok(let subModel))
					{
						subModel.Emit = false;
						model.AllOf.Add(subModel);
					}
					i++;
				}
			}
			else
			{
				AddWarning(scope $"Schema '{model.Name}' has non-array allOf; ignoring it.");
			}
		}
		
		return .Ok(model);
	}
	
	private Result<void, SchemaError> ParseDefinitionMap(JsonObject obj, StringView keyword, Dictionary<String, SchemaModel> target, StringView ownerName)
	{
		let defsResult = obj.TryGet(keyword);
		if (defsResult case .Err)
		{
			return .Ok;
		}
		
		JsonValue defsVal = default;
		if (defsResult case .Ok(let val))
		{
			defsVal = val;
		}
		
		if (!defsVal.IsObject())
		{
			AddWarning(scope $"Schema '{ownerName}' has non-object {keyword}; ignoring it.");
			return .Ok;
		}
		
		let defsObj = defsVal.As<JsonObject>();
		for (var kvp in defsObj)
		{
			String defName = scope String();
			ToPascalCase(kvp.key, defName);
			if (defName.IsEmpty)
			{
				defName.Append(ownerName);
				defName.Append("Definition");
			}
			
			var defResult = ParseSchema(kvp.value, defName);
			if (defResult case .Err(let err))
			{
				return .Err(err);
			}
			
			if (defResult case .Ok(let defSchema))
			{
				target.Add(new String(kvp.key), defSchema);
			}
		}
		
		return .Ok;
	}
	
	private void ParseType(JsonValue typeVal, SchemaModel model)
	{
		if (typeVal.IsString())
		{
			StringView typeStr = (StringView)typeVal;
			switch (typeStr)
			{
			case "string": model.Type = .String;
			case "integer": model.Type = .Integer;
			case "number": model.Type = .Number;
			case "boolean": model.Type = .Boolean;
			case "array": model.Type = .Array;
			case "object": model.Type = .Object;
			case "null": model.Type = .Any;
			default:
				model.Type = .Any;
				AddWarning(scope $"Schema '{model.Name}' has unsupported type '{typeStr}'; using JsonValue fallback.");
			}
		}
		else if (typeVal.IsArray())
		{
			bool hasNull = false;
			StringView firstType = default;
			int nonNullTypeCount = 0;
			
			for (var item in typeVal.As<JsonArray>())
			{
				if (item.IsString())
				{
					StringView s = (StringView)item;
					if (s == "null")
					{
						hasNull = true;
					}
					else if (firstType.IsEmpty)
					{
						firstType = s;
						nonNullTypeCount++;
					}
					else
					{
						nonNullTypeCount++;
					}
				}
			}
			
			model.IsNullable = hasNull;
			
			switch (firstType)
			{
			case "string": model.Type = .String;
			case "integer": model.Type = .Integer;
			case "number": model.Type = .Number;
			case "boolean": model.Type = .Boolean;
			case "array": model.Type = .Array;
			case "object": model.Type = .Object;
			default: model.Type = .Any;
			}
			
			if (nonNullTypeCount > 1)
			{
				AddWarning(scope $"Schema '{model.Name}' uses a multi-type union; using the first non-null type.");
			}
		}
		else
		{
			model.Type = .Any;
			AddWarning(scope $"Schema '{model.Name}' has non-string type; using JsonValue fallback.");
		}
	}
	
	private void AddUnsupportedWarnings(JsonObject obj, StringView schemaName)
	{
		for (var kvp in obj)
		{
			switch (kvp.key)
			{
			case "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf",
				"minLength", "maxLength", "format", "pattern",
				"minItems", "maxItems", "uniqueItems", "contains", "minContains", "maxContains",
				"minProperties", "maxProperties", "additionalProperties", "patternProperties",
				"propertyNames", "dependentSchemas", "dependentRequired", "dependencies",
				"unevaluatedItems", "unevaluatedProperties":
				AddWarning(scope $"Ignoring validation keyword '{kvp.key}' in schema '{schemaName}'.");
			case "anyOf", "oneOf", "not", "if", "then", "else", "const", "$dynamicRef", "$dynamicAnchor":
				AddWarning(scope $"Unsupported schema keyword '{kvp.key}' in schema '{schemaName}'; structural generation will ignore it.");
			default:
			}
		}
	}
	
	private void AddWarning(StringView message)
	{
		Warnings.Add(new String(message));
	}
	
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
			else
			{
				if (output.IsEmpty && isDigit)
				{
					output.Append("_");
				}
				
				if (nextUpper)
				{
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
	
	private String ToPascalCase(StringView input)
	{
		var result = new String();
		ToPascalCase(input, result);
		return result;
	}
}

enum SchemaError
{
	case JsonError;
	case InvalidSchema;
	case UnresolvedRef;
	case CircularRef;
}
