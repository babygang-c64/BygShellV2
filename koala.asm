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

    mov r1, #work_buffer
    swi str_expand
    mov r0,#work_buffer
    lda #'#'
    jsr CHROUT
    swi pprint_nl
    
    ldy #0
    mov r1, #$8000
    sec
    swi file_load
    bcs load_error

opt_s:
    sec
    ldx #1
    jsr picture_show

    clc
    ldx #0
    jsr picture_show
    
    clc
    jmp boucle
        
koala_end:
    lda #147
    jsr CHROUT
    lda 646
    jsr CHROUT
    jsr clr
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
    clc
    swi error,msg_load_error
    rts
msg_load_error:
    pstring("Load")
help_msg:
    pstring("*koala (<filename>) (-s)")
    pstring(" s = Show pic if already loaded")
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
    jne pas_koala

    // screen to A800, color to d800
    // screen offset is 2800


    sei
    lda #$36
    sta $01

    // background color

    lda $A710
    sta $d021
    lda #0
    sta $d020

    ldy #0
copy_color:
    // --- colorram (source déplacée de $6328 -> $A328 etc.)
    lda $A328,y
    sta $d800,y
    lda $A428,y
    sta $d900,y
    lda $A528,y
    sta $da00,y
    lda $A628,y
    sta $db00,y
    
    // backup buffers
    lda $ce00,y
    sta $0400,y
    lda $cf00,y
    sta $0500,y

    // --- video matrix (source déplacée de $5F40/$6040/$6140/$6240 -> $9F40/$A040/$A140/$A240)
    lda $9F40,y
    sta $cc00,y    // destination aussi déplacée de $6800 -> $A800
    lda $A040,y
    sta $cd00,y
    lda $A140,y
    sta $ce00,y
    lda $A240,y
    sta $cf00,y

    iny
    bne copy_color

    lda #$34
    sta $01

// copy_hires: $8000-$9F3F vers $e000

    ldy #0
    sty zr1l
    sty zr2l
    lda #$80
    sta zr1h
    lda #$e0
    sta zr2h
copy_hires:
    lda (zr1),y
    sta (zr2),y
    iny
    bne copy_hires
    inc zr1h
    inc zr2h
    bne copy_hires
    
    lda #$36
    sta $01
    cli

    jsr go_gfx
    jmp fin_show

pas_koala:

fin_show:
    lda has_keypress
    beq no_keypress
    jsr key_wait_ram
no_keypress:
    lda save_d021
    sta $d021
    
    ldy #0
recup:
    lda $0400,y
    sta $ce00,y
    lda $0500,y
    sta $cf00,y
    iny
    bne recup

    lda #$37
    sta $01
    cli
    clc
    rts

save_d021:
    .byte 0

go_gfx:
    lda #$3B
    sta $d011
    lda #$18
    sta $d016
    lda #$00
    sta $dd00
    lda #$38
    sta $d018
    rts

go_txt:
    lda #$9b
    sta $d011
    lda #$c8
    sta $d016
    lda #$03
    sta $dd00
    lda #23
    sta $d018
    rts

has_keypress:
    .byte 0
}

key_wait_ram:
{
wait_key:
    jsr SCNKEY
    jsr GETIN
    cmp #$20
    beq wait_key
    cmp #$03
    beq key_ok
    cmp #$51
    beq key_ok
    cmp #$0d
    beq key_ok
    cmp #$11
    beq key_ok
    bne wait_key
key_ok:
    clc
    rts
}
