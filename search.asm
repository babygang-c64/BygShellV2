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
pstring("SEARCH")

search:
{
    .label work_buffer = $ce00
    
    .label OPT_N=1
    .label OPT_L=2
    .label OPT_V=4
    .label OPT_C=8

    ldy #0
    sty line
    sty line+1
    sty count
    sty count+1

    sec
    swi param_init,buffer,options_list
    jcs error
    swi pipe_init
    jcs error
    swi pipe_output
    
    ldx nb_params
    jeq help

    swi param_top
    swi param_next
    ldx #4
    clc
    swi file_open
    jcs error

boucle_read:
    jsr STOP
    jeq ok_close

    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    jcs ok_close
    incw line

    swi param_top
    mov r1, r0
    swi str_pat, work_buffer
    jsr option_v
    bcc not_found

found:
    inc count
    
    lda options_params
    and #OPT_C
    bne boucle_read

    swi pipe_output

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

help:
    swi pprint_lines,help_msg
    sec
    rts

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
    sec
    swi success
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

error:
    jsr ok_close
    clc
    swi error
    rts
    
help_msg:
    pstring("*SEARCH <STRING> <FILE> [-NLVC]")
    pstring(" N = PRINT LINE NUMBER")
    pstring(" L = PRINT LINE NUMBER ONLY")
    pstring(" V = LINES NOT MATCHING")
    pstring(" C = COUNT LINES MATCHING")
    .byte 0

options_list:
    pstring("NLVC")

line:
    .word 0
count:
    .word 0
test_v:
    .byte 0
} // search

