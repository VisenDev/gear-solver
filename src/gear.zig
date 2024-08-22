const std = @import("std");

const GearFromRatioOptions = struct {
    min_spokes: u8 = 15,
    max_spokes: u8 = 85,
};

pub const num_solutions = 150;

pub fn processAllGears() [num_ratios]RatioCacheEntry {
    var result: [num_ratios]RatioCacheEntry = undefined;

    var i: usize = 0;
    for (Gear.min_spokes..Gear.max_spokes) |input| {
        for (Gear.min_spokes..Gear.max_spokes) |output| {
            const gear = Gear{ .input_spokes = @intCast(input), .output_spokes = @intCast(output) };
            const ratio = gear.toRatio().toDecimal();
            result[i] = .{ .gear = gear, .ratio = ratio };
            i += 1;
        }
    }

    std.sort.heap(RatioCacheEntry, &result, {}, (struct {
        pub fn lessThanFn(_: void, a: RatioCacheEntry, b: RatioCacheEntry) bool {
            return (a.ratio < b.ratio);
        }
    }).lessThanFn);
    return result;
}

pub const Gear = struct {
    pub const max_spokes = 128;
    pub const min_spokes = 8;
    input_spokes: u8 = 1,
    output_spokes: u8 = 1,

    pub fn toRatio(self: @This()) Ratio {
        std.debug.assert(self.input_spokes != 0 and self.output_spokes != 0);
        const basic: Ratio = .{ .input = @floatFromInt(self.input_spokes), .output = @floatFromInt(self.output_spokes) };
        return .{ .input = 1, .output = basic.output / basic.input };
    }

    pub fn diff(self: Gear, target: f128) f128 {
        return @abs(target - self.toRatio().toDecimal());
    }

    pub fn diffSeries(self: Gear, other: Gear, target: f128) f128 {
        return @abs(target - (self.toRatio().toDecimal() * other.toRatio().toDecimal()));
    }

    pub fn withinBounds(self: Gear, opt: GearFromRatioOptions) bool {
        return self.input_spokes >= opt.min_spokes and self.input_spokes <= opt.max_spokes and
            self.output_spokes >= opt.min_spokes and self.output_spokes <= opt.max_spokes;
    }
};

pub const mm_per_inch = 25.4;
pub const inch_per_mm = 0.03937008;

pub const Units = enum { mm, inch };

pub const ScrewGear = struct {
    motion_per_rotation: f128,
    units: Units,

    pub fn getValueMM(self: ScrewGear) f128 {
        switch (self.units) {
            .mm => {
                return self.motion_per_rotation;
            },
            .inch => {
                return self.motion_per_rotation * mm_per_inch;
            },
        }
    }
};

pub const Ratio = struct {
    input: f128 = 1,
    output: f128 = 1,

    pub fn multiplyByGear(self: *Ratio, gear: Gear) void {
        self.multiplyByRatio(gear.toRatio());
    }

    pub fn multiplyByRatio(self: *Ratio, ratio: Ratio) void {
        self.input *= ratio.input;
        self.output *= ratio.output;
    }

    pub fn toDecimal(self: Ratio) f128 {
        return self.output / self.input;
    }
};

pub fn calculateTotalRatio(gears: []const Gear) Ratio {
    var result = Ratio{};

    for (gears) |gear| {
        result.multiplyByGear(gear);
    }

    return result;
}

pub const RatioCacheEntry = struct {
    ratio: f128,
    gear: Gear,
};

pub const num_ratios = (Gear.max_spokes - Gear.min_spokes) * (Gear.max_spokes - Gear.min_spokes);

pub fn binarySearch(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (@TypeOf(context), T) std.math.Order,
) usize {
    var low: usize = 0;
    var high: usize = items.len;

    while (low < high) {
        // Avoid overflowing in the midpoint calculation
        const mid = low + (high - low) / 2;
        switch (compareFn(context, items[mid])) {
            .eq => return mid,
            .lt => low = mid + 1, // item too small
            .gt => high = mid, // item too big
        }
    }
    return low;
}

pub fn gearFromRatio(ratio: f128, opt: GearFromRatioOptions) [num_solutions]Gear {
    const RATIOS: [num_ratios]RatioCacheEntry = std.mem.bytesToValue([num_ratios]RatioCacheEntry, @import("options").ratios);
    const median: i128 = binarySearch(RatioCacheEntry, &RATIOS, ratio, (struct {
        pub fn compare(key: f128, item: RatioCacheEntry) std.math.Order {
            if (key > item.ratio) {
                return .lt;
            } else if (key == item.ratio) {
                return .eq;
            } else {
                return .gt;
            }
        }
    }).compare);

    var result: [num_solutions]Gear = .{RATIOS[@intCast(median)].gear} ** num_solutions;
    var i: usize = 1;
    var offset: i64 = 1;
    var mode: i8 = 1;
    while (i < result.len) {
        const index: usize = @intCast(median + (offset * mode));
        if (RATIOS[index].gear.withinBounds(opt)) {
            result[i] = RATIOS[index].gear;
            i += 1;
        }
        if (mode == -1) {
            offset += 1;
            mode = 1;
        } else {
            mode = -1;
        }
    }

    return result;
}

test "calculateTotalRatio_1" {
    const gears = [_]Gear{
        .{ .input_spokes = 10, .output_spokes = 20 },
    };
    try std.testing.expect(std.meta.eql(calculateTotalRatio(&gears), Ratio{ .input = 1, .output = 2 }));
}

test "calculateTotalRatio_2" {
    const gears = [_]Gear{
        .{ .input_spokes = 10, .output_spokes = 20 },
        .{ .input_spokes = 20, .output_spokes = 20 },
        .{ .input_spokes = 20, .output_spokes = 10 },
    };
    try std.testing.expect(std.meta.eql(calculateTotalRatio(&gears), Ratio{ .input = 1, .output = 1 }));
}

test "calculateTotalRatio_3" {
    const gears = [_]Gear{
        .{ .input_spokes = 5, .output_spokes = 15 },
        .{ .input_spokes = 30, .output_spokes = 20 },
    };
    try std.testing.expect(std.meta.eql(calculateTotalRatio(&gears), Ratio{ .input = 1, .output = 2 }));
}
