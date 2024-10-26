const std = @import("std");

const BiosParameterBlock = extern struct {
    jmp_1: u8,
    jmp_2: u8,
    jmp_3: u8,
    oem_1: u8,
    oem_2: u8,
    oem_3: u8,
    oem_4: u8,
    oem_5: u8,
    oem_6: u8,
    oem_7: u8,
    oem_8: u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_fats: u8,
    root_entries: u16,
    total_sectors: u16,
    media_descriptor: u8,
    sectors_per_fat: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    large_sector_count: u32,
};

const VideoMode = struct {
    const SCREEN_WIDTH = 80;
    const SCREEN_HEIGHT = 25;
    const VIDEO_MEMORY: usize = 0xB8000;
};

pub const MenuEntry = extern struct {
    name: [*:0]const u8,
    description: [*:0]const u8,
};

export var selected_entry: u8 = 0;
export var menu_entries = [_]MenuEntry{
    .{ .name = "Boot from Primary Hard Drive", .description = "Boot from first detected hard drive" },
    .{ .name = "Boot from Floppy Drive", .description = "Boot from floppy disk if present" },
};

export var bpb: BiosParameterBlock align(1) = .{
    .jmp_1 = 0xEB,
    .jmp_2 = 0x3C,
    .jmp_3 = 0x90,
    .oem_1 = 'M',
    .oem_2 = 'S',
    .oem_3 = 'D',
    .oem_4 = 'O',
    .oem_5 = 'S',
    .oem_6 = '5',
    .oem_7 = '.',
    .oem_8 = '0',
    .bytes_per_sector = 512,
    .sectors_per_cluster = 1,
    .reserved_sectors = 1,
    .num_fats = 2,
    .root_entries = 224,
    .total_sectors = 2880,
    .media_descriptor = 0xF0,
    .sectors_per_fat = 9,
    .sectors_per_track = 18,
    .num_heads = 2,
    .hidden_sectors = 0,
    .large_sector_count = 0,
};

const GdtEntry = extern struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

export var gdt_entries align(8) = [_]GdtEntry{
    .{ .limit_low = 0, .base_low = 0, .base_middle = 0, .access = 0, .granularity = 0, .base_high = 0 },
    .{ .limit_low = 0xFFFF, .base_low = 0, .base_middle = 0, .access = 0x9A, .granularity = 0xCF, .base_high = 0 },
    .{ .limit_low = 0xFFFF, .base_low = 0, .base_middle = 0, .access = 0x92, .granularity = 0xCF, .base_high = 0 },
};

const Gdtr = extern struct {
    limit: u16,
    base: u32,
};

export var gdtr: Gdtr align(8) = .{
    .limit = (@sizeOf(@TypeOf(gdt_entries)) - 1),
    .base = 0,
};

const ERROR_NO_DISK = "No disk detected!";
const ERROR_READ_FAILED = "Disk read failed!";

export var video_buffer: [VideoMode.SCREEN_WIDTH * VideoMode.SCREEN_HEIGHT * 2]u8 align(1) = undefined;

export fn clear_screen() void {
    const buffer = @as([*]volatile u8, @ptrFromInt(VideoMode.VIDEO_MEMORY));
    var i: usize = 0;
    while (i < VideoMode.SCREEN_WIDTH * VideoMode.SCREEN_HEIGHT * 2) : (i += 2) {
        buffer[i] = ' ';
        buffer[i + 1] = 0x07;
    }
}

export fn print_string(str: [*:0]const u8, row: u16, col: u16, attr: u8) void {
    const buffer = @as([*]volatile u8, @ptrFromInt(VideoMode.VIDEO_MEMORY));
    const offset = (row * VideoMode.SCREEN_WIDTH + col) * 2;
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {
        buffer[offset + i * 2] = str[i];
        buffer[offset + i * 2 + 1] = attr;
    }
}

export fn draw_borders() void {
    const buffer = @as([*]volatile u8, @ptrFromInt(VideoMode.VIDEO_MEMORY));

    var i: usize = 0;
    while (i < VideoMode.SCREEN_WIDTH) : (i += 1) {
        buffer[i * 2] = '-';
        buffer[i * 2 + 1] = 0x0F;
        buffer[(VideoMode.SCREEN_HEIGHT - 1) * VideoMode.SCREEN_WIDTH * 2 + i * 2] = '-';
        buffer[(VideoMode.SCREEN_HEIGHT - 1) * VideoMode.SCREEN_WIDTH * 2 + i * 2 + 1] = 0x0F;
    }

    i = 0;
    while (i < VideoMode.SCREEN_HEIGHT) : (i += 1) {
        buffer[i * VideoMode.SCREEN_WIDTH * 2] = '|';
        buffer[i * VideoMode.SCREEN_WIDTH * 2 + 1] = 0x0F;
        buffer[i * VideoMode.SCREEN_WIDTH * 2 + (VideoMode.SCREEN_WIDTH - 1) * 2] = '|';
        buffer[i * VideoMode.SCREEN_WIDTH * 2 + (VideoMode.SCREEN_WIDTH - 1) * 2 + 1] = 0x0F;
    }

    buffer[0] = '+';
    buffer[(VideoMode.SCREEN_WIDTH - 1) * 2] = '+';
    buffer[(VideoMode.SCREEN_HEIGHT - 1) * VideoMode.SCREEN_WIDTH * 2] = '+';
    buffer[(VideoMode.SCREEN_HEIGHT - 1) * VideoMode.SCREEN_WIDTH * 2 + (VideoMode.SCREEN_WIDTH - 1) * 2] = '+';
}

