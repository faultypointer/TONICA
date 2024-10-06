const std = @import("std");

const BitBoard = @import("board/bitboard.zig").BitBoard;
const zobrist = @import("board/zobrist.zig");

const types = @import("board/types.zig");
const Side = types.Side;
const PieceType = types.PieceType;
const Square = types.Square;
const Move = types.Move;

const StateStack = @import("board/state_stack.zig").StateStack;

// castling rights
// castling is represented by 4 leftmost bits of u8
pub const Castling_WK: u8 = 0b00000001;
pub const Castling_WQ: u8 = 0b00000010;
pub const Castling_BK: u8 = 0b00000100;
pub const Castling_BQ: u8 = 0b00001000;

pub const NUM_SIDE = 2;
pub const NUM_PIECE_TYPE = 6;
pub const NUM_SQUARES = 64;

pub const STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

pub const BState = struct {
    turn: Side,
    castling_rights: u8,
    en_passant: ?Square,
    half_move_clock: u8,
    full_move_clock: u16,
    next_move: ?Move = null,
    key: u64,
};

pub const Board = struct {
    piece_bb: [NUM_SIDE][NUM_PIECE_TYPE]BitBoard,
    side_bb: [NUM_SIDE]BitBoard,
    state: BState,
    state_stack: StateStack = .{},

    pub fn init() Board {
        return Board.readFromFen(STARTING_FEN);
    }

    fn emptyBoard() Board {
        var piece_bb: [NUM_SIDE][NUM_PIECE_TYPE]BitBoard = undefined;
        for (0..NUM_SIDE) |j| {
            for (0..NUM_PIECE_TYPE) |i| {
                piece_bb[j][i] = 0;
            }
        }
        const side_bb = [_]BitBoard{ 0, 0 };
        const state = BState{
            .turn = Side.White,
            .castling_rights = 0,
            .en_passant = null,
            .half_move_clock = 0,
            .full_move_clock = 0,
            .key = 0,
        };
        return .{
            .piece_bb = piece_bb,
            .side_bb = side_bb,
            .state = state,
        };
    }
    pub fn readFromFen(fen: []const u8) Board {
        var board = Board.emptyBoard();
        var fen_iter = std.mem.splitScalar(u8, fen, ' ');
        board.readFenPosition(fen_iter.next().?);
        board.readFenSideToMove(fen_iter.next().?);
        board.readFenCastling(fen_iter.next().?);
        board.readFenEnPassant(fen_iter.next().?);
        if (fen_iter.next()) |half_move| {
            board.readFenMove(half_move, true);
            board.readFenMove(fen_iter.next() orelse "1", false);
        } else {
            board.state.half_move_clock = 0;
            board.state.full_move_clock = 1;
        }
        zobrist.initZobristKey(&board);
        return board;
    }

    fn readFenPosition(board: *Board, fen_position: []const u8) void {
        var rank_iter = std.mem.splitScalar(u8, fen_position, '/');
        var count_rank: u8 = 0;
        while (rank_iter.next()) |rank| : (count_rank += 1) {
            var count_file: u8 = 0;
            for (rank) |piece| {
                var piece_type: ?PieceType = null;
                var side: ?Side = null;
                switch (piece) {
                    'K' => {
                        piece_type = PieceType.King;
                        side = Side.White;
                    },
                    'Q' => {
                        piece_type = PieceType.Queen;
                        side = Side.White;
                    },
                    'R' => {
                        piece_type = PieceType.Rook;
                        side = Side.White;
                    },
                    'B' => {
                        piece_type = PieceType.Bishop;
                        side = Side.White;
                    },
                    'N' => {
                        piece_type = PieceType.Knight;
                        side = Side.White;
                    },
                    'P' => {
                        piece_type = PieceType.Pawn;
                        side = Side.White;
                    },
                    'k' => {
                        piece_type = PieceType.King;
                        side = Side.Black;
                    },
                    'q' => {
                        piece_type = PieceType.Queen;
                        side = Side.Black;
                    },
                    'r' => {
                        piece_type = PieceType.Rook;
                        side = Side.Black;
                    },
                    'b' => {
                        piece_type = PieceType.Bishop;
                        side = Side.Black;
                    },
                    'n' => {
                        piece_type = PieceType.Knight;
                        side = Side.Black;
                    },
                    'p' => {
                        piece_type = PieceType.Pawn;
                        side = Side.Black;
                    },
                    '1'...'8' => {
                        count_file += piece - '0';
                    },
                    else => std.debug.panic("unknown piece type ({c}) in fen: {s}", .{ piece, fen_position }),
                }
                if (piece_type) |exists| {
                    const side_idx: usize = @intFromEnum(side.?);
                    const piece_idx: usize = @intFromEnum(exists);
                    const shift: u6 = @truncate((7 - count_rank) * 8 + count_file);
                    const one: u64 = 1;
                    board.piece_bb[side_idx][piece_idx] |= one << shift;
                    count_file += 1;
                    // std.debug.print("type:{any}\tcolor: {any}\tshifted: {}\n", .{ exists, side.?, shift });
                }
                if (count_file >= 8) {
                    break;
                }
            }
        }
        if (count_rank != 8) {
            std.debug.panic("invalid fen position feild: {s}", .{fen_position});
        }
        for (board.piece_bb, &board.side_bb) |pieces, *side| {
            for (pieces) |piece| {
                side.* |= piece;
            }
        }
    }

    fn readFenSideToMove(board: *Board, fen_stm: []const u8) void {
        if (fen_stm.len != 1) {
            std.debug.panic("invalid fen side to move: {s}\n", .{fen_stm});
        }
        if (fen_stm[0] == 'w') {
            board.state.turn = Side.White;
        } else if (fen_stm[0] == 'b') {
            board.state.turn = Side.Black;
        } else {
            std.debug.panic("invalid fen side to move: {s}\n", .{fen_stm});
        }
    }

    fn readFenCastling(board: *Board, fen_castling: []const u8) void {
        if (fen_castling.len < 1 or fen_castling.len > 4) {
            std.debug.panic("invalid fen castling: {s}\n", .{fen_castling});
        }
        board.state.castling_rights = 0;
        if (fen_castling[0] == '-') {
            return;
        }
        for (fen_castling) |char| {
            switch (char) {
                'K' => board.state.castling_rights |= Castling_WK,
                'Q' => board.state.castling_rights |= Castling_WQ,
                'k' => board.state.castling_rights |= Castling_BK,
                'q' => board.state.castling_rights |= Castling_BQ,
                else => std.debug.panic("invalid fen casling: {s}\n", .{fen_castling}),
            }
        }
    }

    fn readFenEnPassant(board: *Board, fen_en: []const u8) void {
        if (fen_en.len < 1 or fen_en.len > 2) {
            std.debug.panic("invalid fen en-passant square: {s}\n", .{fen_en});
        }

        if (fen_en[0] == '-') {
            board.state.en_passant = null;
            return;
        }

        var square: u8 = 0;
        switch (fen_en[1]) {
            '3'...'6' => square += 8 * (fen_en[1] - '1'),
            else => std.debug.panic("invalid fen en-passant square: {s}\n", .{fen_en}),
        }

        switch (fen_en[0]) {
            'a'...'h' => square += fen_en[0] - 'a',
            else => std.debug.panic("invalid fen en-passant square: {s}\n", .{fen_en}),
        }
        board.state.en_passant = @enumFromInt(square);
    }

    fn readFenMove(board: *Board, fen_half: []const u8, half: bool) void {
        if (fen_half.len < 1) {
            std.debug.panic("invalid fen half move clock: {s}\n", .{fen_half});
        }
        var move_clock: u16 = 0;
        for (fen_half) |digit| {
            std.debug.assert(std.ascii.isDigit(digit));
            move_clock *= 10;
            move_clock += digit - '0';
        }
        if (half) {
            board.state.half_move_clock = @intCast(move_clock);
        } else {
            board.state.full_move_clock = move_clock;
        }
    }
};

