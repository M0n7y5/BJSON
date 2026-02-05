using System;
using System.IO;
using System.Collections;

namespace BJSON.SchemaCodeGen;

class Program
{
	public static int Main(String[] args)
	{
		var options = scope CommandLineOptions();
		
		if (!ParseArguments(args, options))
		{
			PrintUsage();
			return 1;
		}
		
		if (options.ShowHelp || args.Count == 0)
		{
			PrintUsage();
			return 0;
		}
		
		if (options.SchemaFile.IsEmpty)
		{
			Console.Error.WriteLine("Error: Schema file is required.\n");
			PrintUsage();
			return 1;
		}
		
		if (options.Namespace.IsEmpty)
		{
			Console.Error.WriteLine("Error: Namespace is required. Use -n or --namespace.\n");
			PrintUsage();
			return 1;
		}
		
		if (!File.Exists(options.SchemaFile))
		{
			Console.Error.WriteLine(scope $"Error: Schema file not found: {options.SchemaFile}\n");
			return 1;
		}
		
		String schemaContent = scope String();
		var readResult = File.ReadAllText(options.SchemaFile, schemaContent);
		if (readResult case .Err(let fileErr))
		{
			Console.Error.WriteLine(scope $"Error: Failed to read schema file: {fileErr}\n");
			return 1;
		}
		
		String rootName = scope String();
		if (!options.RootClassName.IsEmpty)
		{
			rootName.Append(options.RootClassName);
		}
		else
		{
			String fileName = scope String();
			Path.GetFileNameWithoutExtension(options.SchemaFile, fileName);
			rootName.Append(fileName);
			int dotIndex = rootName.IndexOf('.');
			if (dotIndex >= 0)
			{
				rootName.RemoveToEnd(dotIndex);
			}
		}
		String pascalRootName = scope String();
		ToPascalCase(rootName, pascalRootName);
		rootName.Set(pascalRootName);
		
		Console.WriteLine(scope $"Parsing schema: {options.SchemaFile}");
		
		var parser = scope SchemaParser();
		var parseResult = parser.Parse(schemaContent, rootName);
		
		if (parseResult case .Err(let parseErr))
		{
			Console.Error.Write("Error: Failed to parse schema: ");
			switch (parseErr)
			{
			case .JsonError:
				Console.Error.WriteLine("JSON parse error");
			case .InvalidSchema:
				Console.Error.WriteLine("Invalid schema structure");
			default:
				Console.Error.WriteLine("Unknown error");
			}
			return 2;
		}
		
		if (parseResult case .Ok(let rootSchema))
		{
			Console.WriteLine("Resolving types...");
			
			var resolver = scope TypeResolver();
			var resolveResult = resolver.Resolve(rootSchema);
			
			if (resolveResult case .Err)
			{
				Console.Error.WriteLine("Error: Type resolution failed");
				delete rootSchema;
				return 3;
			}
			
			if (resolveResult case .Ok(let schemas))
			{
				Console.WriteLine(scope $"Found {schemas.Count} types to generate");
				
				GeneratorConfig config = .();
				config.Namespace = options.Namespace;
				config.IntegerType = options.IntegerType;
				config.NumberType = options.NumberType;
				config.SkipDocs = options.SkipDocs;
				
				var writer = scope FileWriter();
				var writeResult = writer.WriteFiles(schemas, config, options.OutputDir);
				
				if (writeResult case .Err(let writeErr))
				{
					switch (writeErr)
					{
					case .CreateDirectoryFailed(let msg):
						Console.Error.WriteLine(scope $"Error: {msg}");
					case .WriteFailed(let msg):
						Console.Error.WriteLine(scope $"Error: {msg}");
					}
					delete schemas;
					resolver.Cleanup();
					return 4;
				}
				
				Console.WriteLine(scope $"\nSuccessfully generated code in: {options.OutputDir}");
				
				// Delete the list but not the items (TypeResolver will clean them up)
				delete schemas;
			}
			
			// TypeResolver cleanup deletes all schemas including rootSchema
			resolver.Cleanup();
		}
		
		return 0;
	}
	
	private static bool ParseArguments(String[] args, CommandLineOptions options)
	{
		for (int i = 0; i < args.Count; i++)
		{
			StringView arg = args[i];
			
			if (arg == "-h" || arg == "--help")
			{
				options.ShowHelp = true;
				return true;
			}
			else if (arg == "-o" || arg == "--output")
			{
				if (++i >= args.Count) return false;
				options.OutputDir.Set(args[i]);
			}
			else if (arg == "-n" || arg == "--namespace")
			{
				if (++i >= args.Count) return false;
				options.Namespace.Set(args[i]);
			}
			else if (arg == "-c" || arg == "--class")
			{
				if (++i >= args.Count) return false;
				options.RootClassName.Set(args[i]);
			}
			else if (arg == "--integer-type")
			{
				if (++i >= args.Count) return false;
				StringView type = args[i];
				if (type == "int32")
					options.IntegerType = .Int32;
				else if (type == "int64")
					options.IntegerType = .Int64;
			}
			else if (arg == "--number-type")
			{
				if (++i >= args.Count) return false;
				StringView type = args[i];
				if (type == "float")
					options.NumberType = .Float;
				else if (type == "double")
					options.NumberType = .Double;
			}
			else if (arg == "--skip-docs")
			{
				options.SkipDocs = true;
			}
			else if (!arg.StartsWith("-"))
			{
				if (!options.SchemaFile.IsEmpty)
				{
					return false;
				}
				options.SchemaFile.Set(arg);
			}
			else
			{
				return false;
			}
		}
		
		return true;
	}
	
	private static void PrintUsage()
	{
		Console.WriteLine("BJSON.SchemaCodeGen - JSON Schema to Beef Code Generator\n");
		Console.WriteLine("Usage: BJSON.SchemaCodeGen [options] <schema.json>\n");
		Console.WriteLine("Arguments:");
		Console.WriteLine("  schema.json    Input JSON Schema file (required)\n");
		Console.WriteLine("Options:");
		Console.WriteLine("  -o, --output <dir>      Output directory (default: ./generated)");
		Console.WriteLine("  -n, --namespace <name>  Namespace for classes (required)");
		Console.WriteLine("  -c, --class <name>      Root class name override");
		Console.WriteLine("  --integer-type <type>   Integer type: int32, int64 (default: int64)");
		Console.WriteLine("  --number-type <type>    Number type: float, double (default: double)");
		Console.WriteLine("  --skip-docs             Skip documentation comments");
		Console.WriteLine("  -h, --help              Show this help\n");
		Console.WriteLine("Examples:");
		Console.WriteLine("  BJSON.SchemaCodeGen user.schema.json -n MyApp.Models");
		Console.WriteLine("  BJSON.SchemaCodeGen api.schema.json -o ./src/Models -n Api.Models");
		Console.WriteLine("  BJSON.SchemaCodeGen schema.json -n MyApp -c ApiResponse");
	}
	
	private static void ToPascalCase(StringView input, String output)
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
}

class CommandLineOptions
{
	public String SchemaFile = new String() ~ delete _;
	public String OutputDir = new String("./generated") ~ delete _;
	public String Namespace = new String() ~ delete _;
	public String RootClassName = new String() ~ delete _;
	public IntegerType IntegerType = .Int64;
	public NumberType NumberType = .Double;
	public bool SkipDocs;
	public bool ShowHelp;
}
