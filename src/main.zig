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
const eval = @import("evaluation.zig");
const sear = @import("search.zig");

pub fn main() !void {
    // std.debug.print("Qf7#\n", .{});
    var board: Board = Board.readFromFen("rnbqkbnr/ppp2ppp/8/3pp1B1/4P1Q1/3P4/PPP2PPP/RN2KBNR w KQkq - 0 1");
    const movgen = MovGen.init();
    // var buffer: [1024]u8 = undefined;
    // for (0..buffer.len) |i| {
    //     buffer[i] = 0;
    // }
    // var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // const allocator = fba.allocator();
    //
    // var args = try std.process.argsWithAllocator(allocator);
    // defer args.deinit();
    //
    // _ = args.skip();
    //
    // if (args.next()) |fen| {
    //     board = Board.readFromFen(fen);
    // } else {
    //     return;
    // }
    //
    // if (args.next()) |depth| {
    //     _ = try perft.runPerft(&movgen, &board, try std.fmt.parseInt(usize, depth, 10));
    // }
    // std.debug.print("possible attack for {any} now\n", .{board.state.turn});
    std.debug.print("Current Position with score: {}\n", .{eval.evaluatePosition(&board)});
    board.printBoard();
    std.debug.print("Moves for white with scores: \n", .{});
    for (0..100) |_| {
        std.debug.print("==========================================================================\n", .{});
        // std.debug.print("{b:0>64}\n", .{moves.moves[i].data});
        const res = sear.search(&board, &movgen, 8);
        std.debug.print("The best move for position is: \n", .{});
        res.best_move.debugPrint();
        std.debug.print("After making move: \n", .{});
        board.makeMove(res.best_move);
        // printBitboard(board.side_bb[0] | board.side_bb[1]);
        board.printBoard();
        // board.state.print();
        // std.debug.print("Is King in check: {any}\n", .{movgen.isInCheck(&board, board.state.turn.opponent())});
        std.debug.print("Score: {}\n", .{eval.evaluatePosition(&board)});
        _ = std.io.getStdIn().reader().readByte() catch unreachable;
    }
}
