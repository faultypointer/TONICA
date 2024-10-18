const std = @import("std");

const types = @import("types.zig");
const Move = types.Move;
const Square = types.Square;
const PieceType = types.PieceType;
const Side = types.Side;
const Board = @import("../board.zig").Board;

pub fn parseUciMove(uci_move: []const u8, board: *const Board) !Move {
    if (uci_move.len != 4 and uci_move.len != 5) return error.InvalidMove;

    const from = std.meta.stringToEnum(Square, uci_move[0..2]).?;
    const from_u6 = @as(u6, @intFromEnum(from));
    const to = std.meta.stringToEnum(Square, uci_move[2..4]).?;
    const to_u6 = @as(u6, @intFromEnum(to));
    const prom: ?u8 = if (uci_move.len == 5) uci_move[4] else null;
    const pcs = board.pieceAt(from, board.state.turn).?;
    var move = Move.init(from_u6, to_u6, pcs);

    if (board.pieceAt(to, board.state.turn.opponent())) |cap| {
        move.addCapturePiece(cap);
    }

    // castling
    if (pcs == PieceType.King) {
        if (from == Square.e1 and (to == Square.g1 or to == Square.c1)) {
            std.debug.assert(board.state.turn == Side.White);
            move.setCastlingFlag();
        } else if (from == Square.e8 and (to == Square.g8 or to == Square.c8)) {
            std.debug.assert(board.state.turn == Side.Black);
            move.setCastlingFlag();
        }
    }

    if (prom) |prom_byte| {
        const prom_type = switch (prom_byte) {
            'b' => PieceType.Bishop,
            'n' => PieceType.Knight,
            'r' => PieceType.Rook,
            'q' => PieceType.Queen,
            else => return error.InvalidPromotionPiece,
        };
        move.addPromotion(prom_type);
    }

    if (pcs == PieceType.Pawn) {
        // double step
        if (@abs(@as(i16, to_u6) - @as(i16, from_u6)) == 16) {
            move.setDoubleStepFlag();
        } else if (board.state.en_passant) |ep| {
            if (ep == to) { // if it was enpassant capture or not
                move.addCapturePiece(PieceType.Pawn);
                move.setEnPassantFlag();
            }
        }
    }
    return move;
}
