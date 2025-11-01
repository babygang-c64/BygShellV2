// CHIP Header (16 bytes)
.text "CHIP"                    // CHIP signature (4 bytes)
.byte $00,$00,$20,$10           // Packet length: 8208 bytes (big-endian)
.byte $00,$00                   // Chip type: ROM (big-endian)
.byte $00,$01                   // Bank: 0 (big-endian)
.byte $80,$00                   // Load address: $8000 (big-endian)
.byte $20,$00                   // ROM size: $2000/8192 bytes (big-endian)

