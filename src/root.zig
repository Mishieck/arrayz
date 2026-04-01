const std = @import("std");
const testing = std.testing;

pub fn Array(comptime element: type) type {
    return struct {
        const Element = element;
        pub const Slice = []Element;
        pub const ConstSlice = []const Element;

        pub inline fn init(comptime capacity: usize) [capacity]Element {
            const array: [capacity]Element = undefined;
            return array;
        }

        pub fn fill(slice: Slice, value: Element) Slice {
            for (0..slice.len) |i| slice[i] = value;
            return slice;
        }
    };
}

test "Array.fill" {
    const Arr = Array(u8);
    var slice = Arr.init(4);

    try testing.expectEqualSlices(u8, &.{ 1, 1, 1, 1 }, Arr.fill(&slice, 1));
}
