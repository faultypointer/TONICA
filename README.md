# TONICA

A chess UCI Engine written in Zig.

## Contents

1. [About The Engine](#about-the-engine)
   1. [Board Representation](#board-representation)
   2. [Move Generation](#move-generation)
   3. [Searching](#searching)
   4. [Evaluation](#evaluation)
   5. [Communication](#communication)
2. [Building](#building)
3. [References](#references)

## About The Engine

Tonica is a UCI (it only supports very few uci commands currently) chess Engine written in zig. I don't know what's its elo
is as I have not tested it that much. Although it can beat me fairly easily. It is still very simple and there are a lot of features
to add and some of them are very necessary stuff like time management.

### Board Representation

The board is essentially represented as 12 bitboards(64 bits where each 1 bit represents presence of a piece on a square) for 6 piece
types each for both side. The actual board struct used to represent the chess board stores other informations along with 12 bitboards.
For example it also store extra 2 bitboards each for one side where 1 bit indicate a piece of that side in that square(denoted by bit position)
of any type.

```zig
pub const Board = struct {
    piece_bb: [NUM_SIDE][NUM_PIECE_TYPE]BitBoard,
    side_bb: [NUM_SIDE]BitBoard,
    state: BState,
    state_stack: StateStack = .{},
}
```

`BState` is a struct that holds informations like side to move, castling rights, en-passant square. Informations that are relevant to current
board position. `StateStack` is just a stack of states that's useful when making and unmaking moves while searching.

```zig
pub const BState = struct {
    turn: Side,
    castling_rights: u8,
    en_passant: ?Square,
    half_move_clock: u16,
    full_move_clock: u16,
    next_move: ?Move = null,
    key: u64,
}
```

`key` is a [Zobrist](https://www.chessprogramming.org/Zobrist_Hashing) key that is used for transposition tables or opening books which are not
currently implemented in tonica.

### Move Generation

Tonica uses a pseudo-legal move generator which generates all possible moves the pieces can make in that position (except for castling when in check)
even the ones which leave king in check. Filtering out those illegals moves is done later in search by checking if the king is in check after the move
and if it is, skipping that move.

For faster move generations, the attack tables of pieces are pre-computed. For non-slider pieces (king, knight, pawn), its simple. The pawn attack table
is generated as follows:

```zig
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

    // Initialize black pawns (attack[1])
    i = 8;
    while (i < NUM_SQUARE) : (i += 1) {
        var bb: BitBoard = 0;
        bitboard.setPieceAtLoc(&bb, i);
        if ((bb & NOT_A_FILE) > 0) attack[1][i] |= (bb >> 9);
        if ((bb & NOT_H_FILE) > 0) attack[1][i] |= (bb >> 7);
    }

    break :blk attack;
};
```

Attack tables for knights and king are generated similarly. You can see the code [here](./src/movegen/nonsliderattack.zig).

Attack tables for non-slider pieces are a little complex as they involve blockers that may block a slider pieces from moving to desired position.
I used [Magic bitboards](https://www.chessprogramming.org/Magic_Bitboards) to generate slider attack tables. The code is available [here](./src/movegen/sliderattack.zig).

### Searching

Currently, I've implemented these searching (and move ordering) techniques:

- negamax alphabeta
- queiscence search
- iterative deepening
- killer and history heuristics
- late move reduction
- null move pruning
- principle variation search
- aspiration window search (which I still haven't merged into main)

### Evaluation

I have implemented piece counting and piece square table for evaluation. The peice square table is just slightly modified version of [Pesto Evaluation](https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function).

### Communication

I have only implemented a few Uci commands and few other test commands that are useful for performance testing.

```zig
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
```

## Building

Clone this repo

```bash
git clone https://github.com/faultypointer/TONICA.git tonica
cd tonica
```

### Dependecies

Tonica doesn't have any external dependency other that the zig programming language itself.
It uses zig version 0.13.0.You can download zig from [here](https://ziglang.org/download/) or you can build
it from [source](https://github.com/ziglang/zig).

If you use nix with direnv support, you can just `cd` into the cloned directory then do:

```bash
direnv allow
```

After zig is successfully installed, you can build the engine as:

```bash
zig build --release=fast
```

The target output is available in `./zig-out/bin/tonica`.

## References

- [Chess Programming Wiki](https://www.chessprogramming.org/Main_Page)
- [Chess Programming by François Dominic Laramé](http://archive.gamedev.net/archive/reference/articles/article1014.html)
- (<http://www.fam-petzke.de/chess_home_en.shtml>)
- [Code Monkey King YT series](https://www.youtube.com/playlist?list=PLmN0neTso3Jxh8ZIylk74JpwfiWNI76Cs)
- [Rustic Chess](https://www.rustic-chess.org/)
- a really great explanation of magic bitboards for premove generation of slider pieces
  - (<https://stackoverflow.com/questions/16925204/sliding-move-generation-using-magic-bitboard>)
