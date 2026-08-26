namespace System
{
	extension Double
	{
		/// The 11 exponent bits of an IEEE 754 binary64.
		const uint64 kExponentMask = ((uint64)(0x7FF00000) << 32) | (uint64)(0x00000000);
		/// The 52 significand bits of an IEEE 754 binary64.
		const uint64 kSignificandMask = ((uint64)(0x000FFFFF) << 32) | (uint64)(0xFFFFFFFF);

		/// True for both +0.0 and -0.0: the masks drop the sign bit, so a caller that needs the
		/// sign of a zero reads it separately. dtoa depends on that to emit the '-' of a negative
		/// zero itself.
		public bool IsZero
		{
			get
			{
				double val = (double)this;
				return ((*(int64*)(&val) & (kExponentMask | kSignificandMask)) == 0);
			}
		}
	}
}