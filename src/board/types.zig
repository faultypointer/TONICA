const std = @import("std");

// flags store the following information
// 00000000
// ||||||||-> [en passant]: is set if an en passant capture becomes possible because of this Move
// |||||||--> [Capture]: set if the move is capture
// ||||||---> [Promotion]: set if the move is a Promotion
// ||+++----> [Promotion type]: if the move is Promotion these 3 bits denote the type the pawn
//                              promotes to according to PieceType enum
//                              Bishop -> 001
//                              Knight -> 010
//                              Rook   -> 011
//                              Queen  -> 100
pub const Move = struct {
    from: Square,
    to: Square,
    flags: u8,

    pub fn isEnpassant(self: Move) bool {
        return (self.flags & 0b00000001) != 0;
    }

    pub fn isCapture(self: Move) bool {
        return (self.flags & 0b00000010) != 0;
    }

    pub fn isPromotion(self: Move) bool {
        return (self.flags & 0b00000100) != 0;
    }

    pub fn promotionType(self: Move) PieceType {
        const promotion_bits: u3 = @truncate(self.flags >> 3);
        return @enumFromInt(promotion_bits);
    }
};

test "isEnpassant" {
    var move = Move{
        .from = Square.a1,
        .to = Square.c2,
        .flags = 0b00110101,
    };

    try std.testing.expect(move.isEnpassant());

    move.flags ^= 1;

    try std.testing.expect(!move.isEnpassant());
}

test "isCapture" {
    var move = Move{
        .from = Square.a1,
        .to = Square.c2,
        .flags = 0b00110111,
    };

    try std.testing.expect(move.isCapture());

    move.flags ^= 2;

    try std.testing.expect(!move.isCapture());
}

test "isPromotion" {
    var move = Move{
        .from = Square.a1,
        .to = Square.c2,
        .flags = 0b00110100,
    };

    try std.testing.expect(move.isPromotion());

    move.flags ^= 4;

    try std.testing.expect(!move.isPromotion());
}

test "promotionType" {
    var move = Move{
        .from = Square.e3,
        .to = Square.f4,
        .flags = 0b00001100,
    };

    try std.testing.expectEqual(PieceType.Bishop, move.promotionType());

    move.flags = 0b00010100;
    try std.testing.expectEqual(PieceType.Knight, move.promotionType());

    move.flags = 0b00011100;
    try std.testing.expectEqual(PieceType.Rook, move.promotionType());

    move.flags = 0b00100100;
    try std.testing.expectEqual(PieceType.Queen, move.promotionType());
}

pub const Side = enum {
    White,
    Black,
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
