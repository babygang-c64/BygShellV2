//----------------------------------------------------
// join : join files
//
// options : 
// Q = Quiet mode
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word join
pstring("JOIN")

join:
{
    .label buffer1 = $ce00
    .label file_out = $ce80
    .label params_buffer = $cd00
    
    .label OPT_Q=1
    .label OPT_A=2

    sec
    swi param_init,buffer,options_diff
    jcs error_params
    
    ldx nb_params
    jeq help
    cpx #1
    jeq help

    // get output file name
    ldx nb_params
    swi lines_goto, buffer
    mov r1,#file_out
    swi str_cpy
    swi str_cat,file_out,suffix_write
    
    lda options_params
    and #OPT_A
    beq not_append

    swi str_cat,file_out,suffix_append
not_append:
    
    // open file for write
    ldx #5
    sec
    swi file_open
    bcs error_file_exists

    // parameters loop, read out last one
    ldy #0
    sec
    swi param_process,params_buffer
    clc
boucle_params:
    swi param_process,params_buffer
    bcs end

    jsr do_join_files
    clc
    jmp boucle_params

end:
    ldx #5
    swi file_close
    clc
    rts

error_params:
    mov r0,#msg_error_params
    mov r1,#$fffd
    bvc error
error_file_not_found:
    mov r0,#msg_error_file_not_found
    mov r1,#$fffc
    bvc error
error_file_exists:
    mov r0,#msg_error_file_exists
    mov r1,#$fffe
error:
    sec
    swi error
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

do_join_files:
{
    ldx #4
    clc
    swi file_open
    bcs error_file_not_found
    
    
loop_copy:
    lda #100
    sta buffer1
    clc
    ldx #4
    swi buffer_read,buffer1
    bcs end_copy
    swi pprint_nl,buffer1
    bvc loop_copy

end_copy:
    ldx #4
    swi file_close
    rts
}

suffix_write:
    pstring(",W")
suffix_append:
    pstring(",A")

help_msg:
    pstring("*join <source files> <target> [-qa]")
    pstring(" a = append and not replace")
    pstring(" q = Quiet mode")
    .byte 0

msg_error_params:
    pstring("Parameters")
msg_error_file_exists:
    pstring("File exists")
msg_error_file_not_found:
    pstring("File not found")

options_diff:
    pstring("QA")
}

