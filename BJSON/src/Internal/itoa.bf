using System;
namespace BJSON.Internal;

static
{
	public const char8[200] cDigitsLut = .(
		'0', '0', '0', '1', '0', '2', '0', '3', '0', '4', '0', '5', '0', '6', '0', '7', '0', '8', '0', '9',
		'1', '0', '1', '1', '1', '2', '1', '3', '1', '4', '1', '5', '1', '6', '1', '7', '1', '8', '1', '9',
		'2', '0', '2', '1', '2', '2', '2', '3', '2', '4', '2', '5', '2', '6', '2', '7', '2', '8', '2', '9',
		'3', '0', '3', '1', '3', '2', '3', '3', '3', '4', '3', '5', '3', '6', '3', '7', '3', '8', '3', '9',
		'4', '0', '4', '1', '4', '2', '4', '3', '4', '4', '4', '5', '4', '6', '4', '7', '4', '8', '4', '9',
		'5', '0', '5', '1', '5', '2', '5', '3', '5', '4', '5', '5', '5', '6', '5', '7', '5', '8', '5', '9',
		'6', '0', '6', '1', '6', '2', '6', '3', '6', '4', '6', '5', '6', '6', '6', '7', '6', '8', '6', '9',
		'7', '0', '7', '1', '7', '2', '7', '3', '7', '4', '7', '5', '7', '6', '7', '7', '7', '8', '7', '9',
		'8', '0', '8', '1', '8', '2', '8', '3', '8', '4', '8', '5', '8', '6', '8', '7', '8', '8', '8', '9',
		'9', '0', '9', '1', '9', '2', '9', '3', '9', '4', '9', '5', '9', '6', '9', '7', '9', '8', '9', '9'
		);

	static char8* u32toa(uint32 value, char8* buffer)
	{
		Runtime.Assert(buffer != null);
		var value;
		var buffer;

		if (value < 10000)
		{
			uint32 d1 = (value / 100) << 1;
			uint32 d2 = (value % 100) << 1;

			if (value >= 1000)
				*buffer++ = cDigitsLut[d1];
			if (value >= 100)
				*buffer++ = cDigitsLut[d1 + 1];
			if (value >= 10)
				*buffer++ = cDigitsLut[d2];
			*buffer++ = cDigitsLut[d2 + 1];
		}
		else if (value < 100000000)
		{
		   // value = bbbbcccc
			uint32 b = value / 10000;
			uint32 c = value % 10000;

			uint32 d1 = (b / 100) << 1;
			uint32 d2 = (b % 100) << 1;

			uint32 d3 = (c / 100) << 1;
			uint32 d4 = (c % 100) << 1;

			if (value >= 10000000)
				*buffer++ = cDigitsLut[d1];
			if (value >= 1000000)
				*buffer++ = cDigitsLut[d1 + 1];
			if (value >= 100000)
				*buffer++ = cDigitsLut[d2];
			*buffer++ = cDigitsLut[d2 + 1];

			*buffer++ = cDigitsLut[d3];
			*buffer++ = cDigitsLut[d3 + 1];
			*buffer++ = cDigitsLut[d4];
			*buffer++ = cDigitsLut[d4 + 1];
		}
		else
		{
		   // value = aabbbbcccc in decimal

			uint32 a = value / 100000000; // 1 to 42
			value %= 100000000;

			if (a >= 10)
			{
				uint i = a << 1;
				*buffer++ = cDigitsLut[i];
				*buffer++ = cDigitsLut[i + 1];
			}
			else
				*buffer++ = (char8)('0' + uint8(a));

			uint32 b = value / 10000; // 0 to 9999
			uint32 c = value % 10000; // 0 to 9999

			uint32 d1 = (b / 100) << 1;
			uint32 d2 = (b % 100) << 1;

			uint32 d3 = (c / 100) << 1;
			uint32 d4 = (c % 100) << 1;

			*buffer++ = cDigitsLut[d1];
			*buffer++ = cDigitsLut[d1 + 1];
			*buffer++ = cDigitsLut[d2];
			*buffer++ = cDigitsLut[d2 + 1];
			*buffer++ = cDigitsLut[d3];
			*buffer++ = cDigitsLut[d3 + 1];
			*buffer++ = cDigitsLut[d4];
			*buffer++ = cDigitsLut[d4 + 1];
		}
		return buffer;
	}

	static char8* i32toa(int32 value, char8* buffer)
	{
		Runtime.Assert(buffer != null);
		var buffer;

		uint32 u = (.)(value);

		if (value < 0)
		{
			*buffer++ = '-';
			u = ~u + 1;
		}

		return u32toa(u, buffer);
	}

	static char8* u64toa(uint64 value, char8* buffer)
	{
		Runtime.Assert(buffer != null);
		var value;
		var buffer;

		const uint64  kTen8 = 100000000;
		uint64  kTen9 = kTen8 * 10;
		uint64 kTen10 = kTen8 * 100;
		uint64 kTen11 = kTen8 * 1000;
		uint64 kTen12 = kTen8 * 10000;
		uint64 kTen13 = kTen8 * 100000;
		uint64 kTen14 = kTen8 * 1000000;
		uint64 kTen15 = kTen8 * 10000000;
		uint64 kTen16 = kTen8 * kTen8;

		if (value < kTen8)
		{
			uint32 v = (.)(value);
			if (v < 10000)
			{
				uint32 d1 = (v / 100) << 1;
				uint32 d2 = (v % 100) << 1;

				if (v >= 1000)
					*buffer++ = cDigitsLut[d1];
				if (v >= 100)
					*buffer++ = cDigitsLut[d1 + 1];
				if (v >= 10)
					*buffer++ = cDigitsLut[d2];
				*buffer++ = cDigitsLut[d2 + 1];
			}
			else
			{
				// value = bbbbcccc
				uint32 b = v / 10000;
				uint32 c = v % 10000;

				uint32 d1 = (b / 100) << 1;
				uint32 d2 = (b % 100) << 1;

				uint32 d3 = (c / 100) << 1;
				uint32 d4 = (c % 100) << 1;

				if (value >= 10000000)
					*buffer++ = cDigitsLut[d1];
				if (value >= 1000000)
					*buffer++ = cDigitsLut[d1 + 1];
				if (value >= 100000)
					*buffer++ = cDigitsLut[d2];
				*buffer++ = cDigitsLut[d2 + 1];

				*buffer++ = cDigitsLut[d3];
				*buffer++ = cDigitsLut[d3 + 1];
				*buffer++ = cDigitsLut[d4];
				*buffer++ = cDigitsLut[d4 + 1];
			}
		}
		else if (value < kTen16)
		{
			uint32 v0 = (.)(value / kTen8);
			uint32 v1 = (.)(value % kTen8);

			uint32 b0 = v0 / 10000;
			uint32 c0 = v0 % 10000;

			uint32 d1 = (b0 / 100) << 1;
			uint32 d2 = (b0 % 100) << 1;

			uint32 d3 = (c0 / 100) << 1;
			uint32 d4 = (c0 % 100) << 1;

			uint32 b1 = v1 / 10000;
			uint32 c1 = v1 % 10000;

			uint32 d5 = (b1 / 100) << 1;
			uint32 d6 = (b1 % 100) << 1;

			uint32 d7 = (c1 / 100) << 1;
			uint32 d8 = (c1 % 100) << 1;

			if (value >= kTen15)
				*buffer++ = cDigitsLut[d1];
			if (value >= kTen14)
				*buffer++ = cDigitsLut[d1 + 1];
			if (value >= kTen13)
				*buffer++ = cDigitsLut[d2];
			if (value >= kTen12)
				*buffer++ = cDigitsLut[d2 + 1];
			if (value >= kTen11)
				*buffer++ = cDigitsLut[d3];
			if (value >= kTen10)
				*buffer++ = cDigitsLut[d3 + 1];
			if (value >= kTen9)
				*buffer++ = cDigitsLut[d4];

			*buffer++ = cDigitsLut[d4 + 1];
			*buffer++ = cDigitsLut[d5];
			*buffer++ = cDigitsLut[d5 + 1];
			*buffer++ = cDigitsLut[d6];
			*buffer++ = cDigitsLut[d6 + 1];
			*buffer++ = cDigitsLut[d7];
			*buffer++ = cDigitsLut[d7 + 1];
			*buffer++ = cDigitsLut[d8];
			*buffer++ = cDigitsLut[d8 + 1];
		}
		else
		{
			uint32 a = (.)(value / kTen16); // 1 to 1844
			value %= kTen16;


			if (a < 10)
				*buffer++ = (char8)('0' + (uint8)(a));
			else if (a < 100)
			{
				uint32 i = a << 1;
				*buffer++ = cDigitsLut[i];
				*buffer++ = cDigitsLut[i + 1];
			}
			else if (a < 1000)
			{
				*buffer++ = (char8)('0' + (uint8)(a / 100));

				uint32 i = (a % 100) << 1;
				*buffer++ = cDigitsLut[i];
				*buffer++ = cDigitsLut[i + 1];
			}
			else
			{
				uint32 i = (a / 100) << 1;
				uint32 j = (a % 100) << 1;
				*buffer++ = cDigitsLut[i];
				*buffer++ = cDigitsLut[i + 1];
				*buffer++ = cDigitsLut[j];
				*buffer++ = cDigitsLut[j + 1];
			}

			uint32 v0 = (.)(value / kTen8);
			uint32 v1 = (.)(value % kTen8);

			uint32 b0 = v0 / 10000;
			uint32 c0 = v0 % 10000;

			uint32 d1 = (b0 / 100) << 1;
			uint32 d2 = (b0 % 100) << 1;

			uint32 d3 = (c0 / 100) << 1;
			uint32 d4 = (c0 % 100) << 1;

			uint32 b1 = v1 / 10000;
			uint32 c1 = v1 % 10000;

			uint32 d5 = (b1 / 100) << 1;
			uint32 d6 = (b1 % 100) << 1;

			uint32 d7 = (c1 / 100) << 1;
			uint32 d8 = (c1 % 100) << 1;

			*buffer++ = cDigitsLut[d1];
			*buffer++ = cDigitsLut[d1 + 1];
			*buffer++ = cDigitsLut[d2];
			*buffer++ = cDigitsLut[d2 + 1];
			*buffer++ = cDigitsLut[d3];
			*buffer++ = cDigitsLut[d3 + 1];
			*buffer++ = cDigitsLut[d4];
			*buffer++ = cDigitsLut[d4 + 1];
			*buffer++ = cDigitsLut[d5];
			*buffer++ = cDigitsLut[d5 + 1];
			*buffer++ = cDigitsLut[d6];
			*buffer++ = cDigitsLut[d6 + 1];
			*buffer++ = cDigitsLut[d7];
			*buffer++ = cDigitsLut[d7 + 1];
			*buffer++ = cDigitsLut[d8];
			*buffer++ = cDigitsLut[d8 + 1];
		}

		return buffer;
	}

	static char8* i64toa(int64 value, char8* buffer)
	{
		Runtime.Assert(buffer != null);
		var buffer;

		uint64 u = (.)(value);
		if (value < 0)
		{
			*buffer++ = '-';
			u = ~u + 1;
		}

		return u64toa(u, buffer);
	}

}