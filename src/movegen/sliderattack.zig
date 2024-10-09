const bitboard = @import("../board/bitboard.zig");
const printBitboard = bitboard.printBitboard;
const BitBoard = bitboard.BitBoard;
const NUM_SQUARE = @import("../board.zig").NUM_SQUARES;

pub const BISHOP_OCCUPANCY = blk: {
    var occupancy: [NUM_SQUARE]BitBoard = undefined;
    for (0..NUM_SQUARE) |i| {
        occupancy[i] = 0;
    }

    for (0..NUM_SQUARE) |sq| {
        const rank = sq / 8;
        const file = sq % 8;
        const bb = &occupancy[sq];

        var r = rank + 1;
        var f = file + 1;
        while (r < 7 and f < 7) : ({
            r += 1;
            f += 1;
        }) {
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }

        r = rank;
        f = file;
        while (r > 1 and f > 1) {
            r -= 1;
            f -= 1;
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }

        r = rank;
        f = file + 1;
        while (r > 1 and f < 7) : (f += 1) {
            r -= 1;
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }

        r = rank + 1;
        f = file;
        while (r < 7 and f > 1) : (r += 1) {
            f -= 1;
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }
    }
    break :blk occupancy;
};

pub const ROOK_OCCUPANCY = blk: {
    var occupancy: [NUM_SQUARE]BitBoard = undefined;
    for (0..NUM_SQUARE) |i| {
        occupancy[i] = 0;
    }

    for (0..NUM_SQUARE) |sq| {
        const rank = sq / 8;
        const file = sq % 8;
        const bb = &occupancy[sq];

        var r = rank + 1;
        var f = file;
        while (r < 7) : (r += 1) {
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }

        r = rank;
        while (r > 1) {
            r -= 1;
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }

        r = rank;
        f = file + 1;
        while (f < 7) : (f += 1) {
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }

        f = file;
        while (f > 1) {
            f -= 1;
            const shift = r * 8 + f;
            bb.* |= (1 << shift);
        }
    }
    break :blk occupancy;
};

pub const SliderAttack = struct {
    bishop: [NUM_SQUARE][512]BitBoard,
    rook: [NUM_SQUARE][4096]BitBoard,

    pub fn init() SliderAttack {
        var slider = SliderAttack{
            .bishop = undefined,
            .rook = undefined,
        };
        slider.initBishop();
        slider.initRook();
        return slider;
    }
    fn initBishop(self: *SliderAttack) void {
        for (0..NUM_SQUARE) |j| {
            for (0..512) |i| {
                self.bishop[j][i] = 0;
            }
        }

        for (0..NUM_SQUARE) |sq| {
            const occ = BISHOP_OCCUPANCY[sq];
            const occ_two = 0xffffffffffffffff - occ + 1;
            var perm: BitBoard = 0;
            var stop = false;
            const sq6: u6 = @intCast(sq);
            while (!stop) : ({
                perm = (perm +% occ_two) & occ;
                stop = perm == 0;
            }) {
                const rank: u6 = sq6 / 8;
                const file: u6 = sq6 % 8;
                const magic_index = (perm *% BISHOP_MAGIC[sq]) >> 55;
                const bb = &self.bishop[sq][magic_index];

                var r = rank + 1;
                var f = file + 1;
                while (r < 8 and f < 8) : ({
                    r += 1;
                    f += 1;
                }) {
                    const shift: u6 = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }

                r = rank;
                f = file;
                while (r > 0 and f > 0) {
                    r -= 1;
                    f -= 1;
                    const shift = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }

                r = rank;
                f = file + 1;
                while (r > 0 and f < 8) : (f += 1) {
                    r -= 1;
                    const shift = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }

                r = rank + 1;
                f = file;
                while (r < 8 and f > 0) : (r += 1) {
                    f -= 1;
                    const shift = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }
            }
        }
    }

    fn initRook(self: *SliderAttack) void {
        for (0..NUM_SQUARE) |j| {
            for (0..4096) |i| {
                self.rook[j][i] = 0;
            }
        }

        for (0..NUM_SQUARE) |sq| {
            const occ = ROOK_OCCUPANCY[sq];
            const occ_two = 0xffffffffffffffff - occ + 1;
            var perm: BitBoard = 0;
            var stop = false;
            const sq6: u6 = @intCast(sq);
            while (!stop) : ({
                perm = (perm +% occ_two) & occ;
                stop = perm == 0;
            }) {
                const rank: u6 = sq6 / 8;
                const file: u6 = sq6 % 8;
                const magic_index = (perm *% ROOK_MAGIC[sq]) >> 52;
                const bb = &self.rook[sq][magic_index];

                var r = rank + 1;
                var f = file;
                while (r < 8) : (r += 1) {
                    const shift = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }

                r = rank;
                while (r > 0) {
                    r -= 1;
                    const shift = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }

                r = rank;
                f = file + 1;
                while (f < 8) : (f += 1) {
                    const shift = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }

                f = file;
                while (f > 0) {
                    f -= 1;
                    const shift = r * 8 + f;
                    const flag = @as(u64, 1) << shift;
                    bb.* |= flag;
                    if ((perm & flag) != 0) break;
                }
            }
        }
    }
};

