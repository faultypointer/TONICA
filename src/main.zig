const Engine = @import("engine.zig").Engine;

pub fn main() !void {
    var engine = Engine.init();
    try engine.run();
}
