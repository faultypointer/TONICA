const std = @import("std");
const assert = std.debug.assert;
const sort = std.sort;

const types = @import("../board/types.zig");
const Move = types.Move;
const MoveList = types.MoveList;
const PieceType = types.PieceType;

const SearchRef = @import("../search.zig").SearchRef;

pub fn sortMoveList(moves: *MoveList) void {
    sort.block(Move, moves.moves[0..moves.len], {}, lessThanMove);
}

fn lessThanMove(_: void, a: Move, b: Move) bool {
    return a.score > b.score;
}

pub fn scoreMoves(movelist: *MoveList, ref: *SearchRef) void {
    const follow_pv = ref.follow_pv;
    if (follow_pv) ref.follow_pv = false;
    for (0..movelist.len) |i| {
        const move = &movelist.moves[i];
        if (follow_pv) {
            if (ref.pv_table[0][ref.ply].data == move.data) {
                ref.follow_pv = true;
                move.score = 20000;
            }
        }
        if (move.isCapture()) {
            assert(move.capturedPiece() != PieceType.None);
            const attacker = @intFromEnum(move.piece());
            const victim = @intFromEnum(move.capturedPiece());
            move.score += MVVLVA[attacker][victim] + 10000;
        } else { // score quite moves
            if (ref.killer_moves[0][ref.ply]) |killer_move| {
                if (killer_move.data == move.data) {
                    move.score += 9000;
                }
            } else if (ref.killer_moves[1][ref.ply]) |killer_move| {
                if (killer_move.data == move.data) {
                    move.score += 8000;
                }
            } else {
                var pcs_idx: usize = @intCast(@intFromEnum(move.piece()));
                if (ref.board.state.turn == .Black) pcs_idx += 6;
                const sq = @intFromEnum(move.toSquare());
                move.score += ref.history_moves[pcs_idx][sq];
            }
        }
    }
}

const MVVLVA = [6][6]i32{
    [6]i32{ 105, 305, 205, 405, 505, 605 },
    [6]i32{ 104, 304, 204, 404, 504, 604 },
    [6]i32{ 103, 303, 203, 403, 503, 603 },
    [6]i32{ 102, 302, 202, 402, 502, 602 },
    [6]i32{ 101, 301, 201, 401, 501, 601 },
    [6]i32{ 100, 300, 200, 400, 500, 600 },
};