export fn draw_menu() void {
    clear_screen();
    draw_borders();

    print_string("GRUB-like Bootloader", 0, 27, 0x0F);
    print_string("Use UP/DOWN arrows to select, ENTER to boot", 2, 20, 0x07);

    var i: usize = 0;
    while (i < menu_entries.len) : (i += 1) {
        const attr: u8 = if (@as(u8, @intCast(i)) == selected_entry) 0x70 else 0x07;
        const row = @as(u16, @intCast(5 + i));
        print_string(menu_entries[i].name, row, 10, attr);
        print_string(menu_entries[i].description, row, 45, attr);
    }
}

export fn check_disk(drive: u8) bool {
    var status: u8 = undefined;
    asm volatile ("int $0x13"
        : [status] "={ah}" (status),
        : [func] "{ah}" (0x01),
          [drive] "{dl}" (drive),
        : "memory"
    );
    return status == 0;
}

export fn read_disk_sectors(drive: u8, start_sector: u32, num_sectors: u8, buffer: [*]u8) bool {
    var tries: u8 = 3;
    while (tries > 0) : (tries -= 1) {
        const cylinder = @as(u16, @intCast(start_sector / (2 * 18)));
        const head = @as(u8, @intCast((start_sector / 18) % 2));
        const sector = @as(u8, @intCast((start_sector % 18) + 1));

        var status: u8 = undefined;
        asm volatile ("int $0x13"
            : [status] "={ah}" (status),
            : [func] "{ah}" (0x02),
              [sectors] "{al}" (num_sectors),
              [cylinder] "{ch}" (@as(u8, @intCast(cylinder))),
              [cylinder_hi] "{cl}" (@as(u8, @intCast((cylinder >> 8) & 0xC0)) | sector),
              [head] "{dh}" (head),
              [drive] "{dl}" (drive),
              [buffer] "{bx}" (buffer),
            : "memory"
        );

        if (status == 0) {
            return true;
        }

        asm volatile ("int $0x13"
            :
            : [func] "{ah}" (0x00),
              [drive] "{dl}" (drive),
            : "memory"
        );
    }
    return false;
}

pub export fn _start() callconv(.Naked) void {
    @setRuntimeSafety(false);
    asm volatile (
        \\.code16
        \\  cli
        \\  xorw %%ax, %%ax
        \\  movw %%ax, %%ds
        \\  movw %%ax, %%es
        \\  movw %%ax, %%ss
        \\  movw $0x7C00, %%sp
        \\
        \\  movb %%dl, (boot_drive)
        \\
        \\  movb $0x00, %%ah
        \\  movb $0x03, %%al
        \\  int $0x10
        \\
        \\  inb $0x92, %%al
        \\  orb $2, %%al
        \\  outb %%al, $0x92
        \\
        \\  movl $gdt_entries, %%eax
        \\  movl %%eax, (gdtr + 2)
        \\  lgdtw (gdtr)
        \\
        \\  movl %%cr0, %%eax
        \\  orl $1, %%eax
        \\  movl %%eax, %%cr0
        \\
        \\  ljmpw $0x08, $protected_mode
        \\
        \\.code32
        \\protected_mode:
        \\  movw $0x10, %%ax
        \\  movw %%ax, %%ds
        \\  movw %%ax, %%es
        \\  movw %%ax, %%fs
        \\  movw %%ax, %%gs
        \\  movw %%ax, %%ss
        \\
        \\  call draw_menu
        \\
        \\menu_loop:
        \\  inb $0x64, %%al
        \\  testb $0x01, %%al
        \\  jz menu_loop
        \\
        \\  inb $0x60, %%al
        \\
        \\  cmpb $0x48, %%al  // Up arrow
        \\  je handle_up
        \\  cmpb $0x50, %%al  // Down arrow
        \\  je handle_down
        \\  cmpb $0x1C, %%al  // Enter
        \\  je handle_enter
        \\
        \\  jmp menu_loop
        \\
        \\handle_up:
        \\  decb (selected_entry)
        \\  andb $0x01, (selected_entry)  // Wrap around to 1 entry
        \\  call draw_menu
        \\  jmp menu_loop
        \\
        \\handle_down:
        \\  incb (selected_entry)
        \\  andb $0x01, (selected_entry)  // Wrap around to 1 entry
        \\  call draw_menu
        \\  jmp menu_loop
        \\
        \\handle_enter:
        \\  movb (selected_entry), %%al
        \\  testb %%al, %%al
        \\  jz boot_hdd
        \\  jmp boot_floppy
        \\
        \\boot_hdd:
        \\  movb $0x80, %%dl
        \\  call check_disk
        \\  jc disk_error
        \\  movw $0x7E00, %%bx
        \\  movb $0x01, %%al
        \\  xorl %%ecx, %%ecx
        \\  call read_disk_sectors
        \\  jc read_error
        \\  ljmpw $0x0000, $0x7E00
        \\
        \\boot_floppy:
        \\  movb $0x00, %%dl
        \\  call check_disk
        \\  jc disk_error
        \\  movw $0x7E00, %%bx
        \\  movb $0x01, %%al
        \\  xorl %%ecx, %%ecx
        \\  call read_disk_sectors
        \\  jc read_error
        \\  ljmpw $0x0000, $0x7E00
        \\
        \\disk_error:
        \\  call clear_screen
        \\  movw $error_no_disk, %%si
        \\  call print_string
        \\  jmp halt
        \\read_error:
        \\  call clear_screen
        \\  movw $error_read_failed, %%si
        \\  call print_string
        \\  jmp halt
        \\
        \\halt:
        \\  hlt
        \\  jmp halt
        ::: "memory");

    unreachable;
}

