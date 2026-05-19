using System;
using System.IO;
using System.Collections;

namespace BJSON.SchemaCodeGen;

class TypeResolver
{
	private List<SchemaModel> mAllSchemas = new List<SchemaModel>() ~ delete _;
	private HashSet<String> mUsedNames = new HashSet<String>() ~ delete _;
	private Dictionary<String, SchemaModel> mRefTargets = new Dictionary<String, SchemaModel>() ~ delete _;
	private Dictionary<String, SchemaModel> mDocuments = new Dictionary<String, SchemaModel>() ~ delete _;
	private HashSet<SchemaModel> mResolvedSchemas = new HashSet<SchemaModel>() ~ delete _;
	private List<SchemaModel> mGenerationOrder = new List<SchemaModel>() ~ delete _;
	private SchemaModel mRootSchema;

	public List<String> Warnings = new List<String>() ~ DeleteContainerAndItems!(_);
	public List<String> Errors = new List<String>() ~ DeleteContainerAndItems!(_);

	public Result<List<SchemaModel>, SchemaError> Resolve(SchemaModel rootSchema)
	{
		mAllSchemas.Clear();
		ClearUsedNames();
		ClearRefTargets();
		ClearDocuments();
		mResolvedSchemas.Clear();
		mGenerationOrder.Clear();
		ClearAndDeleteItems(Warnings);
		ClearAndDeleteItems(Errors);
		mRootSchema = rootSchema;

		RegisterDocument(rootSchema, rootSchema.SourcePath);

		if (ResolveReferences(rootSchema) case .Err(let resolveErr))
		{
			return .Err(resolveErr);
		}

		AssignNames();

		HashSet<SchemaModel> flattened = scope HashSet<SchemaModel>();
		HashSet<SchemaModel> flattening = scope HashSet<SchemaModel>();
		for (var schema in mAllSchemas)
		{
			if (FlattenAllOf(schema, flattened, flattening) case .Err(let flattenErr))
			{
				return .Err(flattenErr);
			}
		}

		if (BuildGenerationOrder() case .Err(let orderErr))
		{
			return .Err(orderErr);
		}

		var result = new List<SchemaModel>();
		for (var schema in mGenerationOrder)
		{
			result.Add(schema);
		}

		return .Ok(result);
	}

	public void Cleanup()
	{
		for (var schema in mAllSchemas)
		{
			delete schema;
		}
		mAllSchemas.Clear();

		ClearUsedNames();
		ClearRefTargets();
		ClearDocuments();
		mResolvedSchemas.Clear();
		mGenerationOrder.Clear();
		mRootSchema = null;
	}

	private void ClearUsedNames()
	{
		for (var name in mUsedNames)
		{
			delete name;
		}
		mUsedNames.Clear();
	}

	private void ClearRefTargets()
	{
		for (var kvp in mRefTargets)
		{
			delete kvp.key;
		}
		mRefTargets.Clear();
	}

	private void ClearDocuments()
	{
		for (var kvp in mDocuments)
		{
			delete kvp.key;
		}
		mDocuments.Clear();
	}

	private void RegisterDocument(SchemaModel rootSchema, StringView sourcePath)
	{
		String normalizedPath = scope String();
		NormalizeFilePath(sourcePath, normalizedPath);
		SetSourcePath(rootSchema, normalizedPath);

		if (!normalizedPath.IsEmpty)
		{
			SchemaModel existing;
			if (!mDocuments.TryGetValueAlt(normalizedPath, out existing))
			{
				mDocuments.Add(new String(normalizedPath), rootSchema);
			}
		}

		CollectAllSchemas(rootSchema);

		String targetPrefix = scope String();
		BuildDocumentRefPrefix(normalizedPath, targetPrefix);
		RegisterRefTargets(rootSchema, targetPrefix);
	}

	private void SetSourcePath(SchemaModel schema, StringView sourcePath)
	{
		if (schema == null) return;

		schema.SourcePath.Set(sourcePath);

		for (var kvp in schema.Defs)
		{
			SetSourcePath(kvp.value, sourcePath);
		}

		for (var kvp in schema.Definitions)
		{
			SetSourcePath(kvp.value, sourcePath);
		}

		for (var kvp in schema.Properties)
		{
			SetSourcePath(kvp.value.Schema, sourcePath);
		}

		SetSourcePath(schema.Items, sourcePath);

		for (var baseSchema in schema.AllOf)
		{
			SetSourcePath(baseSchema, sourcePath);
		}
	}

