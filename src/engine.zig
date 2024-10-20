const std = @import("std");
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const SplitIter = std.mem.SplitIterator(u8, .sequence);

const Board = @import("board.zig").Board;
const MovGen = @import("movegen.zig").MovGen;
const sear = @import("search.zig");
const eval = @import("evaluation.zig");
const SearchParam = sear.SearchParams;
const parse = @import("board/parse.zig");

const UciCommands = enum {
    uci,
    isready,
    ucinewgame,
    position,
    go,
    quit,
};
pub const Engine = struct {
    board: Board,
    mg: MovGen,
    depth: u8 = 8,

    pub fn init() Engine {
        const eng = Engine{
            .board = Board.init(),
            .mg = MovGen.init(),
        };
        return eng;
    }

    pub fn run(self: *Engine) !void {
        var buffer: [1024]u8 = undefined;
        var buffer_fbs = std.io.fixedBufferStream(&buffer);
        const writer = buffer_fbs.writer();
        while (true) {
            try stdin.streamUntilDelimiter(writer, '\n', buffer.len);
            const command = buffer_fbs.getWritten();
            var tokens = std.mem.split(u8, command, " ");
            const cmd: UciCommands = std.meta.stringToEnum(UciCommands, tokens.first()).?;
            try switch (cmd) {
                .uci => try self.handleUci(),
                .isready => try self.handleIsReady(),
                .ucinewgame => self.handleUciNewGame(),
                .position => try self.handlePosition(&tokens),
                .go => self.handleGo(),
                .quit => break,
            };
            buffer_fbs.reset();
        }
    }

    // ====================================== UCI COMMANDS =======================================
    fn handleUci(_: Engine) !void {
        try stdout.print("id name tonica\n", .{});
        try stdout.print("id author faultypointer\n", .{});
        try stdout.print("uciok\n", .{});
    }

    fn handleIsReady(_: Engine) !void {
        try stdout.print("readyok\n", .{});
    }

    fn handleUciNewGame(self: *Engine) void {
        self.board = Board.init();
    }

    fn handlePosition(self: *Engine, tokens: *SplitIter) !void {
        const opt = tokens.next().?;
        if (std.mem.eql(u8, opt, "fen")) {
            var fen_buff: [100]u8 = undefined;
            var fen_fbs = std.io.fixedBufferStream(&fen_buff);
            const fen_writer = fen_fbs.writer();
            for (0..6) |_| {
                try fen_writer.print("{s} ", .{tokens.next().?});
            }
            const fen_str = fen_fbs.getWritten();
            self.board = Board.readFromFen(fen_str);
            _ = tokens.next(); // skip "moves"
            while (tokens.next()) |uci_move| {
                const move = try parse.parseUciMove(uci_move, &self.board);
                self.board.makeMove(move);
                // move.debugPrint();
                // board.printBoard();
            }
        } else if (std.mem.eql(u8, opt, "startpos")) {
            self.board = Board.init();
            _ = tokens.next(); // skip "moves"
            while (tokens.next()) |uci_move| {
                const move = try parse.parseUciMove(uci_move, &self.board);
                self.board.makeMove(move);
                // move.debugPrint();
                // board.printBoard();
            }
        } else {
            std.debug.panic("unknown uci position option: {s}\n", .{opt});
        }
    }

    fn handleGo(self: *Engine) !void {
        const params = SearchParam{
            .board = &self.board,
            .movgen = &self.mg,
            .depth = 5,
        };

        var move_string = [_]u8{ 0, 0, 0, 0, 0 };

        const res = sear.search(params);
        if (res.best_move.data == 0) {
            try stdout.print("bestmove 0000\n", .{});
        }
        // std.debug.print("total node searched: {}\n", .{res.nodes_searched});
        const has_promo = res.best_move.toUciString(&move_string);
        try stdout.print("bestmove {s}\n", .{if (has_promo) move_string[0..] else move_string[0..4]});
    }

    pub fn testEvaluation(self: *Engine) !void {
        var buffer: [10]u8 = undefined;
        var buffer_fbs = std.io.fixedBufferStream(&buffer);
        const writer = buffer_fbs.writer();
        while (true) {
            self.board.state.print();
            self.board.printBoard();
            for (0..5) |i| {
                const params = SearchParam{
                    .board = &self.board,
                    .movgen = &self.mg,
                    .depth = @truncate(i),
                };
                var result = sear.SearchResult{
                    .best_score = -0xffffff,
                    .best_move = .{
                        .data = 0,
                    },
                    .nodes_searched = 0,
                    .time = std.time.Timer.start() catch unreachable,
                };
                std.debug.print("Current eval at depth {}: {}\n", .{ i, sear.alphabeta(params, &result, -0xffffff, 0xffffff, params.depth) });
            }
            try stdin.streamUntilDelimiter(writer, '\n', buffer.len);
            const movestr = buffer_fbs.getWritten();
            buffer_fbs.reset();
            const move = try parse.parseUciMove(movestr, &self.board);
            std.debug.print("Making move: \n", .{});
            move.debugPrint();
            self.board.makeMove(move);
            std.debug.print("Searching for move: ", .{});
            const params = SearchParam{
                .board = &self.board,
                .movgen = &self.mg,
                .time = 10000000000,
                .depth = 5,
            };
            const res = sear.search(params);
            self.board.makeMove(res.best_move);
        }
    }
};
