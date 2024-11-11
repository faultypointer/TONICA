# TONICA

A chess Engine written in Zig.

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
