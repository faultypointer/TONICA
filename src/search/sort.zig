const sort = @import("std").sort;

const types = @import("../board/types.zig");
const Move = types.Move;
const MoveList = types.MoveList;

pub fn sortMoveList(moves: *MoveList) void {
    sort.block(Move, moves.moves[0..moves.len], {}, lessThanMove);
}

fn lessThanMove(_: void, a: Move, b: Move) bool {
    return a.score > b.score;
}
