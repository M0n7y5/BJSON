using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

/// The one place a JSON name becomes a Beef name. Every generated type name, field name and enum
/// member name passes through here, so no schema can spell a name the Beef compiler rejects and no
/// two names of one scope can collide.
static class NameMangler
{
	/// Turns a JSON name into a Beef identifier: every character that cannot appear in one acts as
	/// a word separator, and a leading digit gets an underscore in front of it.
	/// The result is empty when the name carries no letter and no digit.
	/// @param input The raw JSON name.
	/// @param output Caller owned buffer that receives the identifier.
	public static void ToPascalCase(StringView input, String output)
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

	/// Appends name to output, adding a counter when usedNames already holds it: Status, Status2.
	/// Two JSON names can mangle to one Beef name, and Beef rejects the second declaration, so
	/// every name that shares a scope with another one is placed through here.
	/// Ownership: the accepted name enters usedNames as a new String that the set owns, so a
	/// caller MUST delete the items of a set it scopes.
	/// @param name The name to place, already a Beef identifier.
	/// @param usedNames The names already taken in the scope name has to be unique in.
	/// @param output Caller owned buffer that receives the unique name.
	public static void AppendUnique(StringView name, HashSet<String> usedNames, String output)
	{
		String candidate = scope String(name);
		int suffix = 1;
		while (usedNames.Contains(candidate))
		{
			candidate.Set(name);
			candidate.Append(++suffix);
		}

		usedNames.Add(new String(candidate));
		output.Append(candidate);
	}

	/// Whether text is a Beef identifier: letters, digits and underscores, not opening with a
	/// digit. A keyword passes: the compiler reports one better than a check here could, which
	/// would have to track the language.
	/// @param text The candidate name.
	/// @returns true when text can be interpolated into generated source as a name.
	public static bool IsIdentifier(StringView text)
	{
		if (text.IsEmpty)
		{
			return false;
		}

		for (int i = 0; i < text.Length; i++)
		{
			char8 c = text[i];
			bool isLetter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
			bool isDigit = c >= '0' && c <= '9';

			if (isLetter || (c == '_'))
			{
				continue;
			}

			if (isDigit && (i > 0))
			{
				continue;
			}

			return false;
		}

		return true;
	}
}
