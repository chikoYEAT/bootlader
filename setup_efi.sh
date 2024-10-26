#!/bin/bash

# Create the base directories
mkdir -p test_files/EFI/BOOT

# Create a basic BOOTX64.EFI file (placeholder)
cat > test_files/EFI/BOOT/BOOTX64.EFI << 'EOF'
;
; Minimal EFI boot stub
; This is a placeholder - replace with your actual bootloader
;
USE16
org 0x7c00

start:
    ; Basic EFI stub header
    db 'MZ'        ; DOS header
    times 58 db 0  ; Padding
    dd 0x00000080  ; PE header offset

    ; PE header
    db 'PE', 0, 0  ; PE signature
    dw 0x014c      ; Machine (i386)
    dw 1           ; Number of sections
    dd 0           ; Timestamp
    dd 0           ; Symbol table pointer
    dd 0           ; Number of symbols
    dw 224         ; Optional header size
    dw 0x102       ; Characteristics

    times 510-($-$$) db 0
    dw 0xaa55      ; Boot signature
EOF

# Set permissions
chmod -R 755 test_files

# Create directory structure file
tree test_files > directory_structure.txt

echo "EFI directory structure created in test_files/"
echo "Directory structure:"
cat directory_structure.txt
