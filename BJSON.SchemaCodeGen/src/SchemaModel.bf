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
	public SchemaModel ReferencedSchema;
	public String RefPath = new String() ~ delete _;
	
	public ~this()
	{
		// Delete all PropertyModels in Properties
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
		
		// Don't delete AllOf items here - they are also in mAllSchemas and will be deleted there
		// Just clear the list to prevent dangling pointers
		AllOf.Clear();
		
		if (Items != null)
		{
			delete Items;
			Items = null;
		}
		if (ReferencedSchema != null)
		{
			delete ReferencedSchema;
			ReferencedSchema = null;
		}
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
		if (Schema != null)
		{
			delete Schema;
			Schema = null;
		}
	}
}
