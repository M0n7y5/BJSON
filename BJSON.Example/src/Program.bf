using System;
using BJSON.Models;
using System.IO;
using BJSON.Attributes;

namespace BJSON.Example
{
	class Program
	{
		/*[JsonObject("red")]
		class Bar
		{
			public float Damage = 25.f;
		}*/

		[JsonObject("red")]
		class Foo
		{
			//public bool? IsSus = true;

			[JsonIgnore(Condition = .Never)]
			[JsonPropertyName("health")]
			//public float Health = (.)100;

			//[AttributeUsage(.Field)]
			public BingBong SomeRandomName = new .() ~ delete _;

			//public int[] numbers;

		}

		[JsonObject]
		class BingBong { };

		class Test
		{
			Result<BingBong> bb = new BingBong() ~ delete _.Value;
		}

		public static int Main(String[] args)
		{
			/*var json2 = JsonVariant() { 2, 44, 65 };
			defer json2.Dispose();*/

			//let ds = BJSON.Internal.clzll(6686186116816);

			/*char8[25] buff;

			BJSON.Internal.dtoa(5e-324, &buff);
			var str = StringView(&buff);

			var yyy = 18446744073709551616.0d.ToString(.. scope .(), "R", null);

			return 0;

			let testObj = JsonArray()
				{
					JsonNumber(5e-324)
				};

			defer testObj.Dispose();

			let outt = Json.Deserialize("[-0.0]");

			return 0;*/
			bool? lool = true;

			let typ = lool.GetType();

			let isNull = typ.IsNullable;

			let isBool = typeof(Nullable<bool>) == typ;

			

			let tt = scope Foo();

			let jsonString =
				@"""
				{
				"nullTest": null,
				"firstName": "John",
				"lastName": "Smith",
				"isAlive": true,
				"age": 27,
				"another" : {
				"isItWorking": true,
				"someArray": ["please", "work", "ok?", 98, 42, false]
				}
				}
				""";

			//var result = Json.Deserialize<Foo>("[2e+00]");
			var result = Json.Deserialize(jsonString);

			switch (result)
			{
			case .Ok(var value):
				using (value)
				{
					int ageVal = value["age"];

					

					StringView name = value["lastName"];

					bool isWorking = value["another"]["isItWorking"];

					var another = (value["another"]);
					var someArray = (another["someArray"]);

					int arrayVal = (someArray[3]);
					//int arrayVal2 = (someArray[9]);

					//let aa = arrayVal + arrayVal2;

					Console.WriteLine(scope $"{ageVal}, {name}, {isWorking}, {arrayVal}");
				}
			case .Err(let err):
				Console.WriteLine(err.ToString(.. scope String()));
			}

			return 0;

			// initialize as array
			var json2 = JsonArray() { 2, 44, 65 };
			defer json2.Dispose();
			{
				// ...

				var strrrr = scope String();

				//defer delete strrrr;


				// ...
			}

			let str2 = scope String();

			Json.Serialize(json2, str2);

			var json22 = JsonObject()
				{
					("firstName", "John"),
					("lastName", "Smith"),
					("isAlive", true),
					("age", 27)
				};
			defer json22.Dispose();
			let str22 = scope String();
			Json.Serialize(json22, str22);

			//initialize as object
			var json3 = JsonObject()
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
			defer json3.Dispose();

			let str3 = scope String();
			Json.Serialize(json3, str3);

			StringView firstName = json3["firstName"];
			StringView lastName = json3["lastName"];

			int age = json3["age"];
			bool isAlive = json3["isAlive"];

			StringView numberType = json3["phoneNumbers"][1]["type"];
			StringView officeNumber = json3["phoneNumbers"][1]["number"];

			return 0;
		}

		static StringView damn = @"""
		[
		    "JSON Test Pattern pass1",
		    {
		        "object with 1 member": [
		            "array with 1 element"
		        ]
		    },
		    {},
		    [],
		    -42,
		    true,
		    false,
		    null,
		    {
		        "integer": 1234567890,
		        "real": -9876.543210,
		        "e": 0.123456789e-12,
		        "E": 1.234567890E+34,
		        "": 23456789012E66,
		        "zero": 0,
		        "one": 1,
		        "space": " ",
		        "quote": "\"",
		        "backslash": "\\",
		        "controls": "\b\f\n\r\t",
		        "slash": "/ & \/",
		        "alpha": "abcdefghijklmnopqrstuvwyz",
		        "ALPHA": "ABCDEFGHIJKLMNOPQRSTUVWYZ",
		        "digit": "0123456789",
		        "0123456789": "digit",
		        "special": "`1~!@#$%^&*()_+-={':[,]}|;.</>?",
		        "hex": "\u0123\u4567\u89AB\uCDEF\uabcd\uef4A",
		        "true": true,
		        "false": false,
		        "null": null,
		        "array": [],
		        "object": {},
		        "address": "50 St. James Street",
		        "url": "http://www.JSON.org/",
		        "comment": "// /* <!-- --",
		        "# -- --> */": " ",
		        " s p a c e d ": [
		            1,
		            2,
		            3,
		            4,
		            5,
		            6,
		            7
		        ],
		        "compact": [
		            1,
		            2,
		            3,
		            4,
		            5,
		            6,
		            7
		        ],
		        "jsontext": "{\"object with 1 member\":[\"array with 1 element\"]}",
		        "quotes": "&#34; \u0022 %22 0x22 034 &#x22;",
		        "\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?": "A key can be any string"
		    },
		    0.5,
		    98.6,
		    99.44,
		    1066,
		    1e1,
		    0.1e1,
		    1e-1,
		    1e00,
		    2e+00,
		    2e-00,
		    "rosebud"
		]
		
		""";


