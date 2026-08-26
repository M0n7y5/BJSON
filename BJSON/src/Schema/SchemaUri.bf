using System;

namespace BJSON;

static class SchemaUri
{
	public static void NormalizeBaseUri(StringView uri, String output)
	{
		output.Clear();
		if (uri.IsEmpty)
			return;

		int hashIndex = uri.IndexOf('#');
		if (hashIndex == -1)
			output.Append(uri);
		else
			output.Append(uri.Substring(0, hashIndex));
	}

	public static void ResolveUri(StringView baseUri, StringView reference, String output)
	{
		output.Clear();
		if (reference.IsEmpty)
		{
			output.Append(baseUri);
			return;
		}

		if (reference.StartsWith("#"))
		{
			output.Append(baseUri);
			output.Append(reference);
			return;
		}

		if (IsAbsoluteUri(reference) || reference.StartsWith("/") || reference.StartsWith("\\"))
		{
			output.Append(reference);
			return;
		}

		if (baseUri.IsEmpty)
		{
			output.Append(reference);
			return;
		}

		let baseNoFrag = scope String();
		NormalizeBaseUri(baseUri, baseNoFrag);
		let dir = scope String();
		GetDirectory(baseNoFrag, dir);
		if (!dir.IsEmpty)
			AppendPath(dir, reference, output);
		else
			output.Append(reference);
	}

	public static void SplitRef(StringView reference, out StringView docUri, out StringView fragment)
	{
		int hashIndex = reference.IndexOf('#');
		if (hashIndex == -1)
		{
			docUri = reference;
			fragment = "";
			return;
		}

		docUri = reference.Substring(0, hashIndex);
		fragment = reference.Substring(hashIndex + 1);
	}

	public static void BuildAnchorKey(StringView baseUri, StringView anchor, String output)
	{
		output.Clear();
		output.Append(baseUri);
		output.Append('#');
		output.Append(anchor);
	}

	public static void BuildPointer(StringView basePointer, StringView segment, String output)
	{
		output.Clear();
		output.Append(basePointer);
		JsonPointer.Build(segment, output);
	}

	public static void UriToPath(StringView uri, String output)
	{
		output.Clear();
		if (uri.StartsWith("file://"))
		{
			var path = uri.Substring(7);
			if (path.Length >= 3 && path[0] == '/' && path[2] == ':')
				path = path.Substring(1);
			output.Append(path);
			return;
		}
		output.Append(uri);
	}

	private static bool IsAbsoluteUri(StringView uri)
	{
		for (int i = 0; i < uri.Length; i++)
		{
			let c = uri[i];
			if (c == ':')
				return true;
			if (c == '/' || c == '\\')
				break;
		}
		return false;
	}

	private static void GetDirectory(StringView path, String output)
	{
		output.Clear();
		int lastIndex = -1;
		for (int i = 0; i < path.Length; i++)
		{
			let c = path[i];
			if (c == '/' || c == '\\')
				lastIndex = i;
		}
		if (lastIndex > 0)
			output.Append(path.Substring(0, lastIndex));
	}

	private static void AppendPath(StringView dir, StringView relative, String output)
	{
		output.Clear();
		output.Append(dir);
		if (!dir.IsEmpty)
		{
			let last = dir[dir.Length - 1];
			if (last != '/' && last != '\\')
			{
				char8 separator = '/';
				for (let c in dir)
				{
					if (c == '\\')
					{
						separator = '\\';
						break;
					}
				}
				output.Append(separator);
			}
		}
		output.Append(relative);
	}
}
