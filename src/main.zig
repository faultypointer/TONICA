const std = @import("std");
const BitBoard = @import("board/bitboard.zig").BitBoard;
const KNIGHT_ATTACK = @import("movegen/nonsliderattack.zig").KNIGHT_ATTACK;
const Square = @import("board/types.zig").Square;

pub fn main() !void {
    std.debug.print("Qf7#\n", .{});

    for (0..64) |i| {
        const sq: Square = @enumFromInt(i);
        std.debug.print("King on {any} attacks: \n", .{sq});
        printBitboard(KNIGHT_ATTACK[i]);
    }
}

pub fn printBitboard(bitboard: u64) void {
    const stdout = std.io.getStdOut().writer();

    // Print the top border
    stdout.print("  +---+---+---+---+---+---+---+---+\n", .{}) catch unreachable;

    // Iterate through ranks (8 to 1)
    var rank: i32 = 8;
    while (rank >= 1) : (rank -= 1) {
        // Print rank number
        stdout.print("{d} ", .{rank}) catch unreachable;

        // Iterate through files (a to h)
        var file: u8 = 0;
        while (file < 8) : (file += 1) {
            const square = @as(u6, @intCast((rank - 1) * 8 + file));
            const piece = if ((bitboard & (@as(u64, 1) << square)) != 0) "X" else " ";
            stdout.print("| {s} ", .{piece}) catch unreachable;
        }

        stdout.print("|\n", .{}) catch unreachable;

        // Print separator between ranks
        stdout.print("  +---+---+---+---+---+---+---+---+\n", .{}) catch unreachable;
    }

    // Print file letters
    stdout.print("    a   b   c   d   e   f   g   h\n", .{}) catch unreachable;
}
