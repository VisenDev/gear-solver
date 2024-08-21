const std = @import("std");

const GearFromRatioOptions = struct {
    min_spokes: u8 = 15,
    max_spokes: u8 = 85,
};

const num_solutions = 32;

pub fn deriveTwoGearsFromRatioPrecise(alloc: std.mem.Allocator, ratio: f128, opt: GearFromRatioOptions) ![num_solutions][2]Gear {
    const desired_decimal = ratio;

    //var best_gears = Gear{};
    var heap = std.PriorityQueue([2]Gear, f128, (struct {
        pub fn compare(desired: f128, a: [2]Gear, b: [2]Gear) std.math.Order {
            const diff_a = a[0].diffSeries(a[1], desired);
            const diff_b = b[0].diffSeries(b[1], desired);

            if (diff_a < diff_b) {
                return std.math.Order.lt;
            } else if (diff_a == diff_b) {
                return std.math.Order.eq;
            } else {
                return std.math.Order.gt;
            }
        }
    }).compare).init(alloc, desired_decimal);
    defer heap.deinit();

    for (opt.min_spokes..opt.max_spokes + 1) |input_a| {
        for (opt.min_spokes..opt.max_spokes + 1) |output_a| {
            for (opt.min_spokes..opt.max_spokes + 1) |input_b| {
                for (opt.min_spokes..opt.max_spokes + 1) |output_b| {
                    const gear_a = Gear{ .input_spokes = @intCast(input_a), .output_spokes = @intCast(output_a) };
                    const gear_b = Gear{ .input_spokes = @intCast(input_b), .output_spokes = @intCast(output_b) };
                    try heap.add(.{ gear_a, gear_b });

                    if (heap.count() > num_solutions) {
                        _ = heap.removeIndex(heap.count() - 1);
                    }
                }
            }
        }
    }

    var result: [num_solutions][2]Gear = undefined;
    for (&result) |*gear| {
        gear.* = heap.remove();
    }

    return result;
}

pub fn deriveTwoGearsFromRatio(alloc: std.mem.Allocator, ratio: f128, opt: GearFromRatioOptions) ![num_solutions][2]Gear {
    var adjusted = ratio;
    var adjustment: f128 = 1;

    if (ratio > 2) {
        adjustment = @ceil(@sqrt(ratio));
    }
    adjusted /= adjustment;

    const result_a = try deriveSingleGearFromRatio(alloc, adjusted, opt);
    const result_b = try deriveSingleGearFromRatio(alloc, adjustment, opt);

    var result: [num_solutions][2]Gear = undefined;
    for (&result, 0..) |_, i| {
        result[i][0] = result_a[i];
        result[i][1] = result_b[i];
    }
    return result;
}

pub fn deriveSingleGearFromRatio(alloc: std.mem.Allocator, ratio: f128, opt: GearFromRatioOptions) ![num_solutions]Gear {
    const desired_decimal = ratio;

    //var best_gears = Gear{};
    var heap = std.PriorityQueue(Gear, f128, (struct {
        pub fn compare(desired: f128, a: Gear, b: Gear) std.math.Order {
            const diff_a = a.diff(desired);
            const diff_b = b.diff(desired);

            if (diff_a < diff_b) {
                return std.math.Order.lt;
            } else if (diff_a == diff_b) {
                return std.math.Order.eq;
            } else {
                return std.math.Order.gt;
            }
        }
    }).compare).init(alloc, desired_decimal);
    defer heap.deinit();

    for (opt.min_spokes..opt.max_spokes + 1) |input| {
        for (opt.min_spokes..opt.max_spokes + 1) |output| {
            const gear = Gear{ .input_spokes = @intCast(input), .output_spokes = @intCast(output) };
            try heap.add(gear);

            if (heap.count() > num_solutions) {
                _ = heap.removeIndex(heap.count() - 1);
            }
        }
    }

    var result: [num_solutions]Gear = undefined;
    for (&result) |*gear| {
        gear.* = heap.remove();
    }

    return result;
}

pub const Gear = struct {
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
};

pub const mm_per_inch = 25.4;
pub const inch_per_mm = 0.03937008;

pub const ScrewGear = struct {
    mm_per_rotation: f128,

    pub fn initMilimeters(mm: f128) ScrewGear {
        return .{ .mm_per_rotation = mm };
    }

    pub fn initInches(inches: f128) ScrewGear {
        return .{ .mm_per_rotation = inches * mm_per_inch };
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

//test "calculateClosestGear" {
//    const desired_ratio: Ratio = .{ .input = 1, .output = 1.2384981 };
//    const options = try deriveGearFromRatio(std.testing.allocator, desired_ratio, 15, 115);
//
//    for (options, 0..) |option, i| {
//        std.debug.print("#{} best Gear: {}\n", .{ i, option });
//    }
//}
