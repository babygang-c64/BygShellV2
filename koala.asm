//----------------------------------------------------
// koala : view koala paint file
//
// options : 
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word koala
pstring("KOALA")

koala:
{
    .label OPT_S=1

    // initialisation

    sec
    swi param_init,buffer,options_koala

    lda options_params
    and #OPT_S
    bne opt_s

    ldx nb_params
    jeq help

    swi str_next,buffer

    ldy #0
    mov r1, #$4000
    sec
    swi file_load

opt_s:
    sec
    ldx #1
    jsr picture_show

    clc
    ldx #0
    jsr picture_show
        
koala_end:
    lda #147
    jsr CHROUT
    lda 646
    jsr CHROUT
    jsr clr
    clc
    rts
    
clr:
    jsr $a68e
    jsr $ffe7
    lda $37
    ldy $38
    sta $33
    sty $34
    lda $2d
    ldy $2e
    sta $2f
    sty $30
    sta $31
    sty $32
    jsr $a81d
    ldx #$19
    stx $16
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

help_msg:
    pstring("*KOALA (<FILENAME>) (-S)")
    pstring(" S = SHOW PIC ALREADY LOADED")
    .byte 0
options_koala:
    pstring("S")

 } // koala namespace
 
//---------------------------------------------------------------
// picture_show : show picture
//
// R0 = picture data address if needed
// C=1 : wait for keypress and returns to text mode
// X = picture type
//
//  $00 : return to text mode
//  $01 : Koala picture
//---------------------------------------------------------------

picture_show:
{
    stc has_keypress
    bne pas_txt
    jsr go_txt
    
    lda save_d021
    sta $d021
    jmp fin_show

pas_txt:
    lda $d021
    sta save_d021
    cpx #1
    bne pas_koala

    // screen to 6800, color to d800
    // screen offset is 2800

    ldx #0
copy_color:
    lda $6328,x
    sta $d800,x
    lda $6428,x
    sta $d900,x
    lda $6528,x
    sta $da00,x
    lda $6628,x
    sta $db00,x
    lda $5f40,x
    sta $6800,x
    lda $6040,x
    sta $6900,x
    lda $6140,x
    sta $6a00,x
    lda $6240,x
    sta $6b00,x
    dex
    bne copy_color

    // background color

    lda $6710
    sta $d021

    jsr go_gfx
    jmp fin_show

pas_koala:

fin_show:
    lda has_keypress
    beq no_keypress
    swi key_wait
no_keypress:
    lda save_d021
    sta $d021
    clc
    rts

save_d021:
    .byte 0

go_gfx:
    lda #$38
    sta $d011
    lda #$18
    sta $d016
    lda #$02
    sta $dd00
    lda #$A0
    sta $d018
    rts

go_txt:
    lda #$9b
    sta $d011
    lda #$c8
    sta $d016
    lda #$03
    sta $dd00
    lda #$17
    sta $d018
    rts

has_keypress:
    .byte 0
}
