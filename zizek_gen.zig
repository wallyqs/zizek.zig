// Code generated from ZizekIR by emitter/emit.go; DO NOT EDIT.
const std = @import("std");

// The generated core returns owned slices and never frees one — every function
// here is pure, so a caller that keeps a result must outlive the call, and a
// caller that discards one has no hook to free it on. That makes the allocator a
// caller's choice rather than this file's: a long-running caller can point it at
// an arena and reclaim a batch at a time, which the conformance checker does.
// The default is the page allocator, which is what every caller used when this
// was a constant.
pub var allocator: std.mem.Allocator = std.heap.smp_allocator;

fn floatToU64(value: f64) u64 {
    if (std.math.isNan(value) or value <= 0.0) return 0;
    if (value >= 18446744073709551615.0) return std.math.maxInt(u64);
    return @intFromFloat(value);
}

pub fn encode_exponent(biased_exp: u64) u64 {
    var c2047: u64 = undefined;
    var is2047: bool = undefined;
    var c1023: u64 = undefined;
    var ge: bool = undefined;
    var r: u64 = undefined;
    var c2046: u64 = undefined;
    var r2: u64 = undefined;
    c2047 = 2047;
    is2047 = (biased_exp == c2047);
    if (is2047) {
        return c2047;
    }
    c1023 = 1023;
    ge = (biased_exp >= c1023);
    if (ge) {
        r = (biased_exp -% c1023);
        return r;
    }
    c2046 = 2046;
    r2 = (c2046 -% biased_exp);
    return r2;
}

pub fn decode_exponent(enc: u64) u64 {
    var c2047: u64 = undefined;
    var is2047: bool = undefined;
    var c1023: u64 = undefined;
    var le: bool = undefined;
    var r: u64 = undefined;
    var c2046: u64 = undefined;
    var r2: u64 = undefined;
    c2047 = 2047;
    is2047 = (enc == c2047);
    if (is2047) {
        return c2047;
    }
    c1023 = 1023;
    le = (enc <= c1023);
    if (le) {
        r = (enc +% c1023);
        return r;
    }
    c2046 = 2046;
    r2 = (c2046 -% enc);
    return r2;
}

pub fn reverse_bits_n(val: u64, n: u64) u64 {
    var c0: u64 = undefined;
    var isz: bool = undefined;
    var c64: u64 = undefined;
    var rev: u64 = undefined;
    var sh: u64 = undefined;
    var r: u64 = undefined;
    c0 = 0;
    isz = (n == c0);
    if (isz) {
        return c0;
    }
    c64 = 64;
    rev = @bitReverse(val);
    sh = (c64 -% n);
    r = (rev >> @intCast(sh));
    return r;
}

pub fn update_mantissa(unbiased_exp: i64, mantissa: u64) u64 {
    var zero_i: i64 = undefined;
    var le0: bool = undefined;
    var c52: u64 = undefined;
    var r: u64 = undefined;
    var c51i: i64 = undefined;
    var le51: bool = undefined;
    var c52i: i64 = undefined;
    var nfi: i64 = undefined;
    var n_frac: u64 = undefined;
    var one: u64 = undefined;
    var shifted: u64 = undefined;
    var frac_mask: u64 = undefined;
    var frac: u64 = undefined;
    var xored: u64 = undefined;
    var revfrac: u64 = undefined;
    zero_i = 0;
    le0 = (unbiased_exp <= zero_i);
    if (le0) {
        c52 = 52;
        r = reverse_bits_n(mantissa, c52);
        return r;
    }
    c51i = 51;
    le51 = (unbiased_exp <= c51i);
    if (le51) {
        c52i = 52;
        nfi = (c52i - unbiased_exp);
        n_frac = @bitCast(nfi);
        one = 1;
        shifted = (one << @intCast(n_frac));
        frac_mask = (shifted -% one);
        frac = (mantissa & frac_mask);
        xored = (mantissa ^ frac);
        revfrac = reverse_bits_n(frac, n_frac);
        r = (xored | revfrac);
        return r;
    }
    return mantissa;
}

pub fn is_simple_float(x: f64) bool {
    var sb: bool = undefined;
    var inf: bool = undefined;
    var nan: bool = undefined;
    var sb_or_inf: bool = undefined;
    var bad: bool = undefined;
    var false_: bool = undefined;
    var pow56f: f64 = undefined;
    var ge: bool = undefined;
    var i: u64 = undefined;
    var back: f64 = undefined;
    var eqv: bool = undefined;
    var pow56: u64 = undefined;
    var lt: bool = undefined;
    var res: bool = undefined;
    sb = std.math.signbit(x);
    inf = std.math.isInf(x);
    nan = std.math.isNan(x);
    sb_or_inf = (sb or inf);
    bad = (sb_or_inf or nan);
    false_ = false;
    if (bad) {
        return false_;
    }
    pow56f = 72057594037927936;
    ge = (x >= pow56f);
    if (ge) {
        return false_;
    }
    i = floatToU64(x);
    back = @floatFromInt(i);
    eqv = (back == x);
    pow56 = 72057594037927936;
    lt = (i < pow56);
    res = (eqv and lt);
    return res;
}

pub fn float_to_index(x: f64) u64 {
    var simple: bool = undefined;
    var si: u64 = undefined;
    var bits: u64 = undefined;
    var c52: u64 = undefined;
    var shr: u64 = undefined;
    var c2047: u64 = undefined;
    var biased_exp: u64 = undefined;
    var mmask: u64 = undefined;
    var mantissa: u64 = undefined;
    var be_i: i64 = undefined;
    var c1023i: i64 = undefined;
    var unbiased_exp: i64 = undefined;
    var mantissa_enc: u64 = undefined;
    var exp_enc: u64 = undefined;
    var bit63: u64 = undefined;
    var expsh: u64 = undefined;
    var hi: u64 = undefined;
    var r: u64 = undefined;
    simple = is_simple_float(x);
    if (simple) {
        si = floatToU64(x);
        return si;
    }
    bits = @bitCast(x);
    c52 = 52;
    shr = (bits >> @intCast(c52));
    c2047 = 2047;
    biased_exp = (shr & c2047);
    mmask = 4503599627370495;
    mantissa = (bits & mmask);
    be_i = @bitCast(biased_exp);
    c1023i = 1023;
    unbiased_exp = (be_i - c1023i);
    mantissa_enc = update_mantissa(unbiased_exp, mantissa);
    exp_enc = encode_exponent(biased_exp);
    bit63 = 9223372036854775808;
    expsh = (exp_enc << @intCast(c52));
    hi = (bit63 | expsh);
    r = (hi | mantissa_enc);
    return r;
}

pub fn index_to_float(i: u64) f64 {
    var c63: u64 = undefined;
    var top: u64 = undefined;
    var c0: u64 = undefined;
    var isint: bool = undefined;
    var m56: u64 = undefined;
    var integral: u64 = undefined;
    var f: f64 = undefined;
    var c52: u64 = undefined;
    var shr: u64 = undefined;
    var c2047: u64 = undefined;
    var exp_enc: u64 = undefined;
    var biased_exp: u64 = undefined;
    var mmask: u64 = undefined;
    var mantissa_enc: u64 = undefined;
    var be_i: i64 = undefined;
    var c1023i: i64 = undefined;
    var unbiased_exp: i64 = undefined;
    var mantissa: u64 = undefined;
    var besh: u64 = undefined;
    var bitsr: u64 = undefined;
    var f2: f64 = undefined;
    c63 = 63;
    top = (i >> @intCast(c63));
    c0 = 0;
    isint = (top == c0);
    if (isint) {
        m56 = 72057594037927935;
        integral = (i & m56);
        f = @floatFromInt(integral);
        return f;
    }
    c52 = 52;
    shr = (i >> @intCast(c52));
    c2047 = 2047;
    exp_enc = (shr & c2047);
    biased_exp = decode_exponent(exp_enc);
    mmask = 4503599627370495;
    mantissa_enc = (i & mmask);
    be_i = @bitCast(biased_exp);
    c1023i = 1023;
    unbiased_exp = (be_i - c1023i);
    mantissa = update_mantissa(unbiased_exp, mantissa_enc);
    besh = (biased_exp << @intCast(c52));
    bitsr = (besh | mantissa);
    f2 = @bitCast(bitsr);
    return f2;
}

pub fn min_reversed_in_range(lo: u64, hi: u64, n: i64) u64 {
    var zero_i: i64 = undefined;
    var isz: bool = undefined;
    var c0: u64 = undefined;
    var one: u64 = undefined;
    var lop1: u64 = undefined;
    var k_lo: u64 = undefined;
    var k_hi: u64 = undefined;
    var le: bool = undefined;
    var onei: i64 = undefined;
    var nm1: i64 = undefined;
    var rec: u64 = undefined;
    var two: u64 = undefined;
    var r: u64 = undefined;
    zero_i = 0;
    isz = (n == zero_i);
    c0 = 0;
    if (isz) {
        return c0;
    }
    one = 1;
    lop1 = (lo +% one);
    k_lo = (lop1 >> @intCast(one));
    k_hi = (hi >> @intCast(one));
    le = (k_lo <= k_hi);
    if (le) {
        onei = 1;
        nm1 = (n - onei);
        rec = min_reversed_in_range(k_lo, k_hi, nm1);
        two = 2;
        r = (rec *% two);
        return r;
    }
    return lo;
}

pub fn simplest_in_range(lo: f64, hi: f64) f64 {
    var c: f64 = undefined;
    var cle: bool = undefined;
    var pow56f: f64 = undefined;
    var clt: bool = undefined;
    var inrange: bool = undefined;
    var lo_bits: u64 = undefined;
    var hi_bits: u64 = undefined;
    var c52: u64 = undefined;
    var e_lo: u64 = undefined;
    var e_hi: u64 = undefined;
    var mmask: u64 = undefined;
    var m_lo: u64 = undefined;
    var m_hi: u64 = undefined;
    var c1023: u64 = undefined;
    var cond: bool = undefined;
    var ncond: bool = undefined;
    var e: u64 = undefined;
    var m_min: u64 = undefined;
    var m_max: u64 = undefined;
    var eq_hilo: bool = undefined;
    var ne_hilo: bool = undefined;
    var eq_lohi: bool = undefined;
    var ne_lohi: bool = undefined;
    var zero: u64 = undefined;
    var c1023i: i64 = undefined;
    var e_i: i64 = undefined;
    var unbiased: i64 = undefined;
    var c52i: i64 = undefined;
    var ge52: bool = undefined;
    var esh0: u64 = undefined;
    var bitsr0: u64 = undefined;
    var f0: f64 = undefined;
    var zero_i: i64 = undefined;
    var le0: bool = undefined;
    var n_frac: i64 = undefined;
    var nle0: bool = undefined;
    var sub: i64 = undefined;
    var one: u64 = undefined;
    var shl1: u64 = undefined;
    var low_mask: u64 = undefined;
    var h: u64 = undefined;
    var l_lo: u64 = undefined;
    var l_hi: u64 = undefined;
    var minrev: u64 = undefined;
    var hsh: u64 = undefined;
    var m_best: u64 = undefined;
    var esh: u64 = undefined;
    var bitsr: u64 = undefined;
    var f: f64 = undefined;
    c = @ceil(lo);
    cle = (c <= hi);
    pow56f = 72057594037927936;
    clt = (c < pow56f);
    inrange = (cle and clt);
    if (inrange) {
        return c;
    }
    lo_bits = @bitCast(lo);
    hi_bits = @bitCast(hi);
    c52 = 52;
    e_lo = (lo_bits >> @intCast(c52));
    e_hi = (hi_bits >> @intCast(c52));
    mmask = 4503599627370495;
    m_lo = (lo_bits & mmask);
    m_hi = (hi_bits & mmask);
    c1023 = 1023;
    cond = (e_lo >= c1023);
    ncond = (!cond);
    e = e_lo;
    m_min = m_lo;
    m_max = m_hi;
    eq_hilo = (e_hi == e_lo);
    ne_hilo = (!eq_hilo);
    if (ne_hilo) {
        m_max = mmask;
    }
    if (ncond) {
        e = e_hi;
        m_max = m_hi;
        eq_lohi = (e_lo == e_hi);
        ne_lohi = (!eq_lohi);
        if (ne_lohi) {
            zero = 0;
            m_min = zero;
        }
    }
    c1023i = 1023;
    e_i = @bitCast(e);
    unbiased = (e_i - c1023i);
    c52i = 52;
    ge52 = (unbiased >= c52i);
    if (ge52) {
        esh0 = (e << @intCast(c52));
        bitsr0 = (esh0 | m_min);
        f0 = @bitCast(bitsr0);
        return f0;
    }
    zero_i = 0;
    le0 = (unbiased <= zero_i);
    n_frac = c52i;
    nle0 = (!le0);
    if (nle0) {
        sub = (c52i - unbiased);
        n_frac = sub;
    }
    one = 1;
    shl1 = (one << @intCast(n_frac));
    low_mask = (shl1 -% one);
    h = (m_min >> @intCast(n_frac));
    l_lo = (m_min & low_mask);
    l_hi = (m_max & low_mask);
    minrev = min_reversed_in_range(l_lo, l_hi, n_frac);
    hsh = (h << @intCast(n_frac));
    m_best = (hsh | minrev);
    esh = (e << @intCast(c52));
    bitsr = (esh | m_best);
    f = @bitCast(bitsr);
    return f;
}

pub fn base64_encode(data: []const u8) []u8 {
    var alphabet: []const u8 = undefined;
    var out: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"i3": i64 = undefined;
    var @"u0": u64 = undefined;
    var c6: u64 = undefined;
    var c8: u64 = undefined;
    var c12: u64 = undefined;
    var c16: u64 = undefined;
    var c18: u64 = undefined;
    var c3f: u64 = undefined;
    var eq: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var rem: i64 = undefined;
    var b0: u64 = undefined;
    var b1: u64 = undefined;
    var b2: u64 = undefined;
    var has1: bool = undefined;
    var p1: i64 = undefined;
    var has2: bool = undefined;
    var p2: i64 = undefined;
    var s16: u64 = undefined;
    var s8: u64 = undefined;
    var acc0: u64 = undefined;
    var acc: u64 = undefined;
    var t0: u64 = undefined;
    var k0: u64 = undefined;
    var d0: u64 = undefined;
    var t1: u64 = undefined;
    var k1: u64 = undefined;
    var d1: u64 = undefined;
    var d2: u64 = undefined;
    var t2: u64 = undefined;
    var k2: u64 = undefined;
    var d3: u64 = undefined;
    var k3: u64 = undefined;
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    out = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(data.len);
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"i3" = 3;
    @"u0" = 0;
    c6 = 6;
    c8 = 8;
    c12 = 12;
    c16 = 16;
    c18 = 18;
    c3f = 63;
    eq = 61;
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        rem = (n - pos);
        b0 = @intCast(data[@intCast(pos)]);
        b1 = @"u0";
        b2 = @"u0";
        has1 = (rem > @"i1");
        if (has1) {
            p1 = (pos + @"i1");
            b1 = @intCast(data[@intCast(p1)]);
        }
        has2 = (rem > @"i2");
        if (has2) {
            p2 = (pos + @"i2");
            b2 = @intCast(data[@intCast(p2)]);
        }
        s16 = (b0 << @intCast(c16));
        s8 = (b1 << @intCast(c8));
        acc0 = (s16 | s8);
        acc = (acc0 | b2);
        t0 = (acc >> @intCast(c18));
        k0 = (t0 & c3f);
        d0 = @intCast(alphabet[@intCast(k0)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(d0);
        t1 = (acc >> @intCast(c12));
        k1 = (t1 & c3f);
        d1 = @intCast(alphabet[@intCast(k1)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(d1);
        d2 = eq;
        if (has1) {
            t2 = (acc >> @intCast(c6));
            k2 = (t2 & c3f);
            d2 = @intCast(alphabet[@intCast(k2)]);
        }
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(d2);
        d3 = eq;
        if (has2) {
            k3 = (acc & c3f);
            d3 = @intCast(alphabet[@intCast(k3)]);
        }
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(d3);
        pos = (pos + @"i3");
    }
    return out;
}

pub fn base64_value(c: u64) u64 {
    var a_upper: u64 = undefined;
    var z_upper: u64 = undefined;
    var a_lower: u64 = undefined;
    var z_lower: u64 = undefined;
    var zero: u64 = undefined;
    var nine: u64 = undefined;
    var plus: u64 = undefined;
    var slash: u64 = undefined;
    var c26: u64 = undefined;
    var c52: u64 = undefined;
    var c62: u64 = undefined;
    var c63: u64 = undefined;
    var invalid: u64 = undefined;
    var value: u64 = undefined;
    var upper_lo: bool = undefined;
    var upper_hi: bool = undefined;
    var is_upper: bool = undefined;
    var lower_lo: bool = undefined;
    var lower_hi: bool = undefined;
    var is_lower: bool = undefined;
    var lower_offset: u64 = undefined;
    var digit_lo: bool = undefined;
    var digit_hi: bool = undefined;
    var is_digit: bool = undefined;
    var digit_offset: u64 = undefined;
    var is_plus: bool = undefined;
    var is_slash: bool = undefined;
    a_upper = 65;
    z_upper = 90;
    a_lower = 97;
    z_lower = 122;
    zero = 48;
    nine = 57;
    plus = 43;
    slash = 47;
    c26 = 26;
    c52 = 52;
    c62 = 62;
    c63 = 63;
    invalid = 64;
    value = invalid;
    upper_lo = (c >= a_upper);
    upper_hi = (c <= z_upper);
    is_upper = (upper_lo and upper_hi);
    if (is_upper) {
        value = (c -% a_upper);
    }
    lower_lo = (c >= a_lower);
    lower_hi = (c <= z_lower);
    is_lower = (lower_lo and lower_hi);
    if (is_lower) {
        lower_offset = (c -% a_lower);
        value = (lower_offset +% c26);
    }
    digit_lo = (c >= zero);
    digit_hi = (c <= nine);
    is_digit = (digit_lo and digit_hi);
    if (is_digit) {
        digit_offset = (c -% zero);
        value = (digit_offset +% c52);
    }
    is_plus = (c == plus);
    if (is_plus) {
        value = c62;
    }
    is_slash = (c == slash);
    if (is_slash) {
        value = c63;
    }
    return value;
}

pub fn base64_decode(data: []const u8) ?[]u8 {
    var out: []u8 = undefined;
    var none: ?[]u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"i3": i64 = undefined;
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u6": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u12": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u18": u64 = undefined;
    var invalid_value: u64 = undefined;
    var padding: u64 = undefined;
    var rem: i64 = undefined;
    var short_: bool = undefined;
    var bad_length: bool = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var p1: i64 = undefined;
    var p2: i64 = undefined;
    var p3: i64 = undefined;
    var next_: i64 = undefined;
    var last: bool = undefined;
    var b0: u64 = undefined;
    var b1: u64 = undefined;
    var b2: u64 = undefined;
    var b3: u64 = undefined;
    var c0: u64 = undefined;
    var c1: u64 = undefined;
    var bad_c0: bool = undefined;
    var bad_c1: bool = undefined;
    var pad2: bool = undefined;
    var pad3: bool = undefined;
    var any_padding: bool = undefined;
    var not_last: bool = undefined;
    var padding_before_tail: bool = undefined;
    var not_pad3: bool = undefined;
    var bad_padding: bool = undefined;
    var c2: u64 = undefined;
    var not_pad2: bool = undefined;
    var bad_c2: bool = undefined;
    var c3: u64 = undefined;
    var bad_c3: bool = undefined;
    var s18: u64 = undefined;
    var s12: u64 = undefined;
    var s6: u64 = undefined;
    var acc0: u64 = undefined;
    var acc1: u64 = undefined;
    var acc: u64 = undefined;
    var out0: u64 = undefined;
    var out1: u64 = undefined;
    var some: ?[]u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    none = null;
    n = @intCast(data.len);
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"i3" = 3;
    @"i4" = 4;
    @"u0" = 0;
    @"u6" = 6;
    @"u8" = 8;
    @"u12" = 12;
    @"u16" = 16;
    @"u18" = 18;
    invalid_value = 64;
    padding = 61;
    rem = n;
    while (true) {
        short_ = (rem < @"i4");
        if (short_) {
            break;
        }
        rem = (rem - @"i4");
    }
    bad_length = (rem != @"i0");
    if (bad_length) {
        return none;
    }
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        p1 = (pos + @"i1");
        p2 = (pos + @"i2");
        p3 = (pos + @"i3");
        next_ = (pos + @"i4");
        last = (next_ == n);
        b0 = @intCast(data[@intCast(pos)]);
        b1 = @intCast(data[@intCast(p1)]);
        b2 = @intCast(data[@intCast(p2)]);
        b3 = @intCast(data[@intCast(p3)]);
        c0 = base64_value(b0);
        c1 = base64_value(b1);
        bad_c0 = (c0 >= invalid_value);
        if (bad_c0) {
            return none;
        }
        bad_c1 = (c1 >= invalid_value);
        if (bad_c1) {
            return none;
        }
        pad2 = (b2 == padding);
        pad3 = (b3 == padding);
        any_padding = (pad2 or pad3);
        not_last = (!last);
        padding_before_tail = (any_padding and not_last);
        if (padding_before_tail) {
            return none;
        }
        not_pad3 = (!pad3);
        bad_padding = (pad2 and not_pad3);
        if (bad_padding) {
            return none;
        }
        c2 = @"u0";
        not_pad2 = (!pad2);
        if (not_pad2) {
            c2 = base64_value(b2);
            bad_c2 = (c2 >= invalid_value);
            if (bad_c2) {
                return none;
            }
        }
        c3 = @"u0";
        if (not_pad3) {
            c3 = base64_value(b3);
            bad_c3 = (c3 >= invalid_value);
            if (bad_c3) {
                return none;
            }
        }
        s18 = (c0 << @intCast(@"u18"));
        s12 = (c1 << @intCast(@"u12"));
        s6 = (c2 << @intCast(@"u6"));
        acc0 = (s18 | s12);
        acc1 = (acc0 | s6);
        acc = (acc1 | c3);
        out0 = (acc >> @intCast(@"u16"));
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(out0);
        if (not_pad2) {
            out1 = (acc >> @intCast(@"u8"));
            out = allocator.realloc(out, out.len + 1) catch unreachable;
            out[out.len - 1] = @truncate(out1);
        }
        if (not_pad3) {
            out = allocator.realloc(out, out.len + 1) catch unreachable;
            out[out.len - 1] = @truncate(acc);
        }
        pos = next_;
    }
    some = out;
    return some;
}

pub fn u64_as_i64(value: u64) i64 {
    var signed_: i64 = undefined;
    signed_ = @bitCast(value);
    return signed_;
}

pub fn twos_complement_le(data: []const u8) []u8 {
    var out: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u1": u64 = undefined;
    var @"u255": u64 = undefined;
    var carry: bool = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var inverted: u64 = undefined;
    var sum: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(data.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u1" = 1;
    @"u255" = 255;
    carry = true;
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        byte_ = @intCast(data[@intCast(pos)]);
        inverted = (byte_ ^ @"u255");
        sum = inverted;
        if (carry) {
            sum = (inverted +% @"u1");
            carry = (sum > @"u255");
        }
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(sum);
        pos = (pos + @"i1");
    }
    return out;
}

pub fn canonicalize_signed_le(data: []const u8) []u8 {
    var out: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u128": u64 = undefined;
    var @"u255": u64 = undefined;
    var empty: bool = undefined;
    var keep: i64 = undefined;
    var one_left: bool = undefined;
    var last_pos: i64 = undefined;
    var prev_pos: i64 = undefined;
    var last: u64 = undefined;
    var prev: u64 = undefined;
    var prev_sign: u64 = undefined;
    var prev_negative: bool = undefined;
    var prev_positive: bool = undefined;
    var last_zero: bool = undefined;
    var last_ff: bool = undefined;
    var positive_extension: bool = undefined;
    var negative_extension: bool = undefined;
    var redundant: bool = undefined;
    var needed: bool = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(data.len);
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"u0" = 0;
    @"u128" = 128;
    @"u255" = 255;
    empty = (n == @"i0");
    if (empty) {
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(@"u0");
        return out;
    }
    keep = n;
    while (true) {
        one_left = (keep <= @"i1");
        if (one_left) {
            break;
        }
        last_pos = (keep - @"i1");
        prev_pos = (keep - @"i2");
        last = @intCast(data[@intCast(last_pos)]);
        prev = @intCast(data[@intCast(prev_pos)]);
        prev_sign = (prev & @"u128");
        prev_negative = (prev_sign != @"u0");
        prev_positive = (!prev_negative);
        last_zero = (last == @"u0");
        last_ff = (last == @"u255");
        positive_extension = (last_zero and prev_positive);
        negative_extension = (last_ff and prev_negative);
        redundant = (positive_extension or negative_extension);
        needed = (!redundant);
        if (needed) {
            break;
        }
        keep = (keep - @"i1");
    }
    pos = @"i0";
    while (true) {
        done = (pos >= keep);
        if (done) {
            break;
        }
        byte_ = @intCast(data[@intCast(pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        pos = (pos + @"i1");
    }
    return out;
}

pub fn signed_abs_le(data: []const u8) []u8 {
    var value: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u128": u64 = undefined;
    var last_pos: i64 = undefined;
    var last: u64 = undefined;
    var sign: u64 = undefined;
    var negative: bool = undefined;
    var positive: bool = undefined;
    var magnitude: []u8 = undefined;
    var out: []u8 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var mag_last: u64 = undefined;
    var mag_sign: u64 = undefined;
    var needs_zero: bool = undefined;
    value = canonicalize_signed_le(data);
    n = @intCast(value.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u128" = 128;
    last_pos = (n - @"i1");
    last = @intCast(value[@intCast(last_pos)]);
    sign = (last & @"u128");
    negative = (sign != @"u0");
    positive = (!negative);
    if (positive) {
        return value;
    }
    magnitude = twos_complement_le(value);
    out = allocator.alloc(u8, 0) catch unreachable;
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        byte_ = @intCast(magnitude[@intCast(pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        pos = (pos + @"i1");
    }
    mag_last = @intCast(magnitude[@intCast(last_pos)]);
    mag_sign = (mag_last & @"u128");
    needs_zero = (mag_sign != @"u0");
    if (needs_zero) {
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(@"u0");
    }
    return out;
}

pub fn signed_negate_le(data: []const u8) []u8 {
    var value: []u8 = undefined;
    var out: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u128": u64 = undefined;
    var @"u255": u64 = undefined;
    var last_pos: i64 = undefined;
    var last: u64 = undefined;
    var sign: u64 = undefined;
    var negative: bool = undefined;
    var extension: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var negated: []u8 = undefined;
    var canonical: []u8 = undefined;
    value = canonicalize_signed_le(data);
    out = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(value.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u128" = 128;
    @"u255" = 255;
    last_pos = (n - @"i1");
    last = @intCast(value[@intCast(last_pos)]);
    sign = (last & @"u128");
    negative = (sign != @"u0");
    extension = @"u0";
    if (negative) {
        extension = @"u255";
    }
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        byte_ = @intCast(value[@intCast(pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        pos = (pos + @"i1");
    }
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(extension);
    negated = twos_complement_le(out);
    canonical = canonicalize_signed_le(negated);
    return canonical;
}

pub fn signed_add_le(left_raw: []const u8, right_raw: []const u8) []u8 {
    var left: []u8 = undefined;
    var right: []u8 = undefined;
    var out: []u8 = undefined;
    var left_n: i64 = undefined;
    var right_n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u128": u64 = undefined;
    var @"u255": u64 = undefined;
    var left_last_pos: i64 = undefined;
    var right_last_pos: i64 = undefined;
    var left_last: u64 = undefined;
    var right_last: u64 = undefined;
    var left_sign: u64 = undefined;
    var right_sign: u64 = undefined;
    var left_negative: bool = undefined;
    var right_negative: bool = undefined;
    var left_extension: u64 = undefined;
    var right_extension: u64 = undefined;
    var width: i64 = undefined;
    var right_longer: bool = undefined;
    var carry: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var left_byte: u64 = undefined;
    var left_present: bool = undefined;
    var right_byte: u64 = undefined;
    var right_present: bool = undefined;
    var partial: u64 = undefined;
    var sum: u64 = undefined;
    var out_byte: u64 = undefined;
    var canonical: []u8 = undefined;
    left = canonicalize_signed_le(left_raw);
    right = canonicalize_signed_le(right_raw);
    out = allocator.alloc(u8, 0) catch unreachable;
    left_n = @intCast(left.len);
    right_n = @intCast(right.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u8" = 8;
    @"u128" = 128;
    @"u255" = 255;
    left_last_pos = (left_n - @"i1");
    right_last_pos = (right_n - @"i1");
    left_last = @intCast(left[@intCast(left_last_pos)]);
    right_last = @intCast(right[@intCast(right_last_pos)]);
    left_sign = (left_last & @"u128");
    right_sign = (right_last & @"u128");
    left_negative = (left_sign != @"u0");
    right_negative = (right_sign != @"u0");
    left_extension = @"u0";
    if (left_negative) {
        left_extension = @"u255";
    }
    right_extension = @"u0";
    if (right_negative) {
        right_extension = @"u255";
    }
    width = left_n;
    right_longer = (right_n > left_n);
    if (right_longer) {
        width = right_n;
    }
    width = (width + @"i1");
    carry = @"u0";
    pos = @"i0";
    while (true) {
        done = (pos >= width);
        if (done) {
            break;
        }
        left_byte = left_extension;
        left_present = (pos < left_n);
        if (left_present) {
            left_byte = @intCast(left[@intCast(pos)]);
        }
        right_byte = right_extension;
        right_present = (pos < right_n);
        if (right_present) {
            right_byte = @intCast(right[@intCast(pos)]);
        }
        partial = (left_byte +% right_byte);
        sum = (partial +% carry);
        out_byte = (sum & @"u255");
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(out_byte);
        carry = (sum >> @intCast(@"u8"));
        pos = (pos + @"i1");
    }
    canonical = canonicalize_signed_le(out);
    return canonical;
}

pub fn signed_sub_le(left: []const u8, right: []const u8) []u8 {
    var negative_right: []u8 = undefined;
    var result: []u8 = undefined;
    negative_right = signed_negate_le(right);
    result = signed_add_le(left, negative_right);
    return result;
}

pub fn positive_shr1_le(data: []const u8) []u8 {
    var value: []u8 = undefined;
    var out: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u1": u64 = undefined;
    var @"u7": u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var current: u64 = undefined;
    var shifted: u64 = undefined;
    var out_byte: u64 = undefined;
    var next_pos: i64 = undefined;
    var has_next: bool = undefined;
    var next_: u64 = undefined;
    var next_low: u64 = undefined;
    var incoming: u64 = undefined;
    var canonical: []u8 = undefined;
    value = canonicalize_signed_le(data);
    out = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(value.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u1" = 1;
    @"u7" = 7;
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        current = @intCast(value[@intCast(pos)]);
        shifted = (current >> @intCast(@"u1"));
        out_byte = shifted;
        next_pos = (pos + @"i1");
        has_next = (next_pos < n);
        if (has_next) {
            next_ = @intCast(value[@intCast(next_pos)]);
            next_low = (next_ & @"u1");
            incoming = (next_low << @intCast(@"u7"));
            out_byte = (shifted | incoming);
        }
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(out_byte);
        pos = next_pos;
    }
    canonical = canonicalize_signed_le(out);
    return canonical;
}

pub fn signed_mul_le(left_raw: []const u8, right_raw: []const u8) []u8 {
    var left_value: []u8 = undefined;
    var right_value: []u8 = undefined;
    var left_n: i64 = undefined;
    var right_n: i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u128": u64 = undefined;
    var left_last_pos: i64 = undefined;
    var right_last_pos: i64 = undefined;
    var left_last: u64 = undefined;
    var right_last: u64 = undefined;
    var left_sign: u64 = undefined;
    var right_sign: u64 = undefined;
    var left_negative: bool = undefined;
    var right_negative: bool = undefined;
    var negative_result: bool = undefined;
    var multiplicand: []u8 = undefined;
    var multiplier: []u8 = undefined;
    var product: []u8 = undefined;
    var low: u64 = undefined;
    var nonzero: bool = undefined;
    var multiplier_n: i64 = undefined;
    var more_bytes: bool = undefined;
    var has_value: bool = undefined;
    var done: bool = undefined;
    var low_bit: u64 = undefined;
    var odd: bool = undefined;
    left_value = canonicalize_signed_le(left_raw);
    right_value = canonicalize_signed_le(right_raw);
    left_n = @intCast(left_value.len);
    right_n = @intCast(right_value.len);
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u128" = 128;
    left_last_pos = (left_n - @"i1");
    right_last_pos = (right_n - @"i1");
    left_last = @intCast(left_value[@intCast(left_last_pos)]);
    right_last = @intCast(right_value[@intCast(right_last_pos)]);
    left_sign = (left_last & @"u128");
    right_sign = (right_last & @"u128");
    left_negative = (left_sign != @"u0");
    right_negative = (right_sign != @"u0");
    negative_result = (left_negative != right_negative);
    multiplicand = signed_abs_le(left_value);
    multiplier = signed_abs_le(right_value);
    product = allocator.alloc(u8, 0) catch unreachable;
    product = allocator.realloc(product, product.len + 1) catch unreachable;
    product[product.len - 1] = @truncate(@"u0");
    while (true) {
        low = @intCast(multiplier[@intCast(@"u0")]);
        nonzero = (low != @"u0");
        multiplier_n = @intCast(multiplier.len);
        more_bytes = (multiplier_n > @"i1");
        has_value = (nonzero or more_bytes);
        done = (!has_value);
        if (done) {
            break;
        }
        low_bit = (low & @"u1");
        odd = (low_bit != @"u0");
        if (odd) {
            product = signed_add_le(product, multiplicand);
        }
        multiplicand = signed_add_le(multiplicand, multiplicand);
        multiplier = positive_shr1_le(multiplier);
    }
    if (negative_result) {
        product = signed_negate_le(product);
    }
    return product;
}

pub fn positive_div_le_nonzero(dividend_raw: []const u8, divisor_raw: []const u8) []u8 {
    var remainder: []u8 = undefined;
    var scaled_divisor: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var quotient: []u8 = undefined;
    var bit: []u8 = undefined;
    var scale_cmp: i64 = undefined;
    var can_scale: bool = undefined;
    var stop_scaling: bool = undefined;
    var bit_low: u64 = undefined;
    var bit_n: i64 = undefined;
    var bit_nonzero: bool = undefined;
    var bit_more: bool = undefined;
    var has_bit: bool = undefined;
    var done: bool = undefined;
    var cmp: i64 = undefined;
    var can_subtract: bool = undefined;
    remainder = signed_abs_le(dividend_raw);
    scaled_divisor = signed_abs_le(divisor_raw);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    quotient = allocator.alloc(u8, 0) catch unreachable;
    quotient = allocator.realloc(quotient, quotient.len + 1) catch unreachable;
    quotient[quotient.len - 1] = @truncate(@"u0");
    bit = allocator.alloc(u8, 0) catch unreachable;
    bit = allocator.realloc(bit, bit.len + 1) catch unreachable;
    bit[bit.len - 1] = @truncate(@"u1");
    while (true) {
        scale_cmp = signed_compare_le(scaled_divisor, remainder);
        can_scale = (scale_cmp <= @"i0");
        stop_scaling = (!can_scale);
        if (stop_scaling) {
            break;
        }
        scaled_divisor = signed_add_le(scaled_divisor, scaled_divisor);
        bit = signed_add_le(bit, bit);
    }
    while (true) {
        scaled_divisor = positive_shr1_le(scaled_divisor);
        bit = positive_shr1_le(bit);
        bit_low = @intCast(bit[@intCast(@"u0")]);
        bit_n = @intCast(bit.len);
        bit_nonzero = (bit_low != @"u0");
        bit_more = (bit_n > @"i1");
        has_bit = (bit_nonzero or bit_more);
        done = (!has_bit);
        if (done) {
            break;
        }
        cmp = signed_compare_le(scaled_divisor, remainder);
        can_subtract = (cmp <= @"i0");
        if (can_subtract) {
            remainder = signed_sub_le(remainder, scaled_divisor);
            quotient = signed_add_le(quotient, bit);
        }
    }
    return quotient;
}

pub fn positive_rem_le_nonzero(dividend: []const u8, divisor: []const u8) []u8 {
    var positive_dividend: []u8 = undefined;
    var positive_divisor: []u8 = undefined;
    var quotient: []u8 = undefined;
    var product: []u8 = undefined;
    var remainder: []u8 = undefined;
    positive_dividend = signed_abs_le(dividend);
    positive_divisor = signed_abs_le(divisor);
    quotient = positive_div_le_nonzero(positive_dividend, positive_divisor);
    product = signed_mul_le(quotient, positive_divisor);
    remainder = signed_sub_le(positive_dividend, product);
    return remainder;
}

pub fn positive_pow_le(base_raw: []const u8, exponent: u64) []u8 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var result: []u8 = undefined;
    var factor: []u8 = undefined;
    var power: u64 = undefined;
    var done: bool = undefined;
    var low_bit: u64 = undefined;
    var odd: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    result = allocator.alloc(u8, 0) catch unreachable;
    result = allocator.realloc(result, result.len + 1) catch unreachable;
    result[result.len - 1] = @truncate(@"u1");
    factor = signed_abs_le(base_raw);
    power = exponent;
    while (true) {
        done = (power == @"u0");
        if (done) {
            break;
        }
        low_bit = (power & @"u1");
        odd = (low_bit != @"u0");
        if (odd) {
            result = signed_mul_le(result, factor);
        }
        factor = signed_mul_le(factor, factor);
        power = (power >> @intCast(@"u1"));
    }
    return result;
}

pub fn positive_mul_add_small_le(value_raw: []const u8, factor: u64, addend: u64) []u8 {
    var value: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var out: []u8 = undefined;
    var carry: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var scaled: u64 = undefined;
    var sum: u64 = undefined;
    var out_byte: u64 = undefined;
    var drained: bool = undefined;
    var carry_byte: u64 = undefined;
    var canonical: []u8 = undefined;
    value = signed_abs_le(value_raw);
    n = @intCast(value.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u8" = 8;
    @"u255" = 255;
    out = allocator.alloc(u8, 0) catch unreachable;
    carry = addend;
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        byte_ = @intCast(value[@intCast(pos)]);
        scaled = (byte_ *% factor);
        sum = (scaled +% carry);
        out_byte = (sum & @"u255");
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(out_byte);
        carry = (sum >> @intCast(@"u8"));
        pos = (pos + @"i1");
    }
    while (true) {
        drained = (carry == @"u0");
        if (drained) {
            break;
        }
        carry_byte = (carry & @"u255");
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(carry_byte);
        carry = (carry >> @intCast(@"u8"));
    }
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(@"u0");
    canonical = canonicalize_signed_le(out);
    return canonical;
}

pub fn small_quotient_digit(current: u64, divisor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var digit: u64 = undefined;
    var rest: u64 = undefined;
    var bit: u64 = undefined;
    var done: bool = undefined;
    var step: u64 = undefined;
    var fits: bool = undefined;
    var place: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    digit = @"u0";
    rest = current;
    bit = @"u8";
    while (true) {
        done = (bit == @"u0");
        if (done) {
            break;
        }
        bit = (bit -% @"u1");
        step = (divisor << @intCast(bit));
        fits = (rest >= step);
        if (fits) {
            rest = (rest -% step);
            place = (@"u1" << @intCast(bit));
            digit = (digit | place);
        }
    }
    return digit;
}

pub fn positive_div_small_le(value_raw: []const u8, divisor: u64) []u8 {
    var value: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var high_first: []u8 = undefined;
    var remainder: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var shifted: u64 = undefined;
    var current: u64 = undefined;
    var digit: u64 = undefined;
    var taken: u64 = undefined;
    var out: []u8 = undefined;
    var canonical: []u8 = undefined;
    value = signed_abs_le(value_raw);
    n = @intCast(value.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u8" = 8;
    high_first = allocator.alloc(u8, 0) catch unreachable;
    remainder = @"u0";
    pos = n;
    while (true) {
        done = (pos == @"i0");
        if (done) {
            break;
        }
        pos = (pos - @"i1");
        byte_ = @intCast(value[@intCast(pos)]);
        shifted = (remainder << @intCast(@"u8"));
        current = (shifted +% byte_);
        digit = small_quotient_digit(current, divisor);
        high_first = allocator.realloc(high_first, high_first.len + 1) catch unreachable;
        high_first[high_first.len - 1] = @truncate(digit);
        taken = (digit *% divisor);
        remainder = (current -% taken);
    }
    out = allocator.alloc(u8, 0) catch unreachable;
    pos = n;
    while (true) {
        done = (pos == @"i0");
        if (done) {
            break;
        }
        pos = (pos - @"i1");
        byte_ = @intCast(high_first[@intCast(pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
    }
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(@"u0");
    canonical = canonicalize_signed_le(out);
    return canonical;
}

pub fn positive_rem_small_le(value_raw: []const u8, divisor: u64) u64 {
    var value: []u8 = undefined;
    var n: i64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var remainder: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var shifted: u64 = undefined;
    var current: u64 = undefined;
    var digit: u64 = undefined;
    var taken: u64 = undefined;
    value = signed_abs_le(value_raw);
    n = @intCast(value.len);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u8" = 8;
    remainder = @"u0";
    pos = n;
    while (true) {
        done = (pos == @"i0");
        if (done) {
            break;
        }
        pos = (pos - @"i1");
        byte_ = @intCast(value[@intCast(pos)]);
        shifted = (remainder << @intCast(@"u8"));
        current = (shifted +% byte_);
        digit = small_quotient_digit(current, divisor);
        taken = (digit *% divisor);
        remainder = (current -% taken);
    }
    return remainder;
}

pub fn signed_compare_le(left_raw: []const u8, right_raw: []const u8) i64 {
    var left: []u8 = undefined;
    var right: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u128": u64 = undefined;
    var negative_one: i64 = undefined;
    var left_n: i64 = undefined;
    var right_n: i64 = undefined;
    var left_last_pos: i64 = undefined;
    var right_last_pos: i64 = undefined;
    var left_last: u64 = undefined;
    var right_last: u64 = undefined;
    var left_sign: u64 = undefined;
    var right_sign: u64 = undefined;
    var left_negative: bool = undefined;
    var right_negative: bool = undefined;
    var right_positive: bool = undefined;
    var left_only_negative: bool = undefined;
    var left_positive: bool = undefined;
    var right_only_negative: bool = undefined;
    var left_shorter: bool = undefined;
    var short_result: i64 = undefined;
    var left_longer: bool = undefined;
    var long_result: i64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var left_byte: u64 = undefined;
    var right_byte: u64 = undefined;
    var byte_less: bool = undefined;
    var byte_greater: bool = undefined;
    left = canonicalize_signed_le(left_raw);
    right = canonicalize_signed_le(right_raw);
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u128" = 128;
    negative_one = (@"i0" - @"i1");
    left_n = @intCast(left.len);
    right_n = @intCast(right.len);
    left_last_pos = (left_n - @"i1");
    right_last_pos = (right_n - @"i1");
    left_last = @intCast(left[@intCast(left_last_pos)]);
    right_last = @intCast(right[@intCast(right_last_pos)]);
    left_sign = (left_last & @"u128");
    right_sign = (right_last & @"u128");
    left_negative = (left_sign != @"u0");
    right_negative = (right_sign != @"u0");
    right_positive = (!right_negative);
    left_only_negative = (left_negative and right_positive);
    if (left_only_negative) {
        return negative_one;
    }
    left_positive = (!left_negative);
    right_only_negative = (left_positive and right_negative);
    if (right_only_negative) {
        return @"i1";
    }
    left_shorter = (left_n < right_n);
    if (left_shorter) {
        short_result = negative_one;
        if (left_negative) {
            short_result = @"i1";
        }
        return short_result;
    }
    left_longer = (left_n > right_n);
    if (left_longer) {
        long_result = @"i1";
        if (left_negative) {
            long_result = negative_one;
        }
        return long_result;
    }
    pos = left_n;
    while (true) {
        done = (pos == @"i0");
        if (done) {
            break;
        }
        pos = (pos - @"i1");
        left_byte = @intCast(left[@intCast(pos)]);
        right_byte = @intCast(right[@intCast(pos)]);
        byte_less = (left_byte < right_byte);
        if (byte_less) {
            return negative_one;
        }
        byte_greater = (left_byte > right_byte);
        if (byte_greater) {
            return @"i1";
        }
    }
    return @"i0";
}

pub fn bigint_zero() []u8 {
    var out: []u8 = undefined;
    var zero: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    zero = 0;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(zero);
    return out;
}

pub fn bigint_one() []u8 {
    var out: []u8 = undefined;
    var one: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    one = 1;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(one);
    return out;
}

pub fn bigint_two() []u8 {
    var out: []u8 = undefined;
    var two: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    two = 2;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(two);
    return out;
}

pub fn bigint_base_256() []u8 {
    var out: []u8 = undefined;
    var zero: u64 = undefined;
    var one: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    zero = 0;
    one = 1;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(zero);
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(one);
    return out;
}

pub fn positive_u8_le(value: u64) []u8 {
    var out: []u8 = undefined;
    var @"u0": u64 = undefined;
    var @"u128": u64 = undefined;
    var needs_sign_byte: bool = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"u0" = 0;
    @"u128" = 128;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(value);
    needs_sign_byte = (value >= @"u128");
    if (needs_sign_byte) {
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(@"u0");
    }
    return out;
}

pub fn bigint_min(left: []const u8, right: []const u8) []u8 {
    var cmp: i64 = undefined;
    var @"i0": i64 = undefined;
    var left_is_min: bool = undefined;
    var out_left: []u8 = undefined;
    var out_right: []u8 = undefined;
    cmp = signed_compare_le(left, right);
    @"i0" = 0;
    left_is_min = (cmp <= @"i0");
    if (left_is_min) {
        out_left = canonicalize_signed_le(left);
        return out_left;
    }
    out_right = canonicalize_signed_le(right);
    return out_right;
}

pub fn integer_simplest(min_value: []const u8, max_value: []const u8, shrink_towards: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var below_cmp: i64 = undefined;
    var below: bool = undefined;
    var min_out: []u8 = undefined;
    var above_cmp: i64 = undefined;
    var above: bool = undefined;
    var max_out: []u8 = undefined;
    var target_out: []u8 = undefined;
    @"i0" = 0;
    below_cmp = signed_compare_le(shrink_towards, min_value);
    below = (below_cmp < @"i0");
    if (below) {
        min_out = canonicalize_signed_le(min_value);
        return min_out;
    }
    above_cmp = signed_compare_le(shrink_towards, max_value);
    above = (above_cmp > @"i0");
    if (above) {
        max_out = canonicalize_signed_le(max_value);
        return max_out;
    }
    target_out = canonicalize_signed_le(shrink_towards);
    return target_out;
}

pub fn integer_validate(min_value: []const u8, max_value: []const u8, value: []const u8) bool {
    var @"i0": i64 = undefined;
    var min_cmp: i64 = undefined;
    var max_cmp: i64 = undefined;
    var above_min: bool = undefined;
    var below_max: bool = undefined;
    var valid: bool = undefined;
    @"i0" = 0;
    min_cmp = signed_compare_le(min_value, value);
    max_cmp = signed_compare_le(value, max_value);
    above_min = (min_cmp <= @"i0");
    below_max = (max_cmp <= @"i0");
    valid = (above_min and below_max);
    return valid;
}

pub fn integer_unit(min_value: []const u8, max_value: []const u8, shrink_towards: []const u8) []u8 {
    var simplest: []u8 = undefined;
    var one: []u8 = undefined;
    var successor: []u8 = undefined;
    var successor_valid: bool = undefined;
    var predecessor: []u8 = undefined;
    var predecessor_valid: bool = undefined;
    simplest = integer_simplest(min_value, max_value, shrink_towards);
    one = bigint_one();
    successor = signed_add_le(simplest, one);
    successor_valid = integer_validate(min_value, max_value, successor);
    if (successor_valid) {
        return successor;
    }
    predecessor = signed_sub_le(simplest, one);
    predecessor_valid = integer_validate(min_value, max_value, predecessor);
    if (predecessor_valid) {
        return predecessor;
    }
    return simplest;
}

pub fn integer_max_index(min_value: []const u8, max_value: []const u8) []u8 {
    var difference: []u8 = undefined;
    var out: []u8 = undefined;
    difference = signed_sub_le(max_value, min_value);
    out = signed_abs_le(difference);
    return out;
}

pub fn integer_to_index(min_value: []const u8, max_value: []const u8, shrink_towards: []const u8, value: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var simplest: []u8 = undefined;
    var value_cmp: i64 = undefined;
    var at_simplest: bool = undefined;
    var zero: []u8 = undefined;
    var above_delta: []u8 = undefined;
    var above: []u8 = undefined;
    var below_delta: []u8 = undefined;
    var below: []u8 = undefined;
    var value_delta: []u8 = undefined;
    var distance: []u8 = undefined;
    var one: []u8 = undefined;
    var distance_minus_one: []u8 = undefined;
    var count_above: []u8 = undefined;
    var count_below: []u8 = undefined;
    var count: []u8 = undefined;
    var value_above: bool = undefined;
    var up_index: []u8 = undefined;
    var distance_cmp: i64 = undefined;
    var up_slot_exists: bool = undefined;
    var down_index: []u8 = undefined;
    @"i0" = 0;
    simplest = integer_simplest(min_value, max_value, shrink_towards);
    value_cmp = signed_compare_le(value, simplest);
    at_simplest = (value_cmp == @"i0");
    if (at_simplest) {
        zero = bigint_zero();
        return zero;
    }
    above_delta = signed_sub_le(max_value, simplest);
    above = signed_abs_le(above_delta);
    below_delta = signed_sub_le(simplest, min_value);
    below = signed_abs_le(below_delta);
    value_delta = signed_sub_le(value, simplest);
    distance = signed_abs_le(value_delta);
    one = bigint_one();
    distance_minus_one = signed_sub_le(distance, one);
    count_above = bigint_min(distance_minus_one, above);
    count_below = bigint_min(distance_minus_one, below);
    count = signed_add_le(count_above, count_below);
    value_above = (value_cmp > @"i0");
    if (value_above) {
        up_index = signed_add_le(count, one);
        return up_index;
    }
    distance_cmp = signed_compare_le(distance, above);
    up_slot_exists = (distance_cmp <= @"i0");
    if (up_slot_exists) {
        count = signed_add_le(count, one);
    }
    down_index = signed_add_le(count, one);
    return down_index;
}

pub fn integer_from_index(min_value: []const u8, max_value: []const u8, shrink_towards: []const u8, index_raw: []const u8) ?[]u8 {
    var @"i0": i64 = undefined;
    var simplest: []u8 = undefined;
    var index: []u8 = undefined;
    var zero: []u8 = undefined;
    var index_zero_cmp: i64 = undefined;
    var at_zero: bool = undefined;
    var some_simplest: ?[]u8 = undefined;
    var above_delta: []u8 = undefined;
    var above: []u8 = undefined;
    var below_delta: []u8 = undefined;
    var below: []u8 = undefined;
    var max_index: []u8 = undefined;
    var past_cmp: i64 = undefined;
    var past_end: bool = undefined;
    var none: ?[]u8 = undefined;
    var a: []u8 = undefined;
    var two_a: []u8 = undefined;
    var two_a_cmp: i64 = undefined;
    var interleaved: bool = undefined;
    var distance: []u8 = undefined;
    var up: bool = undefined;
    var one: []u8 = undefined;
    var two: []u8 = undefined;
    var index_plus_one: []u8 = undefined;
    var parity: []u8 = undefined;
    var parity_cmp: i64 = undefined;
    var tail: bool = undefined;
    var range_cmp: i64 = undefined;
    var result: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    simplest = integer_simplest(min_value, max_value, shrink_towards);
    index = signed_abs_le(index_raw);
    zero = bigint_zero();
    index_zero_cmp = signed_compare_le(index, zero);
    at_zero = (index_zero_cmp == @"i0");
    if (at_zero) {
        some_simplest = simplest;
        return some_simplest;
    }
    above_delta = signed_sub_le(max_value, simplest);
    above = signed_abs_le(above_delta);
    below_delta = signed_sub_le(simplest, min_value);
    below = signed_abs_le(below_delta);
    max_index = signed_add_le(above, below);
    past_cmp = signed_compare_le(index, max_index);
    past_end = (past_cmp > @"i0");
    if (past_end) {
        none = null;
        return none;
    }
    a = bigint_min(above, below);
    two_a = signed_add_le(a, a);
    two_a_cmp = signed_compare_le(index, two_a);
    interleaved = (two_a_cmp <= @"i0");
    distance = allocator.dupe(u8, index) catch unreachable;
    up = false;
    if (interleaved) {
        one = bigint_one();
        two = bigint_two();
        index_plus_one = signed_add_le(index, one);
        distance = positive_div_le_nonzero(index_plus_one, two);
        parity = positive_rem_le_nonzero(index, two);
        parity_cmp = signed_compare_le(parity, zero);
        up = (parity_cmp != @"i0");
    }
    tail = (!interleaved);
    if (tail) {
        distance = signed_sub_le(index, a);
        range_cmp = signed_compare_le(above, below);
        up = (range_cmp > @"i0");
    }
    result = signed_sub_le(simplest, distance);
    if (up) {
        result = signed_add_le(simplest, distance);
    }
    some = result;
    return some;
}

pub fn integer_shrink_extra_divisor(slot: u64) []u8 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u10": u64 = undefined;
    var divisor: u64 = undefined;
    var is_three: bool = undefined;
    var is_five: bool = undefined;
    var is_seven: bool = undefined;
    var out: []u8 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u5" = 5;
    @"u7" = 7;
    @"u10" = 10;
    divisor = @"u10";
    is_three = (slot == @"u0");
    if (is_three) {
        divisor = @"u3";
    }
    is_five = (slot == @"u1");
    if (is_five) {
        divisor = @"u5";
    }
    is_seven = (slot == @"u2");
    if (is_seven) {
        divisor = @"u7";
    }
    out = positive_u8_le(divisor);
    return out;
}

pub fn integer_trailing_power(distance: []const u8, radix: u64) []u8 {
    var @"i0": i64 = undefined;
    var base: []u8 = undefined;
    var zero: []u8 = undefined;
    var power: []u8 = undefined;
    var rest: []u8 = undefined;
    var rest_cmp: i64 = undefined;
    var exhausted: bool = undefined;
    var remainder: []u8 = undefined;
    var remainder_cmp: i64 = undefined;
    var divides: bool = undefined;
    var stops: bool = undefined;
    @"i0" = 0;
    base = positive_u8_le(radix);
    zero = bigint_zero();
    power = bigint_one();
    rest = signed_abs_le(distance);
    while (true) {
        rest_cmp = signed_compare_le(rest, zero);
        exhausted = (rest_cmp == @"i0");
        if (exhausted) {
            break;
        }
        remainder = positive_rem_le_nonzero(rest, base);
        remainder_cmp = signed_compare_le(remainder, zero);
        divides = (remainder_cmp == @"i0");
        stops = (!divides);
        if (stops) {
            break;
        }
        rest = positive_div_le_nonzero(rest, base);
        power = signed_mul_le(power, base);
    }
    return power;
}

pub fn integer_shrink_extra_distance(distance: []const u8, slot: u64) []u8 {
    var @"i0": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u10": u64 = undefined;
    var zero: []u8 = undefined;
    var one: []u8 = undefined;
    var divides: bool = undefined;
    var divisor: []u8 = undefined;
    var quotient: []u8 = undefined;
    var radix: u64 = undefined;
    var decimal: bool = undefined;
    var power: []u8 = undefined;
    var one_cmp: i64 = undefined;
    var trivial: bool = undefined;
    var whole_cmp: i64 = undefined;
    var whole: bool = undefined;
    var earlier: u64 = undefined;
    var checked: bool = undefined;
    var earlier_divisor: []u8 = undefined;
    var earlier_quotient: []u8 = undefined;
    var same_cmp: i64 = undefined;
    var same: bool = undefined;
    @"i0" = 0;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u4" = 4;
    @"u10" = 10;
    zero = bigint_zero();
    one = bigint_one();
    divides = (slot < @"u4");
    if (divides) {
        divisor = integer_shrink_extra_divisor(slot);
        quotient = positive_div_le_nonzero(distance, divisor);
        return quotient;
    }
    radix = @"u2";
    decimal = (slot == @"u4");
    if (decimal) {
        radix = @"u10";
    }
    power = integer_trailing_power(distance, radix);
    one_cmp = signed_compare_le(power, one);
    trivial = (one_cmp <= @"i0");
    if (trivial) {
        return zero;
    }
    whole_cmp = signed_compare_le(power, distance);
    whole = (whole_cmp >= @"i0");
    if (whole) {
        return zero;
    }
    earlier = @"u0";
    while (true) {
        checked = (earlier >= @"u4");
        if (checked) {
            break;
        }
        earlier_divisor = integer_shrink_extra_divisor(earlier);
        earlier_quotient = positive_div_le_nonzero(distance, earlier_divisor);
        same_cmp = signed_compare_le(power, earlier_quotient);
        same = (same_cmp == @"i0");
        if (same) {
            return zero;
        }
        earlier = (earlier +% @"u1");
    }
    return power;
}

pub fn integer_shrink_extra(min_value: []const u8, max_value: []const u8, shrink_towards: []const u8, value: []const u8, ordinal: u64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u6": u64 = undefined;
    var zero: []u8 = undefined;
    var prefix: []u8 = undefined;
    var simplest: []u8 = undefined;
    var offset: []u8 = undefined;
    var distance: []u8 = undefined;
    var seen: u64 = undefined;
    var slot: u64 = undefined;
    var slots_done: bool = undefined;
    var moved: []u8 = undefined;
    var moved_cmp: i64 = undefined;
    var moves: bool = undefined;
    var side: u64 = undefined;
    var sides_done: bool = undefined;
    var candidate: []u8 = undefined;
    var below: bool = undefined;
    var valid: bool = undefined;
    var index: []u8 = undefined;
    var index_cmp: i64 = undefined;
    var unprobed: bool = undefined;
    var wanted: bool = undefined;
    var some: ?[]u8 = undefined;
    var none: ?[]u8 = undefined;
    @"i0" = 0;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u5" = 5;
    @"u6" = 6;
    zero = bigint_zero();
    prefix = positive_u8_le(@"u5");
    simplest = integer_simplest(min_value, max_value, shrink_towards);
    offset = signed_sub_le(value, simplest);
    distance = signed_abs_le(offset);
    seen = @"u0";
    slot = @"u0";
    while (true) {
        slots_done = (slot >= @"u6");
        if (slots_done) {
            break;
        }
        moved = integer_shrink_extra_distance(distance, slot);
        moved_cmp = signed_compare_le(moved, zero);
        moves = (moved_cmp > @"i0");
        if (moves) {
            side = @"u0";
            while (true) {
                sides_done = (side >= @"u2");
                if (sides_done) {
                    break;
                }
                candidate = signed_add_le(simplest, moved);
                below = (side == @"u1");
                if (below) {
                    candidate = signed_sub_le(simplest, moved);
                }
                valid = integer_validate(min_value, max_value, candidate);
                if (valid) {
                    index = integer_to_index(min_value, max_value, shrink_towards, candidate);
                    index_cmp = signed_compare_le(index, prefix);
                    unprobed = (index_cmp >= @"i0");
                    if (unprobed) {
                        wanted = (seen == ordinal);
                        if (wanted) {
                            some = candidate;
                            return some;
                        }
                        seen = (seen +% @"u1");
                    }
                }
                side = (side +% @"u1");
            }
        }
        slot = (slot +% @"u1");
    }
    none = null;
    return none;
}

pub fn boolean_max_index() []u8 {
    var one: []u8 = undefined;
    one = bigint_one();
    return one;
}

pub fn boolean_to_index(value: bool) []u8 {
    var one: []u8 = undefined;
    var zero: []u8 = undefined;
    if (value) {
        one = bigint_one();
        return one;
    }
    zero = bigint_zero();
    return zero;
}

pub fn boolean_from_index(index: []const u8) ?bool {
    var @"i0": i64 = undefined;
    var zero: []u8 = undefined;
    var zero_cmp: i64 = undefined;
    var is_zero: bool = undefined;
    var false_: bool = undefined;
    var some_false: ?bool = undefined;
    var one: []u8 = undefined;
    var one_cmp: i64 = undefined;
    var is_one: bool = undefined;
    var true_: bool = undefined;
    var some_true: ?bool = undefined;
    var none: ?bool = undefined;
    @"i0" = 0;
    zero = bigint_zero();
    zero_cmp = signed_compare_le(index, zero);
    is_zero = (zero_cmp == @"i0");
    if (is_zero) {
        false_ = false;
        some_false = false_;
        return some_false;
    }
    one = bigint_one();
    one_cmp = signed_compare_le(index, one);
    is_one = (one_cmp == @"i0");
    if (is_one) {
        true_ = true;
        some_true = true_;
        return some_true;
    }
    none = null;
    return none;
}

pub fn bytes_simplest(min_size: i64) []u8 {
    var out: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    pos = @"i0";
    while (true) {
        done = (pos >= min_size);
        if (done) {
            break;
        }
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(@"u0");
        pos = (pos + @"i1");
    }
    return out;
}

pub fn bytes_unit(min_size: i64, max_size: i64) []u8 {
    var out: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var has_minimum: bool = undefined;
    var last_pos: i64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var is_last: bool = undefined;
    var byte_: u64 = undefined;
    var has_values: bool = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    has_minimum = (min_size > @"i0");
    if (has_minimum) {
        last_pos = (min_size - @"i1");
        pos = @"i0";
        while (true) {
            done = (pos >= min_size);
            if (done) {
                break;
            }
            is_last = (pos == last_pos);
            byte_ = @"u0";
            if (is_last) {
                byte_ = @"u1";
            }
            out = allocator.realloc(out, out.len + 1) catch unreachable;
            out[out.len - 1] = @truncate(byte_);
            pos = (pos + @"i1");
        }
        return out;
    }
    has_values = (max_size > @"i0");
    if (has_values) {
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(@"u1");
    }
    return out;
}

pub fn bytes_validate(min_size: i64, max_size: i64, value: []const u8) bool {
    var length: i64 = undefined;
    var above_min: bool = undefined;
    var below_max: bool = undefined;
    var valid: bool = undefined;
    length = @intCast(value.len);
    above_min = (length >= min_size);
    below_max = (length <= max_size);
    valid = (above_min and below_max);
    return valid;
}

pub fn bytes_to_index(min_size: i64, value: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var value_length: i64 = undefined;
    var last: i64 = undefined;
    var out: []u8 = undefined;
    var carry: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var mirror: i64 = undefined;
    var digit: u64 = undefined;
    var sum: u64 = undefined;
    var in_offset: bool = undefined;
    var out_byte: u64 = undefined;
    var index: []u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    @"u255" = 255;
    value_length = @intCast(value.len);
    last = (value_length - @"i1");
    out = allocator.alloc(u8, 0) catch unreachable;
    carry = @"u0";
    pos = @"i0";
    while (true) {
        done = (pos >= value_length);
        if (done) {
            break;
        }
        mirror = (last - pos);
        digit = @intCast(value[@intCast(mirror)]);
        sum = (digit +% carry);
        in_offset = (pos >= min_size);
        if (in_offset) {
            sum = (sum +% @"u1");
        }
        out_byte = (sum & @"u255");
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(out_byte);
        carry = (sum >> @intCast(@"u8"));
        pos = (pos + @"i1");
    }
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(carry);
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(@"u0");
    index = canonicalize_signed_le(out);
    return index;
}

pub fn bytes_max_index(min_size: i64, max_size: i64) []u8 {
    var last: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u255": u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var index: []u8 = undefined;
    last = allocator.alloc(u8, 0) catch unreachable;
    @"i0" = 0;
    @"i1" = 1;
    @"u255" = 255;
    pos = @"i0";
    while (true) {
        done = (pos >= max_size);
        if (done) {
            break;
        }
        last = allocator.realloc(last, last.len + 1) catch unreachable;
        last[last.len - 1] = @truncate(@"u255");
        pos = (pos + @"i1");
    }
    index = bytes_to_index(min_size, last);
    return index;
}

pub fn bytes_from_index(min_size: i64, max_size: i64, index_raw: []const u8) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"u256": u64 = undefined;
    var index: []u8 = undefined;
    var index_n: i64 = undefined;
    var significant: i64 = undefined;
    var none_left: bool = undefined;
    var top_pos: i64 = undefined;
    var top: u64 = undefined;
    var top_set: bool = undefined;
    var length: i64 = undefined;
    var past_min: bool = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var index_byte: u64 = undefined;
    var offset_byte: u64 = undefined;
    var in_offset: bool = undefined;
    var below: bool = undefined;
    var above: bool = undefined;
    var past_end: bool = undefined;
    var none: ?[]u8 = undefined;
    var low_first: []u8 = undefined;
    var borrow: u64 = undefined;
    var present: bool = undefined;
    var subtrahend: u64 = undefined;
    var lifted: u64 = undefined;
    var difference: u64 = undefined;
    var out_byte: u64 = undefined;
    var kept: u64 = undefined;
    var out: []u8 = undefined;
    var byte_: u64 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    @"u255" = 255;
    @"u256" = 256;
    index = signed_abs_le(index_raw);
    index_n = @intCast(index.len);
    significant = index_n;
    while (true) {
        none_left = (significant == @"i0");
        if (none_left) {
            break;
        }
        top_pos = (significant - @"i1");
        top = @intCast(index[@intCast(top_pos)]);
        top_set = (top != @"u0");
        if (top_set) {
            break;
        }
        significant = top_pos;
    }
    length = min_size;
    past_min = (significant > min_size);
    if (past_min) {
        length = significant;
        pos = significant;
        while (true) {
            done = (pos == @"i0");
            if (done) {
                break;
            }
            pos = (pos - @"i1");
            index_byte = @intCast(index[@intCast(pos)]);
            offset_byte = @"u0";
            in_offset = (pos >= min_size);
            if (in_offset) {
                offset_byte = @"u1";
            }
            below = (index_byte < offset_byte);
            if (below) {
                length = (significant - @"i1");
                break;
            }
            above = (index_byte > offset_byte);
            if (above) {
                break;
            }
        }
    }
    past_end = (length > max_size);
    if (past_end) {
        none = null;
        return none;
    }
    low_first = allocator.alloc(u8, 0) catch unreachable;
    borrow = @"u0";
    pos = @"i0";
    while (true) {
        done = (pos >= length);
        if (done) {
            break;
        }
        index_byte = @"u0";
        present = (pos < index_n);
        if (present) {
            index_byte = @intCast(index[@intCast(pos)]);
        }
        subtrahend = borrow;
        in_offset = (pos >= min_size);
        if (in_offset) {
            subtrahend = (subtrahend +% @"u1");
        }
        lifted = (index_byte +% @"u256");
        difference = (lifted -% subtrahend);
        out_byte = (difference & @"u255");
        low_first = allocator.realloc(low_first, low_first.len + 1) catch unreachable;
        low_first[low_first.len - 1] = @truncate(out_byte);
        kept = (difference >> @intCast(@"u8"));
        borrow = (@"u1" -% kept);
        pos = (pos + @"i1");
    }
    out = allocator.alloc(u8, 0) catch unreachable;
    pos = length;
    while (true) {
        done = (pos == @"i0");
        if (done) {
            break;
        }
        pos = (pos - @"i1");
        byte_ = @intCast(low_first[@intCast(pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
    }
    some = out;
    return some;
}

pub fn f64_abs(value: f64) f64 {
    var mask: u64 = undefined;
    var bits: u64 = undefined;
    var cleared: u64 = undefined;
    var out: f64 = undefined;
    mask = 9223372036854775807;
    bits = @bitCast(value);
    cleared = (bits & mask);
    out = @bitCast(cleared);
    return out;
}

pub fn f64_neg(value: f64) f64 {
    var mask: u64 = undefined;
    var bits: u64 = undefined;
    var flipped: u64 = undefined;
    var out: f64 = undefined;
    mask = 9223372036854775808;
    bits = @bitCast(value);
    flipped = (bits ^ mask);
    out = @bitCast(flipped);
    return out;
}

pub fn f64_infinity() f64 {
    var bits: u64 = undefined;
    var out: f64 = undefined;
    bits = 9218868437227405312;
    out = @bitCast(bits);
    return out;
}

pub fn f64_neg_infinity() f64 {
    var positive: f64 = undefined;
    var out: f64 = undefined;
    positive = f64_infinity();
    out = f64_neg(positive);
    return out;
}

pub fn f64_nan() f64 {
    var bits: u64 = undefined;
    var out: f64 = undefined;
    bits = 9221120237041090560;
    out = @bitCast(bits);
    return out;
}

pub fn f64_max() f64 {
    var bits: u64 = undefined;
    var out: f64 = undefined;
    bits = 9218868437227405311;
    out = @bitCast(bits);
    return out;
}

pub fn sign_aware_lte(left: f64, right: f64) bool {
    var zero: f64 = undefined;
    var left_zero: bool = undefined;
    var right_zero: bool = undefined;
    var both_zero: bool = undefined;
    var left_negative: bool = undefined;
    var right_negative: bool = undefined;
    var left_positive: bool = undefined;
    var only_right_negative: bool = undefined;
    var ordered: bool = undefined;
    zero = 0;
    left_zero = (left == zero);
    right_zero = (right == zero);
    both_zero = (left_zero and right_zero);
    if (both_zero) {
        left_negative = std.math.signbit(left);
        right_negative = std.math.signbit(right);
        left_positive = (!left_negative);
        only_right_negative = (left_positive and right_negative);
        ordered = (!only_right_negative);
        return ordered;
    }
    ordered = (left <= right);
    return ordered;
}

pub fn float_validate(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, value: f64) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var is_nan: bool = undefined;
    var is_infinite: bool = undefined;
    var no_infinity: bool = undefined;
    var negative_infinity: f64 = undefined;
    var is_negative_infinity: bool = undefined;
    var min_bounded: bool = undefined;
    var reject_low: bool = undefined;
    var positive_infinity: f64 = undefined;
    var is_positive_infinity: bool = undefined;
    var max_bounded: bool = undefined;
    var reject_high: bool = undefined;
    var zero: f64 = undefined;
    var nonzero: bool = undefined;
    var magnitude: f64 = undefined;
    var below_smallest: bool = undefined;
    var reject_tiny: bool = undefined;
    var above_min: bool = undefined;
    var below_max: bool = undefined;
    var valid: bool = undefined;
    false_ = false;
    true_ = true;
    is_nan = std.math.isNan(value);
    if (is_nan) {
        return allow_nan;
    }
    is_infinite = std.math.isInf(value);
    if (is_infinite) {
        no_infinity = (!allow_infinity);
        if (no_infinity) {
            return false_;
        }
        negative_infinity = f64_neg_infinity();
        is_negative_infinity = (value == negative_infinity);
        min_bounded = (min_value > negative_infinity);
        reject_low = (is_negative_infinity and min_bounded);
        if (reject_low) {
            return false_;
        }
        positive_infinity = f64_infinity();
        is_positive_infinity = (value == positive_infinity);
        max_bounded = (max_value < positive_infinity);
        reject_high = (is_positive_infinity and max_bounded);
        if (reject_high) {
            return false_;
        }
        return true_;
    }
    zero = 0;
    nonzero = (value != zero);
    magnitude = f64_abs(value);
    below_smallest = (magnitude < smallest_nonzero);
    reject_tiny = (nonzero and below_smallest);
    if (reject_tiny) {
        return false_;
    }
    above_min = sign_aware_lte(min_value, value);
    below_max = sign_aware_lte(value, max_value);
    valid = (above_min and below_max);
    return valid;
}

pub fn float_simplest(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64) ?f64 {
    var zero: f64 = undefined;
    var zero_ok: bool = undefined;
    var found: ?f64 = undefined;
    var negative_zero: f64 = undefined;
    var negative_zero_ok: bool = undefined;
    var has_best: bool = undefined;
    var best_index: u64 = undefined;
    var best_value: f64 = undefined;
    var largest: f64 = undefined;
    var max_positive: bool = undefined;
    var low: f64 = undefined;
    var min_below_smallest: bool = undefined;
    var high: f64 = undefined;
    var max_above_largest: bool = undefined;
    var ordered: bool = undefined;
    var candidate: f64 = undefined;
    var index: u64 = undefined;
    var min_negative: bool = undefined;
    var mirrored_low: f64 = undefined;
    var mirror_below_smallest: bool = undefined;
    var mirrored_high: f64 = undefined;
    var mirror_above_largest: bool = undefined;
    var no_best: bool = undefined;
    var strictly_lower: bool = undefined;
    var take: bool = undefined;
    var negated: f64 = undefined;
    var positive_infinity: f64 = undefined;
    var positive_ok: bool = undefined;
    var negative_infinity: f64 = undefined;
    var negative_ok: bool = undefined;
    var not_a_number: f64 = undefined;
    var missing: ?f64 = undefined;
    zero = 0;
    zero_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, zero);
    if (zero_ok) {
        found = zero;
        return found;
    }
    negative_zero = f64_neg(zero);
    negative_zero_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, negative_zero);
    if (negative_zero_ok) {
        found = negative_zero;
        return found;
    }
    has_best = false;
    best_index = 0;
    best_value = zero;
    largest = f64_max();
    max_positive = (max_value > zero);
    if (max_positive) {
        low = min_value;
        min_below_smallest = (min_value < smallest_nonzero);
        if (min_below_smallest) {
            low = smallest_nonzero;
        }
        high = max_value;
        max_above_largest = (max_value > largest);
        if (max_above_largest) {
            high = largest;
        }
        ordered = (low <= high);
        if (ordered) {
            candidate = simplest_in_range(low, high);
            index = float_to_index(candidate);
            has_best = true;
            best_index = index;
            best_value = candidate;
        }
    }
    min_negative = (min_value < zero);
    if (min_negative) {
        mirrored_low = f64_neg(max_value);
        low = mirrored_low;
        mirror_below_smallest = (mirrored_low < smallest_nonzero);
        if (mirror_below_smallest) {
            low = smallest_nonzero;
        }
        mirrored_high = f64_neg(min_value);
        high = mirrored_high;
        mirror_above_largest = (mirrored_high > largest);
        if (mirror_above_largest) {
            high = largest;
        }
        ordered = (low <= high);
        if (ordered) {
            candidate = simplest_in_range(low, high);
            index = float_to_index(candidate);
            no_best = (!has_best);
            strictly_lower = (index < best_index);
            take = (no_best or strictly_lower);
            if (take) {
                negated = f64_neg(candidate);
                has_best = true;
                best_index = index;
                best_value = negated;
            }
        }
    }
    if (has_best) {
        found = best_value;
        return found;
    }
    if (allow_infinity) {
        positive_infinity = f64_infinity();
        positive_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, positive_infinity);
        if (positive_ok) {
            found = positive_infinity;
            return found;
        }
        negative_infinity = f64_neg_infinity();
        negative_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, negative_infinity);
        if (negative_ok) {
            found = negative_infinity;
            return found;
        }
    }
    if (allow_nan) {
        not_a_number = f64_nan();
        found = not_a_number;
        return found;
    }
    missing = null;
    return missing;
}

pub fn float_unit(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64) ?f64 {
    var simplest_opt: ?f64 = undefined;
    var present: bool = undefined;
    var absent: bool = undefined;
    var missing: ?f64 = undefined;
    var simplest: f64 = undefined;
    var simplest_is_nan: bool = undefined;
    var found: ?f64 = undefined;
    var @"u1": u64 = undefined;
    var @"u4": u64 = undefined;
    var magnitude: f64 = undefined;
    var base: u64 = undefined;
    var offset: u64 = undefined;
    var exhausted: bool = undefined;
    var index: u64 = undefined;
    var positive: f64 = undefined;
    var positive_is_nan: bool = undefined;
    var positive_finite: bool = undefined;
    var positive_ok: bool = undefined;
    var take_positive: bool = undefined;
    var negative: f64 = undefined;
    var negative_is_nan: bool = undefined;
    var negative_finite: bool = undefined;
    var negative_ok: bool = undefined;
    var take_negative: bool = undefined;
    var simplest_bits: u64 = undefined;
    var min_is_nan: bool = undefined;
    var min_finite: bool = undefined;
    var min_bits: u64 = undefined;
    var min_distinct: bool = undefined;
    var min_ok: bool = undefined;
    var min_usable: bool = undefined;
    var take_min: bool = undefined;
    var max_is_nan: bool = undefined;
    var max_finite: bool = undefined;
    var max_bits: u64 = undefined;
    var max_distinct: bool = undefined;
    var max_ok: bool = undefined;
    var max_usable: bool = undefined;
    var take_max: bool = undefined;
    var mirrored: f64 = undefined;
    var mirrored_is_nan: bool = undefined;
    var mirrored_finite: bool = undefined;
    var mirrored_bits: u64 = undefined;
    var mirrored_distinct: bool = undefined;
    var mirrored_ok: bool = undefined;
    var mirrored_usable: bool = undefined;
    var take_mirrored: bool = undefined;
    simplest_opt = float_simplest(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero);
    present = simplest_opt != null;
    absent = (!present);
    if (absent) {
        missing = null;
        return missing;
    }
    simplest = simplest_opt.?;
    simplest_is_nan = std.math.isNan(simplest);
    if (simplest_is_nan) {
        found = simplest;
        return found;
    }
    @"u1" = 1;
    @"u4" = 4;
    magnitude = f64_abs(simplest);
    base = float_to_index(magnitude);
    offset = @"u1";
    while (true) {
        exhausted = (offset >= @"u4");
        if (exhausted) {
            break;
        }
        index = (base +% offset);
        positive = index_to_float(index);
        positive_is_nan = std.math.isNan(positive);
        positive_finite = (!positive_is_nan);
        positive_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, positive);
        take_positive = (positive_finite and positive_ok);
        if (take_positive) {
            found = positive;
            return found;
        }
        negative = f64_neg(positive);
        negative_is_nan = std.math.isNan(negative);
        negative_finite = (!negative_is_nan);
        negative_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, negative);
        take_negative = (negative_finite and negative_ok);
        if (take_negative) {
            found = negative;
            return found;
        }
        offset = (offset +% @"u1");
    }
    simplest_bits = @bitCast(simplest);
    min_is_nan = std.math.isNan(min_value);
    min_finite = (!min_is_nan);
    min_bits = @bitCast(min_value);
    min_distinct = (min_bits != simplest_bits);
    min_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, min_value);
    min_usable = (min_finite and min_distinct);
    take_min = (min_usable and min_ok);
    if (take_min) {
        found = min_value;
        return found;
    }
    max_is_nan = std.math.isNan(max_value);
    max_finite = (!max_is_nan);
    max_bits = @bitCast(max_value);
    max_distinct = (max_bits != simplest_bits);
    max_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, max_value);
    max_usable = (max_finite and max_distinct);
    take_max = (max_usable and max_ok);
    if (take_max) {
        found = max_value;
        return found;
    }
    mirrored = f64_neg(simplest);
    mirrored_is_nan = std.math.isNan(mirrored);
    mirrored_finite = (!mirrored_is_nan);
    mirrored_bits = @bitCast(mirrored);
    mirrored_distinct = (mirrored_bits != simplest_bits);
    mirrored_ok = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, mirrored);
    mirrored_usable = (mirrored_finite and mirrored_distinct);
    take_mirrored = (mirrored_usable and mirrored_ok);
    if (take_mirrored) {
        found = mirrored;
        return found;
    }
    found = simplest;
    return found;
}

pub fn u64_to_bigint_le(value: u64) []u8 {
    var out: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i8": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var shift: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var shifted: u64 = undefined;
    var byte_: u64 = undefined;
    var canonical: []u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"i0" = 0;
    @"i1" = 1;
    @"i8" = 8;
    @"u0" = 0;
    @"u8" = 8;
    @"u255" = 255;
    shift = @"u0";
    pos = @"i0";
    while (true) {
        done = (pos >= @"i8");
        if (done) {
            break;
        }
        shifted = (value >> @intCast(shift));
        byte_ = (shifted & @"u255");
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        shift = (shift +% @"u8");
        pos = (pos + @"i1");
    }
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(@"u0");
    canonical = canonicalize_signed_le(out);
    return canonical;
}

pub fn bigint_to_u64_le(value: []const u8) ?u64 {
    var canonical: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i8": i64 = undefined;
    var @"i9": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u128": u64 = undefined;
    var length: i64 = undefined;
    var last_pos: i64 = undefined;
    var last: u64 = undefined;
    var sign_bit: u64 = undefined;
    var negative: bool = undefined;
    var none: ?u64 = undefined;
    var too_wide: bool = undefined;
    var at_limit: bool = undefined;
    var top: u64 = undefined;
    var magnitude_in_top: bool = undefined;
    var accumulator: u64 = undefined;
    var shift: u64 = undefined;
    var pos: i64 = undefined;
    var past_width: bool = undefined;
    var past_end: bool = undefined;
    var byte_: u64 = undefined;
    var shifted: u64 = undefined;
    var found: ?u64 = undefined;
    canonical = canonicalize_signed_le(value);
    @"i0" = 0;
    @"i1" = 1;
    @"i8" = 8;
    @"i9" = 9;
    @"u0" = 0;
    @"u8" = 8;
    @"u128" = 128;
    length = @intCast(canonical.len);
    last_pos = (length - @"i1");
    last = @intCast(canonical[@intCast(last_pos)]);
    sign_bit = (last & @"u128");
    negative = (sign_bit != @"u0");
    if (negative) {
        none = null;
        return none;
    }
    too_wide = (length > @"i9");
    if (too_wide) {
        none = null;
        return none;
    }
    at_limit = (length == @"i9");
    if (at_limit) {
        top = @intCast(canonical[@intCast(@"i8")]);
        magnitude_in_top = (top != @"u0");
        if (magnitude_in_top) {
            none = null;
            return none;
        }
    }
    accumulator = @"u0";
    shift = @"u0";
    pos = @"i0";
    while (true) {
        past_width = (pos >= @"i8");
        if (past_width) {
            break;
        }
        past_end = (pos >= length);
        if (past_end) {
            break;
        }
        byte_ = @intCast(canonical[@intCast(pos)]);
        shifted = (byte_ << @intCast(shift));
        accumulator = (accumulator | shifted);
        shift = (shift +% @"u8");
        pos = (pos + @"i1");
    }
    found = accumulator;
    return found;
}

pub fn max_finite_global_rank() []u8 {
    var max_finite_lex: u64 = undefined;
    var lex: []u8 = undefined;
    var two: []u8 = undefined;
    var one: []u8 = undefined;
    var doubled: []u8 = undefined;
    var rank: []u8 = undefined;
    max_finite_lex = 18442240474082181119;
    lex = u64_to_bigint_le(max_finite_lex);
    two = bigint_two();
    one = bigint_one();
    doubled = signed_mul_le(lex, two);
    rank = signed_add_le(doubled, one);
    return rank;
}

pub fn float_global_rank(value: f64) []u8 {
    var one: []u8 = undefined;
    var two: []u8 = undefined;
    var is_nan: bool = undefined;
    var mantissa_mask: u64 = undefined;
    var quiet_bit: u64 = undefined;
    var @"u63": u64 = undefined;
    var bits: u64 = undefined;
    var mantissa: u64 = undefined;
    var nan_offset: u64 = undefined;
    var sign: u64 = undefined;
    var base: []u8 = undefined;
    var three: []u8 = undefined;
    var offset_big: []u8 = undefined;
    var sign_big: []u8 = undefined;
    var spread: []u8 = undefined;
    var with_base: []u8 = undefined;
    var with_offset: []u8 = undefined;
    var rank: []u8 = undefined;
    var is_infinite: bool = undefined;
    var zero: f64 = undefined;
    var positive: bool = undefined;
    var negative: bool = undefined;
    var magnitude: f64 = undefined;
    var lex: u64 = undefined;
    var lex_big: []u8 = undefined;
    var doubled: []u8 = undefined;
    one = bigint_one();
    two = bigint_two();
    is_nan = std.math.isNan(value);
    if (is_nan) {
        mantissa_mask = 4503599627370495;
        quiet_bit = 2251799813685248;
        @"u63" = 63;
        bits = @bitCast(value);
        mantissa = (bits & mantissa_mask);
        nan_offset = (mantissa ^ quiet_bit);
        sign = (bits >> @intCast(@"u63"));
        base = max_finite_global_rank();
        three = signed_add_le(two, one);
        offset_big = u64_to_bigint_le(nan_offset);
        sign_big = u64_to_bigint_le(sign);
        spread = signed_mul_le(offset_big, two);
        with_base = signed_add_le(base, three);
        with_offset = signed_add_le(with_base, spread);
        rank = signed_add_le(with_offset, sign_big);
        return rank;
    }
    is_infinite = std.math.isInf(value);
    if (is_infinite) {
        zero = 0;
        base = max_finite_global_rank();
        positive = (value > zero);
        if (positive) {
            rank = signed_add_le(base, one);
            return rank;
        }
        rank = signed_add_le(base, two);
        return rank;
    }
    negative = std.math.signbit(value);
    magnitude = f64_abs(value);
    lex = float_to_index(magnitude);
    lex_big = u64_to_bigint_le(lex);
    doubled = signed_mul_le(lex_big, two);
    sign_big = bigint_zero();
    if (negative) {
        sign_big = bigint_one();
    }
    rank = signed_add_le(doubled, sign_big);
    return rank;
}

pub fn float_from_global_rank(rank: []const u8) ?f64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u52": u64 = undefined;
    var @"u56": u64 = undefined;
    var @"u63": u64 = undefined;
    var one: []u8 = undefined;
    var two: []u8 = undefined;
    var max_finite: []u8 = undefined;
    var ordering: i64 = undefined;
    var beyond_finite: bool = undefined;
    var offset: []u8 = undefined;
    var is_positive_infinity: i64 = undefined;
    var positive_infinity_slot: bool = undefined;
    var infinity: f64 = undefined;
    var found: ?f64 = undefined;
    var is_negative_infinity: i64 = undefined;
    var negative_infinity_slot: bool = undefined;
    var negative_infinity: f64 = undefined;
    var three: []u8 = undefined;
    var nan_relative: []u8 = undefined;
    var sign_big: []u8 = undefined;
    var mantissa_big: []u8 = undefined;
    var mantissa_opt: ?u64 = undefined;
    var mantissa_fits: bool = undefined;
    var mantissa_too_wide: bool = undefined;
    var none: ?f64 = undefined;
    var mantissa_base: u64 = undefined;
    var overflow: u64 = undefined;
    var overflows: bool = undefined;
    var quiet_bit: u64 = undefined;
    var exponent_bits: u64 = undefined;
    var mantissa: u64 = undefined;
    var sign_opt: ?u64 = undefined;
    var sign: u64 = undefined;
    var sign_shifted: u64 = undefined;
    var with_exponent: u64 = undefined;
    var bits: u64 = undefined;
    var candidate: f64 = undefined;
    var candidate_is_nan: bool = undefined;
    var negative_big: []u8 = undefined;
    var magnitude_big: []u8 = undefined;
    var magnitude_opt: ?u64 = undefined;
    var magnitude_fits: bool = undefined;
    var magnitude_too_wide: bool = undefined;
    var lex: u64 = undefined;
    var simple_flag: u64 = undefined;
    var simple: bool = undefined;
    var high_bits: u64 = undefined;
    var too_large_for_simple: bool = undefined;
    var unreachable_: bool = undefined;
    var magnitude: f64 = undefined;
    var negative: bool = undefined;
    var mirrored: f64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u52" = 52;
    @"u56" = 56;
    @"u63" = 63;
    one = bigint_one();
    two = bigint_two();
    max_finite = max_finite_global_rank();
    ordering = signed_compare_le(rank, max_finite);
    beyond_finite = (ordering == @"i1");
    if (beyond_finite) {
        offset = signed_sub_le(rank, max_finite);
        is_positive_infinity = signed_compare_le(offset, one);
        positive_infinity_slot = (is_positive_infinity == @"i0");
        if (positive_infinity_slot) {
            infinity = f64_infinity();
            found = infinity;
            return found;
        }
        is_negative_infinity = signed_compare_le(offset, two);
        negative_infinity_slot = (is_negative_infinity == @"i0");
        if (negative_infinity_slot) {
            negative_infinity = f64_neg_infinity();
            found = negative_infinity;
            return found;
        }
        three = signed_add_le(two, one);
        nan_relative = signed_sub_le(offset, three);
        sign_big = positive_rem_le_nonzero(nan_relative, two);
        mantissa_big = positive_div_le_nonzero(nan_relative, two);
        mantissa_opt = bigint_to_u64_le(mantissa_big);
        mantissa_fits = mantissa_opt != null;
        mantissa_too_wide = (!mantissa_fits);
        if (mantissa_too_wide) {
            none = null;
            return none;
        }
        mantissa_base = mantissa_opt.?;
        overflow = (mantissa_base >> @intCast(@"u52"));
        overflows = (overflow != @"u0");
        if (overflows) {
            none = null;
            return none;
        }
        quiet_bit = 2251799813685248;
        exponent_bits = 9218868437227405312;
        mantissa = (mantissa_base ^ quiet_bit);
        sign_opt = bigint_to_u64_le(sign_big);
        sign = sign_opt.?;
        sign_shifted = (sign << @intCast(@"u63"));
        with_exponent = (sign_shifted | exponent_bits);
        bits = (with_exponent | mantissa);
        candidate = @bitCast(bits);
        candidate_is_nan = std.math.isNan(candidate);
        if (candidate_is_nan) {
            found = candidate;
            return found;
        }
        none = null;
        return none;
    }
    negative_big = positive_rem_le_nonzero(rank, two);
    magnitude_big = positive_div_le_nonzero(rank, two);
    magnitude_opt = bigint_to_u64_le(magnitude_big);
    magnitude_fits = magnitude_opt != null;
    magnitude_too_wide = (!magnitude_fits);
    if (magnitude_too_wide) {
        none = null;
        return none;
    }
    lex = magnitude_opt.?;
    simple_flag = (lex >> @intCast(@"u63"));
    simple = (simple_flag == @"u0");
    high_bits = (lex >> @intCast(@"u56"));
    too_large_for_simple = (high_bits != @"u0");
    unreachable_ = (simple and too_large_for_simple);
    if (unreachable_) {
        none = null;
        return none;
    }
    magnitude = index_to_float(lex);
    sign_opt = bigint_to_u64_le(negative_big);
    sign = sign_opt.?;
    negative = (sign == @"u1");
    if (negative) {
        mirrored = f64_neg(magnitude);
        found = mirrored;
        return found;
    }
    found = magnitude;
    return found;
}

pub fn float_choice_max_index() []u8 {
    var nan_payloads: u64 = undefined;
    var base: []u8 = undefined;
    var two: []u8 = undefined;
    var payloads: []u8 = undefined;
    var with_infinities: []u8 = undefined;
    var max_index: []u8 = undefined;
    nan_payloads = 9007199254740992;
    base = max_finite_global_rank();
    two = bigint_two();
    payloads = u64_to_bigint_le(nan_payloads);
    with_infinities = signed_add_le(base, two);
    max_index = signed_add_le(with_infinities, payloads);
    return max_index;
}

pub fn float_choice_to_index(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, value: f64) ?[]u8 {
    var simplest_opt: ?f64 = undefined;
    var present: bool = undefined;
    var absent: bool = undefined;
    var none: ?[]u8 = undefined;
    var simplest: f64 = undefined;
    var value_rank: []u8 = undefined;
    var simplest_rank: []u8 = undefined;
    var index: []u8 = undefined;
    var found: ?[]u8 = undefined;
    simplest_opt = float_simplest(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero);
    present = simplest_opt != null;
    absent = (!present);
    if (absent) {
        none = null;
        return none;
    }
    simplest = simplest_opt.?;
    value_rank = float_global_rank(value);
    simplest_rank = float_global_rank(simplest);
    index = signed_sub_le(value_rank, simplest_rank);
    found = index;
    return found;
}

pub fn float_choice_from_index(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, index: []const u8) ?f64 {
    var simplest_opt: ?f64 = undefined;
    var present: bool = undefined;
    var absent: bool = undefined;
    var none: ?f64 = undefined;
    var simplest: f64 = undefined;
    var simplest_rank: []u8 = undefined;
    var raw: []u8 = undefined;
    var @"i0": i64 = undefined;
    var zero: []u8 = undefined;
    var ordering: i64 = undefined;
    var below_zero: bool = undefined;
    var candidate_opt: ?f64 = undefined;
    var decoded: bool = undefined;
    var undecodable: bool = undefined;
    var candidate: f64 = undefined;
    var valid: bool = undefined;
    var found: ?f64 = undefined;
    simplest_opt = float_simplest(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero);
    present = simplest_opt != null;
    absent = (!present);
    if (absent) {
        none = null;
        return none;
    }
    simplest = simplest_opt.?;
    simplest_rank = float_global_rank(simplest);
    raw = signed_add_le(simplest_rank, index);
    @"i0" = 0;
    zero = bigint_zero();
    ordering = signed_compare_le(raw, zero);
    below_zero = (ordering < @"i0");
    if (below_zero) {
        none = null;
        return none;
    }
    candidate_opt = float_from_global_rank(raw);
    decoded = candidate_opt != null;
    undecodable = (!decoded);
    if (undecodable) {
        none = null;
        return none;
    }
    candidate = candidate_opt.?;
    valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, candidate);
    if (valid) {
        found = candidate;
        return found;
    }
    none = null;
    return none;
}

pub fn code_length_counts(lengths: []const u8, max_bits: u64) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var counts: []u8 = undefined;
    var max_bits_i: i64 = undefined;
    var slots: i64 = undefined;
    var width: i64 = undefined;
    var fill: i64 = undefined;
    var filled: bool = undefined;
    var n: i64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var length: u64 = undefined;
    var unused: bool = undefined;
    var too_long: bool = undefined;
    var skip: bool = undefined;
    var countable: bool = undefined;
    var length_i: i64 = undefined;
    var offset: i64 = undefined;
    var high_offset: i64 = undefined;
    var low: u64 = undefined;
    var high: u64 = undefined;
    var shifted: u64 = undefined;
    var current: u64 = undefined;
    var next_: u64 = undefined;
    var next_low: u64 = undefined;
    var next_shifted: u64 = undefined;
    var next_high: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    @"u255" = 255;
    counts = allocator.alloc(u8, 0) catch unreachable;
    max_bits_i = @bitCast(max_bits);
    slots = (max_bits_i + @"i1");
    width = (slots * @"i2");
    fill = @"i0";
    while (true) {
        filled = (fill >= width);
        if (filled) {
            break;
        }
        counts = allocator.realloc(counts, counts.len + 1) catch unreachable;
        counts[counts.len - 1] = @truncate(@"u0");
        fill = (fill + @"i1");
    }
    n = @intCast(lengths.len);
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        length = @intCast(lengths[@intCast(pos)]);
        unused = (length == @"u0");
        too_long = (length > max_bits);
        skip = (unused or too_long);
        countable = (!skip);
        if (countable) {
            length_i = @bitCast(length);
            offset = (length_i * @"i2");
            high_offset = (offset + @"i1");
            low = @intCast(counts[@intCast(offset)]);
            high = @intCast(counts[@intCast(high_offset)]);
            shifted = (high << @intCast(@"u8"));
            current = (low | shifted);
            next_ = (current +% @"u1");
            next_low = (next_ & @"u255");
            next_shifted = (next_ >> @intCast(@"u8"));
            next_high = (next_shifted & @"u255");
            counts[@intCast(offset)] = @truncate(next_low);
            counts[@intCast(high_offset)] = @truncate(next_high);
        }
        pos = (pos + @"i1");
    }
    return counts;
}

pub fn packed_u16_at(packed_: []const u8, slot: u64) u64 {
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var n: i64 = undefined;
    var slot_i: i64 = undefined;
    var offset: i64 = undefined;
    var high_offset: i64 = undefined;
    var past_end: bool = undefined;
    var low: u64 = undefined;
    var high: u64 = undefined;
    var shifted: u64 = undefined;
    var value: u64 = undefined;
    @"i1" = 1;
    @"i2" = 2;
    @"u0" = 0;
    @"u8" = 8;
    n = @intCast(packed_.len);
    slot_i = @bitCast(slot);
    offset = (slot_i * @"i2");
    high_offset = (offset + @"i1");
    past_end = (high_offset >= n);
    if (past_end) {
        return @"u0";
    }
    low = @intCast(packed_[@intCast(offset)]);
    high = @intCast(packed_[@intCast(high_offset)]);
    shifted = (high << @intCast(@"u8"));
    value = (low | shifted);
    return value;
}

pub fn code_length_count_at(counts: []const u8, length: u64) u64 {
    var value: u64 = undefined;
    value = packed_u16_at(counts, length);
    return value;
}

pub fn code_lengths_valid(lengths: []const u8, max_bits: u64) bool {
    var @"u1": u64 = undefined;
    var true_: bool = undefined;
    var false_: bool = undefined;
    var counts: []u8 = undefined;
    var left: u64 = undefined;
    var length: u64 = undefined;
    var done: bool = undefined;
    var doubled: u64 = undefined;
    var count: u64 = undefined;
    var over: bool = undefined;
    @"u1" = 1;
    true_ = true;
    false_ = false;
    counts = code_length_counts(lengths, max_bits);
    left = @"u1";
    length = @"u1";
    while (true) {
        done = (length > max_bits);
        if (done) {
            break;
        }
        doubled = (left +% left);
        count = code_length_count_at(counts, length);
        over = (count > doubled);
        if (over) {
            return false_;
        }
        left = (doubled -% count);
        length = (length +% @"u1");
    }
    return true_;
}

pub fn read_bits(data: []const u8, bit_pos: u64, count: u64) ?u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u64": u64 = undefined;
    var too_wide: bool = undefined;
    var none: ?u64 = undefined;
    var n: i64 = undefined;
    var n_u: u64 = undefined;
    var available: u64 = undefined;
    var end_: u64 = undefined;
    var past_end: bool = undefined;
    var value: u64 = undefined;
    var taken: u64 = undefined;
    var done: bool = undefined;
    var at: u64 = undefined;
    var byte_index: u64 = undefined;
    var byte_offset: i64 = undefined;
    var byte_: u64 = undefined;
    var bit_index: u64 = undefined;
    var shifted: u64 = undefined;
    var bit: u64 = undefined;
    var placed: u64 = undefined;
    var some: ?u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u3" = 3;
    @"u7" = 7;
    @"u8" = 8;
    @"u64" = 64;
    too_wide = (count > @"u64");
    if (too_wide) {
        none = null;
        return none;
    }
    n = @intCast(data.len);
    n_u = @bitCast(n);
    available = (n_u *% @"u8");
    end_ = (bit_pos +% count);
    past_end = (end_ > available);
    if (past_end) {
        none = null;
        return none;
    }
    value = @"u0";
    taken = @"u0";
    while (true) {
        done = (taken >= count);
        if (done) {
            break;
        }
        at = (bit_pos +% taken);
        byte_index = (at >> @intCast(@"u3"));
        byte_offset = @bitCast(byte_index);
        byte_ = @intCast(data[@intCast(byte_offset)]);
        bit_index = (at & @"u7");
        shifted = (byte_ >> @intCast(bit_index));
        bit = (shifted & @"u1");
        placed = (bit << @intCast(taken));
        value = (value | placed);
        taken = (taken +% @"u1");
    }
    some = value;
    return some;
}

pub fn symbol_offsets(counts: []const u8, max_bits: u64) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var offsets: []u8 = undefined;
    var max_bits_i: i64 = undefined;
    var slots: i64 = undefined;
    var width: i64 = undefined;
    var fill: i64 = undefined;
    var filled: bool = undefined;
    var running: u64 = undefined;
    var length: u64 = undefined;
    var done: bool = undefined;
    var length_i: i64 = undefined;
    var offset: i64 = undefined;
    var high_offset: i64 = undefined;
    var low: u64 = undefined;
    var shifted: u64 = undefined;
    var high: u64 = undefined;
    var count: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    @"u255" = 255;
    offsets = allocator.alloc(u8, 0) catch unreachable;
    max_bits_i = @bitCast(max_bits);
    slots = (max_bits_i + @"i2");
    width = (slots * @"i2");
    fill = @"i0";
    while (true) {
        filled = (fill >= width);
        if (filled) {
            break;
        }
        offsets = allocator.realloc(offsets, offsets.len + 1) catch unreachable;
        offsets[offsets.len - 1] = @truncate(@"u0");
        fill = (fill + @"i1");
    }
    running = @"u0";
    length = @"u1";
    while (true) {
        done = (length > max_bits);
        if (done) {
            break;
        }
        length_i = @bitCast(length);
        offset = (length_i * @"i2");
        high_offset = (offset + @"i1");
        low = (running & @"u255");
        shifted = (running >> @intCast(@"u8"));
        high = (shifted & @"u255");
        offsets[@intCast(offset)] = @truncate(low);
        offsets[@intCast(high_offset)] = @truncate(high);
        count = code_length_count_at(counts, length);
        running = (running +% count);
        length = (length +% @"u1");
    }
    return offsets;
}

pub fn sorted_symbols(lengths: []const u8, max_bits: u64) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var counts: []u8 = undefined;
    var offsets: []u8 = undefined;
    var coded: u64 = undefined;
    var length: u64 = undefined;
    var done: bool = undefined;
    var count: u64 = undefined;
    var symbols: []u8 = undefined;
    var coded_i: i64 = undefined;
    var width: i64 = undefined;
    var fill: i64 = undefined;
    var filled: bool = undefined;
    var cursor: []u8 = undefined;
    var n: i64 = undefined;
    var symbol: i64 = undefined;
    var unused: bool = undefined;
    var too_long: bool = undefined;
    var skip: bool = undefined;
    var placeable: bool = undefined;
    var slot: u64 = undefined;
    var length_i: i64 = undefined;
    var cursor_offset: i64 = undefined;
    var cursor_high: i64 = undefined;
    var next_: u64 = undefined;
    var next_low: u64 = undefined;
    var next_shifted: u64 = undefined;
    var next_high: u64 = undefined;
    var slot_i: i64 = undefined;
    var slot_offset: i64 = undefined;
    var slot_high: i64 = undefined;
    var symbol_u: u64 = undefined;
    var sym_low: u64 = undefined;
    var sym_shifted: u64 = undefined;
    var sym_high: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    @"u255" = 255;
    counts = code_length_counts(lengths, max_bits);
    offsets = symbol_offsets(counts, max_bits);
    coded = @"u0";
    length = @"u1";
    while (true) {
        done = (length > max_bits);
        if (done) {
            break;
        }
        count = code_length_count_at(counts, length);
        coded = (coded +% count);
        length = (length +% @"u1");
    }
    symbols = allocator.alloc(u8, 0) catch unreachable;
    coded_i = @bitCast(coded);
    width = (coded_i * @"i2");
    fill = @"i0";
    while (true) {
        filled = (fill >= width);
        if (filled) {
            break;
        }
        symbols = allocator.realloc(symbols, symbols.len + 1) catch unreachable;
        symbols[symbols.len - 1] = @truncate(@"u0");
        fill = (fill + @"i1");
    }
    cursor = allocator.dupe(u8, offsets) catch unreachable;
    n = @intCast(lengths.len);
    symbol = @"i0";
    while (true) {
        done = (symbol >= n);
        if (done) {
            break;
        }
        length = @intCast(lengths[@intCast(symbol)]);
        unused = (length == @"u0");
        too_long = (length > max_bits);
        skip = (unused or too_long);
        placeable = (!skip);
        if (placeable) {
            slot = code_length_count_at(cursor, length);
            length_i = @bitCast(length);
            cursor_offset = (length_i * @"i2");
            cursor_high = (cursor_offset + @"i1");
            next_ = (slot +% @"u1");
            next_low = (next_ & @"u255");
            next_shifted = (next_ >> @intCast(@"u8"));
            next_high = (next_shifted & @"u255");
            cursor[@intCast(cursor_offset)] = @truncate(next_low);
            cursor[@intCast(cursor_high)] = @truncate(next_high);
            slot_i = @bitCast(slot);
            slot_offset = (slot_i * @"i2");
            slot_high = (slot_offset + @"i1");
            symbol_u = @bitCast(symbol);
            sym_low = (symbol_u & @"u255");
            sym_shifted = (symbol_u >> @intCast(@"u8"));
            sym_high = (sym_shifted & @"u255");
            symbols[@intCast(slot_offset)] = @truncate(sym_low);
            symbols[@intCast(slot_high)] = @truncate(sym_high);
        }
        symbol = (symbol + @"i1");
    }
    return symbols;
}

pub fn huffman_decode(data: []const u8, bit_pos: u64, counts: []const u8, symbols: []const u8, max_bits: u64) ?u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u32": u64 = undefined;
    var code: u64 = undefined;
    var first: u64 = undefined;
    var index: u64 = undefined;
    var length: u64 = undefined;
    var done: bool = undefined;
    var at: u64 = undefined;
    var bit_at: u64 = undefined;
    var bit: ?u64 = undefined;
    var have_bit: bool = undefined;
    var truncated: bool = undefined;
    var none: ?u64 = undefined;
    var bit_value: u64 = undefined;
    var count: u64 = undefined;
    var span: u64 = undefined;
    var within: bool = undefined;
    var rank: u64 = undefined;
    var slot: u64 = undefined;
    var symbol: u64 = undefined;
    var shifted_len: u64 = undefined;
    var packed_: u64 = undefined;
    var some: ?u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u32" = 32;
    code = @"u0";
    first = @"u0";
    index = @"u0";
    length = @"u1";
    while (true) {
        done = (length > max_bits);
        if (done) {
            break;
        }
        at = (length -% @"u1");
        bit_at = (bit_pos +% at);
        bit = read_bits(data, bit_at, @"u1");
        have_bit = bit != null;
        truncated = (!have_bit);
        if (truncated) {
            none = null;
            return none;
        }
        bit_value = bit.?;
        code = (code | bit_value);
        count = code_length_count_at(counts, length);
        span = (first +% count);
        within = (code < span);
        if (within) {
            rank = (code -% first);
            slot = (index +% rank);
            symbol = packed_u16_at(symbols, slot);
            shifted_len = (length << @intCast(@"u32"));
            packed_ = (shifted_len | symbol);
            some = packed_;
            return some;
        }
        index = (index +% count);
        first = (span +% span);
        code = (code +% code);
        length = (length +% @"u1");
    }
    none = null;
    return none;
}

pub fn length_base(symbol: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u254": u64 = undefined;
    var @"u257": u64 = undefined;
    var @"u261": u64 = undefined;
    var @"u264": u64 = undefined;
    var @"u265": u64 = undefined;
    var @"u285": u64 = undefined;
    var @"u258": u64 = undefined;
    var below: bool = undefined;
    var above: bool = undefined;
    var outside: bool = undefined;
    var is_max: bool = undefined;
    var flat: bool = undefined;
    var base: u64 = undefined;
    var extra_index: u64 = undefined;
    var extra: u64 = undefined;
    var step: u64 = undefined;
    var within: u64 = undefined;
    var mantissa: u64 = undefined;
    var scaled: u64 = undefined;
    @"u0" = 0;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u254" = 254;
    @"u257" = 257;
    @"u261" = 261;
    @"u264" = 264;
    @"u265" = 265;
    @"u285" = 285;
    @"u258" = 258;
    below = (symbol < @"u257");
    above = (symbol > @"u285");
    outside = (below or above);
    if (outside) {
        return @"u0";
    }
    is_max = (symbol == @"u285");
    if (is_max) {
        return @"u258";
    }
    flat = (symbol <= @"u264");
    if (flat) {
        base = (symbol -% @"u254");
        return base;
    }
    extra_index = (symbol -% @"u261");
    extra = (extra_index >> @intCast(@"u2"));
    step = (symbol -% @"u265");
    within = (step & @"u3");
    mantissa = (within +% @"u4");
    scaled = (mantissa << @intCast(extra));
    base = (scaled +% @"u3");
    return base;
}

pub fn length_extra(symbol: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u257": u64 = undefined;
    var @"u261": u64 = undefined;
    var @"u264": u64 = undefined;
    var @"u285": u64 = undefined;
    var below: bool = undefined;
    var above: bool = undefined;
    var outside: bool = undefined;
    var is_max: bool = undefined;
    var flat: bool = undefined;
    var extra_index: u64 = undefined;
    var extra: u64 = undefined;
    @"u0" = 0;
    @"u2" = 2;
    @"u257" = 257;
    @"u261" = 261;
    @"u264" = 264;
    @"u285" = 285;
    below = (symbol < @"u257");
    above = (symbol > @"u285");
    outside = (below or above);
    if (outside) {
        return @"u0";
    }
    is_max = (symbol == @"u285");
    if (is_max) {
        return @"u0";
    }
    flat = (symbol <= @"u264");
    if (flat) {
        return @"u0";
    }
    extra_index = (symbol -% @"u261");
    extra = (extra_index >> @intCast(@"u2"));
    return extra;
}

pub fn distance_base(symbol: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u29": u64 = undefined;
    var above: bool = undefined;
    var flat: bool = undefined;
    var base: u64 = undefined;
    var extra_index: u64 = undefined;
    var extra: u64 = undefined;
    var parity: u64 = undefined;
    var mantissa: u64 = undefined;
    var scaled: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u29" = 29;
    above = (symbol > @"u29");
    if (above) {
        return @"u0";
    }
    flat = (symbol <= @"u3");
    if (flat) {
        base = (symbol +% @"u1");
        return base;
    }
    extra_index = (symbol -% @"u2");
    extra = (extra_index >> @intCast(@"u1"));
    parity = (symbol & @"u1");
    mantissa = (parity +% @"u2");
    scaled = (mantissa << @intCast(extra));
    base = (scaled +% @"u1");
    return base;
}

pub fn distance_extra(symbol: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u29": u64 = undefined;
    var above: bool = undefined;
    var flat: bool = undefined;
    var extra_index: u64 = undefined;
    var extra: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u29" = 29;
    above = (symbol > @"u29");
    if (above) {
        return @"u0";
    }
    flat = (symbol <= @"u3");
    if (flat) {
        return @"u0";
    }
    extra_index = (symbol -% @"u2");
    extra = (extra_index >> @intCast(@"u1"));
    return extra;
}

pub fn fixed_literal_lengths() []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i288": i64 = undefined;
    var @"i144": i64 = undefined;
    var @"i256": i64 = undefined;
    var @"i280": i64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u9": u64 = undefined;
    var lengths: []u8 = undefined;
    var symbol: i64 = undefined;
    var done: bool = undefined;
    var length: u64 = undefined;
    var past_144: bool = undefined;
    var below_256: bool = undefined;
    var is_nine: bool = undefined;
    var past_256: bool = undefined;
    var below_280: bool = undefined;
    var is_seven: bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i288" = 288;
    @"i144" = 144;
    @"i256" = 256;
    @"i280" = 280;
    @"u7" = 7;
    @"u8" = 8;
    @"u9" = 9;
    lengths = allocator.alloc(u8, 0) catch unreachable;
    symbol = @"i0";
    while (true) {
        done = (symbol >= @"i288");
        if (done) {
            break;
        }
        length = @"u8";
        past_144 = (symbol >= @"i144");
        below_256 = (symbol < @"i256");
        is_nine = (past_144 and below_256);
        if (is_nine) {
            length = @"u9";
        }
        past_256 = (symbol >= @"i256");
        below_280 = (symbol < @"i280");
        is_seven = (past_256 and below_280);
        if (is_seven) {
            length = @"u7";
        }
        lengths = allocator.realloc(lengths, lengths.len + 1) catch unreachable;
        lengths[lengths.len - 1] = @truncate(length);
        symbol = (symbol + @"i1");
    }
    return lengths;
}

pub fn fixed_distance_lengths() []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i30": i64 = undefined;
    var @"u5": u64 = undefined;
    var lengths: []u8 = undefined;
    var symbol: i64 = undefined;
    var done: bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i30" = 30;
    @"u5" = 5;
    lengths = allocator.alloc(u8, 0) catch unreachable;
    symbol = @"i0";
    while (true) {
        done = (symbol >= @"i30");
        if (done) {
            break;
        }
        lengths = allocator.realloc(lengths, lengths.len + 1) catch unreachable;
        lengths[lengths.len - 1] = @truncate(@"u5");
        symbol = (symbol + @"i1");
    }
    return lengths;
}

pub fn code_length_order() []u8 {
    var order: []u8 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u6": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u9": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u11": u64 = undefined;
    var @"u12": u64 = undefined;
    var @"u13": u64 = undefined;
    var @"u14": u64 = undefined;
    var @"u15": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u17": u64 = undefined;
    var @"u18": u64 = undefined;
    order = allocator.alloc(u8, 0) catch unreachable;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u5" = 5;
    @"u6" = 6;
    @"u7" = 7;
    @"u8" = 8;
    @"u9" = 9;
    @"u10" = 10;
    @"u11" = 11;
    @"u12" = 12;
    @"u13" = 13;
    @"u14" = 14;
    @"u15" = 15;
    @"u16" = 16;
    @"u17" = 17;
    @"u18" = 18;
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u16");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u17");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u18");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u0");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u8");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u7");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u9");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u6");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u10");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u5");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u11");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u4");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u12");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u3");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u13");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u2");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u14");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u1");
    order = allocator.realloc(order, order.len + 1) catch unreachable;
    order[order.len - 1] = @truncate(@"u15");
    return order;
}

pub fn max_decompressed_len() u64 {
    var max: u64 = undefined;
    max = 16777216;
    return max;
}

pub fn inflate(data: []const u8) ?[]u8 {
    var limit: u64 = undefined;
    var out: ?[]u8 = undefined;
    limit = max_decompressed_len();
    out = inflate_bounded(data, limit);
    return out;
}

pub fn inflate_bounded(data: []const u8, limit: u64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u15": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u17": u64 = undefined;
    var @"u19": u64 = undefined;
    var @"u32": u64 = undefined;
    var @"u65535": u64 = undefined;
    var @"u256": u64 = undefined;
    var @"u257": u64 = undefined;
    var @"u285": u64 = undefined;
    var @"u286": u64 = undefined;
    var @"u29": u64 = undefined;
    var @"u30": u64 = undefined;
    var @"u11": u64 = undefined;
    var out: []u8 = undefined;
    var bit_pos: u64 = undefined;
    var order: []u8 = undefined;
    var final_opt: ?u64 = undefined;
    var have_final: bool = undefined;
    var no_final: bool = undefined;
    var none: ?[]u8 = undefined;
    var final_: u64 = undefined;
    var type_opt: ?u64 = undefined;
    var have_type: bool = undefined;
    var no_type: bool = undefined;
    var block_type: u64 = undefined;
    var reserved: bool = undefined;
    var stored: bool = undefined;
    var slack: u64 = undefined;
    var needs_pad: bool = undefined;
    var pad: u64 = undefined;
    var len_opt: ?u64 = undefined;
    var have_len: bool = undefined;
    var no_len: bool = undefined;
    var len_: u64 = undefined;
    var nlen_opt: ?u64 = undefined;
    var have_nlen: bool = undefined;
    var no_nlen: bool = undefined;
    var nlen: u64 = undefined;
    var complement: u64 = undefined;
    var agrees: bool = undefined;
    var disagrees: bool = undefined;
    var stored_produced: i64 = undefined;
    var stored_produced_u: u64 = undefined;
    var stored_total: u64 = undefined;
    var stored_over: bool = undefined;
    var copied: u64 = undefined;
    var copy_done: bool = undefined;
    var byte_opt: ?u64 = undefined;
    var have_byte: bool = undefined;
    var no_byte: bool = undefined;
    var byte_: u64 = undefined;
    var compressed: bool = undefined;
    var lit_lengths: []u8 = undefined;
    var dist_lengths: []u8 = undefined;
    var dynamic: bool = undefined;
    var hlit_opt: ?u64 = undefined;
    var have_hlit: bool = undefined;
    var no_hlit: bool = undefined;
    var hlit_raw: u64 = undefined;
    var hlit: u64 = undefined;
    var hdist_opt: ?u64 = undefined;
    var have_hdist: bool = undefined;
    var no_hdist: bool = undefined;
    var hdist_raw: u64 = undefined;
    var hdist: u64 = undefined;
    var hclen_opt: ?u64 = undefined;
    var have_hclen: bool = undefined;
    var no_hclen: bool = undefined;
    var hclen_raw: u64 = undefined;
    var hclen: u64 = undefined;
    var hlit_bad: bool = undefined;
    var hdist_bad: bool = undefined;
    var header_bad: bool = undefined;
    var cl_lengths: []u8 = undefined;
    var zero_fill: u64 = undefined;
    var zeroed: bool = undefined;
    var cl_read: u64 = undefined;
    var cl_done: bool = undefined;
    var cl_opt: ?u64 = undefined;
    var have_cl: bool = undefined;
    var no_cl: bool = undefined;
    var cl_value: u64 = undefined;
    var order_index: i64 = undefined;
    var slot: u64 = undefined;
    var cl_ok: bool = undefined;
    var cl_bad: bool = undefined;
    var cl_counts: []u8 = undefined;
    var cl_symbols: []u8 = undefined;
    var wanted: u64 = undefined;
    var all_lengths: []u8 = undefined;
    var have: u64 = undefined;
    var previous: u64 = undefined;
    var enough: bool = undefined;
    var decoded: ?u64 = undefined;
    var have_decoded: bool = undefined;
    var no_decoded: bool = undefined;
    var packed_: u64 = undefined;
    var used: u64 = undefined;
    var symbol: u64 = undefined;
    var literal: bool = undefined;
    var repeats: bool = undefined;
    var repeat_previous: bool = undefined;
    var extra_width: u64 = undefined;
    var run_base: u64 = undefined;
    var value: u64 = undefined;
    var nothing_yet: bool = undefined;
    var short_zeroes: bool = undefined;
    var extra_opt: ?u64 = undefined;
    var have_extra: bool = undefined;
    var no_extra: bool = undefined;
    var extra: u64 = undefined;
    var run: u64 = undefined;
    var over: u64 = undefined;
    var overruns: bool = undefined;
    var written: u64 = undefined;
    var run_done: bool = undefined;
    var hlit_i: i64 = undefined;
    var wanted_i: i64 = undefined;
    var lit_ok: bool = undefined;
    var dist_ok: bool = undefined;
    var codes_ok: bool = undefined;
    var codes_bad: bool = undefined;
    var lit_counts: []u8 = undefined;
    var lit_symbols: []u8 = undefined;
    var dist_counts: []u8 = undefined;
    var dist_symbols: []u8 = undefined;
    var end_of_block: bool = undefined;
    var is_literal: bool = undefined;
    var literal_produced: i64 = undefined;
    var literal_produced_u: u64 = undefined;
    var literal_full: bool = undefined;
    var is_match: bool = undefined;
    var unknown: bool = undefined;
    var base: u64 = undefined;
    var width: u64 = undefined;
    var len_extra_opt: ?u64 = undefined;
    var have_len_extra: bool = undefined;
    var no_len_extra: bool = undefined;
    var len_extra: u64 = undefined;
    var match_length: u64 = undefined;
    var dist_decoded: ?u64 = undefined;
    var have_dist: bool = undefined;
    var no_dist: bool = undefined;
    var dist_packed: u64 = undefined;
    var dist_used: u64 = undefined;
    var dist_symbol: u64 = undefined;
    var dist_unknown: bool = undefined;
    var dist_base: u64 = undefined;
    var dist_width: u64 = undefined;
    var dist_extra_opt: ?u64 = undefined;
    var have_dist_extra: bool = undefined;
    var no_dist_extra: bool = undefined;
    var dist_extra: u64 = undefined;
    var distance: u64 = undefined;
    var produced: i64 = undefined;
    var produced_u: u64 = undefined;
    var too_far: bool = undefined;
    var match_total: u64 = undefined;
    var match_over: bool = undefined;
    var from_: u64 = undefined;
    var taken: u64 = undefined;
    var match_done: bool = undefined;
    var at: u64 = undefined;
    var at_i: i64 = undefined;
    var last: bool = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u5" = 5;
    @"u7" = 7;
    @"u8" = 8;
    @"u15" = 15;
    @"u16" = 16;
    @"u17" = 17;
    @"u19" = 19;
    @"u32" = 32;
    @"u65535" = 65535;
    @"u256" = 256;
    @"u257" = 257;
    @"u285" = 285;
    @"u286" = 286;
    @"u29" = 29;
    @"u30" = 30;
    @"u11" = 11;
    out = allocator.alloc(u8, 0) catch unreachable;
    bit_pos = @"u0";
    order = code_length_order();
    while (true) {
        final_opt = read_bits(data, bit_pos, @"u1");
        have_final = final_opt != null;
        no_final = (!have_final);
        if (no_final) {
            none = null;
            return none;
        }
        final_ = final_opt.?;
        bit_pos = (bit_pos +% @"u1");
        type_opt = read_bits(data, bit_pos, @"u2");
        have_type = type_opt != null;
        no_type = (!have_type);
        if (no_type) {
            none = null;
            return none;
        }
        block_type = type_opt.?;
        bit_pos = (bit_pos +% @"u2");
        reserved = (block_type == @"u3");
        if (reserved) {
            none = null;
            return none;
        }
        stored = (block_type == @"u0");
        if (stored) {
            slack = (bit_pos & @"u7");
            needs_pad = (slack > @"u0");
            if (needs_pad) {
                pad = (@"u8" -% slack);
                bit_pos = (bit_pos +% pad);
            }
            len_opt = read_bits(data, bit_pos, @"u16");
            have_len = len_opt != null;
            no_len = (!have_len);
            if (no_len) {
                none = null;
                return none;
            }
            len_ = len_opt.?;
            bit_pos = (bit_pos +% @"u16");
            nlen_opt = read_bits(data, bit_pos, @"u16");
            have_nlen = nlen_opt != null;
            no_nlen = (!have_nlen);
            if (no_nlen) {
                none = null;
                return none;
            }
            nlen = nlen_opt.?;
            bit_pos = (bit_pos +% @"u16");
            complement = (len_ ^ @"u65535");
            agrees = (nlen == complement);
            disagrees = (!agrees);
            if (disagrees) {
                none = null;
                return none;
            }
            stored_produced = @intCast(out.len);
            stored_produced_u = @bitCast(stored_produced);
            stored_total = (stored_produced_u +% len_);
            stored_over = (stored_total > limit);
            if (stored_over) {
                none = null;
                return none;
            }
            copied = @"u0";
            while (true) {
                copy_done = (copied >= len_);
                if (copy_done) {
                    break;
                }
                byte_opt = read_bits(data, bit_pos, @"u8");
                have_byte = byte_opt != null;
                no_byte = (!have_byte);
                if (no_byte) {
                    none = null;
                    return none;
                }
                byte_ = byte_opt.?;
                out = allocator.realloc(out, out.len + 1) catch unreachable;
                out[out.len - 1] = @truncate(byte_);
                bit_pos = (bit_pos +% @"u8");
                copied = (copied +% @"u1");
            }
        }
        compressed = (!stored);
        if (compressed) {
            lit_lengths = fixed_literal_lengths();
            dist_lengths = fixed_distance_lengths();
            dynamic = (block_type == @"u2");
            if (dynamic) {
                hlit_opt = read_bits(data, bit_pos, @"u5");
                have_hlit = hlit_opt != null;
                no_hlit = (!have_hlit);
                if (no_hlit) {
                    none = null;
                    return none;
                }
                hlit_raw = hlit_opt.?;
                hlit = (hlit_raw +% @"u257");
                bit_pos = (bit_pos +% @"u5");
                hdist_opt = read_bits(data, bit_pos, @"u5");
                have_hdist = hdist_opt != null;
                no_hdist = (!have_hdist);
                if (no_hdist) {
                    none = null;
                    return none;
                }
                hdist_raw = hdist_opt.?;
                hdist = (hdist_raw +% @"u1");
                bit_pos = (bit_pos +% @"u5");
                hclen_opt = read_bits(data, bit_pos, @"u4");
                have_hclen = hclen_opt != null;
                no_hclen = (!have_hclen);
                if (no_hclen) {
                    none = null;
                    return none;
                }
                hclen_raw = hclen_opt.?;
                hclen = (hclen_raw +% @"u4");
                bit_pos = (bit_pos +% @"u4");
                hlit_bad = (hlit > @"u286");
                hdist_bad = (hdist > @"u30");
                header_bad = (hlit_bad or hdist_bad);
                if (header_bad) {
                    none = null;
                    return none;
                }
                cl_lengths = allocator.alloc(u8, 0) catch unreachable;
                zero_fill = @"u0";
                while (true) {
                    zeroed = (zero_fill >= @"u19");
                    if (zeroed) {
                        break;
                    }
                    cl_lengths = allocator.realloc(cl_lengths, cl_lengths.len + 1) catch unreachable;
                    cl_lengths[cl_lengths.len - 1] = @truncate(@"u0");
                    zero_fill = (zero_fill +% @"u1");
                }
                cl_read = @"u0";
                while (true) {
                    cl_done = (cl_read >= hclen);
                    if (cl_done) {
                        break;
                    }
                    cl_opt = read_bits(data, bit_pos, @"u3");
                    have_cl = cl_opt != null;
                    no_cl = (!have_cl);
                    if (no_cl) {
                        none = null;
                        return none;
                    }
                    cl_value = cl_opt.?;
                    bit_pos = (bit_pos +% @"u3");
                    order_index = @bitCast(cl_read);
                    slot = @intCast(order[@intCast(order_index)]);
                    cl_lengths[@intCast(slot)] = @truncate(cl_value);
                    cl_read = (cl_read +% @"u1");
                }
                cl_ok = code_lengths_valid(cl_lengths, @"u7");
                cl_bad = (!cl_ok);
                if (cl_bad) {
                    none = null;
                    return none;
                }
                cl_counts = code_length_counts(cl_lengths, @"u7");
                cl_symbols = sorted_symbols(cl_lengths, @"u7");
                wanted = (hlit +% hdist);
                all_lengths = allocator.alloc(u8, 0) catch unreachable;
                have = @"u0";
                previous = @"u0";
                while (true) {
                    enough = (have >= wanted);
                    if (enough) {
                        break;
                    }
                    decoded = huffman_decode(data, bit_pos, cl_counts, cl_symbols, @"u7");
                    have_decoded = decoded != null;
                    no_decoded = (!have_decoded);
                    if (no_decoded) {
                        none = null;
                        return none;
                    }
                    packed_ = decoded.?;
                    used = (packed_ >> @intCast(@"u32"));
                    symbol = (packed_ & @"u65535");
                    bit_pos = (bit_pos +% used);
                    literal = (symbol < @"u16");
                    if (literal) {
                        all_lengths = allocator.realloc(all_lengths, all_lengths.len + 1) catch unreachable;
                        all_lengths[all_lengths.len - 1] = @truncate(symbol);
                        previous = symbol;
                        have = (have +% @"u1");
                    }
                    repeats = (!literal);
                    if (repeats) {
                        repeat_previous = (symbol == @"u16");
                        extra_width = @"u7";
                        run_base = @"u11";
                        value = @"u0";
                        if (repeat_previous) {
                            extra_width = @"u2";
                            run_base = @"u3";
                            value = previous;
                            nothing_yet = (have == @"u0");
                            if (nothing_yet) {
                                none = null;
                                return none;
                            }
                        }
                        short_zeroes = (symbol == @"u17");
                        if (short_zeroes) {
                            extra_width = @"u3";
                            run_base = @"u3";
                        }
                        extra_opt = read_bits(data, bit_pos, extra_width);
                        have_extra = extra_opt != null;
                        no_extra = (!have_extra);
                        if (no_extra) {
                            none = null;
                            return none;
                        }
                        extra = extra_opt.?;
                        bit_pos = (bit_pos +% extra_width);
                        run = (run_base +% extra);
                        over = (have +% run);
                        overruns = (over > wanted);
                        if (overruns) {
                            none = null;
                            return none;
                        }
                        written = @"u0";
                        while (true) {
                            run_done = (written >= run);
                            if (run_done) {
                                break;
                            }
                            all_lengths = allocator.realloc(all_lengths, all_lengths.len + 1) catch unreachable;
                            all_lengths[all_lengths.len - 1] = @truncate(value);
                            written = (written +% @"u1");
                        }
                        have = (have +% run);
                    }
                }
                hlit_i = @bitCast(hlit);
                wanted_i = @bitCast(wanted);
                lit_lengths = allocator.dupe(u8, all_lengths[@intCast(@"i0")..@intCast(hlit_i)]) catch unreachable;
                dist_lengths = allocator.dupe(u8, all_lengths[@intCast(hlit_i)..@intCast(wanted_i)]) catch unreachable;
            }
            lit_ok = code_lengths_valid(lit_lengths, @"u15");
            dist_ok = code_lengths_valid(dist_lengths, @"u15");
            codes_ok = (lit_ok and dist_ok);
            codes_bad = (!codes_ok);
            if (codes_bad) {
                none = null;
                return none;
            }
            lit_counts = code_length_counts(lit_lengths, @"u15");
            lit_symbols = sorted_symbols(lit_lengths, @"u15");
            dist_counts = code_length_counts(dist_lengths, @"u15");
            dist_symbols = sorted_symbols(dist_lengths, @"u15");
            while (true) {
                decoded = huffman_decode(data, bit_pos, lit_counts, lit_symbols, @"u15");
                have_decoded = decoded != null;
                no_decoded = (!have_decoded);
                if (no_decoded) {
                    none = null;
                    return none;
                }
                packed_ = decoded.?;
                used = (packed_ >> @intCast(@"u32"));
                symbol = (packed_ & @"u65535");
                bit_pos = (bit_pos +% used);
                end_of_block = (symbol == @"u256");
                if (end_of_block) {
                    break;
                }
                is_literal = (symbol < @"u256");
                if (is_literal) {
                    literal_produced = @intCast(out.len);
                    literal_produced_u = @bitCast(literal_produced);
                    literal_full = (literal_produced_u >= limit);
                    if (literal_full) {
                        none = null;
                        return none;
                    }
                    out = allocator.realloc(out, out.len + 1) catch unreachable;
                    out[out.len - 1] = @truncate(symbol);
                }
                is_match = (symbol > @"u256");
                if (is_match) {
                    unknown = (symbol > @"u285");
                    if (unknown) {
                        none = null;
                        return none;
                    }
                    base = length_base(symbol);
                    width = length_extra(symbol);
                    len_extra_opt = read_bits(data, bit_pos, width);
                    have_len_extra = len_extra_opt != null;
                    no_len_extra = (!have_len_extra);
                    if (no_len_extra) {
                        none = null;
                        return none;
                    }
                    len_extra = len_extra_opt.?;
                    bit_pos = (bit_pos +% width);
                    match_length = (base +% len_extra);
                    dist_decoded = huffman_decode(data, bit_pos, dist_counts, dist_symbols, @"u15");
                    have_dist = dist_decoded != null;
                    no_dist = (!have_dist);
                    if (no_dist) {
                        none = null;
                        return none;
                    }
                    dist_packed = dist_decoded.?;
                    dist_used = (dist_packed >> @intCast(@"u32"));
                    dist_symbol = (dist_packed & @"u65535");
                    bit_pos = (bit_pos +% dist_used);
                    dist_unknown = (dist_symbol > @"u29");
                    if (dist_unknown) {
                        none = null;
                        return none;
                    }
                    dist_base = distance_base(dist_symbol);
                    dist_width = distance_extra(dist_symbol);
                    dist_extra_opt = read_bits(data, bit_pos, dist_width);
                    have_dist_extra = dist_extra_opt != null;
                    no_dist_extra = (!have_dist_extra);
                    if (no_dist_extra) {
                        none = null;
                        return none;
                    }
                    dist_extra = dist_extra_opt.?;
                    bit_pos = (bit_pos +% dist_width);
                    distance = (dist_base +% dist_extra);
                    produced = @intCast(out.len);
                    produced_u = @bitCast(produced);
                    too_far = (distance > produced_u);
                    if (too_far) {
                        none = null;
                        return none;
                    }
                    match_total = (produced_u +% match_length);
                    match_over = (match_total > limit);
                    if (match_over) {
                        none = null;
                        return none;
                    }
                    from_ = (produced_u -% distance);
                    taken = @"u0";
                    while (true) {
                        match_done = (taken >= match_length);
                        if (match_done) {
                            break;
                        }
                        at = (from_ +% taken);
                        at_i = @bitCast(at);
                        byte_ = @intCast(out[@intCast(at_i)]);
                        out = allocator.realloc(out, out.len + 1) catch unreachable;
                        out[out.len - 1] = @truncate(byte_);
                        taken = (taken +% @"u1");
                    }
                }
            }
        }
        last = (final_ > @"u0");
        if (last) {
            break;
        }
    }
    some = out;
    return some;
}

pub fn adler32(data: []const u8) u64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u65521": u64 = undefined;
    var low: u64 = undefined;
    var high: u64 = undefined;
    var n: i64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var low_sum: u64 = undefined;
    var low_over: bool = undefined;
    var high_sum: u64 = undefined;
    var high_over: bool = undefined;
    var shifted: u64 = undefined;
    var value: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u16" = 16;
    @"u65521" = 65521;
    low = @"u1";
    high = @"u0";
    n = @intCast(data.len);
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        byte_ = @intCast(data[@intCast(pos)]);
        low_sum = (low +% byte_);
        low = low_sum;
        low_over = (low_sum >= @"u65521");
        if (low_over) {
            low = (low_sum -% @"u65521");
        }
        high_sum = (high +% low);
        high = high_sum;
        high_over = (high_sum >= @"u65521");
        if (high_over) {
            high = (high_sum -% @"u65521");
        }
        pos = (pos + @"i1");
    }
    shifted = (high << @intCast(@"u16"));
    value = (shifted | low);
    return value;
}

pub fn zlib_decompress(data: []const u8) ?[]u8 {
    var limit: u64 = undefined;
    var out: ?[]u8 = undefined;
    limit = max_decompressed_len();
    out = zlib_decompress_bounded(data, limit);
    return out;
}

pub fn zlib_decompress_bounded(data: []const u8, limit: u64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"i4": i64 = undefined;
    var @"i6": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u15": u64 = undefined;
    var @"u31": u64 = undefined;
    var @"u32": u64 = undefined;
    var @"u256": u64 = undefined;
    var n: i64 = undefined;
    var too_short: bool = undefined;
    var none: ?[]u8 = undefined;
    var cmf: u64 = undefined;
    var flg: u64 = undefined;
    var method: u64 = undefined;
    var not_deflate: bool = undefined;
    var scaled: u64 = undefined;
    var header: u64 = undefined;
    var check: u64 = undefined;
    var reduced: bool = undefined;
    var bad_check: bool = undefined;
    var u32_flag: u64 = undefined;
    var has_dict: bool = undefined;
    var body_end: i64 = undefined;
    var body: []u8 = undefined;
    var inflated: ?[]u8 = undefined;
    var present: bool = undefined;
    var missing: bool = undefined;
    var out: []u8 = undefined;
    var expected: u64 = undefined;
    var at: i64 = undefined;
    var read_done: bool = undefined;
    var byte_: u64 = undefined;
    var moved: u64 = undefined;
    var actual: u64 = undefined;
    var agrees: bool = undefined;
    var disagrees: bool = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"i4" = 4;
    @"i6" = 6;
    @"u0" = 0;
    @"u8" = 8;
    @"u15" = 15;
    @"u31" = 31;
    @"u32" = 32;
    @"u256" = 256;
    n = @intCast(data.len);
    too_short = (n < @"i6");
    if (too_short) {
        none = null;
        return none;
    }
    cmf = @intCast(data[@intCast(@"i0")]);
    flg = @intCast(data[@intCast(@"i1")]);
    method = (cmf & @"u15");
    not_deflate = (method != @"u8");
    if (not_deflate) {
        none = null;
        return none;
    }
    scaled = (cmf *% @"u256");
    header = (scaled +% flg);
    check = header;
    while (true) {
        reduced = (check < @"u31");
        if (reduced) {
            break;
        }
        check = (check -% @"u31");
    }
    bad_check = (check != @"u0");
    if (bad_check) {
        none = null;
        return none;
    }
    u32_flag = (flg & @"u32");
    has_dict = (u32_flag > @"u0");
    if (has_dict) {
        none = null;
        return none;
    }
    body_end = (n - @"i4");
    body = allocator.dupe(u8, data[@intCast(@"i2")..@intCast(body_end)]) catch unreachable;
    inflated = inflate_bounded(body, limit);
    present = inflated != null;
    missing = (!present);
    if (missing) {
        none = null;
        return none;
    }
    out = inflated.?;
    expected = @"u0";
    at = body_end;
    while (true) {
        read_done = (at >= n);
        if (read_done) {
            break;
        }
        byte_ = @intCast(data[@intCast(at)]);
        moved = (expected *% @"u256");
        expected = (moved +% byte_);
        at = (at + @"i1");
    }
    actual = adler32(out);
    agrees = (actual == expected);
    disagrees = (!agrees);
    if (disagrees) {
        none = null;
        return none;
    }
    some = out;
    return some;
}

pub fn deflate_write_bits(state: []const u8, value: u64, count: u64) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var out: []u8 = undefined;
    var n: i64 = undefined;
    var copy_pos: i64 = undefined;
    var copy_done: bool = undefined;
    var copy_byte: u64 = undefined;
    var remaining: u64 = undefined;
    var written: u64 = undefined;
    var done: bool = undefined;
    var used: u64 = undefined;
    var at_boundary: bool = undefined;
    var out_n: i64 = undefined;
    var last: i64 = undefined;
    var current: u64 = undefined;
    var bit: u64 = undefined;
    var shifted: u64 = undefined;
    var next_: u64 = undefined;
    var next_byte: u64 = undefined;
    var next_used_raw: u64 = undefined;
    var next_used: u64 = undefined;
    var full: bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    @"u255" = 255;
    out = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(state.len);
    copy_pos = @"i0";
    while (true) {
        copy_done = (copy_pos >= n);
        if (copy_done) {
            break;
        }
        copy_byte = @intCast(state[@intCast(copy_pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(copy_byte);
        copy_pos = (copy_pos + @"i1");
    }
    remaining = value;
    written = @"u0";
    while (true) {
        done = (written >= count);
        if (done) {
            break;
        }
        used = @intCast(out[@intCast(@"i0")]);
        at_boundary = (used == @"u0");
        if (at_boundary) {
            out = allocator.realloc(out, out.len + 1) catch unreachable;
            out[out.len - 1] = @truncate(@"u0");
        }
        out_n = @intCast(out.len);
        last = (out_n - @"i1");
        current = @intCast(out[@intCast(last)]);
        bit = (remaining & @"u1");
        shifted = (bit << @intCast(used));
        next_ = (current | shifted);
        next_byte = (next_ & @"u255");
        out[@intCast(last)] = @truncate(next_byte);
        next_used_raw = (used +% @"u1");
        next_used = next_used_raw;
        full = (next_used_raw == @"u8");
        if (full) {
            next_used = @"u0";
        }
        out[@intCast(@"i0")] = @truncate(next_used);
        remaining = (remaining >> @intCast(@"u1"));
        written = (written +% @"u1");
    }
    return out;
}

pub fn deflate_drain_complete(state: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var used: u64 = undefined;
    var n: i64 = undefined;
    var end_: i64 = undefined;
    var partial: bool = undefined;
    var out: []u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    used = @intCast(state[@intCast(@"i0")]);
    n = @intCast(state.len);
    end_ = n;
    partial = (used != @"u0");
    if (partial) {
        end_ = (n - @"i1");
    }
    out = allocator.dupe(u8, state[@intCast(@"i1")..@intCast(end_)]) catch unreachable;
    return out;
}

pub fn deflate_drain_carry(state: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var out: []u8 = undefined;
    var used: u64 = undefined;
    var partial: bool = undefined;
    var n: i64 = undefined;
    var last: i64 = undefined;
    var last_byte: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    out = allocator.alloc(u8, 0) catch unreachable;
    used = @intCast(state[@intCast(@"i0")]);
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(used);
    partial = (used != @"u0");
    if (partial) {
        n = @intCast(state.len);
        last = (n - @"i1");
        last_byte = @intCast(state[@intCast(last)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(last_byte);
    }
    return out;
}

pub fn deflate_reverse_code(code: u64, width: u64) u64 {
    var @"u64": u64 = undefined;
    var reversed: u64 = undefined;
    var shift: u64 = undefined;
    var out: u64 = undefined;
    @"u64" = 64;
    reversed = @bitReverse(code);
    shift = (@"u64" -% width);
    out = (reversed >> @intCast(shift));
    return out;
}

pub fn deflate_fixed_symbol(state: []const u8, symbol: u64) []u8 {
    var @"u0": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u9": u64 = undefined;
    var @"u48": u64 = undefined;
    var @"u143": u64 = undefined;
    var @"u144": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"u256": u64 = undefined;
    var @"u279": u64 = undefined;
    var @"u280": u64 = undefined;
    var @"u400": u64 = undefined;
    var @"u192": u64 = undefined;
    var code: u64 = undefined;
    var code_width: u64 = undefined;
    var first: bool = undefined;
    var second_low: bool = undefined;
    var second_high: bool = undefined;
    var second: bool = undefined;
    var third_low: bool = undefined;
    var third_high: bool = undefined;
    var third: bool = undefined;
    var fourth: bool = undefined;
    var offset: u64 = undefined;
    var wire_code: u64 = undefined;
    var out: []u8 = undefined;
    @"u0" = 0;
    @"u7" = 7;
    @"u8" = 8;
    @"u9" = 9;
    @"u48" = 48;
    @"u143" = 143;
    @"u144" = 144;
    @"u255" = 255;
    @"u256" = 256;
    @"u279" = 279;
    @"u280" = 280;
    @"u400" = 400;
    @"u192" = 192;
    code = @"u0";
    code_width = @"u8";
    first = (symbol <= @"u143");
    if (first) {
        code = (@"u48" +% symbol);
    }
    second_low = (symbol >= @"u144");
    second_high = (symbol <= @"u255");
    second = (second_low and second_high);
    if (second) {
        code = (@"u400" +% symbol);
        code = (code -% @"u144");
        code_width = @"u9";
    }
    third_low = (symbol >= @"u256");
    third_high = (symbol <= @"u279");
    third = (third_low and third_high);
    if (third) {
        code = (symbol -% @"u256");
        code_width = @"u7";
    }
    fourth = (symbol >= @"u280");
    if (fourth) {
        offset = (symbol -% @"u280");
        code = (@"u192" +% offset);
        code_width = @"u8";
    }
    wire_code = deflate_reverse_code(code, code_width);
    out = deflate_write_bits(state, wire_code, code_width);
    return out;
}

pub fn deflate_hash(b0: u64, b1: u64, b2: u64) u64 {
    var @"u8": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u17": u64 = undefined;
    var @"u2654435761": u64 = undefined;
    var @"u4294967295": u64 = undefined;
    var b0s: u64 = undefined;
    var b1s: u64 = undefined;
    var partial: u64 = undefined;
    var key: u64 = undefined;
    var mixed: u64 = undefined;
    var mixed32: u64 = undefined;
    var bucket: u64 = undefined;
    @"u8" = 8;
    @"u16" = 16;
    @"u17" = 17;
    @"u2654435761" = 2654435761;
    @"u4294967295" = 4294967295;
    b0s = (b0 << @intCast(@"u16"));
    b1s = (b1 << @intCast(@"u8"));
    partial = (b0s | b1s);
    key = (partial | b2);
    mixed = (key *% @"u2654435761");
    mixed32 = (mixed & @"u4294967295");
    bucket = (mixed32 >> @intCast(@"u17"));
    return bucket;
}

pub fn deflate_token_entry(tag: u64, value: i64, distance: i64) []u8 {
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var value_u: u64 = undefined;
    var distance_u: u64 = undefined;
    var value_low: u64 = undefined;
    var value_shifted: u64 = undefined;
    var value_high: u64 = undefined;
    var distance_low: u64 = undefined;
    var distance_shifted: u64 = undefined;
    var distance_high: u64 = undefined;
    var entry: []u8 = undefined;
    @"u8" = 8;
    @"u255" = 255;
    value_u = @bitCast(value);
    distance_u = @bitCast(distance);
    value_low = (value_u & @"u255");
    value_shifted = (value_u >> @intCast(@"u8"));
    value_high = (value_shifted & @"u255");
    distance_low = (distance_u & @"u255");
    distance_shifted = (distance_u >> @intCast(@"u8"));
    distance_high = (distance_shifted & @"u255");
    entry = allocator.alloc(u8, 0) catch unreachable;
    entry = allocator.realloc(entry, entry.len + 1) catch unreachable;
    entry[entry.len - 1] = @truncate(tag);
    entry = allocator.realloc(entry, entry.len + 1) catch unreachable;
    entry[entry.len - 1] = @truncate(value_low);
    entry = allocator.realloc(entry, entry.len + 1) catch unreachable;
    entry[entry.len - 1] = @truncate(value_high);
    entry = allocator.realloc(entry, entry.len + 1) catch unreachable;
    entry[entry.len - 1] = @truncate(distance_low);
    entry = allocator.realloc(entry, entry.len + 1) catch unreachable;
    entry[entry.len - 1] = @truncate(distance_high);
    return entry;
}

pub fn deflate_tokens(data: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"i3": i64 = undefined;
    var @"i5": i64 = undefined;
    var @"i128": i64 = undefined;
    var @"i258": i64 = undefined;
    var @"i32768": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u24": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"u32767": u64 = undefined;
    var @"u131072": u64 = undefined;
    var tokens: []u8 = undefined;
    var n: i64 = undefined;
    var head: []u8 = undefined;
    var prev: []u8 = undefined;
    var hashed: i64 = undefined;
    var pos: i64 = undefined;
    var saved_length: i64 = undefined;
    var saved_distance: i64 = undefined;
    var done: bool = undefined;
    var caught_up: bool = undefined;
    var hash_end: i64 = undefined;
    var hashable: bool = undefined;
    var hb0: u64 = undefined;
    var hb1_at: i64 = undefined;
    var hb1: u64 = undefined;
    var hb2: u64 = undefined;
    var bucket: u64 = undefined;
    var head_off_u: u64 = undefined;
    var head_off: i64 = undefined;
    var head_off1: i64 = undefined;
    var head_off2: i64 = undefined;
    var head_off3: i64 = undefined;
    var old0: u64 = undefined;
    var old1: u64 = undefined;
    var old2: u64 = undefined;
    var old3: u64 = undefined;
    var p_u: u64 = undefined;
    var p_slot: u64 = undefined;
    var prev_off_u: u64 = undefined;
    var prev_off: i64 = undefined;
    var prev_off1: i64 = undefined;
    var prev_off2: i64 = undefined;
    var prev_off3: i64 = undefined;
    var p_b0: u64 = undefined;
    var p_s1: u64 = undefined;
    var p_b1: u64 = undefined;
    var p_s2: u64 = undefined;
    var p_b2: u64 = undefined;
    var p_s3: u64 = undefined;
    var p_b3: u64 = undefined;
    var has_saved: bool = undefined;
    var threshold: i64 = undefined;
    var best_length: i64 = undefined;
    var best_distance: i64 = undefined;
    var probes_left: i64 = undefined;
    var tail2: i64 = undefined;
    var searchable: bool = undefined;
    var window_start: i64 = undefined;
    var before_start: bool = undefined;
    var sb0: u64 = undefined;
    var sb1_at: i64 = undefined;
    var sb1: u64 = undefined;
    var sb2: u64 = undefined;
    var search_bucket: u64 = undefined;
    var sh_off_u: u64 = undefined;
    var sh_off: i64 = undefined;
    var sh_off1: i64 = undefined;
    var sh_off2: i64 = undefined;
    var sh_off3: i64 = undefined;
    var c0: u64 = undefined;
    var c1: u64 = undefined;
    var c2: u64 = undefined;
    var c3: u64 = undefined;
    var c1s: u64 = undefined;
    var c2s: u64 = undefined;
    var c3s: u64 = undefined;
    var c01: u64 = undefined;
    var c012: u64 = undefined;
    var candidate_u: u64 = undefined;
    var candidate: i64 = undefined;
    var in_window: bool = undefined;
    var out_of_window: bool = undefined;
    var distance: i64 = undefined;
    var matched: i64 = undefined;
    var at_limit: bool = undefined;
    var target_at: i64 = undefined;
    var past_input: bool = undefined;
    var source_offset: i64 = undefined;
    var offset_small: bool = undefined;
    var source_at: i64 = undefined;
    var source_byte: u64 = undefined;
    var target_byte: u64 = undefined;
    var different: bool = undefined;
    var better: bool = undefined;
    var maximal: bool = undefined;
    var exhausted: bool = undefined;
    var c_u: u64 = undefined;
    var c_slot: u64 = undefined;
    var pv_off_u: u64 = undefined;
    var pv_off: i64 = undefined;
    var pv_off1: i64 = undefined;
    var pv_off2: i64 = undefined;
    var pv_off3: i64 = undefined;
    var pv0: u64 = undefined;
    var pv1: u64 = undefined;
    var pv2: u64 = undefined;
    var pv3: u64 = undefined;
    var pv1s: u64 = undefined;
    var pv2s: u64 = undefined;
    var pv3s: u64 = undefined;
    var pv01: u64 = undefined;
    var pv012: u64 = undefined;
    var next_u: u64 = undefined;
    var found: bool = undefined;
    var current_length: i64 = undefined;
    var current_distance: i64 = undefined;
    var later_better: bool = undefined;
    var literal_at: i64 = undefined;
    var literal_u: u64 = undefined;
    var literal: i64 = undefined;
    var entry: []u8 = undefined;
    var entry_at: i64 = undefined;
    var entry_done: bool = undefined;
    var entry_byte: u64 = undefined;
    var long_: bool = undefined;
    var short_: bool = undefined;
    var keep_saved: bool = undefined;
    var remaining: i64 = undefined;
    var no_saved: bool = undefined;
    var has_match: bool = undefined;
    var no_match: bool = undefined;
    var pending: bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"i3" = 3;
    @"i5" = 5;
    @"i128" = 128;
    @"i258" = 258;
    @"i32768" = 32768;
    @"u0" = 0;
    @"u1" = 1;
    @"u4" = 4;
    @"u8" = 8;
    @"u16" = 16;
    @"u24" = 24;
    @"u255" = 255;
    @"u32767" = 32767;
    @"u131072" = 131072;
    tokens = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(data.len);
    head = blk: {
        const zeroed = allocator.alloc(u8, @intCast(@"u131072")) catch unreachable;
        @memset(zeroed, 0);
        break :blk zeroed;
    };
    prev = blk: {
        const zeroed = allocator.alloc(u8, @intCast(@"u131072")) catch unreachable;
        @memset(zeroed, 0);
        break :blk zeroed;
    };
    hashed = @"i1";
    pos = @"i0";
    saved_length = @"i0";
    saved_distance = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        while (true) {
            caught_up = (hashed >= pos);
            if (caught_up) {
                break;
            }
            hash_end = (hashed + @"i2");
            hashable = (hash_end < n);
            if (hashable) {
                hb0 = @intCast(data[@intCast(hashed)]);
                hb1_at = (hashed + @"i1");
                hb1 = @intCast(data[@intCast(hb1_at)]);
                hb2 = @intCast(data[@intCast(hash_end)]);
                bucket = deflate_hash(hb0, hb1, hb2);
                head_off_u = (bucket *% @"u4");
                head_off = @bitCast(head_off_u);
                head_off1 = (head_off + @"i1");
                head_off2 = (head_off + @"i2");
                head_off3 = (head_off + @"i3");
                old0 = @intCast(head[@intCast(head_off)]);
                old1 = @intCast(head[@intCast(head_off1)]);
                old2 = @intCast(head[@intCast(head_off2)]);
                old3 = @intCast(head[@intCast(head_off3)]);
                p_u = @bitCast(hashed);
                p_slot = (p_u & @"u32767");
                prev_off_u = (p_slot *% @"u4");
                prev_off = @bitCast(prev_off_u);
                prev_off1 = (prev_off + @"i1");
                prev_off2 = (prev_off + @"i2");
                prev_off3 = (prev_off + @"i3");
                prev[@intCast(prev_off)] = @truncate(old0);
                prev[@intCast(prev_off1)] = @truncate(old1);
                prev[@intCast(prev_off2)] = @truncate(old2);
                prev[@intCast(prev_off3)] = @truncate(old3);
                p_b0 = (p_u & @"u255");
                p_s1 = (p_u >> @intCast(@"u8"));
                p_b1 = (p_s1 & @"u255");
                p_s2 = (p_u >> @intCast(@"u16"));
                p_b2 = (p_s2 & @"u255");
                p_s3 = (p_u >> @intCast(@"u24"));
                p_b3 = (p_s3 & @"u255");
                head[@intCast(head_off)] = @truncate(p_b0);
                head[@intCast(head_off1)] = @truncate(p_b1);
                head[@intCast(head_off2)] = @truncate(p_b2);
                head[@intCast(head_off3)] = @truncate(p_b3);
            }
            hashed = (hashed + @"i1");
        }
        has_saved = (saved_length > @"i0");
        threshold = @"i2";
        if (has_saved) {
            threshold = saved_length;
        }
        best_length = threshold;
        best_distance = @"i0";
        probes_left = @"i128";
        tail2 = (pos + @"i2");
        searchable = (tail2 < n);
        if (searchable) {
            window_start = (pos - @"i32768");
            before_start = (window_start < @"i1");
            if (before_start) {
                window_start = @"i1";
            }
            sb0 = @intCast(data[@intCast(pos)]);
            sb1_at = (pos + @"i1");
            sb1 = @intCast(data[@intCast(sb1_at)]);
            sb2 = @intCast(data[@intCast(tail2)]);
            search_bucket = deflate_hash(sb0, sb1, sb2);
            sh_off_u = (search_bucket *% @"u4");
            sh_off = @bitCast(sh_off_u);
            sh_off1 = (sh_off + @"i1");
            sh_off2 = (sh_off + @"i2");
            sh_off3 = (sh_off + @"i3");
            c0 = @intCast(head[@intCast(sh_off)]);
            c1 = @intCast(head[@intCast(sh_off1)]);
            c2 = @intCast(head[@intCast(sh_off2)]);
            c3 = @intCast(head[@intCast(sh_off3)]);
            c1s = (c1 << @intCast(@"u8"));
            c2s = (c2 << @intCast(@"u16"));
            c3s = (c3 << @intCast(@"u24"));
            c01 = (c0 | c1s);
            c012 = (c01 | c2s);
            candidate_u = (c012 | c3s);
            candidate = @bitCast(candidate_u);
            while (true) {
                in_window = (candidate >= window_start);
                out_of_window = (!in_window);
                if (out_of_window) {
                    break;
                }
                distance = (pos - candidate);
                matched = @"i0";
                while (true) {
                    at_limit = (matched >= @"i258");
                    if (at_limit) {
                        break;
                    }
                    target_at = (pos + matched);
                    past_input = (target_at >= n);
                    if (past_input) {
                        break;
                    }
                    source_offset = matched;
                    while (true) {
                        offset_small = (source_offset < distance);
                        if (offset_small) {
                            break;
                        }
                        source_offset = (source_offset - distance);
                    }
                    source_at = (candidate + source_offset);
                    source_byte = @intCast(data[@intCast(source_at)]);
                    target_byte = @intCast(data[@intCast(target_at)]);
                    different = (source_byte != target_byte);
                    if (different) {
                        break;
                    }
                    matched = (matched + @"i1");
                }
                better = (matched > best_length);
                if (better) {
                    best_length = matched;
                    best_distance = distance;
                }
                maximal = (best_length == @"i258");
                if (maximal) {
                    break;
                }
                probes_left = (probes_left - @"i1");
                exhausted = (probes_left <= @"i0");
                if (exhausted) {
                    break;
                }
                c_u = @bitCast(candidate);
                c_slot = (c_u & @"u32767");
                pv_off_u = (c_slot *% @"u4");
                pv_off = @bitCast(pv_off_u);
                pv_off1 = (pv_off + @"i1");
                pv_off2 = (pv_off + @"i2");
                pv_off3 = (pv_off + @"i3");
                pv0 = @intCast(prev[@intCast(pv_off)]);
                pv1 = @intCast(prev[@intCast(pv_off1)]);
                pv2 = @intCast(prev[@intCast(pv_off2)]);
                pv3 = @intCast(prev[@intCast(pv_off3)]);
                pv1s = (pv1 << @intCast(@"u8"));
                pv2s = (pv2 << @intCast(@"u16"));
                pv3s = (pv3 << @intCast(@"u24"));
                pv01 = (pv0 | pv1s);
                pv012 = (pv01 | pv2s);
                next_u = (pv012 | pv3s);
                candidate = @bitCast(next_u);
            }
        }
        found = (best_distance > @"i0");
        current_length = @"i0";
        current_distance = @"i0";
        if (found) {
            current_length = best_length;
            current_distance = best_distance;
        }
        if (has_saved) {
            later_better = (current_length > saved_length);
            if (later_better) {
                literal_at = (pos - @"i1");
                literal_u = @intCast(data[@intCast(literal_at)]);
                literal = @bitCast(literal_u);
                entry = deflate_token_entry(@"u0", literal, @"i0");
                entry_at = @"i0";
                while (true) {
                    entry_done = (entry_at >= @"i5");
                    if (entry_done) {
                        break;
                    }
                    entry_byte = @intCast(entry[@intCast(entry_at)]);
                    tokens = allocator.realloc(tokens, tokens.len + 1) catch unreachable;
                    tokens[tokens.len - 1] = @truncate(entry_byte);
                    entry_at = (entry_at + @"i1");
                }
                long_ = (current_length >= @"i128");
                if (long_) {
                    entry = deflate_token_entry(@"u1", current_length, current_distance);
                    entry_at = @"i0";
                    while (true) {
                        entry_done = (entry_at >= @"i5");
                        if (entry_done) {
                            break;
                        }
                        entry_byte = @intCast(entry[@intCast(entry_at)]);
                        tokens = allocator.realloc(tokens, tokens.len + 1) catch unreachable;
                        tokens[tokens.len - 1] = @truncate(entry_byte);
                        entry_at = (entry_at + @"i1");
                    }
                    pos = (pos + current_length);
                    saved_length = @"i0";
                    saved_distance = @"i0";
                }
                short_ = (!long_);
                if (short_) {
                    saved_length = current_length;
                    saved_distance = current_distance;
                    pos = (pos + @"i1");
                }
            }
            keep_saved = (!later_better);
            if (keep_saved) {
                entry = deflate_token_entry(@"u1", saved_length, saved_distance);
                entry_at = @"i0";
                while (true) {
                    entry_done = (entry_at >= @"i5");
                    if (entry_done) {
                        break;
                    }
                    entry_byte = @intCast(entry[@intCast(entry_at)]);
                    tokens = allocator.realloc(tokens, tokens.len + 1) catch unreachable;
                    tokens[tokens.len - 1] = @truncate(entry_byte);
                    entry_at = (entry_at + @"i1");
                }
                remaining = (saved_length - @"i1");
                pos = (pos + remaining);
                saved_length = @"i0";
                saved_distance = @"i0";
            }
        }
        no_saved = (!has_saved);
        if (no_saved) {
            has_match = (current_length >= @"i3");
            if (has_match) {
                long_ = (current_length >= @"i128");
                if (long_) {
                    entry = deflate_token_entry(@"u1", current_length, current_distance);
                    entry_at = @"i0";
                    while (true) {
                        entry_done = (entry_at >= @"i5");
                        if (entry_done) {
                            break;
                        }
                        entry_byte = @intCast(entry[@intCast(entry_at)]);
                        tokens = allocator.realloc(tokens, tokens.len + 1) catch unreachable;
                        tokens[tokens.len - 1] = @truncate(entry_byte);
                        entry_at = (entry_at + @"i1");
                    }
                    pos = (pos + current_length);
                }
                short_ = (!long_);
                if (short_) {
                    saved_length = current_length;
                    saved_distance = current_distance;
                    pos = (pos + @"i1");
                }
            }
            no_match = (!has_match);
            if (no_match) {
                literal_u = @intCast(data[@intCast(pos)]);
                literal = @bitCast(literal_u);
                entry = deflate_token_entry(@"u0", literal, @"i0");
                entry_at = @"i0";
                while (true) {
                    entry_done = (entry_at >= @"i5");
                    if (entry_done) {
                        break;
                    }
                    entry_byte = @intCast(entry[@intCast(entry_at)]);
                    tokens = allocator.realloc(tokens, tokens.len + 1) catch unreachable;
                    tokens[tokens.len - 1] = @truncate(entry_byte);
                    entry_at = (entry_at + @"i1");
                }
                pos = (pos + @"i1");
            }
        }
    }
    pending = (saved_length > @"i0");
    if (pending) {
        entry = deflate_token_entry(@"u1", saved_length, saved_distance);
        entry_at = @"i0";
        while (true) {
            entry_done = (entry_at >= @"i5");
            if (entry_done) {
                break;
            }
            entry_byte = @intCast(entry[@intCast(entry_at)]);
            tokens = allocator.realloc(tokens, tokens.len + 1) catch unreachable;
            tokens[tokens.len - 1] = @truncate(entry_byte);
            entry_at = (entry_at + @"i1");
        }
    }
    return tokens;
}

pub fn deflate_fixed(data: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"i3": i64 = undefined;
    var @"i4": i64 = undefined;
    var @"i5": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u256": u64 = undefined;
    var @"u257": u64 = undefined;
    var @"u258": u64 = undefined;
    var @"u285": u64 = undefined;
    var @"u30": u64 = undefined;
    var out: []u8 = undefined;
    var state: []u8 = undefined;
    var tokens: []u8 = undefined;
    var n: i64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var tag: u64 = undefined;
    var is_match: bool = undefined;
    var value_low_at: i64 = undefined;
    var value_high_at: i64 = undefined;
    var distance_low_at: i64 = undefined;
    var distance_high_at: i64 = undefined;
    var value_low: u64 = undefined;
    var value_high: u64 = undefined;
    var value_high_shifted: u64 = undefined;
    var length_u: u64 = undefined;
    var distance_low: u64 = undefined;
    var distance_high: u64 = undefined;
    var distance_high_shifted: u64 = undefined;
    var distance_u: u64 = undefined;
    var length_symbol: u64 = undefined;
    var last_length: bool = undefined;
    var base: u64 = undefined;
    var extra_count: u64 = undefined;
    var span: u64 = undefined;
    var upper: u64 = undefined;
    var fits: bool = undefined;
    var maximum_length: bool = undefined;
    var length_base_value: u64 = undefined;
    var length_extra_count: u64 = undefined;
    var length_extra_value: u64 = undefined;
    var distance_symbol: u64 = undefined;
    var last_distance: bool = undefined;
    var distance_base_value: u64 = undefined;
    var distance_extra_count: u64 = undefined;
    var distance_span: u64 = undefined;
    var distance_upper: u64 = undefined;
    var distance_fits: bool = undefined;
    var distance_wire: u64 = undefined;
    var distance_base_final: u64 = undefined;
    var distance_extra_final: u64 = undefined;
    var distance_value: u64 = undefined;
    var is_literal: bool = undefined;
    var literal_at: i64 = undefined;
    var literal: u64 = undefined;
    var complete: []u8 = undefined;
    var complete_n: i64 = undefined;
    var drain_at: i64 = undefined;
    var drain_done: bool = undefined;
    var drain_byte: u64 = undefined;
    var state_n: i64 = undefined;
    var tail_at: i64 = undefined;
    var tail_done: bool = undefined;
    var tail_byte: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"i3" = 3;
    @"i4" = 4;
    @"i5" = 5;
    @"u0" = 0;
    @"u1" = 1;
    @"u3" = 3;
    @"u5" = 5;
    @"u8" = 8;
    @"u256" = 256;
    @"u257" = 257;
    @"u258" = 258;
    @"u285" = 285;
    @"u30" = 30;
    out = allocator.alloc(u8, 0) catch unreachable;
    state = allocator.alloc(u8, 0) catch unreachable;
    state = allocator.realloc(state, state.len + 1) catch unreachable;
    state[state.len - 1] = @truncate(@"u0");
    state = deflate_write_bits(state, @"u3", @"u3");
    tokens = deflate_tokens(data);
    n = @intCast(tokens.len);
    pos = @"i0";
    while (true) {
        done = (pos >= n);
        if (done) {
            break;
        }
        tag = @intCast(tokens[@intCast(pos)]);
        is_match = (tag == @"u1");
        if (is_match) {
            value_low_at = (pos + @"i1");
            value_high_at = (pos + @"i2");
            distance_low_at = (pos + @"i3");
            distance_high_at = (pos + @"i4");
            value_low = @intCast(tokens[@intCast(value_low_at)]);
            value_high = @intCast(tokens[@intCast(value_high_at)]);
            value_high_shifted = (value_high << @intCast(@"u8"));
            length_u = (value_low | value_high_shifted);
            distance_low = @intCast(tokens[@intCast(distance_low_at)]);
            distance_high = @intCast(tokens[@intCast(distance_high_at)]);
            distance_high_shifted = (distance_high << @intCast(@"u8"));
            distance_u = (distance_low | distance_high_shifted);
            length_symbol = @"u257";
            while (true) {
                last_length = (length_symbol >= @"u285");
                if (last_length) {
                    break;
                }
                base = length_base(length_symbol);
                extra_count = length_extra(length_symbol);
                span = (@"u1" << @intCast(extra_count));
                upper = (base +% span);
                fits = (length_u < upper);
                if (fits) {
                    break;
                }
                length_symbol = (length_symbol +% @"u1");
            }
            maximum_length = (length_u == @"u258");
            if (maximum_length) {
                length_symbol = @"u285";
            }
            state = deflate_fixed_symbol(state, length_symbol);
            length_base_value = length_base(length_symbol);
            length_extra_count = length_extra(length_symbol);
            length_extra_value = (length_u -% length_base_value);
            state = deflate_write_bits(state, length_extra_value, length_extra_count);
            distance_symbol = @"u0";
            while (true) {
                last_distance = (distance_symbol >= @"u30");
                if (last_distance) {
                    break;
                }
                distance_base_value = distance_base(distance_symbol);
                distance_extra_count = distance_extra(distance_symbol);
                distance_span = (@"u1" << @intCast(distance_extra_count));
                distance_upper = (distance_base_value +% distance_span);
                distance_fits = (distance_u < distance_upper);
                if (distance_fits) {
                    break;
                }
                distance_symbol = (distance_symbol +% @"u1");
            }
            distance_wire = deflate_reverse_code(distance_symbol, @"u5");
            state = deflate_write_bits(state, distance_wire, @"u5");
            distance_base_final = distance_base(distance_symbol);
            distance_extra_final = distance_extra(distance_symbol);
            distance_value = (distance_u -% distance_base_final);
            state = deflate_write_bits(state, distance_value, distance_extra_final);
        }
        is_literal = (!is_match);
        if (is_literal) {
            literal_at = (pos + @"i1");
            literal = @intCast(tokens[@intCast(literal_at)]);
            state = deflate_fixed_symbol(state, literal);
        }
        complete = deflate_drain_complete(state);
        complete_n = @intCast(complete.len);
        drain_at = @"i0";
        while (true) {
            drain_done = (drain_at >= complete_n);
            if (drain_done) {
                break;
            }
            drain_byte = @intCast(complete[@intCast(drain_at)]);
            out = allocator.realloc(out, out.len + 1) catch unreachable;
            out[out.len - 1] = @truncate(drain_byte);
            drain_at = (drain_at + @"i1");
        }
        state = deflate_drain_carry(state);
        pos = (pos + @"i5");
    }
    state = deflate_fixed_symbol(state, @"u256");
    state_n = @intCast(state.len);
    tail_at = @"i1";
    while (true) {
        tail_done = (tail_at >= state_n);
        if (tail_done) {
            break;
        }
        tail_byte = @intCast(state[@intCast(tail_at)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(tail_byte);
        tail_at = (tail_at + @"i1");
    }
    return out;
}

pub fn deflate_u16_zeros(count: u64) []u8 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var out: []u8 = undefined;
    var width: u64 = undefined;
    var at: u64 = undefined;
    var done: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    out = allocator.alloc(u8, 0) catch unreachable;
    width = (count *% @"u2");
    at = @"u0";
    while (true) {
        done = (at >= width);
        if (done) {
            break;
        }
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(@"u0");
        at = (at +% @"u1");
    }
    return out;
}

pub fn deflate_u16_get(data: []const u8, index: u64) u64 {
    var @"i1": i64 = undefined;
    var @"u8": u64 = undefined;
    var @"u2": u64 = undefined;
    var offset_u: u64 = undefined;
    var offset: i64 = undefined;
    var high_at: i64 = undefined;
    var low: u64 = undefined;
    var high: u64 = undefined;
    var shifted: u64 = undefined;
    var value: u64 = undefined;
    @"i1" = 1;
    @"u8" = 8;
    @"u2" = 2;
    offset_u = (index *% @"u2");
    offset = @bitCast(offset_u);
    high_at = (offset + @"i1");
    low = @intCast(data[@intCast(offset)]);
    high = @intCast(data[@intCast(high_at)]);
    shifted = (high << @intCast(@"u8"));
    value = (low | shifted);
    return value;
}

pub fn deflate_u16_set(data: []const u8, index: u64, value: u64) []u8 {
    var @"i1": i64 = undefined;
    var @"u2": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"i0": i64 = undefined;
    var out: []u8 = undefined;
    var n: i64 = undefined;
    var copy_at: i64 = undefined;
    var copy_done: bool = undefined;
    var copy_byte: u64 = undefined;
    var offset_u: u64 = undefined;
    var offset: i64 = undefined;
    var high_at: i64 = undefined;
    var low: u64 = undefined;
    var shifted: u64 = undefined;
    var high: u64 = undefined;
    @"i1" = 1;
    @"u2" = 2;
    @"u8" = 8;
    @"u255" = 255;
    @"i0" = 0;
    out = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(data.len);
    copy_at = @"i0";
    while (true) {
        copy_done = (copy_at >= n);
        if (copy_done) {
            break;
        }
        copy_byte = @intCast(data[@intCast(copy_at)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(copy_byte);
        copy_at = (copy_at + @"i1");
    }
    offset_u = (index *% @"u2");
    offset = @bitCast(offset_u);
    high_at = (offset + @"i1");
    low = (value & @"u255");
    shifted = (value >> @intCast(@"u8"));
    high = (shifted & @"u255");
    out[@intCast(offset)] = @truncate(low);
    out[@intCast(high_at)] = @truncate(high);
    return out;
}

pub fn deflate_u16_increment(data: []const u8, index: u64, amount: u64) []u8 {
    var @"u65535": u64 = undefined;
    var old: u64 = undefined;
    var sum: u64 = undefined;
    var wrapped: u64 = undefined;
    var out: []u8 = undefined;
    @"u65535" = 65535;
    old = deflate_u16_get(data, index);
    sum = (old +% amount);
    wrapped = (sum & @"u65535");
    out = deflate_u16_set(data, index, wrapped);
    return out;
}

pub fn deflate_record_key_get(records: []const u8, record: u64) u64 {
    var @"u2": u64 = undefined;
    var word: u64 = undefined;
    var key: u64 = undefined;
    @"u2" = 2;
    word = (record *% @"u2");
    key = deflate_u16_get(records, word);
    return key;
}

pub fn deflate_record_key_set(records: []const u8, record: u64, key: u64) []u8 {
    var @"u2": u64 = undefined;
    var word: u64 = undefined;
    var out: []u8 = undefined;
    @"u2" = 2;
    word = (record *% @"u2");
    out = deflate_u16_set(records, word, key);
    return out;
}

pub fn deflate_optimized_lengths(counts: []const u8, table_len: u64, limit: u64) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"i3": i64 = undefined;
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u33": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"u65535": u64 = undefined;
    var used: []u8 = undefined;
    var used_count: u64 = undefined;
    var symbol: u64 = undefined;
    var done: bool = undefined;
    var frequency: u64 = undefined;
    var present: bool = undefined;
    var frequency_low: u64 = undefined;
    var frequency_shifted: u64 = undefined;
    var frequency_high: u64 = undefined;
    var symbol_low: u64 = undefined;
    var symbol_shifted: u64 = undefined;
    var symbol_high: u64 = undefined;
    var used_count_i: i64 = undefined;
    var chosen: []u8 = undefined;
    var chosen_at: u64 = undefined;
    var chosen_done: bool = undefined;
    var sorted: []u8 = undefined;
    var slot: u64 = undefined;
    var sorted_done: bool = undefined;
    var scan: u64 = undefined;
    var best_index: u64 = undefined;
    var best_frequency: u64 = undefined;
    var have_best: u64 = undefined;
    var scan_done: bool = undefined;
    var scan_i: i64 = undefined;
    var already: u64 = undefined;
    var unchosen: bool = undefined;
    var record_u: u64 = undefined;
    var scan_record: i64 = undefined;
    var record_high: i64 = undefined;
    var low: u64 = undefined;
    var high: u64 = undefined;
    var high_shifted: u64 = undefined;
    var first_candidate: bool = undefined;
    var lower: bool = undefined;
    var take: bool = undefined;
    var best_i: i64 = undefined;
    var best_record_u: u64 = undefined;
    var best_record: i64 = undefined;
    var copy_: i64 = undefined;
    var copy_done: bool = undefined;
    var source: i64 = undefined;
    var byte_: u64 = undefined;
    var one: bool = undefined;
    var many: bool = undefined;
    var f0: u64 = undefined;
    var f1: u64 = undefined;
    var initial_sum: u64 = undefined;
    var initial_wrapped: u64 = undefined;
    var root: u64 = undefined;
    var leaf: u64 = undefined;
    var next_: u64 = undefined;
    var last_internal: u64 = undefined;
    var merge_done: bool = undefined;
    var leaf_end: bool = undefined;
    var take_root: bool = undefined;
    var leaf_available: bool = undefined;
    var root_key: u64 = undefined;
    var leaf_key: u64 = undefined;
    var root_lower: bool = undefined;
    var take_leaf: bool = undefined;
    var leaf_end2: bool = undefined;
    var take_root2: bool = undefined;
    var leaf_available2: bool = undefined;
    var root_before_next: bool = undefined;
    var root_key2: u64 = undefined;
    var leaf_key2: u64 = undefined;
    var root_lower2: bool = undefined;
    var next_key: u64 = undefined;
    var combined: u64 = undefined;
    var combined_wrapped: u64 = undefined;
    var take_leaf2: bool = undefined;
    var n_minus2: u64 = undefined;
    var back: u64 = undefined;
    var back_done: bool = undefined;
    var parent: u64 = undefined;
    var parent_depth: u64 = undefined;
    var depth: u64 = undefined;
    var slots_available: u64 = undefined;
    var used_here: u64 = undefined;
    var root_i: i64 = undefined;
    var next_i: i64 = undefined;
    var assign_done: bool = undefined;
    var root_negative: bool = undefined;
    var root_u: u64 = undefined;
    var root_depth: u64 = undefined;
    var different_depth: bool = undefined;
    var enough: bool = undefined;
    var next_u: u64 = undefined;
    var num_codes: []u8 = undefined;
    var count_record: u64 = undefined;
    var count_record_done: bool = undefined;
    var count_depth: u64 = undefined;
    var over: u64 = undefined;
    var over_sum: u64 = undefined;
    var over_done: bool = undefined;
    var amount: u64 = undefined;
    var limit_count: u64 = undefined;
    var limit_total: u64 = undefined;
    var total: u64 = undefined;
    var width: u64 = undefined;
    var width_done: bool = undefined;
    var count: u64 = undefined;
    var shift: u64 = undefined;
    var weighted: u64 = undefined;
    var capacity: u64 = undefined;
    var balanced: bool = undefined;
    var limit_less: u64 = undefined;
    var seek: u64 = undefined;
    var seek_count: u64 = undefined;
    var found: bool = undefined;
    var seek_less: u64 = undefined;
    var deeper: u64 = undefined;
    var deeper_count: u64 = undefined;
    var deeper_more: u64 = undefined;
    var lengths: []u8 = undefined;
    var fill: u64 = undefined;
    var fill_done: bool = undefined;
    var last: u64 = undefined;
    var length_first: u64 = undefined;
    var length_record: u64 = undefined;
    var length_record_done: bool = undefined;
    var record_base_u: u64 = undefined;
    var record_base: i64 = undefined;
    var symbol_low_at: i64 = undefined;
    var symbol_high_at: i64 = undefined;
    var symbol_high_shifted: u64 = undefined;
    var symbol_u: u64 = undefined;
    var symbol_i: i64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"i3" = 3;
    @"i4" = 4;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u4" = 4;
    @"u8" = 8;
    @"u33" = 33;
    @"u255" = 255;
    @"u65535" = 65535;
    used = allocator.alloc(u8, 0) catch unreachable;
    used_count = @"u0";
    symbol = @"u0";
    while (true) {
        done = (symbol >= table_len);
        if (done) {
            break;
        }
        frequency = deflate_u16_get(counts, symbol);
        present = (frequency != @"u0");
        if (present) {
            frequency_low = (frequency & @"u255");
            frequency_shifted = (frequency >> @intCast(@"u8"));
            frequency_high = (frequency_shifted & @"u255");
            symbol_low = (symbol & @"u255");
            symbol_shifted = (symbol >> @intCast(@"u8"));
            symbol_high = (symbol_shifted & @"u255");
            used = allocator.realloc(used, used.len + 1) catch unreachable;
            used[used.len - 1] = @truncate(frequency_low);
            used = allocator.realloc(used, used.len + 1) catch unreachable;
            used[used.len - 1] = @truncate(frequency_high);
            used = allocator.realloc(used, used.len + 1) catch unreachable;
            used[used.len - 1] = @truncate(symbol_low);
            used = allocator.realloc(used, used.len + 1) catch unreachable;
            used[used.len - 1] = @truncate(symbol_high);
            used_count = (used_count +% @"u1");
        }
        symbol = (symbol +% @"u1");
    }
    used_count_i = @bitCast(used_count);
    chosen = allocator.alloc(u8, 0) catch unreachable;
    chosen_at = @"u0";
    while (true) {
        chosen_done = (chosen_at >= used_count);
        if (chosen_done) {
            break;
        }
        chosen = allocator.realloc(chosen, chosen.len + 1) catch unreachable;
        chosen[chosen.len - 1] = @truncate(@"u0");
        chosen_at = (chosen_at +% @"u1");
    }
    sorted = allocator.alloc(u8, 0) catch unreachable;
    slot = @"u0";
    while (true) {
        sorted_done = (slot >= used_count);
        if (sorted_done) {
            break;
        }
        scan = @"u0";
        best_index = @"u0";
        best_frequency = @"u65535";
        have_best = @"u0";
        while (true) {
            scan_done = (scan >= used_count);
            if (scan_done) {
                break;
            }
            scan_i = @bitCast(scan);
            already = @intCast(chosen[@intCast(scan_i)]);
            unchosen = (already == @"u0");
            if (unchosen) {
                record_u = (scan *% @"u4");
                scan_record = @bitCast(record_u);
                record_high = (scan_record + @"i1");
                low = @intCast(used[@intCast(scan_record)]);
                high = @intCast(used[@intCast(record_high)]);
                high_shifted = (high << @intCast(@"u8"));
                frequency = (low | high_shifted);
                first_candidate = (have_best == @"u0");
                lower = (frequency < best_frequency);
                take = (first_candidate or lower);
                if (take) {
                    best_index = scan;
                    best_frequency = frequency;
                    have_best = @"u1";
                }
            }
            scan = (scan +% @"u1");
        }
        best_i = @bitCast(best_index);
        chosen[@intCast(best_i)] = @truncate(@"u1");
        best_record_u = (best_index *% @"u4");
        best_record = @bitCast(best_record_u);
        copy_ = @"i0";
        while (true) {
            copy_done = (copy_ >= @"i4");
            if (copy_done) {
                break;
            }
            source = (best_record + copy_);
            byte_ = @intCast(used[@intCast(source)]);
            sorted = allocator.realloc(sorted, sorted.len + 1) catch unreachable;
            sorted[sorted.len - 1] = @truncate(byte_);
            copy_ = (copy_ + @"i1");
        }
        slot = (slot +% @"u1");
    }
    one = (used_count == @"u1");
    if (one) {
        sorted[@intCast(@"i0")] = @truncate(@"u1");
        sorted[@intCast(@"i1")] = @truncate(@"u0");
    }
    many = (used_count > @"u1");
    if (many) {
        f0 = deflate_record_key_get(sorted, @"u0");
        f1 = deflate_record_key_get(sorted, @"u1");
        initial_sum = (f0 +% f1);
        initial_wrapped = (initial_sum & @"u65535");
        sorted = deflate_record_key_set(sorted, @"u0", initial_wrapped);
        root = @"u0";
        leaf = @"u2";
        next_ = @"u1";
        last_internal = (used_count -% @"u1");
        while (true) {
            merge_done = (next_ >= last_internal);
            if (merge_done) {
                break;
            }
            leaf_end = (leaf >= used_count);
            take_root = leaf_end;
            leaf_available = (!leaf_end);
            if (leaf_available) {
                root_key = deflate_record_key_get(sorted, root);
                leaf_key = deflate_record_key_get(sorted, leaf);
                root_lower = (root_key < leaf_key);
                take_root = root_lower;
            }
            if (take_root) {
                root_key = deflate_record_key_get(sorted, root);
                sorted = deflate_record_key_set(sorted, next_, root_key);
                sorted = deflate_record_key_set(sorted, root, next_);
                root = (root +% @"u1");
            }
            take_leaf = (!take_root);
            if (take_leaf) {
                leaf_key = deflate_record_key_get(sorted, leaf);
                sorted = deflate_record_key_set(sorted, next_, leaf_key);
                leaf = (leaf +% @"u1");
            }
            leaf_end2 = (leaf >= used_count);
            take_root2 = leaf_end2;
            leaf_available2 = (!leaf_end2);
            if (leaf_available2) {
                root_before_next = (root < next_);
                if (root_before_next) {
                    root_key2 = deflate_record_key_get(sorted, root);
                    leaf_key2 = deflate_record_key_get(sorted, leaf);
                    root_lower2 = (root_key2 < leaf_key2);
                    take_root2 = root_lower2;
                }
            }
            next_key = deflate_record_key_get(sorted, next_);
            if (take_root2) {
                root_key2 = deflate_record_key_get(sorted, root);
                combined = (next_key +% root_key2);
                combined_wrapped = (combined & @"u65535");
                sorted = deflate_record_key_set(sorted, next_, combined_wrapped);
                sorted = deflate_record_key_set(sorted, root, next_);
                root = (root +% @"u1");
            }
            take_leaf2 = (!take_root2);
            if (take_leaf2) {
                leaf_key2 = deflate_record_key_get(sorted, leaf);
                combined = (next_key +% leaf_key2);
                combined_wrapped = (combined & @"u65535");
                sorted = deflate_record_key_set(sorted, next_, combined_wrapped);
                leaf = (leaf +% @"u1");
            }
            next_ = (next_ +% @"u1");
        }
        n_minus2 = (used_count -% @"u2");
        sorted = deflate_record_key_set(sorted, n_minus2, @"u0");
        back = n_minus2;
        while (true) {
            back_done = (back == @"u0");
            if (back_done) {
                break;
            }
            back = (back -% @"u1");
            parent = deflate_record_key_get(sorted, back);
            parent_depth = deflate_record_key_get(sorted, parent);
            depth = (parent_depth +% @"u1");
            sorted = deflate_record_key_set(sorted, back, depth);
        }
        slots_available = @"u1";
        used_here = @"u0";
        depth = @"u0";
        root_i = @bitCast(n_minus2);
        next_i = (used_count_i - @"i1");
        while (true) {
            assign_done = (slots_available == @"u0");
            if (assign_done) {
                break;
            }
            while (true) {
                root_negative = (root_i < @"i0");
                if (root_negative) {
                    break;
                }
                root_u = @bitCast(root_i);
                root_depth = deflate_record_key_get(sorted, root_u);
                different_depth = (root_depth != depth);
                if (different_depth) {
                    break;
                }
                used_here = (used_here +% @"u1");
                root_i = (root_i - @"i1");
            }
            while (true) {
                enough = (slots_available <= used_here);
                if (enough) {
                    break;
                }
                next_u = @bitCast(next_i);
                sorted = deflate_record_key_set(sorted, next_u, depth);
                next_i = (next_i - @"i1");
                slots_available = (slots_available -% @"u1");
            }
            slots_available = (used_here *% @"u2");
            depth = (depth +% @"u1");
            used_here = @"u0";
        }
    }
    num_codes = deflate_u16_zeros(@"u33");
    count_record = @"u0";
    while (true) {
        count_record_done = (count_record >= used_count);
        if (count_record_done) {
            break;
        }
        count_depth = deflate_record_key_get(sorted, count_record);
        num_codes = deflate_u16_increment(num_codes, count_depth, @"u1");
        count_record = (count_record +% @"u1");
    }
    over = (limit +% @"u1");
    over_sum = @"u0";
    while (true) {
        over_done = (over >= @"u33");
        if (over_done) {
            break;
        }
        amount = deflate_u16_get(num_codes, over);
        over_sum = (over_sum +% amount);
        over = (over +% @"u1");
    }
    limit_count = deflate_u16_get(num_codes, limit);
    limit_total = (limit_count +% over_sum);
    num_codes = deflate_u16_set(num_codes, limit, limit_total);
    total = @"u0";
    width = @"u1";
    while (true) {
        width_done = (width > limit);
        if (width_done) {
            break;
        }
        count = deflate_u16_get(num_codes, width);
        shift = (limit -% width);
        weighted = (count << @intCast(shift));
        total = (total +% weighted);
        width = (width +% @"u1");
    }
    capacity = (@"u1" << @intCast(limit));
    while (true) {
        balanced = (total <= capacity);
        if (balanced) {
            break;
        }
        limit_count = deflate_u16_get(num_codes, limit);
        limit_less = (limit_count -% @"u1");
        num_codes = deflate_u16_set(num_codes, limit, limit_less);
        seek = (limit -% @"u1");
        while (true) {
            seek_count = deflate_u16_get(num_codes, seek);
            found = (seek_count != @"u0");
            if (found) {
                seek_less = (seek_count -% @"u1");
                num_codes = deflate_u16_set(num_codes, seek, seek_less);
                deeper = (seek +% @"u1");
                deeper_count = deflate_u16_get(num_codes, deeper);
                deeper_more = (deeper_count +% @"u2");
                num_codes = deflate_u16_set(num_codes, deeper, deeper_more);
                break;
            }
            seek = (seek -% @"u1");
        }
        total = (total -% @"u1");
    }
    lengths = allocator.alloc(u8, 0) catch unreachable;
    fill = @"u0";
    while (true) {
        fill_done = (fill >= table_len);
        if (fill_done) {
            break;
        }
        lengths = allocator.realloc(lengths, lengths.len + 1) catch unreachable;
        lengths[lengths.len - 1] = @truncate(@"u0");
        fill = (fill +% @"u1");
    }
    last = used_count;
    width = @"u1";
    while (true) {
        width_done = (width > limit);
        if (width_done) {
            break;
        }
        amount = deflate_u16_get(num_codes, width);
        length_first = (last -% amount);
        length_record = length_first;
        while (true) {
            length_record_done = (length_record >= last);
            if (length_record_done) {
                break;
            }
            record_base_u = (length_record *% @"u4");
            record_base = @bitCast(record_base_u);
            symbol_low_at = (record_base + @"i2");
            symbol_high_at = (record_base + @"i3");
            symbol_low = @intCast(sorted[@intCast(symbol_low_at)]);
            symbol_high = @intCast(sorted[@intCast(symbol_high_at)]);
            symbol_high_shifted = (symbol_high << @intCast(@"u8"));
            symbol_u = (symbol_low | symbol_high_shifted);
            symbol_i = @bitCast(symbol_u);
            lengths[@intCast(symbol_i)] = @truncate(width);
            length_record = (length_record +% @"u1");
        }
        last = length_first;
        width = (width +% @"u1");
    }
    return lengths;
}

pub fn deflate_canonical_codes(lengths: []const u8, max_bits: u64) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var counts: []u8 = undefined;
    var counts_head: []u8 = undefined;
    var n: i64 = undefined;
    var at: i64 = undefined;
    var count_done: bool = undefined;
    var width: u64 = undefined;
    var coded: bool = undefined;
    var next_count: u64 = undefined;
    var next_: []u8 = undefined;
    var code: u64 = undefined;
    var next_done: bool = undefined;
    var previous: u64 = undefined;
    var previous_count: u64 = undefined;
    var sum: u64 = undefined;
    var n_u: u64 = undefined;
    var codes: []u8 = undefined;
    var symbol: i64 = undefined;
    var codes_done: bool = undefined;
    var canonical: u64 = undefined;
    var wire: u64 = undefined;
    var symbol_u: u64 = undefined;
    var canonical_next: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    counts = deflate_u16_zeros(max_bits);
    counts_head = allocator.alloc(u8, 0) catch unreachable;
    counts_head = allocator.realloc(counts_head, counts_head.len + 1) catch unreachable;
    counts_head[counts_head.len - 1] = @truncate(@"u0");
    counts_head = allocator.realloc(counts_head, counts_head.len + 1) catch unreachable;
    counts_head[counts_head.len - 1] = @truncate(@"u0");
    counts = append_bytes(counts_head, counts);
    n = @intCast(lengths.len);
    at = @"i0";
    while (true) {
        count_done = (at >= n);
        if (count_done) {
            break;
        }
        width = @intCast(lengths[@intCast(at)]);
        coded = (width != @"u0");
        if (coded) {
            counts = deflate_u16_increment(counts, width, @"u1");
        }
        at = (at + @"i1");
    }
    next_count = (max_bits +% @"u1");
    next_ = deflate_u16_zeros(next_count);
    code = @"u0";
    width = 2;
    while (true) {
        next_done = (width > max_bits);
        if (next_done) {
            break;
        }
        previous = (width -% @"u1");
        previous_count = deflate_u16_get(counts, previous);
        sum = (code +% previous_count);
        code = (sum << @intCast(@"u1"));
        next_ = deflate_u16_set(next_, width, code);
        width = (width +% @"u1");
    }
    n_u = @bitCast(n);
    codes = deflate_u16_zeros(n_u);
    symbol = @"i0";
    while (true) {
        codes_done = (symbol >= n);
        if (codes_done) {
            break;
        }
        width = @intCast(lengths[@intCast(symbol)]);
        coded = (width != @"u0");
        if (coded) {
            canonical = deflate_u16_get(next_, width);
            wire = deflate_reverse_code(canonical, width);
            symbol_u = @bitCast(symbol);
            codes = deflate_u16_set(codes, symbol_u, wire);
            canonical_next = (canonical +% @"u1");
            next_ = deflate_u16_set(next_, width, canonical_next);
        }
        symbol = (symbol + @"i1");
    }
    return codes;
}

pub fn deflate_pack_code_lengths(lengths: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u6": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u11": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u17": u64 = undefined;
    var @"u18": u64 = undefined;
    var @"u19": u64 = undefined;
    var @"u138": u64 = undefined;
    var counts: []u8 = undefined;
    var packed_: []u8 = undefined;
    var n: i64 = undefined;
    var at: i64 = undefined;
    var done: bool = undefined;
    var width: u64 = undefined;
    var zero: bool = undefined;
    var run: u64 = undefined;
    var scan: i64 = undefined;
    var scan_end: bool = undefined;
    var run_full: bool = undefined;
    var stop: bool = undefined;
    var next_width: u64 = undefined;
    var different: bool = undefined;
    var short_: bool = undefined;
    var left: u64 = undefined;
    var emitted: bool = undefined;
    var not_short: bool = undefined;
    var medium: bool = undefined;
    var extra: u64 = undefined;
    var long_: bool = undefined;
    var run_i: i64 = undefined;
    var nonzero: bool = undefined;
    var repeat: u64 = undefined;
    var repeat_done: bool = undefined;
    var chunk_full: bool = undefined;
    var repeat_short: bool = undefined;
    var repeat_long: bool = undefined;
    var out: []u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u3" = 3;
    @"u6" = 6;
    @"u10" = 10;
    @"u11" = 11;
    @"u16" = 16;
    @"u17" = 17;
    @"u18" = 18;
    @"u19" = 19;
    @"u138" = 138;
    counts = deflate_u16_zeros(@"u19");
    packed_ = allocator.alloc(u8, 0) catch unreachable;
    n = @intCast(lengths.len);
    at = @"i0";
    while (true) {
        done = (at >= n);
        if (done) {
            break;
        }
        width = @intCast(lengths[@intCast(at)]);
        zero = (width == @"u0");
        if (zero) {
            run = @"u1";
            scan = (at + @"i1");
            while (true) {
                scan_end = (scan >= n);
                run_full = (run >= @"u138");
                stop = (scan_end or run_full);
                if (stop) {
                    break;
                }
                next_width = @intCast(lengths[@intCast(scan)]);
                different = (next_width != @"u0");
                if (different) {
                    break;
                }
                run = (run +% @"u1");
                scan = (scan + @"i1");
            }
            short_ = (run < @"u3");
            if (short_) {
                left = run;
                while (true) {
                    emitted = (left == @"u0");
                    if (emitted) {
                        break;
                    }
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(@"u0");
                    counts = deflate_u16_increment(counts, @"u0", @"u1");
                    left = (left -% @"u1");
                }
            }
            not_short = (!short_);
            if (not_short) {
                medium = (run <= @"u10");
                if (medium) {
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(@"u17");
                    extra = (run -% @"u3");
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(extra);
                    counts = deflate_u16_increment(counts, @"u17", @"u1");
                }
                long_ = (!medium);
                if (long_) {
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(@"u18");
                    extra = (run -% @"u11");
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(extra);
                    counts = deflate_u16_increment(counts, @"u18", @"u1");
                }
            }
            run_i = @bitCast(run);
            at = (at + run_i);
        }
        nonzero = (!zero);
        if (nonzero) {
            packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
            packed_[packed_.len - 1] = @truncate(width);
            counts = deflate_u16_increment(counts, width, @"u1");
            at = (at + @"i1");
            repeat = @"u0";
            while (true) {
                repeat_done = (at >= n);
                if (repeat_done) {
                    break;
                }
                next_width = @intCast(lengths[@intCast(at)]);
                different = (next_width != width);
                if (different) {
                    break;
                }
                repeat = (repeat +% @"u1");
                at = (at + @"i1");
                chunk_full = (repeat == @"u6");
                if (chunk_full) {
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(@"u16");
                    extra = (repeat -% @"u3");
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(extra);
                    counts = deflate_u16_increment(counts, @"u16", @"u1");
                    repeat = @"u0";
                }
            }
            repeat_short = (repeat < @"u3");
            if (repeat_short) {
                left = repeat;
                while (true) {
                    emitted = (left == @"u0");
                    if (emitted) {
                        break;
                    }
                    packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                    packed_[packed_.len - 1] = @truncate(width);
                    counts = deflate_u16_increment(counts, width, @"u1");
                    left = (left -% @"u1");
                }
            }
            repeat_long = (repeat >= @"u3");
            if (repeat_long) {
                packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                packed_[packed_.len - 1] = @truncate(@"u16");
                extra = (repeat -% @"u3");
                packed_ = allocator.realloc(packed_, packed_.len + 1) catch unreachable;
                packed_[packed_.len - 1] = @truncate(extra);
                counts = deflate_u16_increment(counts, @"u16", @"u1");
            }
        }
    }
    out = append_bytes(counts, packed_);
    return out;
}

pub fn deflate_huffman_symbol(state: []const u8, codes: []const u8, lengths: []const u8, symbol: u64) []u8 {
    var symbol_i: i64 = undefined;
    var width: u64 = undefined;
    var code: u64 = undefined;
    var out: []u8 = undefined;
    symbol_i = @bitCast(symbol);
    width = @intCast(lengths[@intCast(symbol_i)]);
    code = deflate_u16_get(codes, symbol);
    out = deflate_write_bits(state, code, width);
    return out;
}

pub fn deflate_match_symbols(length: u64, distance: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u30": u64 = undefined;
    var @"u32": u64 = undefined;
    var @"u257": u64 = undefined;
    var @"u258": u64 = undefined;
    var @"u285": u64 = undefined;
    var length_symbol: u64 = undefined;
    var last_length: bool = undefined;
    var base: u64 = undefined;
    var extra_count: u64 = undefined;
    var span: u64 = undefined;
    var upper: u64 = undefined;
    var fits: bool = undefined;
    var maximum_length: bool = undefined;
    var distance_symbol: u64 = undefined;
    var last_distance: bool = undefined;
    var length_high: u64 = undefined;
    var packed_: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u30" = 30;
    @"u32" = 32;
    @"u257" = 257;
    @"u258" = 258;
    @"u285" = 285;
    length_symbol = @"u257";
    while (true) {
        last_length = (length_symbol >= @"u285");
        if (last_length) {
            break;
        }
        base = length_base(length_symbol);
        extra_count = length_extra(length_symbol);
        span = (@"u1" << @intCast(extra_count));
        upper = (base +% span);
        fits = (length < upper);
        if (fits) {
            break;
        }
        length_symbol = (length_symbol +% @"u1");
    }
    maximum_length = (length == @"u258");
    if (maximum_length) {
        length_symbol = @"u285";
    }
    distance_symbol = @"u0";
    while (true) {
        last_distance = (distance_symbol >= @"u30");
        if (last_distance) {
            break;
        }
        base = distance_base(distance_symbol);
        extra_count = distance_extra(distance_symbol);
        span = (@"u1" << @intCast(extra_count));
        upper = (base +% span);
        fits = (distance < upper);
        if (fits) {
            break;
        }
        distance_symbol = (distance_symbol +% @"u1");
    }
    length_high = (length_symbol << @intCast(@"u32"));
    packed_ = (length_high | distance_symbol);
    return packed_;
}

pub fn deflate_dynamic(data: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"i3": i64 = undefined;
    var @"i4": i64 = undefined;
    var @"i5": i64 = undefined;
    var @"i38": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u15": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u19": u64 = undefined;
    var @"u30": u64 = undefined;
    var @"u32": u64 = undefined;
    var @"u256": u64 = undefined;
    var @"u257": u64 = undefined;
    var @"u286": u64 = undefined;
    var @"u288": u64 = undefined;
    var @"u4294967295": u64 = undefined;
    var tokens: []u8 = undefined;
    var lit_counts: []u8 = undefined;
    var dist_counts: []u8 = undefined;
    var tokens_n: i64 = undefined;
    var token_at: i64 = undefined;
    var count_done: bool = undefined;
    var tag: u64 = undefined;
    var match_: bool = undefined;
    var value_low_at: i64 = undefined;
    var value_high_at: i64 = undefined;
    var distance_low_at: i64 = undefined;
    var distance_high_at: i64 = undefined;
    var value_low: u64 = undefined;
    var value_high: u64 = undefined;
    var value_high_shifted: u64 = undefined;
    var length: u64 = undefined;
    var distance_low: u64 = undefined;
    var distance_high: u64 = undefined;
    var distance_high_shifted: u64 = undefined;
    var distance: u64 = undefined;
    var symbols: u64 = undefined;
    var length_symbol: u64 = undefined;
    var distance_symbol: u64 = undefined;
    var literal: bool = undefined;
    var literal_at: i64 = undefined;
    var literal_symbol: u64 = undefined;
    var lit_lengths: []u8 = undefined;
    var dist_lengths: []u8 = undefined;
    var lit_codes: []u8 = undefined;
    var dist_codes: []u8 = undefined;
    var num_lit: u64 = undefined;
    var minimum_lit: bool = undefined;
    var last_lit: u64 = undefined;
    var last_lit_i: i64 = undefined;
    var last_width: u64 = undefined;
    var used_lit: bool = undefined;
    var num_dist: u64 = undefined;
    var minimum_dist: bool = undefined;
    var last_dist: u64 = undefined;
    var last_dist_i: i64 = undefined;
    var used_dist: bool = undefined;
    var num_lit_i: i64 = undefined;
    var num_dist_i: i64 = undefined;
    var packed_lit_lengths: []u8 = undefined;
    var packed_dist_lengths: []u8 = undefined;
    var sizes: []u8 = undefined;
    var packed_bundle: []u8 = undefined;
    var bundle_n: i64 = undefined;
    var cl_counts: []u8 = undefined;
    var packed_: []u8 = undefined;
    var cl_lengths: []u8 = undefined;
    var cl_codes: []u8 = undefined;
    var order: []u8 = undefined;
    var num_bit_lengths: u64 = undefined;
    var minimum_cl: bool = undefined;
    var order_at: u64 = undefined;
    var order_at_i: i64 = undefined;
    var cl_symbol: u64 = undefined;
    var cl_symbol_i: i64 = undefined;
    var cl_width: u64 = undefined;
    var used_cl: bool = undefined;
    var out: []u8 = undefined;
    var state: []u8 = undefined;
    var hlit: u64 = undefined;
    var hdist: u64 = undefined;
    var hclen: u64 = undefined;
    var order_done: bool = undefined;
    var packed_n: i64 = undefined;
    var packed_at: i64 = undefined;
    var packed_done: bool = undefined;
    var has_extra: bool = undefined;
    var extra: u64 = undefined;
    var extra_index: u64 = undefined;
    var extra_width: u64 = undefined;
    var is17: bool = undefined;
    var is18: bool = undefined;
    var emit_done: bool = undefined;
    var length_base_value: u64 = undefined;
    var length_extra_width: u64 = undefined;
    var length_extra_value: u64 = undefined;
    var distance_base_value: u64 = undefined;
    var distance_extra_width: u64 = undefined;
    var distance_extra_value: u64 = undefined;
    var complete: []u8 = undefined;
    var complete_n: i64 = undefined;
    var drain_at: i64 = undefined;
    var drain_done: bool = undefined;
    var drain_byte: u64 = undefined;
    var state_n: i64 = undefined;
    var tail_at: i64 = undefined;
    var tail_done: bool = undefined;
    var tail_byte: u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"i3" = 3;
    @"i4" = 4;
    @"i5" = 5;
    @"i38" = 38;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u5" = 5;
    @"u7" = 7;
    @"u8" = 8;
    @"u15" = 15;
    @"u16" = 16;
    @"u19" = 19;
    @"u30" = 30;
    @"u32" = 32;
    @"u256" = 256;
    @"u257" = 257;
    @"u286" = 286;
    @"u288" = 288;
    @"u4294967295" = 4294967295;
    tokens = deflate_tokens(data);
    lit_counts = deflate_u16_zeros(@"u288");
    dist_counts = deflate_u16_zeros(@"u32");
    tokens_n = @intCast(tokens.len);
    token_at = @"i0";
    while (true) {
        count_done = (token_at >= tokens_n);
        if (count_done) {
            break;
        }
        tag = @intCast(tokens[@intCast(token_at)]);
        match_ = (tag == @"u1");
        if (match_) {
            value_low_at = (token_at + @"i1");
            value_high_at = (token_at + @"i2");
            distance_low_at = (token_at + @"i3");
            distance_high_at = (token_at + @"i4");
            value_low = @intCast(tokens[@intCast(value_low_at)]);
            value_high = @intCast(tokens[@intCast(value_high_at)]);
            value_high_shifted = (value_high << @intCast(@"u8"));
            length = (value_low | value_high_shifted);
            distance_low = @intCast(tokens[@intCast(distance_low_at)]);
            distance_high = @intCast(tokens[@intCast(distance_high_at)]);
            distance_high_shifted = (distance_high << @intCast(@"u8"));
            distance = (distance_low | distance_high_shifted);
            symbols = deflate_match_symbols(length, distance);
            length_symbol = (symbols >> @intCast(@"u32"));
            distance_symbol = (symbols & @"u4294967295");
            lit_counts = deflate_u16_increment(lit_counts, length_symbol, @"u1");
            dist_counts = deflate_u16_increment(dist_counts, distance_symbol, @"u1");
        }
        literal = (!match_);
        if (literal) {
            literal_at = (token_at + @"i1");
            literal_symbol = @intCast(tokens[@intCast(literal_at)]);
            lit_counts = deflate_u16_increment(lit_counts, literal_symbol, @"u1");
        }
        token_at = (token_at + @"i5");
    }
    lit_counts = deflate_u16_set(lit_counts, @"u256", @"u1");
    lit_lengths = deflate_optimized_lengths(lit_counts, @"u288", @"u15");
    dist_lengths = deflate_optimized_lengths(dist_counts, @"u32", @"u15");
    lit_codes = deflate_canonical_codes(lit_lengths, @"u15");
    dist_codes = deflate_canonical_codes(dist_lengths, @"u15");
    num_lit = @"u286";
    while (true) {
        minimum_lit = (num_lit <= @"u257");
        if (minimum_lit) {
            break;
        }
        last_lit = (num_lit -% @"u1");
        last_lit_i = @bitCast(last_lit);
        last_width = @intCast(lit_lengths[@intCast(last_lit_i)]);
        used_lit = (last_width != @"u0");
        if (used_lit) {
            break;
        }
        num_lit = last_lit;
    }
    num_dist = @"u30";
    while (true) {
        minimum_dist = (num_dist <= @"u1");
        if (minimum_dist) {
            break;
        }
        last_dist = (num_dist -% @"u1");
        last_dist_i = @bitCast(last_dist);
        last_width = @intCast(dist_lengths[@intCast(last_dist_i)]);
        used_dist = (last_width != @"u0");
        if (used_dist) {
            break;
        }
        num_dist = last_dist;
    }
    num_lit_i = @bitCast(num_lit);
    num_dist_i = @bitCast(num_dist);
    packed_lit_lengths = allocator.dupe(u8, lit_lengths[@intCast(@"i0")..@intCast(num_lit_i)]) catch unreachable;
    packed_dist_lengths = allocator.dupe(u8, dist_lengths[@intCast(@"i0")..@intCast(num_dist_i)]) catch unreachable;
    sizes = append_bytes(packed_lit_lengths, packed_dist_lengths);
    packed_bundle = deflate_pack_code_lengths(sizes);
    bundle_n = @intCast(packed_bundle.len);
    cl_counts = allocator.dupe(u8, packed_bundle[@intCast(@"i0")..@intCast(@"i38")]) catch unreachable;
    packed_ = allocator.dupe(u8, packed_bundle[@intCast(@"i38")..@intCast(bundle_n)]) catch unreachable;
    cl_lengths = deflate_optimized_lengths(cl_counts, @"u19", @"u7");
    cl_codes = deflate_canonical_codes(cl_lengths, @"u7");
    order = code_length_order();
    num_bit_lengths = @"u19";
    while (true) {
        minimum_cl = (num_bit_lengths <= @"u4");
        if (minimum_cl) {
            break;
        }
        order_at = (num_bit_lengths -% @"u1");
        order_at_i = @bitCast(order_at);
        cl_symbol = @intCast(order[@intCast(order_at_i)]);
        cl_symbol_i = @bitCast(cl_symbol);
        cl_width = @intCast(cl_lengths[@intCast(cl_symbol_i)]);
        used_cl = (cl_width != @"u0");
        if (used_cl) {
            break;
        }
        num_bit_lengths = order_at;
    }
    out = allocator.alloc(u8, 0) catch unreachable;
    state = allocator.alloc(u8, 0) catch unreachable;
    state = allocator.realloc(state, state.len + 1) catch unreachable;
    state[state.len - 1] = @truncate(@"u0");
    state = deflate_write_bits(state, @"u5", @"u3");
    hlit = (num_lit -% @"u257");
    hdist = (num_dist -% @"u1");
    hclen = (num_bit_lengths -% @"u4");
    state = deflate_write_bits(state, hlit, @"u5");
    state = deflate_write_bits(state, hdist, @"u5");
    state = deflate_write_bits(state, hclen, @"u4");
    order_at = @"u0";
    while (true) {
        order_done = (order_at >= num_bit_lengths);
        if (order_done) {
            break;
        }
        order_at_i = @bitCast(order_at);
        cl_symbol = @intCast(order[@intCast(order_at_i)]);
        cl_symbol_i = @bitCast(cl_symbol);
        cl_width = @intCast(cl_lengths[@intCast(cl_symbol_i)]);
        state = deflate_write_bits(state, cl_width, @"u3");
        order_at = (order_at +% @"u1");
    }
    packed_n = @intCast(packed_.len);
    packed_at = @"i0";
    while (true) {
        packed_done = (packed_at >= packed_n);
        if (packed_done) {
            break;
        }
        cl_symbol = @intCast(packed_[@intCast(packed_at)]);
        state = deflate_huffman_symbol(state, cl_codes, cl_lengths, cl_symbol);
        packed_at = (packed_at + @"i1");
        has_extra = (cl_symbol >= @"u16");
        if (has_extra) {
            extra = @intCast(packed_[@intCast(packed_at)]);
            extra_index = (cl_symbol -% @"u16");
            extra_width = @"u2";
            is17 = (extra_index == @"u1");
            if (is17) {
                extra_width = @"u3";
            }
            is18 = (extra_index == @"u2");
            if (is18) {
                extra_width = @"u7";
            }
            state = deflate_write_bits(state, extra, extra_width);
            packed_at = (packed_at + @"i1");
        }
    }
    token_at = @"i0";
    while (true) {
        emit_done = (token_at >= tokens_n);
        if (emit_done) {
            break;
        }
        tag = @intCast(tokens[@intCast(token_at)]);
        match_ = (tag == @"u1");
        if (match_) {
            value_low_at = (token_at + @"i1");
            value_high_at = (token_at + @"i2");
            distance_low_at = (token_at + @"i3");
            distance_high_at = (token_at + @"i4");
            value_low = @intCast(tokens[@intCast(value_low_at)]);
            value_high = @intCast(tokens[@intCast(value_high_at)]);
            value_high_shifted = (value_high << @intCast(@"u8"));
            length = (value_low | value_high_shifted);
            distance_low = @intCast(tokens[@intCast(distance_low_at)]);
            distance_high = @intCast(tokens[@intCast(distance_high_at)]);
            distance_high_shifted = (distance_high << @intCast(@"u8"));
            distance = (distance_low | distance_high_shifted);
            symbols = deflate_match_symbols(length, distance);
            length_symbol = (symbols >> @intCast(@"u32"));
            distance_symbol = (symbols & @"u4294967295");
            state = deflate_huffman_symbol(state, lit_codes, lit_lengths, length_symbol);
            length_base_value = length_base(length_symbol);
            length_extra_width = length_extra(length_symbol);
            length_extra_value = (length -% length_base_value);
            state = deflate_write_bits(state, length_extra_value, length_extra_width);
            state = deflate_huffman_symbol(state, dist_codes, dist_lengths, distance_symbol);
            distance_base_value = distance_base(distance_symbol);
            distance_extra_width = distance_extra(distance_symbol);
            distance_extra_value = (distance -% distance_base_value);
            state = deflate_write_bits(state, distance_extra_value, distance_extra_width);
        }
        literal = (!match_);
        if (literal) {
            literal_at = (token_at + @"i1");
            literal_symbol = @intCast(tokens[@intCast(literal_at)]);
            state = deflate_huffman_symbol(state, lit_codes, lit_lengths, literal_symbol);
        }
        complete = deflate_drain_complete(state);
        complete_n = @intCast(complete.len);
        drain_at = @"i0";
        while (true) {
            drain_done = (drain_at >= complete_n);
            if (drain_done) {
                break;
            }
            drain_byte = @intCast(complete[@intCast(drain_at)]);
            out = allocator.realloc(out, out.len + 1) catch unreachable;
            out[out.len - 1] = @truncate(drain_byte);
            drain_at = (drain_at + @"i1");
        }
        state = deflate_drain_carry(state);
        token_at = (token_at + @"i5");
    }
    state = deflate_huffman_symbol(state, lit_codes, lit_lengths, @"u256");
    state_n = @intCast(state.len);
    tail_at = @"i1";
    while (true) {
        tail_done = (tail_at >= state_n);
        if (tail_done) {
            break;
        }
        tail_byte = @intCast(state[@intCast(tail_at)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(tail_byte);
        tail_at = (tail_at + @"i1");
    }
    return out;
}

pub fn deflate_stored(data: []const u8) []u8 {
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"u65535": u64 = undefined;
    var head: []u8 = undefined;
    var n_i: i64 = undefined;
    var n: u64 = undefined;
    var n_low: u64 = undefined;
    var n_shifted: u64 = undefined;
    var n_high: u64 = undefined;
    var complement: u64 = undefined;
    var complement_low: u64 = undefined;
    var complement_shifted: u64 = undefined;
    var complement_high: u64 = undefined;
    var out: []u8 = undefined;
    @"u1" = 1;
    @"u8" = 8;
    @"u255" = 255;
    @"u65535" = 65535;
    head = allocator.alloc(u8, 0) catch unreachable;
    head = allocator.realloc(head, head.len + 1) catch unreachable;
    head[head.len - 1] = @truncate(@"u1");
    n_i = @intCast(data.len);
    n = @bitCast(n_i);
    n_low = (n & @"u255");
    n_shifted = (n >> @intCast(@"u8"));
    n_high = (n_shifted & @"u255");
    complement = (@"u65535" -% n);
    complement_low = (complement & @"u255");
    complement_shifted = (complement >> @intCast(@"u8"));
    complement_high = (complement_shifted & @"u255");
    head = allocator.realloc(head, head.len + 1) catch unreachable;
    head[head.len - 1] = @truncate(n_low);
    head = allocator.realloc(head, head.len + 1) catch unreachable;
    head[head.len - 1] = @truncate(n_high);
    head = allocator.realloc(head, head.len + 1) catch unreachable;
    head[head.len - 1] = @truncate(complement_low);
    head = allocator.realloc(head, head.len + 1) catch unreachable;
    head[head.len - 1] = @truncate(complement_high);
    out = append_bytes(head, data);
    return out;
}

pub fn deflate_miniz_level6(data: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i32": i64 = undefined;
    var @"i48": i64 = undefined;
    var @"i65535": i64 = undefined;
    var n: i64 = undefined;
    var body: []u8 = undefined;
    var fixed: bool = undefined;
    var dynamic: bool = undefined;
    var body_n: i64 = undefined;
    var large: bool = undefined;
    var expanded: bool = undefined;
    var fits_stored: bool = undefined;
    var fallback_candidate: bool = undefined;
    var fallback: bool = undefined;
    @"i0" = 0;
    @"i32" = 32;
    @"i48" = 48;
    @"i65535" = 65535;
    n = @intCast(data.len);
    body = allocator.dupe(u8, data[@intCast(@"i0")..@intCast(@"i0")]) catch unreachable;
    fixed = (n < @"i48");
    if (fixed) {
        body = deflate_fixed(data);
    }
    dynamic = (n >= @"i48");
    if (dynamic) {
        body = deflate_dynamic(data);
    }
    body_n = @intCast(body.len);
    large = (n > @"i32");
    expanded = (body_n >= n);
    fits_stored = (n <= @"i65535");
    fallback_candidate = (large and expanded);
    fallback = (fallback_candidate and fits_stored);
    if (fallback) {
        body = deflate_stored(data);
    }
    return body;
}

pub fn zlib_compress(data: []const u8) []u8 {
    var @"u8": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u24": u64 = undefined;
    var @"u120": u64 = undefined;
    var @"u156": u64 = undefined;
    var @"u255": u64 = undefined;
    var out: []u8 = undefined;
    var body: []u8 = undefined;
    var prefixed: []u8 = undefined;
    var checksum: u64 = undefined;
    var b3_shifted: u64 = undefined;
    var b3: u64 = undefined;
    var b2_shifted: u64 = undefined;
    var b2: u64 = undefined;
    var b1_shifted: u64 = undefined;
    var b1: u64 = undefined;
    var b0: u64 = undefined;
    var trailer: []u8 = undefined;
    var complete: []u8 = undefined;
    @"u8" = 8;
    @"u16" = 16;
    @"u24" = 24;
    @"u120" = 120;
    @"u156" = 156;
    @"u255" = 255;
    out = allocator.alloc(u8, 0) catch unreachable;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(@"u120");
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(@"u156");
    body = deflate_miniz_level6(data);
    prefixed = append_bytes(out, body);
    checksum = adler32(data);
    b3_shifted = (checksum >> @intCast(@"u24"));
    b3 = (b3_shifted & @"u255");
    b2_shifted = (checksum >> @intCast(@"u16"));
    b2 = (b2_shifted & @"u255");
    b1_shifted = (checksum >> @intCast(@"u8"));
    b1 = (b1_shifted & @"u255");
    b0 = (checksum & @"u255");
    trailer = allocator.alloc(u8, 0) catch unreachable;
    trailer = allocator.realloc(trailer, trailer.len + 1) catch unreachable;
    trailer[trailer.len - 1] = @truncate(b3);
    trailer = allocator.realloc(trailer, trailer.len + 1) catch unreachable;
    trailer[trailer.len - 1] = @truncate(b2);
    trailer = allocator.realloc(trailer, trailer.len + 1) catch unreachable;
    trailer[trailer.len - 1] = @truncate(b1);
    trailer = allocator.realloc(trailer, trailer.len + 1) catch unreachable;
    trailer[trailer.len - 1] = @truncate(b0);
    complete = append_bytes(prefixed, trailer);
    return complete;
}

pub fn append_bytes(left: []const u8, right: []const u8) []u8 {
    var out: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var left_n: i64 = undefined;
    var right_n: i64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"i0" = 0;
    @"i1" = 1;
    left_n = @intCast(left.len);
    right_n = @intCast(right.len);
    pos = @"i0";
    while (true) {
        done = (pos >= left_n);
        if (done) {
            break;
        }
        byte_ = @intCast(left[@intCast(pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        pos = (pos + @"i1");
    }
    pos = @"i0";
    while (true) {
        done = (pos >= right_n);
        if (done) {
            break;
        }
        byte_ = @intCast(right[@intCast(pos)]);
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        pos = (pos + @"i1");
    }
    return out;
}

pub fn u32_to_le(value: u64) []u8 {
    var out: []u8 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"u4": u64 = undefined;
    var pos: u64 = undefined;
    var remaining: u64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var one: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"u8" = 8;
    @"u255" = 255;
    @"u4" = 4;
    pos = 0;
    remaining = value;
    while (true) {
        done = (pos >= @"u4");
        if (done) {
            break;
        }
        byte_ = (remaining & @"u255");
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        remaining = (remaining >> @intCast(@"u8"));
        one = 1;
        pos = (pos +% one);
    }
    return out;
}

pub fn u64_to_le(value: u64) []u8 {
    var out: []u8 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var count: u64 = undefined;
    var pos: u64 = undefined;
    var remaining: u64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var one: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"u8" = 8;
    @"u255" = 255;
    count = 8;
    pos = 0;
    remaining = value;
    while (true) {
        done = (pos >= count);
        if (done) {
            break;
        }
        byte_ = (remaining & @"u255");
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(byte_);
        remaining = (remaining >> @intCast(@"u8"));
        one = 1;
        pos = (pos +% one);
    }
    return out;
}

pub fn read_u32_le(data: []const u8, start: i64) u64 {
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i4": i64 = undefined;
    var result: u64 = undefined;
    var shift: u64 = undefined;
    var pos: i64 = undefined;
    var read: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var part: u64 = undefined;
    @"u0" = 0;
    @"u8" = 8;
    @"i0" = 0;
    @"i1" = 1;
    @"i4" = 4;
    result = @"u0";
    shift = @"u0";
    pos = start;
    read = @"i0";
    while (true) {
        done = (read >= @"i4");
        if (done) {
            break;
        }
        byte_ = @intCast(data[@intCast(pos)]);
        part = (byte_ << @intCast(shift));
        result = (result | part);
        shift = (shift +% @"u8");
        pos = (pos + @"i1");
        read = (read + @"i1");
    }
    return result;
}

pub fn read_u64_le(data: []const u8, start: i64) u64 {
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i8": i64 = undefined;
    var result: u64 = undefined;
    var shift: u64 = undefined;
    var pos: i64 = undefined;
    var read: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var part: u64 = undefined;
    @"u0" = 0;
    @"u8" = 8;
    @"i0" = 0;
    @"i1" = 1;
    @"i8" = 8;
    result = @"u0";
    shift = @"u0";
    pos = start;
    read = @"i0";
    while (true) {
        done = (read >= @"i8");
        if (done) {
            break;
        }
        byte_ = @intCast(data[@intCast(pos)]);
        part = (byte_ << @intCast(shift));
        result = (result | part);
        shift = (shift +% @"u8");
        pos = (pos + @"i1");
        read = (read + @"i1");
    }
    return result;
}

pub fn bounded_advance(data: []const u8, start: i64, amount: u64) i64 {
    var @"i0": i64 = undefined;
    var negative: bool = undefined;
    var amount_i64: i64 = undefined;
    var end_: i64 = undefined;
    var n: i64 = undefined;
    var inside: bool = undefined;
    @"i0" = 0;
    negative = (start < @"i0");
    if (negative) {
        return @"i0";
    }
    amount_i64 = @bitCast(amount);
    end_ = (start + amount_i64);
    n = @intCast(data.len);
    inside = (end_ <= n);
    if (inside) {
        return end_;
    }
    return @"i0";
}

pub fn choice_list_header(count: u64) []u8 {
    var header: []u8 = undefined;
    header = u32_to_le(count);
    return header;
}

pub fn serialize_integer_choice(value_raw: []const u8) []u8 {
    var out: []u8 = undefined;
    var tag: u64 = undefined;
    var subtag: u64 = undefined;
    var value: []u8 = undefined;
    var length_i64: i64 = undefined;
    var length: u64 = undefined;
    var length_bytes: []u8 = undefined;
    var with_length: []u8 = undefined;
    var encoded: []u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    tag = 0;
    subtag = 10;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(subtag);
    value = canonicalize_signed_le(value_raw);
    length_i64 = @intCast(value.len);
    length = @bitCast(length_i64);
    length_bytes = u32_to_le(length);
    with_length = append_bytes(out, length_bytes);
    encoded = append_bytes(with_length, value);
    return encoded;
}

pub fn serialize_boolean_choice(value: bool) []u8 {
    var out: []u8 = undefined;
    var tag: u64 = undefined;
    var byte_: u64 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    tag = 1;
    byte_ = 0;
    if (value) {
        byte_ = 1;
    }
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(byte_);
    return out;
}

pub fn serialize_float_choice(value: f64) []u8 {
    var out: []u8 = undefined;
    var tag: u64 = undefined;
    var bits: u64 = undefined;
    var raw: []u8 = undefined;
    var encoded: []u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    tag = 2;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    bits = @bitCast(value);
    raw = u64_to_le(bits);
    encoded = append_bytes(out, raw);
    return encoded;
}

pub fn serialize_bytes_choice(value: []const u8) []u8 {
    var out: []u8 = undefined;
    var tag: u64 = undefined;
    var length_i64: i64 = undefined;
    var length: u64 = undefined;
    var length_bytes: []u8 = undefined;
    var with_length: []u8 = undefined;
    var encoded: []u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    tag = 3;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    length_i64 = @intCast(value.len);
    length = @bitCast(length_i64);
    length_bytes = u32_to_le(length);
    with_length = append_bytes(out, length_bytes);
    encoded = append_bytes(with_length, value);
    return encoded;
}

pub fn serialize_string_choice_packed(count: u64, codepoints_le: []const u8) []u8 {
    var out: []u8 = undefined;
    var tag: u64 = undefined;
    var length_bytes: []u8 = undefined;
    var with_length: []u8 = undefined;
    var encoded: []u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    tag = 4;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    length_bytes = u32_to_le(count);
    with_length = append_bytes(out, length_bytes);
    encoded = append_bytes(with_length, codepoints_le);
    return encoded;
}

pub fn serialize_clone_header(child_count: u64) []u8 {
    var out: []u8 = undefined;
    var tag: u64 = undefined;
    var header: []u8 = undefined;
    var encoded: []u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    tag = 5;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    header = choice_list_header(child_count);
    encoded = append_bytes(out, header);
    return encoded;
}

pub fn serialize_keyed_choice(key: u64, inner: []const u8) []u8 {
    var out: []u8 = undefined;
    var tag: u64 = undefined;
    var key_bytes: []u8 = undefined;
    var with_key: []u8 = undefined;
    var encoded: []u8 = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    tag = 6;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    key_bytes = u64_to_le(key);
    with_key = append_bytes(out, key_bytes);
    encoded = append_bytes(with_key, inner);
    return encoded;
}

pub fn keyed_entry_key(data: []const u8, start: i64) ?u64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u6": u64 = undefined;
    var @"u8": u64 = undefined;
    var none: ?u64 = undefined;
    var n: i64 = undefined;
    var start_negative: bool = undefined;
    var missing_tag: bool = undefined;
    var tag: u64 = undefined;
    var keyed: bool = undefined;
    var unkeyed: bool = undefined;
    var key_start: i64 = undefined;
    var key_end: i64 = undefined;
    var truncated: bool = undefined;
    var key: u64 = undefined;
    var found: ?u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u6" = 6;
    @"u8" = 8;
    none = null;
    n = @intCast(data.len);
    start_negative = (start < @"i0");
    if (start_negative) {
        return none;
    }
    missing_tag = (start >= n);
    if (missing_tag) {
        return none;
    }
    tag = @intCast(data[@intCast(start)]);
    keyed = (tag == @"u6");
    unkeyed = (!keyed);
    if (unkeyed) {
        return none;
    }
    key_start = (start + @"i1");
    key_end = bounded_advance(data, key_start, @"u8");
    truncated = (key_end == @"i0");
    if (truncated) {
        return none;
    }
    key = read_u64_le(data, key_start);
    found = key;
    return found;
}

pub fn keyed_entry_inner(data: []const u8, start: i64) i64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u8": u64 = undefined;
    var key: ?u64 = undefined;
    var present: bool = undefined;
    var absent: bool = undefined;
    var key_start: i64 = undefined;
    var inner: i64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u8" = 8;
    key = keyed_entry_key(data, start);
    present = key != null;
    absent = (!present);
    if (absent) {
        return @"i0";
    }
    key_start = (start + @"i1");
    inner = bounded_advance(data, key_start, @"u8");
    return inner;
}

pub fn choice_entry_end(data: []const u8, start: i64, depth: u64) i64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u100": u64 = undefined;
    var too_deep: bool = undefined;
    var n: i64 = undefined;
    var start_negative: bool = undefined;
    var missing_tag: bool = undefined;
    var tag: u64 = undefined;
    var value_start: i64 = undefined;
    var integer: bool = undefined;
    var sub_end: i64 = undefined;
    var sub_missing: bool = undefined;
    var sub: u64 = undefined;
    var sub0: bool = undefined;
    var end_: i64 = undefined;
    var sub1: bool = undefined;
    var sub2: bool = undefined;
    var @"u3": u64 = undefined;
    var sub3: bool = undefined;
    var sub4: bool = undefined;
    var @"u5": u64 = undefined;
    var sub5: bool = undefined;
    var @"u6": u64 = undefined;
    var sub6: bool = undefined;
    var @"u7": u64 = undefined;
    var sub7: bool = undefined;
    var sub8: bool = undefined;
    var @"u9": u64 = undefined;
    var sub9: bool = undefined;
    var @"u10": u64 = undefined;
    var sub10: bool = undefined;
    var header_end: i64 = undefined;
    var header_missing: bool = undefined;
    var length: u64 = undefined;
    var boolean_: bool = undefined;
    var float_: bool = undefined;
    var bytes: bool = undefined;
    var string_: bool = undefined;
    var byte_length: u64 = undefined;
    var keyed: bool = undefined;
    var inner: i64 = undefined;
    var truncated: bool = undefined;
    var nested_key: ?u64 = undefined;
    var double_keyed: bool = undefined;
    var clone: bool = undefined;
    var count: u64 = undefined;
    var child_pos: i64 = undefined;
    var child_index: u64 = undefined;
    var child_depth: u64 = undefined;
    var done: bool = undefined;
    var child_end: i64 = undefined;
    var child_invalid: bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u4" = 4;
    @"u8" = 8;
    @"u16" = 16;
    @"u100" = 100;
    too_deep = (depth > @"u100");
    if (too_deep) {
        return @"i0";
    }
    n = @intCast(data.len);
    start_negative = (start < @"i0");
    if (start_negative) {
        return @"i0";
    }
    missing_tag = (start >= n);
    if (missing_tag) {
        return @"i0";
    }
    tag = @intCast(data[@intCast(start)]);
    value_start = (start + @"i1");
    integer = (tag == @"u0");
    if (integer) {
        sub_end = bounded_advance(data, value_start, @"u1");
        sub_missing = (sub_end == @"i0");
        if (sub_missing) {
            return @"i0";
        }
        sub = @intCast(data[@intCast(value_start)]);
        sub0 = (sub == @"u0");
        if (sub0) {
            end_ = bounded_advance(data, sub_end, @"u1");
            return end_;
        }
        sub1 = (sub == @"u1");
        if (sub1) {
            end_ = bounded_advance(data, sub_end, @"u2");
            return end_;
        }
        sub2 = (sub == @"u2");
        if (sub2) {
            end_ = bounded_advance(data, sub_end, @"u4");
            return end_;
        }
        @"u3" = 3;
        sub3 = (sub == @"u3");
        if (sub3) {
            end_ = bounded_advance(data, sub_end, @"u8");
            return end_;
        }
        sub4 = (sub == @"u4");
        if (sub4) {
            end_ = bounded_advance(data, sub_end, @"u16");
            return end_;
        }
        @"u5" = 5;
        sub5 = (sub == @"u5");
        if (sub5) {
            end_ = bounded_advance(data, sub_end, @"u1");
            return end_;
        }
        @"u6" = 6;
        sub6 = (sub == @"u6");
        if (sub6) {
            end_ = bounded_advance(data, sub_end, @"u2");
            return end_;
        }
        @"u7" = 7;
        sub7 = (sub == @"u7");
        if (sub7) {
            end_ = bounded_advance(data, sub_end, @"u4");
            return end_;
        }
        sub8 = (sub == @"u8");
        if (sub8) {
            end_ = bounded_advance(data, sub_end, @"u8");
            return end_;
        }
        @"u9" = 9;
        sub9 = (sub == @"u9");
        if (sub9) {
            end_ = bounded_advance(data, sub_end, @"u16");
            return end_;
        }
        @"u10" = 10;
        sub10 = (sub == @"u10");
        if (sub10) {
            header_end = bounded_advance(data, sub_end, @"u4");
            header_missing = (header_end == @"i0");
            if (header_missing) {
                return @"i0";
            }
            length = read_u32_le(data, sub_end);
            end_ = bounded_advance(data, header_end, length);
            return end_;
        }
        return @"i0";
    }
    boolean_ = (tag == @"u1");
    if (boolean_) {
        end_ = bounded_advance(data, value_start, @"u1");
        return end_;
    }
    float_ = (tag == @"u2");
    if (float_) {
        end_ = bounded_advance(data, value_start, @"u8");
        return end_;
    }
    @"u3" = 3;
    bytes = (tag == @"u3");
    if (bytes) {
        header_end = bounded_advance(data, value_start, @"u4");
        header_missing = (header_end == @"i0");
        if (header_missing) {
            return @"i0";
        }
        length = read_u32_le(data, value_start);
        end_ = bounded_advance(data, header_end, length);
        return end_;
    }
    string_ = (tag == @"u4");
    if (string_) {
        header_end = bounded_advance(data, value_start, @"u4");
        header_missing = (header_end == @"i0");
        if (header_missing) {
            return @"i0";
        }
        length = read_u32_le(data, value_start);
        byte_length = (length *% @"u4");
        end_ = bounded_advance(data, header_end, byte_length);
        return end_;
    }
    @"u6" = 6;
    keyed = (tag == @"u6");
    if (keyed) {
        inner = bounded_advance(data, value_start, @"u8");
        truncated = (inner == @"i0");
        if (truncated) {
            return @"i0";
        }
        nested_key = keyed_entry_key(data, inner);
        double_keyed = nested_key != null;
        if (double_keyed) {
            return @"i0";
        }
        end_ = choice_entry_end(data, inner, depth);
        return end_;
    }
    @"u5" = 5;
    clone = (tag == @"u5");
    if (clone) {
        header_end = bounded_advance(data, value_start, @"u4");
        header_missing = (header_end == @"i0");
        if (header_missing) {
            return @"i0";
        }
        count = read_u32_le(data, value_start);
        child_pos = header_end;
        child_index = @"u0";
        child_depth = (depth +% @"u1");
        while (true) {
            done = (child_index >= count);
            if (done) {
                break;
            }
            child_end = choice_entry_end(data, child_pos, child_depth);
            child_invalid = (child_end == @"i0");
            if (child_invalid) {
                return @"i0";
            }
            child_pos = child_end;
            child_index = (child_index +% @"u1");
        }
        return child_pos;
    }
    return @"i0";
}

pub fn choice_stream_validate(data: []const u8) bool {
    var @"i0": i64 = undefined;
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u4": u64 = undefined;
    var header_end: i64 = undefined;
    var header_missing: bool = undefined;
    var invalid: bool = undefined;
    var count: u64 = undefined;
    var pos: i64 = undefined;
    var index: u64 = undefined;
    var done: bool = undefined;
    var end_: i64 = undefined;
    var invalid_entry: bool = undefined;
    var valid: bool = undefined;
    @"i0" = 0;
    @"i4" = 4;
    @"u0" = 0;
    @"u1" = 1;
    @"u4" = 4;
    header_end = bounded_advance(data, @"i0", @"u4");
    header_missing = (header_end == @"i0");
    if (header_missing) {
        invalid = false;
        return invalid;
    }
    count = read_u32_le(data, @"i0");
    pos = @"i4";
    index = @"u0";
    while (true) {
        done = (index >= count);
        if (done) {
            break;
        }
        end_ = choice_entry_end(data, pos, @"u0");
        invalid_entry = (end_ == @"i0");
        if (invalid_entry) {
            invalid = false;
            return invalid;
        }
        pos = end_;
        index = (index +% @"u1");
    }
    valid = true;
    return valid;
}

pub fn choice_stream_count(data: []const u8) u64 {
    var @"i0": i64 = undefined;
    var count: u64 = undefined;
    @"i0" = 0;
    count = read_u32_le(data, @"i0");
    return count;
}

pub fn deserialize_integer_choice(data: []const u8, start: i64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i6": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u10": u64 = undefined;
    var end_: i64 = undefined;
    var invalid: bool = undefined;
    var none: ?[]u8 = undefined;
    var tag: u64 = undefined;
    var wrong_tag: bool = undefined;
    var sub_pos: i64 = undefined;
    var sub: u64 = undefined;
    var wrong_sub: bool = undefined;
    var value_start: i64 = undefined;
    var value: []u8 = undefined;
    var canonical: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i6" = 6;
    @"u0" = 0;
    @"u10" = 10;
    end_ = choice_entry_end(data, start, @"u0");
    invalid = (end_ == @"i0");
    if (invalid) {
        none = null;
        return none;
    }
    tag = @intCast(data[@intCast(start)]);
    wrong_tag = (tag != @"u0");
    if (wrong_tag) {
        none = null;
        return none;
    }
    sub_pos = (start + @"i1");
    sub = @intCast(data[@intCast(sub_pos)]);
    wrong_sub = (sub != @"u10");
    if (wrong_sub) {
        none = null;
        return none;
    }
    value_start = (start + @"i6");
    value = allocator.dupe(u8, data[@intCast(value_start)..@intCast(end_)]) catch unreachable;
    canonical = canonicalize_signed_le(value);
    some = canonical;
    return some;
}

pub fn deserialize_boolean_choice(data: []const u8, start: i64) ?bool {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var end_: i64 = undefined;
    var invalid: bool = undefined;
    var none: ?bool = undefined;
    var tag: u64 = undefined;
    var wrong_tag: bool = undefined;
    var value_pos: i64 = undefined;
    var byte_: u64 = undefined;
    var value: bool = undefined;
    var some: ?bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    end_ = choice_entry_end(data, start, @"u0");
    invalid = (end_ == @"i0");
    if (invalid) {
        none = null;
        return none;
    }
    tag = @intCast(data[@intCast(start)]);
    wrong_tag = (tag != @"u1");
    if (wrong_tag) {
        none = null;
        return none;
    }
    value_pos = (start + @"i1");
    byte_ = @intCast(data[@intCast(value_pos)]);
    value = (byte_ != @"u0");
    some = value;
    return some;
}

pub fn deserialize_float_choice(data: []const u8, start: i64) ?f64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u2": u64 = undefined;
    var end_: i64 = undefined;
    var invalid: bool = undefined;
    var none: ?f64 = undefined;
    var tag: u64 = undefined;
    var wrong_tag: bool = undefined;
    var value_pos: i64 = undefined;
    var bits: u64 = undefined;
    var value: f64 = undefined;
    var some: ?f64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u2" = 2;
    end_ = choice_entry_end(data, start, @"u0");
    invalid = (end_ == @"i0");
    if (invalid) {
        none = null;
        return none;
    }
    tag = @intCast(data[@intCast(start)]);
    wrong_tag = (tag != @"u2");
    if (wrong_tag) {
        none = null;
        return none;
    }
    value_pos = (start + @"i1");
    bits = read_u64_le(data, value_pos);
    value = @bitCast(bits);
    some = value;
    return some;
}

pub fn deserialize_bytes_choice(data: []const u8, start: i64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i5": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u3": u64 = undefined;
    var end_: i64 = undefined;
    var invalid: bool = undefined;
    var none: ?[]u8 = undefined;
    var tag: u64 = undefined;
    var wrong_tag: bool = undefined;
    var value_start: i64 = undefined;
    var value: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i5" = 5;
    @"u0" = 0;
    @"u3" = 3;
    end_ = choice_entry_end(data, start, @"u0");
    invalid = (end_ == @"i0");
    if (invalid) {
        none = null;
        return none;
    }
    tag = @intCast(data[@intCast(start)]);
    wrong_tag = (tag != @"u3");
    if (wrong_tag) {
        none = null;
        return none;
    }
    value_start = (start + @"i5");
    value = allocator.dupe(u8, data[@intCast(value_start)..@intCast(end_)]) catch unreachable;
    some = value;
    return some;
}

pub fn deserialize_string_choice(data: []const u8, start: i64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i5": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u4": u64 = undefined;
    var end_: i64 = undefined;
    var invalid: bool = undefined;
    var none: ?[]u8 = undefined;
    var tag: u64 = undefined;
    var wrong_tag: bool = undefined;
    var value_start: i64 = undefined;
    var value: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i5" = 5;
    @"u0" = 0;
    @"u4" = 4;
    end_ = choice_entry_end(data, start, @"u0");
    invalid = (end_ == @"i0");
    if (invalid) {
        none = null;
        return none;
    }
    tag = @intCast(data[@intCast(start)]);
    wrong_tag = (tag != @"u4");
    if (wrong_tag) {
        none = null;
        return none;
    }
    value_start = (start + @"i5");
    value = allocator.dupe(u8, data[@intCast(value_start)..@intCast(end_)]) catch unreachable;
    some = value;
    return some;
}

pub fn failure_use_compressed(compressed_n: u64, raw_n: u64) bool {
    var max: u64 = undefined;
    var shorter: bool = undefined;
    var fits: bool = undefined;
    var use_: bool = undefined;
    max = max_decompressed_len();
    shorter = (compressed_n < raw_n);
    fits = (raw_n <= max);
    use_ = (shorter and fits);
    return use_;
}

pub fn raw_failure_encode(serialized_choices: []const u8) []u8 {
    var raw_payload: []u8 = undefined;
    var prefix_raw: u64 = undefined;
    var prefix_zlib: u64 = undefined;
    var raw_prefixed: []u8 = undefined;
    var compressed: []u8 = undefined;
    var compressed_len: i64 = undefined;
    var compressed_n: u64 = undefined;
    var raw_len: i64 = undefined;
    var raw_n: u64 = undefined;
    var use_compressed: bool = undefined;
    var chosen: []u8 = undefined;
    var zlib_payload: []u8 = undefined;
    var blob: []u8 = undefined;
    raw_payload = allocator.alloc(u8, 0) catch unreachable;
    prefix_raw = 0;
    prefix_zlib = 1;
    raw_payload = allocator.realloc(raw_payload, raw_payload.len + 1) catch unreachable;
    raw_payload[raw_payload.len - 1] = @truncate(prefix_raw);
    raw_prefixed = append_bytes(raw_payload, serialized_choices);
    compressed = zlib_compress(serialized_choices);
    compressed_len = @intCast(compressed.len);
    compressed_n = @bitCast(compressed_len);
    raw_len = @intCast(serialized_choices.len);
    raw_n = @bitCast(raw_len);
    use_compressed = failure_use_compressed(compressed_n, raw_n);
    chosen = allocator.dupe(u8, raw_prefixed) catch unreachable;
    if (use_compressed) {
        zlib_payload = allocator.alloc(u8, 0) catch unreachable;
        zlib_payload = allocator.realloc(zlib_payload, zlib_payload.len + 1) catch unreachable;
        zlib_payload[zlib_payload.len - 1] = @truncate(prefix_zlib);
        chosen = append_bytes(zlib_payload, compressed);
    }
    blob = base64_encode(chosen);
    return blob;
}

pub fn raw_failure_decode(blob: []const u8) ?[]u8 {
    var decoded: ?[]u8 = undefined;
    var present: bool = undefined;
    var missing: bool = undefined;
    var none: ?[]u8 = undefined;
    var payload: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var n: i64 = undefined;
    var empty: bool = undefined;
    var prefix: u64 = undefined;
    var u1_prefix: u64 = undefined;
    var raw: bool = undefined;
    var compressed: bool = undefined;
    var known: bool = undefined;
    var unknown: bool = undefined;
    var serialized: []u8 = undefined;
    var inflated: ?[]u8 = undefined;
    var inflated_ok: bool = undefined;
    var inflate_failed: bool = undefined;
    var valid: bool = undefined;
    var invalid: bool = undefined;
    var some: ?[]u8 = undefined;
    decoded = base64_decode(blob);
    present = decoded != null;
    missing = (!present);
    if (missing) {
        none = null;
        return none;
    }
    payload = decoded.?;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    n = @intCast(payload.len);
    empty = (n == @"i0");
    if (empty) {
        none = null;
        return none;
    }
    prefix = @intCast(payload[@intCast(@"i0")]);
    u1_prefix = 1;
    raw = (prefix == @"u0");
    compressed = (prefix == u1_prefix);
    known = (raw or compressed);
    unknown = (!known);
    if (unknown) {
        none = null;
        return none;
    }
    serialized = allocator.dupe(u8, payload[@intCast(@"i1")..@intCast(n)]) catch unreachable;
    if (compressed) {
        inflated = zlib_decompress(serialized);
        inflated_ok = inflated != null;
        inflate_failed = (!inflated_ok);
        if (inflate_failed) {
            none = null;
            return none;
        }
        serialized = inflated.?;
    }
    valid = choice_stream_validate(serialized);
    invalid = (!valid);
    if (invalid) {
        none = null;
        return none;
    }
    some = serialized;
    return some;
}

pub fn alphabet_codepoint_allowed(codepoint: u64) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var max: u64 = undefined;
    var surrogate_low: u64 = undefined;
    var surrogate_high: u64 = undefined;
    var too_high: bool = undefined;
    var at_or_above_low: bool = undefined;
    var at_or_below_high: bool = undefined;
    var surrogate: bool = undefined;
    false_ = false;
    true_ = true;
    max = 1114111;
    surrogate_low = 55296;
    surrogate_high = 57343;
    too_high = (codepoint > max);
    if (too_high) {
        return false_;
    }
    at_or_above_low = (codepoint >= surrogate_low);
    at_or_below_high = (codepoint <= surrogate_high);
    surrogate = (at_or_above_low and at_or_below_high);
    if (surrogate) {
        return false_;
    }
    return true_;
}

pub fn alphabet_interval_count(alphabet: []const u8) u64 {
    var @"u3": u64 = undefined;
    var length: i64 = undefined;
    var length_u64: u64 = undefined;
    var count: u64 = undefined;
    @"u3" = 3;
    length = @intCast(alphabet.len);
    length_u64 = @bitCast(length);
    count = (length_u64 >> @intCast(@"u3"));
    return count;
}

pub fn alphabet_interval_start(alphabet: []const u8, interval: u64) u64 {
    var @"i8": i64 = undefined;
    var interval_i64: i64 = undefined;
    var offset: i64 = undefined;
    var start: u64 = undefined;
    @"i8" = 8;
    interval_i64 = @bitCast(interval);
    offset = (interval_i64 * @"i8");
    start = read_u32_le(alphabet, offset);
    return start;
}

pub fn alphabet_interval_end(alphabet: []const u8, interval: u64) u64 {
    var @"i4": i64 = undefined;
    var @"i8": i64 = undefined;
    var interval_i64: i64 = undefined;
    var base: i64 = undefined;
    var offset: i64 = undefined;
    var end_: u64 = undefined;
    @"i4" = 4;
    @"i8" = 8;
    interval_i64 = @bitCast(interval);
    base = (interval_i64 * @"i8");
    offset = (base + @"i4");
    end_ = read_u32_le(alphabet, offset);
    return end_;
}

pub fn alphabet_valid(alphabet: []const u8) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var @"i0": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u3": u64 = undefined;
    var length: i64 = undefined;
    var empty: bool = undefined;
    var length_u64: u64 = undefined;
    var count_u64: u64 = undefined;
    var exact: u64 = undefined;
    var ragged: bool = undefined;
    var previous_end: u64 = undefined;
    var interval: u64 = undefined;
    var done: bool = undefined;
    var start: u64 = undefined;
    var end_: u64 = undefined;
    var descending: bool = undefined;
    var start_ok: bool = undefined;
    var start_bad: bool = undefined;
    var end_ok: bool = undefined;
    var end_bad: bool = undefined;
    var surrogate_low: u64 = undefined;
    var surrogate_high: u64 = undefined;
    var spans_below: bool = undefined;
    var spans_above: bool = undefined;
    var straddles: bool = undefined;
    var later: bool = undefined;
    var needed: u64 = undefined;
    var touching: bool = undefined;
    false_ = false;
    true_ = true;
    @"i0" = 0;
    @"u0" = 0;
    @"u1" = 1;
    @"u3" = 3;
    length = @intCast(alphabet.len);
    empty = (length <= @"i0");
    if (empty) {
        return false_;
    }
    length_u64 = @bitCast(length);
    count_u64 = (length_u64 >> @intCast(@"u3"));
    exact = (count_u64 << @intCast(@"u3"));
    ragged = (exact != length_u64);
    if (ragged) {
        return false_;
    }
    previous_end = @"u0";
    interval = @"u0";
    while (true) {
        done = (interval >= count_u64);
        if (done) {
            break;
        }
        start = alphabet_interval_start(alphabet, interval);
        end_ = alphabet_interval_end(alphabet, interval);
        descending = (start > end_);
        if (descending) {
            return false_;
        }
        start_ok = alphabet_codepoint_allowed(start);
        start_bad = (!start_ok);
        if (start_bad) {
            return false_;
        }
        end_ok = alphabet_codepoint_allowed(end_);
        end_bad = (!end_ok);
        if (end_bad) {
            return false_;
        }
        surrogate_low = 55296;
        surrogate_high = 57343;
        spans_below = (start <= surrogate_high);
        spans_above = (end_ >= surrogate_low);
        straddles = (spans_below and spans_above);
        if (straddles) {
            return false_;
        }
        later = (interval > @"u0");
        if (later) {
            needed = (previous_end +% @"u1");
            touching = (start <= needed);
            if (touching) {
                return false_;
            }
        }
        previous_end = end_;
        interval = (interval +% @"u1");
    }
    return true_;
}

pub fn alphabet_size(alphabet: []const u8) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var count: u64 = undefined;
    var size: u64 = undefined;
    var interval: u64 = undefined;
    var done: bool = undefined;
    var start: u64 = undefined;
    var end_: u64 = undefined;
    var span: u64 = undefined;
    var members: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    count = alphabet_interval_count(alphabet);
    size = @"u0";
    interval = @"u0";
    while (true) {
        done = (interval >= count);
        if (done) {
            break;
        }
        start = alphabet_interval_start(alphabet, interval);
        end_ = alphabet_interval_end(alphabet, interval);
        span = (end_ -% start);
        members = (span +% @"u1");
        size = (size +% members);
        interval = (interval +% @"u1");
    }
    return size;
}

pub fn alphabet_index_of(alphabet: []const u8, codepoint: u64) ?u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var count: u64 = undefined;
    var offset: u64 = undefined;
    var interval: u64 = undefined;
    var done: bool = undefined;
    var start: u64 = undefined;
    var end_: u64 = undefined;
    var at_or_above: bool = undefined;
    var at_or_below: bool = undefined;
    var inside: bool = undefined;
    var within: u64 = undefined;
    var index: u64 = undefined;
    var found: ?u64 = undefined;
    var span: u64 = undefined;
    var members: u64 = undefined;
    var missing: ?u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    count = alphabet_interval_count(alphabet);
    offset = @"u0";
    interval = @"u0";
    while (true) {
        done = (interval >= count);
        if (done) {
            break;
        }
        start = alphabet_interval_start(alphabet, interval);
        end_ = alphabet_interval_end(alphabet, interval);
        at_or_above = (codepoint >= start);
        at_or_below = (codepoint <= end_);
        inside = (at_or_above and at_or_below);
        if (inside) {
            within = (codepoint -% start);
            index = (offset +% within);
            found = index;
            return found;
        }
        span = (end_ -% start);
        members = (span +% @"u1");
        offset = (offset +% members);
        interval = (interval +% @"u1");
    }
    missing = null;
    return missing;
}

pub fn alphabet_codepoint_at(alphabet: []const u8, index: u64) ?u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var count: u64 = undefined;
    var remaining: u64 = undefined;
    var interval: u64 = undefined;
    var done: bool = undefined;
    var start: u64 = undefined;
    var end_: u64 = undefined;
    var span: u64 = undefined;
    var members: u64 = undefined;
    var inside: bool = undefined;
    var codepoint: u64 = undefined;
    var found: ?u64 = undefined;
    var missing: ?u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    count = alphabet_interval_count(alphabet);
    remaining = index;
    interval = @"u0";
    while (true) {
        done = (interval >= count);
        if (done) {
            break;
        }
        start = alphabet_interval_start(alphabet, interval);
        end_ = alphabet_interval_end(alphabet, interval);
        span = (end_ -% start);
        members = (span +% @"u1");
        inside = (remaining < members);
        if (inside) {
            codepoint = (start +% remaining);
            found = codepoint;
            return found;
        }
        remaining = (remaining -% members);
        interval = (interval +% @"u1");
    }
    missing = null;
    return missing;
}

pub fn alphabet_contains(alphabet: []const u8, codepoint: u64) bool {
    var index: ?u64 = undefined;
    var present: bool = undefined;
    index = alphabet_index_of(alphabet, codepoint);
    present = index != null;
    return present;
}

pub fn alphabet_index_above(alphabet: []const u8, codepoint: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var count: u64 = undefined;
    var below: u64 = undefined;
    var interval: u64 = undefined;
    var done: bool = undefined;
    var start: u64 = undefined;
    var end_: u64 = undefined;
    var before_interval: bool = undefined;
    var inside: bool = undefined;
    var within: u64 = undefined;
    var index: u64 = undefined;
    var span: u64 = undefined;
    var members: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    count = alphabet_interval_count(alphabet);
    below = @"u0";
    interval = @"u0";
    while (true) {
        done = (interval >= count);
        if (done) {
            break;
        }
        start = alphabet_interval_start(alphabet, interval);
        end_ = alphabet_interval_end(alphabet, interval);
        before_interval = (codepoint <= start);
        if (before_interval) {
            return below;
        }
        inside = (codepoint <= end_);
        if (inside) {
            within = (codepoint -% start);
            index = (below +% within);
            return index;
        }
        span = (end_ -% start);
        members = (span +% @"u1");
        below = (below +% members);
        interval = (interval +% @"u1");
    }
    return below;
}

pub fn alphabet_shrink_pivot(alphabet: []const u8) u64 {
    var zero: u64 = undefined;
    var pivot: u64 = undefined;
    zero = 48;
    pivot = alphabet_index_above(alphabet, zero);
    return pivot;
}

pub fn alphabet_shrink_last(alphabet: []const u8) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var upper_z: u64 = undefined;
    var found: ?u64 = undefined;
    var present: bool = undefined;
    var index: u64 = undefined;
    var pivot: u64 = undefined;
    var at_front: bool = undefined;
    var last: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    upper_z = 90;
    found = alphabet_index_of(alphabet, upper_z);
    present = found != null;
    if (present) {
        index = found.?;
        return index;
    }
    pivot = alphabet_shrink_pivot(alphabet);
    at_front = (pivot == @"u0");
    if (at_front) {
        return @"u0";
    }
    last = (pivot -% @"u1");
    return last;
}

pub fn alphabet_shrink_promoted(alphabet: []const u8) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var pivot: u64 = undefined;
    var last: u64 = undefined;
    var empty: bool = undefined;
    var span: u64 = undefined;
    var promoted: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    pivot = alphabet_shrink_pivot(alphabet);
    last = alphabet_shrink_last(alphabet);
    empty = (last < pivot);
    if (empty) {
        return @"u0";
    }
    span = (last -% pivot);
    promoted = (span +% @"u1");
    return promoted;
}

pub fn alphabet_shrink_index(alphabet: []const u8, rank: u64) u64 {
    var size: u64 = undefined;
    var past_end: bool = undefined;
    var pivot: u64 = undefined;
    var last: u64 = undefined;
    var promoted: u64 = undefined;
    var in_promoted: bool = undefined;
    var index: u64 = undefined;
    var displaced: bool = undefined;
    size = alphabet_size(alphabet);
    past_end = (rank >= size);
    if (past_end) {
        return rank;
    }
    pivot = alphabet_shrink_pivot(alphabet);
    last = alphabet_shrink_last(alphabet);
    promoted = alphabet_shrink_promoted(alphabet);
    in_promoted = (rank < promoted);
    if (in_promoted) {
        index = (pivot +% rank);
        return index;
    }
    displaced = (rank <= last);
    if (displaced) {
        index = (rank -% promoted);
        return index;
    }
    return rank;
}

pub fn alphabet_shrink_rank(alphabet: []const u8, index: u64) u64 {
    var size: u64 = undefined;
    var past_end: bool = undefined;
    var pivot: u64 = undefined;
    var last: u64 = undefined;
    var promoted: u64 = undefined;
    var at_or_above: bool = undefined;
    var at_or_below: bool = undefined;
    var in_promoted: bool = undefined;
    var rank: u64 = undefined;
    var below: bool = undefined;
    size = alphabet_size(alphabet);
    past_end = (index >= size);
    if (past_end) {
        return index;
    }
    pivot = alphabet_shrink_pivot(alphabet);
    last = alphabet_shrink_last(alphabet);
    promoted = alphabet_shrink_promoted(alphabet);
    at_or_above = (index >= pivot);
    at_or_below = (index <= last);
    in_promoted = (at_or_above and at_or_below);
    if (in_promoted) {
        rank = (index -% pivot);
        return rank;
    }
    below = (index < pivot);
    if (below) {
        rank = (index +% promoted);
        return rank;
    }
    return index;
}

pub fn alphabet_shrink_codepoint(alphabet: []const u8, rank: u64) ?u64 {
    var index: u64 = undefined;
    var codepoint: ?u64 = undefined;
    index = alphabet_shrink_index(alphabet, rank);
    codepoint = alphabet_codepoint_at(alphabet, index);
    return codepoint;
}

pub fn alphabet_range(min_codepoint: u64, max_codepoint: u64) []u8 {
    var out: []u8 = undefined;
    var max: u64 = undefined;
    var surrogate_below: u64 = undefined;
    var surrogate_above: u64 = undefined;
    var low: u64 = undefined;
    var high: u64 = undefined;
    var over: bool = undefined;
    var empty: bool = undefined;
    var starts_below: bool = undefined;
    var first_end: u64 = undefined;
    var clip: bool = undefined;
    var start_bytes: []u8 = undefined;
    var end_bytes: []u8 = undefined;
    var ends_above: bool = undefined;
    var second_start: u64 = undefined;
    var lift: bool = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    max = 1114111;
    surrogate_below = 55295;
    surrogate_above = 57344;
    low = min_codepoint;
    high = max_codepoint;
    over = (high > max);
    if (over) {
        high = max;
    }
    empty = (low > high);
    if (empty) {
        return out;
    }
    starts_below = (low <= surrogate_below);
    if (starts_below) {
        first_end = high;
        clip = (first_end > surrogate_below);
        if (clip) {
            first_end = surrogate_below;
        }
        start_bytes = u32_to_le(low);
        end_bytes = u32_to_le(first_end);
        out = append_bytes(out, start_bytes);
        out = append_bytes(out, end_bytes);
    }
    ends_above = (high >= surrogate_above);
    if (ends_above) {
        second_start = low;
        lift = (second_start < surrogate_above);
        if (lift) {
            second_start = surrogate_above;
        }
        start_bytes = u32_to_le(second_start);
        end_bytes = u32_to_le(high);
        out = append_bytes(out, start_bytes);
        out = append_bytes(out, end_bytes);
    }
    return out;
}

pub fn alphabet_insert(alphabet: []const u8, codepoint: u64) []u8 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var count: u64 = undefined;
    var out: []u8 = undefined;
    var allowed: bool = undefined;
    var rejected: bool = undefined;
    var unchanged: []u8 = undefined;
    var pending_start: u64 = undefined;
    var pending_end: u64 = undefined;
    var placed: bool = undefined;
    var interval: u64 = undefined;
    var done: bool = undefined;
    var start: u64 = undefined;
    var end_: u64 = undefined;
    var gap_start: u64 = undefined;
    var strictly_below: bool = undefined;
    var start_bytes: []u8 = undefined;
    var end_bytes: []u8 = undefined;
    var touches_below: bool = undefined;
    var gap_end: u64 = undefined;
    var strictly_above: bool = undefined;
    var not_yet: bool = undefined;
    var pending_start_bytes: []u8 = undefined;
    var pending_end_bytes: []u8 = undefined;
    var overlaps: bool = undefined;
    var lower: bool = undefined;
    var higher: bool = undefined;
    var unplaced: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    count = alphabet_interval_count(alphabet);
    out = allocator.alloc(u8, 0) catch unreachable;
    allowed = alphabet_codepoint_allowed(codepoint);
    rejected = (!allowed);
    if (rejected) {
        unchanged = append_bytes(out, alphabet);
        return unchanged;
    }
    pending_start = codepoint;
    pending_end = codepoint;
    placed = false;
    interval = @"u0";
    while (true) {
        done = (interval >= count);
        if (done) {
            break;
        }
        start = alphabet_interval_start(alphabet, interval);
        end_ = alphabet_interval_end(alphabet, interval);
        gap_start = (end_ +% @"u1");
        strictly_below = (gap_start < pending_start);
        if (strictly_below) {
            start_bytes = u32_to_le(start);
            end_bytes = u32_to_le(end_);
            out = append_bytes(out, start_bytes);
            out = append_bytes(out, end_bytes);
        }
        touches_below = (!strictly_below);
        if (touches_below) {
            gap_end = (pending_end +% @"u1");
            strictly_above = (start > gap_end);
            if (strictly_above) {
                not_yet = (!placed);
                if (not_yet) {
                    pending_start_bytes = u32_to_le(pending_start);
                    pending_end_bytes = u32_to_le(pending_end);
                    out = append_bytes(out, pending_start_bytes);
                    out = append_bytes(out, pending_end_bytes);
                    placed = true;
                }
                start_bytes = u32_to_le(start);
                end_bytes = u32_to_le(end_);
                out = append_bytes(out, start_bytes);
                out = append_bytes(out, end_bytes);
            }
            overlaps = (!strictly_above);
            if (overlaps) {
                lower = (start < pending_start);
                if (lower) {
                    pending_start = start;
                }
                higher = (end_ > pending_end);
                if (higher) {
                    pending_end = end_;
                }
            }
        }
        interval = (interval +% @"u1");
    }
    unplaced = (!placed);
    if (unplaced) {
        pending_start_bytes = u32_to_le(pending_start);
        pending_end_bytes = u32_to_le(pending_end);
        out = append_bytes(out, pending_start_bytes);
        out = append_bytes(out, pending_end_bytes);
    }
    return out;
}

pub fn string_length(value: []const u8) i64 {
    var @"u2": u64 = undefined;
    var length: i64 = undefined;
    var length_u64: u64 = undefined;
    var count_u64: u64 = undefined;
    var count: i64 = undefined;
    @"u2" = 2;
    length = @intCast(value.len);
    length_u64 = @bitCast(length);
    count_u64 = (length_u64 >> @intCast(@"u2"));
    count = @bitCast(count_u64);
    return count;
}

pub fn string_codepoint_at(value: []const u8, position: i64) u64 {
    var @"i4": i64 = undefined;
    var offset: i64 = undefined;
    var codepoint: u64 = undefined;
    @"i4" = 4;
    offset = (position * @"i4");
    codepoint = read_u32_le(value, offset);
    return codepoint;
}

pub fn string_validate(alphabet: []const u8, min_size: i64, max_size: i64, value: []const u8) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i4": i64 = undefined;
    var length: i64 = undefined;
    var count: i64 = undefined;
    var exact: i64 = undefined;
    var ragged: bool = undefined;
    var too_short: bool = undefined;
    var too_long: bool = undefined;
    var position: i64 = undefined;
    var done: bool = undefined;
    var codepoint: u64 = undefined;
    var member: bool = undefined;
    var outside: bool = undefined;
    false_ = false;
    true_ = true;
    @"i0" = 0;
    @"i1" = 1;
    @"i4" = 4;
    length = @intCast(value.len);
    count = string_length(value);
    exact = (count * @"i4");
    ragged = (exact != length);
    if (ragged) {
        return false_;
    }
    too_short = (count < min_size);
    if (too_short) {
        return false_;
    }
    too_long = (count > max_size);
    if (too_long) {
        return false_;
    }
    position = @"i0";
    while (true) {
        done = (position >= count);
        if (done) {
            break;
        }
        codepoint = string_codepoint_at(value, position);
        member = alphabet_contains(alphabet, codepoint);
        outside = (!member);
        if (outside) {
            return false_;
        }
        position = (position + @"i1");
    }
    return true_;
}

pub fn string_simplest(alphabet: []const u8, min_size: i64) []u8 {
    var out: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var first: ?u64 = undefined;
    var present: bool = undefined;
    var empty_alphabet: bool = undefined;
    var codepoint: u64 = undefined;
    var packed_: []u8 = undefined;
    var position: i64 = undefined;
    var done: bool = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    first = alphabet_shrink_codepoint(alphabet, @"u0");
    present = first != null;
    empty_alphabet = (!present);
    if (empty_alphabet) {
        return out;
    }
    codepoint = first.?;
    packed_ = u32_to_le(codepoint);
    position = @"i0";
    while (true) {
        done = (position >= min_size);
        if (done) {
            break;
        }
        out = append_bytes(out, packed_);
        position = (position + @"i1");
    }
    return out;
}

pub fn string_unit(alphabet: []const u8, min_size: i64, max_size: i64) []u8 {
    var out: []u8 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var first: ?u64 = undefined;
    var present: bool = undefined;
    var empty_alphabet: bool = undefined;
    var lowest: u64 = undefined;
    var next_: ?u64 = undefined;
    var has_next: bool = undefined;
    var stepped: u64 = undefined;
    var second: u64 = undefined;
    var lowest_packed: []u8 = undefined;
    var stepped_packed: []u8 = undefined;
    var has_minimum: bool = undefined;
    var last: i64 = undefined;
    var position: i64 = undefined;
    var done: bool = undefined;
    var is_last: bool = undefined;
    var is_earlier: bool = undefined;
    var has_room: bool = undefined;
    out = allocator.alloc(u8, 0) catch unreachable;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    first = alphabet_shrink_codepoint(alphabet, @"u0");
    present = first != null;
    empty_alphabet = (!present);
    if (empty_alphabet) {
        return out;
    }
    lowest = first.?;
    next_ = alphabet_shrink_codepoint(alphabet, @"u1");
    has_next = next_ != null;
    stepped = lowest;
    if (has_next) {
        second = next_.?;
        stepped = second;
    }
    lowest_packed = u32_to_le(lowest);
    stepped_packed = u32_to_le(stepped);
    has_minimum = (min_size > @"i0");
    if (has_minimum) {
        last = (min_size - @"i1");
        position = @"i0";
        while (true) {
            done = (position >= min_size);
            if (done) {
                break;
            }
            is_last = (position == last);
            if (is_last) {
                out = append_bytes(out, stepped_packed);
            }
            is_earlier = (!is_last);
            if (is_earlier) {
                out = append_bytes(out, lowest_packed);
            }
            position = (position + @"i1");
        }
        return out;
    }
    has_room = (max_size > @"i0");
    if (has_room) {
        out = append_bytes(out, stepped_packed);
    }
    return out;
}

pub fn string_duplicate_rank(alphabet: []const u8, value: []const u8) ?u64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var length: i64 = undefined;
    var ranks: []u8 = undefined;
    var at: i64 = undefined;
    var done: bool = undefined;
    var codepoint: u64 = undefined;
    var index: ?u64 = undefined;
    var present: bool = undefined;
    var stored: u64 = undefined;
    var index_value: u64 = undefined;
    var rank: u64 = undefined;
    var stored_byte: u64 = undefined;
    var packed_all: bool = undefined;
    var stored_low: u64 = undefined;
    var best: u64 = undefined;
    var found: bool = undefined;
    var lowerable: bool = undefined;
    var improves: bool = undefined;
    var not_found: bool = undefined;
    var better: bool = undefined;
    var worth_counting: bool = undefined;
    var seen: u64 = undefined;
    var other: i64 = undefined;
    var counted: bool = undefined;
    var other_stored: u64 = undefined;
    var same: bool = undefined;
    var twice: bool = undefined;
    var repeated: bool = undefined;
    var missing: bool = undefined;
    var none: ?u64 = undefined;
    var some: ?u64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u4" = 4;
    @"u8" = 8;
    @"u255" = 255;
    length = string_length(value);
    ranks = allocator.alloc(u8, 0) catch unreachable;
    at = @"i0";
    while (true) {
        done = (at >= length);
        if (done) {
            break;
        }
        codepoint = string_codepoint_at(value, at);
        index = alphabet_index_of(alphabet, codepoint);
        present = index != null;
        stored = @"u0";
        if (present) {
            index_value = index.?;
            rank = alphabet_shrink_rank(alphabet, index_value);
            stored = (rank +% @"u1");
        }
        stored_byte = @"u0";
        while (true) {
            packed_all = (stored_byte == @"u4");
            if (packed_all) {
                break;
            }
            stored_low = (stored & @"u255");
            ranks = allocator.realloc(ranks, ranks.len + 1) catch unreachable;
            ranks[ranks.len - 1] = @truncate(stored_low);
            stored = (stored >> @intCast(@"u8"));
            stored_byte = (stored_byte +% @"u1");
        }
        at = (at + @"i1");
    }
    best = @"u0";
    found = false;
    at = @"i0";
    while (true) {
        done = (at >= length);
        if (done) {
            break;
        }
        stored = string_codepoint_at(ranks, at);
        present = (stored != @"u0");
        if (present) {
            rank = (stored -% @"u1");
            lowerable = (rank != @"u0");
            improves = (rank > best);
            not_found = (!found);
            better = (improves or not_found);
            worth_counting = (lowerable and better);
            if (worth_counting) {
                seen = @"u0";
                other = @"i0";
                while (true) {
                    counted = (other >= length);
                    if (counted) {
                        break;
                    }
                    other_stored = string_codepoint_at(ranks, other);
                    same = (other_stored == stored);
                    if (same) {
                        seen = (seen +% @"u1");
                        twice = (seen >= @"u2");
                        if (twice) {
                            break;
                        }
                    }
                    other = (other + @"i1");
                }
                repeated = (seen >= @"u2");
                if (repeated) {
                    best = rank;
                    found = true;
                }
            }
        }
        at = (at + @"i1");
    }
    missing = (!found);
    if (missing) {
        none = null;
        return none;
    }
    some = best;
    return some;
}

pub fn string_replace_rank(alphabet: []const u8, value: []const u8, from_rank: u64, to_rank: u64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var unchanged: bool = undefined;
    var none_same: ?[]u8 = undefined;
    var target: ?u64 = undefined;
    var target_present: bool = undefined;
    var target_missing: bool = undefined;
    var none_target: ?[]u8 = undefined;
    var target_codepoint: u64 = undefined;
    var length: i64 = undefined;
    var out: []u8 = undefined;
    var at: i64 = undefined;
    var done: bool = undefined;
    var codepoint: u64 = undefined;
    var emitted: u64 = undefined;
    var index: ?u64 = undefined;
    var present: bool = undefined;
    var index_value: u64 = undefined;
    var rank: u64 = undefined;
    var matches: bool = undefined;
    var packed_: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    unchanged = (from_rank == to_rank);
    if (unchanged) {
        none_same = null;
        return none_same;
    }
    target = alphabet_shrink_codepoint(alphabet, to_rank);
    target_present = target != null;
    target_missing = (!target_present);
    if (target_missing) {
        none_target = null;
        return none_target;
    }
    target_codepoint = target.?;
    length = string_length(value);
    out = allocator.alloc(u8, 0) catch unreachable;
    at = @"i0";
    while (true) {
        done = (at >= length);
        if (done) {
            break;
        }
        codepoint = string_codepoint_at(value, at);
        emitted = codepoint;
        index = alphabet_index_of(alphabet, codepoint);
        present = index != null;
        if (present) {
            index_value = index.?;
            rank = alphabet_shrink_rank(alphabet, index_value);
            matches = (rank == from_rank);
            if (matches) {
                emitted = target_codepoint;
            }
        }
        packed_ = u32_to_le(emitted);
        out = append_bytes(out, packed_);
        at = (at + @"i1");
    }
    some = out;
    return some;
}

pub fn string_drop_character(value: []const u8, min_size: i64, position: i64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var length: i64 = undefined;
    var at_minimum: bool = undefined;
    var none_minimum: ?[]u8 = undefined;
    var before_start: bool = undefined;
    var none_before: ?[]u8 = undefined;
    var past_end: bool = undefined;
    var none_past: ?[]u8 = undefined;
    var @"i4": i64 = undefined;
    var whole: i64 = undefined;
    var drop_start: i64 = undefined;
    var drop_end: i64 = undefined;
    var out: []u8 = undefined;
    var at: i64 = undefined;
    var done: bool = undefined;
    var before: bool = undefined;
    var after: bool = undefined;
    var kept: bool = undefined;
    var byte_: u64 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    length = string_length(value);
    at_minimum = (length <= min_size);
    if (at_minimum) {
        none_minimum = null;
        return none_minimum;
    }
    before_start = (position < @"i0");
    if (before_start) {
        none_before = null;
        return none_before;
    }
    past_end = (position >= length);
    if (past_end) {
        none_past = null;
        return none_past;
    }
    @"i4" = 4;
    whole = (length * @"i4");
    drop_start = (position * @"i4");
    drop_end = (drop_start + @"i4");
    out = allocator.alloc(u8, 0) catch unreachable;
    at = @"i0";
    while (true) {
        done = (at >= whole);
        if (done) {
            break;
        }
        before = (at < drop_start);
        after = (at >= drop_end);
        kept = (before or after);
        if (kept) {
            byte_ = @intCast(value[@intCast(at)]);
            out = allocator.realloc(out, out.len + 1) catch unreachable;
            out[out.len - 1] = @truncate(byte_);
        }
        at = (at + @"i1");
    }
    some = out;
    return some;
}

pub fn string_to_index(alphabet: []const u8, min_size: i64, value: []const u8) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var size: u64 = undefined;
    var count: i64 = undefined;
    var offset: []u8 = undefined;
    var has_offset: bool = undefined;
    var length: i64 = undefined;
    var done: bool = undefined;
    var scale: i64 = undefined;
    var position: []u8 = undefined;
    var pos: i64 = undefined;
    var codepoint: u64 = undefined;
    var found: ?u64 = undefined;
    var present: bool = undefined;
    var rank: u64 = undefined;
    var alphabet_index: u64 = undefined;
    var index: []u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    size = alphabet_size(alphabet);
    count = string_length(value);
    offset = bigint_zero();
    has_offset = (count > min_size);
    if (has_offset) {
        length = min_size;
        while (true) {
            done = (length >= count);
            if (done) {
                break;
            }
            offset = positive_mul_add_small_le(offset, size, @"u1");
            length = (length + @"i1");
        }
        scale = @"i0";
        while (true) {
            done = (scale >= min_size);
            if (done) {
                break;
            }
            offset = positive_mul_add_small_le(offset, size, @"u0");
            scale = (scale + @"i1");
        }
    }
    position = bigint_zero();
    pos = @"i0";
    while (true) {
        done = (pos >= count);
        if (done) {
            break;
        }
        codepoint = string_codepoint_at(value, pos);
        found = alphabet_index_of(alphabet, codepoint);
        present = found != null;
        rank = @"u0";
        if (present) {
            alphabet_index = found.?;
            rank = alphabet_shrink_rank(alphabet, alphabet_index);
        }
        position = positive_mul_add_small_le(position, size, rank);
        pos = (pos + @"i1");
    }
    index = signed_add_le(offset, position);
    return index;
}

pub fn string_index_compare(alphabet: []const u8, min_size: i64, left: []const u8, right: []const u8) i64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var negative_one: i64 = undefined;
    var size: u64 = undefined;
    var left_count: i64 = undefined;
    var right_count: i64 = undefined;
    var has_members: bool = undefined;
    var left_sized: bool = undefined;
    var right_sized: bool = undefined;
    var both_sized: bool = undefined;
    var direct: bool = undefined;
    var indirect: bool = undefined;
    var left_index: []u8 = undefined;
    var right_index: []u8 = undefined;
    var order: i64 = undefined;
    var left_shorter: bool = undefined;
    var left_longer: bool = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var left_codepoint: u64 = undefined;
    var right_codepoint: u64 = undefined;
    var differs: bool = undefined;
    var left_found: ?u64 = undefined;
    var left_present: bool = undefined;
    var left_rank: u64 = undefined;
    var left_alphabet_index: u64 = undefined;
    var right_found: ?u64 = undefined;
    var right_present: bool = undefined;
    var right_rank: u64 = undefined;
    var right_alphabet_index: u64 = undefined;
    var rank_less: bool = undefined;
    var rank_greater: bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    negative_one = (@"i0" - @"i1");
    size = alphabet_size(alphabet);
    left_count = string_length(left);
    right_count = string_length(right);
    has_members = (size != @"u0");
    left_sized = (left_count >= min_size);
    right_sized = (right_count >= min_size);
    both_sized = (left_sized and right_sized);
    direct = (has_members and both_sized);
    indirect = (!direct);
    if (indirect) {
        left_index = string_to_index(alphabet, min_size, left);
        right_index = string_to_index(alphabet, min_size, right);
        order = signed_compare_le(left_index, right_index);
        return order;
    }
    left_shorter = (left_count < right_count);
    if (left_shorter) {
        return negative_one;
    }
    left_longer = (left_count > right_count);
    if (left_longer) {
        return @"i1";
    }
    pos = @"i0";
    while (true) {
        done = (pos >= left_count);
        if (done) {
            break;
        }
        left_codepoint = string_codepoint_at(left, pos);
        right_codepoint = string_codepoint_at(right, pos);
        differs = (left_codepoint != right_codepoint);
        if (differs) {
            left_found = alphabet_index_of(alphabet, left_codepoint);
            left_present = left_found != null;
            left_rank = @"u0";
            if (left_present) {
                left_alphabet_index = left_found.?;
                left_rank = alphabet_shrink_rank(alphabet, left_alphabet_index);
            }
            right_found = alphabet_index_of(alphabet, right_codepoint);
            right_present = right_found != null;
            right_rank = @"u0";
            if (right_present) {
                right_alphabet_index = right_found.?;
                right_rank = alphabet_shrink_rank(alphabet, right_alphabet_index);
            }
            rank_less = (left_rank < right_rank);
            if (rank_less) {
                return negative_one;
            }
            rank_greater = (left_rank > right_rank);
            if (rank_greater) {
                return @"i1";
            }
        }
        pos = (pos + @"i1");
    }
    return @"i0";
}

pub fn string_max_index(alphabet: []const u8, min_size: i64, max_size: i64) []u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var size: u64 = undefined;
    var no_members: bool = undefined;
    var zero: []u8 = undefined;
    var top_rank: u64 = undefined;
    var top: ?u64 = undefined;
    var present: bool = undefined;
    var missing: bool = undefined;
    var codepoint: u64 = undefined;
    var packed_: []u8 = undefined;
    var last: []u8 = undefined;
    var position: i64 = undefined;
    var done: bool = undefined;
    var index: []u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    size = alphabet_size(alphabet);
    no_members = (size == @"u0");
    if (no_members) {
        zero = bigint_zero();
        return zero;
    }
    top_rank = (size -% @"u1");
    top = alphabet_shrink_codepoint(alphabet, top_rank);
    present = top != null;
    missing = (!present);
    if (missing) {
        zero = bigint_zero();
        return zero;
    }
    codepoint = top.?;
    packed_ = u32_to_le(codepoint);
    last = allocator.alloc(u8, 0) catch unreachable;
    position = @"i0";
    while (true) {
        done = (position >= max_size);
        if (done) {
            break;
        }
        last = append_bytes(last, packed_);
        position = (position + @"i1");
    }
    index = string_to_index(alphabet, min_size, last);
    return index;
}

pub fn string_from_index(alphabet: []const u8, min_size: i64, max_size: i64, index_raw: []const u8) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i8": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u255": u64 = undefined;
    var size: u64 = undefined;
    var no_members: bool = undefined;
    var none: ?[]u8 = undefined;
    var remaining: []u8 = undefined;
    var remaining_n: i64 = undefined;
    var remaining_bits: i64 = undefined;
    var narrow: bool = undefined;
    var several: bool = undefined;
    var first_bucket: bool = undefined;
    var bucket: []u8 = undefined;
    var build_bucket: bool = undefined;
    var scale: i64 = undefined;
    var done: bool = undefined;
    var length: i64 = undefined;
    var past_end: bool = undefined;
    var bucket_cmp: i64 = undefined;
    var inside_bucket: bool = undefined;
    var ranks: []u8 = undefined;
    var pos: i64 = undefined;
    var rank: u64 = undefined;
    var rank_byte: u64 = undefined;
    var packed_all: bool = undefined;
    var rank_low: u64 = undefined;
    var out: []u8 = undefined;
    var found: ?u64 = undefined;
    var present: bool = undefined;
    var codepoint: u64 = undefined;
    var codepoint_byte: u64 = undefined;
    var codepoint_low: u64 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i8" = 8;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u4" = 4;
    @"u8" = 8;
    @"u255" = 255;
    size = alphabet_size(alphabet);
    no_members = (size == @"u0");
    if (no_members) {
        none = null;
        return none;
    }
    remaining = signed_abs_le(index_raw);
    remaining_n = @intCast(remaining.len);
    remaining_bits = (remaining_n * @"i8");
    narrow = (remaining_bits <= min_size);
    several = (size >= @"u2");
    first_bucket = (narrow and several);
    bucket = bigint_one();
    build_bucket = (!first_bucket);
    if (build_bucket) {
        scale = @"i0";
        while (true) {
            done = (scale >= min_size);
            if (done) {
                break;
            }
            bucket = positive_mul_add_small_le(bucket, size, @"u0");
            scale = (scale + @"i1");
        }
    }
    length = min_size;
    while (true) {
        past_end = (length > max_size);
        if (past_end) {
            break;
        }
        bucket_cmp = signed_compare_le(remaining, bucket);
        inside_bucket = (bucket_cmp < @"i0");
        inside_bucket = (inside_bucket or first_bucket);
        if (inside_bucket) {
            ranks = allocator.alloc(u8, 0) catch unreachable;
            pos = @"i0";
            while (true) {
                done = (pos >= length);
                if (done) {
                    break;
                }
                rank = positive_rem_small_le(remaining, size);
                rank_byte = @"u0";
                while (true) {
                    packed_all = (rank_byte == @"u4");
                    if (packed_all) {
                        break;
                    }
                    rank_low = (rank & @"u255");
                    ranks = allocator.realloc(ranks, ranks.len + 1) catch unreachable;
                    ranks[ranks.len - 1] = @truncate(rank_low);
                    rank = (rank >> @intCast(@"u8"));
                    rank_byte = (rank_byte +% @"u1");
                }
                remaining = positive_div_small_le(remaining, size);
                pos = (pos + @"i1");
            }
            out = allocator.alloc(u8, 0) catch unreachable;
            pos = length;
            while (true) {
                done = (pos == @"i0");
                if (done) {
                    break;
                }
                pos = (pos - @"i1");
                rank = string_codepoint_at(ranks, pos);
                found = alphabet_shrink_codepoint(alphabet, rank);
                present = found != null;
                codepoint = @"u0";
                if (present) {
                    codepoint = found.?;
                }
                codepoint_byte = @"u0";
                while (true) {
                    packed_all = (codepoint_byte == @"u4");
                    if (packed_all) {
                        break;
                    }
                    codepoint_low = (codepoint & @"u255");
                    out = allocator.realloc(out, out.len + 1) catch unreachable;
                    out[out.len - 1] = @truncate(codepoint_low);
                    codepoint = (codepoint >> @intCast(@"u8"));
                    codepoint_byte = (codepoint_byte +% @"u1");
                }
            }
            some = out;
            return some;
        }
        remaining = signed_sub_le(remaining, bucket);
        bucket = positive_mul_add_small_le(bucket, size, @"u0");
        length = (length + @"i1");
    }
    none = null;
    return none;
}

pub fn choice_delete_range(data: []const u8, start_index: u64, end_index: u64) ?[]u8 {
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var stream_valid: bool = undefined;
    var stream_invalid: bool = undefined;
    var none: ?[]u8 = undefined;
    var count: u64 = undefined;
    var ordered: bool = undefined;
    var end_valid: bool = undefined;
    var bounds_valid: bool = undefined;
    var bounds_invalid: bool = undefined;
    var position: i64 = undefined;
    var index: u64 = undefined;
    var start_offset: i64 = undefined;
    var done: bool = undefined;
    var at_start: bool = undefined;
    var next_: i64 = undefined;
    var empty_range: bool = undefined;
    var end_offset: i64 = undefined;
    var data_end: i64 = undefined;
    var before: []u8 = undefined;
    var after: []u8 = undefined;
    var removed: u64 = undefined;
    var new_count: u64 = undefined;
    var header: []u8 = undefined;
    var with_before: []u8 = undefined;
    var out: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i4" = 4;
    @"u0" = 0;
    @"u1" = 1;
    stream_valid = choice_stream_validate(data);
    stream_invalid = (!stream_valid);
    if (stream_invalid) {
        none = null;
        return none;
    }
    count = choice_stream_count(data);
    ordered = (start_index <= end_index);
    end_valid = (end_index <= count);
    bounds_valid = (ordered and end_valid);
    bounds_invalid = (!bounds_valid);
    if (bounds_invalid) {
        none = null;
        return none;
    }
    position = @"i4";
    index = @"u0";
    start_offset = @"i4";
    while (true) {
        done = (index >= end_index);
        if (done) {
            break;
        }
        at_start = (index == start_index);
        if (at_start) {
            start_offset = position;
        }
        next_ = choice_entry_end(data, position, @"u0");
        position = next_;
        index = (index +% @"u1");
    }
    empty_range = (start_index == end_index);
    if (empty_range) {
        start_offset = position;
    }
    end_offset = position;
    data_end = @intCast(data.len);
    before = allocator.dupe(u8, data[@intCast(@"i4")..@intCast(start_offset)]) catch unreachable;
    after = allocator.dupe(u8, data[@intCast(end_offset)..@intCast(data_end)]) catch unreachable;
    removed = (end_index -% start_index);
    new_count = (count -% removed);
    header = choice_list_header(new_count);
    with_before = append_bytes(header, before);
    out = append_bytes(with_before, after);
    some = out;
    return some;
}

pub fn choice_swap_ranges(data: []const u8, a_start: u64, a_end: u64, b_start: u64, b_end: u64) ?[]u8 {
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var stream_valid: bool = undefined;
    var stream_invalid: bool = undefined;
    var none_stream: ?[]u8 = undefined;
    var count: u64 = undefined;
    var a_ordered: bool = undefined;
    var disjoint: bool = undefined;
    var b_ordered: bool = undefined;
    var in_range: bool = undefined;
    var front_ok: bool = undefined;
    var back_ok: bool = undefined;
    var bounds_valid: bool = undefined;
    var bounds_invalid: bool = undefined;
    var none_bounds: ?[]u8 = undefined;
    var position: i64 = undefined;
    var index: u64 = undefined;
    var a_start_offset: i64 = undefined;
    var a_end_offset: i64 = undefined;
    var b_start_offset: i64 = undefined;
    var done: bool = undefined;
    var at_a_start: bool = undefined;
    var at_a_end: bool = undefined;
    var at_b_start: bool = undefined;
    var next_: i64 = undefined;
    var a_start_at_end: bool = undefined;
    var a_end_at_end: bool = undefined;
    var b_start_at_end: bool = undefined;
    var b_end_offset: i64 = undefined;
    var data_end: i64 = undefined;
    var before: []u8 = undefined;
    var first: []u8 = undefined;
    var middle: []u8 = undefined;
    var second: []u8 = undefined;
    var after: []u8 = undefined;
    var header: []u8 = undefined;
    var with_before: []u8 = undefined;
    var with_second: []u8 = undefined;
    var with_middle: []u8 = undefined;
    var with_first: []u8 = undefined;
    var out: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i4" = 4;
    @"u0" = 0;
    @"u1" = 1;
    stream_valid = choice_stream_validate(data);
    stream_invalid = (!stream_valid);
    if (stream_invalid) {
        none_stream = null;
        return none_stream;
    }
    count = choice_stream_count(data);
    a_ordered = (a_start <= a_end);
    disjoint = (a_end <= b_start);
    b_ordered = (b_start <= b_end);
    in_range = (b_end <= count);
    front_ok = (a_ordered and disjoint);
    back_ok = (b_ordered and in_range);
    bounds_valid = (front_ok and back_ok);
    bounds_invalid = (!bounds_valid);
    if (bounds_invalid) {
        none_bounds = null;
        return none_bounds;
    }
    position = @"i4";
    index = @"u0";
    a_start_offset = @"i4";
    a_end_offset = @"i4";
    b_start_offset = @"i4";
    while (true) {
        done = (index >= b_end);
        if (done) {
            break;
        }
        at_a_start = (index == a_start);
        if (at_a_start) {
            a_start_offset = position;
        }
        at_a_end = (index == a_end);
        if (at_a_end) {
            a_end_offset = position;
        }
        at_b_start = (index == b_start);
        if (at_b_start) {
            b_start_offset = position;
        }
        next_ = choice_entry_end(data, position, @"u0");
        position = next_;
        index = (index +% @"u1");
    }
    a_start_at_end = (a_start == b_end);
    if (a_start_at_end) {
        a_start_offset = position;
    }
    a_end_at_end = (a_end == b_end);
    if (a_end_at_end) {
        a_end_offset = position;
    }
    b_start_at_end = (b_start == b_end);
    if (b_start_at_end) {
        b_start_offset = position;
    }
    b_end_offset = position;
    data_end = @intCast(data.len);
    before = allocator.dupe(u8, data[@intCast(@"i4")..@intCast(a_start_offset)]) catch unreachable;
    first = allocator.dupe(u8, data[@intCast(a_start_offset)..@intCast(a_end_offset)]) catch unreachable;
    middle = allocator.dupe(u8, data[@intCast(a_end_offset)..@intCast(b_start_offset)]) catch unreachable;
    second = allocator.dupe(u8, data[@intCast(b_start_offset)..@intCast(b_end_offset)]) catch unreachable;
    after = allocator.dupe(u8, data[@intCast(b_end_offset)..@intCast(data_end)]) catch unreachable;
    header = choice_list_header(count);
    with_before = append_bytes(header, before);
    with_second = append_bytes(with_before, second);
    with_middle = append_bytes(with_second, middle);
    with_first = append_bytes(with_middle, first);
    out = append_bytes(with_first, after);
    some = out;
    return some;
}

pub fn choice_duplicate_ranges(data: []const u8, a_start: u64, a_end: u64, b_start: u64, b_end: u64, use_a: bool) ?[]u8 {
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var stream_valid: bool = undefined;
    var stream_invalid: bool = undefined;
    var none_stream: ?[]u8 = undefined;
    var count: u64 = undefined;
    var a_ordered: bool = undefined;
    var disjoint: bool = undefined;
    var b_ordered: bool = undefined;
    var in_range: bool = undefined;
    var front_ok: bool = undefined;
    var back_ok: bool = undefined;
    var bounds_valid: bool = undefined;
    var bounds_invalid: bool = undefined;
    var none_bounds: ?[]u8 = undefined;
    var position: i64 = undefined;
    var index: u64 = undefined;
    var a_start_offset: i64 = undefined;
    var a_end_offset: i64 = undefined;
    var b_start_offset: i64 = undefined;
    var done: bool = undefined;
    var at_a_start: bool = undefined;
    var at_a_end: bool = undefined;
    var at_b_start: bool = undefined;
    var next_: i64 = undefined;
    var b_end_offset: i64 = undefined;
    var data_end: i64 = undefined;
    var before: []u8 = undefined;
    var first: []u8 = undefined;
    var middle: []u8 = undefined;
    var second: []u8 = undefined;
    var after: []u8 = undefined;
    var donor: []u8 = undefined;
    var donor_count: u64 = undefined;
    var a_count: u64 = undefined;
    var b_count: u64 = undefined;
    var removed: u64 = undefined;
    var base_count: u64 = undefined;
    var twice_donor: u64 = undefined;
    var new_count: u64 = undefined;
    var header: []u8 = undefined;
    var with_before: []u8 = undefined;
    var with_first: []u8 = undefined;
    var with_middle: []u8 = undefined;
    var with_second: []u8 = undefined;
    var out: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i4" = 4;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    stream_valid = choice_stream_validate(data);
    stream_invalid = (!stream_valid);
    if (stream_invalid) {
        none_stream = null;
        return none_stream;
    }
    count = choice_stream_count(data);
    a_ordered = (a_start < a_end);
    disjoint = (a_end <= b_start);
    b_ordered = (b_start < b_end);
    in_range = (b_end <= count);
    front_ok = (a_ordered and disjoint);
    back_ok = (b_ordered and in_range);
    bounds_valid = (front_ok and back_ok);
    bounds_invalid = (!bounds_valid);
    if (bounds_invalid) {
        none_bounds = null;
        return none_bounds;
    }
    position = @"i4";
    index = @"u0";
    a_start_offset = @"i4";
    a_end_offset = @"i4";
    b_start_offset = @"i4";
    while (true) {
        done = (index >= b_end);
        if (done) {
            break;
        }
        at_a_start = (index == a_start);
        if (at_a_start) {
            a_start_offset = position;
        }
        at_a_end = (index == a_end);
        if (at_a_end) {
            a_end_offset = position;
        }
        at_b_start = (index == b_start);
        if (at_b_start) {
            b_start_offset = position;
        }
        next_ = choice_entry_end(data, position, @"u0");
        position = next_;
        index = (index +% @"u1");
    }
    b_end_offset = position;
    data_end = @intCast(data.len);
    before = allocator.dupe(u8, data[@intCast(@"i4")..@intCast(a_start_offset)]) catch unreachable;
    first = allocator.dupe(u8, data[@intCast(a_start_offset)..@intCast(a_end_offset)]) catch unreachable;
    middle = allocator.dupe(u8, data[@intCast(a_end_offset)..@intCast(b_start_offset)]) catch unreachable;
    second = allocator.dupe(u8, data[@intCast(b_start_offset)..@intCast(b_end_offset)]) catch unreachable;
    after = allocator.dupe(u8, data[@intCast(b_end_offset)..@intCast(data_end)]) catch unreachable;
    donor = allocator.dupe(u8, second) catch unreachable;
    donor_count = (b_end -% b_start);
    if (use_a) {
        donor = allocator.dupe(u8, first) catch unreachable;
        donor_count = (a_end -% a_start);
    }
    a_count = (a_end -% a_start);
    b_count = (b_end -% b_start);
    removed = (a_count +% b_count);
    base_count = (count -% removed);
    twice_donor = (donor_count *% @"u2");
    new_count = (base_count +% twice_donor);
    header = choice_list_header(new_count);
    with_before = append_bytes(header, before);
    with_first = append_bytes(with_before, donor);
    with_middle = append_bytes(with_first, middle);
    with_second = append_bytes(with_middle, donor);
    out = append_bytes(with_second, after);
    some = out;
    return some;
}

pub fn choice_duplicate_nested_prefix(data: []const u8, outer_start: u64, outer_end: u64, inner_start: u64, inner_end: u64) ?[]u8 {
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var stream_valid: bool = undefined;
    var stream_invalid: bool = undefined;
    var none_stream: ?[]u8 = undefined;
    var count: u64 = undefined;
    var outer_nonempty: bool = undefined;
    var inner_nonempty: bool = undefined;
    var starts_inside: bool = undefined;
    var ends_inside: bool = undefined;
    var in_range: bool = undefined;
    var nonempty: bool = undefined;
    var contained: bool = undefined;
    var shape_valid: bool = undefined;
    var bounds_valid: bool = undefined;
    var bounds_invalid: bool = undefined;
    var none_bounds: ?[]u8 = undefined;
    var position: i64 = undefined;
    var index: u64 = undefined;
    var outer_offset: i64 = undefined;
    var done: bool = undefined;
    var at_outer: bool = undefined;
    var next_: i64 = undefined;
    var same_start: bool = undefined;
    var inner_offset: i64 = undefined;
    var data_end: i64 = undefined;
    var before_inner: []u8 = undefined;
    var from_outer: []u8 = undefined;
    var prefix_count: u64 = undefined;
    var new_count: u64 = undefined;
    var header: []u8 = undefined;
    var with_before: []u8 = undefined;
    var out: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i4" = 4;
    @"u0" = 0;
    @"u1" = 1;
    stream_valid = choice_stream_validate(data);
    stream_invalid = (!stream_valid);
    if (stream_invalid) {
        none_stream = null;
        return none_stream;
    }
    count = choice_stream_count(data);
    outer_nonempty = (outer_start < outer_end);
    inner_nonempty = (inner_start < inner_end);
    starts_inside = (outer_start <= inner_start);
    ends_inside = (inner_end <= outer_end);
    in_range = (outer_end <= count);
    nonempty = (outer_nonempty and inner_nonempty);
    contained = (starts_inside and ends_inside);
    shape_valid = (nonempty and contained);
    bounds_valid = (shape_valid and in_range);
    bounds_invalid = (!bounds_valid);
    if (bounds_invalid) {
        none_bounds = null;
        return none_bounds;
    }
    position = @"i4";
    index = @"u0";
    outer_offset = @"i4";
    while (true) {
        done = (index >= inner_start);
        if (done) {
            break;
        }
        at_outer = (index == outer_start);
        if (at_outer) {
            outer_offset = position;
        }
        next_ = choice_entry_end(data, position, @"u0");
        position = next_;
        index = (index +% @"u1");
    }
    same_start = (outer_start == inner_start);
    if (same_start) {
        outer_offset = position;
    }
    inner_offset = position;
    data_end = @intCast(data.len);
    before_inner = allocator.dupe(u8, data[@intCast(@"i4")..@intCast(inner_offset)]) catch unreachable;
    from_outer = allocator.dupe(u8, data[@intCast(outer_offset)..@intCast(data_end)]) catch unreachable;
    prefix_count = (inner_start -% outer_start);
    new_count = (count +% prefix_count);
    header = choice_list_header(new_count);
    with_before = append_bytes(header, before_inner);
    out = append_bytes(with_before, from_outer);
    some = out;
    return some;
}

pub fn choice_mutate_ranges(data: []const u8, a_start: u64, a_end: u64, b_start: u64, b_end: u64, use_a: bool) ?[]u8 {
    var a_before_b: bool = undefined;
    var b_ends_in_a: bool = undefined;
    var a_contains_b: bool = undefined;
    var nested_a: ?[]u8 = undefined;
    var b_before_a: bool = undefined;
    var a_ends_in_b: bool = undefined;
    var b_contains_a: bool = undefined;
    var nested_b: ?[]u8 = undefined;
    var duplicate_ab: ?[]u8 = undefined;
    var use_b: bool = undefined;
    var duplicate_ba: ?[]u8 = undefined;
    a_before_b = (a_start <= b_start);
    b_ends_in_a = (b_end <= a_end);
    a_contains_b = (a_before_b and b_ends_in_a);
    if (a_contains_b) {
        nested_a = choice_duplicate_nested_prefix(data, a_start, a_end, b_start, b_end);
        return nested_a;
    }
    b_before_a = (b_start <= a_start);
    a_ends_in_b = (a_end <= b_end);
    b_contains_a = (b_before_a and a_ends_in_b);
    if (b_contains_a) {
        nested_b = choice_duplicate_nested_prefix(data, b_start, b_end, a_start, a_end);
        return nested_b;
    }
    if (a_before_b) {
        duplicate_ab = choice_duplicate_ranges(data, a_start, a_end, b_start, b_end, use_a);
        return duplicate_ab;
    }
    use_b = (!use_a);
    duplicate_ba = choice_duplicate_ranges(data, b_start, b_end, a_start, a_end, use_b);
    return duplicate_ba;
}

pub fn clone_inner_stream(data: []const u8, offset: u64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u5": u64 = undefined;
    var n: i64 = undefined;
    var at: i64 = undefined;
    var past_end: bool = undefined;
    var none: ?[]u8 = undefined;
    var tag: u64 = undefined;
    var not_clone: bool = undefined;
    var end_: i64 = undefined;
    var malformed: bool = undefined;
    var payload_start: i64 = undefined;
    var inner: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u5" = 5;
    n = @intCast(data.len);
    at = @bitCast(offset);
    past_end = (at >= n);
    if (past_end) {
        none = null;
        return none;
    }
    tag = @intCast(data[@intCast(at)]);
    not_clone = (tag != @"u5");
    if (not_clone) {
        none = null;
        return none;
    }
    end_ = choice_entry_end(data, at, @"u0");
    malformed = (end_ == @"i0");
    if (malformed) {
        none = null;
        return none;
    }
    payload_start = (at + @"i1");
    inner = allocator.dupe(u8, data[@intCast(payload_start)..@intCast(end_)]) catch unreachable;
    some = inner;
    return some;
}

pub fn clone_replace_inner(data: []const u8, offset: u64, inner: []const u8) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u5": u64 = undefined;
    var n: i64 = undefined;
    var at: i64 = undefined;
    var past_end: bool = undefined;
    var none: ?[]u8 = undefined;
    var tag: u64 = undefined;
    var not_clone: bool = undefined;
    var inner_valid: bool = undefined;
    var inner_invalid: bool = undefined;
    var end_: i64 = undefined;
    var malformed: bool = undefined;
    var prefix_end: i64 = undefined;
    var head: []u8 = undefined;
    var tail: []u8 = undefined;
    var out: []u8 = undefined;
    var with_head: []u8 = undefined;
    var with_inner: []u8 = undefined;
    var rebuilt: []u8 = undefined;
    var some: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u5" = 5;
    n = @intCast(data.len);
    at = @bitCast(offset);
    past_end = (at >= n);
    if (past_end) {
        none = null;
        return none;
    }
    tag = @intCast(data[@intCast(at)]);
    not_clone = (tag != @"u5");
    if (not_clone) {
        none = null;
        return none;
    }
    inner_valid = choice_stream_validate(inner);
    inner_invalid = (!inner_valid);
    if (inner_invalid) {
        none = null;
        return none;
    }
    end_ = choice_entry_end(data, at, @"u0");
    malformed = (end_ == @"i0");
    if (malformed) {
        none = null;
        return none;
    }
    prefix_end = (at + @"i1");
    head = allocator.dupe(u8, data[@intCast(@"i0")..@intCast(prefix_end)]) catch unreachable;
    tail = allocator.dupe(u8, data[@intCast(end_)..@intCast(n)]) catch unreachable;
    out = allocator.alloc(u8, 0) catch unreachable;
    with_head = append_bytes(out, head);
    with_inner = append_bytes(with_head, inner);
    rebuilt = append_bytes(with_inner, tail);
    some = rebuilt;
    return some;
}

pub fn choice_offset_at(data: []const u8, index: u64) ?u64 {
    var @"i0": i64 = undefined;
    var @"i4": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var stream_valid: bool = undefined;
    var stream_invalid: bool = undefined;
    var none: ?u64 = undefined;
    var count: u64 = undefined;
    var past_end: bool = undefined;
    var position: i64 = undefined;
    var seen: u64 = undefined;
    var found: bool = undefined;
    var next_: i64 = undefined;
    var malformed: bool = undefined;
    var offset: u64 = undefined;
    var some: ?u64 = undefined;
    @"i0" = 0;
    @"i4" = 4;
    @"u0" = 0;
    @"u1" = 1;
    stream_valid = choice_stream_validate(data);
    stream_invalid = (!stream_valid);
    if (stream_invalid) {
        none = null;
        return none;
    }
    count = choice_stream_count(data);
    past_end = (index >= count);
    if (past_end) {
        none = null;
        return none;
    }
    position = @"i4";
    seen = @"u0";
    while (true) {
        found = (seen >= index);
        if (found) {
            break;
        }
        next_ = choice_entry_end(data, position, @"u0");
        malformed = (next_ == @"i0");
        if (malformed) {
            none = null;
            return none;
        }
        position = next_;
        seen = (seen +% @"u1");
    }
    offset = @bitCast(position);
    some = offset;
    return some;
}

pub fn integer_boundary_eligible(candidate: i64, min_value: i64, max_value: i64) bool {
    var above_min: bool = undefined;
    var below_max: bool = undefined;
    var in_range: bool = undefined;
    var is_min: bool = undefined;
    var is_max: bool = undefined;
    var is_boundary: bool = undefined;
    var not_boundary: bool = undefined;
    var eligible: bool = undefined;
    above_min = (candidate >= min_value);
    below_max = (candidate <= max_value);
    in_range = (above_min and below_max);
    is_min = (candidate == min_value);
    is_max = (candidate == max_value);
    is_boundary = (is_min or is_max);
    not_boundary = (!is_boundary);
    eligible = (in_range and not_boundary);
    return eligible;
}

pub fn integer_boundary_candidate(min_value: i64, max_value: i64, ordinal: u64) ?i64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"i2": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u63": u64 = undefined;
    var want_min: bool = undefined;
    var some_min: ?i64 = undefined;
    var seen: u64 = undefined;
    var same_bounds: bool = undefined;
    var distinct_bounds: bool = undefined;
    var want_max: bool = undefined;
    var some_max: ?i64 = undefined;
    var zero_eligible: bool = undefined;
    var want_zero: bool = undefined;
    var some_zero: ?i64 = undefined;
    var power: i64 = undefined;
    var iteration: u64 = undefined;
    var done: bool = undefined;
    var positive_eligible: bool = undefined;
    var want_positive: bool = undefined;
    var some_positive: ?i64 = undefined;
    var negative: i64 = undefined;
    var negative_eligible: bool = undefined;
    var want_negative: bool = undefined;
    var some_negative: ?i64 = undefined;
    var has_more: bool = undefined;
    var none: ?i64 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"i2" = 2;
    @"u0" = 0;
    @"u1" = 1;
    @"u63" = 63;
    want_min = (ordinal == @"u0");
    if (want_min) {
        some_min = min_value;
        return some_min;
    }
    seen = @"u1";
    same_bounds = (min_value == max_value);
    distinct_bounds = (!same_bounds);
    if (distinct_bounds) {
        want_max = (ordinal == seen);
        if (want_max) {
            some_max = max_value;
            return some_max;
        }
        seen = (seen +% @"u1");
    }
    zero_eligible = integer_boundary_eligible(@"i0", min_value, max_value);
    if (zero_eligible) {
        want_zero = (ordinal == seen);
        if (want_zero) {
            some_zero = @"i0";
            return some_zero;
        }
        seen = (seen +% @"u1");
    }
    power = @"i1";
    iteration = @"u0";
    while (true) {
        done = (iteration >= @"u63");
        if (done) {
            break;
        }
        positive_eligible = integer_boundary_eligible(power, min_value, max_value);
        if (positive_eligible) {
            want_positive = (ordinal == seen);
            if (want_positive) {
                some_positive = power;
                return some_positive;
            }
            seen = (seen +% @"u1");
        }
        negative = (@"i0" - power);
        negative_eligible = integer_boundary_eligible(negative, min_value, max_value);
        if (negative_eligible) {
            want_negative = (ordinal == seen);
            if (want_negative) {
                some_negative = negative;
                return some_negative;
            }
            seen = (seen +% @"u1");
        }
        iteration = (iteration +% @"u1");
        has_more = (iteration < @"u63");
        if (has_more) {
            power = (power * @"i2");
        }
    }
    none = null;
    return none;
}

pub fn integer_swarm_is_wide(min_value: i64, max_value: i64) bool {
    var min_bits: u64 = undefined;
    var max_bits: u64 = undefined;
    var width: u64 = undefined;
    var @"u256": u64 = undefined;
    var wide: bool = undefined;
    min_bits = @bitCast(min_value);
    max_bits = @bitCast(max_value);
    width = (max_bits -% min_bits);
    @"u256" = 256;
    wide = (width >= @"u256");
    return wide;
}

pub fn integer_swarm_endpoint_permille(entropy: u64) u64 {
    var mask: u64 = undefined;
    var slot: u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u41": u64 = undefined;
    var @"u51": u64 = undefined;
    var @"u700": u64 = undefined;
    var @"u20": u64 = undefined;
    var @"u3": u64 = undefined;
    var endpoint_heavy: bool = undefined;
    var interesting_heavy: bool = undefined;
    var diffuse_heavy: bool = undefined;
    mask = 255;
    slot = (entropy & mask);
    @"u10" = 10;
    @"u41" = 41;
    @"u51" = 51;
    @"u700" = 700;
    @"u20" = 20;
    @"u3" = 3;
    endpoint_heavy = (slot < @"u10");
    if (endpoint_heavy) {
        return @"u700";
    }
    interesting_heavy = (slot < @"u41");
    if (interesting_heavy) {
        return @"u20";
    }
    diffuse_heavy = (slot < @"u51");
    if (diffuse_heavy) {
        return @"u20";
    }
    return @"u3";
}

pub fn integer_swarm_interesting_permille(entropy: u64) u64 {
    var mask: u64 = undefined;
    var slot: u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u41": u64 = undefined;
    var @"u51": u64 = undefined;
    var @"u100": u64 = undefined;
    var @"u700": u64 = undefined;
    var @"u80": u64 = undefined;
    var endpoint_heavy: bool = undefined;
    var interesting_heavy: bool = undefined;
    var diffuse_heavy: bool = undefined;
    mask = 255;
    slot = (entropy & mask);
    @"u10" = 10;
    @"u41" = 41;
    @"u51" = 51;
    @"u100" = 100;
    @"u700" = 700;
    @"u80" = 80;
    endpoint_heavy = (slot < @"u10");
    if (endpoint_heavy) {
        return @"u100";
    }
    interesting_heavy = (slot < @"u41");
    if (interesting_heavy) {
        return @"u700";
    }
    diffuse_heavy = (slot < @"u51");
    if (diffuse_heavy) {
        return @"u100";
    }
    return @"u80";
}

pub fn integer_swarm_diffuse_permille(entropy: u64) u64 {
    var mask: u64 = undefined;
    var slot: u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u41": u64 = undefined;
    var @"u51": u64 = undefined;
    var @"u50": u64 = undefined;
    var @"u80": u64 = undefined;
    var @"u700": u64 = undefined;
    var @"u17": u64 = undefined;
    var endpoint_heavy: bool = undefined;
    var interesting_heavy: bool = undefined;
    var diffuse_heavy: bool = undefined;
    mask = 255;
    slot = (entropy & mask);
    @"u10" = 10;
    @"u41" = 41;
    @"u51" = 51;
    @"u50" = 50;
    @"u80" = 80;
    @"u700" = 700;
    @"u17" = 17;
    endpoint_heavy = (slot < @"u10");
    if (endpoint_heavy) {
        return @"u50";
    }
    interesting_heavy = (slot < @"u41");
    if (interesting_heavy) {
        return @"u80";
    }
    diffuse_heavy = (slot < @"u51");
    if (diffuse_heavy) {
        return @"u700";
    }
    return @"u17";
}

pub fn integer_swarm_category(entropy: u64, roll: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var endpoint: u64 = undefined;
    var in_endpoint: bool = undefined;
    var interesting: u64 = undefined;
    var after_interesting: u64 = undefined;
    var in_interesting: bool = undefined;
    var diffuse: u64 = undefined;
    var after_diffuse: u64 = undefined;
    var in_diffuse: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    endpoint = integer_swarm_endpoint_permille(entropy);
    in_endpoint = (roll < endpoint);
    if (in_endpoint) {
        return @"u0";
    }
    interesting = integer_swarm_interesting_permille(entropy);
    after_interesting = (endpoint +% interesting);
    in_interesting = (roll < after_interesting);
    if (in_interesting) {
        return @"u1";
    }
    diffuse = integer_swarm_diffuse_permille(entropy);
    after_diffuse = (after_interesting +% diffuse);
    in_diffuse = (roll < after_diffuse);
    if (in_diffuse) {
        return @"u2";
    }
    return @"u3";
}

pub fn integer_swarm_endpoint_candidate(min_value: i64, max_value: i64, ordinal: u64) ?i64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"i1": i64 = undefined;
    var is_min: bool = undefined;
    var value: ?i64 = undefined;
    var is_max: bool = undefined;
    var is_min_neighbor: bool = undefined;
    var neighbor: i64 = undefined;
    var is_max_neighbor: bool = undefined;
    var none: ?i64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"i1" = 1;
    is_min = (ordinal == @"u0");
    if (is_min) {
        value = min_value;
        return value;
    }
    is_max = (ordinal == @"u1");
    if (is_max) {
        value = max_value;
        return value;
    }
    is_min_neighbor = (ordinal == @"u2");
    if (is_min_neighbor) {
        neighbor = (min_value + @"i1");
        value = neighbor;
        return value;
    }
    is_max_neighbor = (ordinal == @"u3");
    if (is_max_neighbor) {
        neighbor = (max_value - @"i1");
        value = neighbor;
        return value;
    }
    none = null;
    return none;
}

pub fn integer_swarm_diffuse_count() u64 {
    var count: u64 = undefined;
    count = 12;
    return count;
}

pub fn integer_swarm_diffuse_if_in_range(candidate: i64, min_value: i64, max_value: i64) ?i64 {
    var above_min: bool = undefined;
    var below_max: bool = undefined;
    var eligible: bool = undefined;
    var value: ?i64 = undefined;
    var none: ?i64 = undefined;
    above_min = (candidate >= min_value);
    below_max = (candidate <= max_value);
    eligible = (above_min and below_max);
    if (eligible) {
        value = candidate;
        return value;
    }
    none = null;
    return none;
}

pub fn integer_swarm_diffuse_candidate(min_value: i64, max_value: i64, ordinal: u64) ?i64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u6": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u9": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u11": u64 = undefined;
    var @"i0": i64 = undefined;
    var match_: bool = undefined;
    var candidate: i64 = undefined;
    var value: ?i64 = undefined;
    var m32768: i64 = undefined;
    var m2147483648: i64 = undefined;
    var m1000000: i64 = undefined;
    var m1000000000: i64 = undefined;
    var m6148914691236517205: i64 = undefined;
    var m81985529216486895: i64 = undefined;
    var none: ?i64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u5" = 5;
    @"u6" = 6;
    @"u7" = 7;
    @"u8" = 8;
    @"u9" = 9;
    @"u10" = 10;
    @"u11" = 11;
    @"i0" = 0;
    match_ = (ordinal == @"u0");
    if (match_) {
        candidate = 32767;
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u1");
    if (match_) {
        m32768 = 32768;
        candidate = (@"i0" - m32768);
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u2");
    if (match_) {
        candidate = 2147483647;
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u3");
    if (match_) {
        m2147483648 = 2147483648;
        candidate = (@"i0" - m2147483648);
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u4");
    if (match_) {
        candidate = 1000000;
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u5");
    if (match_) {
        m1000000 = 1000000;
        candidate = (@"i0" - m1000000);
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u6");
    if (match_) {
        candidate = 1000000000;
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u7");
    if (match_) {
        m1000000000 = 1000000000;
        candidate = (@"i0" - m1000000000);
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u8");
    if (match_) {
        candidate = 6148914691236517205;
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u9");
    if (match_) {
        m6148914691236517205 = 6148914691236517205;
        candidate = (@"i0" - m6148914691236517205);
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u10");
    if (match_) {
        candidate = 81985529216486895;
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    match_ = (ordinal == @"u11");
    if (match_) {
        m81985529216486895 = 81985529216486895;
        candidate = (@"i0" - m81985529216486895);
        value = integer_swarm_diffuse_if_in_range(candidate, min_value, max_value);
        return value;
    }
    none = null;
    return none;
}

pub fn integer_default_shrink_target(min_value: i64, max_value: i64) i64 {
    var @"i0": i64 = undefined;
    var at_or_below: bool = undefined;
    var at_or_above: bool = undefined;
    var contains_zero: bool = undefined;
    @"i0" = 0;
    at_or_below = (min_value <= @"i0");
    at_or_above = (max_value >= @"i0");
    contains_zero = (at_or_below and at_or_above);
    if (contains_zero) {
        return @"i0";
    }
    return min_value;
}

pub fn text_widened_max(min_size: u64) u64 {
    var @"u15": u64 = undefined;
    var @"u16": u64 = undefined;
    var widened: u64 = undefined;
    var below: bool = undefined;
    @"u15" = 15;
    @"u16" = 16;
    widened = (min_size +% @"u15");
    below = (widened < @"u16");
    if (below) {
        return @"u16";
    }
    return widened;
}

pub fn integer_boundary_count(min_value: i64, max_value: i64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var ordinal: u64 = undefined;
    var candidate: ?i64 = undefined;
    var present: bool = undefined;
    var done: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    ordinal = @"u0";
    while (true) {
        candidate = integer_boundary_candidate(min_value, max_value, ordinal);
        present = candidate != null;
        done = (!present);
        if (done) {
            break;
        }
        ordinal = (ordinal +% @"u1");
    }
    return ordinal;
}

pub fn float_generation_spec_valid(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64) bool {
    var false_: bool = undefined;
    var min_nan: bool = undefined;
    var max_nan: bool = undefined;
    var smallest_nan: bool = undefined;
    var zero: f64 = undefined;
    var smallest_negative: bool = undefined;
    var ordered: bool = undefined;
    var simplest: ?f64 = undefined;
    var usable: bool = undefined;
    false_ = false;
    min_nan = std.math.isNan(min_value);
    if (min_nan) {
        return false_;
    }
    max_nan = std.math.isNan(max_value);
    if (max_nan) {
        return false_;
    }
    smallest_nan = std.math.isNan(smallest_nonzero);
    if (smallest_nan) {
        return false_;
    }
    zero = 0;
    smallest_negative = (smallest_nonzero < zero);
    if (smallest_negative) {
        return false_;
    }
    ordered = sign_aware_lte(min_value, max_value);
    if (ordered) {
        simplest = float_simplest(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero);
        usable = simplest != null;
        return usable;
    }
    return false_;
}

pub fn float_entropy_below(word: u64, count: u64) u64 {
    var mask: u64 = undefined;
    var @"u32": u64 = undefined;
    var word_low: u64 = undefined;
    var word_high: u64 = undefined;
    var count_low: u64 = undefined;
    var count_high: u64 = undefined;
    var low_low: u64 = undefined;
    var low_high: u64 = undefined;
    var high_low: u64 = undefined;
    var high_high: u64 = undefined;
    var carry: u64 = undefined;
    var low_high_low: u64 = undefined;
    var high_low_low: u64 = undefined;
    var middle: u64 = undefined;
    var low_high_high: u64 = undefined;
    var high_low_high: u64 = undefined;
    var middle_high: u64 = undefined;
    var product: u64 = undefined;
    mask = 4294967295;
    @"u32" = 32;
    word_low = (word & mask);
    word_high = (word >> @intCast(@"u32"));
    count_low = (count & mask);
    count_high = (count >> @intCast(@"u32"));
    low_low = (word_low *% count_low);
    low_high = (word_low *% count_high);
    high_low = (word_high *% count_low);
    high_high = (word_high *% count_high);
    carry = (low_low >> @intCast(@"u32"));
    low_high_low = (low_high & mask);
    high_low_low = (high_low & mask);
    middle = (carry +% low_high_low);
    middle = (middle +% high_low_low);
    low_high_high = (low_high >> @intCast(@"u32"));
    high_low_high = (high_low >> @intCast(@"u32"));
    middle_high = (middle >> @intCast(@"u32"));
    product = (high_high +% low_high_high);
    product = (product +% high_low_high);
    product = (product +% middle_high);
    return product;
}

pub fn float_entropy_between(word: u64, low: u64, high: u64) u64 {
    var @"u1": u64 = undefined;
    var all: u64 = undefined;
    var span: u64 = undefined;
    var full: bool = undefined;
    var count: u64 = undefined;
    var offset: u64 = undefined;
    var value: u64 = undefined;
    @"u1" = 1;
    all = 18446744073709551615;
    span = (high -% low);
    full = (span == all);
    if (full) {
        return word;
    }
    count = (span +% @"u1");
    offset = float_entropy_below(word, count);
    value = (low +% offset);
    return value;
}

pub fn float_entropy_coin(word: u64, bit: u64) bool {
    var @"u1": u64 = undefined;
    var shifted: u64 = undefined;
    var low: u64 = undefined;
    var set: bool = undefined;
    @"u1" = 1;
    shifted = (word >> @intCast(bit));
    low = (shifted & @"u1");
    set = (low == @"u1");
    return set;
}

pub fn float_entropy_unit(word: u64) f64 {
    var @"u11": u64 = undefined;
    var scale_bits: u64 = undefined;
    var top: u64 = undefined;
    var integer: f64 = undefined;
    var scale: f64 = undefined;
    var unit: f64 = undefined;
    @"u11" = 11;
    scale_bits = 4368491638549381120;
    top = (word >> @intCast(@"u11"));
    integer = @floatFromInt(top);
    scale = @bitCast(scale_bits);
    unit = (integer * scale);
    return unit;
}

pub fn float_log_uniform_magnitude(low: f64, high: f64, exponent_word: u64, mantissa_word: u64) f64 {
    var @"u0": u64 = undefined;
    var @"u52": u64 = undefined;
    var mantissa_mask: u64 = undefined;
    var low_bits: u64 = undefined;
    var high_bits: u64 = undefined;
    var low_exponent: u64 = undefined;
    var high_exponent: u64 = undefined;
    var exponent: u64 = undefined;
    var mantissa_low: u64 = undefined;
    var at_low: bool = undefined;
    var mantissa_high: u64 = undefined;
    var at_high: bool = undefined;
    var mantissa: u64 = undefined;
    var exponent_field: u64 = undefined;
    var bits: u64 = undefined;
    var magnitude: f64 = undefined;
    @"u0" = 0;
    @"u52" = 52;
    mantissa_mask = 4503599627370495;
    low_bits = @bitCast(low);
    high_bits = @bitCast(high);
    low_exponent = (low_bits >> @intCast(@"u52"));
    high_exponent = (high_bits >> @intCast(@"u52"));
    exponent = float_entropy_between(exponent_word, low_exponent, high_exponent);
    mantissa_low = @"u0";
    at_low = (exponent == low_exponent);
    if (at_low) {
        mantissa_low = (low_bits & mantissa_mask);
    }
    mantissa_high = mantissa_mask;
    at_high = (exponent == high_exponent);
    if (at_high) {
        mantissa_high = (high_bits & mantissa_mask);
    }
    mantissa = float_entropy_between(mantissa_word, mantissa_low, mantissa_high);
    exponent_field = (exponent << @intCast(@"u52"));
    bits = (exponent_field | mantissa);
    magnitude = @bitCast(bits);
    return magnitude;
}

pub fn float_bit_length(value: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var rest: u64 = undefined;
    var length: u64 = undefined;
    var done: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    rest = value;
    length = @"u0";
    while (true) {
        done = (rest == @"u0");
        if (done) {
            break;
        }
        rest = (rest >> @intCast(@"u1"));
        length = (length +% @"u1");
    }
    return length;
}

pub fn float_log_uniform_integer(low: u64, high: u64, binade_word: u64, value_word: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var low_length: u64 = undefined;
    var high_length: u64 = undefined;
    var length: u64 = undefined;
    var first: u64 = undefined;
    var last: u64 = undefined;
    var nonzero: bool = undefined;
    var shift: u64 = undefined;
    var below_first: u64 = undefined;
    var from_: u64 = undefined;
    var low_above: bool = undefined;
    var to: u64 = undefined;
    var high_below: bool = undefined;
    var value: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    low_length = float_bit_length(low);
    high_length = float_bit_length(high);
    length = float_entropy_between(binade_word, low_length, high_length);
    first = @"u0";
    last = @"u0";
    nonzero = (length > @"u0");
    if (nonzero) {
        shift = (length -% @"u1");
        first = (@"u1" << @intCast(shift));
        below_first = (first -% @"u1");
        last = (first +% below_first);
    }
    from_ = first;
    low_above = (low > from_);
    if (low_above) {
        from_ = low;
    }
    to = last;
    high_below = (high < to);
    if (high_below) {
        to = high;
    }
    value = float_entropy_between(value_word, from_, to);
    return value;
}

pub fn f64_next_up(value: f64) f64 {
    var @"u1": u64 = undefined;
    var zero: f64 = undefined;
    var is_nan: bool = undefined;
    var infinity: f64 = undefined;
    var at_top: bool = undefined;
    var is_zero: bool = undefined;
    var smallest: f64 = undefined;
    var bits: u64 = undefined;
    var negative: bool = undefined;
    var lower: u64 = undefined;
    var toward_zero: f64 = undefined;
    var higher: u64 = undefined;
    var away: f64 = undefined;
    @"u1" = 1;
    zero = 0;
    is_nan = std.math.isNan(value);
    if (is_nan) {
        return value;
    }
    infinity = f64_infinity();
    at_top = (value == infinity);
    if (at_top) {
        return value;
    }
    is_zero = (value == zero);
    if (is_zero) {
        smallest = @bitCast(@"u1");
        return smallest;
    }
    bits = @bitCast(value);
    negative = std.math.signbit(value);
    if (negative) {
        lower = (bits -% @"u1");
        toward_zero = @bitCast(lower);
        return toward_zero;
    }
    higher = (bits +% @"u1");
    away = @bitCast(higher);
    return away;
}

pub fn f64_next_down(value: f64) f64 {
    var negated: f64 = undefined;
    var up: f64 = undefined;
    var down: f64 = undefined;
    negated = f64_neg(value);
    up = f64_next_up(negated);
    down = f64_neg(up);
    return down;
}

pub fn f64_floor(value: f64) f64 {
    var one: f64 = undefined;
    var ceiling: f64 = undefined;
    var integral: bool = undefined;
    var floor: f64 = undefined;
    one = 1;
    ceiling = @ceil(value);
    integral = (ceiling == value);
    if (integral) {
        return ceiling;
    }
    floor = (ceiling - one);
    return floor;
}

pub fn float_category_is_point(category: u64) bool {
    var @"u9": u64 = undefined;
    var @"u13": u64 = undefined;
    var from_nan: bool = undefined;
    var to_zero: bool = undefined;
    var point: bool = undefined;
    @"u9" = 9;
    @"u13" = 13;
    from_nan = (category >= @"u9");
    to_zero = (category <= @"u13");
    point = (from_nan and to_zero);
    return point;
}

pub fn float_swarm_weight(entropy: u64, category: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u12": u64 = undefined;
    var @"u15": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u17": u64 = undefined;
    var @"u34": u64 = undefined;
    var @"u50": u64 = undefined;
    var @"u52": u64 = undefined;
    var @"u64": u64 = undefined;
    var @"u150": u64 = undefined;
    var @"u200": u64 = undefined;
    var @"u255": u64 = undefined;
    var @"u541": u64 = undefined;
    var @"u1000": u64 = undefined;
    var out_of_range: bool = undefined;
    var is_default: bool = undefined;
    var point: bool = undefined;
    var slot: u64 = undefined;
    var ordinary: bool = undefined;
    var focus_field: u64 = undefined;
    var focus: u64 = undefined;
    var level_field: u64 = undefined;
    var level_step: u64 = undefined;
    var level_rise: u64 = undefined;
    var level: u64 = undefined;
    var floor: u64 = undefined;
    var focus_point: bool = undefined;
    var claimed: u64 = undefined;
    var rest: u64 = undefined;
    var is_focus: bool = undefined;
    @"u0" = 0;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u8" = 8;
    @"u12" = 12;
    @"u15" = 15;
    @"u16" = 16;
    @"u17" = 17;
    @"u34" = 34;
    @"u50" = 50;
    @"u52" = 52;
    @"u64" = 64;
    @"u150" = 150;
    @"u200" = 200;
    @"u255" = 255;
    @"u541" = 541;
    @"u1000" = 1000;
    out_of_range = (category > @"u16");
    if (out_of_range) {
        return @"u0";
    }
    is_default = (category == @"u16");
    point = float_category_is_point(category);
    slot = (entropy & @"u255");
    ordinary = (slot >= @"u64");
    if (ordinary) {
        if (is_default) {
            return @"u541";
        }
        if (point) {
            return @"u17";
        }
        return @"u34";
    }
    focus_field = (entropy >> @intCast(@"u8"));
    focus = (focus_field & @"u15");
    level_field = (entropy >> @intCast(@"u12"));
    level_step = (level_field & @"u3");
    level_rise = (level_step *% @"u150");
    level = (@"u200" +% level_rise);
    if (is_default) {
        floor = @"u50";
        focus_point = float_category_is_point(focus);
        if (focus_point) {
            floor = @"u52";
        }
        claimed = (level +% floor);
        rest = (@"u1000" -% claimed);
        return rest;
    }
    is_focus = (category == focus);
    if (is_focus) {
        return level;
    }
    if (point) {
        return @"u2";
    }
    return @"u4";
}

pub fn float_swarm_total(entropy: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u17": u64 = undefined;
    var total: u64 = undefined;
    var category: u64 = undefined;
    var done: bool = undefined;
    var weight: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u17" = 17;
    total = @"u0";
    category = @"u0";
    while (true) {
        done = (category >= @"u17");
        if (done) {
            break;
        }
        weight = float_swarm_weight(entropy, category);
        total = (total +% weight);
        category = (category +% @"u1");
    }
    return total;
}

pub fn float_swarm_roll_span() u64 {
    var span: u64 = undefined;
    span = 1000;
    return span;
}

pub fn float_swarm_category(entropy: u64, roll: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u16": u64 = undefined;
    var reached: u64 = undefined;
    var category: u64 = undefined;
    var done: bool = undefined;
    var weight: u64 = undefined;
    var inside: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u16" = 16;
    reached = @"u0";
    category = @"u0";
    while (true) {
        done = (category >= @"u16");
        if (done) {
            break;
        }
        weight = float_swarm_weight(entropy, category);
        reached = (reached +% weight);
        inside = (roll < reached);
        if (inside) {
            return category;
        }
        category = (category +% @"u1");
    }
    return @"u16";
}

pub fn float_side_low(min_value: f64, max_value: f64, smallest_nonzero: f64, negative: bool) f64 {
    var @"u1": u64 = undefined;
    var low: f64 = undefined;
    var under_smallest: bool = undefined;
    var tiniest: f64 = undefined;
    var under_tiniest: bool = undefined;
    @"u1" = 1;
    low = min_value;
    if (negative) {
        low = f64_neg(max_value);
    }
    under_smallest = (low < smallest_nonzero);
    if (under_smallest) {
        low = smallest_nonzero;
    }
    tiniest = @bitCast(@"u1");
    under_tiniest = (low < tiniest);
    if (under_tiniest) {
        low = tiniest;
    }
    return low;
}

pub fn float_side_high(min_value: f64, max_value: f64, negative: bool) f64 {
    var high: f64 = undefined;
    var largest: f64 = undefined;
    var over_largest: bool = undefined;
    high = max_value;
    if (negative) {
        high = f64_neg(min_value);
    }
    largest = f64_max();
    over_largest = (high > largest);
    if (over_largest) {
        high = largest;
    }
    return high;
}

pub fn float_magnitude_sample(category: u64, low: f64, high: f64, coins: u64, first: u64, second: u64) ?f64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u5": u64 = undefined;
    var @"u6": u64 = undefined;
    var @"u7": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u14": u64 = undefined;
    var @"u16": u64 = undefined;
    var @"u52": u64 = undefined;
    var mantissa_mask: u64 = undefined;
    var none: ?f64 = undefined;
    var band_low: f64 = undefined;
    var band_high: f64 = undefined;
    var banded: bool = undefined;
    var near_zero: bool = undefined;
    var bits_low: u64 = undefined;
    var bits_high: u64 = undefined;
    var subnormal: bool = undefined;
    var near_max_for_add: bool = undefined;
    var near_max_for_mul: bool = undefined;
    var near_sqrt_min_positive: bool = undefined;
    var whole_side: bool = undefined;
    var from_: f64 = undefined;
    var band_above: bool = undefined;
    var to: f64 = undefined;
    var band_below: bool = undefined;
    var empty: bool = undefined;
    var magnitude: f64 = undefined;
    var found: ?f64 = undefined;
    var low_bits: u64 = undefined;
    var high_bits: u64 = undefined;
    var near_one: bool = undefined;
    var one_bits: u64 = undefined;
    var mantissa_bits: u64 = undefined;
    var closeness: u64 = undefined;
    var span_shift: u64 = undefined;
    var span: u64 = undefined;
    var above_from: u64 = undefined;
    var low_over_one: bool = undefined;
    var above_end: u64 = undefined;
    var above_to: u64 = undefined;
    var high_under_above: bool = undefined;
    var double_span: u64 = undefined;
    var below_reach: u64 = undefined;
    var below_from: u64 = undefined;
    var low_over_below: bool = undefined;
    var below_to: u64 = undefined;
    var high_under_below: bool = undefined;
    var above_open: bool = undefined;
    var below_open: bool = undefined;
    var below_first: bool = undefined;
    var take_below: bool = undefined;
    var above_first: bool = undefined;
    var prefer_above: bool = undefined;
    var above_only: bool = undefined;
    var bits: u64 = undefined;
    var value: f64 = undefined;
    var integer: bool = undefined;
    var one: f64 = undefined;
    var limit_bits: u64 = undefined;
    var limit: f64 = undefined;
    var under_one: bool = undefined;
    var over_limit: bool = undefined;
    var from_integer: u64 = undefined;
    var to_integer: u64 = undefined;
    var picked: u64 = undefined;
    var half_integer: bool = undefined;
    var zero: f64 = undefined;
    var half: f64 = undefined;
    var low_less_half: f64 = undefined;
    var under_zero: bool = undefined;
    var high_less_half: f64 = undefined;
    var whole: f64 = undefined;
    var binade_edge: bool = undefined;
    var low_exponent: u64 = undefined;
    var low_mantissa: u64 = undefined;
    var from_exponent: u64 = undefined;
    var subnormal_low: bool = undefined;
    var inside_binade: bool = undefined;
    var past_power: bool = undefined;
    var to_exponent: u64 = undefined;
    var exponent: u64 = undefined;
    var power: u64 = undefined;
    var predecessor: u64 = undefined;
    var want_predecessor: bool = undefined;
    var predecessor_in_range: bool = undefined;
    var use_predecessor: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u5" = 5;
    @"u6" = 6;
    @"u7" = 7;
    @"u8" = 8;
    @"u14" = 14;
    @"u16" = 16;
    @"u52" = 52;
    mantissa_mask = 4503599627370495;
    none = null;
    band_low = low;
    band_high = high;
    banded = false;
    near_zero = (category == @"u1");
    if (near_zero) {
        bits_low = 4503599627370496;
        bits_high = 4591870180066957721;
        band_low = @bitCast(bits_low);
        band_high = @bitCast(bits_high);
        banded = true;
    }
    subnormal = (category == @"u2");
    if (subnormal) {
        band_low = @bitCast(@"u1");
        band_high = @bitCast(mantissa_mask);
        banded = true;
    }
    near_max_for_add = (category == @"u6");
    if (near_max_for_add) {
        bits_low = 9214364837600034816;
        band_low = @bitCast(bits_low);
        band_high = f64_max();
        banded = true;
    }
    near_max_for_mul = (category == @"u7");
    if (near_max_for_mul) {
        bits_low = 6908521828386340864;
        bits_high = 6917529027641081855;
        band_low = @bitCast(bits_low);
        band_high = @bitCast(bits_high);
        banded = true;
    }
    near_sqrt_min_positive = (category == @"u8");
    if (near_sqrt_min_positive) {
        bits_low = 2296835809958952960;
        bits_high = 2310346608841064447;
        band_low = @bitCast(bits_low);
        band_high = @bitCast(bits_high);
        banded = true;
    }
    whole_side = (category == @"u16");
    if (whole_side) {
        banded = true;
    }
    if (banded) {
        from_ = low;
        band_above = (band_low > from_);
        if (band_above) {
            from_ = band_low;
        }
        to = high;
        band_below = (band_high < to);
        if (band_below) {
            to = band_high;
        }
        empty = (from_ > to);
        if (empty) {
            return none;
        }
        magnitude = float_log_uniform_magnitude(from_, to, first, second);
        found = magnitude;
        return found;
    }
    low_bits = @bitCast(low);
    high_bits = @bitCast(high);
    near_one = (category == @"u3");
    if (near_one) {
        one_bits = 4607182418800017408;
        mantissa_bits = 52;
        closeness = float_entropy_between(first, @"u1", mantissa_bits);
        span_shift = (mantissa_bits -% closeness);
        span = (@"u1" << @intCast(span_shift));
        above_from = one_bits;
        low_over_one = (low_bits > above_from);
        if (low_over_one) {
            above_from = low_bits;
        }
        above_end = (one_bits +% span);
        above_to = (above_end -% @"u1");
        high_under_above = (high_bits < above_to);
        if (high_under_above) {
            above_to = high_bits;
        }
        double_span = (span +% span);
        below_reach = (double_span -% @"u1");
        below_from = (one_bits -% below_reach);
        low_over_below = (low_bits > below_from);
        if (low_over_below) {
            below_from = low_bits;
        }
        below_to = (one_bits -% @"u1");
        high_under_below = (high_bits < below_to);
        if (high_under_below) {
            below_to = high_bits;
        }
        above_open = (above_from <= above_to);
        below_open = (below_from <= below_to);
        below_first = float_entropy_coin(coins, @"u1");
        take_below = below_open;
        above_first = (!below_first);
        prefer_above = (above_first and above_open);
        if (prefer_above) {
            take_below = false;
        }
        above_only = (!below_open);
        if (above_only) {
            take_below = false;
        }
        if (take_below) {
            bits = float_entropy_between(second, below_from, below_to);
            value = @bitCast(bits);
            found = value;
            return found;
        }
        if (above_open) {
            bits = float_entropy_between(second, above_from, above_to);
            value = @bitCast(bits);
            found = value;
            return found;
        }
        return none;
    }
    integer = (category == @"u4");
    if (integer) {
        one = 1;
        limit_bits = 4845873199050653696;
        limit = @bitCast(limit_bits);
        from_ = @ceil(low);
        under_one = (from_ < one);
        if (under_one) {
            from_ = one;
        }
        to = f64_floor(high);
        over_limit = (to > limit);
        if (over_limit) {
            to = limit;
        }
        empty = (from_ > to);
        if (empty) {
            return none;
        }
        from_integer = floatToU64(from_);
        to_integer = floatToU64(to);
        picked = float_log_uniform_integer(from_integer, to_integer, first, second);
        value = @floatFromInt(picked);
        found = value;
        return found;
    }
    half_integer = (category == @"u5");
    if (half_integer) {
        zero = 0;
        half = 0.5;
        limit_bits = 4841369599423283198;
        limit = @bitCast(limit_bits);
        low_less_half = (low - half);
        from_ = @ceil(low_less_half);
        under_zero = (from_ < zero);
        if (under_zero) {
            from_ = zero;
        }
        high_less_half = (high - half);
        to = f64_floor(high_less_half);
        over_limit = (to > limit);
        if (over_limit) {
            to = limit;
        }
        empty = (from_ > to);
        if (empty) {
            return none;
        }
        from_integer = floatToU64(from_);
        to_integer = floatToU64(to);
        picked = float_log_uniform_integer(from_integer, to_integer, first, second);
        whole = @floatFromInt(picked);
        value = (whole + half);
        found = value;
        return found;
    }
    binade_edge = (category == @"u14");
    if (binade_edge) {
        low_exponent = (low_bits >> @intCast(@"u52"));
        low_mantissa = (low_bits & mantissa_mask);
        from_exponent = low_exponent;
        subnormal_low = (low_exponent == @"u0");
        inside_binade = (low_mantissa != @"u0");
        past_power = (subnormal_low or inside_binade);
        if (past_power) {
            from_exponent = (low_exponent +% @"u1");
        }
        to_exponent = (high_bits >> @intCast(@"u52"));
        empty = (from_exponent > to_exponent);
        if (empty) {
            return none;
        }
        exponent = float_entropy_between(first, from_exponent, to_exponent);
        power = (exponent << @intCast(@"u52"));
        bits = power;
        predecessor = (power -% @"u1");
        want_predecessor = float_entropy_coin(coins, @"u1");
        predecessor_in_range = (predecessor >= low_bits);
        use_predecessor = (want_predecessor and predecessor_in_range);
        if (use_predecessor) {
            bits = predecessor;
        }
        value = @bitCast(bits);
        found = value;
        return found;
    }
    return none;
}

pub fn float_signed_sample(category: u64, min_value: f64, max_value: f64, smallest_nonzero: f64, coins: u64, first: u64, second: u64) ?f64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var negative: bool = undefined;
    var tried: u64 = undefined;
    var done: bool = undefined;
    var low: f64 = undefined;
    var high: f64 = undefined;
    var open: bool = undefined;
    var magnitude: ?f64 = undefined;
    var present: bool = undefined;
    var value: f64 = undefined;
    var found: ?f64 = undefined;
    var none: ?f64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    negative = float_entropy_coin(coins, @"u0");
    tried = @"u0";
    while (true) {
        done = (tried >= @"u2");
        if (done) {
            break;
        }
        low = float_side_low(min_value, max_value, smallest_nonzero, negative);
        high = float_side_high(min_value, max_value, negative);
        open = (low <= high);
        if (open) {
            magnitude = float_magnitude_sample(category, low, high, coins, first, second);
            present = magnitude != null;
            if (present) {
                value = magnitude.?;
                if (negative) {
                    value = f64_neg(value);
                }
                found = value;
                return found;
            }
        }
        negative = (!negative);
        tried = (tried +% @"u1");
    }
    none = null;
    return none;
}

pub fn float_point_option_count(category: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u6": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u13": u64 = undefined;
    var endpoint: bool = undefined;
    var from_infinity: bool = undefined;
    var to_zero: bool = undefined;
    var paired: bool = undefined;
    @"u0" = 0;
    @"u2" = 2;
    @"u6" = 6;
    @"u10" = 10;
    @"u13" = 13;
    endpoint = (category == @"u0");
    if (endpoint) {
        return @"u6";
    }
    from_infinity = (category >= @"u10");
    to_zero = (category <= @"u13");
    paired = (from_infinity and to_zero);
    if (paired) {
        return @"u2";
    }
    return @"u0";
}

pub fn float_point_option(category: u64, min_value: f64, max_value: f64, index: u64) f64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u11": u64 = undefined;
    var @"u12": u64 = undefined;
    var one: f64 = undefined;
    var endpoint: bool = undefined;
    var want_min: bool = undefined;
    var want_max: bool = undefined;
    var want_above_min: bool = undefined;
    var above_min: f64 = undefined;
    var want_min_plus_one: bool = undefined;
    var min_plus_one: f64 = undefined;
    var want_max_less_one: bool = undefined;
    var max_less_one: f64 = undefined;
    var below_max: f64 = undefined;
    var magnitude: f64 = undefined;
    var infinity: bool = undefined;
    var max_magnitude: bool = undefined;
    var max_exact_integer: bool = undefined;
    var limit_bits: u64 = undefined;
    var negative: bool = undefined;
    var negated: f64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u10" = 10;
    @"u11" = 11;
    @"u12" = 12;
    one = 1;
    endpoint = (category == @"u0");
    if (endpoint) {
        want_min = (index == @"u0");
        if (want_min) {
            return min_value;
        }
        want_max = (index == @"u1");
        if (want_max) {
            return max_value;
        }
        want_above_min = (index == @"u2");
        if (want_above_min) {
            above_min = f64_next_up(min_value);
            return above_min;
        }
        want_min_plus_one = (index == @"u3");
        if (want_min_plus_one) {
            min_plus_one = (min_value + one);
            return min_plus_one;
        }
        want_max_less_one = (index == @"u4");
        if (want_max_less_one) {
            max_less_one = (max_value - one);
            return max_less_one;
        }
        below_max = f64_next_down(max_value);
        return below_max;
    }
    magnitude = 0;
    infinity = (category == @"u10");
    if (infinity) {
        magnitude = f64_infinity();
    }
    max_magnitude = (category == @"u11");
    if (max_magnitude) {
        magnitude = f64_max();
    }
    max_exact_integer = (category == @"u12");
    if (max_exact_integer) {
        limit_bits = 4845873199050653696;
        magnitude = @bitCast(limit_bits);
    }
    negative = (index == @"u1");
    if (negative) {
        negated = f64_neg(magnitude);
        return negated;
    }
    return magnitude;
}

pub fn float_point_option_admitted(category: u64, min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, index: u64) bool {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var false_: bool = undefined;
    var option: f64 = undefined;
    var valid: bool = undefined;
    var invalid: bool = undefined;
    var option_bits: u64 = undefined;
    var earlier: u64 = undefined;
    var done: bool = undefined;
    var previous: f64 = undefined;
    var previous_bits: u64 = undefined;
    var repeat: bool = undefined;
    var true_: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    false_ = false;
    option = float_point_option(category, min_value, max_value, index);
    valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, option);
    invalid = (!valid);
    if (invalid) {
        return false_;
    }
    option_bits = @bitCast(option);
    earlier = @"u0";
    while (true) {
        done = (earlier >= index);
        if (done) {
            break;
        }
        previous = float_point_option(category, min_value, max_value, earlier);
        previous_bits = @bitCast(previous);
        repeat = (previous_bits == option_bits);
        if (repeat) {
            return false_;
        }
        earlier = (earlier +% @"u1");
    }
    true_ = true;
    return true_;
}

pub fn float_point_candidate(category: u64, min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, word: u64) ?f64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var count: u64 = undefined;
    var admitted: u64 = undefined;
    var index: u64 = undefined;
    var done: bool = undefined;
    var admit: bool = undefined;
    var none: ?f64 = undefined;
    var nothing: bool = undefined;
    var wanted: u64 = undefined;
    var seen: u64 = undefined;
    var hit: bool = undefined;
    var option: f64 = undefined;
    var found: ?f64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    count = float_point_option_count(category);
    admitted = @"u0";
    index = @"u0";
    while (true) {
        done = (index >= count);
        if (done) {
            break;
        }
        admit = float_point_option_admitted(category, min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, index);
        if (admit) {
            admitted = (admitted +% @"u1");
        }
        index = (index +% @"u1");
    }
    none = null;
    nothing = (admitted == @"u0");
    if (nothing) {
        return none;
    }
    wanted = float_entropy_below(word, admitted);
    seen = @"u0";
    index = @"u0";
    while (true) {
        done = (index >= count);
        if (done) {
            break;
        }
        admit = float_point_option_admitted(category, min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, index);
        if (admit) {
            hit = (seen == wanted);
            if (hit) {
                option = float_point_option(category, min_value, max_value, index);
                found = option;
                return found;
            }
            seen = (seen +% @"u1");
        }
        index = (index +% @"u1");
    }
    return none;
}

pub fn float_nan_candidate(allow_nan: bool, coins: u64, first: u64) ?f64 {
    var @"u1": u64 = undefined;
    var @"u63": u64 = undefined;
    var exponent_field: u64 = undefined;
    var quiet: u64 = undefined;
    var refused: bool = undefined;
    var none: ?f64 = undefined;
    var sign_bit: u64 = undefined;
    var sign: u64 = undefined;
    var payload: u64 = undefined;
    var canonical: bool = undefined;
    var random: bool = undefined;
    var payload_top: u64 = undefined;
    var low_payload: u64 = undefined;
    var bits: u64 = undefined;
    var value: f64 = undefined;
    var found: ?f64 = undefined;
    @"u1" = 1;
    @"u63" = 63;
    exponent_field = 9218868437227405312;
    quiet = 2251799813685248;
    refused = (!allow_nan);
    if (refused) {
        none = null;
        return none;
    }
    sign_bit = (coins & @"u1");
    sign = (sign_bit << @intCast(@"u63"));
    payload = quiet;
    canonical = float_entropy_coin(coins, @"u1");
    random = (!canonical);
    if (random) {
        payload_top = (quiet -% @"u1");
        low_payload = float_entropy_between(first, @"u1", payload_top);
        payload = (quiet | low_payload);
    }
    bits = (sign | exponent_field);
    bits = (bits | payload);
    value = @bitCast(bits);
    found = value;
    return found;
}

pub fn float_odd_denominator(word: u64) u64 {
    var @"u1": u64 = undefined;
    var @"u500": u64 = undefined;
    var half: u64 = undefined;
    var double_: u64 = undefined;
    var odd: u64 = undefined;
    @"u1" = 1;
    @"u500" = 500;
    half = float_entropy_between(word, @"u1", @"u500");
    double_ = (half +% half);
    odd = (double_ +% @"u1");
    return odd;
}

pub fn float_divides(numerator: f64, denominator: f64) bool {
    var quotient: f64 = undefined;
    var ceiling: f64 = undefined;
    var integral: bool = undefined;
    quotient = (numerator / denominator);
    ceiling = @ceil(quotient);
    integral = (ceiling == quotient);
    return integral;
}

pub fn float_non_dyadic_candidate(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, coins: u64, first: u64, second: u64, third: u64, fourth: u64) ?f64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u100": u64 = undefined;
    var @"u300": u64 = undefined;
    var five: f64 = undefined;
    var one: f64 = undefined;
    var magnitude: f64 = undefined;
    var decimal: bool = undefined;
    var digits: u64 = undefined;
    var scale: u64 = undefined;
    var raised: u64 = undefined;
    var done: bool = undefined;
    var numerator_top: u64 = undefined;
    var numerator_integer: u64 = undefined;
    var numerator: f64 = undefined;
    var five_divides: bool = undefined;
    var denominator: f64 = undefined;
    var fraction: bool = undefined;
    var denominator_integer: u64 = undefined;
    var whole: bool = undefined;
    var negated: f64 = undefined;
    var first_value: f64 = undefined;
    var second_value: f64 = undefined;
    var negative_first: bool = undefined;
    var first_valid: bool = undefined;
    var found: ?f64 = undefined;
    var second_valid: bool = undefined;
    var none: ?f64 = undefined;
    var size: f64 = undefined;
    var size_nan: bool = undefined;
    var size_infinite: bool = undefined;
    var ratio: f64 = undefined;
    var offset: f64 = undefined;
    var value: f64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u8" = 8;
    @"u10" = 10;
    @"u100" = 100;
    @"u300" = 300;
    five = 5;
    one = 1;
    magnitude = 0;
    decimal = float_entropy_coin(coins, @"u1");
    if (decimal) {
        digits = float_entropy_between(first, @"u1", @"u8");
        scale = @"u1";
        raised = @"u0";
        while (true) {
            done = (raised >= digits);
            if (done) {
                break;
            }
            scale = (scale *% @"u10");
            raised = (raised +% @"u1");
        }
        numerator_top = (scale *% @"u100");
        numerator_integer = float_entropy_between(second, @"u1", numerator_top);
        numerator = @floatFromInt(numerator_integer);
        five_divides = float_divides(numerator, five);
        if (five_divides) {
            numerator = (numerator + one);
        }
        denominator = @floatFromInt(scale);
        magnitude = (numerator / denominator);
    }
    fraction = (!decimal);
    if (fraction) {
        denominator_integer = float_odd_denominator(first);
        numerator_integer = float_entropy_between(second, @"u1", @"u300");
        numerator = @floatFromInt(numerator_integer);
        denominator = @floatFromInt(denominator_integer);
        whole = float_divides(numerator, denominator);
        if (whole) {
            numerator = (numerator + one);
        }
        magnitude = (numerator / denominator);
    }
    negated = f64_neg(magnitude);
    first_value = magnitude;
    second_value = negated;
    negative_first = float_entropy_coin(coins, @"u0");
    if (negative_first) {
        first_value = negated;
        second_value = magnitude;
    }
    first_valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, first_value);
    if (first_valid) {
        found = first_value;
        return found;
    }
    second_valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, second_value);
    if (second_valid) {
        found = second_value;
        return found;
    }
    none = null;
    size = (max_value - min_value);
    size_nan = std.math.isNan(size);
    if (size_nan) {
        return none;
    }
    size_infinite = std.math.isInf(size);
    if (size_infinite) {
        return none;
    }
    denominator_integer = float_odd_denominator(third);
    numerator_top = (denominator_integer -% @"u1");
    numerator_integer = float_entropy_between(fourth, @"u1", numerator_top);
    numerator = @floatFromInt(numerator_integer);
    denominator = @floatFromInt(denominator_integer);
    ratio = (numerator / denominator);
    offset = (size * ratio);
    value = (min_value + offset);
    found = value;
    return found;
}

pub fn float_category_candidate(category: u64, min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, coins: u64, first: u64, second: u64, third: u64, fourth: u64) ?f64 {
    var @"u0": u64 = undefined;
    var @"u8": u64 = undefined;
    var @"u9": u64 = undefined;
    var @"u14": u64 = undefined;
    var @"u15": u64 = undefined;
    var candidate: ?f64 = undefined;
    var options: u64 = undefined;
    var pointed: bool = undefined;
    var not_endpoint: bool = undefined;
    var through_bands: bool = undefined;
    var band: bool = undefined;
    var binade_edge: bool = undefined;
    var signed_: bool = undefined;
    var nan: bool = undefined;
    var non_dyadic: bool = undefined;
    var present: bool = undefined;
    var value: f64 = undefined;
    var valid: bool = undefined;
    var none: ?f64 = undefined;
    @"u0" = 0;
    @"u8" = 8;
    @"u9" = 9;
    @"u14" = 14;
    @"u15" = 15;
    candidate = null;
    options = float_point_option_count(category);
    pointed = (options > @"u0");
    if (pointed) {
        candidate = float_point_candidate(category, min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, first);
    }
    not_endpoint = (category > @"u0");
    through_bands = (category <= @"u8");
    band = (not_endpoint and through_bands);
    binade_edge = (category == @"u14");
    signed_ = (band or binade_edge);
    if (signed_) {
        candidate = float_signed_sample(category, min_value, max_value, smallest_nonzero, coins, first, second);
    }
    nan = (category == @"u9");
    if (nan) {
        candidate = float_nan_candidate(allow_nan, coins, first);
    }
    non_dyadic = (category == @"u15");
    if (non_dyadic) {
        candidate = float_non_dyadic_candidate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, coins, first, second, third, fourth);
    }
    present = candidate != null;
    if (present) {
        value = candidate.?;
        valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, value);
        if (valid) {
            return candidate;
        }
    }
    none = null;
    return none;
}

pub fn float_default_candidate(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, coins: u64, first: u64, second: u64, third: u64) f64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u16": u64 = undefined;
    var one: f64 = undefined;
    var log_uniform: bool = undefined;
    var sign_coins: u64 = undefined;
    var sampled: ?f64 = undefined;
    var present: bool = undefined;
    var value: f64 = undefined;
    var valid: bool = undefined;
    var largest: f64 = undefined;
    var lowest: f64 = undefined;
    var low: f64 = undefined;
    var under: bool = undefined;
    var high: f64 = undefined;
    var over: bool = undefined;
    var unit: f64 = undefined;
    var rest: f64 = undefined;
    var low_share: f64 = undefined;
    var high_share: f64 = undefined;
    var simplest: ?f64 = undefined;
    var has_simplest: bool = undefined;
    var fallback: f64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u16" = 16;
    one = 1;
    log_uniform = float_entropy_coin(coins, @"u0");
    if (log_uniform) {
        sign_coins = (coins >> @intCast(@"u1"));
        sampled = float_signed_sample(@"u16", min_value, max_value, smallest_nonzero, sign_coins, first, second);
        present = sampled != null;
        if (present) {
            value = sampled.?;
            valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, value);
            if (valid) {
                return value;
            }
        }
    }
    largest = f64_max();
    lowest = f64_neg(largest);
    low = min_value;
    under = (low < lowest);
    if (under) {
        low = lowest;
    }
    high = max_value;
    over = (high > largest);
    if (over) {
        high = largest;
    }
    unit = float_entropy_unit(third);
    rest = (one - unit);
    low_share = (low * rest);
    high_share = (high * unit);
    value = (low_share + high_share);
    valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, value);
    if (valid) {
        return value;
    }
    simplest = float_simplest(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero);
    has_simplest = simplest != null;
    if (has_simplest) {
        fallback = simplest.?;
        return fallback;
    }
    return value;
}

pub fn text_biased_rank_span() u64 {
    var span: u64 = undefined;
    span = 128;
    return span;
}

pub fn text_bias_threshold() u64 {
    var threshold: u64 = undefined;
    threshold = 900;
    return threshold;
}

pub fn text_rank_span(alphabet: []const u8, biased: bool) u64 {
    var size: u64 = undefined;
    var span: u64 = undefined;
    var biased_span: u64 = undefined;
    var narrower: bool = undefined;
    size = alphabet_size(alphabet);
    span = size;
    if (biased) {
        biased_span = text_biased_rank_span();
        narrower = (biased_span < size);
        if (narrower) {
            span = biased_span;
        }
    }
    return span;
}

pub fn generation_request_kind(attempts: u64, pending_mutations: u64, mutation_streak: u64) u64 {
    var @"u0": u64 = undefined;
    var simplest: u64 = undefined;
    var mutation: u64 = undefined;
    var random: u64 = undefined;
    var first: bool = undefined;
    var has_mutation: bool = undefined;
    var brood: u64 = undefined;
    var fresh_due: bool = undefined;
    @"u0" = 0;
    simplest = 1;
    mutation = 2;
    random = 3;
    first = (attempts == @"u0");
    if (first) {
        return simplest;
    }
    has_mutation = (pending_mutations > @"u0");
    if (has_mutation) {
        brood = mutation_attempt_count();
        fresh_due = (mutation_streak >= brood);
        if (fresh_due) {
            return random;
        }
        return mutation;
    }
    return random;
}

pub fn generation_enqueue_mutations(request_kind: u64, valid: u64) bool {
    var random: u64 = undefined;
    var @"u10": u64 = undefined;
    var is_random: bool = undefined;
    var corpus_ready: bool = undefined;
    var enqueue: bool = undefined;
    random = 3;
    @"u10" = 10;
    is_random = (request_kind == random);
    corpus_ready = (valid >= @"u10");
    enqueue = (is_random and corpus_ready);
    return enqueue;
}

pub fn generation_should_continue(valid: u64, examples: u64) bool {
    var continue_: bool = undefined;
    continue_ = (valid < examples);
    return continue_;
}

pub fn generation_novelty_action(request_kind: u64, exact_seen: bool) u64 {
    var skip: u64 = undefined;
    var execute: u64 = undefined;
    var execute_and_record: u64 = undefined;
    var mutation: u64 = undefined;
    var is_mutation: bool = undefined;
    skip = 0;
    execute = 1;
    execute_and_record = 2;
    mutation = 2;
    is_mutation = (request_kind == mutation);
    if (is_mutation) {
        if (exact_seen) {
            return skip;
        }
        return execute_and_record;
    }
    return execute;
}

pub fn generation_rare_label_permille() u64 {
    var permille: u64 = undefined;
    permille = 250;
    return permille;
}

pub fn generation_label_rare(observed: u64, valid: u64, min_permille: u64) bool {
    var true_: bool = undefined;
    var false_: bool = undefined;
    var thousand: u64 = undefined;
    var max_scaled: u64 = undefined;
    var floor: u64 = undefined;
    var threshold: u64 = undefined;
    var below_floor: bool = undefined;
    var over_rate: bool = undefined;
    var short_: bool = undefined;
    var lhs_overflows: bool = undefined;
    var rhs_overflows: bool = undefined;
    var lhs: u64 = undefined;
    var rhs: u64 = undefined;
    var rare: bool = undefined;
    true_ = true;
    false_ = false;
    thousand = 1000;
    max_scaled = 18446744073709551;
    floor = generation_rare_label_permille();
    threshold = min_permille;
    below_floor = (threshold < floor);
    if (below_floor) {
        threshold = floor;
    }
    over_rate = (threshold > thousand);
    if (over_rate) {
        short_ = (observed < valid);
        return short_;
    }
    lhs_overflows = (observed > max_scaled);
    if (lhs_overflows) {
        return false_;
    }
    rhs_overflows = (valid > max_scaled);
    if (rhs_overflows) {
        return true_;
    }
    lhs = (observed *% thousand);
    rhs = (valid *% threshold);
    rare = (lhs < rhs);
    return rare;
}

pub fn generation_mutation_admission(request_kind: u64, valid: u64, pending: u64, held_rare_label: bool) u64 {
    var none: u64 = undefined;
    var back: u64 = undefined;
    var front: u64 = undefined;
    var brood: u64 = undefined;
    var full: bool = undefined;
    var base: bool = undefined;
    none = 0;
    back = 1;
    front = 2;
    brood = mutation_attempt_count();
    full = (pending >= brood);
    if (full) {
        return none;
    }
    base = generation_enqueue_mutations(request_kind, valid);
    if (base) {
        if (held_rare_label) {
            return front;
        }
        return back;
    }
    if (held_rare_label) {
        return front;
    }
    return none;
}

pub fn mutation_index(count: u64, entropy: u64) ?u64 {
    var @"u0": u64 = undefined;
    var @"u32": u64 = undefined;
    var @"u4294967296": u64 = undefined;
    var empty: bool = undefined;
    var too_large: bool = undefined;
    var invalid: bool = undefined;
    var none: ?u64 = undefined;
    var slot: u64 = undefined;
    var scaled: u64 = undefined;
    var index: u64 = undefined;
    var some: ?u64 = undefined;
    @"u0" = 0;
    @"u32" = 32;
    @"u4294967296" = 4294967296;
    empty = (count == @"u0");
    too_large = (count > @"u4294967296");
    invalid = (empty or too_large);
    if (invalid) {
        none = null;
        return none;
    }
    slot = (entropy >> @intCast(@"u32"));
    scaled = (slot *% count);
    index = (scaled >> @intCast(@"u32"));
    some = index;
    return some;
}

pub fn mutation_distinct_index(count: u64, first: u64, entropy: u64) ?u64 {
    var @"u1": u64 = undefined;
    var too_small: bool = undefined;
    var first_invalid: bool = undefined;
    var invalid: bool = undefined;
    var none: ?u64 = undefined;
    var remaining: u64 = undefined;
    var raw_opt: ?u64 = undefined;
    var raw: u64 = undefined;
    var past_hole: bool = undefined;
    var index: u64 = undefined;
    var some: ?u64 = undefined;
    @"u1" = 1;
    too_small = (count <= @"u1");
    first_invalid = (first >= count);
    invalid = (too_small or first_invalid);
    if (invalid) {
        none = null;
        return none;
    }
    remaining = (count -% @"u1");
    raw_opt = mutation_index(remaining, entropy);
    raw = raw_opt.?;
    past_hole = (raw >= first);
    index = raw;
    if (past_hole) {
        index = (raw +% @"u1");
    }
    some = index;
    return some;
}

pub fn mutation_use_first(entropy: u64) bool {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var low: u64 = undefined;
    var first: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    low = (entropy & @"u1");
    first = (low == @"u0");
    return first;
}

pub fn mutation_attempt_count() u64 {
    var @"u6": u64 = undefined;
    @"u6" = 6;
    return @"u6";
}

pub fn mutation_attempt_randomized(attempt: u64) bool {
    var @"u2": u64 = undefined;
    var randomized: bool = undefined;
    @"u2" = 2;
    randomized = (attempt >= @"u2");
    return randomized;
}

pub fn stateful_feature_generation_raw() u64 {
    var @"u0": u64 = undefined;
    @"u0" = 0;
    return @"u0";
}

pub fn stateful_feature_probability(raw: u64) f64 {
    var @"u254": u64 = undefined;
    var f255: f64 = undefined;
    var bounded: u64 = undefined;
    var too_large: bool = undefined;
    var value: f64 = undefined;
    var probability: f64 = undefined;
    @"u254" = 254;
    f255 = 255;
    bounded = raw;
    too_large = (bounded > @"u254");
    if (too_large) {
        bounded = @"u254";
    }
    value = @floatFromInt(bounded);
    probability = (value / f255);
    return probability;
}

pub fn stateful_feature_forced(candidate_count: u64, is_candidate: bool, decided: bool, disabled: bool) ?bool {
    var @"u1": u64 = undefined;
    var false_: bool = undefined;
    var last: bool = undefined;
    var must_enable: bool = undefined;
    var forced: ?bool = undefined;
    var free: ?bool = undefined;
    @"u1" = 1;
    false_ = false;
    last = (candidate_count == @"u1");
    must_enable = (last and is_candidate);
    if (must_enable) {
        forced = false_;
        return forced;
    }
    if (decided) {
        forced = disabled;
        return forced;
    }
    free = null;
    return free;
}

pub fn stateful_rule_probe_count() u64 {
    var @"u3": u64 = undefined;
    @"u3" = 3;
    return @"u3";
}

pub fn stateful_fallback_max_good(rule_count: u64, known_bad_count: u64) u64 {
    var @"u0": u64 = undefined;
    var valid: bool = undefined;
    var remaining: u64 = undefined;
    @"u0" = 0;
    valid = (known_bad_count < rule_count);
    if (valid) {
        remaining = (rule_count -% known_bad_count);
        return remaining;
    }
    return @"u0";
}

pub fn stateful_fallback_accept(allowed_count: u64, speculative: u64) bool {
    var accept: bool = undefined;
    accept = (allowed_count > speculative);
    return accept;
}

pub fn stateful_choice_protocol(data: []const u8, start: i64, remaining: u64) u64 {
    var @"i0": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var first: i64 = undefined;
    var third: i64 = undefined;
    var seen: u64 = undefined;
    var pos: i64 = undefined;
    var left: u64 = undefined;
    var enough: bool = undefined;
    var exhausted: bool = undefined;
    var end_: i64 = undefined;
    var bad_entry: bool = undefined;
    var key: ?u64 = undefined;
    var named: bool = undefined;
    var positional: bool = undefined;
    var is_first: bool = undefined;
    var is_third: bool = undefined;
    var first_choice: ?bool = undefined;
    var first_boolean: bool = undefined;
    var first_value: bool = undefined;
    var tag: u64 = undefined;
    var integer: bool = undefined;
    @"i0" = 0;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    first = @"i0";
    third = @"i0";
    seen = @"u0";
    pos = start;
    left = remaining;
    while (true) {
        enough = (seen >= @"u3");
        if (enough) {
            break;
        }
        exhausted = (left == @"u0");
        if (exhausted) {
            return @"u1";
        }
        end_ = choice_entry_end(data, pos, @"u0");
        bad_entry = (end_ == @"i0");
        if (bad_entry) {
            return @"u1";
        }
        key = keyed_entry_key(data, pos);
        named = key != null;
        positional = (!named);
        if (positional) {
            is_first = (seen == @"u0");
            if (is_first) {
                first = pos;
            }
            is_third = (seen == @"u2");
            if (is_third) {
                third = pos;
            }
            seen = (seen +% @"u1");
        }
        pos = end_;
        left = (left -% @"u1");
    }
    first_choice = deserialize_boolean_choice(data, first);
    first_boolean = first_choice != null;
    if (first_boolean) {
        first_value = first_choice.?;
        if (first_value) {
            return @"u3";
        }
    }
    tag = @intCast(data[@intCast(third)]);
    integer = (tag == @"u0");
    if (integer) {
        return @"u2";
    }
    return @"u1";
}

pub fn stateful_stop_forced(steps_drawn: u64, steps_rejected: u64, step_count: u64) ?bool {
    var @"u0": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u1000": u64 = undefined;
    var u_max: u64 = undefined;
    var mul_ceiling: u64 = undefined;
    var true_: bool = undefined;
    var false_: bool = undefined;
    var successful: u64 = undefined;
    var progressed: bool = undefined;
    var done: bool = undefined;
    var halt: ?bool = undefined;
    var attempts: u64 = undefined;
    var fits: bool = undefined;
    var stalled: bool = undefined;
    var below_floor: bool = undefined;
    var spent: bool = undefined;
    var first: bool = undefined;
    var go_: ?bool = undefined;
    var free: ?bool = undefined;
    @"u0" = 0;
    @"u10" = 10;
    @"u1000" = 1000;
    u_max = 18446744073709551615;
    mul_ceiling = 1844674407370955161;
    true_ = true;
    false_ = false;
    successful = @"u0";
    progressed = (steps_drawn > steps_rejected);
    if (progressed) {
        successful = (steps_drawn -% steps_rejected);
    }
    done = (successful >= step_count);
    if (done) {
        halt = true_;
        return halt;
    }
    attempts = u_max;
    fits = (step_count <= mul_ceiling);
    if (fits) {
        attempts = (step_count *% @"u10");
    }
    stalled = (successful == @"u0");
    if (stalled) {
        below_floor = (attempts < @"u1000");
        if (below_floor) {
            attempts = @"u1000";
        }
    }
    spent = (steps_drawn >= attempts);
    if (spent) {
        halt = true_;
        return halt;
    }
    first = (steps_drawn == @"u0");
    if (first) {
        go_ = false_;
        return go_;
    }
    free = null;
    return free;
}

pub fn stateful_continue_forced(steps_drawn: u64, steps_rejected: u64, step_count: u64) ?bool {
    var stop: ?bool = undefined;
    var decided: bool = undefined;
    var halt: bool = undefined;
    var go_: bool = undefined;
    var forced: ?bool = undefined;
    var free: ?bool = undefined;
    stop = stateful_stop_forced(steps_drawn, steps_rejected, step_count);
    decided = stop != null;
    if (decided) {
        halt = stop.?;
        go_ = (!halt);
        forced = go_;
        return forced;
    }
    free = null;
    return free;
}

pub fn stateful_continue_probability() f64 {
    var f1: f64 = undefined;
    var f2_32: f64 = undefined;
    var stop: f64 = undefined;
    var probability: f64 = undefined;
    f1 = 1;
    f2_32 = 4294967296;
    stop = (f1 / f2_32);
    probability = (f1 - stop);
    return probability;
}

pub fn stateful_pool_position(active_count: u64, newest_offset: u64) ?u64 {
    var @"u1": u64 = undefined;
    var valid: bool = undefined;
    var invalid: bool = undefined;
    var none: ?u64 = undefined;
    var last: u64 = undefined;
    var position: u64 = undefined;
    var some: ?u64 = undefined;
    @"u1" = 1;
    valid = (newest_offset < active_count);
    invalid = (!valid);
    if (invalid) {
        none = null;
        return none;
    }
    last = (active_count -% @"u1");
    position = (last -% newest_offset);
    some = position;
    return some;
}

pub fn stateful_fresh_id_window(max_plus_one: u64) u64 {
    var @"u1": u64 = undefined;
    var window: u64 = undefined;
    @"u1" = 1;
    window = (max_plus_one +% @"u1");
    return window;
}

pub fn stateful_set_choice_window(max_plus_one: u64) u64 {
    var window: u64 = undefined;
    window = max_plus_one;
    return window;
}

pub fn stateful_fresh_id_fallback_step(candidate: u64, used_id: u64) u64 {
    var @"u1": u64 = undefined;
    var next_: u64 = undefined;
    var taken: bool = undefined;
    @"u1" = 1;
    next_ = candidate;
    taken = (used_id == candidate);
    if (taken) {
        next_ = (candidate +% @"u1");
    }
    return next_;
}

pub fn stateful_fresh_id_accepts(value: u64, window_hi: u64, in_use: bool) bool {
    var in_window: bool = undefined;
    var unused: bool = undefined;
    var accepts: bool = undefined;
    in_window = (value <= window_hi);
    unused = (!in_use);
    accepts = (in_window and unused);
    return accepts;
}

pub fn stateful_set_choice_accepts(value: u64, window_hi: u64) bool {
    var accepts: bool = undefined;
    accepts = (value <= window_hi);
    return accepts;
}

pub fn stateful_set_choice_better(candidate: u64, raw: u64, best: u64) bool {
    var at_or_below: bool = undefined;
    var above_best: bool = undefined;
    var better: bool = undefined;
    at_or_below = (candidate <= raw);
    above_best = (candidate > best);
    better = (at_or_below and above_best);
    return better;
}

pub fn outcome_is_failure(outcome: u64) bool {
    var interesting: u64 = undefined;
    var is_failure: bool = undefined;
    interesting = 4;
    is_failure = (outcome == interesting);
    return is_failure;
}

pub fn shrink_accept(outcome: u64, origin_matches: bool) bool {
    var is_failure: bool = undefined;
    var accept: bool = undefined;
    is_failure = outcome_is_failure(outcome);
    accept = (is_failure and origin_matches);
    return accept;
}

pub fn shrink_cost_progress(candidate_cost: u64, current_cost: u64, stream_simpler: bool) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var cheaper: bool = undefined;
    var dearer: bool = undefined;
    false_ = false;
    true_ = true;
    cheaper = (candidate_cost < current_cost);
    if (cheaper) {
        return true_;
    }
    dearer = (candidate_cost > current_cost);
    if (dearer) {
        return false_;
    }
    return stream_simpler;
}

pub fn generation_rejection_limit(base: u64, valid: u64) u64 {
    var @"u100": u64 = undefined;
    var max: u64 = undefined;
    var max_valid: u64 = undefined;
    var scale_overflows: bool = undefined;
    var earned: u64 = undefined;
    var remaining: u64 = undefined;
    var add_overflows: bool = undefined;
    var limit: u64 = undefined;
    @"u100" = 100;
    max = 18446744073709551615;
    max_valid = 184467440737095516;
    scale_overflows = (valid > max_valid);
    if (scale_overflows) {
        return max;
    }
    earned = (valid *% @"u100");
    remaining = (max -% earned);
    add_overflows = (base > remaining);
    if (add_overflows) {
        return max;
    }
    limit = (base +% earned);
    return limit;
}

pub fn health_filter_too_much(rejections: u64, valid: u64, suppressed: bool) bool {
    var @"u10": u64 = undefined;
    var @"u50": u64 = undefined;
    var many_rejections: bool = undefined;
    var few_valid: bool = undefined;
    var active: bool = undefined;
    var unhealthy: bool = undefined;
    var report: bool = undefined;
    @"u10" = 10;
    @"u50" = 50;
    many_rejections = (rejections >= @"u50");
    few_valid = (valid < @"u10");
    active = (!suppressed);
    unhealthy = (many_rejections and few_valid);
    report = (unhealthy and active);
    return report;
}

pub fn choice_budget_exhausted(draw_count: u64) bool {
    var buffer_size: u64 = undefined;
    var exhausted: bool = undefined;
    buffer_size = 8192;
    exhausted = (draw_count >= buffer_size);
    return exhausted;
}

pub fn health_data_too_large(overruns: u64, valid: u64, suppressed: bool) bool {
    var @"u10": u64 = undefined;
    var @"u20": u64 = undefined;
    var many_overruns: bool = undefined;
    var few_valid: bool = undefined;
    var active: bool = undefined;
    var unhealthy: bool = undefined;
    var report: bool = undefined;
    @"u10" = 10;
    @"u20" = 20;
    many_overruns = (overruns >= @"u20");
    few_valid = (valid < @"u10");
    active = (!suppressed);
    unhealthy = (many_overruns and few_valid);
    report = (unhealthy and active);
    return report;
}

pub fn health_large_base_example(overran: bool, outcome: u64, draw_count: u64, suppressed: bool) bool {
    var @"u0": u64 = undefined;
    var half_buffer: u64 = undefined;
    var valid: bool = undefined;
    var large: bool = undefined;
    var large_valid: bool = undefined;
    var unhealthy: bool = undefined;
    var active: bool = undefined;
    var report: bool = undefined;
    @"u0" = 0;
    half_buffer = 4096;
    valid = (outcome == @"u0");
    large = (draw_count > half_buffer);
    large_valid = (valid and large);
    unhealthy = (overran or large_valid);
    active = (!suppressed);
    report = (unhealthy and active);
    return report;
}

pub fn health_too_slow(generation_us: u64, valid: u64, suppressed: bool) bool {
    var @"u10": u64 = undefined;
    var one_second_us: u64 = undefined;
    var slow: bool = undefined;
    var few_valid: bool = undefined;
    var active: bool = undefined;
    var unhealthy: bool = undefined;
    var report: bool = undefined;
    @"u10" = 10;
    one_second_us = 1000000;
    slow = (generation_us > one_second_us);
    few_valid = (valid < @"u10");
    active = (!suppressed);
    unhealthy = (slow and few_valid);
    report = (unhealthy and active);
    return report;
}

pub fn coverage_failed(observed: u64, valid: u64, min_permille: u64) bool {
    var true_: bool = undefined;
    var false_: bool = undefined;
    var zero: u64 = undefined;
    var thousand: u64 = undefined;
    var max_scaled: u64 = undefined;
    var never: bool = undefined;
    var no_rate: bool = undefined;
    var lhs_overflows: bool = undefined;
    var over_rate: bool = undefined;
    var failed_clamped: bool = undefined;
    var rhs_overflows: bool = undefined;
    var lhs: u64 = undefined;
    var rhs: u64 = undefined;
    var failed: bool = undefined;
    true_ = true;
    false_ = false;
    zero = 0;
    thousand = 1000;
    max_scaled = 18446744073709551;
    never = (observed == zero);
    if (never) {
        return true_;
    }
    no_rate = (min_permille == zero);
    if (no_rate) {
        return false_;
    }
    lhs_overflows = (observed > max_scaled);
    if (lhs_overflows) {
        return false_;
    }
    over_rate = (min_permille > thousand);
    if (over_rate) {
        failed_clamped = (observed < valid);
        return failed_clamped;
    }
    rhs_overflows = (valid > max_scaled);
    if (rhs_overflows) {
        return true_;
    }
    lhs = (observed *% thousand);
    rhs = (min_permille *% valid);
    failed = (lhs < rhs);
    return failed;
}

pub fn shrink_candidate_at(current: u64, ordinal: u64) ?u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u5": u64 = undefined;
    var empty: bool = undefined;
    var none_empty: ?u64 = undefined;
    var within_current: bool = undefined;
    var within_prefix: bool = undefined;
    var linear: bool = undefined;
    var some_linear: ?u64 = undefined;
    var prefix_exhausts: bool = undefined;
    var none_prefix: ?u64 = undefined;
    var seen: u64 = undefined;
    var lower: u64 = undefined;
    var gap: u64 = undefined;
    var exhausted: bool = undefined;
    var half: u64 = undefined;
    var probe: u64 = undefined;
    var want_probe: bool = undefined;
    var some_probe: ?u64 = undefined;
    var none: ?u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u4" = 4;
    @"u5" = 5;
    empty = (current == @"u0");
    if (empty) {
        none_empty = null;
        return none_empty;
    }
    within_current = (ordinal < current);
    within_prefix = (ordinal < @"u5");
    linear = (within_current and within_prefix);
    if (linear) {
        some_linear = ordinal;
        return some_linear;
    }
    prefix_exhausts = (current <= @"u5");
    if (prefix_exhausts) {
        none_prefix = null;
        return none_prefix;
    }
    seen = @"u5";
    lower = @"u4";
    while (true) {
        gap = (current -% lower);
        exhausted = (gap <= @"u1");
        if (exhausted) {
            break;
        }
        half = (gap >> @intCast(@"u1"));
        probe = (lower +% half);
        want_probe = (ordinal == seen);
        if (want_probe) {
            some_probe = probe;
            return some_probe;
        }
        seen = (seen +% @"u1");
        lower = probe;
    }
    none = null;
    return none;
}

pub fn shrink_next_shrinks(phase: u64, feedback: u64, shrinks: u64) u64 {
    var @"u1": u64 = undefined;
    var phase_baseline: u64 = undefined;
    var phase_verify: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_baseline: bool = undefined;
    var in_verify: bool = undefined;
    var accepted: bool = undefined;
    var bumped: u64 = undefined;
    @"u1" = 1;
    phase_baseline = 0;
    phase_verify = 3;
    feedback_accepted = 2;
    in_baseline = (phase == phase_baseline);
    if (in_baseline) {
        return shrinks;
    }
    in_verify = (phase == phase_verify);
    if (in_verify) {
        return shrinks;
    }
    accepted = (feedback == feedback_accepted);
    if (accepted) {
        bumped = (shrinks +% @"u1");
        return bumped;
    }
    return shrinks;
}

pub fn shrink_sweep_again(improved: bool, shrinks: u64, max_shrinks: u64) bool {
    var @"u0": u64 = undefined;
    var false_: bool = undefined;
    var true_: bool = undefined;
    var idle: bool = undefined;
    var uncapped: bool = undefined;
    var under: bool = undefined;
    @"u0" = 0;
    false_ = false;
    true_ = true;
    idle = (!improved);
    if (idle) {
        return false_;
    }
    uncapped = (max_shrinks == @"u0");
    if (uncapped) {
        return true_;
    }
    under = (shrinks < max_shrinks);
    return under;
}

pub fn shrink_next_stall(stall: u64, feedback: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var bumped: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    feedback_skip = 0;
    feedback_accepted = 2;
    accepted = (feedback == feedback_accepted);
    if (accepted) {
        return @"u0";
    }
    skipped = (feedback == feedback_skip);
    if (skipped) {
        return stall;
    }
    bumped = (stall +% @"u1");
    return bumped;
}

pub fn shrink_next_span_cursor(phase: u64, feedback: u64, span_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_delete: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_delete: bool = undefined;
    var accepted: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_delete = 1;
    feedback_accepted = 2;
    in_delete = (phase == phase_delete);
    if (in_delete) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        advanced = (span_cursor +% @"u1");
        return advanced;
    }
    return @"u0";
}

pub fn shrink_next_paid_cursor(phase: u64, feedback: u64, paid_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_paid: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_paid: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_paid = 12;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_paid = (phase == phase_paid);
    if (in_paid) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (paid_cursor +% @"u1");
            return advanced;
        }
        return paid_cursor;
    }
    return @"u0";
}

pub fn shrink_delete_paid_variant(ordinal: u64, widened: bool) ?i64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var step: u64 = undefined;
    var plain: bool = undefined;
    var some_plain: ?i64 = undefined;
    var down: bool = undefined;
    var minus_one: i64 = undefined;
    var some_down: ?i64 = undefined;
    var up: bool = undefined;
    var some_up: ?i64 = undefined;
    var none: ?i64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"i0" = 0;
    @"i1" = 1;
    step = ordinal;
    if (widened) {
        plain = (ordinal == @"u0");
        if (plain) {
            some_plain = @"i0";
            return some_plain;
        }
        step = (ordinal -% @"u1");
    }
    down = (step == @"u0");
    if (down) {
        minus_one = (@"i0" - @"i1");
        some_down = minus_one;
        return some_down;
    }
    up = (step == @"u1");
    if (up) {
        some_up = @"i1";
        return some_up;
    }
    none = null;
    return none;
}

pub fn shrink_next_raise_cursor(phase: u64, feedback: u64, raise_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_raise: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_raise: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_raise = 13;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_raise = (phase == phase_raise);
    if (in_raise) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (raise_cursor +% @"u1");
            return advanced;
        }
        return raise_cursor;
    }
    return @"u0";
}

pub fn shrink_raise_candidate(current_index: u64, max_index: u64, ordinal: u64) ?u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var below_max: bool = undefined;
    var at_max: bool = undefined;
    var none_max: ?u64 = undefined;
    var next_: u64 = undefined;
    var first: bool = undefined;
    var some_next: ?u64 = undefined;
    var second: bool = undefined;
    var beyond_next: bool = undefined;
    var jumps: bool = undefined;
    var some_max: ?u64 = undefined;
    var none: ?u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    below_max = (current_index < max_index);
    at_max = (!below_max);
    if (at_max) {
        none_max = null;
        return none_max;
    }
    next_ = (current_index +% @"u1");
    first = (ordinal == @"u0");
    if (first) {
        some_next = next_;
        return some_next;
    }
    second = (ordinal == @"u1");
    beyond_next = (next_ < max_index);
    jumps = (second and beyond_next);
    if (jumps) {
        some_max = max_index;
        return some_max;
    }
    none = null;
    return none;
}

pub fn shrink_next_position(phase: u64, feedback: u64, position: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_lower: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_lower: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_lower = 2;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_lower = (phase == phase_lower);
    if (in_lower) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (position +% @"u1");
            return advanced;
        }
        return position;
    }
    return @"u0";
}

pub fn shrink_next_shorten_cursor(phase: u64, feedback: u64, shorten_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_shorten: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_shorten: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_shorten = 11;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_shorten = (phase == phase_shorten);
    if (in_shorten) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (shorten_cursor +% @"u1");
            return advanced;
        }
        return shorten_cursor;
    }
    return @"u0";
}

pub fn shrink_next_character_cursor(phase: u64, feedback: u64, character_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_character: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_character: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_character = 10;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_character = (phase == phase_character);
    if (in_character) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (character_cursor +% @"u1");
            return advanced;
        }
        return character_cursor;
    }
    return @"u0";
}

pub fn shrink_next_descendant_cursor(phase: u64, feedback: u64, descendant_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_descendant: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_descendant: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_descendant = 9;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_descendant = (phase == phase_descendant);
    if (in_descendant) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (descendant_cursor +% @"u1");
            return advanced;
        }
        return descendant_cursor;
    }
    return @"u0";
}

pub fn shrink_descendant_worthwhile(ancestor_choices: u64, descendant_choices: u64) bool {
    var @"u0": u64 = undefined;
    var nonempty: bool = undefined;
    var shorter: bool = undefined;
    var worthwhile: bool = undefined;
    @"u0" = 0;
    nonempty = (descendant_choices > @"u0");
    shorter = (descendant_choices < ancestor_choices);
    worthwhile = (nonempty and shorter);
    return worthwhile;
}

pub fn shrink_next_trivial_cursor(phase: u64, feedback: u64, trivial_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_trivial: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_trivial: bool = undefined;
    var accepted: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_trivial = 8;
    feedback_accepted = 2;
    in_trivial = (phase == phase_trivial);
    if (in_trivial) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        advanced = (trivial_cursor +% @"u1");
        return advanced;
    }
    return @"u0";
}

pub fn shrink_trivial_worthwhile(rewritable: u64) bool {
    var @"u0": u64 = undefined;
    var worthwhile: bool = undefined;
    @"u0" = 0;
    worthwhile = (rewritable > @"u0");
    return worthwhile;
}

pub fn shrink_next_reorder_cursor(phase: u64, feedback: u64, reorder_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_reorder: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_reorder: bool = undefined;
    var accepted: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_reorder = 7;
    feedback_accepted = 2;
    in_reorder = (phase == phase_reorder);
    if (in_reorder) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        advanced = (reorder_cursor +% @"u1");
        return advanced;
    }
    return @"u0";
}

pub fn shrink_next_pair_cursor(phase: u64, feedback: u64, pair_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_pair: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_pair: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_pair = 6;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_pair = (phase == phase_pair);
    if (in_pair) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (pair_cursor +% @"u1");
            return advanced;
        }
        return pair_cursor;
    }
    return @"u0";
}

pub fn shrink_pair_count(draw_count: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var empty: bool = undefined;
    var pairs: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    empty = (draw_count < @"u1");
    if (empty) {
        return @"u0";
    }
    pairs = (draw_count -% @"u1");
    return pairs;
}

pub fn shrink_next_duplicate_cursor(phase: u64, feedback: u64, duplicate_cursor: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_duplicate: u64 = undefined;
    var feedback_skip: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var in_duplicate: bool = undefined;
    var accepted: bool = undefined;
    var skipped: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_duplicate = 5;
    feedback_skip = 0;
    feedback_accepted = 2;
    in_duplicate = (phase == phase_duplicate);
    if (in_duplicate) {
        accepted = (feedback == feedback_accepted);
        if (accepted) {
            return @"u0";
        }
        skipped = (feedback == feedback_skip);
        if (skipped) {
            advanced = (duplicate_cursor +% @"u1");
            return advanced;
        }
        return duplicate_cursor;
    }
    return @"u0";
}

pub fn shrink_next_ordinal(phase: u64, feedback: u64, ordinal: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var phase_lower: u64 = undefined;
    var phase_duplicate: u64 = undefined;
    var phase_pair: u64 = undefined;
    var phase_descendant: u64 = undefined;
    var phase_character: u64 = undefined;
    var phase_shorten: u64 = undefined;
    var phase_paid: u64 = undefined;
    var phase_raise: u64 = undefined;
    var feedback_rejected: u64 = undefined;
    var is_lower: bool = undefined;
    var is_duplicate: bool = undefined;
    var is_pair: bool = undefined;
    var is_descendant: bool = undefined;
    var is_character: bool = undefined;
    var is_shorten: bool = undefined;
    var is_paid: bool = undefined;
    var is_raise: bool = undefined;
    var walks_schedule: bool = undefined;
    var walks_ordinal: bool = undefined;
    var walks_span: bool = undefined;
    var walks_string: bool = undefined;
    var walks_shorten: bool = undefined;
    var walks_paid: bool = undefined;
    var in_lower: bool = undefined;
    var rejected: bool = undefined;
    var advanced: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    phase_lower = 2;
    phase_duplicate = 5;
    phase_pair = 6;
    phase_descendant = 9;
    phase_character = 10;
    phase_shorten = 11;
    phase_paid = 12;
    phase_raise = 13;
    feedback_rejected = 1;
    is_lower = (phase == phase_lower);
    is_duplicate = (phase == phase_duplicate);
    is_pair = (phase == phase_pair);
    is_descendant = (phase == phase_descendant);
    is_character = (phase == phase_character);
    is_shorten = (phase == phase_shorten);
    is_paid = (phase == phase_paid);
    is_raise = (phase == phase_raise);
    walks_schedule = (is_lower or is_duplicate);
    walks_ordinal = (walks_schedule or is_pair);
    walks_span = (walks_ordinal or is_descendant);
    walks_string = (walks_span or is_character);
    walks_shorten = (walks_string or is_shorten);
    walks_paid = (walks_shorten or is_paid);
    in_lower = (walks_paid or is_raise);
    if (in_lower) {
        rejected = (feedback == feedback_rejected);
        if (rejected) {
            advanced = (ordinal +% @"u1");
            return advanced;
        }
        return @"u0";
    }
    return @"u0";
}

pub fn shrink_next_phase(phase: u64, feedback: u64, span_cursor: u64, duplicate_cursor: u64, position: u64, pair_cursor: u64, reorder_cursor: u64, trivial_cursor: u64, descendant_cursor: u64, character_cursor: u64, shorten_cursor: u64, paid_cursor: u64, raise_cursor: u64, shrinks: u64, stall: u64, max_shrinks: u64, max_stall: u64, draw_count: u64, span_count: u64) u64 {
    var @"u0": u64 = undefined;
    var phase_baseline: u64 = undefined;
    var phase_delete: u64 = undefined;
    var phase_lower: u64 = undefined;
    var phase_verify: u64 = undefined;
    var phase_done: u64 = undefined;
    var phase_duplicate: u64 = undefined;
    var phase_pair: u64 = undefined;
    var phase_reorder: u64 = undefined;
    var phase_trivial: u64 = undefined;
    var phase_descendant: u64 = undefined;
    var phase_character: u64 = undefined;
    var phase_shorten: u64 = undefined;
    var phase_paid: u64 = undefined;
    var phase_raise: u64 = undefined;
    var feedback_accepted: u64 = undefined;
    var accepted: bool = undefined;
    var next_: u64 = undefined;
    var in_baseline: bool = undefined;
    var in_delete: bool = undefined;
    var in_paid: bool = undefined;
    var in_raise: bool = undefined;
    var in_descendant: bool = undefined;
    var in_verify: bool = undefined;
    var settled: bool = undefined;
    var shrinks_next: u64 = undefined;
    var stall_next: u64 = undefined;
    var shrinks_capped: bool = undefined;
    var over_shrinks: bool = undefined;
    var stop_shrinks: bool = undefined;
    var stall_capped: bool = undefined;
    var over_stall: bool = undefined;
    var stop_stall: bool = undefined;
    var lands_delete: bool = undefined;
    var span_next: u64 = undefined;
    var spans_left: bool = undefined;
    var spans_done: bool = undefined;
    var lands_paid: bool = undefined;
    var paid_next: u64 = undefined;
    var paid_left: bool = undefined;
    var paid_done: bool = undefined;
    var lands_trivial: bool = undefined;
    var trivial_next: u64 = undefined;
    var trivial_left: bool = undefined;
    var trivial_done: bool = undefined;
    var lands_descendant: bool = undefined;
    var descendant_next: u64 = undefined;
    var descendants_left: bool = undefined;
    var descendants_done: bool = undefined;
    var lands_reorder: bool = undefined;
    var reorder_next: u64 = undefined;
    var siblings_left: bool = undefined;
    var siblings_done: bool = undefined;
    var lands_duplicate: bool = undefined;
    var duplicate_next: u64 = undefined;
    var duplicate_left: bool = undefined;
    var duplicate_done: bool = undefined;
    var lands_lower: bool = undefined;
    var position_next: u64 = undefined;
    var draws_left: bool = undefined;
    var draws_done: bool = undefined;
    var lands_pair: bool = undefined;
    var pair_next: u64 = undefined;
    var pair_count: u64 = undefined;
    var pairs_left: bool = undefined;
    var pairs_done: bool = undefined;
    var lands_shorten: bool = undefined;
    var shorten_next: u64 = undefined;
    var shorten_left: bool = undefined;
    var shorten_done: bool = undefined;
    var lands_character: bool = undefined;
    var character_next: u64 = undefined;
    var characters_left: bool = undefined;
    var characters_done: bool = undefined;
    var lands_raise: bool = undefined;
    var raise_next: u64 = undefined;
    var raisable: u64 = undefined;
    var raises_left: bool = undefined;
    var raises_done: bool = undefined;
    @"u0" = 0;
    phase_baseline = 0;
    phase_delete = 1;
    phase_lower = 2;
    phase_verify = 3;
    phase_done = 4;
    phase_duplicate = 5;
    phase_pair = 6;
    phase_reorder = 7;
    phase_trivial = 8;
    phase_descendant = 9;
    phase_character = 10;
    phase_shorten = 11;
    phase_paid = 12;
    phase_raise = 13;
    feedback_accepted = 2;
    accepted = (feedback == feedback_accepted);
    next_ = phase;
    in_baseline = (phase == phase_baseline);
    if (in_baseline) {
        next_ = phase_lower;
        if (accepted) {
            next_ = phase_delete;
        }
    }
    in_delete = (phase == phase_delete);
    if (in_delete) {
        if (accepted) {
            next_ = phase_baseline;
        }
    }
    in_paid = (phase == phase_paid);
    if (in_paid) {
        if (accepted) {
            next_ = phase_baseline;
        }
    }
    in_raise = (phase == phase_raise);
    if (in_raise) {
        if (accepted) {
            next_ = phase_baseline;
        }
    }
    in_descendant = (phase == phase_descendant);
    if (in_descendant) {
        if (accepted) {
            next_ = phase_baseline;
        }
    }
    in_verify = (phase == phase_verify);
    if (in_verify) {
        next_ = phase_done;
    }
    settled = (next_ != phase_done);
    if (settled) {
        shrinks_next = shrink_next_shrinks(phase, feedback, shrinks);
        stall_next = shrink_next_stall(stall, feedback);
        shrinks_capped = (max_shrinks != @"u0");
        over_shrinks = (shrinks_next >= max_shrinks);
        stop_shrinks = (shrinks_capped and over_shrinks);
        if (stop_shrinks) {
            next_ = phase_verify;
        }
        stall_capped = (max_stall != @"u0");
        over_stall = (stall_next >= max_stall);
        stop_stall = (stall_capped and over_stall);
        if (stop_stall) {
            next_ = phase_verify;
        }
    }
    lands_delete = (next_ == phase_delete);
    if (lands_delete) {
        span_next = shrink_next_span_cursor(phase, feedback, span_cursor);
        spans_left = (span_next < span_count);
        spans_done = (!spans_left);
        if (spans_done) {
            next_ = phase_paid;
        }
    }
    lands_paid = (next_ == phase_paid);
    if (lands_paid) {
        paid_next = shrink_next_paid_cursor(phase, feedback, paid_cursor);
        paid_left = (paid_next < span_count);
        paid_done = (!paid_left);
        if (paid_done) {
            next_ = phase_trivial;
        }
    }
    lands_trivial = (next_ == phase_trivial);
    if (lands_trivial) {
        trivial_next = shrink_next_trivial_cursor(phase, feedback, trivial_cursor);
        trivial_left = (trivial_next < span_count);
        trivial_done = (!trivial_left);
        if (trivial_done) {
            next_ = phase_descendant;
        }
    }
    lands_descendant = (next_ == phase_descendant);
    if (lands_descendant) {
        descendant_next = shrink_next_descendant_cursor(phase, feedback, descendant_cursor);
        descendants_left = (descendant_next < span_count);
        descendants_done = (!descendants_left);
        if (descendants_done) {
            next_ = phase_reorder;
        }
    }
    lands_reorder = (next_ == phase_reorder);
    if (lands_reorder) {
        reorder_next = shrink_next_reorder_cursor(phase, feedback, reorder_cursor);
        siblings_left = (reorder_next < span_count);
        siblings_done = (!siblings_left);
        if (siblings_done) {
            next_ = phase_duplicate;
        }
    }
    lands_duplicate = (next_ == phase_duplicate);
    if (lands_duplicate) {
        duplicate_next = shrink_next_duplicate_cursor(phase, feedback, duplicate_cursor);
        duplicate_left = (duplicate_next < draw_count);
        duplicate_done = (!duplicate_left);
        if (duplicate_done) {
            next_ = phase_lower;
        }
    }
    lands_lower = (next_ == phase_lower);
    if (lands_lower) {
        position_next = shrink_next_position(phase, feedback, position);
        draws_left = (position_next < draw_count);
        draws_done = (!draws_left);
        if (draws_done) {
            next_ = phase_pair;
        }
    }
    lands_pair = (next_ == phase_pair);
    if (lands_pair) {
        pair_next = shrink_next_pair_cursor(phase, feedback, pair_cursor);
        pair_count = shrink_pair_count(draw_count);
        pairs_left = (pair_next < pair_count);
        pairs_done = (!pairs_left);
        if (pairs_done) {
            next_ = phase_shorten;
        }
    }
    lands_shorten = (next_ == phase_shorten);
    if (lands_shorten) {
        shorten_next = shrink_next_shorten_cursor(phase, feedback, shorten_cursor);
        shorten_left = (shorten_next < draw_count);
        shorten_done = (!shorten_left);
        if (shorten_done) {
            next_ = phase_character;
        }
    }
    lands_character = (next_ == phase_character);
    if (lands_character) {
        character_next = shrink_next_character_cursor(phase, feedback, character_cursor);
        characters_left = (character_next < draw_count);
        characters_done = (!characters_left);
        if (characters_done) {
            next_ = phase_raise;
        }
    }
    lands_raise = (next_ == phase_raise);
    if (lands_raise) {
        raise_next = shrink_next_raise_cursor(phase, feedback, raise_cursor);
        raisable = shrink_pair_count(draw_count);
        raises_left = (raise_next < raisable);
        raises_done = (!raises_left);
        if (raises_done) {
            next_ = phase_verify;
        }
    }
    return next_;
}

pub fn shrink_request_kind(phase: u64, span_cursor: u64, duplicate_cursor: u64, position: u64, pair_cursor: u64, reorder_cursor: u64, trivial_cursor: u64, descendant_cursor: u64, character_cursor: u64, shorten_cursor: u64, paid_cursor: u64, raise_cursor: u64, draw_count: u64, span_count: u64) u64 {
    var phase_baseline: u64 = undefined;
    var phase_delete: u64 = undefined;
    var phase_lower: u64 = undefined;
    var phase_verify: u64 = undefined;
    var phase_duplicate: u64 = undefined;
    var phase_pair: u64 = undefined;
    var phase_reorder: u64 = undefined;
    var phase_trivial: u64 = undefined;
    var phase_descendant: u64 = undefined;
    var phase_character: u64 = undefined;
    var phase_shorten: u64 = undefined;
    var phase_paid: u64 = undefined;
    var phase_raise: u64 = undefined;
    var request_done: u64 = undefined;
    var request_baseline: u64 = undefined;
    var request_delete: u64 = undefined;
    var request_lower: u64 = undefined;
    var request_verify: u64 = undefined;
    var request_duplicates: u64 = undefined;
    var request_pair: u64 = undefined;
    var request_reorder: u64 = undefined;
    var request_trivial: u64 = undefined;
    var request_descendant: u64 = undefined;
    var request_character: u64 = undefined;
    var request_shorten: u64 = undefined;
    var request_paid: u64 = undefined;
    var request_raise: u64 = undefined;
    var is_baseline: bool = undefined;
    var is_delete: bool = undefined;
    var spans_left: bool = undefined;
    var is_paid: bool = undefined;
    var paid_left: bool = undefined;
    var is_trivial: bool = undefined;
    var trivial_left: bool = undefined;
    var is_descendant: bool = undefined;
    var descendants_left: bool = undefined;
    var is_reorder: bool = undefined;
    var siblings_left: bool = undefined;
    var is_duplicate: bool = undefined;
    var groups_left: bool = undefined;
    var is_lower: bool = undefined;
    var draws_left: bool = undefined;
    var is_pair: bool = undefined;
    var pair_count: u64 = undefined;
    var pairs_left: bool = undefined;
    var is_shorten: bool = undefined;
    var shorten_left: bool = undefined;
    var is_character: bool = undefined;
    var characters_left: bool = undefined;
    var is_raise: bool = undefined;
    var raisable: u64 = undefined;
    var raises_left: bool = undefined;
    var is_verify: bool = undefined;
    phase_baseline = 0;
    phase_delete = 1;
    phase_lower = 2;
    phase_verify = 3;
    phase_duplicate = 5;
    phase_pair = 6;
    phase_reorder = 7;
    phase_trivial = 8;
    phase_descendant = 9;
    phase_character = 10;
    phase_shorten = 11;
    phase_paid = 12;
    phase_raise = 13;
    request_done = 0;
    request_baseline = 1;
    request_delete = 2;
    request_lower = 3;
    request_verify = 4;
    request_duplicates = 5;
    request_pair = 6;
    request_reorder = 7;
    request_trivial = 8;
    request_descendant = 9;
    request_character = 10;
    request_shorten = 11;
    request_paid = 12;
    request_raise = 13;
    is_baseline = (phase == phase_baseline);
    if (is_baseline) {
        return request_baseline;
    }
    is_delete = (phase == phase_delete);
    if (is_delete) {
        spans_left = (span_cursor < span_count);
        if (spans_left) {
            return request_delete;
        }
        return request_done;
    }
    is_paid = (phase == phase_paid);
    if (is_paid) {
        paid_left = (paid_cursor < span_count);
        if (paid_left) {
            return request_paid;
        }
        return request_done;
    }
    is_trivial = (phase == phase_trivial);
    if (is_trivial) {
        trivial_left = (trivial_cursor < span_count);
        if (trivial_left) {
            return request_trivial;
        }
        return request_done;
    }
    is_descendant = (phase == phase_descendant);
    if (is_descendant) {
        descendants_left = (descendant_cursor < span_count);
        if (descendants_left) {
            return request_descendant;
        }
        return request_done;
    }
    is_reorder = (phase == phase_reorder);
    if (is_reorder) {
        siblings_left = (reorder_cursor < span_count);
        if (siblings_left) {
            return request_reorder;
        }
        return request_done;
    }
    is_duplicate = (phase == phase_duplicate);
    if (is_duplicate) {
        groups_left = (duplicate_cursor < draw_count);
        if (groups_left) {
            return request_duplicates;
        }
        return request_done;
    }
    is_lower = (phase == phase_lower);
    if (is_lower) {
        draws_left = (position < draw_count);
        if (draws_left) {
            return request_lower;
        }
        return request_done;
    }
    is_pair = (phase == phase_pair);
    if (is_pair) {
        pair_count = shrink_pair_count(draw_count);
        pairs_left = (pair_cursor < pair_count);
        if (pairs_left) {
            return request_pair;
        }
        return request_done;
    }
    is_shorten = (phase == phase_shorten);
    if (is_shorten) {
        shorten_left = (shorten_cursor < draw_count);
        if (shorten_left) {
            return request_shorten;
        }
        return request_done;
    }
    is_character = (phase == phase_character);
    if (is_character) {
        characters_left = (character_cursor < draw_count);
        if (characters_left) {
            return request_character;
        }
        return request_done;
    }
    is_raise = (phase == phase_raise);
    if (is_raise) {
        raisable = shrink_pair_count(draw_count);
        raises_left = (raise_cursor < raisable);
        if (raises_left) {
            return request_raise;
        }
        return request_done;
    }
    is_verify = (phase == phase_verify);
    if (is_verify) {
        return request_verify;
    }
    return request_done;
}

pub fn shrink_request_span(span_cursor: u64, span_count: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var spans_left: bool = undefined;
    var exhausted: bool = undefined;
    var last: u64 = undefined;
    var index: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    spans_left = (span_cursor < span_count);
    exhausted = (!spans_left);
    if (exhausted) {
        return @"u0";
    }
    last = (span_count -% @"u1");
    index = (last -% span_cursor);
    return index;
}

pub fn shrink_duplicate_worthwhile(members: u64, current_index: u64) bool {
    var @"u0": u64 = undefined;
    var @"u2": u64 = undefined;
    var shared: bool = undefined;
    var lowerable: bool = undefined;
    var worthwhile: bool = undefined;
    @"u0" = 0;
    @"u2" = 2;
    shared = (members >= @"u2");
    lowerable = (current_index != @"u0");
    worthwhile = (shared and lowerable);
    return worthwhile;
}

pub fn shrink_pair_base(left_index: u64, right_index: u64) u64 {
    var right_smaller: bool = undefined;
    right_smaller = (right_index < left_index);
    if (right_smaller) {
        return right_index;
    }
    return left_index;
}

pub fn shrink_pair_worthwhile(left_index: u64, right_index: u64) bool {
    var @"u0": u64 = undefined;
    var base: u64 = undefined;
    var worthwhile: bool = undefined;
    @"u0" = 0;
    base = shrink_pair_base(left_index, right_index);
    worthwhile = (base != @"u0");
    return worthwhile;
}

pub fn shrink_pair_candidate(index: u64, base: u64, candidate: u64) ?u64 {
    var rising: bool = undefined;
    var none_rising: ?u64 = undefined;
    var shift: u64 = undefined;
    var too_small: bool = undefined;
    var none_small: ?u64 = undefined;
    var shifted: u64 = undefined;
    var some_shifted: ?u64 = undefined;
    rising = (candidate > base);
    if (rising) {
        none_rising = null;
        return none_rising;
    }
    shift = (base -% candidate);
    too_small = (index < shift);
    if (too_small) {
        none_small = null;
        return none_small;
    }
    shifted = (index -% shift);
    some_shifted = shifted;
    return some_shifted;
}

pub fn shrink_candidate_count(current: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var ordinal: u64 = undefined;
    var candidate: ?u64 = undefined;
    var present: bool = undefined;
    var done: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    ordinal = @"u0";
    while (true) {
        candidate = shrink_candidate_at(current, ordinal);
        present = candidate != null;
        done = (!present);
        if (done) {
            break;
        }
        ordinal = (ordinal +% @"u1");
    }
    return ordinal;
}

pub fn length_p_continue(min_size: i64, max_size: i64, has_max: bool) f64 {
    var f0_5: f64 = undefined;
    var f1: f64 = undefined;
    var f2: f64 = undefined;
    var f5: f64 = undefined;
    var f0_99: f64 = undefined;
    var minimum: u64 = undefined;
    var min_f: f64 = undefined;
    var infinity: f64 = undefined;
    var max_f: f64 = undefined;
    var bounded: u64 = undefined;
    var doubled: f64 = undefined;
    var plus_five: f64 = undefined;
    var floor: f64 = undefined;
    var five_larger: bool = undefined;
    var span: f64 = undefined;
    var midpoint: f64 = undefined;
    var average: f64 = undefined;
    var midpoint_smaller: bool = undefined;
    var desired_extra: f64 = undefined;
    var max_extra: f64 = undefined;
    var saturated: bool = undefined;
    var unbounded: bool = undefined;
    var denominator: f64 = undefined;
    var ratio: f64 = undefined;
    var p: f64 = undefined;
    f0_5 = 0.5;
    f1 = 1;
    f2 = 2;
    f5 = 5;
    f0_99 = 0.99;
    minimum = @bitCast(min_size);
    min_f = @floatFromInt(minimum);
    infinity = f64_infinity();
    max_f = infinity;
    if (has_max) {
        bounded = @bitCast(max_size);
        max_f = @floatFromInt(bounded);
    }
    doubled = (min_f * f2);
    plus_five = (min_f + f5);
    floor = doubled;
    five_larger = (plus_five > doubled);
    if (five_larger) {
        floor = plus_five;
    }
    span = (min_f + max_f);
    midpoint = (span * f0_5);
    average = floor;
    midpoint_smaller = (midpoint < floor);
    if (midpoint_smaller) {
        average = midpoint;
    }
    desired_extra = (average - min_f);
    max_extra = (max_f - min_f);
    saturated = (desired_extra >= max_extra);
    if (saturated) {
        return f0_99;
    }
    unbounded = std.math.isInf(max_f);
    if (unbounded) {
        denominator = (f1 + desired_extra);
        ratio = (f1 / denominator);
        p = (f1 - ratio);
        return p;
    }
    denominator = (f2 + desired_extra);
    ratio = (f1 / denominator);
    p = (f1 - ratio);
    return p;
}

pub fn many_draws_choice(min_size: i64, max_size: i64, has_max: bool) bool {
    var fixed: bool = undefined;
    var bounded_and_fixed: bool = undefined;
    var varies: bool = undefined;
    fixed = (min_size == max_size);
    bounded_and_fixed = (has_max and fixed);
    varies = (!bounded_and_fixed);
    return varies;
}

pub fn many_forced_value(force_stop: bool, count: i64, min_size: i64, max_size: i64, has_max: bool, p_continue: f64) ?bool {
    var true_: bool = undefined;
    var false_: bool = undefined;
    var stop: ?bool = undefined;
    var below_minimum: bool = undefined;
    var go_: ?bool = undefined;
    var at_maximum: bool = undefined;
    var f0: f64 = undefined;
    var f1: f64 = undefined;
    var never: bool = undefined;
    var always: bool = undefined;
    var free: ?bool = undefined;
    true_ = true;
    false_ = false;
    if (force_stop) {
        stop = false_;
        return stop;
    }
    below_minimum = (count < min_size);
    if (below_minimum) {
        go_ = true_;
        return go_;
    }
    if (has_max) {
        at_maximum = (count >= max_size);
        if (at_maximum) {
            stop = false_;
            return stop;
        }
    }
    f0 = 0;
    f1 = 1;
    never = (p_continue <= f0);
    if (never) {
        stop = false_;
        return stop;
    }
    always = (p_continue >= f1);
    if (always) {
        go_ = true_;
        return go_;
    }
    free = null;
    return free;
}

pub fn filter_retry_allowed(attempts: u64) bool {
    var @"u3": u64 = undefined;
    var allowed: bool = undefined;
    @"u3" = 3;
    allowed = (attempts < @"u3");
    return allowed;
}

pub fn many_rejection_budget(count: i64) u64 {
    var @"i0": i64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var u_max: u64 = undefined;
    var half_max: u64 = undefined;
    var zero: i64 = undefined;
    var accepted: i64 = undefined;
    var positive: bool = undefined;
    var magnitude: u64 = undefined;
    var ceiling: u64 = undefined;
    var doubled: u64 = undefined;
    var fits: bool = undefined;
    var budget: u64 = undefined;
    var below_floor: bool = undefined;
    @"i0" = 0;
    @"u2" = 2;
    @"u3" = 3;
    u_max = 18446744073709551615;
    half_max = 9223372036854775807;
    zero = @"i0";
    accepted = zero;
    positive = (count > @"i0");
    if (positive) {
        accepted = count;
    }
    magnitude = @bitCast(accepted);
    ceiling = u_max;
    doubled = ceiling;
    fits = (magnitude <= half_max);
    if (fits) {
        doubled = (magnitude *% @"u2");
    }
    budget = doubled;
    below_floor = (doubled < @"u3");
    if (below_floor) {
        budget = @"u3";
    }
    return budget;
}

pub fn many_reject_action(rejections: u64, count: i64, min_size: i64) u64 {
    var retry_: u64 = undefined;
    var stop: u64 = undefined;
    var invalid: u64 = undefined;
    var budget: u64 = undefined;
    var over_budget: bool = undefined;
    var within_budget: bool = undefined;
    var below_minimum: bool = undefined;
    retry_ = 0;
    stop = 1;
    invalid = 2;
    budget = many_rejection_budget(count);
    over_budget = (rejections > budget);
    within_budget = (!over_budget);
    if (within_budget) {
        return retry_;
    }
    below_minimum = (count < min_size);
    if (below_minimum) {
        return invalid;
    }
    return stop;
}

pub fn replay_integer(stream: []const u8, offset: i64, min_value: []const u8, max_value: []const u8, target: []const u8) []u8 {
    var entry: ?[]u8 = undefined;
    var present: bool = undefined;
    var recorded: []u8 = undefined;
    var usable: bool = undefined;
    var punned: []u8 = undefined;
    entry = deserialize_integer_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = integer_validate(min_value, max_value, recorded);
        if (usable) {
            return recorded;
        }
    }
    punned = integer_unit(min_value, max_value, target);
    return punned;
}

pub fn replay_boolean(stream: []const u8, offset: i64) bool {
    var entry: ?bool = undefined;
    var present: bool = undefined;
    var recorded: bool = undefined;
    var punned: bool = undefined;
    entry = deserialize_boolean_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        return recorded;
    }
    punned = true;
    return punned;
}

pub fn replay_float(stream: []const u8, offset: i64, min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64) ?f64 {
    var entry: ?f64 = undefined;
    var present: bool = undefined;
    var recorded: f64 = undefined;
    var usable: bool = undefined;
    var found: ?f64 = undefined;
    var punned: ?f64 = undefined;
    entry = deserialize_float_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, recorded);
        if (usable) {
            found = recorded;
            return found;
        }
    }
    punned = float_unit(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero);
    return punned;
}

pub fn replay_bytes(stream: []const u8, offset: i64, min_size: i64, max_size: i64) []u8 {
    var entry: ?[]u8 = undefined;
    var present: bool = undefined;
    var recorded: []u8 = undefined;
    var usable: bool = undefined;
    var punned: []u8 = undefined;
    entry = deserialize_bytes_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = bytes_validate(min_size, max_size, recorded);
        if (usable) {
            return recorded;
        }
    }
    punned = bytes_unit(min_size, max_size);
    return punned;
}

pub fn replay_string(stream: []const u8, offset: i64, alphabet: []const u8, min_size: i64, max_size: i64) []u8 {
    var entry: ?[]u8 = undefined;
    var present: bool = undefined;
    var recorded: []u8 = undefined;
    var usable: bool = undefined;
    var punned: []u8 = undefined;
    entry = deserialize_string_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = string_validate(alphabet, min_size, max_size, recorded);
        if (usable) {
            return recorded;
        }
    }
    punned = string_unit(alphabet, min_size, max_size);
    return punned;
}

pub fn replay_integer_puns(stream: []const u8, offset: i64, min_value: []const u8, max_value: []const u8) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var entry: ?[]u8 = undefined;
    var present: bool = undefined;
    var recorded: []u8 = undefined;
    var usable: bool = undefined;
    false_ = false;
    true_ = true;
    entry = deserialize_integer_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = integer_validate(min_value, max_value, recorded);
        if (usable) {
            return false_;
        }
    }
    return true_;
}

pub fn replay_boolean_puns(stream: []const u8, offset: i64) bool {
    var entry: ?bool = undefined;
    var present: bool = undefined;
    var punned: bool = undefined;
    entry = deserialize_boolean_choice(stream, offset);
    present = entry != null;
    punned = (!present);
    return punned;
}

pub fn replay_float_puns(stream: []const u8, offset: i64, min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var entry: ?f64 = undefined;
    var present: bool = undefined;
    var recorded: f64 = undefined;
    var usable: bool = undefined;
    false_ = false;
    true_ = true;
    entry = deserialize_float_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, recorded);
        if (usable) {
            return false_;
        }
    }
    return true_;
}

pub fn replay_bytes_puns(stream: []const u8, offset: i64, min_size: i64, max_size: i64) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var entry: ?[]u8 = undefined;
    var present: bool = undefined;
    var recorded: []u8 = undefined;
    var usable: bool = undefined;
    false_ = false;
    true_ = true;
    entry = deserialize_bytes_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = bytes_validate(min_size, max_size, recorded);
        if (usable) {
            return false_;
        }
    }
    return true_;
}

pub fn replay_string_puns(stream: []const u8, offset: i64, alphabet: []const u8, min_size: i64, max_size: i64) bool {
    var false_: bool = undefined;
    var true_: bool = undefined;
    var entry: ?[]u8 = undefined;
    var present: bool = undefined;
    var recorded: []u8 = undefined;
    var usable: bool = undefined;
    false_ = false;
    true_ = true;
    entry = deserialize_string_choice(stream, offset);
    present = entry != null;
    if (present) {
        recorded = entry.?;
        usable = string_validate(alphabet, min_size, max_size, recorded);
        if (usable) {
            return false_;
        }
    }
    return true_;
}

pub fn key_append_int(encoded: []const u8, value_raw: []const u8) []u8 {
    var tag: u64 = undefined;
    var out: []u8 = undefined;
    var value: []u8 = undefined;
    var length_i64: i64 = undefined;
    var length: u64 = undefined;
    var length_bytes: []u8 = undefined;
    var with_length: []u8 = undefined;
    var component: []u8 = undefined;
    var result: []u8 = undefined;
    tag = 0;
    out = allocator.alloc(u8, 0) catch unreachable;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    value = canonicalize_signed_le(value_raw);
    length_i64 = @intCast(value.len);
    length = @bitCast(length_i64);
    length_bytes = u32_to_le(length);
    with_length = append_bytes(out, length_bytes);
    component = append_bytes(with_length, value);
    result = append_bytes(encoded, component);
    return result;
}

pub fn key_append_text(encoded: []const u8, value: []const u8) []u8 {
    var tag: u64 = undefined;
    var out: []u8 = undefined;
    var length_i64: i64 = undefined;
    var length: u64 = undefined;
    var length_bytes: []u8 = undefined;
    var with_length: []u8 = undefined;
    var component: []u8 = undefined;
    var result: []u8 = undefined;
    tag = 1;
    out = allocator.alloc(u8, 0) catch unreachable;
    out = allocator.realloc(out, out.len + 1) catch unreachable;
    out[out.len - 1] = @truncate(tag);
    length_i64 = @intCast(value.len);
    length = @bitCast(length_i64);
    length_bytes = u32_to_le(length);
    with_length = append_bytes(out, length_bytes);
    component = append_bytes(with_length, value);
    result = append_bytes(encoded, component);
    return result;
}

pub fn key_hash(encoded: []const u8) u64 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var offset_basis: u64 = undefined;
    var prime: u64 = undefined;
    var length: i64 = undefined;
    var hash: u64 = undefined;
    var pos: i64 = undefined;
    var done: bool = undefined;
    var byte_: u64 = undefined;
    var reserved: bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    @"u1" = 1;
    offset_basis = 14695981039346656037;
    prime = 1099511628211;
    length = @intCast(encoded.len);
    hash = offset_basis;
    pos = @"i0";
    while (true) {
        done = (pos >= length);
        if (done) {
            break;
        }
        byte_ = @intCast(encoded[@intCast(pos)]);
        hash = (hash ^ byte_);
        hash = (hash *% prime);
        pos = (pos + @"i1");
    }
    reserved = (hash == @"u0");
    if (reserved) {
        return @"u1";
    }
    return hash;
}

pub fn targeting_schedule_step(max_test_cases: u64) u64 {
    var @"u1": u64 = undefined;
    var @"u10": u64 = undefined;
    var @"u50": u64 = undefined;
    var ten: []u8 = undefined;
    var max_big: []u8 = undefined;
    var tenth_big: []u8 = undefined;
    var tenth_opt: ?u64 = undefined;
    var tenth: u64 = undefined;
    var cap_: u64 = undefined;
    var over_fifty: bool = undefined;
    var half: u64 = undefined;
    var step: u64 = undefined;
    var half_wins: bool = undefined;
    var below_floor: bool = undefined;
    @"u1" = 1;
    @"u10" = 10;
    @"u50" = 50;
    ten = u64_to_bigint_le(@"u10");
    max_big = u64_to_bigint_le(max_test_cases);
    tenth_big = positive_div_le_nonzero(max_big, ten);
    tenth_opt = bigint_to_u64_le(tenth_big);
    tenth = tenth_opt.?;
    cap_ = tenth;
    over_fifty = (cap_ > @"u50");
    if (over_fifty) {
        cap_ = @"u50";
    }
    half = (max_test_cases >> @intCast(@"u1"));
    step = (cap_ +% @"u1");
    half_wins = (half > step);
    if (half_wins) {
        step = half;
    }
    below_floor = (step < @"u10");
    if (below_floor) {
        step = @"u10";
    }
    return step;
}

pub fn targeting_should_fire(valid: u64, next_at: u64) bool {
    var fire: bool = undefined;
    fire = (valid >= next_at);
    return fire;
}

pub fn targeting_next_threshold(next_at: u64, step: u64) u64 {
    var max: u64 = undefined;
    var room: u64 = undefined;
    var overflows: bool = undefined;
    var sum: u64 = undefined;
    max = 18446744073709551615;
    room = (max -% step);
    overflows = (next_at > room);
    if (overflows) {
        return max;
    }
    sum = (next_at +% step);
    return sum;
}

pub fn targeting_trial_budget(max_test_cases: u64) u64 {
    var @"u10": u64 = undefined;
    var max: u64 = undefined;
    var room: u64 = undefined;
    var overflows: bool = undefined;
    var budget: u64 = undefined;
    @"u10" = 10;
    max = 18446744073709551615;
    room = 1844674407370955161;
    overflows = (max_test_cases > room);
    if (overflows) {
        return max;
    }
    budget = (max_test_cases *% @"u10");
    return budget;
}

pub fn targeting_improvement_allowance(round: u64) u64 {
    var @"u10": u64 = undefined;
    var @"u61": u64 = undefined;
    var max: u64 = undefined;
    var too_far: bool = undefined;
    var allowance: u64 = undefined;
    @"u10" = 10;
    @"u61" = 61;
    max = 18446744073709551615;
    too_far = (round >= @"u61");
    if (too_far) {
        return max;
    }
    allowance = (@"u10" << @intCast(round));
    return allowance;
}

pub fn targeting_record(has_best: bool, best_score: f64, score: f64) bool {
    var true_: bool = undefined;
    var none_yet: bool = undefined;
    var improves: bool = undefined;
    true_ = true;
    none_yet = (!has_best);
    if (none_yet) {
        return true_;
    }
    improves = (score > best_score);
    return improves;
}

pub fn targeting_accept(new_score: f64, current_score: f64, new_count: u64, current_count: u64) u64 {
    var reject: u64 = undefined;
    var lateral: u64 = undefined;
    var improvement: u64 = undefined;
    var worse: bool = undefined;
    var strict: bool = undefined;
    var grew: bool = undefined;
    reject = 0;
    lateral = 1;
    improvement = 2;
    worse = (new_score < current_score);
    if (worse) {
        return reject;
    }
    strict = (new_score > current_score);
    if (strict) {
        return improvement;
    }
    grew = (new_count > current_count);
    if (grew) {
        return reject;
    }
    return lateral;
}

pub fn targeting_step_cap() u64 {
    var cap_: u64 = undefined;
    cap_ = 1048576;
    return cap_;
}

pub fn signed_le_from_i64(value: i64) []u8 {
    var @"i0": i64 = undefined;
    var negative: bool = undefined;
    var negated: i64 = undefined;
    var negated_u: u64 = undefined;
    var magnitude: []u8 = undefined;
    var out: []u8 = undefined;
    var value_u: u64 = undefined;
    var out_pos: []u8 = undefined;
    @"i0" = 0;
    negative = (value < @"i0");
    if (negative) {
        negated = (@"i0" - value);
        negated_u = @bitCast(negated);
        magnitude = u64_to_bigint_le(negated_u);
        out = signed_negate_le(magnitude);
        return out;
    }
    value_u = @bitCast(value);
    out_pos = u64_to_bigint_le(value_u);
    return out_pos;
}

pub fn targeting_step_integer(min_value: []const u8, max_value: []const u8, value: []const u8, delta: i64) ?[]u8 {
    var delta_big: []u8 = undefined;
    var stepped: []u8 = undefined;
    var valid: bool = undefined;
    var out: ?[]u8 = undefined;
    var none: ?[]u8 = undefined;
    delta_big = signed_le_from_i64(delta);
    stepped = signed_add_le(value, delta_big);
    valid = integer_validate(min_value, max_value, stepped);
    if (valid) {
        out = stepped;
        return out;
    }
    none = null;
    return none;
}

pub fn targeting_step_boolean(value: bool, delta: i64) ?bool {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var false_: bool = undefined;
    var true_: bool = undefined;
    var is_zero: bool = undefined;
    var same: ?bool = undefined;
    var negative: bool = undefined;
    var magnitude: i64 = undefined;
    var is_down: bool = undefined;
    var down: ?bool = undefined;
    var none_down: ?bool = undefined;
    var is_up: bool = undefined;
    var up: ?bool = undefined;
    var none: ?bool = undefined;
    @"i0" = 0;
    @"i1" = 1;
    false_ = false;
    true_ = true;
    is_zero = (delta == @"i0");
    if (is_zero) {
        same = value;
        return same;
    }
    negative = (delta < @"i0");
    if (negative) {
        magnitude = (@"i0" - delta);
        is_down = (magnitude == @"i1");
        if (is_down) {
            down = false_;
            return down;
        }
        none_down = null;
        return none_down;
    }
    is_up = (delta == @"i1");
    if (is_up) {
        up = true_;
        return up;
    }
    none = null;
    return none;
}

pub fn targeting_step_float(min_value: f64, max_value: f64, allow_nan: bool, allow_infinity: bool, smallest_nonzero: f64, value: f64, delta: i64) ?f64 {
    var @"i0": i64 = undefined;
    var negative: bool = undefined;
    var magnitude_i: i64 = undefined;
    var magnitude_u: u64 = undefined;
    var delta_f: f64 = undefined;
    var stepped: f64 = undefined;
    var valid: bool = undefined;
    var out: ?f64 = undefined;
    var none: ?f64 = undefined;
    @"i0" = 0;
    negative = (delta < @"i0");
    magnitude_i = delta;
    if (negative) {
        magnitude_i = (@"i0" - delta);
    }
    magnitude_u = @bitCast(magnitude_i);
    delta_f = @floatFromInt(magnitude_u);
    if (negative) {
        delta_f = f64_neg(delta_f);
    }
    stepped = (value + delta_f);
    valid = float_validate(min_value, max_value, allow_nan, allow_infinity, smallest_nonzero, stepped);
    if (valid) {
        out = stepped;
        return out;
    }
    none = null;
    return none;
}

pub fn targeting_step_bytes(min_size: i64, max_size: i64, value: []const u8, delta: i64) ?[]u8 {
    var @"i0": i64 = undefined;
    var @"i1": i64 = undefined;
    var @"u0": u64 = undefined;
    var n: i64 = undefined;
    var le: []u8 = undefined;
    var pos: i64 = undefined;
    var at_start: bool = undefined;
    var byte_: u64 = undefined;
    var delta_big: []u8 = undefined;
    var sum: []u8 = undefined;
    var zero: []u8 = undefined;
    var sign: i64 = undefined;
    var negative: bool = undefined;
    var none_negative: ?[]u8 = undefined;
    var sum_len: i64 = undefined;
    var mag_len: i64 = undefined;
    var empty: bool = undefined;
    var last_at: i64 = undefined;
    var last: u64 = undefined;
    var nonzero: bool = undefined;
    var width: i64 = undefined;
    var narrow: bool = undefined;
    var out: []u8 = undefined;
    var at: i64 = undefined;
    var done: bool = undefined;
    var in_magnitude: bool = undefined;
    var digit: u64 = undefined;
    var valid: bool = undefined;
    var some: ?[]u8 = undefined;
    var none: ?[]u8 = undefined;
    @"i0" = 0;
    @"i1" = 1;
    @"u0" = 0;
    n = @intCast(value.len);
    le = allocator.alloc(u8, 0) catch unreachable;
    pos = n;
    while (true) {
        at_start = (pos <= @"i0");
        if (at_start) {
            break;
        }
        pos = (pos - @"i1");
        byte_ = @intCast(value[@intCast(pos)]);
        le = allocator.realloc(le, le.len + 1) catch unreachable;
        le[le.len - 1] = @truncate(byte_);
    }
    le = allocator.realloc(le, le.len + 1) catch unreachable;
    le[le.len - 1] = @truncate(@"u0");
    delta_big = signed_le_from_i64(delta);
    sum = signed_add_le(le, delta_big);
    zero = bigint_zero();
    sign = signed_compare_le(sum, zero);
    negative = (sign < @"i0");
    if (negative) {
        none_negative = null;
        return none_negative;
    }
    sum_len = @intCast(sum.len);
    mag_len = sum_len;
    while (true) {
        empty = (mag_len <= @"i0");
        if (empty) {
            break;
        }
        last_at = (mag_len - @"i1");
        last = @intCast(sum[@intCast(last_at)]);
        nonzero = (last != @"u0");
        if (nonzero) {
            break;
        }
        mag_len = last_at;
    }
    width = mag_len;
    narrow = (width < n);
    if (narrow) {
        width = n;
    }
    out = allocator.alloc(u8, 0) catch unreachable;
    at = width;
    while (true) {
        done = (at <= @"i0");
        if (done) {
            break;
        }
        at = (at - @"i1");
        in_magnitude = (at < mag_len);
        digit = @"u0";
        if (in_magnitude) {
            digit = @intCast(sum[@intCast(at)]);
        }
        out = allocator.realloc(out, out.len + 1) catch unreachable;
        out[out.len - 1] = @truncate(digit);
    }
    valid = bytes_validate(min_size, max_size, out);
    if (valid) {
        some = out;
        return some;
    }
    none = null;
    return none;
}

pub fn find_integer_probe(mode: u64, a: u64, b: u64) ?u64 {
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var done: bool = undefined;
    var none: ?u64 = undefined;
    var linear: bool = undefined;
    var probe_a: ?u64 = undefined;
    var grow: bool = undefined;
    var probe_b: ?u64 = undefined;
    var gap: u64 = undefined;
    var half: u64 = undefined;
    var mid: u64 = undefined;
    var probe_mid: ?u64 = undefined;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    done = (mode >= @"u3");
    if (done) {
        none = null;
        return none;
    }
    linear = (mode < @"u1");
    if (linear) {
        probe_a = a;
        return probe_a;
    }
    grow = (mode < @"u2");
    if (grow) {
        probe_b = b;
        return probe_b;
    }
    gap = (b -% a);
    half = (gap >> @intCast(@"u1"));
    mid = (a +% half);
    probe_mid = mid;
    return probe_mid;
}

pub fn find_integer_result(mode: u64, a: u64, b: u64) ?u64 {
    _ = b;
    var @"u3": u64 = undefined;
    var done: bool = undefined;
    var answer: ?u64 = undefined;
    var none: ?u64 = undefined;
    @"u3" = 3;
    done = (mode >= @"u3");
    if (done) {
        answer = a;
        return answer;
    }
    none = null;
    return none;
}

pub fn find_integer_bracket_mode(lo: u64, hi: u64) u64 {
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var next_: u64 = undefined;
    var open: bool = undefined;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    next_ = (lo +% @"u1");
    open = (next_ < hi);
    if (open) {
        return @"u2";
    }
    return @"u3";
}

pub fn find_integer_next_mode(mode: u64, a: u64, b: u64, ok: bool) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var half_max: u64 = undefined;
    var done: bool = undefined;
    var linear: bool = undefined;
    var failed: bool = undefined;
    var still_small: bool = undefined;
    var grow: bool = undefined;
    var overflows: bool = undefined;
    var bracketed: u64 = undefined;
    var gap: u64 = undefined;
    var half: u64 = undefined;
    var mid: u64 = undefined;
    var above: u64 = undefined;
    var below: u64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    half_max = 9223372036854775807;
    done = (mode >= @"u3");
    if (done) {
        return @"u3";
    }
    linear = (mode < @"u1");
    if (linear) {
        failed = (!ok);
        if (failed) {
            return @"u3";
        }
        still_small = (a < @"u4");
        if (still_small) {
            return @"u0";
        }
        return @"u1";
    }
    grow = (mode < @"u2");
    if (grow) {
        if (ok) {
            overflows = (b > half_max);
            if (overflows) {
                return @"u3";
            }
            return @"u1";
        }
        bracketed = find_integer_bracket_mode(a, b);
        return bracketed;
    }
    gap = (b -% a);
    half = (gap >> @intCast(@"u1"));
    mid = (a +% half);
    if (ok) {
        above = find_integer_bracket_mode(mid, b);
        return above;
    }
    below = find_integer_bracket_mode(a, mid);
    return below;
}

pub fn find_integer_next_a(mode: u64, a: u64, b: u64, ok: bool) u64 {
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var done: bool = undefined;
    var linear: bool = undefined;
    var failed: bool = undefined;
    var previous: u64 = undefined;
    var still_small: bool = undefined;
    var next_: u64 = undefined;
    var grow: bool = undefined;
    var gap: u64 = undefined;
    var half: u64 = undefined;
    var mid: u64 = undefined;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    done = (mode >= @"u3");
    if (done) {
        return a;
    }
    linear = (mode < @"u1");
    if (linear) {
        failed = (!ok);
        if (failed) {
            previous = (a -% @"u1");
            return previous;
        }
        still_small = (a < @"u4");
        if (still_small) {
            next_ = (a +% @"u1");
            return next_;
        }
        return @"u4";
    }
    grow = (mode < @"u2");
    if (grow) {
        if (ok) {
            return b;
        }
        return a;
    }
    if (ok) {
        gap = (b -% a);
        half = (gap >> @intCast(@"u1"));
        mid = (a +% half);
        return mid;
    }
    return a;
}

pub fn find_integer_next_b(mode: u64, a: u64, b: u64, ok: bool) u64 {
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var @"u3": u64 = undefined;
    var @"u4": u64 = undefined;
    var @"u5": u64 = undefined;
    var half_max: u64 = undefined;
    var done: bool = undefined;
    var linear: bool = undefined;
    var failed: bool = undefined;
    var still_small: bool = undefined;
    var grow: bool = undefined;
    var overflows: bool = undefined;
    var doubled: u64 = undefined;
    var gap: u64 = undefined;
    var half: u64 = undefined;
    var mid: u64 = undefined;
    @"u1" = 1;
    @"u2" = 2;
    @"u3" = 3;
    @"u4" = 4;
    @"u5" = 5;
    half_max = 9223372036854775807;
    done = (mode >= @"u3");
    if (done) {
        return b;
    }
    linear = (mode < @"u1");
    if (linear) {
        failed = (!ok);
        if (failed) {
            return b;
        }
        still_small = (a < @"u4");
        if (still_small) {
            return b;
        }
        return @"u5";
    }
    grow = (mode < @"u2");
    if (grow) {
        if (ok) {
            overflows = (b > half_max);
            if (overflows) {
                return b;
            }
            doubled = (b *% @"u2");
            return doubled;
        }
        return b;
    }
    if (ok) {
        return b;
    }
    gap = (b -% a);
    half = (gap >> @intCast(@"u1"));
    mid = (a +% half);
    return mid;
}

pub fn recursive_large_target_probability() f64 {
    var probability: f64 = undefined;
    probability = 0.75;
    return probability;
}

pub fn recursive_target_drawn(max_leaves: u64) bool {
    var @"u2": u64 = undefined;
    var drawn: bool = undefined;
    @"u2" = 2;
    drawn = (max_leaves >= @"u2");
    return drawn;
}

pub fn recursive_retry_allowed(attempt: u64) bool {
    var @"u9": u64 = undefined;
    var allowed: bool = undefined;
    @"u9" = 9;
    allowed = (attempt < @"u9");
    return allowed;
}

pub fn recursive_effective_target(target: u64, attempt: u64) u64 {
    var @"u1": u64 = undefined;
    var shifted: u64 = undefined;
    var below_one: bool = undefined;
    @"u1" = 1;
    shifted = (target >> @intCast(attempt));
    below_one = (shifted < @"u1");
    if (below_one) {
        return @"u1";
    }
    return shifted;
}

pub fn recursive_arity_estimate(closed_children: u64, closed_branches: u64) f64 {
    var prior_children: f64 = undefined;
    var prior_branches: f64 = undefined;
    var children: f64 = undefined;
    var branches: f64 = undefined;
    var numerator: f64 = undefined;
    var denominator: f64 = undefined;
    var estimate: f64 = undefined;
    prior_children = 0.5;
    prior_branches = 0.25;
    children = @floatFromInt(closed_children);
    branches = @floatFromInt(closed_branches);
    numerator = (prior_children + children);
    denominator = (prior_branches + branches);
    estimate = (numerator / denominator);
    return estimate;
}

pub fn recursive_branch_probability(mean_arity: f64, max_leaves: u64) f64 {
    var f1: f64 = undefined;
    var f0_95: f64 = undefined;
    var @"u2": u64 = undefined;
    var @"u4294967296": u64 = undefined;
    var arity: f64 = undefined;
    var arity_too_small: bool = undefined;
    var budget: u64 = undefined;
    var budget_too_small: bool = undefined;
    var budget_too_large: bool = undefined;
    var budget_f: f64 = undefined;
    var numerator: f64 = undefined;
    var scaled_arity: f64 = undefined;
    var denominator: f64 = undefined;
    var probability: f64 = undefined;
    var over_cap: bool = undefined;
    f1 = 1;
    f0_95 = 0.95;
    @"u2" = 2;
    @"u4294967296" = 4294967296;
    arity = mean_arity;
    arity_too_small = (arity < f1);
    if (arity_too_small) {
        arity = f1;
    }
    budget = max_leaves;
    budget_too_small = (budget < @"u2");
    if (budget_too_small) {
        budget = @"u2";
    }
    budget_too_large = (budget > @"u4294967296");
    if (budget_too_large) {
        budget = @"u4294967296";
    }
    budget_f = @floatFromInt(budget);
    numerator = (budget_f - f1);
    scaled_arity = (budget_f * arity);
    denominator = (scaled_arity - f1);
    probability = (numerator / denominator);
    over_cap = (probability > f0_95);
    if (over_cap) {
        return f0_95;
    }
    return probability;
}

pub fn recursive_priced_probability(closed_children: u64, closed_branches: u64, attempt: u64, target: u64) f64 {
    var arity: f64 = undefined;
    var attempt_f: f64 = undefined;
    var priced_arity: f64 = undefined;
    var effective: u64 = undefined;
    var probability: f64 = undefined;
    arity = recursive_arity_estimate(closed_children, closed_branches);
    attempt_f = @floatFromInt(attempt);
    priced_arity = (arity + attempt_f);
    effective = recursive_effective_target(target, attempt);
    probability = recursive_branch_probability(priced_arity, effective);
    return probability;
}

pub fn recursive_profile_boundary(target: f64, arity: f64, tail_probability: f64, max_depth: u64) u64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var @"u4096": u64 = undefined;
    var f1: f64 = undefined;
    var grow: f64 = undefined;
    var horizon: u64 = undefined;
    var too_far: bool = undefined;
    var tail_numerator: f64 = undefined;
    var tail_times_arity: f64 = undefined;
    var tail_denominator: f64 = undefined;
    var lo: f64 = undefined;
    var grow_times_arity: f64 = undefined;
    var grow_stop: f64 = undefined;
    var lift: f64 = undefined;
    var hi: f64 = undefined;
    var boundary: u64 = undefined;
    var reached: bool = undefined;
    var at_horizon: bool = undefined;
    var done: bool = undefined;
    var next_lift: f64 = undefined;
    var next_: f64 = undefined;
    var gain: f64 = undefined;
    var epsilon: f64 = undefined;
    var plateau: bool = undefined;
    var lo_lift: f64 = undefined;
    @"u0" = 0;
    @"u1" = 1;
    @"u4096" = 4096;
    f1 = 1;
    grow = 0.95;
    horizon = max_depth;
    too_far = (horizon > @"u4096");
    if (too_far) {
        horizon = @"u4096";
    }
    tail_numerator = (f1 - tail_probability);
    tail_times_arity = (tail_probability * arity);
    tail_denominator = (f1 - tail_times_arity);
    lo = (tail_numerator / tail_denominator);
    grow_times_arity = (grow * arity);
    grow_stop = (f1 - grow);
    lift = (grow_times_arity * lo);
    hi = (grow_stop + lift);
    boundary = @"u0";
    while (true) {
        reached = (hi >= target);
        at_horizon = (boundary >= horizon);
        done = (reached or at_horizon);
        if (done) {
            break;
        }
        next_lift = (grow_times_arity * hi);
        next_ = (grow_stop + next_lift);
        gain = (next_ - hi);
        epsilon = 0.000000001;
        plateau = (gain < epsilon);
        if (plateau) {
            break;
        }
        lo_lift = (grow_times_arity * lo);
        lo = (grow_stop + lo_lift);
        hi = next_;
        boundary = (boundary +% @"u1");
    }
    return boundary;
}

pub fn recursive_profile_expected(target: f64, arity: f64, tail_probability: f64, max_depth: u64) f64 {
    var @"u0": u64 = undefined;
    var @"u1": u64 = undefined;
    var f1: f64 = undefined;
    var grow: f64 = undefined;
    var zero_depth: bool = undefined;
    var boundary: u64 = undefined;
    var tail_numerator: f64 = undefined;
    var tail_times_arity: f64 = undefined;
    var tail_denominator: f64 = undefined;
    var lo: f64 = undefined;
    var grow_times_arity: f64 = undefined;
    var grow_stop: f64 = undefined;
    var lo_lift: f64 = undefined;
    var hi: f64 = undefined;
    var at: u64 = undefined;
    var done: bool = undefined;
    var next_lo_lift: f64 = undefined;
    var next_hi_lift: f64 = undefined;
    var hi_below: bool = undefined;
    var lo_above: bool = undefined;
    @"u0" = 0;
    @"u1" = 1;
    f1 = 1;
    grow = 0.95;
    zero_depth = (max_depth == @"u0");
    if (zero_depth) {
        return f1;
    }
    boundary = recursive_profile_boundary(target, arity, tail_probability, max_depth);
    tail_numerator = (f1 - tail_probability);
    tail_times_arity = (tail_probability * arity);
    tail_denominator = (f1 - tail_times_arity);
    lo = (tail_numerator / tail_denominator);
    grow_times_arity = (grow * arity);
    grow_stop = (f1 - grow);
    lo_lift = (grow_times_arity * lo);
    hi = (grow_stop + lo_lift);
    at = @"u0";
    while (true) {
        done = (at >= boundary);
        if (done) {
            break;
        }
        next_lo_lift = (grow_times_arity * lo);
        lo = (grow_stop + next_lo_lift);
        next_hi_lift = (grow_times_arity * hi);
        hi = (grow_stop + next_hi_lift);
        at = (at +% @"u1");
    }
    hi_below = (hi <= target);
    if (hi_below) {
        return hi;
    }
    lo_above = (lo >= target);
    if (lo_above) {
        return lo;
    }
    return target;
}

pub fn recursive_decision_probability(max_depth: u64, depth: u64, target: u64, attempt: u64, closed_children: u64, closed_branches: u64) f64 {
    var f0: f64 = undefined;
    var @"u1": u64 = undefined;
    var at_cap: bool = undefined;
    var effective: u64 = undefined;
    var single: bool = undefined;
    var priced: f64 = undefined;
    var arity: f64 = undefined;
    var attempt_f: f64 = undefined;
    var priced_arity: f64 = undefined;
    var @"u2": u64 = undefined;
    var tail: f64 = undefined;
    var target_f: f64 = undefined;
    var boundary: u64 = undefined;
    var before: bool = undefined;
    var grow: f64 = undefined;
    var on_boundary: bool = undefined;
    var f1: f64 = undefined;
    var tail_numerator: f64 = undefined;
    var tail_times_arity: f64 = undefined;
    var tail_denominator: f64 = undefined;
    var lo: f64 = undefined;
    var grow_times_arity: f64 = undefined;
    var grow_stop: f64 = undefined;
    var lo_lift: f64 = undefined;
    var hi: f64 = undefined;
    var at: u64 = undefined;
    var done: bool = undefined;
    var next_lo_lift: f64 = undefined;
    var next_hi_lift: f64 = undefined;
    var hi_below: bool = undefined;
    var lo_above: bool = undefined;
    var gap: f64 = undefined;
    var offset: f64 = undefined;
    var fraction: f64 = undefined;
    var probability_gap: f64 = undefined;
    var scaled: f64 = undefined;
    var interpolated: f64 = undefined;
    f0 = 0;
    @"u1" = 1;
    at_cap = (depth >= max_depth);
    if (at_cap) {
        return f0;
    }
    effective = recursive_effective_target(target, attempt);
    single = (effective == @"u1");
    if (single) {
        priced = recursive_priced_probability(closed_children, closed_branches, attempt, target);
        return priced;
    }
    arity = recursive_arity_estimate(closed_children, closed_branches);
    attempt_f = @floatFromInt(attempt);
    priced_arity = (arity + attempt_f);
    @"u2" = 2;
    tail = recursive_branch_probability(priced_arity, @"u2");
    target_f = @floatFromInt(effective);
    boundary = recursive_profile_boundary(target_f, arity, tail, max_depth);
    before = (depth < boundary);
    if (before) {
        grow = 0.95;
        return grow;
    }
    on_boundary = (depth == boundary);
    if (on_boundary) {
        f1 = 1;
        grow = 0.95;
        tail_numerator = (f1 - tail);
        tail_times_arity = (tail * arity);
        tail_denominator = (f1 - tail_times_arity);
        lo = (tail_numerator / tail_denominator);
        grow_times_arity = (grow * arity);
        grow_stop = (f1 - grow);
        lo_lift = (grow_times_arity * lo);
        hi = (grow_stop + lo_lift);
        at = 0;
        while (true) {
            done = (at >= boundary);
            if (done) {
                break;
            }
            next_lo_lift = (grow_times_arity * lo);
            lo = (grow_stop + next_lo_lift);
            next_hi_lift = (grow_times_arity * hi);
            hi = (grow_stop + next_hi_lift);
            at = (at +% @"u1");
        }
        hi_below = (hi <= target_f);
        if (hi_below) {
            return grow;
        }
        lo_above = (lo >= target_f);
        if (lo_above) {
            return tail;
        }
        gap = (hi - lo);
        offset = (target_f - lo);
        fraction = (offset / gap);
        probability_gap = (grow - tail);
        scaled = (probability_gap * fraction);
        interpolated = (tail + scaled);
        return interpolated;
    }
    return tail;
}

pub fn recursive_finish_mispriced(max_depth: u64, target: u64, attempt: u64, leaves: u64, closed_children: u64, closed_branches: u64, start_probability: f64, reprices: u64) bool {
    var @"u1": u64 = undefined;
    var @"u2": u64 = undefined;
    var maxed: bool = undefined;
    var false_: bool = undefined;
    var effective: u64 = undefined;
    var single: bool = undefined;
    var repriced: f64 = undefined;
    var difference: f64 = undefined;
    var threshold: f64 = undefined;
    var mispriced: bool = undefined;
    var half_floor: u64 = undefined;
    var remainder: u64 = undefined;
    var half_ceil: u64 = undefined;
    var too_small: bool = undefined;
    var arity: f64 = undefined;
    var target_f: f64 = undefined;
    var zero: f64 = undefined;
    var reachable: f64 = undefined;
    var f2: f64 = undefined;
    var twice_reachable: f64 = undefined;
    var reachable_enough: bool = undefined;
    @"u1" = 1;
    @"u2" = 2;
    maxed = (reprices >= @"u2");
    if (maxed) {
        false_ = false;
        return false_;
    }
    effective = recursive_effective_target(target, attempt);
    single = (effective == @"u1");
    if (single) {
        repriced = recursive_priced_probability(closed_children, closed_branches, attempt, target);
        difference = (repriced - start_probability);
        threshold = 0.05;
        mispriced = (difference > threshold);
        return mispriced;
    }
    half_floor = (effective >> @intCast(@"u1"));
    remainder = (effective & @"u1");
    half_ceil = (half_floor +% remainder);
    too_small = (leaves < half_ceil);
    if (too_small) {
        arity = recursive_arity_estimate(closed_children, closed_branches);
        target_f = @floatFromInt(effective);
        zero = 0;
        reachable = recursive_profile_expected(target_f, arity, zero, max_depth);
        f2 = 2;
        twice_reachable = (reachable * f2);
        reachable_enough = (twice_reachable >= target_f);
        return reachable_enough;
    }
    false_ = false;
    return false_;
}
