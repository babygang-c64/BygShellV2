//----------------------------------------------------
// xform : process delimited / text file line by line
//
// options : 
// F = use file for commands
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word xform
pstring("XFORM")

xform:
{
    .label commands_list = $cc00
    .label buffer_line = $cd00
    .label params_buffer = $ce00
    
    .label OPT_F=1

    sec
    swi param_init,buffer,options_xform
    jcs error_params
    
    ldx nb_params
    jeq help

    swi pipe_init
    jcs error_params

    // 1st parameter is file to process
    mov nb_output,#0
    mov commands_list,#0
    ldy #0
    ldx #1
    swi lines_goto, buffer
    swi pprint_nl

    // then commands
    ldx #2
    stx pos_param
    inc nb_params

    lda options_params
    and #OPT_PIPE
    beq params
    dec nb_params

params:
    cpx nb_params
    beq end
    swi lines_goto, buffer
    swi pprint_nl
    inc pos_param
    ldx pos_param
    jmp params

end:
    swi pipe_end
    lda nb_output
    swi return_int
    clc
    rts

pos_param:
    .byte 0
print_params:
print_next:
    swi pprint_nl
//    add r0,a
    dex
    bne print_next
    rts

error_params:
    mov r0,#msg_error_params
    mov r1,#$fffd
    bvc error
error_file_not_found:
    mov r0,#msg_error_file_not_found
    mov r1,#$fffc
    bvc error
error:
    sec
    swi error
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

nb_output:
    .word 0

help_msg:
    pstring("*xform <file> <processes..> [-f <ini>]")
    pstring(" f = Use ini file")
    .byte 0

msg_error_params:
    pstring("Parameters")
msg_error_file_not_found:
    pstring("File not found")

options_xform:
    pstring("F")
}
