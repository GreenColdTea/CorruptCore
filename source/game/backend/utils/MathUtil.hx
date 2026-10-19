package game.backend.utils;

final class MathUtil
{
    inline public static function quantize(f:Float, snap:Float){
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		return (m / snap);
	}

	inline public static function scale(x:Float, l1:Float, h1:Float, l2:Float, h2:Float):Float
		return ((x - l1) * (h2 - l2) / (h1 - l1) + l2);

	inline public static function clamp(n:Float, l:Float, h:Float)
	{
		if (n > h)
			n = h;
		if (n < l)
			n = l;

		return n;
	}

	inline public static function rotate(x:Float, y:Float, angle:Float, ?point:FlxPoint):FlxPoint
	{
		var p = point == null ? FlxPoint.weak() : point;
		p.set((x * Math.cos(angle)) - (y * Math.sin(angle)), (x * Math.sin(angle)) + (y * Math.cos(angle)));
		return p;
	}

	inline public static function boundTo(value:Float, min:Float, max:Float):Float 
	{
		return Math.max(min, Math.min(max, value));
	}

	inline public static function quantizeAlpha(f:Float, interval:Float){
		return Std.int((f+interval/2)/interval)*interval;
	}

    inline public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max)
		{
			dumbArray.push(i);
		}
		return dumbArray;
	}

	 /**
	 * GCD stands for Greatest Common Divisor
	 * It's used in FullScreenScaleMode to prevent weird window resolutions from being counted as wide screen since those were causing issues positioning the game
	 * It returns the greatest common divisor between m and n
	 *
	 * think it's from hxp..?
	 * @param m
	 * @param n
	 * @return Int the common divisor between m and n
	 */
	public static function gcd(m:Int, n:Int):Int
	{
		m = Math.floor(Math.abs(m));
		n = Math.floor(Math.abs(n));
		var t;
		do {
			if (n == 0) return m;
			t = m;
			m = n;
			n = t % m;
		}
		while (true);
	}

	/**
	 * Moves a value towards a target at a fixed rate.
	 *
	 * @param value   The current value.
	 * @param target  The value we want to reach.
	 * @param amount  The maximum step size to move this update.
	 * @return        The new value, moved closer to the target by up to `amount`.
	 *
	 * Example:
	 *   var x = 0;
	 *   x = approach(x, 10, 2); // x = 2
	 *   x = approach(x, 10, 2); // x = 4
	 *   ...
	 *   x = 10 (stops exactly at the target)
	 */
	inline public static function approach(value:Float, target:Float, amount:Float):Float
	{
		if (value < target)
			return Math.min(value + amount, target);
		else
			return Math.max(value - amount, target);
	}

	/**
     * Returns -1.0 or 1.0 based on angle
	 * 
	 * @param angle Angle in radians
	 * @return -1.0 or 1.0 depending on the angle position in
     */
    inline public static function square(angle:Float):Float {
        var fAngle = angle % (Math.PI * 2);
        return fAngle >= Math.PI ? -1.0 : 1.0;
    }

	inline public static function catmullRom(t:Float, p0:Float, p1:Float, p2:Float, p3:Float):Float {
		final t2 = t * t;
		final t3 = t2 * t;
		return 0.5 * (2*p1 + (-p0 + p2)*t + (2*p0 - 5*p1 + 4*p2 - p3)*t2 + (-p0 + 3*p1 - 3*p2 + p3)*t3);
	}

	inline public static function catmullRomDeriv(t:Float, p0:Float, p1:Float, p2:Float, p3:Float):Float {
        final t2 = t * t;
        return 0.5 * ((-p0 + p2) + 2*(2*p0 - 5*p1 + 4*p2 - p3)*t + 3*(-p0 + 3*p1 - 3*p2 + p3)*t2);
    }
}