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
    ply: u8 = 0,
};

pub fn search(board: *Board, mg: *MovGen, depth: u8) SearchResult {
    var result = SearchResult{
        .best_score = -0xffffff,
        .best_move = Move{
            .data = 0,
        },
        .nodes_searched = 0,
        .ply = 0,
    };
    result.best_score = negamax(board, mg, &result, -0x7ffffff, 0x7ffffff, depth);
    return result;
}

fn negamax(board: *Board, mg: *const MovGen, res: *SearchResult, alpha: i32, beta: i32, depth: u8) i32 {
    var mut_alpha = alpha;

    if (depth == 0) {
        return quiescence(board, mg, res, alpha, beta);
    }

    const in_check = mg.isInCheck(board, board.state.turn);
    var legal_moves: u8 = 0;
    res.nodes_searched += 1;
    const movelist = mg.generateMoves(board, .All);

    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        res.ply += 1;
        board.makeMove(move);
        if (mg.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            res.ply -= 1;
            continue;
        }
        legal_moves += 1;
        const score = -negamax(board, mg, res, -beta, -mut_alpha, depth - 1);
        board.unMakeMove();
        res.ply -= 1;

        if (score >= beta) return beta;

        if (score > mut_alpha) {
            mut_alpha = score;
            if (res.ply == 0) {
                res.best_move = move;
            }
        }
    }
    if (legal_moves == 0) {
        if (in_check) return -0xffffff + @as(i32, res.ply);
        return 0;
    }

    return mut_alpha;
}

fn quiescence(board: *Board, mg: *const MovGen, res: *SearchResult, alpha: i32, beta: i32) i32 {
    var mut_alpha = alpha;

    const evaluation = eval.evaluatePosition(board);

    if (evaluation >= beta) return beta;

    if (evaluation > mut_alpha) {
        mut_alpha = evaluation;
    }

    const movelist = mg.generateMoves(board, .Capture);
    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        res.ply += 1;
        board.makeMove(move);
        if (mg.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            res.ply -= 1;
            continue;
        }
        const score = -quiescence(board, mg, res, -beta, -mut_alpha);
        board.unMakeMove();
        res.ply -= 1;

        if (score >= beta) return beta;

        if (score > mut_alpha) {
            mut_alpha = score;
        }
    }
    return mut_alpha;
}
