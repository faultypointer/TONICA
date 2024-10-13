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
const perft = @import("movegen/perft.zig");

pub fn main() !void {
    // std.debug.print("Qf7#\n", .{});
    var board: Board = undefined;
    const movgen = MovGen.init();
    var buffer: [1024]u8 = undefined;
    for (0..buffer.len) |i| {
        buffer[i] = 0;
    }
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    if (args.next()) |fen| {
        board = Board.readFromFen(fen);
    } else {
        return;
    }

    if (args.next()) |depth| {
        _ = try perft.runPerft(&movgen, &board, try std.fmt.parseInt(usize, depth, 10));
    }
    // std.debug.print("possible attack for {any} now\n", .{board.state.turn});
    // const moves = movgen.generateMoves(&board);
    // for (0..moves.len) |i| {
    //     std.debug.print("==========================================================================\n", .{});
    //     // std.debug.print("{b:0>64}\n", .{moves.moves[i].data});
    //     board.makeMove(moves.moves[i]);
    //     // printBitboard(board.side_bb[0] | board.side_bb[1]);
    //     board.printBoard();
    //     board.state.print();
    //     std.debug.print("Is King in check: {any}\n", .{movgen.isInCheck(&board, board.state.turn.opponent())});
    //     _ = std.io.getStdIn().reader().readByte() catch unreachable;
    //     board.unMakeMove();
    // }
}
