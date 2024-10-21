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
const MAX_PLY = 64;

pub const SearchResult = struct {
    best_score: i32,
    best_move: Move,
    nodes_searched: u64,
    ply: u8 = 0,
};

pub const SearchRef = struct {
    board: *Board,
    mg: *MovGen,
    res: *SearchResult,
    killer_moves: [2][MAX_PLY]?Move,
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

    var ref = SearchRef{
        .board = board,
        .mg = mg,
        .killer_moves = undefined,
        .res = &result,
    };
    for (0..2) |i| {
        for (0..MAX_PLY) |j| {
            ref.killer_moves[i][j] = null;
        }
    }
    result.best_score = negamax(&ref, -0x7ffffff, 0x7ffffff, depth);
    return result;
}

fn negamax(ref: *SearchRef, alpha: i32, beta: i32, depth: u8) i32 {
    const board = ref.board;
    const mg = ref.mg;
    const res = ref.res;
    var mut_alpha = alpha;

    if (depth == 0) {
        return quiescence(board, mg, res, alpha, beta);
    }

    const in_check = mg.isInCheck(board, board.state.turn);
    var legal_moves: u8 = 0;
    res.nodes_searched += 1;
    var movelist = mg.generateMoves(board, .All);
    sort.scoreMoves(&movelist);
    sort.sortMoveList(&movelist);

    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        res.ply += 1;
        board.makeMove(move);
        // std.debug.print("available pseudo moves\n", .{});
        // board.printBoard();
        if (mg.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            res.ply -= 1;
            continue;
        }
        // std.debug.print("legal move\n", .{});
        // _ = std.io.getStdIn().reader().readByte() catch unreachable;
        legal_moves += 1;
        const score = -negamax(ref, -beta, -mut_alpha, depth - 1);
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
    res.nodes_searched += 1;

    const evaluation = eval.evaluatePosition(board);

    if (evaluation >= beta) return beta;

    if (evaluation > mut_alpha) {
        mut_alpha = evaluation;
    }

    var movelist = mg.generateMoves(board, .Capture);
    sort.scoreMoves(&movelist);
    sort.sortMoveList(&movelist);
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
