const std = @import("std");
const testing = std.testing;
const mem = std.mem;

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
            // TODO: Use @memset
            for (0..slice.len) |i| slice[i] = value;
            return slice;
        }

        /// Sets a value of `slice` at `index` to `value`.
        pub fn set(slice: Slice, index: usize, value: Element) Slice {
            slice[index] = value;
            return slice;
        }

        /// Sets a region of `slice` starting at `index` to `value`. The condition
        /// `slice.len >= index + value.len` must be satisfied.
        pub fn setSlice(slice: Slice, index: usize, value: ConstSlice) Slice {
            @memcpy(slice[index .. index + value.len], value);
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

        /// Replaces a slice at `index` with length `remove_count` by `replacement` in `slice`.
        /// Values from the start of `slice` to `length` are considered to be set. All values
        /// beyond `length` are considered undefined. The condition
        ///
        /// ```
        /// slice.len >= (slice.len + (replacement.len - remove_count))
        /// ```
        ///
        /// must be satisfied. Otherwise, `slice` will overflow.
        pub fn splice(
            slice: Slice,
            index: usize,
            length: usize,
            remove_count: usize,
            replacement: ConstSlice,
        ) Slice {
            const slide_index = index + remove_count;
            const slide_length = length - slide_index;
            const i_replacement_len: isize = @bitCast(replacement.len);
            const i_remove_count: isize = @bitCast(remove_count);
            const slide_steps = i_replacement_len - i_remove_count;

            return setSlice(
                slide(slice, slide_index, slide_length, slide_steps),
                index,
                replacement,
            );
        }

        /// Shifts values in a `slice` by `steps` to the left or right. If `steps < 0` values are
        /// shifted to the left. Otherwise, values are shifted to the right.
        pub fn shift(slice: Slice, steps: isize) Slice {
            const Shift = fn (slice: Slice, steps: usize) Slice;
            const sh: *const Shift = if (steps < 0) shiftLeft else shiftRight;
            return sh(slice, @abs(steps));
        }

        /// Shifts values in a `slice` by `steps` to the left.
        pub fn shiftLeft(slice: Slice, steps: usize) Slice {
            var start: usize = 1;
            var end: usize = slice.len;

            for (0..steps) |_| {
                var i: usize = start;
                while (i < end) : (i += 1) slice[i - 1] = slice[i];
                start = @max(start - 1, 1);
                end -= 1;
            }

            return slice;
        }

        /// Shifts values in a `slice` by `steps` to the right.
        pub fn shiftRight(slice: Slice, steps: usize) Slice {
            var start: usize = 0;
            var end: usize = slice.len - 1;

            for (0..steps) |_| {
                var i: usize = end;
                while (i > start) : (i -= 1) slice[i] = slice[i - 1];
                start += 1;
                end = @min(end + 1, slice.len);
            }

            return slice;
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

        /// Removes `value`s from the start nad end of the `slice`.
        pub fn trim(slice: ConstSlice, value: ConstSlice) ConstSlice {
            return mem.trim(Element, slice, value);
        }

        /// Removes `value`s from the start of the `slice`.
        pub fn trimStart(slice: ConstSlice, value: ConstSlice) ConstSlice {
            return mem.trimStart(Element, slice, value);
        }

        /// Removes `value`s from the end of the `slice`.
        pub fn trimEnd(slice: ConstSlice, value: ConstSlice) ConstSlice {
            return mem.trimEnd(Element, slice, value);
        }

        /// Pads the start and end of `value` with `padding`. The `value` is centered. The length
        /// of `slice` determines the size of padding.
        pub fn pad(slice: Slice, padding: Element, value: ConstSlice) Slice {
            const padding_length = slice.len - value.len;
            const half_padding_length = padding_length / 2;
            const padding_remainder = padding_length % 2;
            const value_start = half_padding_length + padding_remainder;
            const value_end = value_start + value.len;

            _ = padStart(slice[0..value_end], padding, value);
            _ = fill(slice[value_end..], padding);
            return slice;
        }

        /// Pads the start of `value` with `padding`. The length of `slice` determines the amount of
        /// padding.
        pub fn padStart(slice: Slice, padding: Element, value: ConstSlice) Slice {
            const value_index = slice.len - value.len;
            _ = fill(slice[0..value_index], padding);
            return setSlice(slice, value_index, value);
        }

        /// Pads the end of `value` with `padding`. The length of `slice` determines the size of
        /// padding.
        pub fn padEnd(slice: Slice, padding: Element, value: ConstSlice) Slice {
            _ = fill(slice[value.len..], padding);
            return setSlice(slice, 0, value);
        }
    };
}

