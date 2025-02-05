const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

const DialogLevel = enum(c_int) {
    info,
    warn,
    err,
};

const DialogButtons = enum(c_int) {
    ok,
    ok_cancel,
    yes_no,
};

const MessageOptions = struct {
    level: DialogLevel = .info,
    buttons: DialogButtons = .ok,
};

pub fn message(text: [*:0]const u8, options: MessageOptions) i32 {
    return osdialog_message(@intFromEnum(options.level), @intFromEnum(options.buttons), text);
}
extern fn osdialog_message(level: c_int, buttons: c_int, message: [*c]const u8) c_int;

const PromptOptions = struct {
    level: DialogLevel = .info,
    default_text: [:0]const u8 = "",
};

pub fn prompt(allocator: Allocator, text: [*:0]const u8, options: PromptOptions) Allocator.Error!?[:0]u8 {
    if (osdialog_prompt(@intFromEnum(options.level), text, options.default_text)) |c_string| {
        defer std.c.free(c_string);
        return try allocator.dupeZ(u8, std.mem.span(@as([*c]u8, @ptrCast(c_string))));
    }
    return null;
}
extern fn osdialog_prompt(level: c_int, text: [*c]const u8, default_text: [*c]const u8) ?*anyopaque;

const osdialog_filter_patterns = extern struct {
    pattern: [*c]u8,
    next: ?*osdialog_filter_patterns,
};
const osdialog_filters = extern struct {
    name: [*c]u8,
    patterns: *osdialog_filter_patterns,
    next: ?*osdialog_filters,
};
extern fn osdialog_filters_parse(string: [*c]const u8) ?*osdialog_filters;
extern fn osdialog_filters_free(filters: ?*osdialog_filters) void;
//extern fn osdialog_filter_patterns_free(patterns: *osdialog_filter_patterns) void; // called by osdialog_filters_free()

const FileAction = enum(c_int) {
    open,
    open_dir,
    save,
};

pub const Filters = struct {
    filters: *osdialog_filters,

    pub fn init(patterns: [*:0]const u8) Filters {
        return Filters{
            .filters = osdialog_filters_parse(patterns).?, // library does not check if malloc failed
        };
    }

    pub fn deinit(self: Filters) void {
        osdialog_filters_free(self.filters);
    }
};

const FileOptions = struct {
    path: ?[*:0]const u8 = null,
    filename: ?[*:0]const u8 = null,
    filters: ?Filters = null,
};

pub fn file(allocator: Allocator, action: FileAction, options: FileOptions) Allocator.Error!?[:0]u8 {
    if (osdialog_file(@intFromEnum(action), options.path, options.filename, if (options.filters) |filters| filters.filters else null)) |c_string| {
        defer std.c.free(c_string);
        return try allocator.dupeZ(u8, std.mem.span(@as([*c]u8, @ptrCast(c_string))));
    }
    return null;
}
extern fn osdialog_file(action: c_int, path: [*c]const u8, filename: [*c]const u8, filters: ?*osdialog_filters) ?*anyopaque;

pub const Color = osdialog_color;
const osdialog_color = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

const ColorOptions = struct {
    color: Color = Color{},
    opacity: bool = false,
};

pub fn color(options: ColorOptions) ?Color {
    var col: osdialog_color = options.color;
    return if (osdialog_color_picker(&col, @intFromBool(options.opacity)) == 0) null else col;
}
extern fn osdialog_color_picker(color: *osdialog_color, enable_opacity: c_int) c_int;

const osdialog_save_callback = *const fn () callconv(.C) ?*anyopaque;
const SaveCallback = osdialog_save_callback;
pub fn setSaveCallback(callback: SaveCallback) void {
    osdialog_set_save_callback(callback);
}
extern fn osdialog_set_save_callback(callback: osdialog_save_callback) void;

const osdialog_restore_callback = *const fn (?*anyopaque) callconv(.C) void;
const RestoreCallback = osdialog_restore_callback;
pub fn setRestoreCallback(callback: RestoreCallback) void {
    osdialog_set_restore_callback(callback);
}
extern fn osdialog_set_restore_callback(callback: osdialog_restore_callback) void;

