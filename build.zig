const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("root", .{
        .root_source_file = b.path("src/zosdialog.zig"),
    });

    const osd = b.addStaticLibrary(.{
        .name = "osdialog",
        .target = target,
        .optimize = optimize,
    });
    osd.linkLibC();
    osd.addIncludePath(b.path("libs/osdialog"));
    osd.addCSourceFile(.{
        .file = b.path("libs/osdialog/osdialog.c"),
        .flags = &.{ "-std=c99", "-fno-sanitize=undefined" },
    });
    switch (builtin.os.tag) {
        .windows => {
            osd.addCSourceFile(.{ .file = b.path("libs/osdialog/osdialog_win.c") });
            osd.linkSystemLibrary("comdlg32");
        },
        .linux => {
            osd.addCSourceFile(.{ .file = b.path("libs/osdialog/osdialog_gtk3.c") });
            osd.linkSystemLibrary("gtk+-3.0");
        },
        .macos => {
            osd.addCSourceFile(.{ .file = b.path("libs/osdialog/osdialog_mac.m") });
            osd.linkFramework("AppKit");
        },
        else => {
            @panic("OS not supported.");
        },
    }
    b.installArtifact(osd);

    const test_step = b.step("test", "Run zosdialog tests");
    const tests = b.addTest(.{
        .name = "zosdialog-tests",
        .root_source_file = b.path("src/zosdialog.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibC();
    tests.linkLibrary(osd);
    b.installArtifact(tests);
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