test "fill" {
    const Arr = Array(u8);
    var slice = Arr.init(4);

    try testing.expectEqualSlices(u8, &.{ 1, 1, 1, 1 }, Arr.fill(&slice, 1));
}

test "set" {
    const Arr = Array(u8);
    var slice = Arr.init(4);

    try testing.expectEqualSlices(u8, &.{1}, Arr.set(&slice, 0, 1)[0..1]);
}

test "setSlice" {
    const Arr = Array(u8);
    var slice = Arr.init(4);

    try testing.expectEqualSlices(u8, &.{ 1, 2 }, Arr.setSlice(&slice, 0, &.{ 1, 2 })[0..2]);
    try testing.expectEqualSlices(u8, &.{ 1, 2 }, Arr.setSlice(&slice, 2, &.{ 1, 2 })[2..]);
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

test "shiftLeft" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, Arr.shiftLeft(&slice, 1)[0..3]);
}

test "shiftRight" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2 }, Arr.shiftRight(&slice, 1)[1..4]);
}

test "shift" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });

    try testing.expectEqualSlices(u8, &.{ 0, 1, 2 }, Arr.shift(&slice, 1)[1..4]);
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2 }, Arr.shift(&slice, -1)[0..3]);
}

test "trimStart" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    @memcpy(slice[0..4], &[_]Arr.Element{ 1, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 2, 3 }, Arr.trimStart(&slice, &.{1})[0..2]);

    @memcpy(slice[0..6], &[_]Arr.Element{ 0, 1, 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 2, 3 }, Arr.trimStart(&slice, &.{ 0, 1 })[0..2]);
}

test "trimEnd" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    @memcpy(slice[4..], &[_]Arr.Element{ 2, 3, 1, 1 });
    try testing.expectEqualSlices(u8, &.{ 2, 3 }, Arr.trimEnd(&slice, &.{1})[4..]);

    @memcpy(slice[2..], &[_]Arr.Element{ 2, 3, 0, 1, 0, 1 });
    try testing.expectEqualSlices(u8, &.{ 2, 3 }, Arr.trimEnd(&slice, &.{ 0, 1 })[2..]);
}

test "trim" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    @memcpy(&slice, &[_]Arr.Element{ 1, 1, 2, 3, 4, 5, 1, 1 });
    try testing.expectEqualSlices(u8, &.{ 2, 3, 4, 5 }, Arr.trim(&slice, &.{1}));

    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3, 4, 5, 0, 1 });
    try testing.expectEqualSlices(u8, &.{ 2, 3, 4, 5 }, Arr.trim(&slice, &.{ 0, 1 }));
}

test "padStart" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    try testing.expectEqualSlices(u8, &.{ 0, 0, 1, 2 }, Arr.padStart(&slice, 0, &.{ 1, 2 }));
}

test "padEnd" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    try testing.expectEqualSlices(u8, &.{ 1, 2, 0, 0 }, Arr.padEnd(&slice, 0, &.{ 1, 2 }));
}

test "pad" {
    const Arr = Array(u8);
    var slice = Arr.init(6);
    try testing.expectEqualSlices(u8, &.{ 0, 0, 1, 2, 0, 0 }, Arr.pad(&slice, 0, &.{ 1, 2 }));
    try testing.expectEqualSlices(u8, &.{ 0, 0, 1, 2, 0 }, Arr.pad(slice[0..5], 0, &.{ 1, 2 }));
}

test "splice" {
    const Arr = Array(u8);
    var slice = Arr.init(8);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3, 4, 5, 6, 7 });

    try testing.expectEqualSlices(
        u8,
        &.{ 0, 1, 2, 1, 0 },
        Arr.splice(&slice, 3, 5, 0, &.{ 1, 0 })[0..5],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 2, 4, 1, 0 },
        Arr.splice(&slice, 0, 5, 3, &.{ 1, 2, 4 })[0..5],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 2, 4, 8, 16 },
        Arr.splice(&slice, 3, 6, 3, &.{ 8, 16 })[0..5],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 4, 16 },
        Arr.splice(&slice, 1, 5, 3, &.{4})[0..3],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 16 },
        Arr.splice(&slice, 1, 3, 1, &.{})[0..2],
    );
}