test "all" {
    const print = std.debug.print;
    const allocator = std.testing.allocator;

    const Callbacks = struct {
        pub fn save() callconv(.C) ?*anyopaque {
            print("save\n", .{});
            return null;
        }

        pub fn restore(data: ?*anyopaque) callconv(.C) void {
            _ = data;
            print("restore\n", .{});
        }
    };

    setSaveCallback(Callbacks.save);
    setRestoreCallback(Callbacks.restore);

    {
        print("message info\n", .{});
        var result = message("Info こんにちは", .{ .level = .info, .buttons = .ok });
        print("\t{d}\n", .{result});

        print("message warning\n", .{});
        result = message("Warning こんにちは", .{ .level = .warn, .buttons = .ok_cancel });
        print("\t{d}\n", .{result});

        print("message error\n", .{});
        result = message("Error こんにちは", .{ .level = .err, .buttons = .yes_no });
        print("\t{d}\n", .{result});
    }

    {
        print("prompt info\n", .{});
        if (try prompt(allocator, "Info", .{ .level = .info, .default_text = "default text" })) |result| {
            defer allocator.free(result);
            print("\t{s}\n", .{result});
        } else {
            print("\tCanceled\n", .{});
        }

        print("prompt warning\n", .{});
        if (try prompt(allocator, "Warning", .{ .level = .warn, .default_text = "default text" })) |result| {
            defer allocator.free(result);
            print("\t{s}\n", .{result});
        } else {
            print("\tCanceled\n", .{});
        }

        print("prompt error\n", .{});
        if (try prompt(allocator, "Error", .{ .level = .err, .default_text = "default text" })) |result| {
            defer allocator.free(result);
            print("\t{s}\n", .{result});
        } else {
            print("\tCanceled\n", .{});
        }
    }

    {
        print("file open dir\n", .{});
        if (try file(allocator, .open_dir, .{})) |pathname| {
            defer allocator.free(pathname);
            print("\t{s}\n", .{pathname});
        } else {
            print("\tCanceled\n", .{});
        }

        print("file open\n", .{});
        if (try file(allocator, .open, .{})) |filepath| {
            defer allocator.free(filepath);
            print("\t{s}\n", .{filepath});
        } else {
            print("\tCanceled\n", .{});
        }

        print("file save\n", .{});
        if (try file(allocator, .save, .{})) |filepath| {
            defer allocator.free(filepath);
            print("\t{s}\n", .{filepath});
        } else {
            print("\tCanceled\n", .{});
        }

        const osdialog_path = "./libs/osdialog";
        const filename = "こんにちは";
        const filters = Filters.init("Source:c,cpp,m;Header:h,hpp");
        defer filters.deinit();

        print("file open dir in cwd\n", .{});
        if (try file(allocator, .open_dir, .{ .path = osdialog_path, .filename = filename })) |pathname| {
            defer allocator.free(pathname);
            print("\t{s}\n", .{pathname});
        } else {
            print("\tCanceled\n", .{});
        }

        print("file open in cwd\n", .{});
        if (try file(allocator, .open, .{ .path = osdialog_path, .filename = filename, .filters = filters })) |filepath| {
            defer allocator.free(filepath);
            print("\t{s}\n", .{filepath});
        } else {
            print("\tCanceled\n", .{});
        }

        print("file save in cwd\n", .{});
        if (try file(allocator, .save, .{ .path = osdialog_path, .filename = filename, .filters = filters })) |filepath| {
            defer allocator.free(filepath);
            print("\t{s}\n", .{filepath});
        } else {
            print("\tCanceled\n", .{});
        }
    }

    {
        const init_color = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };

        print("color picker\n", .{});
        if (color(.{ .color = init_color })) |col| {
            print("\t#{x:0>2}{x:0>2}{x:0>2}{x:0>2}\n", .{ col.r, col.g, col.b, col.a });
        }

        print("color picker with opacity\n", .{});
        if (color(.{ .color = init_color, .opacity = true })) |col| {
            print("\t#{x:0>2}{x:0>2}{x:0>2}{x:0>2}\n", .{ col.r, col.g, col.b, col.a });
        }
    }
}
