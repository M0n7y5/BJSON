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
		
		if (options.ShowHelp)
		{
			PrintUsage();
			return 0;
		}
		
		if (options.SchemaFile.IsEmpty)
		{
			ReportError("Error: a schema file is required.\n");
			PrintUsage();
			return 1;
		}
		
		if (options.Namespace.IsEmpty)
		{
			ReportError("Error: a namespace is required. Use -n or --namespace.\n");
			PrintUsage();
			return 1;
		}
		
		if (!File.Exists(options.SchemaFile))
		{
			ReportError(scope $"Error: schema file not found: {options.SchemaFile}");
			return 1;
		}
		
		String schemaContent = scope String();
		if (File.ReadAllText(options.SchemaFile, schemaContent) case .Err(let fileErr))
		{
			ReportError(scope $"Error: cannot read schema file {options.SchemaFile}: {fileErr}");
			return 1;
		}
		
		// -c wins over a `title` in the document, so the parser only reads `title` without it.
		String rootName = scope String();
		if (!options.RootClassName.IsEmpty)
		{
			ToPascalCase(options.RootClassName, rootName);
		}
		else
		{
			String fileName = scope String();
			Path.GetFileNameWithoutExtension(options.SchemaFile, fileName);
			int dotIndex = fileName.IndexOf('.');
			if (dotIndex >= 0)
			{
				fileName.RemoveToEnd(dotIndex);
			}
			ToPascalCase(fileName, rootName);
		}
		
		Console.WriteLine(scope $"Parsing schema: {options.SchemaFile}");
		
		// The node list owns every schema of the run, so one pass frees the whole graph.
		List<SchemaModel> schemaNodes = scope List<SchemaModel>();
		defer { ClearAndDeleteItems!(schemaNodes); }
		
		var parser = scope SchemaParser();
		if (parser.Parse(schemaContent, rootName, options.RootClassName.IsEmpty, schemaNodes) case .Err(let parseErr))
		{
			ReportError(scope $"Error: failed to parse schema: {parseErr}");
			return 2;
		}
		
		Console.WriteLine("Resolving types...");
		
		var resolver = scope TypeResolver();
		List<SchemaModel> generationOrder = scope List<SchemaModel>();
		if (resolver.Resolve(schemaNodes, generationOrder) case .Err(let resolveErr))
		{
			ReportError(scope $"Error: type resolution failed: {resolveErr}");
			return 3;
		}
		
		if (generationOrder.IsEmpty)
		{
			ReportError("Error: the schema declares no object or enum type, so there is nothing to generate.");
			return 2;
		}
		
		Console.WriteLine(scope $"Found {generationOrder.Count} types to generate");
		
		GeneratorConfig config = .();
		config.Namespace = options.Namespace;
		config.IntegerType = options.IntegerType;
		config.NumberType = options.NumberType;
		config.SkipDocs = options.SkipDocs;
		
		var writer = scope FileWriter();
		if (writer.WriteFiles(generationOrder, config, options.OutputDir) case .Err(let writeErr))
		{
			ReportError(scope $"Error: {writeErr}. Output directory: {options.OutputDir}");
			return 4;
		}
		
		Console.WriteLine(scope $"\nSuccessfully generated code in: {options.OutputDir}");
		
		return 0;
	}
	
	/// Fills options from the command line, reporting the first unusable argument.
	/// @returns false when the caller should print usage and fail.
	private static bool ParseArguments(String[] args, CommandLineOptions options)
	{
		bool sawOutput = false;
		bool sawNamespace = false;
		bool sawClass = false;
		bool sawIntegerType = false;
		bool sawNumberType = false;
		bool sawSkipDocs = false;
		
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
				if (!TakeValue(args, ref i, arg, ref sawOutput, options.OutputDir))
					return false;
			}
			else if (arg == "-n" || arg == "--namespace")
			{
				if (!TakeValue(args, ref i, arg, ref sawNamespace, options.Namespace))
					return false;
			}
			else if (arg == "-c" || arg == "--class")
			{
				if (!TakeValue(args, ref i, arg, ref sawClass, options.RootClassName))
					return false;
			}
			else if (arg == "--integer-type")
			{
				String type = scope String();
				if (!TakeValue(args, ref i, arg, ref sawIntegerType, type))
					return false;
				
				if (type == "int32")
					options.IntegerType = .Int32;
				else if (type == "int64")
					options.IntegerType = .Int64;
				else
				{
					ReportError(scope $"Error: unknown --integer-type value: {type}. Expected int32 or int64.\n");
					return false;
				}
			}
			else if (arg == "--number-type")
			{
				String type = scope String();
				if (!TakeValue(args, ref i, arg, ref sawNumberType, type))
					return false;
				
				if (type == "float")
					options.NumberType = .Float;
				else if (type == "double")
					options.NumberType = .Double;
				else
				{
					ReportError(scope $"Error: unknown --number-type value: {type}. Expected float or double.\n");
					return false;
				}
			}
			else if (arg == "--skip-docs")
			{
				if (sawSkipDocs)
				{
					ReportError(scope $"Error: option {arg} was given more than once.\n");
					return false;
				}
				
				sawSkipDocs = true;
				options.SkipDocs = true;
			}
			else if (!arg.StartsWith("-"))
			{
				if (!options.SchemaFile.IsEmpty)
				{
					ReportError(scope $"Error: only one schema file is accepted, got a second one: {arg}\n");
					return false;
				}
				
				options.SchemaFile.Set(arg);
			}
			else
			{
				ReportError(scope $"Error: unknown option: {arg}\n");
				return false;
			}
		}
		
		return true;
	}
	
	/// Reads the value that follows a flag.
	/// @param i Index of the flag, advanced past the value it consumed.
	/// @param flag The flag as the user spelled it, for the message.
	/// @param seen Whether the flag already appeared. Set once the value is taken.
	/// @param output Caller owned buffer that receives the value.
	/// @returns false after reporting a repeated flag, a missing value or an empty value.
	private static bool TakeValue(String[] args, ref int i, StringView flag, ref bool seen, String output)
	{
		if (seen)
		{
			ReportError(scope $"Error: option {flag} was given more than once.\n");
			return false;
		}
		
		if (i + 1 >= args.Count)
		{
			ReportError(scope $"Error: option {flag} requires a value.\n");
			return false;
		}
		
		i++;
		if (args[i].IsEmpty)
		{
			ReportError(scope $"Error: option {flag} requires a value that is not empty.\n");
			return false;
		}
		
		seen = true;
		output.Set(args[i]);
		
		return true;
	}
	
	/// Reports a message on stderr. A failed diagnostic write cannot be acted on, so its result
	/// is dropped on purpose.
	private static void ReportError(StringView message)
	{
		Console.Error.WriteLine(message).IgnoreError();
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
		Console.WriteLine("  -c, --class <name>      Root class name override (wins over the schema title)");
		Console.WriteLine("  --integer-type <type>   Integer type: int32, int64 (default: int64)");
		Console.WriteLine("  --number-type <type>    Number type: float, double (default: double)");
		Console.WriteLine("  --skip-docs             Skip documentation comments");
		Console.WriteLine("  -h, --help              Show this help\n");
		Console.WriteLine("Examples:");
		Console.WriteLine("  BJSON.SchemaCodeGen user.schema.json -n MyApp.Models");
		Console.WriteLine("  BJSON.SchemaCodeGen api.schema.json -o ./src/Models -n Api.Models");
		Console.WriteLine("  BJSON.SchemaCodeGen schema.json -n MyApp -c ApiResponse");
	}
	
	/// Turns a name into a Beef identifier the same way SchemaParser does: every character that
	/// cannot appear in one acts as a word separator, and a leading digit gets an underscore in
	/// front of it.
	private static void ToPascalCase(StringView input, String output)
	{
		bool nextUpper = true;
		for (int i = 0; i < input.Length; i++)
		{
			char8 c = input[i];
			bool isLetter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
			bool isDigit = c >= '0' && c <= '9';
			if (!isLetter && !isDigit)
			{
				nextUpper = true;
			}
			else if (nextUpper)
			{
				if (output.IsEmpty && isDigit)
				{
					output.Append('_');
				}
				
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
