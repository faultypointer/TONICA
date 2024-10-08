const NUM_SIDE = @import("../board.zig").NUM_SIDE;
const NUM_SQUARE = @import("../board.zig").NUM_SQUARES;
const bitboard = @import("../board/bitboard.zig");
const BitBoard = bitboard.BitBoard;

const NOT_A_FILE = 0xFEFEFEFEFEFEFEFE;
const NOT_H_FILE = 0x7F7F7F7F7F7F7F7F;
const NOT_AB_FILE = 0xFCFCFCFCFCFCFCFC;
const NOT_GH_FILE = 0x3F3F3F3F3F3F3F3F;

pub const PAWN_ATTACK = blk: {
    var attack: [NUM_SIDE][NUM_SQUARE]BitBoard = undefined;
    for (0..NUM_SQUARE) |i| {
        attack[0][i] = 0;
        attack[1][i] = 0;
    }

    // Initialize white pawns
    var i: usize = 0;
    while (i < NUM_SQUARE - 8) : (i += 1) {
        var bb: BitBoard = 0;
        bitboard.setPieceAtLoc(&bb, i);
        if ((bb & NOT_A_FILE) > 0) attack[0][i] |= (bb << 7);
        if ((bb & NOT_H_FILE) > 0) attack[0][i] |= (bb << 9);
    }

    // TODO: Initialize black pawns (attack[1])
    i = 8;
    while (i < NUM_SQUARE) : (i += 1) {
        var bb: BitBoard = 0;
        bitboard.setPieceAtLoc(&bb, i);
        if ((bb & NOT_A_FILE) > 0) attack[1][i] |= (bb >> 9);
        if ((bb & NOT_H_FILE) > 0) attack[1][i] |= (bb >> 7);
    }

    break :blk attack;
};

pub const KING_ATTACK = blk: {
    var attack: [NUM_SQUARE]BitBoard = undefined;
    for (0..NUM_SQUARE) |i| {
        var bb: BitBoard = 0;
        bitboard.setPieceAtLoc(&bb, i);
        attack[i] = 0;
        attack[i] |= (bb << 8) | (bb >> 8);

        if ((bb & NOT_A_FILE) > 0) {
            attack[i] |= (bb >> 1) | (bb << 7) | (bb >> 9);
        }
        if ((bb & NOT_H_FILE) > 0) {
            attack[i] |= (bb << 1) | (bb >> 7) | (bb << 9);
        }
    }

    break :blk attack;
};

pub const KNIGHT_ATTACK = blk: {
    var attack: [NUM_SQUARE]BitBoard = undefined;
    for (0..NUM_SQUARE) |i| {
        var bb: BitBoard = 0;
        bitboard.setPieceAtLoc(&bb, i);
        attack[i] = 0;
        if ((bb & NOT_A_FILE) > 0) {
            attack[i] |= (bb << 15) | (bb >> 17);
            if ((bb & NOT_AB_FILE) > 0) {
                attack[i] |= (bb << 6) | (bb >> 10);
            }
        }
        if ((bb & NOT_H_FILE) > 0) {
            attack[i] |= (bb << 17) | (bb >> 15);
            if ((bb & NOT_GH_FILE) > 0) {
                attack[i] |= (bb << 10) | (bb >> 6);
            }
        }
    }
    break :blk attack;
};
