# Arrayz

A Zig library for performing array operations with zero heap allocations.

## Features

The array operations implemented include:

- Concatenation
- Joining
- Insertions
- Shifting
- Reversal
- Mapping
- Filtration
- Splicing
- Sliding
- Rotatiion
- Trimming
- Padding
- Searcing
- Logical Operations
  - ForAll
  - ThereExists

## Usage

### Requirements

- Minimum Zig version: `0.15.1`

### Installation

```sh
zig fetch --save git+https://github.com/mishieck/arrayz  
```

### Build File Update

Add the following code snippet to your `build.zig` file.

```zig
const arrayz = b.dependency("arrayz", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("arrayz", arrayz.module("arrayz"));
```
### Example

```zig
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
```
