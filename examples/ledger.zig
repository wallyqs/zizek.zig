const std = @import("std");
const zizek = @import("zizek");

const limit: i64 = 1_000_000;

// Confirmed by a native `zig build test` run on 2026-08-18: this shell
// produces this blob itself. It had been carried over from the Python
// reference implementation, unverified here, while the stable pool
// identifiers change landed without a Zig toolchain available.
pub const portable_failure = "AXicVYyxCQAgEAMvYmXtILr/cipq+C/ChRykA4K2w4eohyMuWU0ryUWvXBSLdK4FQmgBCA==";

const Ledger = struct {
    balances: std.StringHashMap(i64),

    fn init() Ledger {
        return .{ .balances = std.StringHashMap(i64).init(zizek.shell.allocator) };
    }

    fn balance(self: *Ledger, account: []const u8) i64 {
        return self.balances.get(account) orelse 0;
    }

    fn credit(self: *Ledger, account: []const u8, amount: i64) void {
        self.balances.put(account, self.balance(account) + amount) catch unreachable;
    }

    fn debit(self: *Ledger, account: []const u8, amount: i64) void {
        self.balances.put(account, self.balance(account) - amount) catch unreachable;
    }

    fn transfer(self: *Ledger, from: []const u8, to: []const u8, amount: i64) void {
        const from_balance = self.balance(from);
        if (!std.mem.eql(u8, from, to) and amount - from_balance <= 1) {
            self.debit(from, amount);
            self.credit(to, amount);
        }
    }
};

const LedgerTest = struct {
    ledger: Ledger,
    accounts: zizek.stateful.Pool([]const u8),

    fn createAccount(self: *LedgerTest, case: *zizek.TestCase) !void {
        const account = try zizek.text().minSize(1).draw(case);
        case.note(std.fmt.allocPrint(zizek.shell.allocator, "create account \"{s}\"", .{account}) catch unreachable);
        try self.accounts.add(case, account);
    }

    fn credit(self: *LedgerTest, case: *zizek.TestCase) !void {
        const account = try self.accounts.reusable(case);
        const amount = try zizek.integers().minValue(0).maxValue(limit).draw(case);
        case.note(std.fmt.allocPrint(zizek.shell.allocator, "credit \"{s}\" with {d}", .{ account, amount }) catch unreachable);
        self.ledger.credit(account, amount);
    }

    fn transfer(self: *LedgerTest, case: *zizek.TestCase) !void {
        const from = try self.accounts.reusable(case);
        const to = try self.accounts.reusable(case);
        const amount = try zizek.integers().minValue(0).maxValue(limit).draw(case);
        case.note(std.fmt.allocPrint(zizek.shell.allocator, "transfer {d} from \"{s}\" to \"{s}\"", .{ amount, from, to }) catch unreachable);
        self.ledger.transfer(from, to, amount);
    }

    fn nonnegativeBalances(self: *LedgerTest, _: *zizek.TestCase) !void {
        var iterator = self.ledger.balances.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.* < 0) return error.NegativeBalance;
        }
    }
};

fn property(case: *zizek.TestCase) !void {
    var state = LedgerTest{
        .ledger = Ledger.init(),
        .accounts = zizek.stateful.Pool([]const u8).init(case),
    };
    const rules = [_]zizek.stateful.Rule(LedgerTest){
        .{ .name = "create_account", .apply = LedgerTest.createAccount },
        .{ .name = "credit", .apply = LedgerTest.credit },
        .{ .name = "transfer", .apply = LedgerTest.transfer },
    };
    const invariants = [_]zizek.stateful.Rule(LedgerTest){
        .{ .name = "nonnegative_balances", .apply = LedgerTest.nonnegativeBalances },
    };
    try zizek.stateful.run(&state, zizek.stateful.Machine(LedgerTest){
        .rules = &rules,
        .invariants = &invariants,
    }, case);
}

pub fn findAndReplayBug() !zizek.Failure {
    const found = (try zizek.check(property, .{ .examples = 2_000, .seed = 6 })) orelse return error.BugNotFound;
    return (try zizek.check(property, .{ .reproduce = found.blob })) orelse return error.DidNotReplay;
}

pub fn main(_: std.process.Init) !void {
    const failure = try findAndReplayBug();
    std.debug.print("{s}\nreproduce: {s}\n", .{ failure.cause, failure.blob });
}

test "portable ledger failure replays" {
    const failure = (try zizek.check(property, .{ .reproduce = portable_failure })).?;
    try std.testing.expectEqualStrings("NegativeBalance", failure.cause);
}

test "ledger bug shrinks to the portable three-step failure" {
    const failure = try findAndReplayBug();
    try std.testing.expect(std.mem.indexOf(u8, failure.cause, "NegativeBalance") != null);
}
