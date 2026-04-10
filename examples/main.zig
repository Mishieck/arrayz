const std = @import("std");
const testing = std.testing;

const arrayz = @import("arrayz");

pub fn main() !void {
    const Arr = arrayz.Array(u8);
    var slice = Arr.init(4);
    const slice1 = &.{1};
    const slice2 = &.{ 2, 3, 4 };

    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, Arr.concat(&slice, &.{ slice1, slice2 }));
}