	private void CollectAllSchemas(SchemaModel schema)
	{
		if (schema == null) return;

		if (!ContainsSchema(schema))
		{
			mAllSchemas.Add(schema);
		}

		for (var kvp in schema.Defs)
		{
			CollectAllSchemas(kvp.value);
		}

		for (var kvp in schema.Definitions)
		{
			CollectAllSchemas(kvp.value);
		}

		for (var kvp in schema.Properties)
		{
			CollectAllSchemas(kvp.value.Schema);
		}

		CollectAllSchemas(schema.Items);

		for (var baseSchema in schema.AllOf)
		{
			CollectAllSchemas(baseSchema);
		}
	}

	private bool ContainsSchema(SchemaModel schema)
	{
		for (var existing in mAllSchemas)
		{
			if (existing == schema)
			{
				return true;
			}
		}

		return false;
	}

	private void AssignNames()
	{
		for (var schema in mAllSchemas)
		{
			if (schema.Type == .Object || schema.Type == .Enum)
			{
				String baseName = scope String();
				ToValidTypeName(schema.Name, baseName);
				if (baseName.IsEmpty)
				{
					baseName.Append("GeneratedType");
				}

				int suffix = 1;
				String uniqueName = scope String(baseName);

				while (mUsedNames.Contains(uniqueName))
				{
					uniqueName.Clear();
					uniqueName.Append(baseName);
					uniqueName.Append(++suffix);
				}

				mUsedNames.Add(new String(uniqueName));
				schema.Name.Set(uniqueName);
			}
		}
	}

