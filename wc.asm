//----------------------------------------------------
// wc : count words / lines / bytes in file(s)
//
// options : 
// L = count lines
// W = count words
// C = count bytes
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word wc
pstring("WC")

wc:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00
    
    .label OPT_L=1
    .label OPT_W=2
    .label OPT_C=4


    sec
    swi param_init,buffer,options_wc
    jcs error
    swi pipe_init
    jcs error
    swi pipe_output
    
    ldx nb_params
    jeq help

//    swi param_top
    ldy #0
    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    swi pprint_nl
    jsr do_wc
    clc
    jmp boucle_params

fin_params:
    clc
    rts

do_wc:
    // initialisation
    ldy #0
    sty num_lines
    sty num_lines+1
    sty num_words
    sty num_words+1
    sty num_bytes
    sty num_bytes+1

    mov filename,r0
    ldx #4
    clc
    swi file_open
    jcs error

boucle_wc:
    jsr STOP
    jeq ok_close

    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    bcs ok_close

    add num_bytes,a
    incw num_lines
    
    ldx #32
    clc
    swi str_split, work_buffer
    add num_words,a

    jmp boucle_wc

help:
    swi pprint_lines,help_msg
    sec
    rts

ok_close:
    swi pipe_output
    jsr write_results

    ldx #4
    swi file_close
    swi pipe_end
    clc
    rts

error:
    jsr ok_close
    clc
    swi error
    rts

write_results:
    lda options_params
    and #$7f
    beq ok_lines
    and #OPT_L
    beq ko_lines
    
ok_lines:
    mov r0, num_lines
    jsr write_number
ko_lines:

    lda options_params
    and #$7f
    beq ok_words
    and #OPT_W
    beq ko_words

ok_words:
    mov r0, num_words
    jsr write_number
ko_words:

    lda options_params
    and #$7f
    beq ok_bytes
    and #OPT_C
    beq ko_bytes

ok_bytes:
    mov r0, num_bytes
    jsr write_number

ko_bytes:
    mov r0,filename
    lda #32
    jsr CHROUT
    swi pprint_nl
    clc
    rts

write_number:
    ldx #%10011111
    swi pprint_int
    lda #32
    jmp CHROUT


help_msg:
    pstring("*WC <FILENAME> [-LWC]")
    pstring(" L = COUNT LINES")
    pstring(" W = COUNT WORDS")
    pstring(" C = COUNT BYTES")
    .byte 0

options_wc:
    pstring("LWC")
    
num_lines:
    .word 0
num_words:
    .word 0
num_bytes:
    .word 0
filename:
    .word 0

} // WC namespace
