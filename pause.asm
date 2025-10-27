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
    .label OPT_T=2

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
    // Timeout option
    //------------------------------------------------

    lda options_params
    and #OPT_T
    beq no_t_option

    ldx #'T'
    swi param_get_value
    jcc error_timeout
    mov nb_sec,r0
    jsr init_time

    //------------------------------------------------
    // params : use as message
    //------------------------------------------------
no_t_option:
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
    
    lda options_params
    and #OPT_T
    beq not_timeout
    
wait_timeout:
    jsr wait_second
    decw nb_sec
    lda nb_sec
    ora nb_sec+1
    beq end_wait
    bne wait_timeout
    
not_timeout:
    swi key_wait

end_wait:
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

error_timeout:
    mov r0,#msg_error_timeout
    sec
    bcs do_error
error:
    clc
do_error:
    swi error
    rts

init_time:
    lda $dc0d
    sta $dc0d
    lda $dc0a
    sta $dc0a
    lda $dc09
    sta $dc09
    sta seconds
    lda $dc08
    sta $dc08
    rts

wait_second:
{
    lda $dc0d
    lda $dc0a
    lda $dc09
    cmp seconds
    bne end
    lda $dc08
    jmp wait_second
end:
    sta seconds
    rts
}

seconds:
    .byte 0
msg_error_timeout:
    pstring("Timeout value")
help_msg:
    pstring("*pause [<message>] [options]")
    pstring(" t=<n> : Timeout")
    pstring(" h : Help")
    .byte 0

options_pause:
    pstring("ht")

nb_sec:
    .word 0

} // PAUSE namespace
