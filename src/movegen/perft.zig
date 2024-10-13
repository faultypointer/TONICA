const std = @import("std");
const stdout = std.io.getStdOut().writer();
const time = std.time;

const MovGen = @import("../movegen.zig").MovGen;
const Board = @import("../board.zig").Board;
const Move = @import("../board/types.zig").Move;
const PieceType = @import("../board/types.zig").PieceType;
const bitboard = @import("../board//bitboard.zig");

fn perft(movgen: *const MovGen, board: *Board, depth: usize) u64 {
    var nodes: u64 = 0;

    if (depth == 0) return 1;

    const movelist = movgen.generateMoves(board);
    for (0..movelist.len) |i| {
        board.makeMove(movelist.moves[i]);
        if (!movgen.isInCheck(board, board.state.turn.opponent())) {
            nodes += perft(movgen, board, depth - 1);
        }
        board.unMakeMove();
    }
    return nodes;
}

pub fn runPerft(movgen: *const MovGen, board: *Board, depth: usize) !void {
    var total_nodes: u128 = 0;
    var timer = try time.Timer.start();
    try stdout.print("============================XX PERFORMANCE TESTING XX==================================", .{});
    try stdout.print("Running Perft on board: \n", .{});
    for (1..depth + 1) |d| {
        _ = timer.lap();
        const leaf_nodes = perft(movgen, board, d);
        const time_taken = timer.lap();
        total_nodes += leaf_nodes;

        try stdout.print("Perft [{}]: Nodes: {} Time: {}ns Rate: {}nodes/sec\n", .{ d, leaf_nodes, time_taken, leaf_nodes * 1000000000 / time_taken });
    }

    try stdout.print("Total Nodes: {}\n", .{total_nodes});
}

pub fn divide(movgen: *const MovGen, board: *Board, depth: usize) !u64 {
    var total_nodes: u64 = 0;
    const movelist = movgen.generateMoves(board);

    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        board.makeMove(move);
        if (!movgen.isInCheck(board, board.state.turn.opponent())) {
            const nodes = perft(movgen, board, depth - 1);
            total_nodes += nodes;
            try stdout.print("{s}: {}\n", .{ move.toPerftString(), nodes });
        }
        board.unMakeMove();
    }

    try stdout.print("\n{}\n", .{total_nodes});
    return total_nodes;
}
