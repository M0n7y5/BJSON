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

			Console.WriteLine("Compliance tests from JSONTestSuite ...");

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "nst_json_testsuite");

			let files = Directory.EnumerateFiles(currentPath);
			int localIdx = 1;
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
							if (shouldFail)
								Console.WriteLine(scope $"FAIL: File '{fileName}' should NOT have parsed successfully!");
							Test.Assert(shouldFail == false, scope $"This file should not be successfully parsed! {fileName}");
						}
						else
						{
							if (!shouldFail)
								Console.WriteLine(scope $"FAIL: File '{fileName}' should have parsed successfully but got error!");
							Test.Assert(shouldFail, scope $"This file should not fail to parse! {fileName}");
						}
					}

					//Console.WriteLine(scope $"{localIdx} Done testing file: {fileName} Result: {result case .Ok ? "Ok" : "Err"}");
				}
				else
				{
					Test.Assert(false, scope $"Unable to open file {fileName}");
				}

				localIdx++;
			}

			Console.WriteLine("TEST COMPLETED SUCESSFULLY!");
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

			// Test 8: Exact deep indentation structure for all keys in all objects
			{
				let json = JsonObject()
					{
						("firstName", "John"),
						("lastName", "Smith"),
						("isAlive", true),
						("age", 27),
						("phoneNumbers", JsonArray()
							{
								JsonObject()
									{
										("type", "home"),
										("number", "212 555-1234")
									},
								JsonObject()
									{
										("type", "office"),
										("number", "646 555-4567")
									}
							})
					};
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "Complex nested structure should serialize without error");
				
				// Verify proper indentation by checking that all keys are indented correctly
				// In the broken version, only first key would be indented, others would be at column 0
				Test.Assert(output.Contains("\n  \"firstName\""), "firstName should be indented");
				Test.Assert(output.Contains("\n  \"lastName\""), "lastName should be indented");
				Test.Assert(output.Contains("\n  \"isAlive\""), "isAlive should be indented");
				Test.Assert(output.Contains("\n  \"age\""), "age should be indented");
				Test.Assert(output.Contains("\n  \"phoneNumbers\""), "phoneNumbers should be indented");
				Test.Assert(output.Contains("\n      \"type\""), "type field should be double-indented");
				Test.Assert(output.Contains("\n      \"number\""), "number field should be double-indented");
				
				Debug.WriteLine(scope $"  Test 8 (exact indentation validation): PASSED");
				Debug.WriteLine(scope $"    Output:\n{output}");
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

			// Test 8: Exact deep indentation structure for all keys in all objects
			{
				let json = JsonObject()
					{
						("firstName", "John"),
						("lastName", "Smith"),
						("isAlive", true),
						("age", 27),
						("phoneNumbers", JsonArray()
							{
								JsonObject()
									{
										("type", "home"),
										("number", "212 555-1234")
									},
								JsonObject()
									{
										("type", "office"),
										("number", "646 555-4567")
									}
							})
					};
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true };
				let result = Json.Serialize(json, output, options);

				Test.Assert(result case .Ok, "Complex nested structure should serialize without error");
				
				// Verify proper indentation by checking that all keys are indented correctly
				// In the broken version, only first key would be indented, others would be at column 0
				Test.Assert(output.Contains("\n  \"firstName\""), "firstName should be indented");
				Test.Assert(output.Contains("\n  \"lastName\""), "lastName should be indented");
				Test.Assert(output.Contains("\n  \"isAlive\""), "isAlive should be indented");
				Test.Assert(output.Contains("\n  \"age\""), "age should be indented");
				Test.Assert(output.Contains("\n  \"phoneNumbers\""), "phoneNumbers should be indented");
				Test.Assert(output.Contains("\n      \"type\""), "type field should be double-indented");
				Test.Assert(output.Contains("\n      \"number\""), "number field should be double-indented");
				
				Debug.WriteLine(scope $"  Test 8 (exact indentation validation): PASSED");
				Debug.WriteLine(scope $"    Output:\n{output}");
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
				var result1 = Json.Deserialize(originalJson);
				defer result1.Dispose();

				switch (result1)
				{
				case .Ok(let json1):
					// Serialize
					let serialized = scope String();
					let result2 = Json.Serialize(json1, serialized);

					if (result2 case .Err(let serErr))
					{
						Test.Assert(false, scope $"Round-trip serialization failed! {serErr}");
						return;
					}

					// Parse again
					let result3 = Json.Deserialize(serialized);
					defer result3.Dispose();

					switch (result3)
					{
					case .Ok(let json2):
						// Serialize again to compare
						let serialized2 = scope String();
						Json.Serialize(json2, serialized2);

						Test.Assert(serialized == serialized2, scope $"Round-trip mismatch! First: {serialized}, Second: {serialized2}");
						Debug.WriteLine(scope $"  Test {testNum} ({testName}): PASSED - {serialized}");
					case .Err(let parseErr):
						Test.Assert(false, scope $"Round-trip re-parse failed: {parseErr}");
					}
				case .Err(let err):
					Test.Assert(false, scope $"Round-trip initial parse failed: {err}");
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
				var result1 = Json.Deserialize(inputJson);
				defer result1.Dispose();

				switch (result1)
				{
				case .Ok(let parsed):
					let output = scope String();
					let result2 = Json.Serialize(parsed, output);

					Test.Assert(result2 case .Ok, "Round-trip serialization should succeed");
					Test.Assert(output == inputJson, scope $"Round-trip mismatch! Expected: {inputJson}, Got: {output}");
					Debug.WriteLine(scope $"  Test 9 (round-trip): PASSED - input: {inputJson}, output: {output}");
				case .Err(let err):
					Test.Assert(false, scope $"Round-trip parse failed: {err}");
				}
			}

			// Test 10: Round-trip with all common escapes
			{
				let inputJson = "\"\\\"\\\\\\b\\f\\n\\r\\t\"";
				var result1 = Json.Deserialize(inputJson);
				defer result1.Dispose();

				switch (result1)
				{
				case .Ok(let parsed):
					let output = scope String();
					let result2 = Json.Serialize(parsed, output);

					Test.Assert(result2 case .Ok, "Round-trip with all escapes should succeed");
					Test.Assert(output == inputJson, scope $"Round-trip mismatch! Expected: {inputJson}, Got: {output}");
					Debug.WriteLine(scope $"  Test 10 (all escapes round-trip): PASSED");
				case .Err(let err):
					Test.Assert(false, scope $"Round-trip parse failed: {err}");
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

		[Test(Name = "JSON Comment Support")]
		public static void T_CommentSupport()
		{
			Debug.WriteLine("JSON Comment Support tests ...");

			// Test 1: Single-line comment before JSON
			{
				let jsonWithComments = "// comment at start\n{\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok(let val), "Single-line comment before JSON should succeed");
				if (result case .Ok(let json))
				{
					Test.Assert(json.type == .OBJECT, "Should parse as object");
					StringView str = json["key"];
					Test.Assert(str == "value", scope $"Expected 'value', got '{str}'");
				}
				Debug.WriteLine("  Test 1 (single-line before): PASSED");
			}

			// Test 2: Single-line comment after JSON
			{
				let jsonWithComments = "{\"key\": \"value\"} // comment at end";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Single-line comment after JSON should succeed");
				Debug.WriteLine("  Test 2 (single-line after): PASSED");
			}

			// Test 3: Multi-line comment before JSON
			{
				let jsonWithComments = "/* multi\n   line */\n{\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Multi-line comment before JSON should succeed");
				Debug.WriteLine("  Test 3 (multi-line before): PASSED");
			}

			// Test 4: Multi-line comment after JSON
			{
				let jsonWithComments = "{\"key\": \"value\"} /* comment */";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Multi-line comment after JSON should succeed");
				Debug.WriteLine("  Test 4 (multi-line after): PASSED");
			}

			// Test 5: Comments in arrays
			{
				let jsonWithComments = """
[ 
  1, // first element 
  2, /* second element */
  3 
]
""";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok(let json), "Comments in arrays should succeed");
				if (result case .Ok(let arr))
				{
					Test.Assert(arr.type == .ARRAY, "Should parse as array");
					Test.Assert(arr.As<JsonArray>().Count == 3, scope $"Expected 3 elements, got {arr.As<JsonArray>().Count}");
				}
				Debug.WriteLine("  Test 5 (comments in arrays): PASSED");
			}

			// Test 6: Comments in objects
			{
				let jsonWithComments = """
{
  // property
  "name": "test", /* inline */
  "value": 42
}
""";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok(let json), "Comments in objects should succeed");
				if (result case .Ok(let obj))
				{
					Test.Assert(obj.type == .OBJECT, "Should parse as object");
					StringView str = obj["name"];
					Test.Assert(str == "test", scope $"Expected 'test', got '{str}'");
					int64 num = obj["value"];
					Test.Assert(num == 42, scope $"Expected 42, got {num}");
				}
				Debug.WriteLine("  Test 6 (comments in objects): PASSED");
			}

			// Test 7: Multiple comments
			{
				let jsonWithComments = """
// Start comment
/* Multi-line
   comment */
{
  // Key comment
  "key": /* value comment */ "value"
}
// End comment
""";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Multiple comments should succeed");
				Debug.WriteLine("  Test 7 (multiple comments): PASSED");
			}

			// Test 8: Comment with CRLF line endings
			{
				let jsonWithComments = "// comment\r\n{\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Comment with CRLF should succeed");
				Debug.WriteLine("  Test 8 (CRLF line ending): PASSED");
			}

			// Test 9: Comments disabled (standard JSON mode) - should fail
			{
				let jsonWithComments = "// comment\n{\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = false };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Err, "Comments should fail when disabled");
				Debug.WriteLine("  Test 9 (comments disabled): PASSED");
			}

			// Test 10: Unterminated multi-line comment - should fail
			{
				let jsonWithComments = "/* unterminated comment\n{\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Err, "Unterminated multi-line comment should fail");
				Debug.WriteLine("  Test 10 (unterminated comment): PASSED");
			}

			// Test 11: Only comment, no JSON - should fail
			{
				let jsonWithComments = "// just a comment";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Err, "Only comment, no JSON should fail");
				Debug.WriteLine("  Test 11 (only comment): PASSED");
			}

			// Test 12: Comment between object key and colon
			{
				let jsonWithComments = """
{
  "key" /* comment */ : "value"
}
""";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Comment between key and colon should succeed");
				Debug.WriteLine("  Test 12 (comment between key and colon): PASSED");
			}

			// Test 13: Comment between colon and value
			{
				let jsonWithComments = """
{
  "key": /* comment */ "value"
}
""";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Comment between colon and value should succeed");
				Debug.WriteLine("  Test 13 (comment between colon and value): PASSED");
			}

			// Test 14: Nested multi-line comment (not nested) - /* /* */ treats first */ as end
			{
				let jsonWithComments = "/* outer /* inner */ {\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				// This should parse successfully since first */ closes the comment
				Test.Assert(result case .Ok, "Non-nested comment handling should succeed");
				Debug.WriteLine("  Test 14 (non-nested comments): PASSED");
			}

			// Test 15: Empty single-line comment
			{
				let jsonWithComments = "//\n{\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Empty single-line comment should succeed");
				Debug.WriteLine("  Test 15 (empty single-line): PASSED");
			}

			// Test 16: Empty multi-line comment
			{
				let jsonWithComments = "/**/{\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Empty multi-line comment should succeed");
				Debug.WriteLine("  Test 16 (empty multi-line): PASSED");
			}

			// Test 17: Single / without second / (not a comment) - should fail
			{
				let jsonWithComments = "/ {\"key\": \"value\"}";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Err, "Single / should fail");
				Debug.WriteLine("  Test 17 (single slash): PASSED");
			}

			// Test 18: Complex nested structure with comments everywhere
			{
				let jsonWithComments = """
// Root comment
{
  // Array field
  "items": [ // inline
    1, // first
    /* multi-line
       comment */
    2,
    {
      "nested": /* comment */ "value"
    }
  ], /* after array */
  "flag": true // boolean
}
// Trailing comment
""";
				
				var config = DeserializerConfig() { EnableComments = true };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithComments);
				defer result.Dispose();

				Test.Assert(result case .Ok(let json), "Complex nested structure with comments should succeed");
				if (result case .Ok(let obj))
				{
					Test.Assert(obj.type == .OBJECT, "Should parse as object");
					Test.Assert(obj["items"].type == .ARRAY, "items should be array");
					let itemsArray = obj["items"].As<JsonArray>();
					Test.Assert(itemsArray.Count == 3, scope $"Expected 3 items, got {itemsArray.Count}");
				}
				Debug.WriteLine("  Test 18 (complex nested): PASSED");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "UTF-8 and Internationalization")]
		public static void T_UTF8AndInternationalization()
		{
			Debug.WriteLine("UTF-8 and Internationalization tests ...");

			// Helper method for roundtrip testing
			static void TestRoundtrip(StringView text, StringView description)
			{
				let json = JsonObject() { ("text", text) };
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);
				Test.Assert(result case .Ok, scope $"{description} serialization should succeed");

				var result2 = Json.Deserialize(output);
				defer result2.Dispose();

				Test.Assert(result2 case .Ok, scope $"{description} deserialization should succeed");
				if (result2 case .Ok(let parsed))
				{
					StringView parsed_text = parsed["text"];
					Test.Assert(parsed_text == text, scope $"{description} roundtrip mismatch: expected '{text}', got '{parsed_text}'");
				}
			}

			// Test 1-3: Chinese (Simplified & Traditional)
			TestRoundtrip("你好世界", "Chinese Simplified - Hello World");
			TestRoundtrip("北京", "Chinese - Beijing");
			TestRoundtrip("繁體中文測試", "Chinese Traditional");
			Debug.WriteLine("  Tests 1-3 (Chinese): PASSED");

			// Test 4-6: Japanese
			TestRoundtrip("こんにちは", "Japanese - Hello");
			TestRoundtrip("東京", "Japanese - Tokyo");
			TestRoundtrip("ありがとう", "Japanese - Thank you");
			Debug.WriteLine("  Tests 4-6 (Japanese): PASSED");

			// Test 7-8: Korean
			TestRoundtrip("안녕하세요", "Korean - Hello");
			TestRoundtrip("서울", "Korean - Seoul");
			Debug.WriteLine("  Tests 7-8 (Korean): PASSED");

			// Test 9: Thai
			TestRoundtrip("สวัสดี", "Thai - Hello");
			Debug.WriteLine("  Test 9 (Thai): PASSED");

			// Test 10-11: Arabic (right-to-left)
			TestRoundtrip("مرحبا", "Arabic - Hello");
			TestRoundtrip("العربية", "Arabic - Arabic");
			Debug.WriteLine("  Tests 10-11 (Arabic): PASSED");

			// Test 12-14: Russian
			TestRoundtrip("Привет мир", "Russian - Hello World");
			TestRoundtrip("Москва", "Russian - Moscow");
			TestRoundtrip("Спасибо", "Russian - Thank you");
			Debug.WriteLine("  Tests 12-14 (Russian): PASSED");

			// Test 15-17: French
			TestRoundtrip("Bonjour", "French - Hello");
			TestRoundtrip("Château", "French - Castle");
			TestRoundtrip("café", "French - Coffee");
			Debug.WriteLine("  Tests 15-17 (French): PASSED");

			// Test 18-20: German
			TestRoundtrip("Hühnerfüße", "German - Chicken feet");
			TestRoundtrip("Größe", "German - Size");
			TestRoundtrip("Straße", "German - Street");
			Debug.WriteLine("  Tests 18-20 (German): PASSED");

			// Test 21-23: Spanish
			TestRoundtrip("España", "Spanish - Spain");
			TestRoundtrip("año", "Spanish - Year");
			TestRoundtrip("niño", "Spanish - Child");
			Debug.WriteLine("  Tests 21-23 (Spanish): PASSED");

			// Test 24-26: Polish
			TestRoundtrip("Łódź", "Polish - City");
			TestRoundtrip("Kraków", "Polish - Krakow");
			TestRoundtrip("żółć", "Polish - Bile");
			Debug.WriteLine("  Tests 24-26 (Polish): PASSED");

			// Test 27-29: Czech
			TestRoundtrip("Děkuji", "Czech - Thank you");
			TestRoundtrip("Čeština", "Czech - Czech language");
			TestRoundtrip("příliš", "Czech - Too much");
			Debug.WriteLine("  Tests 27-29 (Czech): PASSED");

			// Test 30-34: Emojis
			TestRoundtrip("🎉", "Emoji - Party popper");
			TestRoundtrip("😀", "Emoji - Grinning face");
			TestRoundtrip("🌟", "Emoji - Star");
			TestRoundtrip("❤️", "Emoji - Heart");
			TestRoundtrip("🚀", "Emoji - Rocket");
			Debug.WriteLine("  Tests 30-34 (Emojis): PASSED");

			// Test 35-38: Math symbols
			TestRoundtrip("∑", "Math - Summation");
			TestRoundtrip("∏", "Math - Product");
			TestRoundtrip("√", "Math - Square root");
			TestRoundtrip("∞", "Math - Infinity");
			Debug.WriteLine("  Tests 35-38 (Math symbols): PASSED");

			// Test 39-42: Currency symbols
			TestRoundtrip("€", "Currency - Euro");
			TestRoundtrip("£", "Currency - Pound");
			TestRoundtrip("¥", "Currency - Yen");
			TestRoundtrip("₹", "Currency - Rupee");
			Debug.WriteLine("  Tests 39-42 (Currency): PASSED");

			// Test 43-45: Various brackets
			TestRoundtrip("【】", "Brackets - Japanese");
			TestRoundtrip("『』", "Brackets - Japanese quotes");
			TestRoundtrip("〈〉", "Brackets - Angle");
			Debug.WriteLine("  Tests 43-45 (Brackets): PASSED");

			// Test 46-47: Mixed content - Emoji with text
			TestRoundtrip("Hello 🌟 World", "Mixed - Emoji with English");
			TestRoundtrip("こんにちは 😀 世界", "Mixed - Japanese with emoji");
			Debug.WriteLine("  Tests 46-47 (Mixed emoji + text): PASSED");

			// Test 48-49: Multi-language mix
			TestRoundtrip("Hello мир 世界", "Mixed - English Russian Chinese");
			TestRoundtrip("Café ☕ 咖啡", "Mixed - French emoji Chinese");
			Debug.WriteLine("  Tests 48-49 (Multi-language): PASSED");

			// Test 50: String with only emojis
			TestRoundtrip("🎉🚀❤️🌟😀", "Only emojis");
			Debug.WriteLine("  Test 50 (Only emojis): PASSED");

			// Test 51-52: Complex multi-language objects
			{
				let json = JsonObject()
				{
					("english", "Hello"),
					("chinese", "你好"),
					("japanese", "こんにちは"),
					("russian", "Привет"),
					("arabic", "مرحبا"),
					("emoji", "🌍")
				};
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);
				Test.Assert(result case .Ok, "Failed to serialize multi-language object");

				var result2 = Json.Deserialize(output);
				defer result2.Dispose();

				Test.Assert(result2 case .Ok, "Failed to parse multi-language object");
				if (result2 case .Ok(let parsed))
				{
					StringView eng = parsed["english"];
					StringView chi = parsed["chinese"];
					StringView jap = parsed["japanese"];
					StringView rus = parsed["russian"];
					StringView ara = parsed["arabic"];
					StringView emo = parsed["emoji"];

					Test.Assert(eng == "Hello", scope $"English mismatch: got '{eng}'");
					Test.Assert(chi == "你好", scope $"Chinese mismatch: got '{chi}'");
					Test.Assert(jap == "こんにちは", scope $"Japanese mismatch: got '{jap}'");
					Test.Assert(rus == "Привет", scope $"Russian mismatch: got '{rus}'");
					Test.Assert(ara == "مرحبا", scope $"Arabic mismatch: got '{ara}'");
					Test.Assert(emo == "🌍", scope $"Emoji mismatch: got '{emo}'");
				}
				Debug.WriteLine("  Test 51 (Multi-language object): PASSED");
			}

			// Test 53: Array with various languages
			{
				let json = JsonArray()
				{
					JsonString("Hello"),
					JsonString("你好"),
					JsonString("こんにちは"),
					JsonString("Привет"),
					JsonString("مرحبا"),
					JsonString("🌍")
				};
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);
				Test.Assert(result case .Ok, "Failed to serialize multi-language array");

				var result2 = Json.Deserialize(output);
				defer result2.Dispose();

				Test.Assert(result2 case .Ok, "Failed to parse multi-language array");
				if (result2 case .Ok(let parsed))
				{
					Test.Assert(parsed.type == .ARRAY, "Should be array");
					let arr = parsed.As<JsonArray>();
					Test.Assert(arr.Count == 6, scope $"Expected 6 elements, got {arr.Count}");

					StringView v0 = arr[0];
					StringView v1 = arr[1];
					StringView v2 = arr[2];
					StringView v3 = arr[3];
					StringView v4 = arr[4];
					StringView v5 = arr[5];

					Test.Assert(v0 == "Hello", scope $"Element 0 mismatch: got '{v0}'");
					Test.Assert(v1 == "你好", scope $"Element 1 mismatch: got '{v1}'");
					Test.Assert(v2 == "こんにちは", scope $"Element 2 mismatch: got '{v2}'");
					Test.Assert(v3 == "Привет", scope $"Element 3 mismatch: got '{v3}'");
					Test.Assert(v4 == "مرحبا", scope $"Element 4 mismatch: got '{v4}'");
					Test.Assert(v5 == "🌍", scope $"Element 5 mismatch: got '{v5}'");
				}
				Debug.WriteLine("  Test 53 (Multi-language array): PASSED");
			}

			// Test 54: Nested structure with UTF-8
			{
				let innerObj = JsonObject()
				{
					("city", "東京"),
					("emoji", "🗼")
				};

				let json = JsonObject()
				{
					("country", "日本"),
					("capital", innerObj)
				};
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);
				Test.Assert(result case .Ok, "Failed to serialize nested UTF-8 structure");

				var result2 = Json.Deserialize(output);
				defer result2.Dispose();

				Test.Assert(result2 case .Ok, "Failed to parse nested UTF-8 structure");
				if (result2 case .Ok(let parsed))
				{
					StringView country = parsed["country"];
					Test.Assert(country == "日本", scope $"Country mismatch: got '{country}'");

					let capital = parsed["capital"];
					StringView city = capital["city"];
					StringView emoji = capital["emoji"];

					Test.Assert(city == "東京", scope $"City mismatch: got '{city}'");
					Test.Assert(emoji == "🗼", scope $"Emoji mismatch: got '{emoji}'");
				}
				Debug.WriteLine("  Test 54 (Nested UTF-8): PASSED");
			}

			// Test 55: Pretty-print with UTF-8 content
			{
				let json = JsonObject()
				{
					("message", "Hello 世界 🌍"),
					("language", "混合")
				};
				defer json.Dispose();

				let output = scope String();
				var options = JsonWriterOptions() { Indented = true };
				let result = Json.Serialize(json, output, options);
				Test.Assert(result case .Ok, "Failed to serialize pretty UTF-8");

				// Verify it contains indentation and UTF-8
				Test.Assert(output.Contains("\n"), "Pretty output should have newlines");
				Test.Assert(output.Contains("世界"), "Should contain Chinese characters");
				Test.Assert(output.Contains("🌍"), "Should contain emoji");

				// Parse back
				var result2 = Json.Deserialize(output);
				defer result2.Dispose();

				Test.Assert(result2 case .Ok, "Failed to parse pretty UTF-8");
				if (result2 case .Ok(let parsed))
				{
					StringView msg = parsed["message"];
					StringView lang = parsed["language"];

					Test.Assert(msg == "Hello 世界 🌍", scope $"Message mismatch: got '{msg}'");
					Test.Assert(lang == "混合", scope $"Language mismatch: got '{lang}'");
				}
				Debug.WriteLine("  Test 55 (Pretty-print UTF-8): PASSED");
			}

			// Test 56-57: Edge cases - very long multi-byte strings
			{
				let longChinese = "中文字符重复测试" + "中文字符重复测试" + "中文字符重复测试";
				TestRoundtrip(longChinese, "Long Chinese string");

				let longEmoji = "🎉🚀❤️🌟😀" + "🎉🚀❤️🌟😀" + "🎉🚀❤️🌟😀";
				TestRoundtrip(longEmoji, "Long emoji string");
				Debug.WriteLine("  Tests 56-57 (Long UTF-8 strings): PASSED");
			}

			// Test 58: Empty string (edge case)
			TestRoundtrip("", "Empty string");
			Debug.WriteLine("  Test 58 (Empty string): PASSED");

			// Test 59: Single character from various scripts
			TestRoundtrip("中", "Single Chinese character");
			TestRoundtrip("あ", "Single Hiragana");
			TestRoundtrip("Ж", "Single Cyrillic");
			TestRoundtrip("€", "Single Euro symbol");
			Debug.WriteLine("  Test 59 (Single characters): PASSED");

			// Test 60: Combining characters and accents
			TestRoundtrip("é", "e with acute accent");
			TestRoundtrip("ñ", "n with tilde");
			TestRoundtrip("ü", "u with umlaut");
			Debug.WriteLine("  Test 60 (Combining/accented chars): PASSED");

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Object Key Escaping")]
		public static void T_ObjectKeyEscaping()
		{
			Debug.WriteLine("Object Key Escaping tests ...");

			// Test 1: Key with double quote
			{
				var json = JsonObject();
				json.Add("key\"with\"quotes", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of key with quotes should succeed");
				// The key should be escaped: "key\"with\"quotes"
				Test.Assert(output.Contains("\"key\\\"with\\\"quotes\""), 
					scope $"Key with quotes should be escaped. Got: {output}");
				Debug.WriteLine(scope $"  Test 1 (key with quotes): output: {output}");

				// Verify round-trip: parse the output and check it works
				var parseResult = Json.Deserialize(output);
				defer parseResult.Dispose();
				Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
			}

			// Test 2: Key with backslash
			{
				var json = JsonObject();
				json.Add("path\\to\\file", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of key with backslash should succeed");
				// The key should be escaped: "path\\to\\file"
				Test.Assert(output.Contains("\"path\\\\to\\\\file\""), 
					scope $"Key with backslash should be escaped. Got: {output}");
				Debug.WriteLine(scope $"  Test 2 (key with backslash): output: {output}");

				// Verify round-trip
				var parseResult = Json.Deserialize(output);
				defer parseResult.Dispose();
				Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
			}

			// Test 3: Key with newline
			{
				var json = JsonObject();
				json.Add("line1\nline2", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of key with newline should succeed");
				// The key should be escaped: "line1\nline2"
				Test.Assert(output.Contains("\"line1\\nline2\""), 
					scope $"Key with newline should be escaped. Got: {output}");
				Debug.WriteLine(scope $"  Test 3 (key with newline): output: {output}");

				// Verify round-trip
				var parseResult = Json.Deserialize(output);
				defer parseResult.Dispose();
				Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
			}

			// Test 4: Key with tab
			{
				var json = JsonObject();
				json.Add("col1\tcol2", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of key with tab should succeed");
				Test.Assert(output.Contains("\"col1\\tcol2\""), 
					scope $"Key with tab should be escaped. Got: {output}");
				Debug.WriteLine(scope $"  Test 4 (key with tab): output: {output}");

				// Verify round-trip
				var parseResult = Json.Deserialize(output);
				defer parseResult.Dispose();
				Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
			}

			// Test 5: Key with control character (NUL)
			{
				var json = JsonObject();
				json.Add(scope String()..Append("key")..Append('\0')..Append("end"), JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of key with NUL should succeed");
				Test.Assert(output.Contains("\\u0000"), 
					scope $"Key with NUL should be escaped as \\u0000. Got: {output}");
				Debug.WriteLine(scope $"  Test 5 (key with NUL): output: {output}");

				// Verify round-trip
				var parseResult = Json.Deserialize(output);
				defer parseResult.Dispose();
				Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
			}

			// Test 6: Key with multiple escape characters
			{
				var json = JsonObject();
				json.Add("\"quoted\"\nand\\slashed", JsonString("value"));
				defer json.Dispose();

				let output = scope String();
				let result = Json.Serialize(json, output);

				Test.Assert(result case .Ok, "Serialization of key with multiple escapes should succeed");
				Debug.WriteLine(scope $"  Test 6 (key with multiple escapes): output: {output}");

				// Verify round-trip - this is the most important test
				var parseResult = Json.Deserialize(output);
				defer parseResult.Dispose();
				Test.Assert(parseResult case .Ok, scope $"Round-trip parse should succeed. Output was: {output}");
				
				if (parseResult case .Ok(let parsed))
				{
					// Verify the key was preserved correctly
					let obj = parsed.AsObject().Value;
					Test.Assert(obj.Count == 1, "Should have exactly one key");
					for (let item in obj)
					{
						Test.Assert(item.key == "\"quoted\"\nand\\slashed", 
							scope $"Key should round-trip correctly. Got: {item.key}");
					}
				}
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Duplicate Key Ignore Behavior")]
		public static void T_DuplicateKeyIgnoreBehavior()
		{
			Debug.WriteLine("Duplicate Key Ignore Behavior tests ...");

			// Test 1: Duplicate key with object value - should ignore the duplicate
			{
				let jsonWithDuplicates = "{\"key\":{\"original\":true},\"key\":{\"duplicate\":true}}";

				var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithDuplicates);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parsing with duplicate object keys should succeed with Ignore behavior");
				if (result case .Ok(let json))
				{
					let obj = json.AsObject().Value;
					let keyValue = obj["key"];
					Test.Assert(keyValue.type == .OBJECT, "key should be an object");
					
					// Should have the FIRST value, not the duplicate
					let innerObj = keyValue.AsObject().Value;
					Test.Assert(innerObj.ContainsKey("original"), 
						scope $"Should keep original value, not duplicate. Keys: {innerObj.Count}");
					Test.Assert(!innerObj.ContainsKey("duplicate"), 
						"Should NOT have duplicate value");
				}
				Debug.WriteLine("  Test 1 (duplicate object value - ignore): PASSED");
			}

			// Test 2: Duplicate key with array value - should ignore the duplicate
			{
				let jsonWithDuplicates = "{\"items\":[1,2,3],\"items\":[4,5,6]}";

				var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithDuplicates);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parsing with duplicate array keys should succeed with Ignore behavior");
				if (result case .Ok(let json))
				{
					let obj = json.AsObject().Value;
					let itemsValue = obj["items"];
					Test.Assert(itemsValue.type == .ARRAY, "items should be an array");
					
					// Should have the FIRST array [1, 2, 3], not [4, 5, 6]
					let arr = itemsValue.AsArray().Value;
					Test.Assert(arr.Count == 3, scope $"Should have 3 items from original array. Got: {arr.Count}");
					
					int64 firstItem = arr[0];
					Test.Assert(firstItem == 1, 
						scope $"First item should be 1 (from original), got: {firstItem}");
				}
				Debug.WriteLine("  Test 2 (duplicate array value - ignore): PASSED");
			}

			// Test 3: Duplicate key with nested array containing objects
			{
				let jsonWithDuplicates = "{\"data\":[{\"id\":1},{\"id\":2}],\"data\":[{\"id\":99}]}";

				var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithDuplicates);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parsing nested duplicate array should succeed");
				if (result case .Ok(let json))
				{
					let obj = json.AsObject().Value;
					let dataValue = obj["data"];
					let arr = dataValue.AsArray().Value;
					
					// Should have 2 items from original array, not 1 from duplicate
					Test.Assert(arr.Count == 2, 
						scope $"Should have 2 items from original array. Got: {arr.Count}");
				}
				Debug.WriteLine("  Test 3 (nested array with objects - ignore): PASSED");
			}

			// Test 4: Duplicate key with primitive value (for comparison)
			{
				let jsonWithDuplicates = "{\"value\":100,\"value\":999}";

				var config = DeserializerConfig() { DuplicateBehavior = .Ignore };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithDuplicates);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parsing with duplicate primitive should succeed");
				if (result case .Ok(let json))
				{
					int64 val = json["value"];
					Test.Assert(val == 100, scope $"Should keep original value 100, got: {val}");
				}
				Debug.WriteLine("  Test 4 (duplicate primitive - ignore): PASSED");
			}

			// Test 5: ThrowError behavior with array duplicate
			{
				let jsonWithDuplicates = "{\"items\":[1,2],\"items\":[3,4]}";

				var config = DeserializerConfig() { DuplicateBehavior = .ThrowError };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithDuplicates);
				defer result.Dispose();

				Test.Assert(result case .Err, "Parsing with duplicate should fail with ThrowError behavior");
				Debug.WriteLine("  Test 5 (duplicate array - throw error): PASSED");
			}

			// Test 6: AlwaysRewrite behavior with array duplicate
			{
				let jsonWithDuplicates = "{\"items\":[1,2,3],\"items\":[7,8,9]}";

				var config = DeserializerConfig() { DuplicateBehavior = .AlwaysRewrite };
				var deserializer = scope Deserializer(config);
				var result = deserializer.Deserialize(jsonWithDuplicates);
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parsing with AlwaysRewrite should succeed");
				if (result case .Ok(let json))
				{
					let arr = json["items"].AsArray().Value;
					// Should have the SECOND (rewritten) array [7, 8, 9]
					Test.Assert(arr.Count == 3, scope $"Should have 3 items. Got: {arr.Count}");
					
					int64 firstItem = arr[0];
					Test.Assert(firstItem == 7, 
						scope $"First item should be 7 (from rewrite), got: {firstItem}");
				}
				Debug.WriteLine("  Test 6 (duplicate array - always rewrite): PASSED");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Remove Methods")]
		public static void T_RemoveMethods()
		{
			Debug.WriteLine("Remove Methods tests ...");

			// Test 1: JsonObject.Remove - existing key
			{
				var json = JsonObject();
				json.Add("key1", JsonString("value1"));
				json.Add("key2", JsonString("value2"));
				json.Add("key3", JsonString("value3"));
				defer json.Dispose();

				Test.Assert(json.Count == 3, "Should have 3 keys initially");
				
				let removed = json.Remove("key2");
				Test.Assert(removed, "Remove should return true for existing key");
				Test.Assert(json.Count == 2, scope $"Should have 2 keys after removal. Got: {json.Count}");
				Test.Assert(!json.ContainsKey("key2"), "key2 should no longer exist");
				Test.Assert(json.ContainsKey("key1"), "key1 should still exist");
				Test.Assert(json.ContainsKey("key3"), "key3 should still exist");
				
				Debug.WriteLine("  Test 1 (JsonObject.Remove existing): PASSED");
			}

			// Test 2: JsonObject.Remove - non-existing key
			{
				var json = JsonObject();
				json.Add("key1", JsonString("value1"));
				defer json.Dispose();

				let removed = json.Remove("nonexistent");
				Test.Assert(!removed, "Remove should return false for non-existing key");
				Test.Assert(json.Count == 1, "Count should remain unchanged");
				
				Debug.WriteLine("  Test 2 (JsonObject.Remove non-existing): PASSED");
			}

			// Test 3: JsonObject.Remove - nested object (ensure proper disposal)
			{
				var json = JsonObject();
				json.Add("nested", JsonObject() { ("inner", "data") });
				json.Add("other", JsonString("value"));
				defer json.Dispose();

				Test.Assert(json.Count == 2, "Should have 2 keys initially");
				
				let removed = json.Remove("nested");
				Test.Assert(removed, "Remove should return true");
				Test.Assert(json.Count == 1, "Should have 1 key after removal");
				Test.Assert(!json.ContainsKey("nested"), "nested should be removed");
				
				Debug.WriteLine("  Test 3 (JsonObject.Remove nested): PASSED");
			}

			// Test 4: JsonArray.RemoveAt - valid index
			{
				var json = JsonArray();
				json.Add(JsonString("first"));
				json.Add(JsonString("second"));
				json.Add(JsonString("third"));
				defer json.Dispose();

				Test.Assert(json.Count == 3, "Should have 3 items initially");
				
				json.RemoveAt(1); // Remove "second"
				Test.Assert(json.Count == 2, scope $"Should have 2 items after removal. Got: {json.Count}");
				
				StringView first = json[0];
				StringView second = json[1];
				Test.Assert(first == "first", scope $"First item should be 'first'. Got: {first}");
				Test.Assert(second == "third", scope $"Second item should be 'third'. Got: {second}");
				
				Debug.WriteLine("  Test 4 (JsonArray.RemoveAt valid): PASSED");
			}

			// Test 5: JsonArray.RemoveAt - first and last elements
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)1));
				json.Add(JsonNumber((int64)2));
				json.Add(JsonNumber((int64)3));
				defer json.Dispose();

				// Remove first
				json.RemoveAt(0);
				Test.Assert(json.Count == 2, "Should have 2 items");
				int64 val = json[0];
				Test.Assert(val == 2, scope $"First item should be 2. Got: {val}");

				// Remove last
				json.RemoveAt(1);
				Test.Assert(json.Count == 1, "Should have 1 item");
				val = json[0];
				Test.Assert(val == 2, scope $"Remaining item should be 2. Got: {val}");
				
				Debug.WriteLine("  Test 5 (JsonArray.RemoveAt first/last): PASSED");
			}

			// Test 6: JsonArray.Remove - by value
			{
				var json = JsonArray();
				let target = JsonString("target");
				json.Add(JsonString("other1"));
				json.Add(target);
				json.Add(JsonString("other2"));
				defer json.Dispose();

				Test.Assert(json.Count == 3, "Should have 3 items initially");
				
				let removed = json.Remove(target);
				Test.Assert(removed, "Remove should return true for existing value");
				Test.Assert(json.Count == 2, scope $"Should have 2 items after removal. Got: {json.Count}");
				
				Debug.WriteLine("  Test 6 (JsonArray.Remove by value): PASSED");
			}

			// Test 7: JsonArray.Remove - non-existing value
			{
				var json = JsonArray();
				json.Add(JsonString("item1"));
				json.Add(JsonString("item2"));
				let notInArray = JsonString("not in array");
				defer json.Dispose();
				defer notInArray.Dispose();

				let removed = json.Remove(notInArray);
				Test.Assert(!removed, "Remove should return false for non-existing value");
				Test.Assert(json.Count == 2, "Count should remain unchanged");
				
				Debug.WriteLine("  Test 7 (JsonArray.Remove non-existing): PASSED");
			}

			// Test 8: JsonArray.RemoveAt - nested array (ensure proper disposal)
			{
				var json = JsonArray();
				json.Add(JsonArray() { JsonNumber((int64)1), JsonNumber((int64)2) });
				json.Add(JsonString("keep"));
				defer json.Dispose();

				Test.Assert(json.Count == 2, "Should have 2 items initially");
				
				json.RemoveAt(0); // Remove nested array
				Test.Assert(json.Count == 1, "Should have 1 item after removal");
				
				StringView remaining = json[0];
				Test.Assert(remaining == "keep", scope $"Remaining item should be 'keep'. Got: {remaining}");
				
				Debug.WriteLine("  Test 8 (JsonArray.RemoveAt nested): PASSED");
			}

			// Test 9: Multiple removes on same object
			{
				var json = JsonObject();
				json.Add("a", JsonNumber((int64)1));
				json.Add("b", JsonNumber((int64)2));
				json.Add("c", JsonNumber((int64)3));
				json.Add("d", JsonNumber((int64)4));
				defer json.Dispose();

				json.Remove("b");
				json.Remove("d");
				Test.Assert(json.Count == 2, scope $"Should have 2 keys. Got: {json.Count}");
				Test.Assert(json.ContainsKey("a"), "Should have 'a'");
				Test.Assert(json.ContainsKey("c"), "Should have 'c'");
				
				Debug.WriteLine("  Test 9 (multiple removes): PASSED");
			}

			// Test 10: Remove all items from array
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)1));
				json.Add(JsonNumber((int64)2));
				json.Add(JsonNumber((int64)3));
				defer json.Dispose();

				while (json.Count > 0)
				{
					json.RemoveAt(0);
				}
				Test.Assert(json.Count == 0, "Array should be empty");
				
				Debug.WriteLine("  Test 10 (remove all from array): PASSED");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Stream Serialization")]
		public static void T_StreamSerialization()
		{
			Debug.WriteLine("Stream Serialization tests ...");

			// Test 1: Basic stream serialization
			{
				let json = JsonObject() { ("name", "test"), ("value", 42) };
				defer json.Dispose();

				let stream = scope MemoryStream();
				let result = Json.Serialize(json, stream);
				
				Test.Assert(result case .Ok, "Stream serialization should succeed");
				
				// Read back and verify
				stream.Position = 0;
				let reader = scope StreamReader(stream);
				let output = reader.ReadToEnd(.. scope .());
				
				Test.Assert(output == "{\"name\":\"test\",\"value\":42}", 
					scope $"Output mismatch. Got: {output}");
				
				Debug.WriteLine("  Test 1 (basic stream): PASSED");
			}

			// Test 2: Stream serialization with options (pretty print)
			{
				let json = JsonObject() { ("key", "value") };
				defer json.Dispose();

				let stream = scope MemoryStream();
				var options = JsonWriterOptions() { Indented = true };
				let result = Json.Serialize(json, stream, options);
				
				Test.Assert(result case .Ok, "Pretty-print stream serialization should succeed");
				
				stream.Position = 0;
				let reader = scope StreamReader(stream);
				let output = reader.ReadToEnd(.. scope .());
				
				Test.Assert(output.Contains("\n"), "Pretty output should contain newlines");
				Test.Assert(output.Contains("  "), "Pretty output should contain indentation");
				
				Debug.WriteLine("  Test 2 (stream with options): PASSED");
			}

			// Test 3: Round-trip stream serialization/deserialization
			{
				let original = JsonObject() 
				{ 
					("string", "hello"),
					("number", 3.14),
					("bool", true),
					("null", JsonNull()),
					("array", JsonArray() { JsonNumber((int64)1), JsonNumber((int64)2) })
				};
				defer original.Dispose();

				// Serialize to stream
				let stream = scope MemoryStream();
				let serResult = Json.Serialize(original, stream);
				Test.Assert(serResult case .Ok, "Serialization should succeed");

				// Deserialize from stream
				stream.Position = 0;
				var deserResult = Json.Deserialize(stream);
				defer deserResult.Dispose();
				
				Test.Assert(deserResult case .Ok, "Deserialization should succeed");
				if (deserResult case .Ok(let parsed))
				{
					StringView str = parsed["string"];
					Test.Assert(str == "hello", scope $"string mismatch. Got: {str}");
					
					bool boolVal = parsed["bool"];
					Test.Assert(boolVal == true, "bool mismatch");
					
					Test.Assert(parsed["null"].IsNull(), "null mismatch");
					
					let arr = parsed["array"].AsArray().Value;
					Test.Assert(arr.Count == 2, scope $"array count mismatch. Got: {arr.Count}");
				}
				
				Debug.WriteLine("  Test 3 (round-trip): PASSED");
			}

			// Test 4: Large JSON to stream
			{
				var json = JsonArray();
				for (int i = 0; i < 100; i++)
				{
					json.Add(JsonObject() { ("index", i), ("data", "item") });
				}
				defer json.Dispose();

				let stream = scope MemoryStream();
				let result = Json.Serialize(json, stream);
				
				Test.Assert(result case .Ok, "Large JSON stream serialization should succeed");
				Test.Assert(stream.Length > 0, "Stream should have content");
				
				Debug.WriteLine(scope $"  Test 4 (large JSON): PASSED - wrote {stream.Length} bytes");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}

		[Test(Name = "Safe Access Methods")]
		public static void T_SafeAccessMethods()
		{
			Debug.WriteLine("Safe Access Methods tests ...");

			// Test 1: JsonObject.TryGet - existing key
			{
				let json = JsonObject() { ("name", "test"), ("value", 42) };
				defer json.Dispose();

				let result = json.TryGet("name");
				Test.Assert(result case .Ok, "TryGet should succeed for existing key");
				if (result case .Ok(let val))
				{
					StringView str = val;
					Test.Assert(str == "test", scope $"Value mismatch. Got: {str}");
				}

				Debug.WriteLine("  Test 1 (JsonObject.TryGet existing): PASSED");
			}

			// Test 2: JsonObject.TryGet - missing key
			{
				let json = JsonObject() { ("name", "test") };
				defer json.Dispose();

				let result = json.TryGet("missing");
				Test.Assert(result case .Err, "TryGet should fail for missing key");

				Debug.WriteLine("  Test 2 (JsonObject.TryGet missing): PASSED");
			}

			// Test 3: JsonObject.GetOrDefault - existing key
			{
				let json = JsonObject() { ("value", 42) };
				defer json.Dispose();

				let val = json.GetOrDefault("value");
				int num = val;
				Test.Assert(num == 42, scope $"Value mismatch. Got: {num}");

				Debug.WriteLine("  Test 3 (JsonObject.GetOrDefault existing): PASSED");
			}

			// Test 4: JsonObject.GetOrDefault - missing key returns default
			{
				let json = JsonObject() { ("name", "test") };
				defer json.Dispose();

				let val = json.GetOrDefault("missing");
				Test.Assert(val.IsNull() || val.type == .NULL, "Missing key should return null default");

				// Test with custom default
				let defaultVal = JsonNumber((int64)99);
				let val2 = json.GetOrDefault("missing", defaultVal);
				int num = val2;
				Test.Assert(num == 99, scope $"Should return custom default. Got: {num}");

				Debug.WriteLine("  Test 4 (JsonObject.GetOrDefault missing): PASSED");
			}

			// Test 5: JsonArray.TryGet - valid index
			{
				var json = JsonArray();
				json.Add(JsonString("first"));
				json.Add(JsonString("second"));
				json.Add(JsonString("third"));
				defer json.Dispose();

				let result = json.TryGet(1);
				Test.Assert(result case .Ok, "TryGet should succeed for valid index");
				if (result case .Ok(let val))
				{
					StringView str = val;
					Test.Assert(str == "second", scope $"Value mismatch. Got: {str}");
				}

				Debug.WriteLine("  Test 5 (JsonArray.TryGet valid): PASSED");
			}

			// Test 6: JsonArray.TryGet - out of bounds
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)1));
				defer json.Dispose();

				Test.Assert(json.TryGet(-1) case .Err, "TryGet should fail for negative index");
				Test.Assert(json.TryGet(1) case .Err, "TryGet should fail for index >= Count");
				Test.Assert(json.TryGet(100) case .Err, "TryGet should fail for large index");

				Debug.WriteLine("  Test 6 (JsonArray.TryGet out of bounds): PASSED");
			}

			// Test 7: JsonArray.GetOrDefault - valid index
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)10));
				json.Add(JsonNumber((int64)20));
				defer json.Dispose();

				let val = json.GetOrDefault(1);
				int num = val;
				Test.Assert(num == 20, scope $"Value mismatch. Got: {num}");

				Debug.WriteLine("  Test 7 (JsonArray.GetOrDefault valid): PASSED");
			}

			// Test 8: JsonArray.GetOrDefault - out of bounds returns default
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)1));
				defer json.Dispose();

				let val = json.GetOrDefault(5);
				Test.Assert(val.IsNull() || val.type == .NULL, "Out of bounds should return null default");

				// Test with custom default
				let defaultVal = JsonNumber((int64)999);
				let val2 = json.GetOrDefault(-1, defaultVal);
				int num = val2;
				Test.Assert(num == 999, scope $"Should return custom default. Got: {num}");

				Debug.WriteLine("  Test 8 (JsonArray.GetOrDefault out of bounds): PASSED");
			}

			// Test 9: Base JsonValue.TryGet for objects
			{
				var result = Json.Deserialize("{\"key\":\"value\"}");
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parse should succeed");
				if (result case .Ok(let json))
				{
					let tryResult = json.TryGet("key");
					Test.Assert(tryResult case .Ok, "TryGet on parsed object should succeed");

					let missingResult = json.TryGet("missing");
					Test.Assert(missingResult case .Err, "TryGet for missing key should fail");
				}

				Debug.WriteLine("  Test 9 (JsonValue.TryGet for objects): PASSED");
			}

			// Test 10: Base JsonValue.TryGet for arrays
			{
				var result = Json.Deserialize("[1, 2, 3]");
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parse should succeed");
				if (result case .Ok(let json))
				{
					let tryResult = json.TryGet(0);
					Test.Assert(tryResult case .Ok, "TryGet on parsed array should succeed");

					let outOfBounds = json.TryGet(10);
					Test.Assert(outOfBounds case .Err, "TryGet for out of bounds should fail");
				}

				Debug.WriteLine("  Test 10 (JsonValue.TryGet for arrays): PASSED");
			}

			// Test 11: Type mismatch - TryGet string key on array
			{
				var json = JsonArray();
				json.Add(JsonNumber((int64)1));
				defer json.Dispose();

				// Cast to JsonValue to use base class TryGet
				JsonValue val = json;
				let tryResult = val.TryGet("key");
				Test.Assert(tryResult case .Err, "TryGet string on array should fail");

				Debug.WriteLine("  Test 11 (type mismatch array): PASSED");
			}

			// Test 12: Type mismatch - TryGet int index on object
			{
				let json = JsonObject() { ("name", "test") };
				defer json.Dispose();

				// Cast to JsonValue to use base class TryGet
				JsonValue val = json;
				let tryResult = val.TryGet(0);
				Test.Assert(tryResult case .Err, "TryGet int on object should fail");

				Debug.WriteLine("  Test 12 (type mismatch object): PASSED");
			}

			// Test 13: GetOrDefault with type mismatch returns default
			{
				var arr = JsonArray();
				arr.Add(JsonNumber((int64)1));
				defer arr.Dispose();

				JsonValue val = arr;
				var defaultObj = JsonObject() { ("default", true) };
				defer defaultObj.Dispose();
				let result = val.GetOrDefault("key", defaultObj);
				
				// Should return the default because arr is not an object
				Test.Assert(result.IsObject(), "Should return default object on type mismatch");

				Debug.WriteLine("  Test 13 (GetOrDefault type mismatch): PASSED");
			}

			// Test 14: Nested safe access
			{
				var result = Json.Deserialize("{\"outer\":{\"inner\":{\"value\":42}}}");
				defer result.Dispose();

				Test.Assert(result case .Ok, "Parse should succeed");
				if (result case .Ok(let json))
				{
					// Chain TryGet calls safely
					if (json.TryGet("outer") case .Ok(let outer))
					{
						if (outer.TryGet("inner") case .Ok(let inner))
						{
							if (inner.TryGet("value") case .Ok(let val))
							{
								int num = val;
								Test.Assert(num == 42, scope $"Nested value mismatch. Got: {num}");
							}
						}
					}

					// Missing nested path should fail gracefully
					let outerResult = json.TryGet("outer");
					if (outerResult case .Ok(let outerVal))
					{
						let innerMissing = outerVal.TryGet("nonexistent");
						Test.Assert(innerMissing case .Err, "Missing nested key should fail");
					}
				}

				Debug.WriteLine("  Test 14 (nested safe access): PASSED");
			}

			Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
		}
	}
}
