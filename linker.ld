ENTRY(_start)
SECTIONS {
    . = 0x7C00;
    .text : {
        *(.text.boot)
        *(.text)
    }
    .rodata : {
        *(.rodata)
    }
    .data : {
        *(.data)
    }
    .bss : {
        *(.bss)
    }
    
    /DISCARD/ : {
        *(.comment)
        *(.eh_frame)
        *(.note.gnu.property)
    }
}
