using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

class CodeGenerator
{
	private GeneratorConfig mConfig;
	
	public this(GeneratorConfig config)
	{
		mConfig = config;
	}
	
	public String Generate(SchemaModel schema)
	{
		var sb = scope String();
		
		GenerateHeader(sb);
		
		if (schema.Type == .Enum)
		{
			GenerateEnum(sb, schema);
		}
		else
		{
			GenerateClass(sb, schema);
		}
		
		return new String(sb);
	}
	
	private void GenerateHeader(String sb)
	{
		sb.Append("using System;\n");
		sb.Append("using System.Collections;\n");
		sb.Append("using BJSON.Attributes;\n");
		sb.Append("using BJSON.Models;\n\n");
		sb.AppendF($"namespace {mConfig.Namespace};\n\n");
	}
	
	private void GenerateClass(String sb, SchemaModel schema)
	{
		if (!schema.Description.IsEmpty && !mConfig.SkipDocs)
		{
			sb.AppendF($"/// {schema.Description}\n");
		}
		
		sb.Append("[JsonObject]\n");
		sb.AppendF($"class {schema.Name}");
		
		bool hasBaseClass = false;
		for (var baseSchema in schema.AllOf)
		{
			if (baseSchema.Type == .Object)
			{
				sb.AppendF($" : {baseSchema.Name}");
				hasBaseClass = true;
				break;
			}
		}
		
		sb.Append("\n{\n");
		
		for (var kvp in schema.Properties)
		{
			GenerateField(sb, kvp.value);
		}
		
		sb.Append("}\n");
	}
	
	private void GenerateField(String sb, PropertyModel prop)
	{
		if (!prop.Description.IsEmpty && !mConfig.SkipDocs)
		{
			sb.AppendF($"\t/// {prop.Description}\n");
		}
		
		if (prop.IsRequired)
		{
			sb.Append("\t[JsonRequired]\n");
		}
		
		if (!prop.JsonName.IsEmpty && !prop.Name.Equals(prop.JsonName, .OrdinalIgnoreCase))
		{
			sb.AppendF($"\t[JsonPropertyName(\"{prop.JsonName}\")]\n");
		}
		
		sb.AppendF($"\tpublic ");
		
		String typeName = scope String();
		GetBeefType(prop.Schema, typeName);
		sb.Append(typeName);
		
		sb.AppendF($" {prop.Name}");
		
		String init = scope String();
		GetInitializer(prop.Schema, init);
		if (!init.IsEmpty)
		{
			sb.Append(init);
		}
		else
		{
			sb.Append(";");
		}
		
		sb.Append("\n\n");
	}
	
	private void GenerateEnum(String sb, SchemaModel schema)
	{
		if (!schema.Description.IsEmpty && !mConfig.SkipDocs)
		{
			sb.AppendF($"/// {schema.Description}\n");
		}
		
		// Note: [JsonObject] is not valid on enums in BJSON
		// Enums are handled natively by the BJSON serializer
		sb.AppendF($"enum {schema.Name}\n");
		sb.Append("{\n");
		
		bool first = true;
		for (var val in schema.EnumValues)
		{
			if (!first) sb.Append(",\n");
			first = false;
			
			String enumName = scope String();
			ToValidEnumName(val, enumName);
			sb.AppendF($"\t{enumName}");
		}
		
		sb.Append("\n}\n");
	}
	
	private void GetBeefType(SchemaModel schema, String output)
	{
		if (schema.Type == .Ref && schema.ReferencedSchema != null)
		{
			output.Append(schema.ReferencedSchema.Name);
			return;
		}
		
		switch (schema.Type)
		{
		case .String:
			output.Append("String");
		case .Integer:
			if (schema.IsNullable)
			{
				output.Append(mConfig.IntegerType == .Int32 ? "int32?" : "int64?");
			}
			else
			{
				output.Append(mConfig.IntegerType == .Int32 ? "int32" : "int64");
			}
		case .Number:
			if (schema.IsNullable)
			{
				output.Append(mConfig.NumberType == .Float ? "float?" : "double?");
			}
			else
			{
				output.Append(mConfig.NumberType == .Float ? "float" : "double");
			}
		case .Boolean:
			if (schema.IsNullable)
			{
				output.Append("bool?");
			}
			else
			{
				output.Append("bool");
			}
		case .Array:
			output.Append("List<");
			if (schema.Items != null)
			{
				GetBeefType(schema.Items, output);
			}
			else
			{
				output.Append("JsonValue");
			}
			output.Append(">");
		case .Object:
			output.Append(schema.Name);
		case .Enum:
			output.Append(schema.Name);
		default:
			// Fallback for unrecognized types
			// If it's nullable, use nullable int64 as a sensible default
			// Otherwise use JsonValue
			if (schema.IsNullable)
			{
				output.Append(mConfig.IntegerType == .Int32 ? "int32?" : "int64?");
			}
			else
			{
				output.Append("JsonValue");
			}
		}
	}
	
	private void GetInitializer(SchemaModel schema, String output)
	{
		if (schema.Type == .Ref && schema.ReferencedSchema != null)
		{
			output.Append(" = new .() ~ delete _;");
			return;
		}
		
		switch (schema.Type)
		{
		case .String:
			output.Append(" = new .() ~ delete _;");
		case .Integer, .Number, .Boolean:
			output.Clear();
		case .Array:
			output.Append(" = new .() ~ DeleteContainerAndItems!(_);");
		case .Object:
			output.Append(" = new .() ~ delete _;");
		default:
			output.Clear();
		}
	}
	
	private void ToValidEnumName(StringView input, String output)
	{
		if (input.IsEmpty)
		{
			output.Append("Unknown");
			return;
		}
		
		bool first = true;
		for (int i = 0; i < input.Length; i++)
		{
			char8 c = input[i];
			bool isLetterOrDigit = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9');
			if (isLetterOrDigit)
			{
				if (first)
				{
					if (c >= 'a' && c <= 'z')
					{
						output.Append((char8)(c - 32));
					}
					else
					{
						output.Append(c);
					}
					first = false;
				}
				else
				{
					output.Append(c);
				}
			}
			else
			{
				output.Append('_');
			}
		}
		
		if (output.IsEmpty)
		{
			output.Append("Unknown");
		}
	}
}

struct GeneratorConfig
{
	public String Namespace;
	public IntegerType IntegerType = .Int64;
	public NumberType NumberType = .Double;
	public bool SkipDocs;
}

enum IntegerType
{
	Int32,
	Int64
}

enum NumberType
{
	Float,
	Double
}
