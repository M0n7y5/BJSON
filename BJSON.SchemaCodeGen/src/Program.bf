using System;
using System.IO;
using System.Collections;

namespace BJSON.SchemaCodeGen;

/// Entry point of the standalone build time generator: schema.json in, one Beef file per generated
/// type out.
/// Usage: BJSON.SchemaCodeGen [options] <schema.json>
/// The single positional argument names the schema document. Options: -o or --output <dir>
/// (default ./generated), -n or --namespace <name> (required), -c or --class <name> (root type
/// name, which beats the schema `title`), --integer-type <int32|int64>, --number-type
/// <float|double>, --skip-docs, and -h or --help. Every option is rejected when it repeats, and
/// every option that takes a value is rejected when the value is missing or empty.
/// A -n value has to spell a Beef namespace, identifiers joined by '.', and the root type name a
/// -c value or the schema file name derives has to hold a letter or a digit. Neither reaches the
/// generated source unchecked.
/// The exit code names the stage that failed:
/// 0, the files were written, or --help was asked for.
/// 1, the arguments are unusable, or the schema file is missing or unreadable.
/// 2, the schema could not be parsed, or it declares no object and no enum, so there is nothing
/// to generate.
/// 3, type resolution failed: an external or unresolved `$ref`, a `$ref` or `allOf` cycle, an
/// unnamed type, or a `required` entry that names no property.
/// 4, the output directory or one of the generated files could not be written.
class Program
{
	/// Runs the pipeline: read the schema file, SchemaParser.Parse, TypeResolver.Resolve,
	/// FileWriter.WriteFiles.
	/// Ownership: the node list scoped here owns every SchemaModel of the run and frees the whole
	/// graph on every path, success or failure. The generation order list only aliases those nodes,
	/// and the option strings outlive the generator that reads them.
	/// @returns The exit code documented on Program.
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
		
		if (!IsNamespace(options.Namespace))
		{
			ReportError(scope $"Error: {options.Namespace} is not a namespace. Expected Beef identifiers joined by '.', for example MyApp.Models.\n");
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
			NameMangler.ToPascalCase(options.RootClassName, rootName);
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
			NameMangler.ToPascalCase(fileName, rootName);
		}
		
		if (!NameMangler.IsIdentifier(rootName))
		{
			ReportError("Error: the root type name holds no letter and no digit. Pass -c with a name that starts a Beef identifier.");
			return 1;
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
	
	/// Whether text spells a Beef namespace: one or more identifiers joined by '.'.
	/// @param text The -n value.
	/// @returns true when text can be interpolated into a `namespace` declaration.
	private static bool IsNamespace(StringView text)
	{
		for (var segment in text.Split('.'))
		{
			if (!NameMangler.IsIdentifier(segment))
			{
				return false;
			}
		}
		
		return true;
	}
}

/// The command line of one run, filled by Program.ParseArguments.
/// Ownership: every string here is allocated with the instance and freed with it. Main scopes the
/// instance, and GeneratorConfig.Namespace plus the output directory view point into these strings,
/// so the instance outlives the code generator and the file writer that read them.
class CommandLineOptions
{
	/// Path of the schema document, from the one positional argument. Empty until it is given.
	public String SchemaFile = new String() ~ delete _;
	/// Directory that receives the generated files, from -o.
	public String OutputDir = new String("./generated") ~ delete _;
	/// Namespace of the generated types, from -n. Required.
	public String Namespace = new String() ~ delete _;
	/// Root type name, from -c. Empty leaves the name to the schema `title`, falling back to the
	/// file name.
	public String RootClassName = new String() ~ delete _;
	/// Beef type for `type: integer`, from --integer-type.
	public IntegerType IntegerType = .Int64;
	/// Beef type for `type: number`, from --number-type.
	public NumberType NumberType = .Double;
	/// Whether --skip-docs was given, which keeps every `description` out of the output.
	public bool SkipDocs;
	/// Whether -h or --help was given, which prints the usage text and ends the run.
	public bool ShowHelp;
}