// **************************************************************************************************
// “Magic”
// **************************************************************************************************

pub const BISHOP_MAGIC: [64]BitBoard = [_]BitBoard{ 149567943745568, 35459526950936, 1284298372055552, 1190080608437534720, 148627721239398656, 8935746699296, 36288449216512, 70952868126720, 4402364056064, 342574296868062464, 285890538651776, 18014675568558080, 9311193330173870081, 288265629245505536, 2594073559314079753, 22518136784292384, 4644341948088328, 4644342249821184, 144255929859735681, 1155736255447959552, 4648875917173915648, 8798242611200, 4616471239332990976, 576469550544194048, 18049720606589202, 121755519747629120, 2305922191501428752, 563540645675040, 145135560040448, 9227877844112138752, 2256237068552192, 18416819896384, 9085273439207456, 2323866633312969232, 6917546929081813056, 70411693859328, 18014673672667392, 35330401046786, 13835341729349240832, 288240272461138944, 721702150597510144, 9223654611880509696, 4901044517148295296, 148654247091635232, 1229487130779123744, 1161084816326976, 9043491796550656, 18212825595912, 576469587218989056, 140807415930880, 19336794112, 538870784, 90202710272, 9367504818216108552, 18225814015332384, 36187264409145348, 36592297139277832, 2757385854976, 72620544528482432, 144397762564329488, 9223376434906595968, 704911523968, 9223515531846402176, 9017099154887184 };
pub const ROOK_MAGIC: [64]BitBoard = [_]BitBoard{ 36028867888037896, 2314859005098332160, 577024870488473664, 666537418882550016, 18155153178888208, 36103581006299680, 36032095587401856, 612490648854995072, 292743321661476864, 39587015559169, 35184439824384, 9223389766513395716, 4644891168614402, 158956741223424, 422216831475721, 158338266431744, 141355964760576, 9300003634161123840, 9223376439198351488, 2199091430432, 10995149838340, 216180478829428740, 1649401725440, 4611704985009258624, 18212809097218, 35219805573130, 105896982349360, 4406737113088, 2305844315026434048, 282059369103872, 144134982588174337, 281479305363520, 299067835940928, 422251254055104, 9007766198944000, 106652762374148, 5136935522140680, 17610443981056, 865254087004815616, 4917932442360217888, 2322170713767968, 306244912301490240, 36064050196520960, 2269892382724, 72058699320983632, 5631698624615424, 27162897960419329, 1155173446156583040, 90072542305337472, 144132780398215184, 2314885393176069128, 9948522014327178272, 1152956697570246688, 6908522139904, 3178284204096, 4785075178733586, 18296012007276561, 18150536052746, 70849849720841, 424411557548098, 288516284071677953, 1125934275035141, 4403457294341, 73184060897239106 };

