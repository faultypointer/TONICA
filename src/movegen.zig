const sliderattack = @import("movegen/sliderattack.zig");
const SliderAttack = sliderattack.SliderAttack;
const ROOK_MASK = sliderattack.ROOK_OCCUPANCY;
const BISHOP_MASK = sliderattack.BISHOP_OCCUPANCY;
const ROOK_MAGIC = sliderattack.ROOK_MAGIC;
const BISHOP_MAGIC = sliderattack.BISHOP_MAGIC;

const nonsliderattack = @import("movegen/nonsliderattack.zig");
const KNIGHT_ATTACK = nonsliderattack.KNIGHT_ATTACK;
const KING_ATTACK = nonsliderattack.KING_ATTACK;

const types = @import("board/types.zig");
const Move = types.Move;
const MoveList = types.MoveList;
const PieceType = types.PieceType;
const Square = types.Square;

const mboard = @import("board.zig");
const Board = mboard.Board;

const bitboard = @import("board/bitboard.zig");
const BitBoard = bitboard.BitBoard;
pub const MovGen = struct {
    slider_attack: SliderAttack,

    pub fn init() MovGen {
        return MovGen{
            .slider_attack = SliderAttack.init(),
        };
    }
    pub fn generateMoves(self: *MovGen, board: Board) MoveList {
        var movelist = MoveList.init();
        self.generateSliderMoves(board, &movelist);
        self.generateKnightMoves(board, &movelist);
        self.generateKingMoves(board, &movelist);

        return movelist;
    }
    // TODO castling moves and castling while in check moves which i dont know should be handled here or
    // while searching
    fn generateKingMoves(_: MovGen, board: Board, movelist: *MoveList) void {
        const us = board.state.turn;
        const us_idx: usize = @intCast(@intFromEnum(us));
        const opp = board.state.turn.opponent();
        const opp_idx: usize = @intCast(@intFromEnum(opp));
        const king_idx = @as(usize, @intFromEnum(PieceType.King));
        var bb = board.piece_bb[us_idx][king_idx];
        const occupancy = board.side_bb[0] | board.side_bb[1];
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            var attack = KING_ATTACK[sq];
            attack &= bitboard.complement(board.side_bb[us_idx]);
            var empty_squares = bitboard.complement(occupancy) & attack;
            // captures
            var captures = attack & board.side_bb[opp_idx];

            while (empty_squares != 0) {
                const to = bitboard.removeLS1B(&empty_squares);
                movelist.addMove(Move.init(sq, to, PieceType.King));
            }
            while (captures != 0) {
                const to = bitboard.removeLS1B(&captures);
                var move = Move.init(sq, to, PieceType.King);
                const to_sq: Square = @enumFromInt(to);
                const cap = board.pieceAt(to_sq, opp);
                move.addCapturePiece(cap.?);
                movelist.addMove(move);
            }
        }
    }

    fn generateKnightMoves(_: MovGen, board: Board, movelist: *MoveList) void {
        const us = board.state.turn;
        const us_idx: usize = @intCast(@intFromEnum(us));
        const opp = board.state.turn.opponent();
        const opp_idx: usize = @intCast(@intFromEnum(opp));
        const knight_idx = @as(usize, @intFromEnum(PieceType.Knight));
        var bb = board.piece_bb[us_idx][knight_idx];
        const occupancy = board.side_bb[0] | board.side_bb[1];
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            var attack = KNIGHT_ATTACK[sq];
            attack &= bitboard.complement(board.side_bb[us_idx]);
            var empty_squares = bitboard.complement(occupancy) & attack;
            // captures
            var captures = attack & board.side_bb[opp_idx];

            while (empty_squares != 0) {
                const to = bitboard.removeLS1B(&empty_squares);
                movelist.addMove(Move.init(sq, to, PieceType.Knight));
            }
            while (captures != 0) {
                const to = bitboard.removeLS1B(&captures);
                var move = Move.init(sq, to, PieceType.Knight);
                const to_sq: Square = @enumFromInt(to);
                const cap = board.pieceAt(to_sq, opp);
                move.addCapturePiece(cap.?);
                movelist.addMove(move);
            }
        }
    }

    fn generateSliderMoves(self: *MovGen, board: Board, movelist: *MoveList) void {
        const us = board.state.turn;
        const us_idx: usize = @intCast(@intFromEnum(us));
        const opp = board.state.turn.opponent();
        const opp_idx: usize = @intCast(@intFromEnum(opp));
        const sliders = [_]PieceType{ PieceType.Bishop, PieceType.Rook, PieceType.Queen };
        for (sliders) |slider| {
            const slider_idx = @as(usize, @intFromEnum(slider));
            var bb = board.piece_bb[us_idx][slider_idx];
            const occupancy = board.side_bb[0] | board.side_bb[1];
            while (bb != 0) {
                const sq = bitboard.removeLS1B(&bb);
                var attack = switch (slider) {
                    .Bishop => blk: {
                        const blockers = occupancy & BISHOP_MASK[sq];
                        const magic_index = (blockers *% BISHOP_MAGIC[sq]) >> 55;
                        break :blk self.slider_attack.bishop[sq][magic_index];
                    },
                    .Rook => blk: {
                        const blockers = occupancy & ROOK_MASK[sq];
                        const magic_index = (blockers *% ROOK_MAGIC[sq]) >> 52;
                        break :blk self.slider_attack.rook[sq][magic_index];
                    },
                    .Queen => blk: {
                        var blockers = occupancy & BISHOP_MASK[sq];
                        var magic_index = (blockers *% BISHOP_MAGIC[sq]) >> 55;
                        const bishop_attack = self.slider_attack.bishop[sq][magic_index];
                        blockers = occupancy & ROOK_MASK[sq];
                        magic_index = (blockers *% ROOK_MASK[sq]) >> 52;
                        break :blk self.slider_attack.rook[sq][magic_index] | bishop_attack;
                    },
                    else => unreachable,
                };
                // disable friendly fire
                attack &= bitboard.complement(board.side_bb[us_idx]);
                // non captures
                var empty_squares = bitboard.complement(occupancy) & attack;
                // captures
                var captures = attack & board.side_bb[opp_idx];

                while (empty_squares != 0) {
                    const to = bitboard.removeLS1B(&empty_squares);
                    movelist.addMove(Move.init(sq, to, slider));
                }
                while (captures != 0) {
                    const to = bitboard.removeLS1B(&captures);
                    var move = Move.init(sq, to, slider);
                    const to_sq: Square = @enumFromInt(to);
                    const cap = board.pieceAt(to_sq, opp);
                    move.addCapturePiece(cap.?);
                    movelist.addMove(move);
                }
            }
        }
    }
};
