using System;
using BJSON.Models;
using System.IO;
using System.Diagnostics;

namespace BJSON.Test;

/// Tests for UTF-8 and internationalization support:
/// - Various languages (Chinese, Japanese, Korean, Arabic, Russian, etc.)
/// - Emojis and special symbols
/// - Mixed content
/// - Round-trip preservation
class Utf8Test
{
	[Test(Name = "UTF-8 and Internationalization")]
	public static void T_UTF8AndInternationalization()
	{
		Debug.WriteLine("UTF-8 and Internationalization tests ...");

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

		TestRoundtrip("你好世界", "Chinese Simplified - Hello World");
		TestRoundtrip("北京", "Chinese - Beijing");
		TestRoundtrip("繁體中文測試", "Chinese Traditional");
		Debug.WriteLine("  Tests 1-3 (Chinese): PASSED");

		TestRoundtrip("こんにちは", "Japanese - Hello");
		TestRoundtrip("東京", "Japanese - Tokyo");
		TestRoundtrip("ありがとう", "Japanese - Thank you");
		Debug.WriteLine("  Tests 4-6 (Japanese): PASSED");

		TestRoundtrip("안녕하세요", "Korean - Hello");
		TestRoundtrip("서울", "Korean - Seoul");
		Debug.WriteLine("  Tests 7-8 (Korean): PASSED");

		TestRoundtrip("สวัสดี", "Thai - Hello");
		Debug.WriteLine("  Test 9 (Thai): PASSED");

		TestRoundtrip("مرحبا", "Arabic - Hello");
		TestRoundtrip("العربية", "Arabic - Arabic");
		Debug.WriteLine("  Tests 10-11 (Arabic): PASSED");

		TestRoundtrip("Привет мир", "Russian - Hello World");
		TestRoundtrip("Москва", "Russian - Moscow");
		TestRoundtrip("Спасибо", "Russian - Thank you");
		Debug.WriteLine("  Tests 12-14 (Russian): PASSED");

		TestRoundtrip("Bonjour", "French - Hello");
		TestRoundtrip("Château", "French - Castle");
		TestRoundtrip("café", "French - Coffee");
		Debug.WriteLine("  Tests 15-17 (French): PASSED");

		TestRoundtrip("Hühnerfüße", "German - Chicken feet");
		TestRoundtrip("Größe", "German - Size");
		TestRoundtrip("Straße", "German - Street");
		Debug.WriteLine("  Tests 18-20 (German): PASSED");

		TestRoundtrip("España", "Spanish - Spain");
		TestRoundtrip("año", "Spanish - Year");
		TestRoundtrip("niño", "Spanish - Child");
		Debug.WriteLine("  Tests 21-23 (Spanish): PASSED");

		TestRoundtrip("Łódź", "Polish - City");
		TestRoundtrip("Kraków", "Polish - Krakow");
		TestRoundtrip("żółć", "Polish - Bile");
		Debug.WriteLine("  Tests 24-26 (Polish): PASSED");

		TestRoundtrip("Děkuji", "Czech - Thank you");
		TestRoundtrip("Čeština", "Czech - Czech language");
		TestRoundtrip("příliš", "Czech - Too much");
		Debug.WriteLine("  Tests 27-29 (Czech): PASSED");

		TestRoundtrip("🎉", "Emoji - Party popper");
		TestRoundtrip("😀", "Emoji - Grinning face");
		TestRoundtrip("🌟", "Emoji - Star");
		TestRoundtrip("❤️", "Emoji - Heart");
		TestRoundtrip("🚀", "Emoji - Rocket");
		Debug.WriteLine("  Tests 30-34 (Emojis): PASSED");

		TestRoundtrip("∑", "Math - Summation");
		TestRoundtrip("∏", "Math - Product");
		TestRoundtrip("√", "Math - Square root");
		TestRoundtrip("∞", "Math - Infinity");
		Debug.WriteLine("  Tests 35-38 (Math symbols): PASSED");

		TestRoundtrip("€", "Currency - Euro");
		TestRoundtrip("£", "Currency - Pound");
		TestRoundtrip("¥", "Currency - Yen");
		TestRoundtrip("₹", "Currency - Rupee");
		Debug.WriteLine("  Tests 39-42 (Currency): PASSED");

		TestRoundtrip("【】", "Brackets - Japanese");
		TestRoundtrip("『』", "Brackets - Japanese quotes");
		TestRoundtrip("〈〉", "Brackets - Angle");
		Debug.WriteLine("  Tests 43-45 (Brackets): PASSED");

		TestRoundtrip("Hello 🌟 World", "Mixed - Emoji with English");
		TestRoundtrip("こんにちは 😀 世界", "Mixed - Japanese with emoji");
		Debug.WriteLine("  Tests 46-47 (Mixed emoji + text): PASSED");

		TestRoundtrip("Hello мир 世界", "Mixed - English Russian Chinese");
		TestRoundtrip("Café ☕ 咖啡", "Mixed - French emoji Chinese");
		Debug.WriteLine("  Tests 48-49 (Multi-language): PASSED");

		TestRoundtrip("🎉🚀❤️🌟😀", "Only emojis");
		Debug.WriteLine("  Test 50 (Only emojis): PASSED");

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

			Test.Assert(output.Contains("\n"), "Pretty output should have newlines");
			Test.Assert(output.Contains("世界"), "Should contain Chinese characters");
			Test.Assert(output.Contains("🌍"), "Should contain emoji");

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

		{
			let longChinese = "中文字符重复测试" + "中文字符重复测试" + "中文字符重复测试";
			TestRoundtrip(longChinese, "Long Chinese string");

			let longEmoji = "🎉🚀❤️🌟😀" + "🎉🚀❤️🌟😀" + "🎉🚀❤️🌟😀";
			TestRoundtrip(longEmoji, "Long emoji string");
			Debug.WriteLine("  Tests 56-57 (Long UTF-8 strings): PASSED");
		}

		TestRoundtrip("", "Empty string");
		Debug.WriteLine("  Test 58 (Empty string): PASSED");

		TestRoundtrip("中", "Single Chinese character");
		TestRoundtrip("あ", "Single Hiragana");
		TestRoundtrip("Ж", "Single Cyrillic");
		TestRoundtrip("€", "Single Euro symbol");
		Debug.WriteLine("  Test 59 (Single characters): PASSED");

		TestRoundtrip("é", "e with acute accent");
		TestRoundtrip("ñ", "n with tilde");
		TestRoundtrip("ü", "u with umlaut");
		Debug.WriteLine("  Test 60 (Combining/accented chars): PASSED");

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}

