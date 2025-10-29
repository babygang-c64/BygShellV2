//----------------------------------------------------
// tail : print tail of file(s)
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

.word tail
pstring("tail")

tail:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_N=1
    .label OPT_Q=2
    .label OPT_V=4
    .label OPT_P=8
    .label OPT_A=16

    lda #10
    sta nb_lignes_max
    ldy #0
    sty cpt_ligne
    
    sec
    jsr option_pagine

    sec
    swi param_init,buffer,options_tail
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

no_value:
    ldy #0
    sec
    ldx nb_lignes_max
    jsr add_line

    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    jsr do_tail
    clc
    jmp boucle_params

fin_params:
    swi pipe_end
    clc
    rts

do_tail:
    ldy #0

    ldx #4
    clc
    swi file_open
    jcs error_open

    swi pipe_output
    jsr option_name

    sec
    ldx #5
    jsr progress

boucle_tail:
    jsr STOP
    jeq ok_close

    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    bcs ok_close

    clc
    jsr progress
    
    lda options_params
    and #OPT_A
    beq not_opt_a
    
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
    
not_opt_a:
    clc
    mov r0,#work_buffer
    jsr add_line
    jmp boucle_tail

help:
    swi pprint_lines,help_msg
    clc
    rts

ok_close:
    ldx #4
    swi file_close
    
    sec
    ldx #0
    jsr progress
    
    jsr view_lines
    rts

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
{
    lda options_params
    and #OPT_P
    jne option_pagine
no_paginate:
    rts
}

help_msg:
    pstring("*tail <filename> [-options]")
    pstring(" n = Number of lines")
    pstring(" q = No filename")
    pstring(" v = Always filename")
    pstring(" p = Paginate output")
    pstring(" a = Convert ASCII")
    .byte 0

options_tail:
    pstring("nqvpa")
    
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
    jsr nl
    lda #'='
    jsr CHROUT
    jsr CHROUT
    lda #'>'
    jsr CHROUT
    lda #32
    jsr CHROUT
    swi pprint
    swi pprint_nl,suff_name
    rts

suff_name:
    pstring(" <==")
}

nl:
{
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
reset_lines:
    lda #23
    sta cpt_ligne
pas_opt_p:
    clc
    rts

do_pagination:
    dec cpt_ligne
    bne pas_opt_p
    
    jsr reset_lines
    swi screen_pause
    rts

cpt_ligne:
    .byte 0
}

//----------------------------------------------------
// add_line : add line in r0 to work buffer, if
// max lines then move out the first one before
//
// if C=1 init, X = max_lines
// uses the free BASIC RAM between STREND and FRETOP
//----------------------------------------------------

add_line:
{
    jcs init
    lda stored_lines
    cmp max_lines
    beq is_max
    inc stored_lines
    jmp insert

is_max:
    ldy #0
    mov r1,STREND
    mov a,(r1)
    add r1,a
    inc r1    
    mov r2,next_space
    sub r2,r1
    mov cpt_copy,r2
    mov r2,STREND
copy:
    mov a,(r1++)
    mov (r2++),a
    decw cpt_copy
    bne copy
    mov next_space,r2
insert:
    mov r1,next_space
    swi str_cpy
    add r1,a
    mov next_space,r1
    tya
    mov (r1),a
    rts

init:
    stx max_lines
    ldy #0
    sty stored_lines
    mov next_space,STREND
    rts

max_lines:
    .byte 0
stored_lines:
    .byte 0
next_space:
    .word 0
cpt_copy:
    .word 0
}

//----------------------------------------------------
// view_lines : print the stored lines, paginate if
// needed
//----------------------------------------------------

view_lines:
{
    mov r0,STREND
    ldx add_line.stored_lines
    beq end
loop:
    swi pprint_nl
    add r0,a
    inc r0
    txa
    pha
    jsr option_pagine
    pla
    tax
    dex
    bne loop
end:
    rts
}

//----------------------------------------------------
// progress : progress animation
//
// C=1 : init, X = steps, C=0 : run, 
// C= 1 and X = 0 : end
//----------------------------------------------------

progress:
{
    bcc not_init
    stx progress_skip
    cpx #0
    beq progress_end
    ldx #3
    jsr CHKOUT
    swi pprint,progress_msg
    ldx #8
start_of_line:
    lda #LEFT
    jsr CHROUT
    dex
    bne start_of_line
    stx progress_pos
    stx progress_nb
not_init:
    ldx #3
    jsr CHKOUT

    ldx #bios.COLOR_ACCENT
    swi theme_set_color
    lda progress_nb
    bne not_anim
    
    lda progress_skip
    sta progress_nb
anim:
    ldx progress_pos
    lda progress_anim,x
    bne anim_ok
    sta progress_pos
    beq anim
anim_ok:
    jsr CHROUT
    lda #LEFT
    jsr CHROUT
    inc progress_pos

not_anim:
    dec progress_nb
    swi pipe_output
    rts

progress_end:
    ldx #3
    jsr CHKOUT
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    ldx #8
pre_erase:
    lda #RIGHT
    jsr CHROUT
    dex
    bne pre_erase

    ldx #8
erase:
    lda #BACKSPACE
    jsr CHROUT
    dex
    bne erase
    swi pipe_output
    rts

progress_skip:
    .byte 0
progress_pos:
    .byte 0
progress_nb:
    .byte 0
progress_msg:
    pstring(" Working")
progress_anim:
    .byte 172,187,190,188,0
}

} // TAIL namespace
