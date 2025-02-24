# zosdialog
Zig build package and bindings for [osdialog](https://github.com/AndrewBelt/osdialog) written by Andrew Belt.

Tested with `0.14.0-dev.2577+271452d22` on Linux (Wayland/X11) and Windows 11.
## Installation
Add the library to your dependencies in `build.zig.zon`.
```zig
.{
    // ...
    .dependencies = .{
        // ...
        .zosdialog = .{
            .url = "https://github.com/l3x61/zosdialog/archive/refs/tags/0.1.5.tar.gz",
            .hash = "1220caf19fda52fc11fce5c0eed252aa4c0c6d480aad472d3b545c388961bc33d640",
        },
        // ...
    },
    // ...
}
```
Add the following to your `build.zig`
```zig
// ...
const zosdialog = b.dependency("zosdialog", .{ .target = target });
exe.root_module.addImport("zosdialog", zosdialog.module("root"));
exe.linkLibrary(zosdialog.artifact("zosdialog"));
// ...
b.installArtifact(exe);
```

## Usage
[Example](example)
