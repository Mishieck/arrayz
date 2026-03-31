const std = @import("std");

pub fn Array(comptime element: type) type {
    return struct {
        const Element = element;
        pub const Slice = []Element;
        pub const ConstSlice = []const Element;
    };
}
