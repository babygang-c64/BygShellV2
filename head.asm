//----------------------------------------------------
// head : print head of file(s)
//
// options : 
// N = number of lines to print
// Q = don't print filename
// V = always print filename
// P = paginate
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word head
pstring("head")

head:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_N=1
    .label OPT_Q=2
    .label OPT_V=4
    .label OPT_P=8

    lda #11
    sta nb_lignes_max
    lda #0
    sta cpt_ligne

    sec
    swi param_init,buffer,options_head
    jcs error
    swi pipe_init
    jcs error

    ldx nb_params
    jeq help

    ldx #'N'
    swi param_get_value
    bcc no_value
    lda zr0l
    sta nb_lignes_max
    inc nb_lignes_max

no_value:
    ldy #0
    sec


boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    jsr do_head
    clc
    jmp boucle_params

fin_params:
    swi pipe_end
    clc
    rts

do_head:
    // initialisation
    ldy #0
    lda nb_lignes_max
    sta nb_lignes

    ldx #4
    clc
    swi file_open
    jcs error_open

boucle_head:
    jsr STOP
    jeq ok_close

    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    bcs ok_close


    dec nb_lignes
    beq ok_close

affiche_ligne:
    swi pipe_output
    swi pprint_nl, work_buffer

    jsr option_pagination
    bcs ok_close
    jmp boucle_head

help:
    swi pprint_lines,help_msg
    clc
    rts

ok_close:
    ldx #4
    swi file_close

fini:
    clc
    swi success
    rts

msg_open:
    pstring("Error open")
error_open:
    swi pprint_nl,msg_open

error:
    jsr ok_close
    clc
    swi error
    rts

option_pagination:
    lda options_params
    and #OPT_P
    jne option_pagine
    rts

help_msg:
    pstring("*head <filename> [-nqvp]")
    pstring(" n = Number of lines")
    pstring(" q = No filename")
    pstring(" v = Always filename")
    pstring(" p = Paginate output")
    .byte 0

options_head:
    pstring("nqvp")
    
cpt_ligne:
    .byte 0
nb_lignes:
    .byte 0
nb_lignes_max:
    .byte 0


//----------------------------------------------------
// do_name : affichage du nom
//----------------------------------------------------

option_name:
{
    lda options_params
    and #OPT_V
    bne do_name
    lda nb_params
    cmp #1
    bne not_one
    rts

not_one:
    lda options_params
    and #OPT_Q
    beq do_name
    rts

do_name:
    lda #13
    jsr CHROUT
    lda #'='
    jsr CHROUT
    jsr CHROUT
    lda #'>'
    jsr CHROUT
    lda #32
    jsr CHROUT
    swi pprint
    lda #32
    jsr CHROUT
    lda #'<'
    jsr CHROUT
    lda #'='
    jsr CHROUT
    jsr CHROUT
    lda #13
    jmp CHROUT
}

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
    rts

cpt_ligne:
    .byte 0
is_break:
    .byte 0
msg_suite:
    pstring("<MORE>")
}

} // CAT namespace
