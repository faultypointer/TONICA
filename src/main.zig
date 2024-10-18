const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const BitBoard = @import("board/bitboard.zig").BitBoard;
const KNIGHT_ATTACK = @import("movegen/nonsliderattack.zig").KNIGHT_ATTACK;
const Square = @import("board/types.zig").Square;
const movegen = @import("movegen.zig");
const MovGen = movegen.MovGen;
const mboard = @import("board.zig");
const Board = mboard.Board;
const Move = @import("board/types.zig").Move;
const PieceType = @import("board/types.zig").PieceType;
const MoveType = movegen.MoveType;
const perft = @import("movegen/perft.zig");
const eval = @import("evaluation.zig");
const sear = @import("search.zig");
const parse = @import("board/parse.zig");
const SearchParam = sear.SearchParams;
const SplitIter = std.mem.SplitIterator(u8, .sequence);

pub fn main() !void {
    var board: Board = Board.init();
    const movgen = MovGen.init();
    var buffer: [1024]u8 = undefined;
    var buffer_fbs = std.io.fixedBufferStream(&buffer);
    const writer = buffer_fbs.writer();
    while (true) {
        try stdin.streamUntilDelimiter(writer, '\n', buffer.len);
        const command = buffer_fbs.getWritten();
        var tokens = std.mem.split(u8, command, " ");
        const cmd: UciCommands = std.meta.stringToEnum(UciCommands, tokens.first()).?;
        try switch (cmd) {
            .uci => try handleUci(),
            .isready => try handleIsReady(),
            .ucinewgame => handleUciNewGame(&board),
            .position => try handlePosition(&board, &tokens),
            .go => handleGo(&board, &movgen),
            .quit => break,
        };
        buffer_fbs.reset();
    }
}

const UciCommands = enum {
    uci,
    isready,
    ucinewgame,
    position,
    go,
    quit,
};

fn handleUci() !void {
    try stdout.print("id name tonica\n", .{});
    try stdout.print("id author faultypointer\n", .{});
    try stdout.print("uciok\n", .{});
}

fn handleIsReady() !void {
    try stdout.print("readyok\n", .{});
}

fn handleUciNewGame(board: *Board) void {
    board.* = Board.init();
}

fn handlePosition(board: *Board, tokens: *SplitIter) !void {
    const opt = tokens.next().?;
    if (std.mem.eql(u8, opt, "fen")) {
        var fen_buff: [100]u8 = undefined;
        var fen_fbs = std.io.fixedBufferStream(&fen_buff);
        const fen_writer = fen_fbs.writer();
        for (0..6) |_| {
            try fen_writer.print("{s} ", .{tokens.next().?});
        }
        const fen_str = fen_fbs.getWritten();
        board.* = Board.readFromFen(fen_str);
        _ = tokens.next(); // skip "moves"
        while (tokens.next()) |uci_move| {
            const move = try parse.parseUciMove(uci_move, board);
            board.makeMove(move);
            move.debugPrint();
            board.printBoard();
        }
    } else if (std.mem.eql(u8, opt, "startpos")) {
        board.* = Board.init();
        _ = tokens.next(); // skip "moves"
        while (tokens.next()) |uci_move| {
            const move = try parse.parseUciMove(uci_move, board);
            board.makeMove(move);
            move.debugPrint();
            board.printBoard();
        }
    } else {
        std.debug.panic("unknown uci position option: {s}\n", .{opt});
    }
}

fn handleGo(board: *Board, mg: *const MovGen) !void {
    const params = SearchParam{
        .board = board,
        .movgen = mg,
        // .depth = 10,
        .node = 100000000,
    };

    var move_string = [_]u8{ 0, 0, 0, 0, 0 };

    const res = sear.search(params);
    if (res.best_move.data == 0) {
        try stdout.print("bestmove 0000\n", .{});
    }
    std.debug.print("total node searched: {}\n", .{res.nodes_searched});
    const has_promo = res.best_move.toUciString(&move_string);
    try stdout.print("bestmove {s}\n", .{if (has_promo) move_string[0..] else move_string[0..4]});
}
