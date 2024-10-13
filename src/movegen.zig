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

        // promotions
        bb = pawn_bb;
        bb &= if (us == Side.White) RANK7 else RANK2; // only pawn that will promote
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            const to = if (us == Side.White) sq +% 8 else sq -% 8;
            if ((occupancy & (@as(u64, 1) << to)) != 0) continue;
            const promotion_types = [_]PieceType{
                PieceType.Bishop,
                PieceType.Knight,
                PieceType.Rook,
                PieceType.Queen,
            };
            for (promotion_types) |pt| {
                var move = Move.init(sq, to, PieceType.Pawn);
                move.addPromotion(pt);
                movelist.addMove(move);
            }
        }

        // promotion captures
        bb = pawn_bb;
        bb &= if (us == Side.White) RANK7 else RANK2; // only pawn that will promote
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            // not enpassant and  non promotion captures
            var possible_captures = nonsliderattack.PAWN_ATTACK[us_idx][sq] & board.side_bb[opp_idx];
            while (possible_captures != 0) {
                const to = bitboard.removeLS1B(&possible_captures);
                const to_sq: Square = @enumFromInt(to);
                const cap = board.pieceAt(to_sq, opp);
                const promotion_types = [_]PieceType{
                    PieceType.Bishop,
                    PieceType.Knight,
                    PieceType.Rook,
                    PieceType.Queen,
                };
                for (promotion_types) |pt| {
                    var move = Move.init(sq, to, PieceType.Pawn);
                    move.addPromotion(pt);
                    move.addCapturePiece(cap.?);
                    movelist.addMove(move);
                }
            }
        }

        // captures
        bb = pawn_bb;
        bb &= if (us == Side.White) ~RANK7 else ~RANK2; // remove pawn that will promote
        while (bb != 0) {
            const sq = bitboard.removeLS1B(&bb);
            // not enpassant and  non promotion captures
            var possible_captures = nonsliderattack.PAWN_ATTACK[us_idx][sq] & board.side_bb[opp_idx];
            while (possible_captures != 0) {
                const to = bitboard.removeLS1B(&possible_captures);
                var move = Move.init(sq, to, PieceType.Pawn);
                const to_sq: Square = @enumFromInt(to);
                const cap = board.pieceAt(to_sq, opp);
                move.addCapturePiece(cap.?);
                movelist.addMove(move);
            }

            // en_passant capture
            if (board.state.en_passant) |square| {
                const sq_idx = @intFromEnum(square);
                if (nonsliderattack.PAWN_ATTACK[us_idx][sq] & (@as(u64, 1) << sq_idx) != 0) {
                    var move = Move.init(sq, sq_idx, PieceType.Pawn);
                    move.addCapturePiece(PieceType.Pawn);
                    move.setEnPassantFlag();
                    movelist.addMove(move);
                }
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

    fn generateKingMoves(self: *const MovGen, board: Board, movelist: *MoveList) void {
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

        // castling moves
        switch (us) {
            .White => {
                // king side castle
                if (((board.state.castling_rights & mboard.Castling_WK) != 0) and // has castling rights
                    ((occupancy & 0x60) == 0) and // and // no pieces (enemy or friend) between king and rook
                    !(self.isSquareAttacked(board, Square.f1) or self.isSquareAttacked(board, Square.g1)))
                {
                    movelist.addMove(types.White_King_Castle);
                }
                // queen side castle
                if (((board.state.castling_rights & mboard.Castling_WQ) != 0) and // has castling rights
                    ((occupancy & 0x0E) == 0) and // no pieces (enemy or friend) between king and rook
                    !(self.isSquareAttacked(board, Square.d1) or self.isSquareAttacked(board, Square.c1)))
                {
                    movelist.addMove(types.White_Queen_Castle);
                }
            },
            .Black => {
                // king side castle
                if (((board.state.castling_rights & mboard.Castling_BK) != 0) and // has castling rights
                    ((occupancy & (@as(u64, 0x60) << 56)) == 0) and // no pieces (enemy or friend) between king and rook
                    !(self.isSquareAttacked(board, Square.f8) or self.isSquareAttacked(board, Square.g8)))
                {
                    movelist.addMove(types.Black_King_Castle);
                }
                // queen side castle
                if (((board.state.castling_rights & mboard.Castling_BQ) != 0) and // has castling rights
                    ((occupancy & (@as(u64, 0x0E) << 56)) == 0) and // no pieces (enemy or friend) between king and rook
                    !(self.isSquareAttacked(board, Square.d8) or self.isSquareAttacked(board, Square.c8)))
                {
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

    fn isSquareAttacked(self: *const MovGen, board: Board, square: Square) bool {
        const sq_idx = @as(usize, @intFromEnum(square));
        const opp_idx = @as(usize, @intFromEnum(board.state.turn.opponent()));
        const king_bb = nonsliderattack.KING_ATTACK[sq_idx];
        const knight_bb = nonsliderattack.KNIGHT_ATTACK[sq_idx];
        const pawn_bb = nonsliderattack.PAWN_ATTACK[opp_idx][sq_idx];

        const bishop_bb = self.getSliderAttackBB(board, square, PieceType.Bishop);
        const rook_bb = self.getSliderAttackBB(board, square, PieceType.Rook);
        const queen_bb = bishop_bb | rook_bb;

        return ((king_bb & board.piece_bb[opp_idx][@as(usize, @intFromEnum(PieceType.King))]) > 0) or
            ((knight_bb & board.piece_bb[opp_idx][@as(usize, @intFromEnum(PieceType.Knight))]) > 0) or
            ((pawn_bb & board.piece_bb[opp_idx][@as(usize, @intFromEnum(PieceType.Pawn))]) > 0) or
            ((bishop_bb & board.piece_bb[opp_idx][@as(usize, @intFromEnum(PieceType.Bishop))]) > 0) or
            ((rook_bb & board.piece_bb[opp_idx][@as(usize, @intFromEnum(PieceType.Rook))]) > 0) or
            ((queen_bb & board.piece_bb[opp_idx][@as(usize, @intFromEnum(PieceType.Queen))]) > 0);
    }

    fn getSliderAttackBB(self: *const MovGen, board: Board, square: Square, pt: PieceType) BitBoard {
        const sq_idx = @as(usize, @intFromEnum(square));
        const occupancy = board.side_bb[0] | board.side_bb[1];
        return switch (pt) {
            .Bishop => blk: {
                const blockers = occupancy & BISHOP_MASK[sq_idx];
                const magic_index = (blockers *% BISHOP_MAGIC[sq_idx]) >> 55;
                break :blk self.slider_attack.bishop[sq_idx][magic_index];
            },
            .Rook => blk: {
                const blockers = occupancy & ROOK_MASK[sq_idx];
                const magic_index = (blockers *% ROOK_MAGIC[sq_idx]) >> 52;
                break :blk self.slider_attack.rook[sq_idx][magic_index];
            },
            .Queen => blk: {
                var blockers = occupancy & BISHOP_MASK[sq_idx];
                var magic_index = (blockers *% BISHOP_MAGIC[sq_idx]) >> 55;
                const bishop_attack = self.slider_attack.bishop[sq_idx][magic_index];
                blockers = occupancy & ROOK_MASK[sq_idx];
                magic_index = (blockers *% ROOK_MAGIC[sq_idx]) >> 52;
                break :blk self.slider_attack.rook[sq_idx][magic_index] | bishop_attack;
            },
            else => unreachable,
        };
    }
};