export var boot_drive: u8 align(1) = 0;

export var error_no_disk: [*:0]const u8 align(1) = ERROR_NO_DISK;
export var error_read_failed: [*:0]const u8 align(1) = ERROR_READ_FAILED;

export var boot_signature: [2]u8 align(1) linksection(".boot_signature") = .{ 0x55, 0xAA };

export fn wait_for_disk() void {
    var status: u8 = undefined;
    while (true) {
        status = inb(0x1F7);
        if ((status & 0xC0) == 0x40) break;
    }
}

export fn read_disk_lba(drive: u8, lba: u32, buffer: [*]u8) bool {
    const sector_per_track = 18;
    const heads = 2;

    const sector = @as(u8, @truncate((lba % sector_per_track) + 1));
    const cylinder = @as(u16, @truncate(lba / (sector_per_track * heads)));
    const head = @as(u8, @truncate((lba / sector_per_track) % heads));

    var status: u8 = undefined;
    asm volatile ("int $0x13"
        : [status] "={ah}" (status),
        : [func] "{ah}" (0x02),
          [count] "{al}" (1),
          [track] "{ch}" (@as(u8, @truncate(cylinder))),
          [sector] "{cl}" (sector),
          [head] "{dh}" (head),
          [drive] "{dl}" (drive),
          [buffer] "{bx}" (buffer),
        : "memory"
    );
    return status == 0;
}

export fn delay(count: u16) void {
    var i: u16 = 0;
    while (i < count) : (i += 1) {
        asm volatile ("nop");
    }
}

export fn check_int13h_extensions(drive: u8) bool {
    var support: u16 = undefined;
    asm volatile ("int $0x13"
        : [support] "={ax}" (support),
        : [func] "{ah}" (0x41),
          [drive] "{dl}" (drive),
          [sig] "{bx}" (0x55AA),
        : "memory"
    );
    return (support & 0xFF00) == 0;
}

const MemoryMapEntry = extern struct {
    base: u64,
    length: u64,
    type: u32,
    extended_attributes: u32,
};

export fn get_memory_map(buffer: [*]MemoryMapEntry, max_entries: usize) usize {
    var entries: usize = 0;
    var continuation: u32 = 0;
    var signature: u32 = 0x534D4150;

    while (entries < max_entries) {
        var entry_size: u32 = undefined;
        asm volatile ("int $0x15"
            : [cont] "={ebx}" (continuation),
              [size] "={ecx}" (entry_size),
              [sig] "={eax}" (signature),
            : [func] "{eax}" (0xE820),
              [cont_in] "{ebx}" (continuation),
              [buffer] "{di}" (&buffer[entries]),
              [buf_size] "{ecx}" (@sizeOf(MemoryMapEntry)),
              [sig_in] "{edx}" (signature),
            : "memory"
        );

        if (signature != 0x534D4150) break;
        if (entry_size == 0) break;

        entries += 1;
        if (continuation == 0) break;
    }

    return entries;
}

export fn enable_a20_keyboard() void {
    wait_keyboard_ready();
    outb(0x64, 0xAD);

    wait_keyboard_ready();
    outb(0x64, 0xD0);
    wait_keyboard_data();
    const output_port = inb(0x60);

    wait_keyboard_ready();
    outb(0x64, 0xD1);
    wait_keyboard_ready();
    outb(0x60, output_port | 2);

    wait_keyboard_ready();
    outb(0x64, 0xAE);
    wait_keyboard_ready();
}

fn wait_keyboard_ready() void {
    while ((inb(0x64) & 2) != 0) {}
}

fn wait_keyboard_data() void {
    while ((inb(0x64) & 1) == 0) {}
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}
