using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

class TypeResolver
{
	private List<SchemaModel> mAllSchemas = new List<SchemaModel>() ~ delete _;
	private HashSet<String> mUsedNames = new HashSet<String>() ~ delete _;
	private Dictionary<String, SchemaModel> mRefTargets = new Dictionary<String, SchemaModel>() ~ delete _;
	private List<SchemaModel> mGenerationOrder = new List<SchemaModel>() ~ delete _;
	private SchemaModel mRootSchema;
	
	public List<String> Warnings = new List<String>() ~ DeleteContainerAndItems!(_);
	public List<String> Errors = new List<String>() ~ DeleteContainerAndItems!(_);
	
	public Result<List<SchemaModel>, SchemaError> Resolve(SchemaModel rootSchema)
	{
		mAllSchemas.Clear();
		ClearUsedNames();
		ClearRefTargets();
		mGenerationOrder.Clear();
		ClearAndDeleteItems(Warnings);
		ClearAndDeleteItems(Errors);
		mRootSchema = rootSchema;
		
		CollectAllSchemas(rootSchema);
		AssignNames();
		RegisterRefTargets(rootSchema, "#");
		
		if (ResolveReferences(rootSchema) case .Err(let resolveErr))
		{
			return .Err(resolveErr);
		}
		
		HashSet<SchemaModel> flattened = scope HashSet<SchemaModel>();
		HashSet<SchemaModel> flattening = scope HashSet<SchemaModel>();
		if (FlattenAllOf(rootSchema, flattened, flattening) case .Err(let flattenErr))
		{
			return .Err(flattenErr);
		}
		
		if (BuildGenerationOrder() case .Err(let orderErr))
		{
			return .Err(orderErr);
		}
		
		var result = new List<SchemaModel>();
		for (var schema in mGenerationOrder)
		{
			result.Add(schema);
		}
		
		return .Ok(result);
	}
	
	public void Cleanup()
	{
		for (var schema in mAllSchemas)
		{
			delete schema;
		}
		mAllSchemas.Clear();
		
		ClearUsedNames();
		ClearRefTargets();
		mGenerationOrder.Clear();
		mRootSchema = null;
	}
	
	private void ClearUsedNames()
	{
		for (var name in mUsedNames)
		{
			delete name;
		}
		mUsedNames.Clear();
	}
	
	private void ClearRefTargets()
	{
		for (var kvp in mRefTargets)
		{
			delete kvp.key;
		}
		mRefTargets.Clear();
	}
	
	private void CollectAllSchemas(SchemaModel schema)
	{
		if (schema == null) return;
		
		if (!ContainsSchema(schema))
		{
			mAllSchemas.Add(schema);
		}
		
		for (var kvp in schema.Defs)
		{
			CollectAllSchemas(kvp.value);
		}
		
		for (var kvp in schema.Definitions)
		{
			CollectAllSchemas(kvp.value);
		}
		
		for (var kvp in schema.Properties)
		{
			CollectAllSchemas(kvp.value.Schema);
		}
		
		CollectAllSchemas(schema.Items);
		
		for (var baseSchema in schema.AllOf)
		{
			CollectAllSchemas(baseSchema);
		}
	}
	
	private bool ContainsSchema(SchemaModel schema)
	{
		for (var existing in mAllSchemas)
		{
			if (existing == schema)
			{
				return true;
			}
		}
		
		return false;
	}
	
	private void AssignNames()
	{
		for (var schema in mAllSchemas)
		{
			if (schema.Type == .Object || schema.Type == .Enum)
			{
				String baseName = scope String();
				ToValidTypeName(schema.Name, baseName);
				if (baseName.IsEmpty)
				{
					baseName.Append("GeneratedType");
				}
				
				int suffix = 1;
				String uniqueName = scope String(baseName);
				
				while (mUsedNames.Contains(uniqueName))
				{
					uniqueName.Clear();
					uniqueName.Append(baseName);
					uniqueName.Append(++suffix);
				}
				
				mUsedNames.Add(new String(uniqueName));
				schema.Name.Set(uniqueName);
			}
		}
	}
	
