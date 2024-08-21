const std = @import("std");
const dvui = @import("dvui");
const RaylibBackend = @import("RaylibBackend");
const ray = RaylibBackend.c;

pub const gear = @import("gear.zig");

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
    var candidates: [32]gear.Gear = undefined;

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
            candidates = try gear.deriveGearFromRatio(
                std.heap.c_allocator,
                .{ .input = 1, .output = desired_ratio },
                25,
                75,
            );
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
                    "Rank #{}:  {} / {}      deviation: {d}",
                    .{ i + 1, gr.output_spokes, gr.input_spokes, gr.diff(desired_ratio) },
                    .{ .id_extra = i },
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

fn colorPicker(result: *dvui.Color) !void {
    _ = dvui.spacer(@src(), .{ .w = 10, .h = 10 }, .{});
    {
        var overlay = try dvui.overlay(@src(), .{ .min_size_content = .{ .w = 100, .h = 100 } });
        defer overlay.deinit();

        const bounds = RaylibBackend.dvuiRectToRaylib(overlay.data().contentRectScale().r);
        var c_color: ray.Color = RaylibBackend.dvuiColorToRaylib(result.*);
        _ = ray.GuiColorPicker(bounds, "Pick Color", &c_color);
        result.* = RaylibBackend.raylibColorToDvui(c_color);
    }

    const color_hex = try result.toHexString();

    {
        var hbox = try dvui.box(@src(), .horizontal, .{});
        defer hbox.deinit();

        try dvui.labelNoFmt(@src(), &color_hex, .{
            .color_text = .{ .color = result.* },
            .gravity_y = 0.5,
        });

        const copy = try dvui.button(@src(), "Copy", .{}, .{});

        if (copy) {
            try dvui.clipboardTextSet(&color_hex);
            try dvui.toast(@src(), .{ .message = "Copied!" });
        }
    }
}

test "all" {
    std.testing.refAllDecls(@This());
}