	[Test(Name = "UTF-8 Validation - Invalid Byte Sequences")]
	public static void T_InvalidUtf8IsRejected()
	{
		Debug.WriteLine("UTF-8 validation tests ...");

		static void AssertRejected(StringView rawBytes, StringView description)
		{
			let json = scope String();
			json.Append("\"");
			json.Append(rawBytes);
			json.Append("\"");

			var result = Json.Deserialize(json);
			defer result.Dispose();

			if (result case .Err(let err))
				Test.Assert(err case .InvalidEncoding, scope $"{description} should report InvalidEncoding, got {err}");
			else
				Test.Assert(false, scope $"{description} should be rejected");
		}

		{
			let raw = scope String();
			raw.Append((char8)0x80);
			AssertRejected(raw, "Lone continuation byte 0x80");
			Debug.WriteLine("  Test 1 (lone continuation byte): PASSED");
		}

		{
			let raw = scope String();
			raw.Append((char8)0xC0);
			raw.Append((char8)0x80);
			AssertRejected(raw, "Overlong NUL 0xC0 0x80");
			Debug.WriteLine("  Test 2 (overlong NUL): PASSED");
		}

		// Test 3: Three byte sequence cut short by the closing quote
		{
			let raw = scope String();
			raw.Append((char8)0xE2);
			raw.Append((char8)0x82);
			AssertRejected(raw, "Truncated 3 byte sequence 0xE2 0x82");
			Debug.WriteLine("  Test 3 (truncated 3 byte sequence): PASSED");
		}

		// Test 4: Lead byte that encodes a code point above U+10FFFF
		{
			let raw = scope String();
			raw.Append((char8)0xF5);
			raw.Append((char8)0x80);
			raw.Append((char8)0x80);
			raw.Append((char8)0x80);
			AssertRejected(raw, "Out of range lead byte 0xF5");
			Debug.WriteLine("  Test 4 (out of range lead byte): PASSED");
		}

		// Test 5: Surrogate half encoded as raw bytes instead of an escape
		{
			let raw = scope String();
			raw.Append((char8)0xED);
			raw.Append((char8)0xA0);
			raw.Append((char8)0x80);
			AssertRejected(raw, "Raw surrogate U+D800");
			Debug.WriteLine("  Test 5 (raw surrogate): PASSED");
		}

		Debug.WriteLine("TEST COMPLETED SUCCESSFULLY!");
	}
}
