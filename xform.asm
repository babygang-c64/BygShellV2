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
    .label actions_list = $cb00
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
    beq no_pipe
    dec nb_params

no_pipe:
    ldy #0
    sty actions_list
    mov update_actions, #actions_list

params:
    cpx nb_params
    beq end
    swi lines_goto, buffer

    mov r1,#buffer_line
    swi str_cpy
    mov r0,r1
    
    sec
    ldx #';'
    swi str_split
    tax
    mov r0,#buffer_line
    jsr print_params

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
    swi pprint_nl
    pha
    push r0
    stx save_x
    jsr lookup_action
    bcs action_not_found

    pha
    mov r1,update_actions
    pla
    mov (r1),a
    incw update_actions

action_not_found:
    pop r0
    pla
    ldx save_x
    clc
    add r0,a
    inc r0    
    dex
    bne print_params
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

save_x:
    .byte 0
update_actions:
    .word 0
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
    
.label act_no_param=0
.label act_col_list=1
.label act_string=2
.label act_int=3

actions:
    pstring("HEAD")
    pstring("SEP")
    pstring("SEL")
    pstring("WRITE")
    .byte 0

actions_params:
    .byte act_int
    .byte act_int
    .byte act_col_list
    .byte act_col_list

actions_jmp:
    .word do_head
    .word do_sep
    .word do_sel
    .word do_write
    
do_head:
do_sep:
do_sel:
do_write:
    clc
    rts

//----------------------------------------------------
// lookup_action : find action
// input : R0 = pararmeter string
//
// output : C=0 OK, C=1 KO, A = action ID, 
// X= parameters type
//----------------------------------------------------

lookup_action:
{
    mov r1, #actions
    ldx #0
    ldy #0
test_action:
    mov a,(r1)
    beq end_of_list
    swi str_cmp
    bcs found
    inx
    mov a,(r1)
    clc
    add r1,a
    inc r1
    jmp test_action

found:
    lda actions_params,x
    txa
    clc
    rts

end_of_list:
    sec
    rts
}

}
