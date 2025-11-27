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

		/*
		for(int i = 0; i < text.Length; i++)
		{
			Console.Write(text[i]);
		}
		*/

		outText.Append(text);
		return false;
	}
}