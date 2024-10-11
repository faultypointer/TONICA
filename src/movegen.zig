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
const Side = types.Side;
const RANK7 = types.BBRANK7;
const RANK2 = types.BBRANK2;

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
        self.generatePawnMoves(board, &movelist);

        return movelist;
    }

    fn generatePawnMoves(_: *const MovGen, board: Board, movelist: *MoveList) void {
        const us = board.state.turn;
        const us_idx: usize = @intCast(@intFromEnum(us));
        const opp = board.state.turn.opponent();
        const opp_idx: usize = @intCast(@intFromEnum(opp));
        const occupancy = board.side_bb[us_idx] | board.side_bb[opp_idx];
        const pawn_bb = board.piece_bb[us_idx][@as(usize, @intFromEnum(PieceType.Pawn))];
        // single push no promotion
        var bb = pawn_bb;
        bb &= if (us == Side.White) ~RANK7 else ~RANK2; // remove pawn that will promote
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            const to = if (us == Side.White) sq +% 8 else sq -% 8;
            if ((occupancy & (@as(u64, 1) << to)) != 0) continue;
            const move = Move.init(sq, to, PieceType.Pawn);
            movelist.addMove(move);
        }

        // captures
        bb = pawn_bb;
        bb &= if (us == Side.White) ~RANK7 else ~RANK2; // remove pawn that will promote
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            // not enpassant captures
            var possible_captures = nonsliderattack.PAWN_ATTACK[us_idx][sq] & board.side_bb[opp_idx];
            while (possible_captures != 0) {
                const to = bitboard.removeLS1B(&possible_captures);
                var move = Move.init(sq, to, PieceType.Pawn);
                const to_sq: Square = @enumFromInt(to);
                const cap = board.pieceAt(to_sq, opp);
                move.addCapturePiece(cap.?);
                movelist.addMove(move);
            }
        }

        // double push
        bb = pawn_bb;
        bb &= if (us == Side.White) RANK2 else RANK7; // double push only available on starting square
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            const to = if (us == Side.White) sq +% 16 else sq -% 16;
            var pawn_blockers = @as(u64, 0x101);
            pawn_blockers <<= if (us == Side.White) (to - 8) else to;
            if ((occupancy & pawn_blockers) != 0) continue;
            var move = Move.init(sq, to, PieceType.Pawn);
            move.setDoubleStepFlag();
            movelist.addMove(move);
        }
    }

    fn generateKingMoves(_: *const MovGen, board: Board, movelist: *MoveList) void {
        const us = board.state.turn;
        const us_idx: usize = @intCast(@intFromEnum(us));
        const opp = board.state.turn.opponent();
        const opp_idx: usize = @intCast(@intFromEnum(opp));
        const king_idx = @as(usize, @intFromEnum(PieceType.King));
        var bb = board.piece_bb[us_idx][king_idx];
        const occupancy = board.side_bb[0] | board.side_bb[1];
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

        // castl
        switch (us) {
            // NOTE WARN ive decided to check if the square king has to move throught while castling
            // is attacked by enemy pieces or not when doing searching
            .White => {
                // king side castle
                if (((board.state.castling_rights & mboard.Castling_WK) != 0) and // has castling rights
                    ((occupancy & 0x60) == 0) // and // no pieces (enemy or friend) between king and rook
                // ((board.attacks_bb[opp_idx] & 0x60) == 0) // no enemy pieces attacks the square the king moves through
                ) {
                    movelist.addMove(types.White_King_Castle);
                }
                // queen side castle
                if (((board.state.castling_rights & mboard.Castling_WQ) != 0) and // has castling rights
                    ((occupancy & 0x0E) == 0) // and // no pieces (enemy or friend) between king and rook
                // ((board.attacks_bb[opp_idx] & 0x0C) == 0) // no enemy pieces attacks the square the king moves through
                ) {
                    movelist.addMove(types.White_Queen_Castle);
                }
            },
            .Black => {
                // king side castle
                if (((board.state.castling_rights & mboard.Castling_BK) != 0) and // has castling rights
                    ((occupancy & (@as(u64, 0x60) << 56)) == 0) // and // no pieces (enemy or friend) between king and rook
                // ((board.attacks_bb[opp_idx] & (@as(u64, 0x60) << 56)) == 0) // no enemy pieces attacks the square the king moves through
                ) {
                    movelist.addMove(types.Black_King_Castle);
                }
                // queen side castle
                if (((board.state.castling_rights & mboard.Castling_BQ) != 0) and // has castling rights
                    ((occupancy & (@as(u64, 0x0E) << 56)) == 0) // and // no pieces (enemy or friend) between king and rook
                // ((board.attacks_bb[opp_idx] & (@as(u64, 0x0C) << 56)) == 0) // no enemy pieces attacks the square the king moves through
                ) {
                    movelist.addMove(types.Black_Queen_Castle);
                }
            },
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
                        magic_index = (blockers *% ROOK_MAGIC[sq]) >> 52;
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
