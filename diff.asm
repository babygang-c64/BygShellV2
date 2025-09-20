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
    .label OPT_F=2
    .label OPT_N=4
    .label OPT_P=8

    sec
    swi param_init,buffer,options_diff
    jcs error
    
    ldx nb_params
    cpx #2
    beq ok_nb_params
    cpx #3
    beq ok_nb_params
    jmp help

ok_nb_params:

    swi pipe_init
    jcs error

    ldx #'N'
    swi param_get_value
    bcc no_value
    mov nb_diff_max,r0
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
    sec
    jsr option_pagine

    jsr do_diff
    
    mov r0,nb_diff
    swi return_int


fin_params:
    swi pipe_end
    ldx #3
    swi file_close
    ldx #4
    swi file_close
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


    //---------------------------------------------
    // run the difference check between files
    //---------------------------------------------

do_diff:
    incw line
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
    jsr write_diff

    jsr option_pagination
    bcs option_f
    
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
line:
    .word 0

different_msg:
    pstring("Files are different")
help_msg:
    pstring("*diff <file A> <file B> [-qfnp]")
    pstring(" n = stop after X differences")
    pstring(" f = Stop after 1 difference")
    pstring(" q = Quiet mode")
    pstring(" p = Paginate output")
    .byte 0

options_diff:
    pstring("QFNP")
}

//---------------------------------------------------------------
// write_diff : write the different lines
//
// <INPUT
// >OUTPUT
//---------------------------------------------------------------

write_diff:
{
    lda options_params
    and #diff.OPT_Q
    bne no_write

    swi pipe_output
    lda #'<'
    jsr CHROUT
    swi pprint_nl,diff.buffer1
    lda #'>'
    jsr CHROUT
    swi pprint_nl,diff.buffer2

no_write:
    rts
}

//---------------------------------------------------------------
// write_nb_diff : write the total number of differences found
//---------------------------------------------------------------

write_nb_diff:
{
    lda options_params
    and #diff.OPT_Q
    beq no_write
    
    swi pipe_output
    mov r0,diff.nb_diff
    jsr write_number
    lda #13
    jsr CHROUT

no_write:
    rts
}

write_number:
{
    ldx #%10011111
    swi pprint_int
    lda #32
    jmp CHROUT
}

//----------------------------------------------------
// option_pagine : pagination option processing for
// printing in CAT / LS commands
// input : if C=1 performs intialisation of number of
// lines already printed. subsequent calls C=0
//----------------------------------------------------

option_pagination:
{
    lda options_params
    and #diff.OPT_P
    beq no_pagination
    clc
    jmp option_pagine
    
no_pagination:
    rts
}

option_pagine:
{
    bcc do_pagination
    lda #0
    sta cpt_ligne
    clc
    rts

do_pagination:
    inc cpt_ligne
    lda cpt_ligne
    cmp #13
    bne pas_opt_p

    lda #0
    sta cpt_ligne
    swi pprint, msg_suite
    swi key_wait
    stc is_break
    jsr efface_msg_suite
    ldc is_break
    rts

pas_opt_p:
    clc
    rts

efface_msg_suite:
    ldy #6
    lda #20
efface_msg:
    jsr CHROUT
    dey
    bne efface_msg
    rts

cpt_ligne:
    .byte 0
is_break:
    .byte 0
msg_suite:
    pstring("<More>")
}
