const std = @import("std");
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const SplitIter = std.mem.SplitIterator(u8, .sequence);

const Board = @import("board.zig").Board;
const MovGen = @import("movegen.zig").MovGen;
const sear = @import("search.zig");
const eval = @import("evaluation.zig");
const parse = @import("board/parse.zig");

const UciCommands = enum {
    uci,
    isready,
    ucinewgame,
    position,
    go,
    quit,

    // debug commands
    eval,
    search,
    play,
    // bench commands
    searchben,
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
                .go => self.handleGo(&tokens),
                .quit => break,
                // debug
                .eval => self.debugHandleEval(),
                .search => self.debugHandleSearch(),
                .play => self.debugPlay(),
                // bench
                .searchben => self.benchSearch(),
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

    fn handleGo(self: *Engine, tokens: *SplitIter) !void {
        // const params = SearchParam{
        //     .board = &self.board,
        //     .movgen = &self.mg,
        //     .depth = 5,
        // };
        _ = tokens;
        var move_string = [_]u8{ 0, 0, 0, 0, 0 };

        const res = sear.search(&self.board, &self.mg, 7);
        if (res.best_move.data == 0) {
            try stdout.print("bestmove 0000\n", .{});
        }
        const has_promo = res.best_move.toUciString(&move_string);
        try stdout.print("bestmove {s}\n", .{if (has_promo) move_string[0..] else move_string[0..4]});
    }

    // debug commands
    fn debugHandleEval(self: *Engine) !void {
        const evalScore = eval.evaluatePosition(&self.board);
        self.board.printBoard();
        try stdout.print("Score: {} for side: {any}\n", .{ evalScore, self.board.state.turn });
    }

    fn debugHandleSearch(self: *Engine) !void {
        for (1..6) |depth| {
            var move_string = [_]u8{ 0, 0, 0, 0, 0 };

            const res = sear.search(&self.board, &self.mg, @intCast(depth));
            if (res.best_move.data == 0) {
                try stdout.print("bestmove 0000 at depth: {}\n", .{depth});
                continue;
            }
            // std.debug.print("total node searched: {}\n", .{res.nodes_searched});
            const has_promo = res.best_move.toUciString(&move_string);
            try stdout.print("bestmove {s} at depth: {} score: {}\n", .{ if (has_promo) move_string[0..] else move_string[0..4], depth, res.best_score });
        }
    }
    fn debugPlay(self: *Engine) !void {
        var buffer: [1024]u8 = undefined;
        var buffer_fbs = std.io.fixedBufferStream(&buffer);
        const writer = buffer_fbs.writer();
        self.board.printBoard();
        while (true) {
            try stdout.print("Playing: awaiting input...\n", .{});
            try stdin.streamUntilDelimiter(writer, '\n', buffer.len);
            const movestr = buffer_fbs.getWritten();
            if (std.mem.eql(u8, movestr, "exit")) {
                try stdout.print("Exiting play\n", .{});
                return;
            }
            const move = parse.parseUciMove(movestr, &self.board) catch |err| {
                try stdout.print("Invalid move: {s} Err: {}\n", .{ movestr, err });
                continue;
            };
            self.board.makeMove(move);
            self.board.printBoard();
            const res = sear.search(&self.board, &self.mg, 8);
            try stdout.print("playing move with score {} after searching nodes: {}\n", .{ res.best_score, res.nodes_searched });
            self.board.makeMove(res.best_move);
            self.board.printBoard();
            buffer_fbs.reset();
        }
    }
    // =================================== bench functions===================================
    fn benchSearch(self: *Engine) !void {
        try stdout.print("Benchmarking Search for position below\n", .{});
        self.board.printBoard();
        for (1..8) |depth| {
            var move_string = [_]u8{ 0, 0, 0, 0, 0 };

            const res = sear.search(&self.board, &self.mg, @intCast(depth));
            if (res.best_move.data == 0) {
                try stdout.print("bestmove 0000 at depth: {}\n", .{depth});
                continue;
            }
            // std.debug.print("total node searched: {}\n", .{res.nodes_searched});
            const has_promo = res.best_move.toUciString(&move_string);
            const move = if (has_promo) move_string[0..] else move_string[0..4];
            try stdout.print("Found Move {s} at depth {} after searching {} nodes\n", .{ move, depth, res.nodes_searched });
        }
    }
};
