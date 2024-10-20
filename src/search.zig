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
    ply: u8 = 0,
};

pub const SearchParams = struct {
    depth: u8 = MAX_DEPTH,
    time: ?u64 = null, // in nanoseconds
    node: ?u64 = null,
    board: *Board,
    movgen: *const MovGen,
};

pub fn search(params: SearchParams) SearchResult {
    var result = SearchResult{
        .best_score = -0xffffff,
        .best_move = Move{
            .data = 0,
        },
        .nodes_searched = 0,
        .ply = 0,
        .time = std.time.Timer.start() catch unreachable,
    };
    _ = alphabeta(params, &result, -0x7ffffff, 0x7ffffff, params.depth);
    return result;
}

pub fn alphabeta(params: SearchParams, res: *SearchResult, A: i32, beta: i32, depth: u8) i32 {
    const board = params.board;
    const movgen = params.movgen;
    var alpha = A;
    res.nodes_searched += 1;

    const in_check = movgen.isInCheck(board, board.state.turn);
    var legal_moves: u8 = 0;
    if (shouldTerminate(params, res) or depth == 0) { // or game draw?? over??
        return eval.evaluatePosition(board);
        // return quiescence(params, res, A, beta);
    }
    const movelist = movgen.generateMoves(board, .All);
    for (0..movelist.len) |i| {
        res.ply += 1;
        const move = movelist.moves[i];
        board.makeMove(move);
        if (movgen.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            res.ply -= 1;
            continue;
        }
        legal_moves += 1;
        const score = -alphabeta(params, res, -beta, -alpha, depth - 1);
        res.ply -= 1;
        if (res.ply == 0) {
            move.debugPrint();
            board.printBoard();
            std.debug.print("score: {} depth: {}\n", .{ score, params.depth - depth });
            _ = std.io.getStdIn().reader().readByte() catch unreachable;
        }
        board.unMakeMove();
        if (score >= beta) return beta;
        if (score > alpha) {
            alpha = score;
            if (res.ply == 0) {
                res.best_move = move;
                res.best_score = score;
            }
        }
    }
    if (legal_moves == 0) {
        if (in_check) return -0x1ffff + @as(i32, res.ply);
        return 0;
    }
    return alpha;
}

fn quiescence(params: SearchParams, res: *SearchResult, A: i32, beta: i32) i32 {
    const board = params.board;
    const movgen = params.movgen;
    res.nodes_searched += 1;
    const stand_pat = eval.evaluatePosition(board);
    var alpha = A;
    if (stand_pat >= beta) return beta;
    if (stand_pat > alpha) alpha = stand_pat;
    if (shouldTerminate(params, res)) {
        return alpha;
    }
    const captures = movgen.generateMoves(board, MoveType.Capture);
    for (0..captures.len) |i| {
        board.makeMove(captures.moves[i]);
        if (movgen.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            continue;
        }
        const score = -quiescence(params, res, -beta, -alpha);
        board.unMakeMove();
        if (score >= beta) return beta;
        if (score > alpha) alpha = score;
    }
    return alpha;
}

fn shouldTerminate(params: SearchParams, res: *SearchResult) bool {
    if (params.time) |t| {
        if (res.time.read() >= t) return true;
    }
    if (params.node) |node| {
        if (res.nodes_searched >= node) return true;
    }
    return false;
}
