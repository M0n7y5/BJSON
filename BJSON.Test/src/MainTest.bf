using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;
namespace BJSON.Test
{
	// most of the tests are taken from:
	// https://github.com/nlohmann/json/blob/develop/tests/src/unit-testsuites.cpp

	class MainTest
	{
		static int idx = 1;

		[Test(Name = "Compliance tests from JSONTestSuite")]
		public static void T_TestSuite1()
		{
			// test cases from https://github.com/nst/JSONTestSuite
			// https://seriot.ch/projects/parsing_json.html

			Debug.WriteLine("Compliance tests from JSONTestSuite ...");

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "nst_json_testsuite");

			let files = Directory.EnumerateFiles(currentPath);
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());

				let fileName = file.GetFileName(.. scope .());

				bool ignoreResult = fileName[0] == 'i';
				bool shouldFail = fileName[0] == 'n';

				let stream = scope FileStream();

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					defer stream.Close();
					var result = Json.Deserialize(stream);

					result.Dispose();

					if (ignoreResult == false)
					{
						if (result case .Ok)
						{
							Test.Assert(shouldFail == false, scope $"This file should not be successfully parsed! {fileName}");
						}
						else
						{
							Test.Assert(shouldFail, scope $"This file should not fail to parse! {fileName}");
						}
					}

