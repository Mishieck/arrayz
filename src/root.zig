const std = @import("std");
const testing = std.testing;

pub fn Array(comptime element: type) type {
    return struct {
        const Element = element;
        pub const Slice = []Element;
        pub const ConstSlice = []const Element;

        /// Creates an array with the given `capacity`.
        pub inline fn init(comptime capacity: usize) [capacity]Element {
            const array: [capacity]Element = undefined;
            return array;
        }

        /// Sets every element of `slice` to `value`.
        pub fn fill(slice: Slice, value: Element) Slice {
            for (0..slice.len) |i| slice[i] = value;
            return slice;
        }

        /// Concatenates `slices`. The returned slice contains the concatenated `slices`.
        pub fn concat(slice: Slice, slices: []const ConstSlice) Slice {
            var i: usize = 0;
            for (slices) |s| {
                @memcpy(slice[i .. i + s.len], s);
                i += s.len;
            }

            return slice[0..i];
        }

        /// Joins `slices` using a `separator`. The returned slice contains the joined `slices`.
        pub fn join(slice: Slice, separator: ConstSlice, slices: []const ConstSlice) Slice {
            if (slices.len == 0) return slice[0..0];
            var i: usize = 0;

            const first_slice = slices[0];
            @memcpy(slice[0..first_slice.len], first_slice);
            i += first_slice.len;

            for (slices[1..]) |s| {
                @memcpy(slice[i .. i + separator.len], separator);
                i += separator.len;
                @memcpy(slice[i .. i + s.len], s);
                i += s.len;
            }

            return slice[0..i];
        }

        /// Slides a slice withing another `slice`. The inner slice starts at `index` and has
        /// length `length`. The inner slice is slid by `steps`. If `steps < 0` the inner slice is
        /// slid left, otherwise, it is slid right. The base slice is returned.
        pub fn slide(slice: Slice, index: usize, length: usize, steps: isize) Slice {
            const Slide = *const fn (slice: Slice, index: usize, length: usize, steps: usize) Slice;
            const s: Slide = if (steps < 0) slideLeft else slideRight;
            return s(slice, index, length, @abs(steps));
        }

        /// Slides a slice withing another `slice` to the left. The inner slice starts at `index`
        /// and has length `length`. The inner slice is slid by `steps`. The base slice is returned.
        pub fn slideLeft(slice: Slice, index: usize, length: usize, steps: usize) Slice {
            var start: usize = index;
            var end: usize = index + length;

            for (0..steps) |_| {
                var i: usize = start;
                while (i < end) : (i += 1) slice[i - 1] = slice[i];
                start -= 1;
                end -= 1;
            }

            return slice;
        }

        /// Slides a slice withing another `slice` to the right. The inner slice starts at `index`
        /// and has length `length`. The inner slice is slid by `steps`. The base slice is returned.
        pub fn slideRight(slice: Slice, index: usize, length: usize, steps: usize) Slice {
            var start: usize = index;
            var end: usize = index + length;

            for (0..steps) |_| {
                var i: usize = end;
                while (i > start) : (i -= 1) slice[i] = slice[i - 1];
                start += 1;
                end += 1;
            }

            return slice;
        }
    };
}

test "fill" {
    const Arr = Array(u8);
    var slice = Arr.init(4);

    try testing.expectEqualSlices(u8, &.{ 1, 1, 1, 1 }, Arr.fill(&slice, 1));
}

test "concat" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    const slice1 = &.{1};
    const slice2 = &.{ 2, 3, 4 };

    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, Arr.concat(&slice, &.{ slice1, slice2 }));
}

test "join" {
    const Arr = Array(u8);
    var slice = Arr.init(16);
    const slice0 = &.{0};
    const slice1 = &.{ 1, 2 };
    const slice2 = &.{ 3, 4, 5 };

    try testing.expectEqualSlices(u8, &.{}, Arr.join(&slice, slice0, &.{}));
    try testing.expectEqualSlices(u8, &.{ 1, 2 }, Arr.join(&slice, slice0, &.{slice1}));
    try testing.expectEqualSlices(
        u8,
        &.{ 1, 2, 0, 3, 4, 5 },
        Arr.join(&slice, slice0, &.{ slice1, slice2 }),
    );
    try testing.expectEqualSlices(
        u8,
        &.{ 1, 2, 0, 3, 4, 5, 0, 1, 2 },
        Arr.join(&slice, slice0, &.{ slice1, slice2, slice1 }),
    );
    try testing.expectEqualSlices(
        u8,
        &.{ 0, 1, 2, 3, 4, 5 },
        Arr.join(&slice, slice1, &.{ slice0, slice2 }),
    );
}

test "slideLeft" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    slice[2] = 2;
    slice[3] = 4;

    try testing.expectEqualSlices(u8, &.{ 2, 4 }, Arr.slideLeft(&slice, 2, 2, 2)[0..2]);
}

test "slideRight" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    slice[1] = 2;
    slice[2] = 4;

    try testing.expectEqualSlices(u8, &.{ 2, 4 }, Arr.slideRight(&slice, 1, 2, 3)[4..6]);
}
test "slide" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    slice[0] = 2;
    slice[1] = 4;
    try testing.expectEqualSlices(u8, &.{ 2, 4 }, Arr.slide(&slice, 0, 2, 2)[2..4]);

    slice[0] = 0;
    slice[1] = 0;
    try testing.expectEqualSlices(u8, &.{ 2, 4 }, Arr.slide(&slice, 2, 2, -2)[0..2]);
}
