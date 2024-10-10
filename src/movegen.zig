const sliderattack = @import("movegen/sliderattack.zig");
const SliderAttack = sliderattack.SliderAttack;
const ROOK_MASK = sliderattack.ROOK_OCCUPANCY;
const BISHOP_MASK = sliderattack.BISHOP_OCCUPANCY;
const ROOK_MAGIC = sliderattack.ROOK_MAGIC;
const BISHOP_MAGIC = sliderattack.BISHOP_MAGIC;

const types = @import("board/types.zig");
const Move = types.Move;
const MoveList = types.MoveList;
const PieceType = types.PieceType;

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
        self.generateSliderMoves(&movelist, board);

        return movelist;
    }

    fn generateSliderMoves(self: *MovGen, board: Board, movelist: *MoveList) void {
        const us = board.state.turn;
        const opp = board.state.turn.opponent();
        const sliders = [_]PieceType{ PieceType.Bishop, PieceType.Rook, PieceType.Queen };
        for (sliders) |slider| {
            var bb = board.piece_bb[us][slider];
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
                attack &= bitboard.complement(board.side_bb[us]);
                // non captures
                var empty_squares = bitboard.complement(occupancy) & attack;
                // captures
                var captures = attack & board.side_bb[opp];

                while (empty_squares != 0) {
                    const to = bitboard.removeLS1B(&empty_squares);
                    movelist.addMove(Move.init(sq, to, slider));
                }
                while (captures != 0) {
                    const to = bitboard.removeLS1B(&captures);
                    var move = Move.init(sq, to, slider);
                    const cap = board.pieceAt(to, opp);
                    move.addCapturePiece(cap.?);
                    movelist.addMove(move);
                }
            }
        }
    }
};
