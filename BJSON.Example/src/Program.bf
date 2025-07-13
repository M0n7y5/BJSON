using System;
using BJSON.Models;
using System.IO;
using BJSON.Attributes;

namespace BJSON.Example
{
	class Program
	{
		public static int Main(String[] args)
		{
			String json =
			@"""
			{
			    "ValueA":"hello \n\n world"
			}
			""";

			var result = Json.Deserialize(json);
			if(result case .Err(let err))
			    Console.WriteLine(scope $"Error2:{err.ToString(.. scope .())}");
		    
			var x = result.Get()["ValueA"].data.string;
			Console.WriteLine(x);

			result.Dispose();

			return 0;
		}
	}
}	
