const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const math = std.math;
const debug = std.debug;

pub fn Array(comptime element: type) type {
    return struct {
        const Element = element;
        pub const Slice = []Element;
        pub const ConstSlice = []const Element;
        pub const Predicate = fn (value: Element, index: usize, slice: ConstSlice) bool;
        pub const Map = fn (value: Element, index: usize, slice: ConstSlice) Element;

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

        /// Inserts `value` into `slice` at `index`. `length` is the length of the sub-slice of
        /// `slice` that has defined values. All values beyond the sub-slice are undefined.
        pub fn insert(slice: Slice, length: usize, index: usize, value: ConstSlice) Slice {
            return splice(slice, length, index, 0, value);
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
            length: usize,
            index: usize,
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

        /// Rotates `slice` by `steps` towards the start.
        pub fn rotateStart(slice: Slice, steps: usize) Slice {
            const i_steps: isize = @bitCast(steps);
            return rotate(slice, -i_steps);
        }

        /// Rotates `slice` by `steps` towards the end.
        pub fn rotateEnd(slice: Slice, steps: usize) Slice {
            return rotate(slice, @bitCast(steps));
        }

        /// Rotates `slice` by `steps`. When `steps` is negative, it rotates towards the start.
        /// Otherwise, it rotates towards the end.
        pub fn rotate(slice: Slice, steps: isize) Slice {
            if (slice.len == 0) return slice;
            const sign: isize = math.sign(steps);
            const steps_abs = @abs(steps);

            for (0..steps_abs) |_| {
                var index: isize = 0;
                var current = slice[@bitCast(index)];

                for (0..slice.len) |_| {
                    const i_slice_len: isize = @bitCast(slice.len);
                    const next_index = @mod(index +% sign, i_slice_len);
                    const next = slice[@bitCast(next_index)];
                    slice[@bitCast(next_index)] = current;
                    current = next;
                    index = next_index;
                }
            }

            return slice;
        }

        /// Shifts values in a `slice` by `steps` to the left.
        pub fn shiftStart(slice: Slice, steps: usize) Slice {
            const i_steps: isize = @bitCast(steps);
            return shift(slice, -i_steps);
        }

        /// Shifts values in a `slice` by `steps` to the right.
        pub fn shiftEnd(slice: Slice, steps: usize) Slice {
            return shift(slice, @bitCast(steps));
        }

        /// Shifts values in a `slice` by `steps` to the left or right. If `steps < 0` values are
        /// shifted to the left. Otherwise, values are shifted to the right.
        pub fn shift(slice: Slice, steps: isize) Slice {
            const direction = math.sign(steps);
            var length: isize = @bitCast(slice.len);
            var current_index: isize = if (direction == -1) 1 else 0;

            for (0..@abs(steps)) |_| {
                _ = slideOnce(slice, @bitCast(current_index), @bitCast(length - 1), direction);
                current_index = @max(current_index + direction, 1);
                length -= 1;
            }

            return slice;
        }

        /// Reverses `slice`.
        pub fn reverse(slice: Slice) Slice {
            mem.reverse(Element, slice);
            return slice;
        }

        /// Swaps element at `first` with element at `second` in `slice`.
        pub fn swap(slice: Slice, first: usize, second: usize) Slice {
            mem.swap(Element, &slice[first], &slice[second]);
            return slice;
        }

        /// Maps each element of `slice` using `f`.
        pub fn map(slice: Slice, f: Map) Slice {
            for (slice, 0..) |value, i| slice[i] = f(value, i, slice);
            return slice;
        }

        /// Filters elements from `slice` using the predicate `f`. The returned slice contains only
        /// the filtered elements.
        pub fn filter(slice: Slice, f: Predicate) Slice {
            var i: usize = 0;

            for (slice) |value| {
                if (!f(value, i, slice)) continue;
                slice[i] = value;
                i += 1;
            }

            return slice[0..i];
        }

        /// Checks that all values in `slice` statisfy a condition defined by `f`.
        pub fn forAll(slice: ConstSlice, f: Predicate) bool {
            return for (slice, 0..) |value, i| {
                if (f(value, i, slice)) continue else break false;
            } else true;
        }

        /// Checks that there is a value in `slice` that statisfies a condition defined by `f`.
        pub fn thereExists(slice: ConstSlice, f: Predicate) bool {
            return for (slice, 0..) |value, i| {
                if (f(value, i, slice)) break true;
            } else false;
        }

        /// Finds a value in `slice` that statisfies a condition defined by `f`.
        pub fn find(slice: ConstSlice, f: Predicate) ?Element {
            return for (slice, 0..) |value, i| {
                if (f(value, i, slice)) break value;
            } else null;
        }

        /// Finds the index of `value` in `slice`.
        pub fn indexOf(slice: ConstSlice, value: Element) ?usize {
            return mem.indexOf(Element, slice, &.{value});
        }

        /// Finds the last index of `value` in `slice`.
        pub fn lastIndexOf(slice: ConstSlice, value: Element) ?usize {
            return mem.lastIndexOf(Element, slice, &.{value});
        }

        /// Finds the last index of `value` in `slice`.
        pub fn findIndexOf(slice: ConstSlice, f: Predicate) ?usize {
            return for (slice, 0..) |value, i| {
                if (f(value, i, slice)) return i;
            } else null;
        }

        /// Finds the last index of `value` in `slice`.
        pub fn findLastIndexOf(slice: ConstSlice, f: Predicate) ?usize {
            var last_index: ?usize = null;
            for (slice, 0..) |value, i| {
                if (f(value, i, slice)) last_index = i;
            }
            return last_index;
        }

        /// Slides a slice withing another `slice` to the left. The inner slice starts at `index`
        /// and has length `length`. The inner slice is slid by `steps`. The base slice is returned.
        pub fn slideStart(slice: Slice, index: usize, length: usize, steps: usize) Slice {
            const i_steps: isize = @bitCast(steps);
            return slide(slice, index, length, -i_steps);
        }

        /// Slides a slice withing another `slice` to the right. The inner slice starts at `index`
        /// and has length `length`. The inner slice is slid by `steps`. The base slice is returned.
        pub fn slideEnd(slice: Slice, index: usize, length: usize, steps: usize) Slice {
            return slide(slice, index, length, @bitCast(steps));
        }

        /// Slides a slice withing another `slice`. The inner slice starts at `index` and has
        /// length `length`. The inner slice is slid by `steps`. If `steps < 0` the inner slice is
        /// slid left, otherwise, it is slid right. The base slice is returned.
        pub fn slide(slice: Slice, index: usize, length: usize, steps: isize) Slice {
            const direction = math.sign(steps);
            var current_index: isize = @bitCast(index);

            for (0..@abs(steps)) |_| {
                _ = slideOnce(slice, @bitCast(current_index), length, direction);
                current_index += direction;
            }

            return slice;
        }

        /// Slides a sub-slice at `index` of length `length` in `slice` at most once. If
        ///
        /// - `direction == -1`: it is going to slide towards the start.
        /// - `direction == 0`: it will not slide.
        /// - `direction == 1`: it will slide towards the end.
        /// - Otherwise: a panic is going to be triggered.
        pub fn slideOnce(slice: Slice, index: usize, length: usize, direction: isize) Slice {
            debug.assert(direction >= -1 and direction <= 1);
            if (slice.len == 0 or length == 0) return slice;

            const end: isize = @bitCast(index + length);
            var current_index: isize = if (direction == -1) end - 1 else @bitCast(index);
            var current = slice[@bitCast(current_index)];

            for (0..length) |_| {
                const next_index = current_index + direction;
                const next = slice[@bitCast(next_index)];
                slice[@bitCast(next_index)] = current;
                current = next;
                current_index = next_index;
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

test "reverse" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 3, 2, 1, 0 }, Arr.reverse(&slice));
}

test "map" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 0, 2, 4, 6 }, Arr.map(&slice, double));
}

