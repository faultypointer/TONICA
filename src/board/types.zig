const std = @import("std");
const testing = std.testing;

// data store the following information
// |---------------------------------------------------------------------------|
// | 0000 000(7) | 0  | 00 | 0  | 0  | 0  | 0  | 000 | 000 | 0000 00 | 00 0000 |
// | not using   | PF | PT | CS | CF | EN | DS | CAP | PCE | TO      | FROM    |
// |---------------------------------------------------------------------------|
//               |                |
//      PF       | Promotion Flag | set if the move is a promotion
//      PT       | Promotion Type | type of piece promoted to
//      CS       | Castling       | if the move is Castling
//      CF       | Captured Flag  | if the move is a capture
//      EN       | Enpassant      | if the move is enpassant capture
//      DS       | Double step    | if the move is a double push by pawn
//      CAP      | Captured piece | the type of piece captured if any
//      PCE      | Piece          | the type of the piece that made the move
//      TO       | TO Square      | which square the piece moved to
//      FROM     | From Square    | which square the piece moved from
//

// some flags to get what i want
const FROM_FLAG = 0b111111;
const TO_FLAG = FROM_FLAG << 6;
const PIECE_FLAG = 0b111 << 12;
const CAP_FLAG = PIECE_FLAG << 3;
const DS_FLAG = 1 << 18;
const EN_FLAG = DS_FLAG << 1;
const CF_FLAG = EN_FLAG << 1;
const CS_FLAG = CF_FLAG << 1;
const PT_FLAG = 0b11 << 22;
const PF_FLAG = 1 << 24;

pub const White_King_Castle = Move{ .data = 0b00000000001000000101000110000100 };
pub const White_Queen_Castle = Move{ .data = 0b00000000001000000101000010000100 };
pub const Black_King_Castle = Move{ .data = 0b00000000001000000101111110111100 };
pub const Black_Queen_Castle = Move{ .data = 0b00000000001000000101111010111100 };
pub const Move = struct {
    data: u32,

    pub fn init(from: u6, to: u6, pce: PieceType) Move {
        var data: u32 = 0;
        data |= from;
        data |= (@as(u32, to) << 6);
        data |= (@as(u32, @intFromEnum(pce)) << 12);
        return Move{ .data = data };
    }
    pub fn addCapturePiece(self: *Move, cap: PieceType) void {
        self.data |= (@as(u32, 1) << 20);
        self.data |= @as(u32, @intFromEnum(cap)) << 15;
    }
    pub fn fromSquare(self: Move) Square {
        const sq: u6 = @truncate(self.data & FROM_FLAG);
        return @enumFromInt(sq);
    }

    pub fn toSquare(self: Move) Square {
        const sq: u6 = @truncate((self.data & TO_FLAG) >> 6);
        return @enumFromInt(sq);
    }

    pub fn piece(self: Move) PieceType {
        const p: u3 = @truncate((self.data & PIECE_FLAG) >> 12);
        return @enumFromInt(p);
    }

    pub fn capturedPiece(self: Move) PieceType {
        const p: u3 = @truncate((self.data & CAP_FLAG) >> 15);
        return @enumFromInt(p);
    }

    pub fn isDoubleStep(self: Move) bool {
        return (self.data & DS_FLAG) != 0;
    }

    pub fn isEnpassant(self: Move) bool {
        return (self.data & EN_FLAG) != 0;
    }

    pub fn isCapture(self: Move) bool {
        return (self.data & CF_FLAG) != 0;
    }

    pub fn isCastling(self: Move) bool {
        return (self.data & CS_FLAG) != 0;
    }

    pub fn isPromotion(self: Move) bool {
        return (self.data & PF_FLAG) != 0;
    }

    pub fn promotionType(self: Move) PieceType {
        var promotion_bits: u3 = @truncate((self.data & PT_FLAG) >> 22);
        promotion_bits += @intFromEnum(PieceType.Bishop);
        return @enumFromInt(promotion_bits);
    }
};

pub const MoveList = struct {
    moves: [100]Move, // there is no way a position has more than 100 possible moves right??
    len: usize,

    pub fn init() MoveList {
        var movelist = MoveList{
            .moves = undefined,
            .len = 0,
        };
        for (0..100) |i| {
            movelist.moves[i] = Move{ .data = 0 };
        }
        movelist.len = 0;
        return movelist;
    }
    pub fn addMove(self: *MoveList, move: Move) void {
        self.moves[self.len] = move;
        self.len += 1;
    }
};

pub const Side = enum {
    White,
    Black,

    pub fn opponent(self: Side) Side {
        return if (self == .White) Side.Black else Side.White;
    }
};

pub const PieceType = enum(u3) {
    Pawn,
    Bishop,
    Knight,
    Rook,
    Queen,
    King,
    None,
};

pub const Square = enum(u6) {
    a1,
    b1,
    c1,
    d1,
    e1,
    f1,
    g1,
    h1,
    a2,
    b2,
    c2,
    d2,
    e2,
    f2,
    g2,
    h2,
    a3,
    b3,
    c3,
    d3,
    e3,
    f3,
    g3,
    h3,
    a4,
    b4,
    c4,
    d4,
    e4,
    f4,
    g4,
    h4,
    a5,
    b5,
    c5,
    d5,
    e5,
    f5,
    g5,
    h5,
    a6,
    b6,
    c6,
    d6,
    e6,
    f6,
    g6,
    h6,
    a7,
    b7,
    c7,
    d7,
    e7,
    f7,
    g7,
    h7,
    a8,
    b8,
    c8,
    d8,
    e8,
    f8,
    g8,
    h8,
};

test "Move.fromSquare" {
    const move = Move{ .data = 26 };
    try std.testing.expectEqual(Square.c4, move.fromSquare());
}

test "Move.toSquare" {
    const move = Move{ .data = 26 << 6 };
    try std.testing.expectEqual(Square.c4, move.toSquare());
}

test "Move.piece" {
    const move = Move{ .data = 4 << 12 };
    try std.testing.expectEqual(PieceType.Queen, move.piece());
}

test "Move.capturedPiece" {
    const move = Move{ .data = 4 << 15 };
    try std.testing.expectEqual(PieceType.Queen, move.capturedPiece());
}

test "Move.promotionType" {
    const move = Move{ .data = 3 << 22 };
    try std.testing.expectEqual(PieceType.Queen, move.promotionType());
}
