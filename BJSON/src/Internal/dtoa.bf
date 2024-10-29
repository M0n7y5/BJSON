using System;
namespace BJSON.Internal;

static
{
	static void GrisuRound(char8* buffer, int len, uint64 delta, uint64 rest, uint64 ten_kappa, uint64 wp_w)
	{
		var rest;

		while (rest < wp_w && delta - rest >= ten_kappa &&
			(rest + ten_kappa < wp_w || /// closer
			wp_w - rest > rest + ten_kappa - wp_w))
		{
			buffer[len - 1]--;
			rest += ten_kappa;
		}
	}

	static int CountDecimalDigit32(uint32 n)
	{
		// Simple pure C++ implementation was faster than __builtin_clz version in this situation.
		if (n < 10) return 1;
		if (n < 100) return 2;
		if (n < 1000) return 3;
		if (n < 10000) return 4;
		if (n < 100000) return 5;
		if (n < 1000000) return 6;
		if (n < 10000000) return 7;
		if (n < 100000000) return 8;
		// Will not reach 10 digits in DigitGen()
		//if (n < 1000000000) return 9;
		//return 10;
		return 9;
	}

	public static void DigitGen(DiyFp W, DiyFp Mp, uint64 delta, char8* buffer, int* len, int* K)
	{
		var delta;

		const uint64[?] kPow10 = .(
			1UL,
			10UL, 100UL, 1000UL, 10000UL, 100000UL,
			1000000UL, 10000000UL, 100000000UL,
			1000000000UL, 10000000000UL, 100000000000UL, 1000000000000UL,
			10000000000000UL, 100000000000000UL, 1000000000000000UL,
			10000000000000000UL, 100000000000000000UL, 1000000000000000000UL,
			10000000000000000000UL);

		DiyFp one = .(((uint64)1) << -Mp.e, Mp.e);
		DiyFp wp_w = Mp - W;

		uint32 p1 = (.)(Mp.f >> -one.e);
		uint64 p2 = Mp.f & (one.f - 1);
		int kappa = CountDecimalDigit32(p1); // kappa in [0, 9]
		*len = 0;

		while (kappa > 0)
		{
			uint32 d = 0;
			switch (kappa) {
			case  9: d = p1 /  100000000; p1 %=  100000000; break;
			case  8: d = p1 /   10000000; p1 %=   10000000; break;
			case  7: d = p1 /    1000000; p1 %=    1000000; break;
			case  6: d = p1 /     100000; p1 %=     100000; break;
			case  5: d = p1 /      10000; p1 %=      10000; break;
			case  4: d = p1 /       1000; p1 %=       1000; break;
			case  3: d = p1 /        100; p1 %=        100; break;
			case  2: d = p1 /         10; p1 %=         10; break;
			case  1: d = p1;              p1 =           0; break;
			default: break;
			}

			if (d != 0 || *len != 0)
				buffer[(*len)++] = (char8)('0' + (uint8)(d));
			kappa--;
			uint64 tmp = ((uint64)(p1) << -one.e) + p2;
			if (tmp <= delta)
			{
				*K += kappa;
				GrisuRound(buffer, *len, delta, tmp, kPow10[kappa] << -one.e, wp_w.f);
				return;
			}
		}

		// kappa = 0
		for (;;)
		{
			p2 *= 10;
			delta *= 10;
			char8 d = (.)(p2 >> -one.e);
			if (d != 0 || *len != 0)
				buffer[(*len)++] = (char8)('0' + (uint8)d);
			p2 &= one.f - 1;
			kappa--;
			if (p2 < delta)
			{
				*K += kappa;
				int index = -kappa;
				GrisuRound(buffer, *len, delta, p2, one.f, wp_w.f * (index < 20 ? kPow10[index] : 0));
				return;
			}
		}
	}

	public static void Grisu2(double value, char8* buffer, int* length, int* K)
	{
		DiyFp v = .(value);
		DiyFp w_m = default, w_p = default;

		v.NormalizedBoundaries(ref w_m, ref w_p);

		DiyFp c_mk = GetCachedPower(w_p.e, K);
		DiyFp W = v.Normalize() * c_mk;
		DiyFp Wp = w_p * c_mk;
		DiyFp Wm = w_m * c_mk;
		Wm.f++;
		Wp.f--;
		DigitGen(W, Wp, Wp.f - Wm.f, buffer, length, K);
	}

	public static char8* WriteExponent(int K, char8* buffer)
	{
		var K;
		var buffer;

		if (K < 0)
		{
			*buffer++ = '-';
			K = -K;
		}

		if (K >= 100)
		{
			*buffer++ = (char8)('0' + (uint8)(K / 100));
			K %= 100;
			//char8* d = cDigitsLut[K * 2];
			*buffer++ = cDigitsLut[(K * 2) + 0];
			*buffer++ = cDigitsLut[(K * 2) + 1];
		}
		else if (K >= 10)
		{
			//char8* d = GetDigitsLut() + K * 2;
			*buffer++ = cDigitsLut[(K * 2) + 0];
			*buffer++ = cDigitsLut[(K * 2) + 1];
		}
		else
			*buffer++ = (char8)('0' + (uint8)(K));

		return buffer;
	}

	public static char8* Prettify(char8* buffer, int length, int k, int maxDecimalPlaces)
	{
		let kk = length + k; // 10^(kk-1) <= v < 10^kk

		if (0 <= k && kk <= 21)
		{
			// 1234e7 -> 12340000000
			for (int i = length; i < kk; i++)
				buffer[i] = '0';
			buffer[kk] = '.';
			buffer[kk + 1] = '0';
			return &buffer[kk + 2];
		}
		else if (0 < kk && kk <= 21)
		{
			// 1234e-2 -> 12.34
			System.Internal.MemMove(&buffer[kk + 1], &buffer[kk], (.)(length - kk));
			buffer[kk] = '.';
			if (0 > k + maxDecimalPlaces)
			{
				// When maxDecimalPlaces = 2, 1.2345 -> 1.23, 1.102 -> 1.1
				// Remove extra trailing zeros (at least one) after truncation.
				for (int i = kk + maxDecimalPlaces; i > kk + 1; i--)
					if (buffer[i] != '0')
						return &buffer[i + 1];
				return &buffer[kk + 2]; // Reserve one zero
			}
			else
				return &buffer[length + 1];
		}
		else if (-6 < kk && kk <= 0)
		{
			// 1234e-6 -> 0.001234
			let offset = 2 - kk;
			System.Internal.MemMove(&buffer[offset], &buffer[0], (.)(length));
			buffer[0] = '0';
			buffer[1] = '.';
			for (int i = 2; i < offset; i++)
				buffer[i] = '0';
			if (length - kk > maxDecimalPlaces)
			{
				// When maxDecimalPlaces = 2, 0.123 -> 0.12, 0.102 -> 0.1
				// Remove extra trailing zeros (at least one) after truncation.
				for (int i = maxDecimalPlaces + 1; i > 2; i--)
					if (buffer[i] != '0')
						return &buffer[i + 1];
				return &buffer[3]; // Reserve one zero
			}
			else
				return &buffer[length + offset];
		}
		else if (kk < -maxDecimalPlaces)
		{
			// Truncate to zero
			buffer[0] = '0';
			buffer[1] = '.';
			buffer[2] = '0';
			return &buffer[3];
		}
		else if (length == 1)
		{
			// 1e30
			buffer[1] = 'e';
			return WriteExponent(kk - 1, &buffer[2]);
		}
		else
		{
			// 1234e30 -> 1.234e33
			System.Internal.MemMove(&buffer[2], &buffer[1], (.)(length - 1));
			buffer[1] = '.';
			buffer[length + 1] = 'e';
			return WriteExponent(kk - 1, &buffer[0 + length + 2]);
		}
	}



	public static char8* dtoa(double value, char8* buffer, int maxDecimalPlaces = 324)
	{
		Runtime.Assert(maxDecimalPlaces >= 1);
		var buffer;
		var value;

		var d = value;

		if (d.IsZero)
		{
			if (d.IsNegative)
				*buffer++ = '-'; // -0.0, Issue #289

			buffer[0] = '0';
			buffer[1] = '.';
			buffer[2] = '0';
			return &buffer[3];
		}
		else
		{
			if (value < 0)
			{
				*buffer++ = '-';
				value = -value;
			}
			int length = 0, K = 0;
			Grisu2(value, buffer, &length, &K);
			return Prettify(buffer, length, K, maxDecimalPlaces);
		}
	}
}