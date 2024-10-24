const std = @import("std");
const builtin = @import("builtin");

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

export var bpb: BiosParameterBlock align(1) = .{
    .jmp_1 = 0xEB,
    .jmp_2 = 0x3C,
    .jmp_3 = 0x90,
    .oem_1 = 'M',
    .oem_2 = 'S',
    .oem_3 = 'W',
    .oem_4 = 'I',
    .oem_5 = 'N',
    .oem_6 = '4',
    .oem_7 = '.',
    .oem_8 = '1',
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
    // Null descriptor
    .{
        .limit_low = 0,
        .base_low = 0,
        .base_middle = 0,
        .access = 0,
        .granularity = 0,
        .base_high = 0,
    },
    .{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0x9A,
        .granularity = 0xCF,
        .base_high = 0,
    },
    .{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0x92,
        .granularity = 0xCF,
        .base_high = 0,
    },
};

const Gdtr = extern struct {
    limit: u16,
    base: u32,
};

export var gdtr: Gdtr align(8) = .{
    .limit = (@sizeOf(@TypeOf(gdt_entries)) - 1),
    .base = 0,
};

pub export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\.code16
        \\  cli                         // Disable interrupts
        \\  xorw %%ax, %%ax            // Zero ax register
        \\  movw %%ax, %%ds            // Set up data segment
        \\  movw %%ax, %%es            // Set up extra segment
        \\  movw %%ax, %%ss            // Set up stack segment
        \\  movw $0x7C00, %%sp         // Set up stack pointer
        \\
        \\  // Enable A20 line
        \\  inb $0x92, %%al            // Read from port 0x92
        \\  orb $2, %%al               // Set A20 bit
        \\  outb %%al, $0x92           // Write back to port
        \\
        \\  // Update GDTR base
        \\  movl $gdt_entries, %%eax
        \\  movl %%eax, (gdtr + 2)
        \\
        \\  // Load GDT
        \\  lgdtw (gdtr)               // Load GDT register
        \\
        \\  // Enter protected mode
        \\  movl %%cr0, %%eax          // Get current CR0
        \\  orl $1, %%eax              // Set PE bit
        \\  movl %%eax, %%cr0          // Write back to CR0
        \\
        \\  // Long jump to set CS and enter protected mode
        \\  ljmpw $0x08, $protected_mode
        \\
        \\.code32
        \\protected_mode:
        \\  // Set up segment registers for protected mode
        \\  movw $0x10, %%ax           // Data segment selector
        \\  movw %%ax, %%ds
        \\  movw %%ax, %%es
        \\  movw %%ax, %%fs
        \\  movw %%ax, %%gs
        \\  movw %%ax, %%ss
        \\
        \\  // Jump to kernel
        \\  jmp 0x10000
        \\
        \\halt:
        \\  hlt
        \\  jmp halt
        ::: "memory");
}
