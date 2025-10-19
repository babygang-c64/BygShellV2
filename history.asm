//----------------------------------------------------
// history : show history content
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word history
pstring("history")

history:
{
    .label params_buffer = $cd00
    .label OPT_C=1
    .label OPT_L=2
    
    //-- init options
    sec
    swi param_init,buffer,options_history
    bcs help

    //-- no options = print help
    lda options_params
    beq help

    lda options_params
    and #OPT_C
    beq not_clear

    ldy #0
    sty history_buffer
    sty history_buffer+1
    sty history_buffer+2

not_clear:
    lda options_params
    and #OPT_L
    beq not_list

    swi pipe_init
    swi pipe_output
    jsr history.list

not_list:
end:
    swi pipe_end
    clc
    swi success
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts
    
    //-- options available
options_history:
    pstring("cl")


msg_help:
    pstring("*history [options]")
    pstring(" show history of last commands")
    pstring(" l = list history")
    pstring(" c = clear history")
    .byte 0

//------------------------------------------------------------
// history : history of commands
//------------------------------------------------------------

history:
{
goto:
    ldy #0
    mov r0,#history_buffer+2
    cpx #0
    beq found
do_goto:
    jsr bios.bios_ram_get_byte
    inc r0
    add r0,a
    dex
    bne do_goto
found:
    rts

list:
    ldy #0
    sty pos_histo
    mov r0,#history_buffer
    jsr bios.bios_ram_get_byte
    sta nb_histo
    cmp #0
    bne next
    rts
next:
    jsr get
    dec nb_histo
    bne next
    rts

nb_histo:
    .byte 0
pos_histo:
    .byte 0

get:
    ldx pos_histo
    jsr history.goto
    inc pos_histo
    lda #'*'
    jsr CHROUT
    clc
    jsr pprint_ram
    lda #13
    jmp CHROUT
}

//------------------------------------------------------------
// pprint_ram : print pstring under basic ROM
//
// input : R0 = pstring, C=0 no conversion, 
// C=1 screen to petscii conversion
//
// uses R7 and indirectly ztmp / zsave
//------------------------------------------------------------

pprint_ram:
{
    stc zr7l
    ldy #0
    jsr bios.bios_ram_get_byte
basic:
    sta zr7h
    cmp #0
    beq no_print
    iny
print:
    jsr bios.bios_ram_get_byte
    ldx zr7l
    beq no_conv
    tax
    swi screen_to_petscii
no_conv:
    jsr CHROUT
    iny
    dec zr7h
    bne print
    ldy #0
    jsr bios.bios_ram_get_byte
no_print:
    rts
}


}
