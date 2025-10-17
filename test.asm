//----------------------------------------------------
// test : test if file exists
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word test
pstring("test")

test:
{
    .label params_buffer = $cd00
    .label work_buffer = $ce00
    .label OPT_Q = 1
    
    //-- init options
    sec
    swi param_init,buffer,options_test
    jcs help

    //-- parameter H = print help
    lda nb_params
    beq help

    swi pipe_init
    jcs error

    lda #1
    sta ok_all

    sec
loop_params:
    swi param_process,params_buffer
    bcs end
    swi pipe_output
    jsr do_test
    bcc found
    lda #0
    sta ok_all
found:
    clc
    bcc loop_params

end:
    swi pipe_end
    lda #0
    sta zr0h
    lda ok_all
    sta zr0l
    sec
    swi success
    rts

error:
    clc
    swi error
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts

ok_all:
    .byte 0
    
    //-- options available
options_test:
    pstring("q")

msg_help:
    pstring("*test <file> [options]")
    pstring(" -q : quiet")
    .byte 0


do_test:
{
    lda options_params
    and #OPT_Q
    beq not_quiet
    swi file_exists
    rts

not_quiet:
    mov r1,r0
    swi pprint,msg_file
    mov r0,r1
    swi pprint
    swi file_exists
    bcs not_found
    swi pprint_nl,msg_exists
    clc
    rts
not_found:
    swi pprint_nl,msg_not_found
    sec
    rts
}

msg_file:
    pstring("File [")
msg_exists:
    pstring("] exists")
msg_not_found:
    pstring("] not found")
}
