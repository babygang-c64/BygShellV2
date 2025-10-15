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
pstring("koala")

koala:
{
    .label work_buffer=$ce00
    .label params_buffer=$cd00
    .label OPT_S=1

    // initialisation

    sec
    swi param_init,buffer,options_koala

    lda options_params
    and #OPT_S
    bne opt_s

    ldx nb_params
    jeq help

    ldy #0
    sec
boucle:
    swi param_process,params_buffer
    bcs koala_end

    lda #0
    sta $d011

    mov r1, #work_buffer
    swi str_expand
    mov r0,#work_buffer
    
    ldy #0
    mov r1, #$6000
    sec
    swi file_load
    bcs load_error

    jsr koala_show
    bcs koala_end
    clc
    jmp boucle

opt_s:
    jsr koala_show
    jmp koala_end

koala_show:
    sec
    ldx #1
    jsr picture_show
    rts
    

text_mode:
    clc
    ldx #0
    jsr picture_show
    rts
        
koala_end:
    jsr text_mode
    jsr clr
    swi theme_normal
    lda #147
    jsr CHROUT
    clc
    swi success
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
load_error:
    lda #$1b
    sta $d011
    clc
    swi error,msg_load_error
    rts
msg_load_error:
    pstring("Load")
help_msg:
    pstring("*koala [<files>] [-s]")
    pstring(" s = Show pic if already loaded")
    .byte 0
options_koala:
    pstring("s")

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
    lda $d020
    sta save_d020
    
    cpx #1
    jne pas_koala

    // screen to 5c00, color to d800

    sei
    lda #$36
    sta $01

    // background color

    lda $8710
    sta $d021
    lda #0
    sta $d020

    ldy #0
copy_color:
    // --- colorram (8328+)
    lda $8328,y
    sta $d800,y
    lda $8428,y
    sta $d900,y
    lda $8528,y
    sta $da00,y
    lda $8628,y
    sta $db00,y
    
    // --- screen (7f40+) to 5c00+
    lda $7f40,y
    sta $5c00,y
    lda $8040,y
    sta $5d00,y
    lda $8140,y
    sta $5e00,y
    lda $8240,y
    sta $5f00,y

    iny
    bne copy_color

    lda #$37
    sta $01
    cli

    jsr go_gfx
    jmp fin_show

pas_koala:

fin_show:
    lda has_keypress
    beq no_keypress
    swi key_wait
    bcs end_show

no_keypress:
    jsr restore_colors
    clc
    rts
restore_colors:
    lda save_d021
    sta $d021
    lda save_d020
    sta $d020
    rts

end_show:
    jsr restore_colors
    sec
    rts

go_gfx:
    lda #$3B
    sta $d011
    lda #$d8
    sta $d016
    lda #$02
    sta $dd00
    lda #$78
    sta $d018
    rts

go_txt:
    sei
    lda #$9b
    sta $d011
    lda #$c8
    sta $d016
    lda #$03
    sta $dd00
    lda #23
    sta $d018
    lda #%01111111
    sta $dc0d
    and $d011
    sta $d011
    sta $dc0d
    sta $dd0d
    lda #1
    sta $d01a
    lda #255
    sta $d012
    cli
    rts

has_keypress:
    .byte 0
}

save_color:
    .byte 0
save_d021:
    .byte 0
save_d020:
    .byte 0

