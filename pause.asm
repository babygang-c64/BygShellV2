//----------------------------------------------------
// pause : wait for key / display message
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word pause
pstring("pause")

pause:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_H=1

    sec
    swi param_init,buffer,options_pause
    jcs error

    //------------------------------------------------
    // help option
    //------------------------------------------------
    
    lda options_params
    and #OPT_H
    jne help

    //------------------------------------------------
    // params : use as message
    //------------------------------------------------

    lda nb_params
    bne is_params
    mov r0,#msg_pause
    jmp wait
    
is_params:
    sec
    swi param_process,params_buffer

wait:
    ldx #bios.COLOR_ACCENT
    swi theme_set_color
    swi pprint_nl
    swi key_wait
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    sta zr0l
    lda #0
    sta zr0h
    swi return_int
    jsr CLRCHN
    clc
    rts


help:
    swi pprint_lines,help_msg
    clc
    rts

msg_pause:
    pstring("[Press any key]")

error:
    clc
    swi error
    rts

help_msg:
    pstring("*pause [<message>]")
    pstring(" h = Help")
    .byte 0

options_pause:
    pstring("h")

} // PAUSE namespace
