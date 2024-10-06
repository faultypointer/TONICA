pub const BitBoard = struct {
    board: u64,

    pub fn init(board: u64) BitBoard {
        return .{
            .board = board,
        };
    }
};
