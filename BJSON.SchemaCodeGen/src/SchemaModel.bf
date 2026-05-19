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

class SchemaModel
{
	public String Name = new String() ~ delete _;
	public String Description = new String() ~ delete _;
	public SchemaType Type;
	public bool IsNullable;
	public Dictionary<String, PropertyModel> Properties = new Dictionary<String, PropertyModel>() ~ delete _;
	public List<String> Required = new List<String>() ~ delete _;
	public List<String> EnumValues = new List<String>() ~ delete _;
	public SchemaModel Items;
	public List<SchemaModel> AllOf = new List<SchemaModel>() ~ delete _;
	public Dictionary<String, SchemaModel> Defs = new Dictionary<String, SchemaModel>() ~ delete _;
	public Dictionary<String, SchemaModel> Definitions = new Dictionary<String, SchemaModel>() ~ delete _;
	public SchemaModel ReferencedSchema;
	public String RefPath = new String() ~ delete _;
	public bool Emit = true;
	
	public ~this()
	{
		for (var kvp in Properties)
		{
			delete kvp.key;
			delete kvp.value;
		}
		Properties.Clear();
		
		// Delete all Strings in Required list
		for (var item in Required)
		{
			delete item;
		}
		Required.Clear();
		
		// Delete all Strings in EnumValues list
		for (var item in EnumValues)
		{
			delete item;
		}
		EnumValues.Clear();
		
		for (var kvp in Defs)
		{
			delete kvp.key;
		}
		Defs.Clear();
		
		for (var kvp in Definitions)
		{
			delete kvp.key;
		}
		Definitions.Clear();
		
		// SchemaModel references are centrally owned by TypeResolver.Cleanup().
		Items = null;
		ReferencedSchema = null;
		AllOf.Clear();
	}
}

class PropertyModel
{
	public String Name = new String() ~ delete _;
	public String JsonName = new String() ~ delete _;
	public SchemaModel Schema;
	public bool IsRequired;
	public String DefaultValue = new String() ~ delete _;
	public String Description = new String() ~ delete _;
	
	public ~this()
	{
		// SchemaModel references are centrally owned by TypeResolver.Cleanup().
		Schema = null;
	}
}
