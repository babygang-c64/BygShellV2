//===============================================================
// BYG SHELL : Command line Shell - BIOS BANK 1
//
// 2024-2025 Babygang
//===============================================================


#import "kernal.asm"
#import "macros.asm"


* = $8000

.word start_cartridge   // cold start vector
.word start_cartridge   // warm start vector
.byte $c3,$c2,$cd
.text "80"

.namespace bios 
{
//===============================================================
// BIOS functions list
//===============================================================

.label test=$0100+9

//===============================================================
// bios_jmp : bios jump table
//===============================================================

bios_jmp:
    .word do_test

do_test:
    lda #'B'
    jsr CHROUT
    lda #'K'
    jsr CHROUT
    lda #'1'
    jsr CHROUT
    lda #13
    jsr CHROUT
    rts

}

start_cartridge:
    brk

bank1_top:
.fill $a000-*, $00
