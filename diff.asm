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
    .label OPT_F=1
    .label OPT_N=1

    sec
    swi param_init,buffer,options_diff
    jcs error
    swi pipe_init
    jcs error
    swi pipe_output
    
    ldx nb_params
    cpx #2
    bne help

    ldx #'N'
    swi param_get_value
    bcc no_value
    lda zr0l
    sta nb_diff_max
    inc nb_diff_max
no_value:


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

    mov nb_diff,#0
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
    incw nb_diff
    lda #'<'
    jsr CHROUT
    swi pprint_nl,buffer1
    lda #'>'
    jsr CHROUT
    swi pprint_nl,buffer2

    swi pipe_output
    
    lda options_params
    and #OPT_F
    bne option_f

    lda options_params
    and #OPT_N
    bne option_n
    
    jmp do_diff

option_n:
    cmpw nb_diff,nb_diff_max
    beq option_f
    jmp do_diff

option_f:
no_more_data_file1:
no_more_data_file2:
    rts

nb_diff:
    .word 0
nb_diff_max:
    .word 0

different_msg:
    pstring("Files are different")
help_msg:
    pstring("*diff <file A> <file B> [-qfn]")
    pstring(" n = stop after X differences")
    pstring(" f = Stop after 1 difference")
    pstring(" q = Quiet mode")
    .byte 0

options_diff:
    pstring("QFN")
}
