const mboard = @import("board.zig");
const Board = mboard.Board;
const NUM_PIECE = mboard.NUM_PIECE_TYPE;
const bitboard = @import("board/bitboard.zig");
const types = @import("board//types.zig");
const Side = types.Side;

const MaterialScore = [_]i32{
    100, // pawn
    330, // bishop
    320, // knight
    500, // rook
    1000, // queen
    10000, // king
};

pub fn evaluatePosition(board: *const Board) i32 {
    var scores = [_]i32{ 0, 0 };

    for (0..2) |side_idx| {
        for (0..NUM_PIECE) |pcs_idx| {
            var bb = board.piece_bb[side_idx][pcs_idx];
            while (bb != 0) {
                var sq = bitboard.removeLS1B(&bb);
                if (side_idx == 1) sq = 63 - sq;
                scores[side_idx] += MaterialScore[pcs_idx];
                scores[side_idx] += PSQT[pcs_idx][sq];
            }
        }
    }
    const score = scores[0] - scores[1];
    return if (board.state.turn == .White) score else -score;
}

// sq ref
// {
//     a1, b1, c1, d1 e1, f1, g1, h1,
//     a2, b2, c2, d2, e2, f2, g2, h2,
//     a3, b3, c3, d3, e3, f3, g3, h3,
//     a4, b4, c4, d4, e4, f4, g4, h4,
//     a5, b5, c5, d5, e5, f5, g5, h5,
//     a6, b6, c6, d6, e6, f6, g6, h6,
//     a7, b7, c7, d7, e7, f7, g7, h7,
//     a8, b8, c8, d8, e8, f8, g8, h8,
// }

// PIECE SQUARE TABLE
const PSQT = [6][64]i32{
    [64]i32{ // pawns
        0,  0,  0,   0,   0,   0,   0,  0,
        5,  10, 10,  -20, -20, 10,  10, 5,
        5,  -5, -10, 0,   0,   -10, -5, 5,
        0,  0,  0,   20,  20,  0,   0,  0,
        5,  5,  10,  25,  25,  10,  5,  5,
        10, 10, 20,  30,  30,  20,  10, 10,
        50, 50, 50,  50,  50,  50,  50, 50,
        0,  0,  0,   0,   0,   0,   0,  0,
    },
    [64]i32{ // bishops
        -20, -10, -10, -10, -10, -10, -10, -20,
        -10, 5,   0,   0,   0,   0,   5,   -10,
        -10, 10,  10,  10,  10,  10,  10,  -10,
        -10, 0,   10,  10,  10,  10,  0,   -10,
        -10, 5,   5,   10,  10,  5,   5,   -10,
        -10, 0,   5,   10,  10,  5,   0,   -10,
        -10, 0,   0,   0,   0,   0,   0,   -10,
        -20, -10, -10, -10, -10, -10, -10, -20,
    },
    [64]i32{ // knight
        -50, -40, -30, -30, -30, -30, -40, -50,
        -40, -20, 0,   5,   5,   0,   -20, -40,
        -30, 5,   10,  15,  15,  10,  5,   -30,
        -30, 0,   15,  20,  20,  15,  0,   -30,
        -30, 5,   15,  20,  20,  15,  5,   -30,
        -30, 0,   10,  15,  15,  10,  0,   -30,
        -40, -20, 0,   0,   0,   0,   -20, -40,
        -50, -40, -30, -30, -30, -30, -40, -50,
    },
    [64]i32{ // rook
        0,  0,  0,  5,  5,  0,  0,  0,
        -5, 0,  0,  0,  0,  0,  0,  -5,
        -5, 0,  0,  0,  0,  0,  0,  -5,
        -5, 0,  0,  0,  0,  0,  0,  -5,
        -5, 0,  0,  0,  0,  0,  0,  -5,
        -5, 0,  0,  0,  0,  0,  0,  -5,
        5,  10, 10, 10, 10, 10, 10, 5,
        0,  0,  0,  0,  0,  0,  0,  0,
    },
    [64]i32{ // queen
        -20, -10, -10, -5, -5, -10, -10, -20,
        -10, 0,   5,   0,  0,  0,   0,   -10,
        -10, 5,   5,   5,  5,  5,   0,   -10,
        0,   0,   5,   5,  5,  5,   0,   -5,
        -5,  0,   5,   5,  5,  5,   0,   -5,
        -10, 0,   5,   5,  5,  5,   0,   -10,
        -10, 0,   0,   0,  0,  0,   0,   -10,
        -20, -10, -10, -5, -5, -10, -10, -20,
    },
    [64]i32{ // king
        20,  30,  10,  0,   0,   10,  30,  20,
        20,  20,  0,   0,   0,   0,   20,  20,
        -10, -20, -20, -20, -20, -20, -20, -10,
        -20, -30, -30, -40, -40, -30, -30, -20,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
    },
};
