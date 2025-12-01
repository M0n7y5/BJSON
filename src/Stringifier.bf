using System;
using BJSON.Models;
namespace BJSON;

class Stringifier
{
	public this()
	{

	}

	public ~this()
	{

	}

	public bool Stringify(String outText)
	{
		return true;

	    String input = scope .(outText);
	    outText.Clear();

	    int indent = 0;
	    bool inString = false;
	    bool escape = false;

	    for (int i = 0; i < input.Length; i++)
	    {
	        char16 c = input[i];

	        // Toggle string state
	        if (!escape && c == '"')
	        {
	            inString = !inString;
	            outText.Append(c);
	            continue;
	        }

	        // If inside a string, just copy and update escape state
	        if (inString)
	        {
	            outText.Append(c);
	            escape = (!escape && c == '\\');
	            continue;
	        }

	        // Outside string — pretty-print structure
	        switch (c)
	        {
	            case '{':
	            case '[':
	                outText.Append(c);
	                outText.Append('\n');
	                indent++;
	                for (int j = 0; j < indent; j++)
	                    outText.Append('\t');
	                break;

	            case '}':
	            case ']':
	                outText.Append('\n');
	                indent--;
	                for (int j = 0; j < indent; j++)
	                    outText.Append('\t');
	                outText.Append(c);
	                break;

	            case ',':
	                outText.Append(c);
	                outText.Append('\n');
	                for (int j = 0; j < indent; j++)
	                    outText.Append('\t');
	                break;

	            case ':':
	                outText.Append(": ");
	                break;

	            default:
	                if (!c.IsWhiteSpace)
	                    outText.Append(c);
	                break;
	        }

	        escape = false; // reset outside strings
	    }

	    return true;
	}

	public bool StringifyOld(String outText)
	{
		String text = scope .(outText);
		outText.Clear();

		char16 delimChar = '\t';
		int tabCount = 0;
		bool inString = false;

		for (int i = 0; i < text.Length; i++)
		{
			char16 c = text[i];

			// Handle string toggling (if not escaped)
			if (c == '"')
			{
				bool escaped = false;
				int j = i - 1;
				while (j >= 0 && text[j] == '\\')
				{
					escaped = !escaped;
					j--;
				}

				if (!escaped)
					inString = !inString;
			}

			if (inString)
				continue;

			if (c == '{' || c == '[')
			{
				tabCount++;
				text.Insert(i + 1, "\n");
				for (int t = 0; t < tabCount; t++)
				{
					text.Insert(i + 2 + t, delimChar);
				}
				i += 1 + tabCount;
			}
			else if (c == ',')
			{
				text.Insert(i + 1, "\n");
				for (int t = 0; t < tabCount; t++)
				{
					text.Insert(i + 2 + t, delimChar);
				}
				i += 1 + tabCount;
			}
			else if (c == '}' || c == ']')
			{
				tabCount--;
				text.Insert(i, "\n");
				i++;
				for (int t = 0; t < tabCount; t++)
				{
					text.Insert(i, delimChar);
					i++;
				}
			}
		}

		outText.Append(text);
		return false;
	}

	public bool StringifyOldOld(String outText)
	{
		String text = scope .(outText);
		outText.Clear();

		char16 delimChar = '\t';

		int tabCount = 0;
		for(int i = 0; i < text.Length; i++)
		{
			if(text[i] == '{' || text[i] == '[')
				tabCount++;
			if(text[i] == '}' || text[i] == ']')
				tabCount--;

			if(text[i] == '{' || text[i] == ',' || text[i] == '[')
			{
				text.Insert(i+1, "\n");

				for(int t = 0; t < tabCount; t++)
				{
					text.Insert(i+2, delimChar);
				}
			}

			if(text[i] == '}' || text[i] == ']')
			{
				text.Insert(i, "\n");
				i++;

				for(int t = 0; t < tabCount; t++)
				{
					text.Insert(i, delimChar);
					i++;
				}
			}
		}

		outText.Append(text);
		return false;
	}
}