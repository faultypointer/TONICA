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

const MAX_PLY = 64;
const FULL_MOVE_SEARCH = 4;
const REDUCTION_LIMIT = 3;

pub const KillerMoves = [2][MAX_PLY]?Move;
pub const HistoryMoves = [12][64]i32;
pub const PVTable = [MAX_PLY][MAX_PLY]Move;
pub const SearchResult = struct {
    best_score: i32,
    best_move: Move,
    nodes_searched: u64,
};

pub const SearchRef = struct {
    follow_pv: bool = false,
    board: *Board,
    mg: *MovGen,
    res: *SearchResult,
    ply: u8 = 0,
    killer_moves: KillerMoves,
    history_moves: HistoryMoves,
    pv_table: PVTable,
    pv_length: [MAX_PLY]usize,
};

pub fn search(board: *Board, mg: *MovGen, depth: u8) SearchResult {
    var result = SearchResult{
        .best_score = -0xffffff,
        .best_move = Move{
            .data = 0,
        },
        .nodes_searched = 0,
    };

    var ref = SearchRef{
        .board = board,
        .mg = mg,
        .killer_moves = undefined,
        .history_moves = undefined,
        .pv_table = undefined,
        .pv_length = undefined,
        .res = &result,
        .ply = 0,
    };
    for (0..2) |i| {
        for (0..MAX_PLY) |j| {
            ref.killer_moves[i][j] = null;
        }
    }
    for (0..12) |i| {
        for (0..64) |j| {
            ref.history_moves[i][j] = 0;
        }
    }
    for (0..MAX_PLY) |i| {
        ref.pv_length[i] = 0;
        for (0..MAX_PLY) |j| {
            ref.pv_table[i][j] = Move{ .data = 0 };
        }
    }
    for (1..depth + 1) |dep| {
        ref.follow_pv = true;
        const d: u8 = @intCast(dep);
        result.best_score = negamax(&ref, -0x7ffffff, 0x7ffffff, d);
    }
    result.best_move = ref.pv_table[0][0];
    return result;
}

fn negamax(ref: *SearchRef, alpha: i32, beta: i32, depth: u8) i32 {
    const board = ref.board;
    const mg = ref.mg;
    const res = ref.res;
    var mut_alpha = alpha;
    var found_pv = false;
    ref.pv_length[ref.ply] = ref.ply;

    if (depth == 0) {
        return quiescence(ref, alpha, beta);
    }

    if (ref.ply > MAX_PLY - 1) {
        return eval.evaluatePosition(board);
    }

    const in_check = mg.isInCheck(board, board.state.turn);
    var legal_moves: u8 = 0;
    res.nodes_searched += 1;
    if (!in_check and (depth >= 3) and (ref.ply > 0)) {
        board.makeNullMove();
        const score = -negamax(ref, -beta, -beta + 1, depth - 1 - 2);
        board.unMakeNullMove();
        if (score >= beta) return beta;
    }
    var movelist = mg.generateMoves(board, .All);
    sort.scoreMoves(&movelist, ref);
    sort.sortMoveList(&movelist);

    var move_searched: usize = 0;
    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        ref.ply += 1;
        board.makeMove(move);
        if (mg.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            ref.ply -= 1;
            continue;
        }
        legal_moves += 1;
        var score: i32 = 0;
        if (found_pv) {
            score = -negamax(ref, -mut_alpha - 1, -mut_alpha, depth - 1);
            if ((score > mut_alpha) and (score < beta)) {
                score = -negamax(ref, -beta, -mut_alpha, depth - 1);
            }
        } else {
            if (move_searched >= FULL_MOVE_SEARCH and depth >= REDUCTION_LIMIT and !mg.isInCheck(board, board.state.turn)) {
                score = -negamax(ref, -beta, -mut_alpha, depth - 2);
            } else {
                score = mut_alpha + 1;
            }
            if (score > mut_alpha) {
                score = -negamax(ref, -beta, -mut_alpha, depth - 1);
            }
        }
        board.unMakeMove();
        move_searched += 1;
        ref.ply -= 1;

        if (score >= beta) {
            if (!move.isCapture()) {
                if (ref.killer_moves[0][ref.ply]) |prev_killer| {
                    ref.killer_moves[1][ref.ply] = prev_killer;
                }
                ref.killer_moves[0][ref.ply] = move;
            }
            return beta;
        }

        if (score > mut_alpha) {
            found_pv = true;

            ref.pv_table[ref.ply][ref.ply] = move;
            for (ref.ply + 1..ref.pv_length[ref.ply + 1]) |next_ply| {
                ref.pv_table[ref.ply][ref.ply + 1] = ref.pv_table[ref.ply + 1][next_ply];
            }
            ref.pv_length[ref.ply] = ref.pv_length[ref.ply + 1];
            mut_alpha = score;
            if (!move.isCapture()) {
                var pcs_idx: usize = @intCast(@intFromEnum(move.piece()));
                if (ref.board.state.turn == .Black) pcs_idx += 6;
                const sq = @intFromEnum(move.toSquare());
                ref.history_moves[pcs_idx][sq] += depth;
            }
        }
    }
    if (legal_moves == 0) {
        if (in_check) return -0xffffff + @as(i32, ref.ply);
        return 0;
    }

    return mut_alpha;
}

fn quiescence(ref: *SearchRef, alpha: i32, beta: i32) i32 {
    const board = ref.board;
    const mg = ref.mg;
    const res = ref.res;
    var mut_alpha = alpha;
    res.nodes_searched += 1;

    const evaluation = eval.evaluatePosition(board);

    if (evaluation >= beta) return beta;

    if (evaluation > mut_alpha) {
        mut_alpha = evaluation;
    }

    var movelist = mg.generateMoves(board, .Capture);
    sort.scoreMoves(&movelist, ref);
    sort.sortMoveList(&movelist);
    for (0..movelist.len) |i| {
        const move = movelist.moves[i];
        ref.ply += 1;
        board.makeMove(move);
        if (mg.isInCheck(board, board.state.turn.opponent())) {
            board.unMakeMove();
            ref.ply -= 1;
            continue;
        }
        const score = -quiescence(ref, -beta, -mut_alpha);
        board.unMakeMove();
        ref.ply -= 1;

        if (score >= beta) return beta;

        if (score > mut_alpha) {
            mut_alpha = score;
        }
    }
    return mut_alpha;
}
