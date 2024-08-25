const std = @import("std");
const dvui = @import("dvui");
const RaylibBackend = @import("RaylibBackend");
const ray = RaylibBackend.c;
//n

pub const gear = @import("gear.zig");
pub const sim = @import("simulation.zig");

const border_opt = dvui.Options{ .expand = .horizontal, .border = dvui.Rect.all(1), .background = true };

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    defer _ = gpa_instance.deinit();

    // create OS window directly with raylib
    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.SetConfigFlags(ray.FLAG_VSYNC_HINT);
    ray.InitWindow(800, 600, "Gear Solver");
    defer ray.CloseWindow();

    // init Raylib backend
    var backend = RaylibBackend.init();
    defer backend.deinit();
    backend.log_events = true;

    // init dvui Window (maps onto a single OS window)
    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{ .theme = &dvui.Theme.AdwaitaLight });
    defer win.deinit();

    var simulation = sim.Simulation.init(gpa);
    defer simulation.deinit();
    var simulation_gear = gear.Gear{};
    var output_constraint_type: usize = 0;
    var solution: ?gear.Gear = null;

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();

        // marks the beginning of a frame for dvui, can call dvui functions after this
        try win.begin(std.time.nanoTimestamp());

        // send all Raylib events to dvui for processing
        _ = try backend.addAllEvents(&win);

        if (backend.shouldBlockRaylibInput()) {
            ray.GuiLock();
        } else {
            ray.GuiUnlock();
        }

        ray.ClearBackground(RaylibBackend.dvuiColorToRaylib(dvui.themeGet().color_fill_window));

        {
            var main_box = try dvui.box(@src(), .vertical, .{
                .background = true,
                .border = dvui.Rect.all(1),
                .expand = .vertical,
                .min_size_content = .{ .w = 250 },
            });
            defer main_box.deinit();

            //=======INPUT CONSTRAINT=======
            if (try dvui.expander(@src(), "Input Rotations", .{}, border_opt)) {
                var box = try dvui.box(@src(), .vertical, .{ .expand = .horizontal });
                defer box.deinit();

                const result = try dvui.textEntryNumber(@src(), f128, .{}, .{});
                if (result == .Valid) {
                    simulation.input = result.Valid;
                }
            }

            //=======GEARTRAIN DISPLAY========
            {
                var vbox = try dvui.box(@src(), .vertical, .{ .expand = .horizontal });
                defer vbox.deinit();

                for (simulation.geartrain.items, 0..) |geartrain_gear, i| {
                    try dvui.label(@src(), "Gear: {} / {}", .{ geartrain_gear.input_spokes, geartrain_gear.output_spokes }, .{
                        .id_extra = i,
                    });
                }
            }

            //======NEW GEARTRAIN GEAR INPUT========
            if (try dvui.expander(@src(), "Add Gear", .{}, border_opt)) {
                var vbox = try dvui.box(@src(), .vertical, .{ .expand = .horizontal });
                defer vbox.deinit();

                {
                    var hbox = try dvui.box(@src(), .vertical, .{});
                    defer hbox.deinit();

                    try dvui.label(@src(), "Input Gear Spokes:", .{}, .{});
                    const input_spokes = try dvui.textEntryNumber(@src(), u8, .{}, .{});

                    if (input_spokes == .Valid) {
                        simulation_gear.input_spokes = input_spokes.Valid;
                    }
                }

                {
                    var hbox = try dvui.box(@src(), .vertical, .{});
                    defer hbox.deinit();

                    try dvui.label(@src(), "Output Gear Spokes:", .{}, .{});
                    const output_spokes = try dvui.textEntryNumber(@src(), u8, .{}, .{});
                    if (output_spokes == .Valid) {
                        simulation_gear.output_spokes = output_spokes.Valid;
                    }
                }

                if (try dvui.button(@src(), "Confirm New Gear", .{}, .{})) {
                    try simulation.geartrain.append(simulation_gear);
                    simulation_gear = gear.Gear{};
                }
            }

            //======SET OUTPUT CONSTRAINT========
            if (try dvui.expander(@src(), "Desired Output", .{}, border_opt)) {
                var vbox = try dvui.box(@src(), .vertical, .{
                    .expand = .horizontal,
                });
                defer vbox.deinit();

                _ = try dvui.dropdown(@src(), std.meta.fieldNames(sim.OutputConstraintTypes), &output_constraint_type, .{});

                switch (output_constraint_type) {
                    0 => {
                        if (std.meta.activeTag(simulation.output) != .rotational) {
                            simulation.output = .{ .rotational = 1 };
                        }

                        try dvui.label(@src(), "Rotations: ", .{}, .{});
                        const rotations = try dvui.textEntryNumber(@src(), f128, .{}, .{});

                        if (rotations == .Valid) {
                            simulation.output = .{ .rotational = rotations.Valid };
                        }
                    },
                    1 => {
                        if (std.meta.activeTag(simulation.output) != .linear) {
                            simulation.output = .{ .linear = undefined };
                        }

                        try dvui.label(@src(), "Screw Gear Actual Motion: ", .{}, .{});
                        const actual = try dvui.textEntryNumber(@src(), f128, .{}, .{});

                        if (actual == .Valid) {}

                        try dvui.label(@src(), "Desired Screw Gear Motion", .{}, .{});
                        const desired = try dvui.textEntryNumber(@src(), f128, .{}, .{});

                        if (desired == .Valid) {
                            //simulation.output = .{ .rotational = desired.Valid };
                        }
                    },
                    else => unreachable,
                }
            }

            //var line = try dvui.box(@src(), .vertical, .{
            //    .background = true,
            //    .border = dvui.Rect.all(1),
            //    .expand = .horizontal,
            //});
            //line.deinit();

            if (try dvui.button(@src(), "Solve", .{}, border_opt)) {
                solution = gear.gearFromRatio(simulation.findRatioToCompensate(), .{ .min_spokes = 25, .max_spokes = 64 })[0];
            }

            if (solution) |sol| {
                try dvui.label(@src(), "{}", .{sol}, .{});
            }
        }

        _ = try win.end(.{});

        // cursor management
        if (win.cursorRequestedFloating()) |cursor| {
            backend.setCursor(cursor);
        } else {
            backend.setCursor(.arrow);
        }

        ray.EndDrawing();
    }
}

test "all" {
    std.testing.refAllDecls(@This());
}
