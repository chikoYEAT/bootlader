const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.i386 },
    };

    const create_image = b.addSystemCommand(&[_][]const u8{
        "dd",
        "if=/dev/zero",
        "of=./disk.img",
        "bs=1M",
        "count=20",
        "status=none",
    });

    const format_disk = b.addSystemCommand(&[_][]const u8{
        "mkfs.fat",
        "-F",
        "12",
        "-n",
        "BOOTDISK",
        "./disk.img",
    });
    format_disk.step.dependOn(&create_image.step);

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
    exe.pie = false;
    exe.force_pic = false;

    const install_exe = b.addInstallArtifact(exe, .{});

    // Convert the ELF to binary
    const objcopy_cmd = b.addSystemCommand(&[_][]const u8{
        "llvm-objcopy",
        "-O",
        "binary",
        "--set-section-flags",
        ".bss=alloc,load,contents",
        "--set-section-flags",
        ".data=alloc,load,contents",
        "zig-out/bin/bootloader",
        "zig-out/bin/bootloader.bin",
    });
    objcopy_cmd.step.dependOn(&install_exe.step);

    // Pad the bootloader to exactly 512 bytes
    const pad_bootloader = b.addSystemCommand(&[_][]const u8{
        "dd",
        "if=zig-out/bin/bootloader.bin",
        "of=zig-out/bin/bootloader.img",
        "bs=512",
        "count=1",
        "conv=sync",
        "status=none",
    });
    pad_bootloader.step.dependOn(&objcopy_cmd.step);

    // Write the padded bootloader to the disk image
    const write_bootloader = b.addSystemCommand(&[_][]const u8{
        "dd",
        "if=zig-out/bin/bootloader.img",
        "of=./disk.img",
        "bs=512",
        "count=1",
        "conv=notrunc",
        "status=none",
    });

    write_bootloader.step.dependOn(&pad_bootloader.step);
    write_bootloader.step.dependOn(&create_image.step);
    write_bootloader.step.dependOn(&format_disk.step);
    // Make the disk image readable
    const chmod_cmd = b.addSystemCommand(&[_][]const u8{
        "chmod",
        "644",
        "./disk.img",
    });
    chmod_cmd.step.dependOn(&write_bootloader.step);

    const build_disk = b.step("disk", "Create bootable disk image");
    build_disk.dependOn(&chmod_cmd.step);

    // Add a run step that specifies raw format explicitly
    const run_qemu = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-drive",
        "file=disk.img,format=raw,if=floppy",
        "-drive",
        "file=fat:rw:./test_files,format=raw,if=ide", // This will mount a directory as a disk
        "-monitor",
        "stdio",
    });
    run_qemu.step.dependOn(&chmod_cmd.step);

    const run_step = b.step("run", "Run QEMU");
    run_step.dependOn(&run_qemu.step);
}