	private void RegisterRefTargets(SchemaModel schema, StringView pointer)
	{
		if (schema == null) return;
		
		AddRefTarget(pointer, schema);
		
		for (var kvp in schema.Defs)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "$defs", childPointer);
			AppendChildPointer(childPointer, kvp.key, childPointer);
			RegisterRefTargets(kvp.value, childPointer);
		}
		
		for (var kvp in schema.Definitions)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "definitions", childPointer);
			AppendChildPointer(childPointer, kvp.key, childPointer);
			RegisterRefTargets(kvp.value, childPointer);
		}
		
		for (var kvp in schema.Properties)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "properties", childPointer);
			AppendChildPointer(childPointer, kvp.key, childPointer);
			RegisterRefTargets(kvp.value.Schema, childPointer);
		}
		
		if (schema.Items != null)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "items", childPointer);
			RegisterRefTargets(schema.Items, childPointer);
		}
		
		for (int i = 0; i < schema.AllOf.Count; i++)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "allOf", childPointer);
			String index = scope String();
			index.Append(i);
			AppendChildPointer(childPointer, index, childPointer);
			RegisterRefTargets(schema.AllOf[i], childPointer);
		}
	}
	
	private void AddRefTarget(StringView pointer, SchemaModel schema)
	{
		SchemaModel existing;
		if (mRefTargets.TryGetValueAlt(pointer, out existing))
		{
			return;
		}
		
		mRefTargets.Add(new String(pointer), schema);
	}
	
	private void AppendChildPointer(StringView parent, StringView token, String output)
	{
		String original = scope String(parent);
		output.Clear();
		output.Append(original);
		output.Append("/");
		AppendEscapedPointerToken(token, output);
	}
	
	private void AppendEscapedPointerToken(StringView token, String output)
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
	
	private Result<void, SchemaError> ResolveReferences(SchemaModel schema)
	{
		if (schema == null) return .Ok;
		
		if (schema.Type == .Ref && !schema.RefPath.IsEmpty)
		{
			if (!schema.RefPath.StartsWith("#"))
			{
				AddWarning(scope $"External $ref '{schema.RefPath}' is not supported; using JsonValue fallback.");
				schema.Type = .Any;
				schema.RefPath.Clear();
				return .Ok;
			}
			
			SchemaModel target;
			if (mRefTargets.TryGetValueAlt(schema.RefPath, out target))
			{
				schema.ReferencedSchema = target;
			}
			else
			{
				AddError(scope $"Unresolved internal $ref '{schema.RefPath}'.");
				return .Err(.UnresolvedRef);
			}
		}
		
		for (var kvp in schema.Defs)
		{
			if (ResolveReferences(kvp.value) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		for (var kvp in schema.Definitions)
		{
			if (ResolveReferences(kvp.value) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		for (var kvp in schema.Properties)
		{
			if (ResolveReferences(kvp.value.Schema) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		if (ResolveReferences(schema.Items) case .Err(let itemsErr))
		{
			return .Err(itemsErr);
		}
		
		for (var baseSchema in schema.AllOf)
		{
			if (ResolveReferences(baseSchema) case .Err(let allOfErr))
			{
				return .Err(allOfErr);
			}
		}
		
		return .Ok;
	}
	
	private Result<void, SchemaError> FlattenAllOf(SchemaModel schema, HashSet<SchemaModel> processed, HashSet<SchemaModel> visiting)
	{
		if (schema == null) return .Ok;
		if (processed.Contains(schema)) return .Ok;
		
		if (visiting.Contains(schema))
		{
			AddError(scope $"Circular allOf reference involving '{schema.Name}'.");
			return .Err(.CircularRef);
		}
		
		visiting.Add(schema);
		
		for (var baseSchema in schema.AllOf)
		{
			SchemaModel resolvedBase = ResolveAlias(baseSchema);
			if (resolvedBase == null)
			{
				continue;
			}
			
			if (FlattenAllOf(resolvedBase, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
			
			if (resolvedBase.Type == .Object)
			{
				CopyObjectProperties(schema, resolvedBase);
			}
			else if (resolvedBase.Type != .Any)
			{
				AddWarning(scope $"Schema '{schema.Name}' has a non-object allOf member; ignoring it for structural generation.");
			}
		}
		
		ApplyRequired(schema);
		
		for (var kvp in schema.Defs)
		{
			if (FlattenAllOf(kvp.value, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		for (var kvp in schema.Definitions)
		{
			if (FlattenAllOf(kvp.value, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		for (var kvp in schema.Properties)
		{
			if (FlattenAllOf(kvp.value.Schema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		if (FlattenAllOf(schema.Items, processed, visiting) case .Err(let err))
		{
			return .Err(err);
		}
		
		visiting.Remove(schema);
		processed.Add(schema);
		return .Ok;
	}
	
	private SchemaModel ResolveAlias(SchemaModel schema)
	{
		if (schema == null) return null;
		
		if (schema.Type == .Ref && schema.ReferencedSchema != null)
		{
			return schema.ReferencedSchema;
		}
		
		return schema;
	}
	
	private void CopyObjectProperties(SchemaModel target, SchemaModel source)
	{
		for (var kvp in source.Properties)
		{
			String matchKey;
			PropertyModel existingProp;
			if (target.Properties.TryGet(kvp.key, out matchKey, out existingProp))
			{
				if (kvp.value.IsRequired)
				{
					existingProp.IsRequired = true;
					AddRequired(target, kvp.key);
				}
				AddWarning(scope $"Schema '{target.Name}' already has property '{kvp.key}' while flattening allOf; keeping the existing field.");
				continue;
			}
			
			var propCopy = new PropertyModel();
			propCopy.Name.Set(kvp.value.Name);
			propCopy.JsonName.Set(kvp.value.JsonName);
			propCopy.Schema = kvp.value.Schema;
			propCopy.IsRequired = kvp.value.IsRequired;
			propCopy.DefaultValue.Set(kvp.value.DefaultValue);
			propCopy.Description.Set(kvp.value.Description);
			
			target.Properties.Add(new String(kvp.key), propCopy);
			
			if (propCopy.IsRequired)
			{
				AddRequired(target, kvp.key);
			}
		}
	}
	
	private void ApplyRequired(SchemaModel schema)
	{
		for (var req in schema.Required)
		{
			String matchKey;
			PropertyModel prop;
			if (schema.Properties.TryGetAlt(req, out matchKey, out prop))
			{
				prop.IsRequired = true;
			}
		}
	}
	
	private void AddRequired(SchemaModel schema, StringView name)
	{
		for (var req in schema.Required)
		{
			if (req == name)
			{
				return;
			}
		}
		
		schema.Required.Add(new String(name));
	}
	
	private Result<void, SchemaError> BuildGenerationOrder()
	{
		HashSet<SchemaModel> processed = scope HashSet<SchemaModel>();
		HashSet<SchemaModel> visiting = scope HashSet<SchemaModel>();
		
		for (var schema in mAllSchemas)
		{
			if (AddToOrder(schema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		return .Ok;
	}
	
	private Result<void, SchemaError> AddToOrder(SchemaModel schema, HashSet<SchemaModel> processed, HashSet<SchemaModel> visiting)
	{
		if (schema == null || processed.Contains(schema)) return .Ok;
		
		if (visiting.Contains(schema))
		{
			AddError(scope $"Circular schema reference involving '{schema.Name}'.");
			return .Err(.CircularRef);
		}
		
		visiting.Add(schema);
		
		if (schema.Type == .Ref && schema.ReferencedSchema != null)
		{
			if (AddToOrder(schema.ReferencedSchema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		for (var baseSchema in schema.AllOf)
		{
			if (AddToOrder(ResolveAlias(baseSchema), processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		for (var kvp in schema.Properties)
		{
			if (AddToOrder(kvp.value.Schema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}
		
		if (AddToOrder(schema.Items, processed, visiting) case .Err(let itemsErr))
		{
			return .Err(itemsErr);
		}
		
		for (var kvp in schema.Defs)
		{
			if (AddToOrder(kvp.value, processed, visiting) case .Err(let defsErr))
			{
				return .Err(defsErr);
			}
		}
		
		for (var kvp in schema.Definitions)
		{
			if (AddToOrder(kvp.value, processed, visiting) case .Err(let definitionsErr))
			{
				return .Err(definitionsErr);
			}
		}
		
		visiting.Remove(schema);
		processed.Add(schema);
		
		if (schema.Emit && (schema.Type == .Enum || schema.Type == .Object))
		{
			mGenerationOrder.Add(schema);
		}
		
		return .Ok;
	}
	
	private void ToValidTypeName(StringView input, String output)
	{
		bool nextUpper = true;
		for (int i = 0; i < input.Length; i++)
		{
			char8 c = input[i];
			bool isLetter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
			bool isDigit = c >= '0' && c <= '9';
			
			if (isLetter || isDigit)
			{
				if (output.IsEmpty && isDigit)
				{
					output.Append("_");
				}
				
				if (nextUpper && c >= 'a' && c <= 'z')
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
				nextUpper = true;
			}
		}
	}
	
	private void AddWarning(StringView message)
	{
		Warnings.Add(new String(message));
	}
	
	private void AddError(StringView message)
	{
		Errors.Add(new String(message));
	}
}
