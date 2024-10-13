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

    const board = Board.readFromFen("rnbqk2r/pppp2pp/5n2/2b1pp2/2B1P3/5Q2/PPPPNPPP/RNB2RK1 b kq - 0 1");
    var movgen = MovGen.init();
    // std.debug.print("Starting board\n", .{});
    // printBitboard(board.side_bb[0] | board.side_bb[1]);
    // var move = Move.init(@intFromEnum(Square.e2), @intFromEnum(Square.e4), PieceType.Pawn);
    // board.makeMove(move);
    // std.debug.print("board after e4\n", .{});
    // printBitboard(board.side_bb[0] | board.side_bb[1]);
    // move = Move.init(@intFromEnum(Square.h7), @intFromEnum(Square.h5), PieceType.Pawn);
    // board.makeMove(move);
    // std.debug.print("board after h5\n", .{});
    // printBitboard(board.side_bb[0] | board.side_bb[1]);
    std.debug.print("possible attack for {any} now\n", .{board.state.turn});
    const moves = movgen.generateMoves(board);
    for (0..moves.len) |i| {
        std.debug.print("==========================================================================\n", .{});
        // std.debug.print("{b:0>64}\n", .{moves.moves[i].data});
        var temp_board = board;
        temp_board.makeMove(moves.moves[i]);
        // printBitboard(board.side_bb[0] | board.side_bb[1]);
        temp_board.printBoard();
        temp_board.state.print();
        _ = std.io.getStdIn().reader().readByte() catch unreachable;
    }
}
