//----------------------------------------------------
// conv : convert files
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word conv
pstring("conv")

.label params_buffer=$cd80

conv:
{
    .label work_buffer = $ce00
    .label OPT_P = 1
    .label OPT_A = 2
    .label OPT_S = 4
    .label OPT_U = 8
    .label OPT_L = 16

    ldy #0
    sty format_in
    sty format_out
    jsr get_formats
    
    //-- init options
    sec
    swi param_init,buffer,options_conv
    jcs help

    swi pipe_init
    jcs error

    //-- no parameters = print help
    ldx nb_params
    jeq help

    //-- check conversion
    jsr check_formats
    bcs error_format
    stx conv_offset

    ldy #0
    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    jsr do_conv
    clc
    jmp boucle_params

fin_params:

    swi pipe_end
    clc
    swi success
    rts

do_conv:
    ldx #4
    clc
    swi file_open
    bcs error

boucle_conv:
    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    bcs ok_close

    ldx conv_offset
    swi str_conv, work_buffer
    
    swi pipe_output
    swi pprint_nl
    jmp boucle_conv

ok_close:
    ldx #4
    swi file_close
    clc
    rts

error:
    jsr ok_close
    swi error
    rts
    
error_format:
    sec
    swi error,msg_format
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts

    clc
    swi error
    rts

    
    //-- options available
options_conv:
    pstring("pasul")

msg_help:
    pstring("*conv <file(s)> -<in format> -<out format>")
    pstring(" -p : PETSCII")
    pstring(" -a : ASCII")
    pstring(" -s : Screen codes")
    pstring(" -u : Uppercase")
    pstring(" -l : Lowercase")
    .byte 0

msg_format:
    pstring("Conversion not available ")

conversions:
    .text "AP"
    .byte bios.ASCII_TO_PETSCII
    .text "SA" 
    .byte bios.SCREEN_TO_ASCII
    .text "SP"
    .byte bios.SCREEN_TO_PETSCII
    .text "AS"
    .byte bios.ASCII_TO_SCREEN
    .text "AU"
    .byte bios.ASCII_TO_UPPER
    .text "AL"
    .byte bios.ASCII_TO_LOWER
    .text "PS" 
    .byte bios.PETSCII_TO_SCREEN
    .byte 0

format_in:
    .byte 0
format_out:
    .byte 0
conv_offset:
    .byte 0

get_formats:
{
    ldx #0
    mov r0,#buffer
    ldx nb_params
params:
    swi str_next
    ldy #1
    mov a,(r0)
    cmp #'-'
    bne next_param

    iny
    mov a,(r0)
    cmp #'A'
    beq value_ok
    cmp #'P'
    beq value_ok
    cmp #'U'
    beq value_ok
    cmp #'L'
    beq value_ok
    cmp #'S'
    bne next_param

value_ok:
    ldy format_in
    bne not_in
    sta format_in
    jmp next_param

not_in:
    ldy format_out
    bne end
    sta format_out
    
next_param:
    dex
    bne params
end:
    ldy #0
    lda format_in
    ora format_out
    beq default
    rts
default:
    lda #'A'
    sta format_in
    lda #'P'
    sta format_out
    rts
}

check_formats:
{
    ldy #0

check:
    lda conversions,y
    beq end_ok
    cmp format_in
    bne next_format
    lda conversions+1,y
    cmp format_out
    bne next_format
    ldx conversions+2,y
    clc
    rts

next_format:
    iny
    iny
    iny
    bne check
    
end_ok:
    sec
    rts
}

}