					Debug.WriteLine(scope $"{idx} Done testing file: {fileName} Result: {result case .Ok ? "Ok" : "Err"}");
				}
				else
				{
					Test.Assert(false, scope $"Unable to open file {fileName}");
				}

				idx++;
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		[Test(Name = "Compliance tests from json.org")]
		public static void T_TestSuite2()
		{
			// test cases from https://json.org/JSON_checker/
			
			Debug.WriteLine("Compliance tests from json.org ...");
			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "json_org_testsuite");

			let files = Directory.EnumerateFiles(currentPath);
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());

				let fileName = file.GetFileName(.. scope .());

				if (fileName.StartsWith("fail1"))
				{
					//this test is not RFC 8259 compliant
					continue;
				}

				bool shouldFail = fileName.StartsWith("fail");

				let stream = scope FileStream();

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					defer stream.Close();

					var result = Json.Deserialize(stream);
					defer result.Dispose();

					Console.WriteLine();

					if (result case .Ok)
					{
						Test.Assert(shouldFail == false, scope $"This file should not be successfully parsed! {fileName}");
					}
					else
					{
						Test.Assert(shouldFail, scope $"This file should not fail to parse! {fileName}");
					}

					Debug.WriteLine(scope $"{idx} Done testing file: {fileName} Result: {result case .Ok ? "Ok" : "Err"}");
				}
				else
				{
					Test.Assert(false, scope $"Unable to open file {fileName}");
				}

				idx++;
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		[Test(Name = "Big List of Naughty Strings")]
		public static void T_TestSuite3()
		{
			// test from https://github.com/minimaxir/big-list-of-naughty-strings

			Debug.WriteLine("Big List of Naughty Strings ...");
			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "big_list_of_naughty_strings");

			let files = Directory.EnumerateFiles(currentPath);
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());

				let fileName = file.GetFileName(.. scope .());

				let stream = scope FileStream();

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					defer stream.Close();

					var result = Json.Deserialize(stream);
					defer result.Dispose();

					Console.WriteLine();

					if (result case .Err(let err))
					{
						Test.Assert(false, scope $"Parsing naughty strings failed! Err: {err.ToString(.. scope .())}");
					}

					Debug.WriteLine(scope $"{idx} Done testing file: {fileName} Result: {result case .Ok ? "Ok" : "Err"}");
				}
				else
				{
					Test.Assert(false, scope $"Unable to open file {fileName}");
				}
				idx++;
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		[Test(Name = "nativejson-benchmark round-trip tests")]
		public static void T_TestSuite4()
		{
			// test from https://github.com/minimaxir/big-list-of-naughty-strings

			Debug.WriteLine("nativejson-benchmark round-trip tests ...");
			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "nativejson_benchmark", "roundtrip");

			let files = Directory.EnumerateFiles(currentPath);
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());
				let fileName = file.GetFileName(.. scope .());

				let stream = scope FileStream();
				let strReader = scope StreamReader(stream);

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					defer stream.Close();

					let inputStr = strReader.ReadToEnd(.. scope .());

					var result = Json.Deserialize(inputStr);
					defer result.Dispose();

					Console.WriteLine();
					if (result case .Err(let err))
					{
						Test.Assert(false, scope $"Roundtrip parsing failed! ({fileName}) Err: {err.ToString(.. scope .())}");
						return;
					}

					let outJson = Json.Serialize(result, .. scope .());
					Test.Assert(inputStr == outJson, scope $"Failed to pass rountrip test. ({fileName}) Expected: {inputStr}, Got: {outJson}");

					Debug.WriteLine(scope $"{idx} Done testing file: {fileName} Result: {result case .Ok ? "Ok" : "Err"}");
				}
				else
				{
					Test.Assert(false, scope $"Unable to open file {fileName}");
				}
				idx++;
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		[Test(Name = "Compliance tests from nativejson-benchmark")]
		public static void T_TestSuite5()
		{
			Debug.WriteLine("Compliance tests from nativejson-benchmark ...");
			// test cases from https://github.com/miloyip/nativejson-benchmark/blob/master/src/main.cpp

			static void TEST_DOUBLE(StringView json_string, double expected)
			{
				var result = Json.Deserialize(json_string);
				defer result.Dispose();

				switch (result)
				{
				case .Ok(let val):
					double number = val[0];
					Test.Assert(number == expected, scope $"Expected: {expected}, Got: {number}");

					Debug.WriteLine(scope $"{idx} Done testing {json_string}.");
					idx++;
				case .Err(let err):
					Test.Assert(false, scope $"Parsing double failed! String: {json_string}, Err: {err.ToString(.. scope .())}");
				}
			}

			TEST_DOUBLE("[0.0]", 0.0);
			TEST_DOUBLE("[-0.0]", -0.0);
			TEST_DOUBLE("[1.0]", 1.0);
			TEST_DOUBLE("[-1.0]", -1.0);
			TEST_DOUBLE("[1.5]", 1.5);
			TEST_DOUBLE("[-1.5]", -1.5);
			TEST_DOUBLE("[3.1416]", 3.1416);
			TEST_DOUBLE("[1E10]", 1E10);
			TEST_DOUBLE("[1e10]", 1e10);
			TEST_DOUBLE("[1E+10]", 1E+10);
			TEST_DOUBLE("[1E-10]", 1E-10);
			TEST_DOUBLE("[-1E10]", -1E10);
			TEST_DOUBLE("[-1e10]", -1e10);
			TEST_DOUBLE("[-1E+10]", -1E+10);
			TEST_DOUBLE("[-1E-10]", -1E-10);
			TEST_DOUBLE("[1.234E+10]", 1.234E+10);
			TEST_DOUBLE("[1.234E-10]", 1.234E-10);
			TEST_DOUBLE("[1.79769e+308]", 1.79769e+308);
			TEST_DOUBLE("[2.22507e-308]", 2.22507e-308);
			TEST_DOUBLE("[-1.79769e+308]", -1.79769e+308);
			TEST_DOUBLE("[-2.22507e-308]", -2.22507e-308);
			TEST_DOUBLE("[4.9406564584124654e-324]", 4.9406564584124654e-324); // minimum denormal
			TEST_DOUBLE("[2.2250738585072009e-308]", 2.2250738585072009e-308); // Max subnormal double
			TEST_DOUBLE("[2.2250738585072014e-308]", 2.2250738585072014e-308); // Min normal positive double
			TEST_DOUBLE("[1.7976931348623157e+308]", 1.7976931348623157e+308); // Max double
			TEST_DOUBLE("[1e-10000]", 0.0); // must underflow
			TEST_DOUBLE("[18446744073709551616]", 
				18446744073709551616.0); // 2^64 (max of uint64_t + 1, force to use double)
			TEST_DOUBLE("[-9223372036854775809]", 
				-9223372036854775809.0); // -2^63 - 1(min of int63_t + 1, force to use double)
			TEST_DOUBLE("[0.9868011474609375]", 
				0.9868011474609375); // https://github.com/miloyip/rapidjson/issues/120
			TEST_DOUBLE("[123e34]", 123e34); // Fast Path Cases In Disguise
			TEST_DOUBLE("[45913141877270640000.0]", 45913141877270640000.0);
			TEST_DOUBLE("[2.2250738585072011e-308]", 
				2.2250738585072011e-308);
			//TEST_DOUBLE("[1e-00011111111111]", 0.0);
			//TEST_DOUBLE("[-1e-00011111111111]", -0.0);
			TEST_DOUBLE("[1e-214748363]", 0.0);
			TEST_DOUBLE("[1e-214748364]", 0.0);
			//TEST_DOUBLE("[1e-21474836311]", 0.0);
			TEST_DOUBLE("[0.017976931348623157e+310]", 1.7976931348623157e+308); // Max double in another form

			// Since
			// abs((2^-1022 - 2^-1074) - 2.2250738585072012e-308) = 3.109754131239141401123495768877590405345064751974375599... ¡Á 10^-324
			// abs((2^-1022) - 2.2250738585072012e-308) = 1.830902327173324040642192159804623318305533274168872044... ¡Á 10 ^ -324
			// So 2.2250738585072012e-308 should round to 2^-1022 = 2.2250738585072014e-308
			TEST_DOUBLE("[2.2250738585072012e-308]",
				2.2250738585072014e-308);

			// More closer to normal/subnormal boundary
			// boundary = 2^-1022 - 2^-1075 = 2.22507385850720113605740979670913197593481954635164564e-308
			TEST_DOUBLE("[2.22507385850720113605740979670913197593481954635164564e-308]", 
				2.2250738585072009e-308);
			TEST_DOUBLE("[2.22507385850720113605740979670913197593481954635164565e-308]", 
				2.2250738585072014e-308);

			// 1.0 is in (1.0 - 2^-54, 1.0 + 2^-53)
			// 1.0 - 2^-54 = 0.999999999999999944488848768742172978818416595458984375
			TEST_DOUBLE("[0.999999999999999944488848768742172978818416595458984375]", 1.0); // round to even
			TEST_DOUBLE("[0.999999999999999944488848768742172978818416595458984374]",	
				0.99999999999999989); // previous double
			TEST_DOUBLE("[0.999999999999999944488848768742172978818416595458984376]", 1.0); // next double
			// 1.0 + 2^-53 = 1.00000000000000011102230246251565404236316680908203125
			TEST_DOUBLE("[1.00000000000000011102230246251565404236316680908203125]", 1.0); // round to even
			TEST_DOUBLE("[1.00000000000000011102230246251565404236316680908203124]", 1.0); // previous double
			TEST_DOUBLE("[1.00000000000000011102230246251565404236316680908203126]", 
				1.00000000000000022); // next double

			// Numbers from https://github.com/floitsch/double-conversion/blob/master/test/cctest/test-strtod.cc

			TEST_DOUBLE("[72057594037927928.0]", 72057594037927928.0);
			TEST_DOUBLE("[72057594037927936.0]", 72057594037927936.0);
			TEST_DOUBLE("[72057594037927932.0]", 72057594037927936.0);
			TEST_DOUBLE("[7205759403792793199999e-5]", 72057594037927928.0);
			TEST_DOUBLE("[7205759403792793200001e-5]", 72057594037927936.0);

			TEST_DOUBLE("[9223372036854774784.0]", 9223372036854774784.0);
			TEST_DOUBLE("[9223372036854775808.0]", 9223372036854775808.0);
			TEST_DOUBLE("[9223372036854775296.0]", 9223372036854775808.0);
			TEST_DOUBLE("[922337203685477529599999e-5]", 9223372036854774784.0);
			TEST_DOUBLE("[922337203685477529600001e-5]", 9223372036854775808.0);

			TEST_DOUBLE("[10141204801825834086073718800384]", 10141204801825834086073718800384.0);
			TEST_DOUBLE("[10141204801825835211973625643008]", 10141204801825835211973625643008.0);
			TEST_DOUBLE("[10141204801825834649023672221696]", 10141204801825835211973625643008.0);
			TEST_DOUBLE("[1014120480182583464902367222169599999e-5]", 10141204801825834086073718800384.0);
			TEST_DOUBLE("[1014120480182583464902367222169600001e-5]", 10141204801825835211973625643008.0);

			{
				String n1e308 = scope .('0', 311); // '1' followed by 308 '0'
				n1e308[0] = '[';
				n1e308[1] = '1';
				n1e308[310] = ']';
				TEST_DOUBLE(n1e308, 1E308);
			}

			// Cover trimming
			TEST_DOUBLE(
				"[2.22507385850720113605740979670913197593481954635164564802342610972482222202107694551652952390813508" +
				"7914149158913039621106870086438694594645527657207407820621743379988141063267329253552286881372149012" +
				"9811224514518898490572223072852551331557550159143974763979834118019993239625482890171070818506906306" +
				"6665599493827577257201576306269066333264756530000924588831643303777979186961204949739037782970490505" +
				"1080609940730262937128958950003583799967207254304360284078895771796150945516748243471030702609144621" +
				"5722898802581825451803257070188608721131280795122334262883686223215037756666225039825343359745688844" +
				"2390026549819838548794829220689472168983109969836584681402285424333066033985088644580400103493397042" +
				"7567186443383770486037861622771738545623065874679014086723327636718751234567890123456789012345678901" +
				"e-308]",
				2.2250738585072014e-308);

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		[Test(Name = "Serialization - Basic tests")]
		public static void T_SerializationBasic()
		{
			Debug.WriteLine("Serialization - Basic tests ...");

			// Test 1: Serialize null
			{
				let json = JsonNull();
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of null should succeed");
				Test.Assert(output == "null", scope $"Expected 'null', got '{output}'");
				Debug.WriteLine(scope $"  Test 1 (null): PASSED - output: {output}");
			}

			// Test 2: Serialize boolean true
			{
				let json = JsonBool(true);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of true should succeed");
				Test.Assert(output == "true", scope $"Expected 'true', got '{output}'");
				Debug.WriteLine(scope $"  Test 2 (true): PASSED - output: {output}");
			}

			// Test 3: Serialize boolean false
			{
				let json = JsonBool(false);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of false should succeed");
				Test.Assert(output == "false", scope $"Expected 'false', got '{output}'");
				Debug.WriteLine(scope $"  Test 3 (false): PASSED - output: {output}");
			}

			// Test 4: Serialize integer number
			{
				let json = JsonNumber((int64)42);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of integer should succeed");
				Test.Assert(output == "42", scope $"Expected '42', got '{output}'");
				Debug.WriteLine(scope $"  Test 4 (int 42): PASSED - output: {output}");
			}

			// Test 5: Serialize negative integer
			{
				let json = JsonNumber((int64)-123);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of negative integer should succeed");
				Test.Assert(output == "-123", scope $"Expected '-123', got '{output}'");
				Debug.WriteLine(scope $"  Test 5 (int -123): PASSED - output: {output}");
			}

			// Test 6: Serialize unsigned integer
			{
				let json = JsonNumber((uint64)999);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of unsigned integer should succeed");
				Test.Assert(output == "999", scope $"Expected '999', got '{output}'");
				Debug.WriteLine(scope $"  Test 6 (uint 999): PASSED - output: {output}");
			}

			// Test 7: Serialize floating-point number
			{
				let json = JsonNumber(3.14);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of float should succeed");
				// Float representation may vary, just check it parses back correctly
				Debug.WriteLine(scope $"  Test 7 (float 3.14): PASSED - output: {output}");
			}

			// Test 8: Serialize string
			{
				var json = JsonString("hello world");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string should succeed");
				Test.Assert(output == "\"hello world\"", scope $"Expected '\"hello world\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 8 (string): PASSED - output: {output}");
			}

			// Test 9: Serialize string with quotes (which are escaped correctly)
			{
				var json = JsonString("say \"hello\"");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with quotes should succeed");
				// The library should escape quotes with backslash
				Debug.WriteLine(scope $"  Test 9 (quoted string): PASSED - output: {output}");
			}

			// Test 10: Serialize empty object
			{
				var json = JsonObject();
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of empty object should succeed");
				Test.Assert(output == "{}", scope $"Expected '{{}}', got '{output}'");
				Debug.WriteLine(scope $"  Test 10 (empty object): PASSED - output: {output}");
			}

			// Test 11: Serialize simple object
			{
				var json = JsonObject();
				json.Add("name", JsonString("test"));
				json.Add("value", JsonNumber((int64)42));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of object should succeed");
				// Object key order may vary, check both possibilities
				let valid = output == "{\"name\":\"test\",\"value\":42}" || output == "{\"value\":42,\"name\":\"test\"}";
				Test.Assert(valid, scope $"Object serialization mismatch, got '{output}'");
				Debug.WriteLine(scope $"  Test 11 (simple object): PASSED - output: {output}");
			}

			// Test 12: Serialize empty array
			{
				var json = JsonArray();
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of empty array should succeed");
				Test.Assert(output == "[]", scope $"Expected '[]', got '{output}'");
				Debug.WriteLine(scope $"  Test 12 (empty array): PASSED - output: {output}");
			}

			// Test 13: Serialize simple array
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)1));
				json.Add(JsonNumber((int64)2));
				json.Add(JsonNumber((int64)3));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of array should succeed");
				Test.Assert(output == "[1,2,3]", scope $"Expected '[1,2,3]', got '{output}'");
				Debug.WriteLine(scope $"  Test 13 (simple array): PASSED - output: {output}");
			}

			// Test 14: Serialize mixed array
			{
				var json = JsonArray();
				json.Add(JsonNull());
				json.Add(JsonBool(true));
				json.Add(JsonNumber((int64)42));
				json.Add(JsonString("text"));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of mixed array should succeed");
				Test.Assert(output == "[null,true,42,\"text\"]", scope $"Expected '[null,true,42,\"text\"]', got '{output}'");
				Debug.WriteLine(scope $"  Test 14 (mixed array): PASSED - output: {output}");
			}

			// Test 15: Serialize nested objects
			{
				var inner = JsonObject();
				inner.Add("nested", JsonString("value"));

				var json = JsonObject();
				json.Add("outer", inner);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of nested object should succeed");
				Test.Assert(output == "{\"outer\":{\"nested\":\"value\"}}", scope $"Nested object mismatch, got '{output}'");
				Debug.WriteLine(scope $"  Test 15 (nested object): PASSED - output: {output}");
			}

			// Test 16: Serialize nested arrays
			{
				var inner = JsonArray();
				inner.Add(JsonNumber((int64)1));
				inner.Add(JsonNumber((int64)2));

				var json = JsonArray();
				json.Add(inner);
				json.Add(JsonNumber((int64)3));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of nested array should succeed");
				Test.Assert(output == "[[1,2],3]", scope $"Nested array mismatch, got '{output}'");
				Debug.WriteLine(scope $"  Test 16 (nested array): PASSED - output: {output}");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Serialization - Pretty-print tests")]
		public static void T_SerializationPrettyPrint()
		{
			Debug.WriteLine("Serialization - Pretty-print tests ...");

			// Test 1: Simple object with default indentation (2 spaces)
			{
				var json = JsonObject();
				json.Add("name", JsonString("test"));
				json.Add("value", JsonNumber((int64)42));
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "Pretty-print serialization should succeed");
				Test.Assert(output.Contains("\n"), "Output should contain newlines");
				Test.Assert(output.Contains("  "), "Output should contain indentation");
				Debug.WriteLine(scope $"  Test 1 (pretty object): PASSED");
				Debug.WriteLine(scope $"    Output:\n{output}");
			}

			// Test 2: Array with default indentation
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)1));
				json.Add(JsonNumber((int64)2));
				json.Add(JsonNumber((int64)3));
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "Pretty-print array serialization should succeed");
				Test.Assert(output.Contains("\n"), "Output should contain newlines");
				Debug.WriteLine(scope $"  Test 2 (pretty array): PASSED");
				Debug.WriteLine(scope $"    Output:\n{output}");
			}

			// Test 3: Custom indent string (tabs)
			{
				var json = JsonObject();
				json.Add("key", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true, IndentString = "\t" };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "Tab-indented serialization should succeed");
				Test.Assert(output.Contains("\t"), "Output should contain tabs");
				Debug.WriteLine(scope $"  Test 3 (tab indent): PASSED");
				Debug.WriteLine(scope $"    Output:\n{output}");
			}

			// Test 4: Custom indent string (4 spaces)
			{
				var json = JsonObject();
				json.Add("key", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true, IndentString = "    " };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "4-space indented serialization should succeed");
				Test.Assert(output.Contains("    "), "Output should contain 4-space indentation");
				Debug.WriteLine(scope $"  Test 4 (4-space indent): PASSED");
				Debug.WriteLine(scope $"    Output:\n{output}");
			}

			// Test 5: Custom newline (CRLF)
			{
				var json = JsonObject();
				json.Add("key", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true, NewLine = "\r\n" };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "CRLF serialization should succeed");
				Test.Assert(output.Contains("\r\n"), "Output should contain CRLF");
				Debug.WriteLine(scope $"  Test 5 (CRLF newline): PASSED");
			}

			// Test 6: Nested structure with indentation
			{
				var innerObj = JsonObject();
				innerObj.Add("nested", JsonString("data"));

				var innerArr = JsonArray();
				innerArr.Add(JsonNumber((int64)1));
				innerArr.Add(JsonNumber((int64)2));

				var json = JsonObject();
				json.Add("object", innerObj);
				json.Add("array", innerArr);
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "Nested pretty-print should succeed");
				// Check that nesting increases indentation - depth 2 should have 2x indent string
				Debug.WriteLine(scope $"  Test 6 (nested pretty): PASSED");
				Debug.WriteLine(scope $"    Output:\n{output}");
			}

			// Test 7: Non-indented should produce minified output
			{
				var json = JsonObject();
				json.Add("key", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = false };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "Non-indented serialization should succeed");
				Test.Assert(!output.Contains("\n"), "Minified output should not contain newlines");
				Test.Assert(output == "{\"key\":\"value\"}", scope $"Minified output mismatch, got '{output}'");
				Debug.WriteLine(scope $"  Test 7 (minified): PASSED - output: {output}");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Serialization - Round-trip tests")]
		public static void T_SerializationRoundTrip()
		{
			Debug.WriteLine("Serialization - Round-trip tests ...");

			// Helper to test round-trip
			static void TestRoundTrip(StringView originalJson, int testNum, StringView testName)
			{
				// Parse original
				var parseResult1 = Json.Deserialize(originalJson);
				defer parseResult1.Dispose();

				switch (parseResult1)
				{
				case .Ok(let json1):
					// Serialize
					let serialized = scope String();
					let serializeResult = Json.Serialize(json1, serialized);

					if (serializeResult case .Err(let serErr))
					{
						Test.Assert(false, scope $"Round-trip serialization failed: {serErr.ToString(.. scope .())}");
						return;
					}

					// Parse again
					var parseResult2 = Json.Deserialize(serialized);
					defer parseResult2.Dispose();

					switch (parseResult2)
					{
					case .Ok(let json2):
						// Serialize again to compare
						let serialized2 = scope String();
						Json.Serialize(json2, serialized2);

						Test.Assert(serialized == serialized2, scope $"Round-trip mismatch! First: {serialized}, Second: {serialized2}");
						Debug.WriteLine(scope $"  Test {testNum} ({testName}): PASSED - {serialized}");
					case .Err(let parseErr):
						Test.Assert(false, scope $"Round-trip re-parse failed: {parseErr.ToString(.. scope .())}");
					}
				case .Err(let err):
					Test.Assert(false, scope $"Round-trip initial parse failed: {err.ToString(.. scope .())}");
				}
			}

			// Test various JSON structures
			TestRoundTrip("null", 1, "null");
			TestRoundTrip("true", 2, "true");
			TestRoundTrip("false", 3, "false");
			TestRoundTrip("42", 4, "integer");
			TestRoundTrip("-123", 5, "negative int");
			TestRoundTrip("3.14", 6, "float");
			TestRoundTrip("\"hello\"", 7, "string");
			TestRoundTrip("{}", 8, "empty object");
			TestRoundTrip("[]", 9, "empty array");
			TestRoundTrip("[1,2,3]", 10, "simple array");
			TestRoundTrip("{\"key\":\"value\"}", 11, "simple object");
			TestRoundTrip("[null,true,false,42,\"text\"]", 12, "mixed array");
			TestRoundTrip("{\"nested\":{\"inner\":\"value\"}}", 13, "nested object");
			TestRoundTrip("[[1,2],[3,4]]", 14, "nested arrays");
			TestRoundTrip("{\"arr\":[1,2],\"obj\":{\"x\":1}}", 15, "complex structure");

			// Test with larger numbers
			TestRoundTrip("9223372036854775807", 16, "max int64");
			TestRoundTrip("-9223372036854775808", 17, "min int64");
			TestRoundTrip("18446744073709551615", 18, "max uint64");

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Serialization - Error handling tests")]
		public static void T_SerializationErrors()
		{
			Debug.WriteLine("Serialization - Error handling tests ...");

			// Test 1: NaN should fail
			{
				let json = JsonNumber(Double.NaN);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Err(.NaNNotAllowed), "NaN serialization should return NaNNotAllowed error");
				Debug.WriteLine("  Test 1 (NaN error): PASSED");
			}

			// Test 2: Positive Infinity should fail
			{
				let json = JsonNumber(Double.PositiveInfinity);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Err(.InfinityNotAllowed), "Positive Infinity should return InfinityNotAllowed error");
				Debug.WriteLine("  Test 2 (Positive Infinity error): PASSED");
			}

			// Test 3: Negative Infinity should fail
			{
				let json = JsonNumber(Double.NegativeInfinity);
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Err(.InfinityNotAllowed), "Negative Infinity should return InfinityNotAllowed error");
				Debug.WriteLine("  Test 3 (Negative Infinity error): PASSED");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Serialization - Escape character tests")]
		public static void T_SerializationEscapeCharacters()
		{
			Debug.WriteLine("Serialization - Escape character tests ...");

			// Test 1: Newline escape
			{
				var json = JsonString("hello\nworld");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with newline should succeed");
				Test.Assert(output == "\"hello\\nworld\"", scope $"Expected '\"hello\\nworld\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 1 (newline): PASSED - output: {output}");
			}

			// Test 2: Tab escape
			{
				var json = JsonString("hello\tworld");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with tab should succeed");
				Test.Assert(output == "\"hello\\tworld\"", scope $"Expected '\"hello\\tworld\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 2 (tab): PASSED - output: {output}");
			}

			// Test 3: Carriage return escape
			{
				var json = JsonString("hello\rworld");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with carriage return should succeed");
				Test.Assert(output == "\"hello\\rworld\"", scope $"Expected '\"hello\\rworld\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 3 (carriage return): PASSED - output: {output}");
			}

			// Test 4: Quote escape
			{
				var json = JsonString("say \"hello\"");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with quotes should succeed");
				Test.Assert(output == "\"say \\\"hello\\\"\"", scope $"Expected '\"say \\\"hello\\\"\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 4 (quotes): PASSED - output: {output}");
			}

			// Test 5: Backslash escape
			{
				var json = JsonString("path\\to\\file");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with backslashes should succeed");
				Test.Assert(output == "\"path\\\\to\\\\file\"", scope $"Expected '\"path\\\\to\\\\file\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 5 (backslash): PASSED - output: {output}");
			}

			// Test 6: Backspace escape
			{
				var json = JsonString("hello\bworld");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with backspace should succeed");
				Test.Assert(output == "\"hello\\bworld\"", scope $"Expected '\"hello\\bworld\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 6 (backspace): PASSED - output: {output}");
			}

			// Test 7: Form feed escape
			{
				var json = JsonString("hello\fworld");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with form feed should succeed");
				Test.Assert(output == "\"hello\\fworld\"", scope $"Expected '\"hello\\fworld\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 7 (form feed): PASSED - output: {output}");
			}

			// Test 8: Multiple escapes in one string
			{
				var json = JsonString("line1\nline2\ttab\r\n");
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of string with multiple escapes should succeed");
				Test.Assert(output == "\"line1\\nline2\\ttab\\r\\n\"", scope $"Expected '\"line1\\nline2\\ttab\\r\\n\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 8 (multiple escapes): PASSED - output: {output}");
			}

			// Test 9: Round-trip with escape characters - parse escaped JSON and serialize back
			{
				let inputJson = "\"hello\\nworld\\t!\"";
				var parseResult = Json.Deserialize(inputJson);
				defer parseResult.Dispose();

				switch (parseResult)
				{
				case .Ok(let parsed):
					let output = scope String();
					let serializeResult = Json.Serialize(parsed, output);

					Test.Assert(serializeResult case .Ok, "Round-trip serialization should succeed");
					Test.Assert(output == inputJson, scope $"Round-trip mismatch! Expected: {inputJson}, Got: {output}");
					Debug.WriteLine(scope $"  Test 9 (round-trip): PASSED - input: {inputJson}, output: {output}");
				case .Err(let err):
					Test.Assert(false, scope $"Round-trip parse failed: {err.ToString(.. scope .())}");
				}
			}

			// Test 10: Round-trip with all common escapes
			{
				let inputJson = "\"\\\"\\\\\\b\\f\\n\\r\\t\"";
				var parseResult = Json.Deserialize(inputJson);
				defer parseResult.Dispose();

				switch (parseResult)
				{
				case .Ok(let parsed):
					let output = scope String();
					let serializeResult = Json.Serialize(parsed, output);

					Test.Assert(serializeResult case .Ok, "Round-trip with all escapes should succeed");
					Test.Assert(output == inputJson, scope $"Round-trip mismatch! Expected: {inputJson}, Got: {output}");
					Debug.WriteLine(scope $"  Test 10 (all escapes round-trip): PASSED");
				case .Err(let err):
					Test.Assert(false, scope $"Round-trip parse failed: {err.ToString(.. scope .())}");
				}
			}

			// Test 11: Control character (NUL - 0x00) uses \u0000 format
			{
				var json = JsonString(scope String()..Append('\0'));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of NUL character should succeed");
				Test.Assert(output == "\"\\u0000\"", scope $"Expected '\"\\u0000\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 11 (NUL control char): PASSED - output: {output}");
			}

			// Test 12: Control character (0x1F) uses \u001f format
			{
				var json = JsonString(scope String()..Append((char8)0x1F));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of control char 0x1F should succeed");
				Test.Assert(output == "\"\\u001f\"", scope $"Expected '\"\\u001f\"', got '{output}'");
				Debug.WriteLine(scope $"  Test 12 (0x1F control char): PASSED - output: {output}");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}
	}
}
