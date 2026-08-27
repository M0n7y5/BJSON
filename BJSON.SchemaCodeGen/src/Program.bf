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

		if (!IsNamespace(options.Namespace))
		{
			Console.Error.WriteLine(scope $"Error: {options.Namespace} is not a namespace. Expected Beef identifiers joined by '.', for example MyApp.Models.\n");
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

		var parser = scope SchemaParser();
		String schemaSourcePath = scope String();
		Path.GetFullPath(options.SchemaFile, schemaSourcePath);

		bool rootNameIsExplicit = !options.RootClassName.IsEmpty;
		String rootName = scope String();
		if (rootNameIsExplicit)
		{
			rootName.Append(options.RootClassName);
		}
		else
		{
			String titleName = scope String();
			let titleResult = parser.ExtractTitle(schemaContent, titleName);
			if (titleResult case .Ok && !titleName.IsEmpty)
			{
				rootName.Append(titleName);
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
		}
		String pascalRootName = scope String();
		NameMangler.ToPascalCase(rootName, pascalRootName);
		rootName.Set(pascalRootName);

		if (!NameMangler.IsIdentifier(rootName))
		{
			Console.Error.WriteLine("Error: The root class name holds no letter and no digit. Use -c with a name that starts a Beef identifier.\n");
			return 1;
		}

		Console.WriteLine(scope $"Parsing schema: {options.SchemaFile}");

		var parseResult = parser.Parse(schemaContent, rootName, schemaSourcePath, rootNameIsExplicit);

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
				PrintWarnings(parser.Warnings);
				PrintWarnings(resolver.Warnings);
				PrintErrors(resolver.Errors);
				resolver.Cleanup();
				return 3;
			}

			if (resolveResult case .Ok(let schemas))
			{
				PrintWarnings(parser.Warnings);
				PrintWarnings(resolver.Warnings);
				int warningCount = parser.Warnings.Count + resolver.Warnings.Count;
				if (options.WarningsAsErrors && warningCount > 0)
				{
					Console.Error.WriteLine("Error: Warnings were treated as errors.");
					delete schemas;
					resolver.Cleanup();
					return 5;
				}

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
					Console.Error.WriteLine(scope $"Error: {writeErr}. Output directory: {options.OutputDir}");
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
			else if (arg == "--warnings-as-errors")
			{
				options.WarningsAsErrors = true;
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
		String usage = scope String();
		AppendUsage(usage);
		Console.Write((StringView)usage);
	}

	/// Appends the CLI usage text, which states that `-c` outranks the schema `title`.
	/// @param output Caller owned string that receives the text.
	public static void AppendUsage(String output)
	{
		output.Append("BJSON.SchemaCodeGen - JSON Schema to Beef Code Generator\n\n");
		output.Append("Usage: BJSON.SchemaCodeGen [options] <schema.json>\n\n");
		output.Append("Arguments:\n");
		output.Append("  schema.json    Input JSON Schema file (required)\n\n");
		output.Append("Options:\n");
		output.Append("  -o, --output <dir>      Output directory (default: ./generated)\n");
		output.Append("  -n, --namespace <name>  Namespace for classes (required)\n");
		output.Append("  -c, --class <name>      Root class name; outranks the schema title (default: schema title, then file name)\n");
		output.Append("  --integer-type <type>   Integer type: int32, int64 (default: int64)\n");
		output.Append("  --number-type <type>    Number type: float, double (default: double)\n");
		output.Append("  --skip-docs             Skip documentation comments\n");
		output.Append("  --warnings-as-errors    Exit with code 5 instead of writing files when warnings are emitted\n");
		output.Append("  -h, --help              Show this help\n\n");
		output.Append("Examples:\n");
		output.Append("  BJSON.SchemaCodeGen user.schema.json -n MyApp.Models\n");
		output.Append("  BJSON.SchemaCodeGen api.schema.json -o ./src/Models -n Api.Models\n");
		output.Append("  BJSON.SchemaCodeGen schema.json -n MyApp -c ApiResponse\n");
	}

	private static void PrintWarnings(List<String> warnings)
	{
		for (var warning in warnings)
		{
			Console.Error.WriteLine(scope $"Warning: {warning}");
		}
	}

	private static void PrintErrors(List<String> errors)
	{
		for (var err in errors)
		{
			Console.Error.WriteLine(scope $"  {err}");
		}
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

class CommandLineOptions
{
	public String SchemaFile = new String() ~ delete _;
	public String OutputDir = new String("./generated") ~ delete _;
	public String Namespace = new String() ~ delete _;
	public String RootClassName = new String() ~ delete _;
	public IntegerType IntegerType = .Int64;
	public NumberType NumberType = .Double;
	public bool SkipDocs;
	public bool WarningsAsErrors;
	public bool ShowHelp;
}
