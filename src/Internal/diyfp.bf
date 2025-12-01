using System;
namespace BJSON.Internal;

static
{
	public static mixin UINT64_C2(uint32 high32, uint32 low32)
	{
		((((uint64)(high32) << 32) | (uint64)(low32)))
	}

	[Inline]
	public static uint32 clzll(uint64 x)
	{
		Runtime.Assert(x != 0);
		var x;

		uint32 r = 0;
		while ((x & ((uint64)(1) << 63))  == 0)
		{
			x <<= 1;
			++r;
		}

		return r;
	}

	public struct DiyFp
	{
		const int kDiySignificandSize = 64;
		const int kDpSignificandSize = 52;
		const int kDpExponentBias = 0x3FF + kDpSignificandSize;
		const int kDpMaxExponent = 0x7FF - kDpExponentBias;
		const int kDpMinExponent = -kDpExponentBias;
		const int kDpDenormalExponent = -kDpExponentBias + 1;
		const uint64 kDpExponentMask = UINT64_C2!(0x7FF00000, 0x00000000);
		const uint64 kDpSignificandMask = UINT64_C2!(0x000FFFFF, 0xFFFFFFFF);
		const uint64 kDpHiddenBit = UINT64_C2!(0x00100000, 0x00000000);

		public uint64 f;
		public int e;


		public this()
		{
			f = default;
			e = default;
		}

		public this(uint64 fp, int exp)
		{
			this.f = fp;
			this.e = exp;
		}

		[Union]
		struct un
		{
			public double d;
			public uint64 u64;

			public this(double dd)
			{
				d = dd;
			}

			public this(uint64 uu)
			{
				u64 = uu;
			}
		}

		public this(double d)
		{
			let u = un(d);

			int biased_e = (int)((u.u64 & kDpExponentMask) >> kDpSignificandSize);
			uint64 significand = (u.u64 & kDpSignificandMask);
			if (biased_e != 0)
			{
				f = significand + kDpHiddenBit;
				e = biased_e - kDpExponentBias;
			}
			else
			{
				f = significand;
				e = kDpMinExponent + 1;
			}
		}

		public static Self operator -(Self lhs, Self rhs)
		{
			return .(lhs.f - rhs.f, lhs.e);
		}

		public static Self operator *(Self lhs, Self rhs)
		{
			uint64 M32 = 0xFFFFFFFF;
			uint64 a = lhs.f >> 32;
			uint64 b = lhs.f & M32;
			uint64 c = rhs.f >> 32;
			uint64 d = rhs.f & M32;
			uint64 ac = a * c;
			uint64 bc = b * c;
			uint64 ad = a * d;
			uint64 bd = b * d;
			uint64 tmp = (bd >> 32) + (ad & M32) + (bc & M32);
			tmp += 1U << 31; /// mult_round
			return .(ac + (ad >> 32) + (bc >> 32) + (tmp >> 32), lhs.e + rhs.e + 64);
		}

		public Self Normalize()
		{
			int s = (.)clzll(f);
			return .(f << s, e - s);
		}

		public Self NormalizeBoundary()
		{
			Self res = this;
			while ((res.f & (kDpHiddenBit << 1)) == 0)
			{
				res.f <<= 1;
				res.e--;
			}
			res.f <<= (kDiySignificandSize - kDpSignificandSize - 2);
			res.e = res.e - (kDiySignificandSize - kDpSignificandSize - 2);
			return res;
		}

		public void NormalizedBoundaries(ref DiyFp minus, ref DiyFp plus)
		{
			Self pl = Self((f << 1) + 1, e - 1).NormalizeBoundary();
			Self mi = (f == kDpHiddenBit) ? .((f << 2) - 1, e - 2) : .((f << 1) - 1, e - 1);
			mi.f <<= mi.e - pl.e;
			mi.e = pl.e;
			plus = pl;
			minus = mi;
		}

		public double ToDouble()
		{
			Runtime.Assert(f <= kDpHiddenBit + kDpSignificandMask);

			if (e < kDpDenormalExponent)
			{
				// Underflow.
				return 0.0;
			}
			if (e >= kDpMaxExponent)
			{
				// Overflow.
				return double.PositiveInfinity;
			}
			uint64 be = (e == kDpDenormalExponent && (f & kDpHiddenBit) == 0) ? 0 :
				(uint64)(e + kDpExponentBias);

			let u = un((f & kDpSignificandMask) | (be << kDpSignificandSize));
			return u.d;
		}

	}
	
	public static DiyFp GetCachedPowerByIndex(uint index)
	{
		Runtime.Assert(index < 87);
		return .(kCachedPowers_F[index], kCachedPowers_E[index]);
	}

	public static DiyFp GetCachedPower10(int exp, int* outExp)
	{
		Runtime.Assert(exp >= -348);
		uint index = (.)(exp + 348) / 8u;
		*outExp = -348 + (int)(index) * 8;
		return GetCachedPowerByIndex(index);
	}

	public static DiyFp GetCachedPower(int e, int* K)
	{

		//int k = static_cast<int>(ceil((-61 - e) * 0.30102999566398114)) + 374;
		double dk = (-61 - e) * 0.30102999566398114 + 347; // dk must be positive, so can do ceiling in positive
		int k = (.)(dk);
		if (dk - k > 0.0)
			k++;

		uint index = (.)((k >> 3) + 1);
		*K = -(-348 + (int)(index << 3)); // decimal exponent no need lookup table

		return GetCachedPowerByIndex(index);
	}

	public const uint64[?] kCachedPowers_F = .(
		UINT64_C2!(0xfa8fd5a0, 0x081c0288), UINT64_C2!(0xbaaee17f, 0xa23ebf76),
		UINT64_C2!(0x8b16fb20, 0x3055ac76), UINT64_C2!(0xcf42894a, 0x5dce35ea),
		UINT64_C2!(0x9a6bb0aa, 0x55653b2d), UINT64_C2!(0xe61acf03, 0x3d1a45df),
		UINT64_C2!(0xab70fe17, 0xc79ac6ca), UINT64_C2!(0xff77b1fc, 0xbebcdc4f),
		UINT64_C2!(0xbe5691ef, 0x416bd60c), UINT64_C2!(0x8dd01fad, 0x907ffc3c),
		UINT64_C2!(0xd3515c28, 0x31559a83), UINT64_C2!(0x9d71ac8f, 0xada6c9b5),
		UINT64_C2!(0xea9c2277, 0x23ee8bcb), UINT64_C2!(0xaecc4991, 0x4078536d),
		UINT64_C2!(0x823c1279, 0x5db6ce57), UINT64_C2!(0xc2109436, 0x4dfb5637),
		UINT64_C2!(0x9096ea6f, 0x3848984f), UINT64_C2!(0xd77485cb, 0x25823ac7),
		UINT64_C2!(0xa086cfcd, 0x97bf97f4), UINT64_C2!(0xef340a98, 0x172aace5),
		UINT64_C2!(0xb23867fb, 0x2a35b28e), UINT64_C2!(0x84c8d4df, 0xd2c63f3b),
		UINT64_C2!(0xc5dd4427, 0x1ad3cdba), UINT64_C2!(0x936b9fce, 0xbb25c996),
		UINT64_C2!(0xdbac6c24, 0x7d62a584), UINT64_C2!(0xa3ab6658, 0x0d5fdaf6),
		UINT64_C2!(0xf3e2f893, 0xdec3f126), UINT64_C2!(0xb5b5ada8, 0xaaff80b8),
		UINT64_C2!(0x87625f05, 0x6c7c4a8b), UINT64_C2!(0xc9bcff60, 0x34c13053),
		UINT64_C2!(0x964e858c, 0x91ba2655), UINT64_C2!(0xdff97724, 0x70297ebd),
		UINT64_C2!(0xa6dfbd9f, 0xb8e5b88f), UINT64_C2!(0xf8a95fcf, 0x88747d94),
		UINT64_C2!(0xb9447093, 0x8fa89bcf), UINT64_C2!(0x8a08f0f8, 0xbf0f156b),
		UINT64_C2!(0xcdb02555, 0x653131b6), UINT64_C2!(0x993fe2c6, 0xd07b7fac),
		UINT64_C2!(0xe45c10c4, 0x2a2b3b06), UINT64_C2!(0xaa242499, 0x697392d3),
		UINT64_C2!(0xfd87b5f2, 0x8300ca0e), UINT64_C2!(0xbce50864, 0x92111aeb),
		UINT64_C2!(0x8cbccc09, 0x6f5088cc), UINT64_C2!(0xd1b71758, 0xe219652c),
		UINT64_C2!(0x9c400000, 0x00000000), UINT64_C2!(0xe8d4a510, 0x00000000),
		UINT64_C2!(0xad78ebc5, 0xac620000), UINT64_C2!(0x813f3978, 0xf8940984),
		UINT64_C2!(0xc097ce7b, 0xc90715b3), UINT64_C2!(0x8f7e32ce, 0x7bea5c70),
		UINT64_C2!(0xd5d238a4, 0xabe98068), UINT64_C2!(0x9f4f2726, 0x179a2245),
		UINT64_C2!(0xed63a231, 0xd4c4fb27), UINT64_C2!(0xb0de6538, 0x8cc8ada8),
		UINT64_C2!(0x83c7088e, 0x1aab65db), UINT64_C2!(0xc45d1df9, 0x42711d9a),
		UINT64_C2!(0x924d692c, 0xa61be758), UINT64_C2!(0xda01ee64, 0x1a708dea),
		UINT64_C2!(0xa26da399, 0x9aef774a), UINT64_C2!(0xf209787b, 0xb47d6b85),
		UINT64_C2!(0xb454e4a1, 0x79dd1877), UINT64_C2!(0x865b8692, 0x5b9bc5c2),
		UINT64_C2!(0xc83553c5, 0xc8965d3d), UINT64_C2!(0x952ab45c, 0xfa97a0b3),
		UINT64_C2!(0xde469fbd, 0x99a05fe3), UINT64_C2!(0xa59bc234, 0xdb398c25),
		UINT64_C2!(0xf6c69a72, 0xa3989f5c), UINT64_C2!(0xb7dcbf53, 0x54e9bece),
		UINT64_C2!(0x88fcf317, 0xf22241e2), UINT64_C2!(0xcc20ce9b, 0xd35c78a5),
		UINT64_C2!(0x98165af3, 0x7b2153df), UINT64_C2!(0xe2a0b5dc, 0x971f303a),
		UINT64_C2!(0xa8d9d153, 0x5ce3b396), UINT64_C2!(0xfb9b7cd9, 0xa4a7443c),
		UINT64_C2!(0xbb764c4c, 0xa7a44410), UINT64_C2!(0x8bab8eef, 0xb6409c1a),
		UINT64_C2!(0xd01fef10, 0xa657842c), UINT64_C2!(0x9b10a4e5, 0xe9913129),
		UINT64_C2!(0xe7109bfb, 0xa19c0c9d), UINT64_C2!(0xac2820d9, 0x623bf429),
		UINT64_C2!(0x80444b5e, 0x7aa7cf85), UINT64_C2!(0xbf21e440, 0x03acdd2d),
		UINT64_C2!(0x8e679c2f, 0x5e44ff8f), UINT64_C2!(0xd433179d, 0x9c8cb841),
		UINT64_C2!(0x9e19db92, 0xb4e31ba9), UINT64_C2!(0xeb96bf6e, 0xbadf77d9),
		UINT64_C2!(0xaf87023b, 0x9bf0ee6b)
		);

	public const int16[?] kCachedPowers_E = .(
		-1220, -1193, -1166, -1140, -1113, -1087, -1060, -1034, -1007,  -980,
		-954,  -927,  -901,  -874,  -847,  -821,  -794,  -768,  -741,  -715,
		-688,  -661,  -635,  -608,  -582,  -555,  -529,  -502,  -475,  -449,
		-422,  -396,  -369,  -343,  -316,  -289,  -263,  -236,  -210,  -183,
		-157,  -130,  -103,   -77,   -50,   -24,     3,    30,    56,    83,
		109,   136,   162,   189,   216,   242,   269,   295,   322,   348,
		375,   402,   428,   455,   481,   508,   534,   561,   588,   614,
		641,   667,   694,   720,   747,   774,   800,   827,   853,   880,
		907,   933,   960,   986,  1013,  1039,  1066);
}