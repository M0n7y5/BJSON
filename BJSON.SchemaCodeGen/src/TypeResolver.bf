using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

/// Second pass over the node graph: makes generated type names unique, resolves `$ref`, applies
/// `allOf` inheritance and lists the types to generate.
/// Rejected here, after SchemaParser accepted the document: a `$ref` that leaves the document
/// (.UnsupportedKeyword), a `$ref` that names a location the document does not define
/// (.UnresolvedRef), a `$ref` chain or an `allOf` chain that forms a cycle (.CircularRef), a
/// `required` entry naming a property that neither the schema nor any of its bases declares
/// (.UnsupportedKeyword), and an object or enum whose name is empty (.UnnamedType).
/// Ownership: the resolver never allocates or frees a SchemaModel. The only allocations that
/// outlive a Resolve call are the PropertyModel copies and dictionary keys that `allOf`
/// inheritance adds, and the SchemaModel that receives them owns them.
class TypeResolver
{
	/// Every node of the schema graph, owned by the caller of Resolve. Non owning.
	private List<SchemaModel> mAllSchemas;

	/// Makes type names unique, resolves `$ref`, applies `allOf` inheritance and lists the types to
	/// generate. A type follows its `$ref` target, its `allOf` bases and its element schema in that
	/// list, while a type a property declares keeps document order and so follows the type that
	/// declares it. Beef needs no declaration order, so the list only decides reading order.
	/// @param allSchemas Every node SchemaParser.Parse produced. Stays owned by the caller.
	/// @param outGenerationOrder Caller owned list that receives the nodes to generate. The
	///                          entries alias allSchemas and must not be deleted through it.
	/// @returns .Ok when the graph resolved, otherwise the construct that failed.
	public Result<void, SchemaError> Resolve(List<SchemaModel> allSchemas, List<SchemaModel> outGenerationOrder)
	{
		mAllSchemas = allSchemas;

		Try!(AssignNames());
		Try!(ResolveReferences());
		Try!(ProcessInheritance());
		BuildGenerationOrder(outGenerationOrder);

		return .Ok;
	}

	/// Gives every generated type a name no other generated type uses, appending a counter to
	/// later duplicates: Address, Address2.
	private Result<void, SchemaError> AssignNames()
	{
		HashSet<String> usedNames = scope HashSet<String>();
		defer { ClearAndDeleteItems!(usedNames); }

		for (var schema in mAllSchemas)
		{
			if ((schema.Type != .Object) && (schema.Type != .Enum))
			{
				continue;
			}

			if (schema.Name.IsEmpty)
			{
				return .Err(.UnnamedType);
			}

			String uniqueName = scope String(schema.Name);
			int suffix = 1;
			while (usedNames.Contains(uniqueName))
			{
				uniqueName.Set(schema.Name);
				uniqueName.Append(++suffix);
			}

			// The set owns its strings: a scope allocated name would leave it hashing freed stack
			// memory after this iteration.
			usedNames.Add(new String(uniqueName));
			schema.Name.Set(uniqueName);
		}

		return .Ok;
	}

	private Result<void, SchemaError> ResolveReferences()
	{
		for (var schema in mAllSchemas)
		{
			if (schema.Type != .Ref)
			{
				continue;
			}

			if (schema.RefPath.IsEmpty)
			{
				return .Err(.InvalidSchema);
			}

			if (!schema.RefPath.StartsWith("#"))
			{
				return .Err(.UnsupportedKeyword("$ref", "only references inside the same document are supported"));
			}

			schema.ReferencedSchema = FindByPointer(schema.RefPath);
			if (schema.ReferencedSchema == null)
			{
				return .Err(.UnresolvedRef);
			}
		}

		// A `$ref` may name another `$ref`, so follow the chain down to the schema that carries
		// the type.
		for (var schema in mAllSchemas)
		{
			if (schema.Type != .Ref)
			{
				continue;
			}

			var target = schema.ReferencedSchema;
			int hops = 0;
			while (target.Type == .Ref)
			{
				target = target.ReferencedSchema;
				hops++;
				if (hops > mAllSchemas.Count)
				{
					return .Err(.CircularRef);
				}
			}

			schema.ReferencedSchema = target;
		}

		return .Ok;
	}

	/// Finds the node whose recorded JSON Pointer matches, case sensitively.
	/// @returns The node, or null when the document defines no such location.
	private SchemaModel FindByPointer(StringView pointer)
	{
		for (var schema in mAllSchemas)
		{
			if (schema.Pointer.Equals(pointer, .Ordinal))
			{
				return schema;
			}
		}

		return null;
	}

