pub const core = @import("zizek_gen.zig");
pub const generators = @import("generators.zig");
pub const shell = @import("shell.zig");
pub const stateful = @import("stateful.zig");

pub const check = shell.check;
pub const setAllocator = shell.setAllocator;
pub const key = shell.keyFor;
pub const KeyPart = shell.KeyPart;
pub const ChoiceSpan = shell.ChoiceSpan;
pub const Config = shell.Config;
pub const Database = shell.Database;
pub const InMemoryDatabase = shell.InMemoryDatabase;
pub const DirectoryDatabase = shell.DirectoryDatabase;
pub const databaseDigest = shell.databaseDigest;
pub const Coverage = shell.Coverage;
pub const FailedCoverage = shell.FailedCoverage;
pub const Failure = shell.Failure;
pub const Flaky = shell.Flaky;
pub const TestCase = shell.TestCase;
pub const IntegerGenerator = generators.IntegerGenerator;
pub const FloatGenerator = generators.FloatGenerator;
pub const TextGenerator = generators.TextGenerator;
pub const ListGenerator = generators.ListGenerator;
pub const integers = generators.integers;
pub const floats = generators.floats;
pub const text = generators.text;
pub const lists = generators.lists;
pub const sets = generators.sets;
pub const uniqueLists = generators.uniqueLists;
pub const alphabet = shell.alphabet;
pub const alphabetRange = shell.alphabetRange;
pub const unicode = shell.unicode;

test {
    _ = generators;
    _ = shell;
    _ = stateful;
}
