const std = @import("std");
const types = @import("board/types.zig");
const eval = @import("evaluation.zig");
const sort = @import("search/sort.zig");
const MovGen = @import("movegen.zig").MovGen;
const MoveType = @import("movegen.zig").MoveType;
const MoveList = types.MoveList;
const Move = types.Move;
const Side = types.Side;
const Board = @import("board.zig").Board;

const MAX_DEPTH = 100;

pub const SearchResult = struct {
    best_score: i32,
    best_move: Move,
    nodes_searched: u64,
    time: std.time.Timer,
};

pub const SearchParams = struct {
    depth: u8 = MAX_DEPTH,
    time: ?u64 = null, // in nanoseconds
    node: ?u64 = null,
    board: *Board,
    movgen: *const MovGen,
};

pub fn search(params: SearchParams) SearchResult {
    const board = params.board;
    const movgen = params.movgen;
    var result = SearchResult{
        .best_score = -0xffffff,
        .best_move = Move{
            .data = 0,
        },
        .nodes_searched = 0,
        .time = std.time.Timer.start() catch unreachable,
    };

    var alpha: i32 = -0xffffff;
    const beta: i32 = 0xffffff;

    var movelist = movgen.generateMoves(board, MoveType.All);
    for (2..params.depth + 1) |d| {
        for (0..movelist.len) |i| {
            result.nodes_searched += 1;
            var move = &movelist.moves[i];
            board.makeMove(move.*);
            if (movgen.isInCheck(board, board.state.turn.opponent())) {
                board.unMakeMove();
                continue;
            }
            const dep: u8 = @truncate(d - 1);
            var abparam = params;
            abparam.depth = dep;
            const score = -alphabeta(&abparam, &result, -beta, -alpha);
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

fn alphabeta(params: *SearchParams, res: *SearchResult, A: i32, beta: i32) i32 {
    const board = params.board;
    const movgen = params.movgen;
    res.nodes_searched += 1;
    if (shouldTerminate(params, res)) { // or game draw?? over??
        // TODO quiescence search
        // params.depth = 1;
        // return quiescence(params, res, A, beta, 10);
        return eval.evaluatePosition(board);
    }
    params.depth -= 1;
    var alpha = A;
    const movelist = movgen.generateMoves(board, MoveType.All);
    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        board.makeMove(move);
        if (movgen.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            continue;
        }
        const score = -alphabeta(params, res, -beta, -alpha);
        board.unMakeMove();
        alpha = if (score > alpha) score else alpha;
        if (alpha >= beta) break;
    }
    return alpha;
}

fn quiescence(params: *SearchParams, res: *SearchResult, A: i32, beta: i32, qdepth: u8) i32 {
    const board = params.board;
    const movgen = params.movgen;
    res.nodes_searched += 1;
    const stand_pat = eval.evaluatePosition(board);
    var alpha = A;
    if (stand_pat >= beta) return beta;
    if (stand_pat > alpha) alpha = stand_pat;
    if (shouldTerminate(params, res) or qdepth == 0) {
        return alpha;
    }
    const captures = movgen.generateMoves(board, MoveType.Capture);
    for (0..captures.len) |i| {
        board.makeMove(captures.moves[i]);
        if (movgen.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            continue;
        }
        const score = -quiescence(params, res, -beta, -alpha, qdepth - 1);
        board.unMakeMove();
        if (score >= beta) return beta;
        if (score > alpha) alpha = score;
    }
    return alpha;
}

fn shouldTerminate(params: *SearchParams, res: *SearchResult) bool {
    if (params.depth == 0) return true;
    if (params.time) |t| {
        if (res.time.read() >= t) return true;
    }
    if (params.node) |node| {
        if (res.nodes_searched >= node) return true;
    }
    return false;
}
