//----------------------------------------------------
// cat : print file(s)
//
// options : 
// N = numbers all lines
// E = prints a $ sign at the end of line
// B = numbers non empty lines
// P = paginates output
// H = hexdump
// A = reads start address in file for hexdump
// > = outputs to file
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word cat
pstring("CAT")

cat:
{
    .label work_buffer = $ce00
    
    .label OPT_B=1
    .label OPT_E=2
    .label OPT_N=4
    .label OPT_P=8
    .label OPT_H=16
    .label OPT_A=32

    // initialisation
    ldy #0
    sty num_lignes
    sty num_lignes+1

    sec
    swi param_init,buffer,options_cat
    jcs error
    swi pipe_init
    jcs error

    ldx nb_params
    jeq help

    // name = 1st parameter
    swi param_top

    sec
    jsr option_pagine

    ldx #4
    clc
    swi file_open
    jcs error
    
    jsr option_start_address

boucle_cat:
    jsr STOP
    jeq ok_close

    lda options_params
    and #OPT_H
    beq pas_hexdump

    ldx #4
    lda #8
    sta buffer_hexdump
    clc
    swi buffer_read, buffer_hexdump
    bcs derniere_ligne_hex

    swi pipe_output
    jsr option_pagination
    bcs ok_close

    swi print_hex_buffer
    jmp boucle_cat

derniere_ligne_hex:
    swi pipe_output
    swi print_hex_buffer
    jmp ok_close
    
pas_hexdump:    
    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    bcs ok_close

    swi pipe_output

affiche_ligne:
    jsr option_numero
    swi pprint, work_buffer

    // option E = affiche $ en fin de ligne
    lda options_params
    and #OPT_E
    beq pas_option_e
    lda #'$'
    jsr CHROUT

pas_option_e:
    lda #13
    jsr CHROUT
    jsr option_pagination
    bcs ok_close
    jmp boucle_cat

help:
    swi pprint_lines,help_msg
    sec
    rts

ok_close:
    swi pipe_end
    ldx #4
    swi file_close
fini:
    clc
    rts

error:
    jsr ok_close
    swi error,error_msg
    sec
    rts

option_pagination:
    lda options_params
    and #OPT_P
    jne option_pagine
    rts

option_numero:
    clc
    lda options_params
    and #OPT_B
    beq pas_opt_b
    lda work_buffer
    bne opt_b_numero_ok

pas_opt_b:
    lda options_params
    and #OPT_N
    beq pas_numero

opt_b_numero_ok:
    incw num_lignes
    ldx #%10011111
    mov r0, num_lignes
    swi pprint_int
    lda #32
    jsr CHROUT

pas_numero:
    rts


help_msg:
    pstring("*CAT <FILENAME> (-BENPHA>) (OUTPUT)")
    pstring(" N = NUMBERS ALL LINES")
    pstring(" E = $ AT EOL")
    pstring(" B = NUMBERS NON EMPTY LINES")
    pstring(" P = PAGINATES OUTPUT")
    pstring(" H = HEXDUMP")
    pstring(" A = READS START ADDRESS FOR HEXDUMP")
    pstring(" > = WRITE TO OUTPUT FILE")
    .byte 0
error_msg:
    pstring("RUN ERROR")
options_cat:
    pstring("BENPHA")
    
num_lignes:
    .word 0
buffer_hexdump:
    pstring("01234567")


//----------------------------------------------------
// option_start_address : reads start address to R1
// if option A, else R1=0
//----------------------------------------------------

option_start_address:
    mov r1, #0
    lda options_params
    and #OPT_A
    beq pas_opt_A
    ldx #4
    jsr CHKIN
    jsr CHRIN
    sta zr1l
    jsr CHRIN
    sta zr1h

pas_opt_A:
    rts

//----------------------------------------------------
// option_pagine : pagination option processing for
// printing in CAT / LS commands
// input : if C=1 performs intialisation of number of
// lines already printed. subsequent calls C=0
//----------------------------------------------------

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
    // ici il faudrait vider le buffer clavier
    rts

cpt_ligne:
    .byte 0
is_break:
    .byte 0
msg_suite:
    pstring("<MORE>")
}

} // CAT namespace
