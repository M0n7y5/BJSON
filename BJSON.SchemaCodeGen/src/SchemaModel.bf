using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

enum SchemaType
{
	Object,
	Array,
	String,
	Integer,
	Number,
	Boolean,
	Enum,
	Ref,
	Any
}

/// One schema of a parsed document.
/// Ownership: a node owns its own strings, the PropertyModel entries of Properties and the
/// DefinitionModel entries of Defs and Definitions. Items, AdditionalProperties, AllOf entries,
/// ReferencedSchema and the schema a DefinitionModel names are non owning pointers to other nodes,
/// which TypeResolver.Cleanup frees centrally.
class SchemaModel
{
	public String Name = new String() ~ delete _;
	public String Description = new String() ~ delete _;
	public SchemaType Type;
	public bool IsNullable;
	/// Object properties in the order the document declares them, which is the order the generated
	/// fields keep. Owns them. FindProperty looks one up by its raw JSON key.
	public List<PropertyModel> Properties = new List<PropertyModel>() ~ DeleteContainerAndItems!(_);
	public List<String> Required = new List<String>() ~ DeleteContainerAndItems!(_);
	public List<String> EnumValues = new List<String>() ~ DeleteContainerAndItems!(_);
	public SchemaModel Items;
	public SchemaModel AdditionalProperties;
	public List<SchemaModel> AllOf = new List<SchemaModel>() ~ delete _;
	/// `$defs` members in the order the document declares them, which keeps the generated files and
	/// the pointers built from these keys the same on every run. Owns the entries.
	public List<DefinitionModel> Defs = new List<DefinitionModel>() ~ DeleteContainerAndItems!(_);
	/// `definitions` members, ordered and owned like Defs.
	public List<DefinitionModel> Definitions = new List<DefinitionModel>() ~ DeleteContainerAndItems!(_);
	public SchemaModel ReferencedSchema;
	public String RefPath = new String() ~ delete _;
	public String SourcePath = new String() ~ delete _;
	public String BaseUri = new String() ~ delete _;
	public String Id = new String() ~ delete _;
	public String Anchor = new String() ~ delete _;
	public bool Emit = true;

	/// Finds the property declaring a raw JSON key, compared case sensitively.
	/// @param jsonName The raw JSON key.
	/// @returns The property, or null when this schema declares no such key. Non owning: the
	///          Properties list owns it.
	public PropertyModel FindProperty(StringView jsonName)
	{
		for (var prop in this.Properties)
		{
			if (prop.JsonName.Equals(jsonName, .Ordinal))
			{
				return prop;
			}
		}

		return null;
	}
}

/// One member of `$defs` or `definitions`. Owned by the list that holds it.
class DefinitionModel
{
	/// Raw JSON key, which is the JSON Pointer token a `$ref` names.
	public String Key = new String() ~ delete _;
	/// Schema the key names. Non owning: TypeResolver.Cleanup frees it.
	public SchemaModel Schema;
}

/// One property of an object schema. Owned by the Properties list that holds it. Owns its strings.
class PropertyModel
{
	public String Name = new String() ~ delete _;
	public String JsonName = new String() ~ delete _;
	/// Schema of the property value. Non owning: TypeResolver.Cleanup frees it. A property copied
	/// in from an `allOf` member is a separate PropertyModel pointing at the same node.
	public SchemaModel Schema;
	public bool IsRequired;
	public String Description = new String() ~ delete _;
}
