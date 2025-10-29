//----------------------------------------------------
// search : find content in file(s)
//
// options : 
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word search
pstring("search")

search:
{
    .label work_buffer = $ce00
    .label search_string = $cd00
    .label params_buffer = $cd80
    .label filename = $cbe0
    
    .label OPT_N=1
    .label OPT_L=2
    .label OPT_V=4
    .label OPT_C=8
    .label OPT_A=16
    .label OPT_P=32

    ldy #0
    sty line
    sty line+1

    sec
    swi param_init,buffer,options_list
    jcs error

    swi pipe_init
    jcs error
    swi pipe_output
    
    ldx nb_params
    jeq help

    swi param_top
    mov r1,#search_string
    swi str_cpy

    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    lda scan_params
    and #$7f
    cmp #1
    beq fin_params

    jsr do_search

    clc
    jmp boucle_params

fin_params:
    sec
    swi success
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

error:
    clc
    swi error
    rts
    
help_msg:
    pstring("*search <string> <file> [-options]")
    pstring(" n = Print line number")
    pstring(" l = Print line numbers only")
    pstring(" v = Lines not matching")
    pstring(" c = Count lines matching")
    pstring(" a = Convert from ASCII")
    pstring(" p = Use standard prefix for matches")
    .byte 0

options_list:
    pstring("nlvcap")

line:
    .word 0
count:
    .word 0
test_v:
    .byte 0
    
do_search:
{
    mov r1,#filename
    swi str_cpy

    ldx #4
    clc
    swi file_open
    jcs error

    ldy #0
    sty count
    sty count+1

boucle_read:
    jsr STOP
    jeq ok_close

    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    jcs ok_close
    
    lda options_params
    and #OPT_A
    beq not_a
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv,work_buffer
not_a:

    incw line

    mov r0,#work_buffer
    mov r1,#search_string
    swi str_pat

    jsr option_v
    jcc not_found

found:
    inc count
    
    lda options_params
    and #OPT_C
    bne boucle_read

    swi pipe_output

    lda options_params
    and #OPT_P
    beq not_p
    
    swi pprint,filename
    lda #':'
    jsr CHROUT
    mov r0, line
    ldx #%11011111
    swi pprint_int
    lda #':'
    jsr CHROUT
    swi pprint_nl,work_buffer
    jmp boucle_read

not_p:
    lda options_params
    and #OPT_N+OPT_L
    beq pas_opt_n
    
    mov r0, line
    ldx #%10011111
    swi pprint_int
    lda #32
    jsr CHROUT
    lda options_params
    and #OPT_L
    beq pas_opt_n

    lda #13
    jsr CHROUT
    jmp boucle_read
    
pas_opt_n:
    swi pprint_nl,work_buffer
    
not_found:
    jmp boucle_read

ok_close:
    lda options_params
    and #OPT_C
    beq pas_opt_c

    mov r0, count
    ldx #%10011111
    swi pprint_int
    lda #13
    jsr CHROUT
    
pas_opt_c:
    ldx #4
    swi file_close
    swi pipe_end
    mov r0,count
    rts

option_v:
    stc test_v
    lda options_params
    and #OPT_V
    beq not_option_v
    lda test_v
    eor #1
    sta test_v
not_option_v:
    ldc test_v
    rts

}

} // search

