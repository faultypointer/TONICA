const std = @import("std");
const types = @import("board/types.zig");
const eval = @import("evaluation.zig");
const sort = @import("search/sort.zig");
const MovGen = @import("movegen.zig").MovGen;
const MoveList = types.MoveList;
const Move = types.Move;
const Side = types.Side;
const Board = @import("board.zig").Board;

pub const SearchResult = struct {
    best_score: i32,
    best_move: Move,
};

pub fn search(board: *Board, movgen: *const MovGen, depth: u8) SearchResult {
    var result = SearchResult{ .best_score = -0xffffff, .best_move = Move{
        .data = 0,
    } };

    var alpha: i32 = -0xffffff;
    const beta: i32 = 0xffffff;

    var movelist = movgen.generateMoves(board);
    for (2..depth + 1) |d| {
        for (0..movelist.len) |i| {
            var move = &movelist.moves[i];
            board.makeMove(move.*);
            if (movgen.isInCheck(board, board.state.turn.opponent())) {
                board.unMakeMove();
                continue;
            }
            const dep: u8 = @truncate(d - 1);
            const score = -alphabeta(board, movgen, dep, -beta, -alpha);
            move.score = if (score < 0) @intCast(-score) else @intCast(score);
            board.unMakeMove();
            if (score > result.best_score) {
                result.best_score = score;
                result.best_move = move.*;
            }

            alpha = if (score > alpha) score else alpha;
            if (alpha >= beta) break;
        }
        sort.sortMoveList(&movelist);
    }
    return result;
}

fn alphabeta(board: *Board, movgen: *const MovGen, depth: u8, A: i32, beta: i32) i32 {
    if (depth == 0) { // or game draw?? over??
        // TODO quiescence search
        return eval.evaluatePosition(board);
    }
    var alpha = A;
    const movelist = movgen.generateMoves(board);
    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        board.makeMove(move);
        if (movgen.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            continue;
        }
        const score = -alphabeta(board, movgen, depth - 1, -beta, -alpha);
        board.unMakeMove();
        alpha = if (score > alpha) score else alpha;
        if (alpha >= beta) break;
    }
    return alpha;
}
