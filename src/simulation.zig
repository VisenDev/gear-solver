const gr = @import("gear.zig");
const std = @import("std");

pub const Solution = struct {
    value: ?gr.Gear = null,
    preceding_index: usize = 0,
};

pub const Simulation = struct {
    input: f128 = 1,
    output: OutputConstraint = undefined,
    geartrain: std.ArrayList(gr.Gear),
    compensation_index: ?usize = null,

    pub fn findRatioToCompensate(self: Simulation) f128 {
        const desired_total_ratio = gr.Ratio{ .input = self.input, .output = self.output.getNeededOutputValue() };
        const current_ratio = gr.calculateTotalRatio(self.geartrain.items);
        const solution = gr.Ratio{ .input = current_ratio.toDecimal(), .output = desired_total_ratio.toDecimal() };
        return solution.toDecimal();
    }

    pub fn addGear(self: *Simulation, gear: gr.Gear) !void {
        try self.geartrain.append(gear);
    }

    pub fn init(a: std.mem.Allocator) Simulation {
        return .{
            .geartrain = std.ArrayList(gr.Gear).init(a),
        };
    }

    pub fn deinit(self: *Simulation) void {
        self.geartrain.deinit();
    }
};

pub const OutputConstraintTypes = enum { rotational, linear };
pub const OutputConstraint = union(OutputConstraintTypes) {
    rotational: f128,
    linear: struct {
        actual: gr.ScrewGear,
        desired: gr.ScrewGear,
    },

    pub fn getNeededOutputValue(self: OutputConstraint) f128 {
        switch (self) {
            .rotational => {
                return self.rotational;
            },
            .linear => |screw| {
                const desired_travel = screw.desired.getValueMM();
                const actual_travel = screw.actual.getValueMM();

                const compensation = gr.Ratio{ .input = actual_travel, .output = desired_travel };
                return compensation.toDecimal();
            },
        }
    }
};

test "solveBasic" {
    var simulation = Simulation.init(std.testing.allocator, .{ .rotational = 2 });
    defer simulation.deinit();
    const solution = simulation.findRatioToCompensate();
    try std.testing.expect(solution == 2);
}

test "solve" {
    var simulation = Simulation.init(std.testing.allocator, .{ .rotational = 7 });
    defer simulation.deinit();
    try simulation.addGear(.{ .input_spokes = 10, .output_spokes = 7 });
    try simulation.addGear(.{ .input_spokes = 5, .output_spokes = 5 });
    const solution = simulation.findRatioToCompensate();
    try std.testing.expect(solution == 10);
}

test "solveScrew" {
    var simulation = Simulation.init(std.testing.allocator, .{
        .linear = .{
            .desired_mm_per_rotation = 2,
            .screwgear = .{ .mm_per_rotation = 1 },
        },
    });
    defer simulation.deinit();
    simulation.input = 10;
    try simulation.addGear(.{ .input_spokes = 5, .output_spokes = 5 });
    const solution = simulation.findRatioToCompensate();
    try std.testing.expect(solution == 0.2);
}

test "solveScrewConversion" {
    var simulation = Simulation.init(std.testing.allocator, .{
        .linear = .{
            .desired_mm_per_rotation = 2 * gr.mm_per_inch,
            .screwgear = .{ .mm_per_rotation = 1 },
        },
    });
    defer simulation.deinit();
    simulation.input = 10;
    try simulation.addGear(.{ .input_spokes = 5, .output_spokes = 5 });
    const solution = simulation.findRatioToCompensate();
    try std.testing.expect(solution == (0.2 * gr.mm_per_inch));
}

test "solveScrewGear" {
    var simulation = Simulation.init(std.testing.allocator, .{
        .linear = .{
            .desired_mm_per_rotation = 2 * gr.mm_per_inch,
            .screwgear = .{ .mm_per_rotation = 1 },
        },
    });
    defer simulation.deinit();
    simulation.input = 10;
    try simulation.addGear(.{ .input_spokes = 35, .output_spokes = 50 });
    try simulation.addGear(.{ .input_spokes = 35, .output_spokes = 133 });

    const solution = gr.gearFromRatio(simulation.findRatioToCompensate(), .{});

    std.debug.print("Desired: {d}\n", .{simulation.findRatioToCompensate()});
    std.debug.print("Result: {any}\n", .{solution[0]});
    std.debug.print("     => {d}\n", .{solution[0].toRatio().toDecimal()});

    //std.debug.print(
    //    "Solution Precise: {any}\n    => {d}\n",
    //    .{ solutionv2[0], (solutionv2[0][0].toRatio().toDecimal() * solutionv2[0][1].toRatio().toDecimal()) },
    //);

    //const solution = try gr.deriveTwoGearsFromRatio(
    //    std.testing.allocator,
    //    simulation.findRatioToCompensate(),
    //    .{ .min_spokes = 25, .max_spokes = 75, .close_enough = 0.0001 },
    //);

    //const solutionv2 = try gr.deriveTwoGearsFromRatioPrecise(
    //    std.testing.allocator,
    //    simulation.findRatioToCompensate(),
    //    .{ .min_spokes = 25, .max_spokes = 75, .close_enough = 0.0001 },
    //);

    //std.debug.print("Found ratio: {d}\n", .{simulation.findRatioToCompensate()});
    //std.debug.print(
    //    "Solution Approx: {any}\n    => {d}\n",
    //    .{ solution[0], (solution[0][0].toRatio().toDecimal() * solution[0][1].toRatio().toDecimal()) },
    //);

    //std.debug.print(
    //    "Solution Precise: {any}\n    => {d}\n",
    //    .{ solutionv2[0], (solutionv2[0][0].toRatio().toDecimal() * solutionv2[0][1].toRatio().toDecimal()) },
    //);
}
