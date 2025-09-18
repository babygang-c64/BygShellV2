// CRT Header (64 bytes)
.text "C64 CARTRIDGE   "        // 16 bytes: signature + 3 spaces + null
.byte $00,$00,$00,$40           // Header length: 64 bytes (big-endian)
.byte $01,$00                   // Version: 1.0 (big-endian) 
.byte $00,$00                   // Hardware type: 0 (big-endian)
.byte $01                       // EXROM line: 1 (active)
.byte $00                       // GAME line: 0 (inactive)
.byte $00,$00,$00,$00,$00,$00   // Reserved (6 bytes)
.text "BYG SHELL V2"           // Cartridge name
.fill 32-"BYG SHELL V2".size(),$00  // Pad name to 32 bytes

// CHIP Header (16 bytes)
.text "CHIP"                    // CHIP signature (4 bytes)
.byte $00,$00,$20,$10           // Packet length: 8208 bytes (big-endian)
.byte $00,$00                   // Chip type: ROM (big-endian)
.byte $00,$00                   // Bank: 0 (big-endian)
.byte $80,$00                   // Load address: $8000 (big-endian)
.byte $20,$00                   // ROM size: $2000/8192 bytes (big-endian)

