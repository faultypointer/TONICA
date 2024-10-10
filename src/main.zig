const std = @import("std");
const BitBoard = @import("board/bitboard.zig").BitBoard;
const KNIGHT_ATTACK = @import("movegen/nonsliderattack.zig").KNIGHT_ATTACK;
const Square = @import("board/types.zig").Square;
const movegen = @import("movegen.zig");
const MovGen = movegen.MovGen;
const mboard = @import("board.zig");
const Board = mboard.Board;
const Move = @import("board/types.zig").Move;
const PieceType = @import("board/types.zig").PieceType;

pub fn main() !void {
    std.debug.print("Qf7#\n", .{});

    var board = Board.init();
    var movgen = MovGen.init();
    // std.debug.print("Starting board\n", .{});
    // printBitboard(board.side_bb[0] | board.side_bb[1]);
    var move = Move.init(@intFromEnum(Square.e2), @intFromEnum(Square.e4), PieceType.Pawn);
    board.makeMove(move);
    // std.debug.print("board after e4\n", .{});
    // printBitboard(board.side_bb[0] | board.side_bb[1]);
    move = Move.init(@intFromEnum(Square.h7), @intFromEnum(Square.h5), PieceType.Pawn);
    board.makeMove(move);
    // std.debug.print("board after h5\n", .{});
    // printBitboard(board.side_bb[0] | board.side_bb[1]);
    std.debug.print("possible attack for white now\n", .{});
    const moves = movgen.generateMoves(board);
    for (0..moves.len) |i| {
        std.debug.print("{b:0>64}\n", .{moves.moves[i].data});
        var temp_board = board;
        temp_board.makeMove(moves.moves[i]);
        // printBitboard(board.side_bb[0] | board.side_bb[1]);
        temp_board.printBoard();
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
