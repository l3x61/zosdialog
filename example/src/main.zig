const std = @import("std");
const print = std.debug.print;

const zosd = @import("zosdialog");

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
pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    zosd.setSaveCallback(Callbacks.save);
    zosd.setRestoreCallback(Callbacks.restore);

    print("message info\n", .{});
    const result = zosd.message("Info こんにちは", .{ .level = .info, .buttons = .ok });
    print("\t{d}\n", .{result});

    print("prompt info\n", .{});
    if (try zosd.prompt(allocator, "Info", .{ .level = .info, .default_text = "default text" })) |input| {
        defer allocator.free(input);
        print("\t{s}\n", .{input});
    } else {
        print("\tCanceled\n", .{});
    }

    const osdialog_path = "./libs/osdialog";
    const filename = "こんにちは";
    const filters = zosd.Filters.init("Source:c,cpp,m;Header:h,hpp");
    defer filters.deinit();

    print("file open dir in cwd\n", .{});
    if (try zosd.file(allocator, .open_dir, .{ .path = osdialog_path, .filename = filename })) |pathname| {
        defer allocator.free(pathname);
        print("\t{s}\n", .{pathname});
    } else {
        print("\tCanceled\n", .{});
    }

    print("file open in cwd\n", .{});
    if (try zosd.file(allocator, .open, .{ .path = osdialog_path, .filename = filename, .filters = filters })) |filepath| {
        defer allocator.free(filepath);
        print("\t{s}\n", .{filepath});
    } else {
        print("\tCanceled\n", .{});
    }

    print("file save in cwd\n", .{});
    if (try zosd.file(allocator, .save, .{ .path = osdialog_path, .filename = filename, .filters = filters })) |filepath| {
        defer allocator.free(filepath);
        print("\t{s}\n", .{filepath});
    } else {
        print("\tCanceled\n", .{});
    }
    const init_color = zosd.Color{ .r = 255, .g = 0, .b = 255, .a = 255 };

    print("color picker with opacity\n", .{});
    if (zosd.color(.{ .color = init_color, .opacity = true })) |col| {
        print("\t#{x:0>2}{x:0>2}{x:0>2}{x:0>2}\n", .{ col.r, col.g, col.b, col.a });
    }
}