		static StringView Yamanote = """
		{
		    "name_en": "Yamanote Line",
		    "name_jp": "山手線",
		    "directions": [
		        {
		            "name_en": "Clockwise",
		            "name_jp": "外回り"
		        },
		        {
		            "name_en": "Counter-Clockwise",
		            "name_jp": "内回り"
		        }
		    ],
		    "stations": [
		        {
		            "name_en": "Shinagawa",
		            "name_jp": "品川",
		            "dist": 0
		        },
		        {
		            "name_en": "Osaki",
		            "name_jp": "大崎",
		            "dist": 2000
		        },
		        {
		            "name_en": "Gotanda",
		            "name_jp": "五反田",
		            "dist": 2900
		        },
		        {
		            "name_en": "Meguro",
		            "name_jp": "目黒",
		            "dist": 4100
		        },
		        {
		            "name_en": "Ebisu",
		            "name_jp": "恵比寿",
		            "dist": 5600
		        },
		        {
		            "name_en": "Shibuya",
		            "name_jp": "渋谷",
		            "dist": 7200
		        },
		        {
		            "name_en": "Harajuku",
		            "name_jp": "原宿",
		            "dist": 8400
		        },
		        {
		            "name_en": "Yoyogi",
		            "name_jp": "代々木",
		            "dist": 9900
		        },
		        {
		            "name_en": "Shinjuku",
		            "name_jp": "新宿",
		            "dist": 10600
		        }
		    ],
		    "stretches": [
		        {
		            "chunkConfigs": [
		                { "enter": 0, "hold": 20, "leave": 0, "curve": 0.0, "deltaY": 0.0 },
		                { "enter": 20, "hold": 30, "leave": 20, "curve": 0.25, "deltaY": 0.0 },
		                { "enter": 0, "hold": 20, "leave": 0, "curve": 0.0, "deltaY": 0.5 },
		                { "enter": 0, "hold": 20, "leave": 0, "curve": 0.0, "deltaY": -0.5 },
		                { "enter": 0, "hold": 20, "leave": 0, "curve": 0.0, "deltaY": 0.5 },
		                { "enter": 0, "hold": 20, "leave": 0, "curve": 0.0, "deltaY": -0.5 },
		                { "enter": 10, "hold": 20, "leave": 10, "curve": -0.25, "deltaY": 1.0 },
		                { "enter": 0, "hold": 20, "leave": 0, "curve": 0.0, "deltaY": 0.0 },
		                { "enter": 10, "hold": 20, "leave": 0, "curve": 0.125, "deltaY": -0.0 }
		            ],
		            "props": [
		                { "z": 0, "propID": 1, "worldOffset": [0.0, 0.0, 0.0], "flip": 1 },
		                { "z": 4, "propID": 1, "worldOffset": [0.0, 0.0, 0.0], "flip": 1 },
		                { "z": 8, "propID": 1, "worldOffset": [0.0, 0.0, 0.0], "flip": 1 },
		                { "z": 12, "propID": 1, "worldOffset": [0.0, 0.0, 0.0], "flip": 1 },
		                { "z": 16, "propID": 1, "worldOffset": [0.0, 0.0, 0.0], "flip": 1 }
		            ]
		        }
		    ],
		    "diagrams": [
		        {
		            "name_en": "Diagram 01",
		            "name_jp": "ダイヤ 01",
		            "difficulty": 1,
		            "atc": true,
		            "direction": 0,
		            "startStation": 0,
		            "endStation": 8,
		            "startAt": "2022-05-28T21:04:00.000Z",
		            "stopTime": 120,
		            "segments": [
		                {
		                    "name_en": "Shinagawa - Osaki",
		                    "name_jp": "品川 - 大崎",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 600,
		                            "speedKmph": 70
		                        },
		                        {
		                            "dist": 1000,
		                            "speedKmph": 50
		                        },
		                        {
		                            "dist": 1850,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": [
		                        {
		                            "dist": 400
		                        },
		                        {
		                            "dist": 1200
		                        }
		                    ]
		                },
		                {
		                    "name_en": "Osaki - Gotanda",
		                    "name_jp": "大崎 - 五反田",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 750,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": []
		                },
		                {
		                    "name_en": "Gotanda - Meguro",
		                    "name_jp": "五反田 - 目黒",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 1050,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": []
		                },
		                {
		                    "name_en": "Meguro - Ebisu",
		                    "name_jp": "目黒 - 恵比寿",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 1350,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": []
		                },
		                {
		                    "name_en": "Ebisu - Shibuya",
		                    "name_jp": "恵比寿 - 渋谷",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 1450,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": []
		                },
		                {
		                    "name_en": "Shibuya - Harajuku",
		                    "name_jp": "渋谷 - 原宿",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 1050,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": []
		                },
		                {
		                    "name_en": "Harajuku - Yoyogi",
		                    "name_jp": "原宿 - 代々木",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 1350,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": []
		                },
		                {
		                    "name_en": "Yoyogi - Shinjuku",
		                    "name_jp": "代々木 - 新宿",
		                    "speedLimits": [
		                        {
		                            "dist": 0,
		                            "speedKmph": 30
		                        },
		                        {
		                            "dist": 200,
		                            "speedKmph": 60
		                        },
		                        {
		                            "dist": 550,
		                            "speedKmph": 30
		                        }
		                    ],
		                    "pois": []
		                }
		            ]
		        }
		    ]
		}	
		""";
	}
}