// *************************************************************************************************
// Finding Magic
// *************************************************************************************************
//
// pub const Magics = struct {
//     bishop: [64]u64,
//     rook: [64]u64,
//     slider: SliderAttack,
//
//     pub fn init() Magics {
//         var magics = Magics{
//             .bishop = undefined,
//             .rook = undefined,
//             .slider = SliderAttack.init(),
//         };
//         // const std = @import("std");
//         // std.debug.print("{any}\n", .{magics.slider.rook[1]});
//
//         magics.initBishop();
//         magics.initRook();
//
//         return magics;
//     }
//
//     fn initBishop(self: *Magics) void {
//         const std = @import("std");
//         var xo = std.Random.Xoshiro256.init(0x1234567890abcdef);
//         const random = xo.random();
//         for (0..64) |sq| {
//             var found = false;
//             while (!found) {
//                 var used_attack: [512]BitBoard = undefined;
//                 for (0..512) |i| {
//                     used_attack[i] = 0;
//                 }
//                 const magic = random.int(u64) & random.int(u64) & random.int(u64) & random.int(u64);
//                 var not_magic = false;
//                 const occ = BISHOP_OCCUPANCY[sq];
//                 const occ_two = 0xffffffffffffffff - occ + 1;
//                 var perm: BitBoard = 0;
//                 for (0..512) |index| {
//                     const magic_index = (perm *% magic) >> 55;
//                     if (used_attack[magic_index] == 0) {
//                         used_attack[magic_index] = self.slider.bishop[sq][index];
//                     } else if (used_attack[magic_index] != self.slider.bishop[sq][index]) {
//                         not_magic = true;
//                         break;
//                     }
//                     // if (perm == 0x040200) {
//                     //     std.debug.print("for blocker: {}\n", .{perm});
//                     //     printBitboard(perm);
//                     //     std.debug.print("from magic index({}) attack\n", .{magic_index});
//                     //     printBitboard(used_attack[magic_index]);
//                     //     std.debug.print("from permutation index index\n", .{});
//                     //     printBitboard(self.slider.bishop[sq][index]);
//                     //     _ = std.io.getStdIn().reader().readByte() catch unreachable;
//                     // }
//                     perm = (perm +% occ_two) & occ;
//                 }
//
//                 if (!not_magic) {
//                     // std.debug.print("found magic for sq {}: {}\n", .{ sq, magic });
//                     // const occccc = 0xffffff;
//                     // std.debug.print("occupancy: \n", .{});
//                     // printBitboard(occccc);
//                     // const mask = BISHOP_OCCUPANCY[sq];
//                     // std.debug.print("mask: \n", .{});
//                     // printBitboard(mask);
//                     // const blocker = 0x040200; // occccc & mask;
//                     // const index = (blocker *% magic) >> 55;
//                     // std.debug.print("test: index:  for blocker: {}\n", .{index});
//                     // printBitboard(blocker);
//                     // std.debug.print("attack: \n", .{});
//                     // printBitboard(self.slider.bishop[sq][index]);
//                     // _ = std.io.getStdIn().reader().readByte() catch unreachable;
//                     self.bishop[sq] = magic;
//                     found = true;
//                 }
//             }
//         }
//     }
//
//     fn initRook(self: *Magics) void {
//         const std = @import("std");
//         var xo = std.Random.Xoshiro256.init(6543);
//         const random = xo.random();
//         for (0..64) |sq| {
//             var found = false;
//             while (!found) {
//                 var used_attack: [4096]BitBoard = undefined;
//                 for (0..4096) |i| {
//                     used_attack[i] = 0;
//                 }
//                 const magic = random.int(u64) & random.int(u64) & random.int(u64) & random.int(u64);
//                 // std.debug.print("trying magic: {}\n", .{magic});
//                 var is_magic = true;
//                 const occ = ROOK_OCCUPANCY[sq];
//                 const occ_two = 0xffffffffffffffff - occ + 1;
//                 var perm: BitBoard = 0;
//                 for (0..4096) |index| {
//                     const magic_index = (perm *% magic) >> 52;
//                     if (used_attack[magic_index] == 0) {
//                         used_attack[magic_index] = self.slider.rook[sq][index];
//                     } else if (used_attack[magic_index] != self.slider.rook[sq][index]) {
//                         // std.debug.print("midx: {}: {}\nindex: {}: {}\n", .{ magic_index, used_attack[magic_index], index, self.slider.rook[sq][index] });
//                         // std.debug.print("failed magic for sq: {}\nmagic: {}\n\n", .{ sq, magic });
//                         is_magic = false;
//                         break;
//                     }
//                     perm = (perm +% occ_two) & occ;
//                 }
//
//                 if (is_magic) {
//                     // std.debug.print("found magic for sq: {}\nmagic: {}\n\n", .{ sq, magic });
//                     self.rook[sq] = magic;
//                     found = true;
//                 }
//             }
//         }
//     }
// };
