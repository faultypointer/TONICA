const Bstate = @import("../board.zig").BState;

pub const BSTATE_STACK_SIZE: usize = 1024;

// a stack to hold the previous board states
// the number of elements in the can be directly accessed through the states feild's len property
pub const StateStack = struct {
    states: [BSTATE_STACK_SIZE]Bstate = undefined,
    top: usize = 0,

    pub fn push(self: *StateStack, state: Bstate) void {
        self.states[self.top] = state;
        self.top += 1;
    }

    pub fn pop(self: *StateStack) Bstate {
        self.top -= 1;
        return self.states[self.top];
    }
    pub fn peek(self: StateStack) Bstate {
        return self.states[self.top - 1];
    }
};
