// Generated from conformance/shell/draw_ops.zir by the zizek emitter. Do not edit by hand.

const std = @import("std");

pub fn traceDraw(case: anytype, op: []const u8, buffer: []u8, alphabet_from_hex: anytype, collect_integer: anytype, collect_unique_integer: anytype) ![]const u8 {
    var parts = std.mem.splitScalar(u8, op, ':');
    const head = parts.next() orelse return error.UnknownDrawOp;
    var fields: [4][]const u8 = undefined;
    var fields_len: usize = 0;
    while (parts.next()) |field| {
        if (fields_len == fields.len) return error.InvalidDrawOp;
        fields[fields_len] = field;
        fields_len += 1;
    }
    if (std.mem.eql(u8, head, "i")) {
        const value = try case.integer(try std.fmt.parseInt(i64, fields[0], 10), try std.fmt.parseInt(i64, fields[1], 10), 0);
        return std.fmt.bufPrint(buffer, "i:{d}", .{value});
    }
    if (std.mem.eql(u8, head, "b")) {
        const value = try case.boolean();
        const encoded: u8 = if (value) 1 else 0;
        return std.fmt.bufPrint(buffer, "b:{d}", .{encoded});
    }
    if (std.mem.eql(u8, head, "y")) {
        const value = try case.bytes(try std.fmt.parseInt(usize, fields[0], 10), try std.fmt.parseInt(usize, fields[1], 10));
        var at = (try std.fmt.bufPrint(buffer, "y:", .{})).len;
        for (value) |byte| {
            at += (try std.fmt.bufPrint(buffer[at..], "{x:0>2}", .{byte})).len;
        }
        return buffer[0..at];
    }
    if (std.mem.eql(u8, head, "f")) {
        const value = try case.float(@as(f64, @bitCast(try std.fmt.parseInt(u64, fields[0], 16))), @as(f64, @bitCast(try std.fmt.parseInt(u64, fields[1], 16))), false, false, std.math.floatMin(f64));
        const bits: u64 = @bitCast(value);
        return std.fmt.bufPrint(buffer, "f:{x:0>16}", .{bits});
    }
    if (std.mem.eql(u8, head, "s")) {
        const value = try case.string(try std.fmt.parseInt(usize, fields[0], 10), try std.fmt.parseInt(usize, fields[1], 10), try alphabet_from_hex(fields[2]));
        var at = (try std.fmt.bufPrint(buffer, "s:", .{})).len;
        for (value) |byte| {
            at += (try std.fmt.bufPrint(buffer[at..], "{x:0>2}", .{byte})).len;
        }
        return buffer[0..at];
    }
    if (std.mem.eql(u8, head, "k")) {
        const value = try case.integerKeyed(try std.fmt.parseInt(i64, fields[0], 10), try std.fmt.parseInt(i64, fields[1], 10), 0, try std.fmt.parseInt(u64, fields[2], 16));
        return std.fmt.bufPrint(buffer, "k:{d}", .{value});
    }
    if (std.mem.eql(u8, head, "l")) {
        const value = try collect_integer(case, try std.fmt.parseInt(usize, fields[0], 10), if (std.mem.eql(u8, fields[1], "-")) null else try std.fmt.parseInt(usize, fields[1], 10), try std.fmt.parseInt(i64, fields[2], 10), try std.fmt.parseInt(i64, fields[3], 10));
        var at = (try std.fmt.bufPrint(buffer, "l:", .{})).len;
        for (value, 0..) |item, index| {
            if (index != 0) {
                buffer[at] = ',';
                at += 1;
            }
            at += (try std.fmt.bufPrint(buffer[at..], "{d}", .{item})).len;
        }
        return buffer[0..at];
    }
    if (std.mem.eql(u8, head, "q")) {
        const value = try collect_unique_integer(case, try std.fmt.parseInt(usize, fields[0], 10), if (std.mem.eql(u8, fields[1], "-")) null else try std.fmt.parseInt(usize, fields[1], 10), try std.fmt.parseInt(i64, fields[2], 10), try std.fmt.parseInt(i64, fields[3], 10));
        var at = (try std.fmt.bufPrint(buffer, "q:", .{})).len;
        for (value, 0..) |item, index| {
            if (index != 0) {
                buffer[at] = ',';
                at += 1;
            }
            at += (try std.fmt.bufPrint(buffer[at..], "{d}", .{item})).len;
        }
        return buffer[0..at];
    }
    if (std.mem.eql(u8, head, "c")) {
        const value = try (try case.cloneStream()).integer(try std.fmt.parseInt(i64, fields[0], 10), try std.fmt.parseInt(i64, fields[1], 10), 0);
        return std.fmt.bufPrint(buffer, "c:{d}", .{value});
    }
    return error.UnknownDrawOp;
}
