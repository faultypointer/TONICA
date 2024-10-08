const std = @import("std");
const math = std.math;
const Square = @import("types.zig").Square;
pub const BitBoard = u64;

const MAX64 = 0xffffffffffffffff;

// removes the least significat 1 Bit from the bitboard and returns it position
pub fn removeLS1B(bb: *BitBoard) u6 {
    std.debug.assert(bb.* != 0);
    const two = MAX64 - bb.* + 1;
    const loc = math.log2_int(u64, bb.* & two);
    bb.* &= bb.* - 1;
    return loc;
}

pub fn removePieceFromSquare(bb: *BitBoard, sq: Square) void {
    std.debug.assert((bb.* & (1 << @intFromEnum(sq))) != 0);
    bb.* ^= (1 << @intFromEnum(sq));
}

pub fn addPieceToSquare(bb: *BitBoard, sq: Square) void {
    std.debug.assert((bb.* & (1 << @intFromEnum(sq))) == 0);
    bb.* |= (1 << @intFromEnum(sq));
}

pub fn setPieceAtLoc(bb: *BitBoard, loc: u6) void {
    bb.* |= (1 << loc);
}

test "removesLSB1" {
    var a: u64 = 0b100;
    try std.testing.expectEqual(2, removeLS1B(&a));
    try std.testing.expectEqual(0, a);
}
