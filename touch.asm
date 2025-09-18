//----------------------------------------------------
// touch : create empty files
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word touch
pstring("TOUCH")

.label params_buffer=$cd80

touch:
{
    .label work_buffer = $ce00
    .label OPT_P = 1

    //-- init options
    sec
    swi param_init,buffer,options_touch
    jcs help

    //-- no parameters = print help
    ldx nb_params
    jeq help

    ldy #0
    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    jsr do_touch
    clc
    jmp boucle_params

fin_params:

    clc
    swi success
    rts

do_touch:
    ldy #0
    mov r1,#work_buffer
    swi str_cpy

    swi file_exists
    bcc error_exists

    lda options_params
    and #OPT_P
    beq add_suffix
    
    swi str_cat,work_buffer,prg_suffix
    jmp ok_suffix


add_suffix:
    swi str_cat,work_buffer,seq_suffix

ok_suffix:
    swi str_cat,work_buffer,write_suffix

    ldx #5
    sec
    swi file_open,work_buffer
    ldx #5
    swi file_close

    clc
    rts

error_exists:
    sec
    swi error,msg_error_exists,$fffd
    rts

msg_error_exists:
    pstring("FILE EXISTS")
write_suffix:
    pstring(",W")
seq_suffix:
    pstring(",S")
prg_suffix:
    pstring(",P")

help:
    swi pprint_lines, help_hw
    clc
    rts

    clc
    swi error
    rts

    
    //-- options available
options_touch:
    pstring("P")

help_hw:
    pstring("*TOUCH <FILE> : CREATE EMPTY FILE")
    pstring(" -P : create PRG file")
    .byte 0

}
