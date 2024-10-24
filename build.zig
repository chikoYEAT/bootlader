const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.i386 },
    };

    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "bootloader",
        .root_source_file = .{ .path = "src/bootloader.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.setLinkerScriptPath(.{ .path = "linker.ld" });
    exe.code_model = .small;
    exe.red_zone = false;

    b.installArtifact(exe);

    const bin_out = b.cache_root.join(b.allocator, &.{ "bin", exe.out_filename }) catch |err| {
        std.debug.print("Error joining bin output path: {}\n", .{err});
        return;
    };

    const bin_bootloader = b.cache_root.join(b.allocator, &.{ "bin", "bootloader.bin" }) catch |err| {
        std.debug.print("Error joining bootloader output path: {}\n", .{err});
        return;
    };

    const objcopy_cmd = b.addSystemCommand(&[_][]const u8{
        "llvm-objcopy",
        "-O",
        "binary",
        bin_out,
        bin_bootloader,
    });
    objcopy_cmd.step.dependOn(&exe.step);

    const objcopy_step = b.step("objcopy", "Convert ELF to raw binary");
    objcopy_step.dependOn(&objcopy_cmd.step);
}