fn double(value: u8, index: usize, slice: []const u8) u8 {
    _ = index;
    _ = slice;
    return value * 2;
}

test "filter" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 0, 2 }, Arr.filter(&slice, isEven));
}

test "forAll" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 2, 4, 6 });
    try testing.expectEqual(true, Arr.forAll(&slice, isEven));
    try testing.expectEqual(false, Arr.forAll(&slice, isOdd));
}

test "thereExists" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 1, 2, 3, 1 });
    try testing.expectEqual(true, Arr.thereExists(&slice, isEven));
    @memcpy(&slice, &[_]Arr.Element{ 1, 3, 5, 7 });
    try testing.expectEqual(false, Arr.thereExists(&slice, isEven));
}

test "find" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 1, 2, 3, 1 });
    try testing.expectEqual(2, Arr.find(&slice, isEven).?);
    @memcpy(&slice, &[_]Arr.Element{ 1, 3, 5, 7 });
    try testing.expectEqual(null, Arr.find(&slice, isEven));
}

test "indexOf" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 1, 2, 3, 1 });
    try testing.expectEqual(1, Arr.indexOf(&slice, 2).?);
    try testing.expectEqual(null, Arr.indexOf(&slice, 4));
}

test "lastIndexOf" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 1, 2, 3, 1 });
    try testing.expectEqual(3, Arr.lastIndexOf(&slice, 1).?);
    try testing.expectEqual(1, Arr.lastIndexOf(&slice, 2).?);
    try testing.expectEqual(null, Arr.lastIndexOf(&slice, 4));
}

