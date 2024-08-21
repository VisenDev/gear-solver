const std = @import("std");

pub fn deriveGearFromRatio(alloc: std.mem.Allocator, ratio: Ratio, min_spokes: u8, max_spokes: u8) ![32]Gear {
    const desired_decimal = ratio.toDecimal();
    std.debug.print("desired decimal: {}\n\n", .{desired_decimal});

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

    for (min_spokes..max_spokes + 1) |input| {
        for (min_spokes..max_spokes + 1) |output| {
            const gear = Gear{ .input_spokes = @intCast(input), .output_spokes = @intCast(output) };
            try heap.add(gear);
        }
    }

    var result: [32]Gear = undefined;
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

test "calculateClosestGear" {
    const desired_ratio: Ratio = .{ .input = 1, .output = 1.2384981 };
    const options = try deriveGearFromRatio(std.testing.allocator, desired_ratio, 15, 115);

    for (options, 0..) |option, i| {
        std.debug.print("#{} best Gear: {}\n", .{ i, option });
    }
}
