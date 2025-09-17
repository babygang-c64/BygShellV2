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

    //-- init options
    sec
    swi param_init,buffer,options_touch
    jcs help

    //-- no parameters = print help
    ldx nb_params
    beq help

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
    mov r1,#work_buffer
    swi str_cpy
    mov a,(r1)
    tay
    dey
    mov a,(r1)
    cmp #','
    beq ok_suffix
    ldy #0
    mov r1,#seq_suffix
    swi str_cat

ok_suffix:
    ldy #0
    mov r1,#write_suffix
    swi str_cat
    
    mov r0,r1
    swi pprint_nl
    clc
    rts

write_suffix:
    pstring(",W")
seq_suffix:
    pstring(",S")

help:
    swi pprint_lines, help_hw
    clc
    rts

    //-- return with C=1 : ERROR
    sec
    swi error
    rts

    
    //-- options available
options_touch:
    pstring("H")

help_hw:
    pstring("*TOUCH <FILE> : CREATE EMPTY FILE")
    .byte 0

}
