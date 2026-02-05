using System;
using System.Collections;
using BJSON;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON.SchemaCodeGen;

class SchemaParser
{
	public Result<SchemaModel, SchemaError> Parse(StringView schemaJson, StringView rootName)
	{
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
		
		Result<JsonValue, JsonPointerError> descResult = json.GetByPointer("/description");
		if (descResult case .Ok(let desc))
		{
			if (desc.IsString())
			{
				model.Description.Set((StringView)desc);
			}
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
			ParseType(typeVal, model);
		}
		else
		{
			model.Type = .Any;
		}
		
		Result<JsonValue, JsonPointerError> enumResult = json.GetByPointer("/enum");
		if (enumResult case .Ok(let enumVal))
		{
			if (enumVal.IsArray())
			{
				model.Type = .Enum;
				for (var item in enumVal.As<JsonArray>())
				{
					if (item.IsString())
					{
						model.EnumValues.Add(new String((StringView)item));
					}
				}
			}
		}
		
		Result<JsonValue, JsonPointerError> propsResult = json.GetByPointer("/properties");
		if (propsResult case .Ok(let props))
		{
			if (props.IsObject())
			{
				var dict = props.As<JsonObject>();
				for (var kvp in dict)
				{
				StringView propName = kvp.key;
				var propModel = new PropertyModel();
				propModel.JsonName.Set(propName);
				var pascalName = ToPascalCase(propName);
				propModel.Name.Set(pascalName);
				delete pascalName;
					
					if (kvp.value.IsObject())
					{
						String nestedName = scope String();
						nestedName.Append(model.Name);
						nestedName.Append(propModel.Name);
						
						var nestedResult = ParseSchema(kvp.value, nestedName);
						if (nestedResult case .Err(let err))
						{
							delete model;
							return .Err(err);
						}
						
						if (nestedResult case .Ok(let nestedSchema))
						{
							propModel.Schema = nestedSchema;
						}
					}
					else
					{
						propModel.Schema = new SchemaModel();
						propModel.Schema.Name.Set(propModel.Name);
						ParseType(kvp.value, propModel.Schema);
					}
					
					Result<JsonValue, JsonPointerError> propDescResult = kvp.value.GetByPointer("/description");
					if (propDescResult case .Ok(let propDesc))
					{
						if (propDesc.IsString())
						{
							propModel.Description.Set((StringView)propDesc);
						}
					}
					
					// Clone the key since kvp.key is owned by BJSON
				var keyClone = new String(kvp.key);
				model.Properties.Add(keyClone, propModel);
				}
			}
		}
		
		Result<JsonValue, JsonPointerError> reqResult = json.GetByPointer("/required");
		if (reqResult case .Ok(let reqVal))
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
					String keyStr = scope String(sv);
					if (model.Properties.TryGet(keyStr, out matchKey, out prop))
						{
							prop.IsRequired = true;
						}
					}
				}
			}
		}
		
		Result<JsonValue, JsonPointerError> itemsResult = json.GetByPointer("/items");
		if (itemsResult case .Ok(let items))
		{
			String itemName = scope String();
			itemName.Append(model.Name);
			itemName.Append("Item");
			
			var itemsParseResult = ParseSchema(items, itemName);
			if (itemsParseResult case .Err(let err))
			{
				delete model;
				return .Err(err);
			}
			
			if (itemsParseResult case .Ok(let itemsModel))
			{
				model.Items = itemsModel;
			}
		}
		
		Result<JsonValue, JsonPointerError> allOfResult = json.GetByPointer("/allOf");
		if (allOfResult case .Ok(let allOfVal))
		{
			if (allOfVal.IsArray())
			{
				int i = 0;
				for (var item in allOfVal.As<JsonArray>())
				{
					String subName = scope String();
					subName.Append(model.Name);
					subName.Append("Base");
					subName.Append(i);
					
					var subResult = ParseSchema(item, subName);
					if (subResult case .Err(let err))
					{
						delete model;
						return .Err(err);
					}
					
					if (subResult case .Ok(let subModel))
					{
						model.AllOf.Add(subModel);
					}
					i++;
				}
			}
		}
		
		return .Ok(model);
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
			default: model.Type = .Any;
			}
		}
		else if (typeVal.IsArray())
		{
			bool hasNull = false;
			StringView firstType = default;
			
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
		}
	}
	
	private void ToPascalCase(StringView input, String output)
	{
		bool nextUpper = true;
		for (int i = 0; i < input.Length; i++)
		{
			char8 c = input[i];
			if (c == '_' || c == '-' || c == ' ')
			{
				nextUpper = true;
			}
			else if (nextUpper)
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
