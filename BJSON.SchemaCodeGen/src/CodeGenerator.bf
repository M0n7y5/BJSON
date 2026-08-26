using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

/// Renders one SchemaModel as the source text of a Beef class or enum.
/// Ownership: mConfig is a copy of the caller's GeneratorConfig, whose Namespace string is non
/// owning, so that string MUST outlive the generator. Generate returns a heap allocated String the
/// caller has to delete. Nothing else here allocates beyond the call.
class CodeGenerator
{
	private GeneratorConfig mConfig;
	
	/// @param config Generator options, copied by value. Its Namespace string stays owned by the
	///               caller and MUST outlive this generator.
	public this(GeneratorConfig config)
	{
		mConfig = config;
	}
	
	/// Renders schema as a whole Beef source file: an enum for .Enum, a class for anything else.
	/// @param schema The type to render. Non owning: the node list owns it, together with the base,
	///               element and property schemas this call reads through it.
	/// @returns A new String the caller owns and MUST delete.
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
		
		for (var member in schema.AllOf)
		{
			// A `$ref` member names the base class through its target.
			var baseSchema = member.Resolved;
			if (baseSchema.Type == .Object)
			{
				sb.AppendF($" : {baseSchema.Name}");
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
		
		// BJSON looks keys up case sensitively, so a rename that only changes case still needs
		// the attribute.
		if (!prop.JsonName.IsEmpty && !prop.Name.Equals(prop.JsonName, .Ordinal))
		{
			String literal = scope String();
			AppendSourceLiteral(prop.JsonName, literal);
			sb.AppendF($"\t[JsonPropertyName(\"{literal}\")]\n");
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
	
	/// Escapes a JSON key for a Beef source string literal, so a key holding a quote or a
	/// backslash cannot break or alter the generated code.
	private void AppendSourceLiteral(StringView text, String outText)
	{
		for (let c in text)
		{
			switch (c)
			{
			case '"': outText.Append("\\\"");
			case '\\': outText.Append("\\\\");
			case '\n': outText.Append("\\n");
			case '\r': outText.Append("\\r");
			case '\t': outText.Append("\\t");
			default: outText.Append(c);
			}
		}
	}
	
	private void GenerateEnum(String sb, SchemaModel schema)
	{
		if (!schema.Description.IsEmpty && !mConfig.SkipDocs)
		{
			sb.AppendF($"/// {schema.Description}\n");
		}
		
		// BJSON serializes enums natively, and [JsonObject] is not valid on one.
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
		var resolved = schema.Resolved;
		
		switch (resolved.Type)
		{
		case .String:
			output.Append("String");
		case .Integer:
			if (resolved.IsNullable)
			{
				output.Append(mConfig.IntegerType == .Int32 ? "int32?" : "int64?");
			}
			else
			{
				output.Append(mConfig.IntegerType == .Int32 ? "int32" : "int64");
			}
		case .Number:
			if (resolved.IsNullable)
			{
				output.Append(mConfig.NumberType == .Float ? "float?" : "double?");
			}
			else
			{
				output.Append(mConfig.NumberType == .Float ? "float" : "double");
			}
		case .Boolean:
			if (resolved.IsNullable)
			{
				output.Append("bool?");
			}
			else
			{
				output.Append("bool");
			}
		case .Array:
			output.Append("List<");
			if (resolved.Items != null)
			{
				GetBeefType(resolved.Items, output);
			}
			else
			{
				output.Append("JsonValue");
			}
			output.Append(">");
		case .Object:
			output.Append(resolved.Name);
		case .Enum:
			output.Append(resolved.Name);
		default:
			if (resolved.IsNullable)
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
		var resolved = schema.Resolved;
		
		switch (resolved.Type)
		{
		case .String:
			output.Append(" = new .() ~ delete _;");
		case .Array:
			// Only a list of heap objects may delete its items.
			if (OwnsListItems(resolved.Items))
			{
				output.Append(" = new .() ~ DeleteContainerAndItems!(_);");
			}
			else
			{
				output.Append(" = new .() ~ delete _;");
			}
		case .Object:
			output.Append(" = new .() ~ delete _;");
		default:
			output.Clear();
		}
	}
	
	/// Whether a List of this element schema holds objects the destructor has to delete.
	private bool OwnsListItems(SchemaModel items)
	{
		if (items == null)
		{
			return false;
		}
		
		switch (items.Resolved.Type)
		{
		case .String, .Object, .Array:
			return true;
		default:
			return false;
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

/// Options that shape the generated source, copied by value into CodeGenerator.
struct GeneratorConfig
{
	/// Namespace of every generated file. Non owning: the caller owns this string and MUST keep it
	/// alive while a CodeGenerator holds the config.
	public String Namespace;
	/// Beef type generated for `type: integer`.
	public IntegerType IntegerType = .Int64;
	/// Beef type generated for `type: number`.
	public NumberType NumberType = .Double;
	/// When true, no schema `description` reaches the generated code as a doc comment.
	public bool SkipDocs;
}

/// Beef type generated for `type: integer`, and for a nullable schema with no usable type.
enum IntegerType
{
	/// int32, or int32? when the schema also allows null.
	Int32,
	/// int64, or int64? when the schema also allows null.
	Int64
}

/// Beef type generated for `type: number`.
enum NumberType
{
	/// float, or float? when the schema also allows null.
	Float,
	/// double, or double? when the schema also allows null.
	Double
}
