//----------------------------------------------------
// diff : compare two files
//
// options : 
// Q = Quiet mode
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word diff
pstring("DIFF")

diff:
{
    .label buffer1 = $ce00
    .label buffer2 = $cc00
    .label params_buffer = $cd00
    
    .label OPT_Q=1

    sec
    swi param_init,buffer,options_diff
    jcs error
    swi pipe_init
    jcs error
    swi pipe_output
    
    ldx nb_params
    cpx #2
    bne help

    ldy #0
    sec
    swi param_process,params_buffer
    
    clc
    ldx #3
    swi file_open
    
    clc
    swi param_process,params_buffer

    clc
    ldx #4
    swi file_open

    jsr do_diff

fin_params:
    ldx #3
    swi file_close
    ldx #4
    swi file_close
    swi pipe_end
    clc
    rts

error:
    sec
    swi error
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

do_diff:
    ldx #3
    jsr CHKIN
    swi file_readline,buffer1
    jcs no_more_data_file1
    ldx #4
    jsr CHKIN
    swi file_readline, buffer2
    jcs no_more_data_file2

    swi str_cmp,buffer1,buffer2
    bcc is_diff
    
    jmp do_diff
    
is_diff:
    lda #'<'
    jsr CHROUT
    swi pprint_nl,buffer1
    lda #'>'
    jsr CHROUT
    swi pprint_nl,buffer2

    swi pipe_output
    jmp do_diff

no_more_data_file1:
no_more_data_file2:
    rts

different_msg:
    pstring("Files are different")
help_msg:
    pstring("*diff <file A> <file B> [-q]")
    pstring(" q = Quiet mode")
    .byte 0

options_diff:
    pstring("Q")
}
