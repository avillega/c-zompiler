const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const stderr_file = std.io.getStdErr().writer();
    var berr = std.io.bufferedWriter(stderr_file);
    const stderr = berr.writer();

    var args_iter = std.process.args();
    _ = args_iter.skip(); // ignore the name of the process.

    const input = args_iter.next();
    if (input == null) {
        _ = try stderr.write("an input file_name is required.\n");
        _ = try stderr.write("Usage: ./c-zompile input_file.\n");
        try berr.flush();
        std.process.exit(2);
    }

    const command = parse_command(&args_iter) catch {
        _ = try stderr.write("Unknown command. List of known commands:\n");
        _ = try stderr.write("    --lex\n");
        _ = try stderr.write("    --parse\n");
        _ = try stderr.write("    --code_gen\n");
        try berr.flush();
        std.process.exit(2);
    };
    _ = command;

    const src_file_name = input.?;
    const stem = std.fs.path.stem(src_file_name);
    const preprocess_file = try std.fmt.allocPrint(arena.allocator(), "{s}.i", .{stem});

    // Calls external preprocessor
    var preprocessorProc = std.process.Child.init(
        &[_][]const u8{
            "arch",
            "-x86_64",
            "gcc",
            "-E",
            "-P",
            src_file_name,
            "-o",
            preprocess_file,
        },
        arena.allocator(),
    );
    _ = try preprocessorProc.spawnAndWait();

    // Compile the preprocessed file to asm
    std.debug.print("Producing assembly file\n", .{});
    const asm_file_name = try std.fmt.allocPrint(arena.allocator(), "{s}.s", .{stem});
    var asm_file = try std.fs.cwd().createFile(asm_file_name, .{});
    asm_file.close();


    // Calls external assembler and linker
    var assemblerProc = std.process.Child.init(
        &[_][]const u8{
            "arch",
            "-x86_64",
            "gcc",
            src_file_name, // TODO: replace with asm_file_name, once we start producing assembly
            "-o",
            stem,
        },
        arena.allocator(),
    );
    _ = try assemblerProc.spawnAndWait();
}

const Command = enum(u8) {
    lex,
    parse,
    code_gen,
    all,
};

const ParseCommandError = error{UnknownCommand};

fn parse_command(arg_iter: *std.process.ArgIterator) ParseCommandError!Command {
    var command: Command = .all;
    while(arg_iter.next()) |arg| {
        if (std.mem.eql(u8, "--lex", arg)) {
            command = .lex;
        } else if (std.mem.eql(u8, "--parse", arg)) {
            command = .parse;
        } else if (std.mem.eql(u8, "--code_gen", arg)) {
            command = .code_gen;
        } else {
            return error.UnknownCommand;
        }
    }
    return command;
}

test {
    const lexer = @import("lexer.zig");
    _ = lexer;

    const parser = @import("parser.zig");
    _ = parser;
}