test "readFenPosition valid" {
    var board = Board.emptyBoard();

    // Test 1: Valid FEN string for the initial chess position
    board.readFenPosition("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR");

    // Check bitboards for initial position
    // Black pieces
    // std.debug.print("{X}\n", .{board.piece_bb[1][4].board});
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Rook)] == 0x8100000000000000);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Knight)] == 0x4200000000000000);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Bishop)] == 0x2400000000000000);
    try std.testing.expectEqual(0x0800000000000000, board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Queen)]);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.King)] == 0x1000000000000000);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Pawn)] == 0x00ff000000000000);
    try std.testing.expectEqual(0xffff000000000000, board.side_bb[@intFromEnum(Side.Black)]);

    // White pieces
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Rook)] == 0x0000000000000081);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Knight)] == 0x0000000000000042);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Bishop)] == 0x0000000000000024);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Queen)] == 0x0000000000000008);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.King)] == 0x0000000000000010);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Pawn)] == 0x000000000000ff00);
    try std.testing.expectEqual(0xffff, board.side_bb[@intFromEnum(Side.White)]);

    // Test 2: Valid FEN string for a end-game position
    board = Board.emptyBoard(); // Reset the board
    board.readFenPosition("8/b1kpq3/2P1P3/2n5/1R2Q3/8/3K4/8");

    // Black pieces
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Rook)], 0);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Knight)], 0x0000000400000000);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Bishop)], 0x0001000000000000);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Queen)], 0x0010000000000000);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.King)], 0x0004000000000000);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Pawn)], 0x0008000000000000);

    // White pieces
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Rook)], 0x0000000002000000);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Knight)], 0);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Bishop)], 0);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Queen)], 0x0000000010000000);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.King)], 0x0000000000000800);
    try std.testing.expectEqual(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Pawn)], 0x0000140000000000);
}

test "readFenSideToMove" {
    var board = Board.emptyBoard();
    board.readFenSideToMove("w");
    try std.testing.expectEqual(board.state.turn, Side.White);

    board.readFenSideToMove("b");
    try std.testing.expectEqual(board.state.turn, Side.Black);
}

