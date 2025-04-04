namespace System
{
	extension Double
	{
		const uint64 kExponentMask = ((uint64)(0x7FF00000) << 32) | (uint64)(0x00000000);
		const uint64 kSignificandMask = ((uint64)(0x000FFFFF) << 32) | (uint64)(0xFFFFFFFF);

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