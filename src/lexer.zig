const std = @import("std");

pub const Lexer = struct {
    index: u32,
    src: [:0]const u8,

    const State = enum {
        start,
        identifier,
        number_literal,
    };

    pub fn init(src: [:0]const u8) Lexer {
        return .{ .index = 0, .src = src };
    }

    pub fn next(lexer: *Lexer) Token {
        var state: State = .start;
        var result: Token = .{
            .tag = undefined,
            .start = lexer.index,
            .end = undefined,
        };
        while (true) : (lexer.index += 1) {
            const c = lexer.src[lexer.index];
            switch (state) {
                .start => switch (c) {
                    0 => { // assume that if you see a null it is the end of the src.
                        return .{ .tag = .eof, .start = lexer.index, .end = lexer.index };
                    },
                    ' ', '\n', '\t', '\r' => { // ignore whitespace
                        result.start = lexer.index + 1;
                    },
                    '(' => {
                        result.tag = .l_paren;
                        lexer.index += 1;
                        break;
                    },
                    ')' => {
                        result.tag = .r_paren;
                        lexer.index += 1;
                        break;
                    },
                    '{' => {
                        result.tag = .l_brace;
                        lexer.index += 1;
                        break;
                    },
                    '}' => {
                        result.tag = .r_brace;
                        lexer.index += 1;
                        break;
                    },
                    ';' => {
                        result.tag = .semicolon;
                        lexer.index += 1;
                        break;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .identifier;
                        result.tag = .identifier;
                    },
                    '0'...'9' => {
                        state = .number_literal;
                        result.tag = .number_literal;
                    },
                    else => std.debug.panic("unreachable got unhandled char '{c}'", .{c}),
                },
                .identifier => switch(c) {
                    'a'...'z', 'A'...'Z', '0'...'9', '_' => continue,
                    else => {
                        if(Token.keywords.get(lexer.src[result.start..lexer.index])) |tag| {
                            result.tag = tag;
                        }
                        break;
                    },
                },
                .number_literal => switch(c) {
                    '0'...'9' => continue,
                    else => break,
                },
            }
        }

        result.end = lexer.index;
        return result;
    }
};

const Token = struct {
    tag: Tag,
    start: u32,
    end: u32,

    const Tag = enum {
        l_brace,
        r_brace,
        l_paren,
        r_paren,
        semicolon,
        identifier,
        number_literal,
        keyword_int,
        keyword_return,
        keyword_void,
        invalid,
        eof,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "int", .keyword_int },
        .{ "return", .keyword_return },
        .{ "void", .keyword_void },
    });
};

test "lex single token items" {
    try testLex("{}();", &.{ .l_brace, .r_brace, .l_paren, .r_paren, .semicolon });
}

test "lex keywords" {
    try testLex("int", &.{.keyword_int});
    try testLex("return", &.{.keyword_return});
    try testLex("void", &.{.keyword_void});
}

test "lex arbitrary identifier" {
    try testLex("main", &.{.identifier});
    try testLex("hello", &.{.identifier});
    try testLex("world01", &.{.identifier});
    try testLex("a", &.{.identifier});
    try testLex("c", &.{.identifier});
}

test "lex number literals" {
    try testLex("1", &.{.number_literal});
    try testLex("2", &.{.number_literal});
    try testLex("12", &.{.number_literal});
    try testLex("125", &.{.number_literal});
    try testLex("99999", &.{.number_literal});
}

test "ignore whitespaces" {
    try testLex("1   35", &.{.number_literal, .number_literal});
    try testLex("     2", &.{.number_literal});
    try testLex("     12", &.{.number_literal});
    try testLex("    125", &.{.number_literal});
    try testLex("     99999", &.{.number_literal});
}

fn testLex(src: [:0]const u8, expected_tags: []const Token.Tag) !void {
    var lexer = Lexer.init(src);
    for (expected_tags) |expected_tag| {
        const token = lexer.next();
        try std.testing.expectEqual(expected_tag, token.tag);
    }

    const last_token = lexer.next();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(src.len, last_token.start);
    try std.testing.expectEqual(src.len, last_token.end);
}
