const std = @import("std");
const dvui = @import("dvui");
const RaylibBackend = @import("RaylibBackend");
const ray = RaylibBackend.c;
//n

pub const gear = @import("gear.zig");
pub const sim = @import("simulation.zig");

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
    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{ .theme = &dvui.Theme.AdwaitaDark });
    defer win.deinit();

    //
    var desired_ratio: f128 = 1;
    var show_candidates = false;
    var candidates: [gear.num_solutions]gear.Gear = undefined;

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
            var box = try dvui.box(@src(), .horizontal, .{});
            defer box.deinit();

            try dvui.label(@src(), "Desired Ratio", .{}, .{});

            const result = try dvui.textEntryNumber(@src(), f128, .{}, .{});
            if (result == .Valid) {
                desired_ratio = result.Valid;
            }
        }

        //ray.DrawText("Congrats! You Combined Raylib, Raygui and DVUI!", 20, 400, 20, ray.RAYWHITE);
        if (try dvui.button(@src(), "Calculate", .{}, .{})) {
            show_candidates = true;
            candidates = gear.gearFromRatio(desired_ratio, .{});
        }

        _ = dvui.spacer(@src(), .{ .h = 20 }, .{});
        if (show_candidates) {
            try dvui.label(
                @src(),
                "Gear Rankings",
                .{},
                .{ .background = true, .border = dvui.Rect.all(1), .expand = .horizontal },
            );

            var box = try dvui.box(@src(), .vertical, .{ .background = true, .border = dvui.Rect.all(1), .expand = .both });
            defer box.deinit();

            var scroll = try dvui.scrollArea(@src(), .{}, .{ .expand = .both });
            defer scroll.deinit();

            var vbox = try dvui.box(@src(), .vertical, .{ .min_size_content = .{ .h = 100 } });
            defer vbox.deinit();

            for (&candidates, 0..) |gr, i| {
                try dvui.label(
                    @src(),
                    "Rank #{d:0>2}: Gear = {} / {}       Ratio = {d: <8.8}        Error Per Rotation = {d:.5}",
                    .{ i + 1, gr.output_spokes, gr.input_spokes, gr.toRatio().toDecimal(), gr.diff(desired_ratio) },
                    .{ .id_extra = i, .font = .{ .name = "Hack", .size = 15 } },
                );
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
