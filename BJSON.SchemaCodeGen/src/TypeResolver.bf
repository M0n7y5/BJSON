using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

class TypeResolver
{
	private List<SchemaModel> mAllSchemas = new List<SchemaModel>() ~ delete _;
	private HashSet<String> mUsedNames = new HashSet<String>() ~ delete _;
	private Dictionary<String, SchemaModel> mRefTargets = new Dictionary<String, SchemaModel>() ~ delete _;
	private List<SchemaModel> mGenerationOrder = new List<SchemaModel>() ~ delete _;
	

	
	public Result<List<SchemaModel>, SchemaError> Resolve(SchemaModel rootSchema)
	{
		mAllSchemas.Clear();
		mUsedNames.Clear();
		mRefTargets.Clear();
		mGenerationOrder.Clear();
		
		CollectAllSchemas(rootSchema, null);
		AssignNames();
		ResolveReferences(rootSchema);
		ProcessInheritance(rootSchema);
		BuildGenerationOrder();
		
		var result = new List<SchemaModel>();
		for (var schema in mGenerationOrder)
		{
			result.Add(schema);
		}
		
		return .Ok(result);
	}
	
	public void Cleanup()
	{
		// Delete all schemas in mAllSchemas
		// Note: Caller must ensure rootSchema is not used after this
		for (var schema in mAllSchemas)
		{
			delete schema;
		}
		mAllSchemas.Clear();
		
		// Clean up all strings in mUsedNames
		for (var name in mUsedNames)
		{
			delete name;
		}
		mUsedNames.Clear();
		
		mRefTargets.Clear();
		mGenerationOrder.Clear();
	}
	
	private void CollectAllSchemas(SchemaModel schema, SchemaModel parent)
	{
		if (schema == null) return;
		
		bool alreadyAdded = false;
		for (var existing in mAllSchemas)
		{
			if (existing == schema)
			{
				alreadyAdded = true;
				break;
			}
		}
		
		if (!alreadyAdded)
		{
			mAllSchemas.Add(schema);
		}
		
		for (var kvp in schema.Properties)
		{
			CollectAllSchemas(kvp.value.Schema, schema);
		}
		
		if (schema.Items != null)
		{
			CollectAllSchemas(schema.Items, schema);
		}
		
		for (var baseSchema in schema.AllOf)
		{
			CollectAllSchemas(baseSchema, schema);
		}
		
		if (schema.ReferencedSchema != null)
		{
			CollectAllSchemas(schema.ReferencedSchema, schema);
		}
	}
	
	private void AssignNames()
	{
		for (var schema in mAllSchemas)
		{
			if (schema.Type == .Object || schema.Type == .Enum)
			{
				String name = scope String();
				name.Append(schema.Name);
				
				int suffix = 1;
				String uniqueName = scope String();
				uniqueName.Append(name);
				
				while (mUsedNames.Contains(uniqueName))
				{
					uniqueName.Clear();
					uniqueName.Append(name);
					uniqueName.Append(++suffix);
				}
				
				mUsedNames.Add(uniqueName);
				schema.Name.Set(uniqueName);
			}
		}
	}
	
	private void ResolveReferences(SchemaModel schema)
	{
		if (schema == null) return;
		
		if (schema.Type == .Ref && !schema.RefPath.IsEmpty)
		{
			var target = FindRefTarget(schema.RefPath, schema);
			if (target != null)
			{
				schema.ReferencedSchema = target;
			}
		}
		
		for (var kvp in schema.Properties)
		{
			ResolveReferences(kvp.value.Schema);
		}
		
		ResolveReferences(schema.Items);
		
		for (var baseSchema in schema.AllOf)
		{
			ResolveReferences(baseSchema);
		}
	}
	
	private SchemaModel FindRefTarget(StringView refPath, SchemaModel context)
	{
		if (refPath.IsEmpty) return null;
		
		if (refPath[0] == '#')
		{
			return FindInternalRef(refPath, context);
		}
		
		return null;
	}
	
	private SchemaModel FindInternalRef(StringView refPath, SchemaModel context)
	{
		if (refPath.Length < 2 || refPath[0] != '#') return null;
		
		if (refPath.StartsWith("#/definitions/"))
		{
			StringView defName = refPath.Substring(14);
			for (var schema in mAllSchemas)
			{
				if (schema.Name.Equals(defName, .OrdinalIgnoreCase))
				{
					return schema;
				}
			}
		}
		
		if (refPath == "#")
		{
			for (var schema in mAllSchemas)
			{
				bool isReferenced = false;
				for (var s in mAllSchemas)
				{
					if (s != schema && s.ReferencedSchema == schema)
					{
						isReferenced = true;
						break;
					}
				}
				if (!isReferenced)
				{
					return schema;
				}
			}
		}
		
		return null;
	}
	
	private void ProcessInheritance(SchemaModel schema)
	{
		if (schema == null) return;
		
		if (schema.AllOf.Count > 0)
		{
			for (int i = schema.AllOf.Count - 1; i >= 0; i--)
			{
				var baseSchema = schema.AllOf[i];
				if (baseSchema.Type == .Ref && baseSchema.ReferencedSchema != null)
				{
					schema.AllOf[i] = baseSchema.ReferencedSchema;
					delete baseSchema;
				}
			}
			
			for (int i = 0; i < schema.AllOf.Count; i++)
			{
				var baseSchema = schema.AllOf[i];
				if (baseSchema.Type != .Object)
				{
					continue;
				}
				
				for (var kvp in baseSchema.Properties)
				{
					String matchKey;
					PropertyModel existingProp;
					if (!schema.Properties.TryGet(kvp.key, out matchKey, out existingProp))
					{
						var propCopy = new PropertyModel();
						propCopy.Name.Set(kvp.value.Name);
						propCopy.JsonName.Set(kvp.value.JsonName);
						propCopy.IsRequired = kvp.value.IsRequired;
						propCopy.Description.Set(kvp.value.Description);
						
						if (kvp.value.Schema != null)
						{
							propCopy.Schema = kvp.value.Schema;
						}
						
						// Clone the key to avoid double-free when both base and derived schemas are destroyed
						var keyClone = new String(kvp.key);
						schema.Properties.Add(keyClone, propCopy);
						
						if (kvp.value.IsRequired)
						{
							schema.Required.Add(new String(kvp.key));
						}
					}
				}
			}
			

		}
		
		for (var kvp in schema.Properties)
		{
			ProcessInheritance(kvp.value.Schema);
		}
		
		ProcessInheritance(schema.Items);
	}
	
	private void BuildGenerationOrder()
	{
		HashSet<SchemaModel> processed = scope HashSet<SchemaModel>();
		
		for (var schema in mAllSchemas)
		{
			AddToOrder(schema, processed);
		}
	}
	
	private void AddToOrder(SchemaModel schema, HashSet<SchemaModel> processed)
	{
		if (schema == null || processed.Contains(schema)) return;
		
		if (schema.Type == .Ref && schema.ReferencedSchema != null)
		{
			AddToOrder(schema.ReferencedSchema, processed);
		}
		
		for (var baseSchema in schema.AllOf)
		{
			AddToOrder(baseSchema, processed);
		}
		
		AddToOrder(schema.Items, processed);
		
		processed.Add(schema);
		
		if (schema.Type == .Enum || schema.Type == .Object || 
			(schema.Type == .Ref && schema.ReferencedSchema != null))
		{
			mGenerationOrder.Add(schema);
		}
	}
}