	private Result<void, SchemaError> ProcessInheritance()
	{
		HashSet<SchemaModel> merged = scope HashSet<SchemaModel>();
		HashSet<SchemaModel> inProgress = scope HashSet<SchemaModel>();

		for (var schema in mAllSchemas)
		{
			Try!(MergeSchema(schema, merged, inProgress));
		}

		return .Ok;
	}

	/// Applies the `allOf` members of schema: the first member that resolves to an object becomes
	/// the Beef base class and keeps its properties where they are, every later object member has
	/// its properties copied in, then the schema's own `required` list is applied.
	/// @param merged Nodes already merged.
	/// @param inProgress Nodes on the current chain, so a cycle is reported instead of recursing.
	private Result<void, SchemaError> MergeSchema(SchemaModel schema, HashSet<SchemaModel> merged, HashSet<SchemaModel> inProgress)
	{
		if (merged.Contains(schema))
		{
			return .Ok;
		}

		if (!inProgress.Add(schema))
		{
			return .Err(.CircularRef);
		}

		bool baseClaimed = false;

		for (var member in schema.AllOf)
		{
			var baseSchema = member.Resolved;
			if (baseSchema.Type != .Object)
			{
				continue;
			}

			Try!(MergeSchema(baseSchema, merged, inProgress));

			// The first object member becomes the Beef base class, so the generated type
			// inherits its fields. Copying them in as well would shadow the base and emit
			// every inherited key twice.
			if (!baseClaimed)
			{
				baseClaimed = true;
				continue;
			}

			InheritProperties(schema, baseSchema);
		}

		Try!(ApplyRequired(schema));

		inProgress.Remove(schema);
		merged.Add(schema);

		return .Ok;
	}

	/// Copies the base properties that schema does not declare itself, for an `allOf` member that
	/// did not become the base class.
	/// Ownership: each copy is a new PropertyModel with its own strings, owned by the Properties
	/// dictionary of schema. Its Schema pointer aliases the base property's node, which the node
	/// list owns, so neither property frees it.
	private void InheritProperties(SchemaModel schema, SchemaModel baseSchema)
	{
		for (var kvp in baseSchema.Properties)
		{
			if (schema.Properties.ContainsKey(kvp.key))
			{
				continue;
			}

			var propCopy = new PropertyModel();
			schema.Properties.Add(new String(kvp.key), propCopy);

			propCopy.Name.Set(kvp.value.Name);
			propCopy.JsonName.Set(kvp.value.JsonName);
			propCopy.Description.Set(kvp.value.Description);
			propCopy.DefaultValue.Set(kvp.value.DefaultValue);
			propCopy.IsRequired = kvp.value.IsRequired;
			propCopy.Schema = kvp.value.Schema;
		}
	}

	/// Marks the properties named by `required`, including the ones a base class declares.
	private Result<void, SchemaError> ApplyRequired(SchemaModel schema)
	{
		for (var name in schema.Required)
		{
			if (schema.Properties.TryGetValue(name, let prop))
			{
				prop.IsRequired = true;
				continue;
			}

			if (MarkRequiredInBase(schema, name))
			{
				continue;
			}

			return .Err(.UnsupportedKeyword("required", "names a property that no schema in the document declares"));
		}

		return .Ok;
	}

	private bool MarkRequiredInBase(SchemaModel schema, StringView name)
	{
		for (var member in schema.AllOf)
		{
			var baseSchema = member.Resolved;
			if (baseSchema.Type != .Object)
			{
				continue;
			}

			if (baseSchema.Properties.TryGetValue(scope String(name), let prop))
			{
				prop.IsRequired = true;
				return true;
			}

			if (MarkRequiredInBase(baseSchema, name))
			{
				return true;
			}
		}

		return false;
	}

	private void BuildGenerationOrder(List<SchemaModel> outGenerationOrder)
	{
		HashSet<SchemaModel> processed = scope HashSet<SchemaModel>();

		for (var schema in mAllSchemas)
		{
			AddToOrder(schema, processed, outGenerationOrder);
		}
	}

	/// Adds schema after the types it needs: its `$ref` target, its `allOf` bases and its element
	/// schema. A property's schema is not followed here, because the caller's pass over every node
	/// reaches it. Only objects and enums become files.
	private void AddToOrder(SchemaModel schema, HashSet<SchemaModel> processed, List<SchemaModel> outGenerationOrder)
	{
		if (schema == null || !processed.Add(schema))
		{
			return;
		}

		if (schema.ReferencedSchema != null)
		{
			AddToOrder(schema.ReferencedSchema, processed, outGenerationOrder);
		}

		for (var baseSchema in schema.AllOf)
		{
			AddToOrder(baseSchema, processed, outGenerationOrder);
		}

		AddToOrder(schema.Items, processed, outGenerationOrder);

		if ((schema.Type == .Object) || (schema.Type == .Enum))
		{
			outGenerationOrder.Add(schema);
		}
	}
}
