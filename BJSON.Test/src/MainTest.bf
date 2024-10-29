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
		//[Test(Name = "Compliance tests from JSONTestSuite")]
		public static void T_TestSuite1()
		{
			// test cases from https://github.com/nst/JSONTestSuite
			// https://seriot.ch/projects/parsing_json.html

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "nst_json_testsuite");

			let files = Directory.EnumerateFiles(currentPath);
			int idx = 0;
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
					Console.WriteLine(scope $"---> {fileName}");
					Debug.WriteLine(scope $"---> {idx++} {fileName}");

					var result = Json.Deserialize(stream);

					Console.WriteLine();

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
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		//[Test(Name = "Compliance tests from json.org")]
		public static void T_TestSuite2()
		{
			// test cases from https://json.org/JSON_checker/

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "json_org_testsuite");

			let files = Directory.EnumerateFiles(currentPath);
			int idx = 0;
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
					Console.WriteLine(scope $"---> {fileName}");
					Debug.WriteLine(scope $"---> {idx++} {fileName}");

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
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		//[Test(Name = "Big List of Naughty Strings")]
		public static void T_TestSuite3()
		{
			// test from https://github.com/minimaxir/big-list-of-naughty-strings

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "big_list_of_naughty_strings");

			let files = Directory.EnumerateFiles(currentPath);
			int idx = 0;
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());

				let fileName = file.GetFileName(.. scope .());

				let stream = scope FileStream();

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					defer stream.Close();
					Console.WriteLine(scope $"---> {fileName}");
					Debug.WriteLine(scope $"---> {idx++} {fileName}");

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
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		[Test(Name = "nativejson-benchmark round-trip tests")]
		public static void T_TestSuite4()
		{
			// test from https://github.com/minimaxir/big-list-of-naughty-strings

			let currentPath = Directory.GetCurrentDirectory(.. scope .());

			Path.Combine(currentPath, "TestSuites", "nativejson_benchmark", "roundtrip");

			let files = Directory.EnumerateFiles(currentPath);
			int idx = 0;
			for (let file in files)
			{
				let filePath = file.GetFilePath(.. scope .());

				let fileName = file.GetFileName(.. scope .());

				let stream = scope FileStream();
				let strReader = scope StreamReader(stream);

				if (stream.Open(filePath, .Read, .Read) case .Ok)
				{
					defer stream.Close();

					Console.WriteLine(scope $"---> {fileName}");
					Debug.WriteLine(scope $"---> {idx++} {fileName}");

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
			}

			Debug.WriteLine("TEST COMPLETED SUCESSFULLY!");
		}

		[Test(Name = "Compliance tests from nativejson-benchmark")]
		public static void T_TestSuite5()
		{
			// test cases from https://github.com/miloyip/nativejson-benchmark/blob/master/src/main.cpp

			static void TEST_DOUBLE(StringView json_string, double expected)
			{
				var result = Json.Deserialize(json_string);
				defer result.Dispose();

				switch (result)
				{
				case .Ok(let val):
					double number = val[0];
					Test.Assert(number == expected);

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
				-9223372036854775809.0); // -2^63 - 1(min of int64_t + 1, force to use double)
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
			// boundary = 2^-1022 - 2^-1075 = 2.225073858507201136057409796709131975934819546351645648... ¡Á 10^-308
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

			TEST_DOUBLE("[5708990770823838890407843763683279797179383808]",
				5708990770823838890407843763683279797179383808.0);
			TEST_DOUBLE("[5708990770823839524233143877797980545530986496]",
				5708990770823839524233143877797980545530986496.0);
			TEST_DOUBLE("[5708990770823839207320493820740630171355185152]",
				5708990770823839524233143877797980545530986496.0);
			TEST_DOUBLE("[5708990770823839207320493820740630171355185151999e-3]",
				5708990770823838890407843763683279797179383808.0);
			TEST_DOUBLE("[5708990770823839207320493820740630171355185152001e-3]",
				5708990770823839524233143877797980545530986496.0);
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
	}
}