	private void RegisterRefTargets(SchemaModel schema, StringView pointer)
	{
		if (schema == null) return;

		AddRefTarget(pointer, schema);

		for (var kvp in schema.Defs)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "$defs", childPointer);
			AppendChildPointer(childPointer, kvp.key, childPointer);
			RegisterRefTargets(kvp.value, childPointer);
		}

		for (var kvp in schema.Definitions)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "definitions", childPointer);
			AppendChildPointer(childPointer, kvp.key, childPointer);
			RegisterRefTargets(kvp.value, childPointer);
		}

		for (var kvp in schema.Properties)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "properties", childPointer);
			AppendChildPointer(childPointer, kvp.key, childPointer);
			RegisterRefTargets(kvp.value.Schema, childPointer);
		}

		if (schema.Items != null)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "items", childPointer);
			RegisterRefTargets(schema.Items, childPointer);
		}

		for (int i = 0; i < schema.AllOf.Count; i++)
		{
			String childPointer = scope String();
			AppendChildPointer(pointer, "allOf", childPointer);
			String index = scope String();
			index.Append(i);
			AppendChildPointer(childPointer, index, childPointer);
			RegisterRefTargets(schema.AllOf[i], childPointer);
		}
	}

	private void AddRefTarget(StringView pointer, SchemaModel schema)
	{
		SchemaModel existing;
		if (mRefTargets.TryGetValueAlt(pointer, out existing))
		{
			return;
		}

		mRefTargets.Add(new String(pointer), schema);
	}

	private void AppendChildPointer(StringView parent, StringView token, String output)
	{
		String original = scope String(parent);
		output.Clear();
		output.Append(original);
		output.Append("/");
		AppendEscapedPointerToken(token, output);
	}

	private void AppendEscapedPointerToken(StringView token, String output)
	{
		for (int i = 0; i < token.Length; i++)
		{
			char8 c = token[i];
			if (c == '~')
			{
				output.Append("~0");
			}
			else if (c == '/')
			{
				output.Append("~1");
			}
			else
			{
				output.Append(c);
			}
		}
	}

	private Result<void, SchemaError> ResolveReferences(SchemaModel schema)
	{
		if (schema == null) return .Ok;
		if (mResolvedSchemas.Contains(schema)) return .Ok;

		if (schema.Type == .Ref && !schema.RefPath.IsEmpty)
		{
			if (ResolveReference(schema) case .Err(let refErr))
			{
				return .Err(refErr);
			}
		}

		for (var kvp in schema.Defs)
		{
			if (ResolveReferences(kvp.value) case .Err(let err))
			{
				return .Err(err);
			}
		}

		for (var kvp in schema.Definitions)
		{
			if (ResolveReferences(kvp.value) case .Err(let err))
			{
				return .Err(err);
			}
		}

		for (var kvp in schema.Properties)
		{
			if (ResolveReferences(kvp.value.Schema) case .Err(let err))
			{
				return .Err(err);
			}
		}

		if (ResolveReferences(schema.Items) case .Err(let itemsErr))
		{
			return .Err(itemsErr);
		}

		for (var baseSchema in schema.AllOf)
		{
			if (ResolveReferences(baseSchema) case .Err(let allOfErr))
			{
				return .Err(allOfErr);
			}
		}

		mResolvedSchemas.Add(schema);
		return .Ok;
	}

	private Result<void, SchemaError> ResolveReference(SchemaModel schema)
	{
		if (IsUnsupportedRemoteRef(schema.RefPath))
		{
			AddWarning(scope $"Remote $ref '{schema.RefPath}' is not supported; using JsonValue fallback.");
			schema.Type = .Any;
			schema.RefPath.Clear();
			return .Ok;
		}

		StringView docPart;
		StringView fragment;
		SplitRef(schema.RefPath, out docPart, out fragment);

		String docPath = scope String();
		if (!docPart.IsEmpty)
		{
			ResolveLocalRefPath(docPart, schema.SourcePath, docPath);
			if (LoadDocument(docPath) case .Err(let loadErr))
			{
				return .Err(loadErr);
			}
		}
		else
		{
			docPath.Set(schema.SourcePath);
		}

		String targetKey = scope String();
		BuildRefTargetKey(docPath, fragment, targetKey);

		SchemaModel target;
		if (mRefTargets.TryGetValueAlt(targetKey, out target))
		{
			schema.ReferencedSchema = target;
			return .Ok;
		}

		if (docPart.IsEmpty)
		{
			AddError(scope $"Unresolved internal $ref '{schema.RefPath}'.");
		}
		else
		{
			AddError(scope $"Unresolved local $ref '{schema.RefPath}' in '{schema.SourcePath}'. Missing target '{targetKey}'.");
		}
		return .Err(.UnresolvedRef);
	}

	private Result<SchemaModel, SchemaError> LoadDocument(StringView docPath)
	{
		SchemaModel cached;
		if (mDocuments.TryGetValueAlt(docPath, out cached))
		{
			return .Ok(cached);
		}

		if (!File.Exists(docPath))
		{
			AddError(scope $"Referenced schema file not found: {docPath}");
			return .Err(.UnresolvedRef);
		}

		String schemaContent = scope String();
		let readResult = File.ReadAllText(docPath, schemaContent);
		if (readResult case .Err(let fileErr))
		{
			AddError(scope $"Failed to read referenced schema file '{docPath}': {fileErr}");
			return .Err(.UnresolvedRef);
		}

		String rootName = scope String();
		BuildRootName(docPath, rootName);

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaContent, rootName, docPath);
		for (var warning in parser.Warnings)
		{
			AddWarning(warning);
		}

		if (parseResult case .Err)
		{
			AddError(scope $"Referenced schema file is not valid JSON Schema: {docPath}");
			return .Err(.UnresolvedRef);
		}

		if (parseResult case .Ok(let externalRoot))
		{
			RegisterDocument(externalRoot, docPath);
			if (ResolveReferences(externalRoot) case .Err(let resolveErr))
			{
				return .Err(resolveErr);
			}
			return .Ok(externalRoot);
		}

		AddError(scope $"Referenced schema file is not valid JSON Schema: {docPath}");
		return .Err(.UnresolvedRef);
	}

	private void SplitRef(StringView reference, out StringView docPart, out StringView fragment)
	{
		int hashIndex = reference.IndexOf('#');
		if (hashIndex == -1)
		{
			docPart = reference;
			fragment = "";
			return;
		}

		docPart = reference.Substring(0, hashIndex);
		fragment = reference.Substring(hashIndex + 1);
	}

	private void ResolveLocalRefPath(StringView docPart, StringView sourcePath, String output)
	{
		output.Clear();

		String localPath = scope String();
		if (StartsWithIgnoreCase(docPart, "file://"))
		{
			FileUriToPath(docPart, localPath);
		}
		else
		{
			localPath.Append(docPart);
		}

		if (IsAbsolutePath(localPath))
		{
			NormalizeFilePath(localPath, output);
			return;
		}

		String baseDir = scope String();
		if (!sourcePath.IsEmpty)
		{
			if (Path.GetDirectoryPath(sourcePath, baseDir) case .Err)
			{
				GetContainingDirectory(sourcePath, baseDir);
			}
		}
		if (baseDir.IsEmpty)
		{
			NormalizeFilePath(localPath, output);
			return;
		}

		String combined = scope String(baseDir);
		if (!combined.EndsWith("\\") && !combined.EndsWith("/"))
		{
			combined.Append(Path.DirectorySeparatorChar);
		}
		combined.Append(localPath);
		NormalizeFilePath(combined, output);
	}

	private void NormalizeFilePath(StringView filePath, String output)
	{
		output.Clear();
		if (filePath.IsEmpty)
		{
			return;
		}

		if (IsAbsolutePath(filePath))
		{
			NormalizePathSegments(filePath, output);
			return;
		}

		String currentDirectory = scope String();
		Directory.GetCurrentDirectory(currentDirectory);

		String combined = scope String(currentDirectory);
		if (!combined.EndsWith("\\") && !combined.EndsWith("/"))
		{
			combined.Append(Path.DirectorySeparatorChar);
		}
		combined.Append(filePath);
		NormalizePathSegments(combined, output);
	}

	private void GetContainingDirectory(StringView filePath, String output)
	{
		output.Clear();
		int lastSeparator = -1;
		for (int i = 0; i < filePath.Length; i++)
		{
			if (IsPathSeparator(filePath[i]))
			{
				lastSeparator = i;
			}
		}

		if (lastSeparator > 0)
		{
			output.Append(filePath, 0, lastSeparator);
		}
		else if (lastSeparator == 0)
		{
			output.Append(filePath, 0, 1);
		}
	}

	private int GetRootLength(StringView path)
	{
		if (path.Length >= 2 && path[1] == ':')
		{
			if (path.Length >= 3 && IsPathSeparator(path[2]))
			{
				return 3;
			}
			return 2;
		}

		if (path.Length >= 1 && IsPathSeparator(path[0]))
		{
			return 1;
		}

		return 0;
	}

	private void NormalizePathSegments(StringView filePath, String output)
	{
		output.Clear();
		if (filePath.IsEmpty)
		{
			return;
		}

		int rootLength = GetRootLength(filePath);
		if (rootLength > 0)
		{
			output.Append(filePath, 0, rootLength);
			NormalizePathSeparators(output);
		}

		int segmentStart = rootLength;
		for (int i = rootLength; i <= filePath.Length; i++)
		{
			if (i == filePath.Length || IsPathSeparator(filePath[i]))
			{
				let segment = filePath.Substring(segmentStart, i - segmentStart);
				if (segment == "" || segment == ".")
				{
				}
				else if (segment == "..")
				{
					RemoveLastPathSegment(output);
				}
				else
				{
					AppendPathSegment(output, segment);
				}

				segmentStart = i + 1;
			}
		}
	}

	private void NormalizePathSeparators(String path)
	{
		for (int i = 0; i < path.Length; i++)
		{
			if (IsPathSeparator(path[i]))
			{
				path[i] = Path.DirectorySeparatorChar;
			}
		}
	}

	private void AppendPathSegment(String output, StringView segment)
	{
		if (!output.IsEmpty && !IsPathSeparator(output[output.Length - 1]) && !(output.Length == 2 && output[1] == ':'))
		{
			output.Append(Path.DirectorySeparatorChar);
		}

		output.Append(segment);
	}

	private void RemoveLastPathSegment(String output)
	{
		int rootLength = GetRootLength(output);
		if (output.Length <= rootLength)
		{
			return;
		}

		int removeStart = output.Length;
		while (removeStart > rootLength && !IsPathSeparator(output[removeStart - 1]))
		{
			removeStart--;
		}

		if (removeStart > rootLength)
		{
			removeStart--;
		}

		output.Remove(removeStart, output.Length - removeStart);
	}

	private bool IsPathSeparator(char8 c)
	{
		return c == '/' || c == '\\';
	}

	private void BuildDocumentRefPrefix(StringView docPath, String output)
	{
		output.Clear();
		if (!docPath.IsEmpty)
		{
			output.Append(docPath);
		}
		output.Append("#");
	}

	private void BuildRefTargetKey(StringView docPath, StringView fragment, String output)
	{
		BuildDocumentRefPrefix(docPath, output);
		output.Append(fragment);
	}

	private void BuildRootName(StringView docPath, String output)
	{
		output.Clear();

		String fileName = scope String();
		Path.GetFileNameWithoutExtension(docPath, fileName);
		output.Append(fileName);

		int dotIndex = output.IndexOf('.');
		if (dotIndex >= 0)
		{
			output.RemoveToEnd(dotIndex);
		}

		String typeName = scope String();
		ToValidTypeName(output, typeName);
		output.Set(typeName);
		if (output.IsEmpty)
		{
			output.Append("GeneratedType");
		}
	}

	private void FileUriToPath(StringView uri, String output)
	{
		output.Clear();
		var path = uri.Substring(7);
		if (path.Length >= 3 && path[0] == '/' && path[2] == ':')
		{
			path = path.Substring(1);
		}
		output.Append(path);
	}

	private bool IsUnsupportedRemoteRef(StringView refPath)
	{
		return StartsWithIgnoreCase(refPath, "http://") || StartsWithIgnoreCase(refPath, "https://");
	}

	private bool IsAbsolutePath(StringView path)
	{
		if (path.Length >= 1 && IsPathSeparator(path[0]))
		{
			return true;
		}

		return IsWindowsAbsolutePath(path);
	}

	private bool IsWindowsAbsolutePath(StringView path)
	{
		if (path.Length < 2 || path[1] != ':')
		{
			return false;
		}

		char8 drive = path[0];
		return (drive >= 'a' && drive <= 'z') || (drive >= 'A' && drive <= 'Z');
	}

	private bool StartsWithIgnoreCase(StringView text, StringView prefix)
	{
		if (prefix.Length > text.Length)
		{
			return false;
		}

		for (int i = 0; i < prefix.Length; i++)
		{
			if (ToLower(text[i]) != ToLower(prefix[i]))
			{
				return false;
			}
		}

		return true;
	}

	private char8 ToLower(char8 c)
	{
		if (c >= 'A' && c <= 'Z')
		{
			return (char8)(c + 32);
		}

		return c;
	}

	private Result<void, SchemaError> FlattenAllOf(SchemaModel schema, HashSet<SchemaModel> processed, HashSet<SchemaModel> visiting)
	{
		if (schema == null) return .Ok;
		if (processed.Contains(schema)) return .Ok;

		if (visiting.Contains(schema))
		{
			AddError(scope $"Circular allOf reference involving '{schema.Name}'.");
			return .Err(.CircularRef);
		}

		visiting.Add(schema);

		for (var baseSchema in schema.AllOf)
		{
			SchemaModel resolvedBase = ResolveAlias(baseSchema);
			if (resolvedBase == null)
			{
				continue;
			}

			if (FlattenAllOf(resolvedBase, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}

			if (resolvedBase.Type == .Object)
			{
				CopyObjectProperties(schema, resolvedBase);
			}
			else if (resolvedBase.Type != .Any)
			{
				AddWarning(scope $"Schema '{schema.Name}' has a non-object allOf member; ignoring it for structural generation.");
			}
		}

		ApplyRequired(schema);

		for (var kvp in schema.Defs)
		{
			if (FlattenAllOf(kvp.value, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}

		for (var kvp in schema.Definitions)
		{
			if (FlattenAllOf(kvp.value, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}

		for (var kvp in schema.Properties)
		{
			if (FlattenAllOf(kvp.value.Schema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}

		if (FlattenAllOf(schema.Items, processed, visiting) case .Err(let err))
		{
			return .Err(err);
		}

		visiting.Remove(schema);
		processed.Add(schema);
		return .Ok;
	}

	private SchemaModel ResolveAlias(SchemaModel schema)
	{
		if (schema == null) return null;

		if (schema.Type == .Ref && schema.ReferencedSchema != null)
		{
			return schema.ReferencedSchema;
		}

		return schema;
	}

	private void CopyObjectProperties(SchemaModel target, SchemaModel source)
	{
		for (var kvp in source.Properties)
		{
			String matchKey;
			PropertyModel existingProp;
			if (target.Properties.TryGet(kvp.key, out matchKey, out existingProp))
			{
				if (kvp.value.IsRequired)
				{
					existingProp.IsRequired = true;
					AddRequired(target, kvp.key);
				}
				AddWarning(scope $"Schema '{target.Name}' already has property '{kvp.key}' while flattening allOf; keeping the existing field.");
				continue;
			}

			var propCopy = new PropertyModel();
			propCopy.Name.Set(kvp.value.Name);
			propCopy.JsonName.Set(kvp.value.JsonName);
			propCopy.Schema = kvp.value.Schema;
			propCopy.IsRequired = kvp.value.IsRequired;
			propCopy.DefaultValue.Set(kvp.value.DefaultValue);
			propCopy.Description.Set(kvp.value.Description);

			target.Properties.Add(new String(kvp.key), propCopy);

			if (propCopy.IsRequired)
			{
				AddRequired(target, kvp.key);
			}
		}
	}

	private void ApplyRequired(SchemaModel schema)
	{
		for (var req in schema.Required)
		{
			String matchKey;
			PropertyModel prop;
			if (schema.Properties.TryGetAlt(req, out matchKey, out prop))
			{
				prop.IsRequired = true;
			}
		}
	}

	private void AddRequired(SchemaModel schema, StringView name)
	{
		for (var req in schema.Required)
		{
			if (req == name)
			{
				return;
			}
		}

		schema.Required.Add(new String(name));
	}

	private Result<void, SchemaError> BuildGenerationOrder()
	{
		HashSet<SchemaModel> processed = scope HashSet<SchemaModel>();
		HashSet<SchemaModel> visiting = scope HashSet<SchemaModel>();

		for (var schema in mAllSchemas)
		{
			if (AddToOrder(schema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}

		return .Ok;
	}

	private Result<void, SchemaError> AddToOrder(SchemaModel schema, HashSet<SchemaModel> processed, HashSet<SchemaModel> visiting)
	{
		if (schema == null || processed.Contains(schema)) return .Ok;

		if (visiting.Contains(schema))
		{
			AddError(scope $"Circular schema reference involving '{schema.Name}'.");
			return .Err(.CircularRef);
		}

		visiting.Add(schema);

		if (schema.Type == .Ref && schema.ReferencedSchema != null)
		{
			if (AddToOrder(schema.ReferencedSchema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}

		for (var baseSchema in schema.AllOf)
		{
			if (AddToOrder(ResolveAlias(baseSchema), processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}

		for (var kvp in schema.Properties)
		{
			if (AddToOrder(kvp.value.Schema, processed, visiting) case .Err(let err))
			{
				return .Err(err);
			}
		}

		if (AddToOrder(schema.Items, processed, visiting) case .Err(let itemsErr))
		{
			return .Err(itemsErr);
		}

		for (var kvp in schema.Defs)
		{
			if (AddToOrder(kvp.value, processed, visiting) case .Err(let defsErr))
			{
				return .Err(defsErr);
			}
		}

		for (var kvp in schema.Definitions)
		{
			if (AddToOrder(kvp.value, processed, visiting) case .Err(let definitionsErr))
			{
				return .Err(definitionsErr);
			}
		}

		visiting.Remove(schema);
		processed.Add(schema);

		if (schema.Emit && (schema.Type == .Enum || schema.Type == .Object))
		{
			mGenerationOrder.Add(schema);
		}

		return .Ok;
	}

	private void ToValidTypeName(StringView input, String output)
	{
		bool nextUpper = true;
		for (int i = 0; i < input.Length; i++)
		{
			char8 c = input[i];
			bool isLetter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
			bool isDigit = c >= '0' && c <= '9';

			if (isLetter || isDigit)
			{
				if (output.IsEmpty && isDigit)
				{
					output.Append("_");
				}

				if (nextUpper && c >= 'a' && c <= 'z')
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
				nextUpper = true;
			}
		}
	}

	private void AddWarning(StringView message)
	{
		Warnings.Add(new String(message));
	}

	private void AddError(StringView message)
	{
		Errors.Add(new String(message));
	}
}
