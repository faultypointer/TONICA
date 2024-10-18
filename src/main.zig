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
const MoveType = movegen.MoveType;
const perft = @import("movegen/perft.zig");
const eval = @import("evaluation.zig");
const sear = @import("search.zig");
const SearchParam = sear.SearchParams;

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
    std.debug.print("possible attack for {any} now\n", .{board.state.turn});
    std.debug.print("Current Position with score: {}\n", .{eval.evaluatePosition(&board)});
    board.printBoard();
    for (0..100) |_| {
        std.debug.print("==========================================================================\n", .{});
        const params = SearchParam{
            .board = &board,
            .movgen = &movgen,
            .time = 10000000000, // 10 sec
        };
        const res = sear.search(params);
        res.best_move.debugPrint();
        board.makeMove(res.best_move);
        board.printBoard();
        _ = std.io.getStdIn().reader().readByte() catch unreachable;
    }
}