test "readFenCastling" {
    var board = Board.emptyBoard();

    board.readFenCastling("-");
    try std.testing.expectEqual(0, board.state.castling_rights);

    board.readFenCastling("K");
    try std.testing.expectEqual(0b00000001, board.state.castling_rights);

    board.readFenCastling("KQ");
    try std.testing.expectEqual(0b00000011, board.state.castling_rights);

    board.readFenCastling("q");
    try std.testing.expectEqual(0b00001000, board.state.castling_rights);

    board.readFenCastling("Qk");
    try std.testing.expectEqual(0b00000110, board.state.castling_rights);

    board.readFenCastling("KQkq");
    try std.testing.expectEqual(0b00001111, board.state.castling_rights);
}

test "readFenEnPassant" {
    var board = Board.emptyBoard();

    board.readFenEnPassant("-");
    try std.testing.expect(board.state.en_passant == null);
    const squares = [_][]const u8{
        // "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
        // "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
        "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
        "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
        "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
        "a6", "b6", "c6", "d6", "e6", "f6", "g6",
        "h6",
        // "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
        // "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
    };
    for (squares, 16..) |sq, i| {
        board.readFenEnPassant(sq);
        const expected: Square = @enumFromInt(i);
        try std.testing.expectEqual(expected, board.state.en_passant.?);
    }
}

test "readFenMove" {
    var board = Board.emptyBoard();

    board.readFenMove("43", true);
    try std.testing.expectEqual(43, board.state.half_move_clock);

    board.readFenMove("03", true);
    try std.testing.expectEqual(3, board.state.half_move_clock);

    board.readFenMove("0", false);
    try std.testing.expectEqual(0, board.state.full_move_clock);

    board.readFenMove("4", false);
    try std.testing.expectEqual(4, board.state.full_move_clock);
}

test "readFromFen" {
    const board = Board.readFromFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Rook)] == 0x8100000000000000);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Knight)] == 0x4200000000000000);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Bishop)] == 0x2400000000000000);
    try std.testing.expectEqual(0x0800000000000000, board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Queen)]);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.King)] == 0x1000000000000000);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.Black)][@intFromEnum(PieceType.Pawn)] == 0x00ff000000000000);

    // White pieces
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Rook)] == 0x0000000000000081);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Knight)] == 0x0000000000000042);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Bishop)] == 0x0000000000000024);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Queen)] == 0x0000000000000008);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.King)] == 0x0000000000000010);
    try std.testing.expect(board.piece_bb[@intFromEnum(Side.White)][@intFromEnum(PieceType.Pawn)] == 0x000000000000ff00);

    try std.testing.expectEqual(0, board.state.half_move_clock);
    try std.testing.expectEqual(Side.White, board.state.turn);
    try std.testing.expectEqual(0b00001111, board.state.castling_rights);
    try std.testing.expectEqual(1, board.state.full_move_clock);
    try std.testing.expect(board.state.en_passant == null);
}

// zobrist testing ------------------------------------------------------------------------
// yay ------------------------------------------------------------------------------------
test "zobrist initZobristKey" {
    const board = Board.init();
    const expected = 0xE7A6167E282C7201 ^ 0x317AFB4107F788D3 ^ 0x4B235F6B9172C839 ^ 0xB1F49FEA387D45D1 ^
        0x85DDD8ABD2FC435F ^ 0x24BCBC736277D7C3 ^ 0x855DE6528BF67EFB ^ 0xAF739F9F79DBDB97 ^
        0xCE9FBF4C3A721D00 ^ 0x3438D5E6E96BC405 ^ 0x7DA23D707E90C1DB ^ 0xF0605D4C82AC3129 ^
        0x2A9203832E9E8A8D ^ 0x16313560D8BC84CE ^ 0x21257FA9660B1186 ^ 0x65924767BFA36402 ^
        0x54B11937A8886E6C ^ 0x7711134EF4E14493 ^ 0xCE9385C80B7DD1A5 ^ 0x2CEE645A2936BB50 ^
        0x1067593163606DFC ^ 0xFF947D4B5F6C4A4A ^ 0x9A415DE43380EC14 ^ 0x37B59B894C9624F3 ^
        0xF334F446B4ED0209 ^ 0xA46E81289F031C70 ^ 0x5E7C93F7A4EA3A7D ^ 0xE628F22BA305A1ED ^
        0xF313072B0907BA1F ^ 0xFAE8EFA7C13495E2 ^ 0xFE9BE7FE9C025FBE ^ 0x8F62C7BC8EDA9A20 ^
        0x3B7CF67F6FB9BCBB ^ 0x5ED6CFE1AB8C3CD2;
    try std.testing.expectEqual(expected, board.state.key);

    const board_with_enpassant = Board.readFromFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq d6 0 1");
    const expected_enpassant = expected ^ 0xA115FFAF3A33B87F;
    try std.testing.expectEqual(expected_enpassant, board_with_enpassant.state.key);
}