test "findIndexOf" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 1, 2, 3, 1 });
    try testing.expectEqual(1, Arr.findIndexOf(&slice, isEven).?);
    @memcpy(&slice, &[_]Arr.Element{ 1, 3, 5, 7 });
    try testing.expectEqual(null, Arr.findIndexOf(&slice, isEven));
}

test "findLastIndexOf" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 1, 2, 2, 1 });
    try testing.expectEqual(2, Arr.findLastIndexOf(&slice, isEven).?);
    try testing.expectEqual(3, Arr.findLastIndexOf(&slice, isOdd).?);
    @memcpy(&slice, &[_]Arr.Element{ 1, 3, 5, 7 });
    try testing.expectEqual(null, Arr.findLastIndexOf(&slice, isEven));
}

fn isEven(value: u8, index: usize, slice: []const u8) bool {
    return isParity(0, value, index, slice);
}

fn isOdd(value: u8, index: usize, slice: []const u8) bool {
    return isParity(1, value, index, slice);
}

/// Checks if `value` has parity defined by `parity`. `0` is even and `1` is odd.
fn isParity(parity: u1, value: u8, index: usize, slice: []const u8) bool {
    _ = index;
    _ = slice;
    return value % 2 == parity;
}

test "swap" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });

    try testing.expectEqualSlices(u8, &.{ 0, 2, 1, 3 }, Arr.swap(&slice, 1, 2));
    try testing.expectEqualSlices(u8, &.{ 3, 2, 1, 0 }, Arr.swap(&slice, 0, 3));
}

test "slideStart" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    slice[2] = 2;
    slice[3] = 4;

    try testing.expectEqualSlices(u8, &.{ 2, 4 }, Arr.slideStart(&slice, 2, 2, 2)[0..2]);
}

test "slideEnd" {
    const Arr = Array(u8);
    var slice = Arr.init(8);

    slice[1] = 2;
    slice[2] = 4;

    try testing.expectEqualSlices(u8, &.{ 2, 4 }, Arr.slideEnd(&slice, 1, 2, 3)[4..6]);
}

test "slideOnce" {
    const Arr = Array(u8);
    var slice = Arr.init(5);

    @memcpy(&slice, &[_]Arr.Element{ 0, 0, 1, 2, 0 });
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2 }, Arr.slideOnce(&slice, 2, 2, -1)[0..3]);
    try testing.expectEqualSlices(u8, &.{ 1, 2 }, Arr.slideOnce(&slice, 1, 2, -1)[0..2]);
    try testing.expectEqualSlices(u8, &.{ 1, 2 }, Arr.slideOnce(&slice, 0, 2, 1)[1..3]);
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

test "shiftStart" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, Arr.shiftStart(&slice, 1)[0..3]);
}

test "shiftEnd" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2 }, Arr.shiftEnd(&slice, 1)[1..4]);
}

test "rotate" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });

    try testing.expectEqualSlices(u8, &.{ 3, 0, 1, 2 }, Arr.rotate(&slice, 1));
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 0 }, Arr.rotate(&slice, 2));
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3 }, Arr.rotate(&slice, 1));
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3 }, Arr.rotate(&slice, 4));
    try testing.expectEqualSlices(u8, &.{ 3, 0, 1, 2 }, Arr.rotate(&slice, 5));
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3 }, Arr.rotate(&slice, -5));
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 0 }, Arr.rotate(&slice, -1));
}

test "rotateStart" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });

    try testing.expectEqualSlices(u8, &.{ 3, 0, 1, 2 }, Arr.rotateStart(&slice, 3));
}

test "rotateEnd" {
    const Arr = Array(u8);
    var slice = Arr.init(4);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3 });

    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 0 }, Arr.rotateEnd(&slice, 3));
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

test "insert" {
    const Arr = Array(u8);
    var slice = Arr.init(5);
    @memcpy(&slice, &[_]Arr.Element{ 0, 0, 1, 0, 0 });
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2, 0, 1 }, Arr.insert(&slice, 3, 1, &.{ 1, 2 }));
}

test "splice" {
    const Arr = Array(u8);
    var slice = Arr.init(8);
    @memcpy(&slice, &[_]Arr.Element{ 0, 1, 2, 3, 4, 5, 6, 7 });

    try testing.expectEqualSlices(
        u8,
        &.{ 0, 1, 2, 1, 0 },
        Arr.splice(&slice, 5, 3, 0, &.{ 1, 0 })[0..5],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 2, 4, 1, 0 },
        Arr.splice(&slice, 5, 0, 3, &.{ 1, 2, 4 })[0..5],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 2, 4, 8, 16 },
        Arr.splice(&slice, 6, 3, 3, &.{ 8, 16 })[0..5],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 4, 16 },
        Arr.splice(&slice, 5, 1, 3, &.{4})[0..3],
    );

    try testing.expectEqualSlices(
        u8,
        &.{ 1, 16 },
        Arr.splice(&slice, 3, 1, 1, &.{})[0..2],
    );
}
