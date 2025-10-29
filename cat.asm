//----------------------------------------------------
// cat : print file(s)
//
// options : 
// N = numbers all lines
// E = prints a $ sign at the end of line
// B = numbers non empty lines
// P = paginates output
// H = hexdump
// S = reads start address in file for hexdump
// > = outputs to file
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word cat
pstring("cat")

cat:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_B=1
    .label OPT_E=2
    .label OPT_N=4
    .label OPT_P=8
    .label OPT_H=16
    .label OPT_S=32
    .label OPT_A=64
    .label OPT_Z=1

    mov r0,#buffer
    mov r1,#options_more
    jsr param_more_options
    sta more_options
    
    sec
    swi param_init,buffer,options_cat
    jcs error
    swi pipe_init
    jcs error

    ldx nb_params
    jeq help


    mov current_line,#0
    ldy #0
    sty with_start_line
    sty with_end_line
    sty was_empty
    
    ldx #'S'
    swi param_get_value
    bcc no_start_line
    mov start_line,r0
    inc with_start_line

no_start_line:
    ldx #'E'
    swi param_get_value
    bcc no_end_line
    mov end_line,r0
    inc with_end_line

no_end_line:
    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    jsr do_cat
    clc
    jmp boucle_params

fin_params:
    swi pipe_end
    clc
    swi success
    rts

do_cat:
    // initialisation
    ldy #0
    sty num_lignes
    sty num_lignes+1

    // name = 1st parameter
    //swi param_top
    
    sec
    jsr option_pagine

    ldx #4
    clc
    swi file_open
    jcs error
    
    lda with_start_line
    bne boucle_cat

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
    jcs ok_close

    swi print_hex_buffer
    add r1,#8
    lda #13
    jsr CHROUT
    jmp boucle_cat

derniere_ligne_hex:
    swi pipe_output
    swi print_hex_buffer
    lda #13
    jsr CHROUT
    jmp ok_close
    
pas_hexdump:    
    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    jcs ok_close
    incw current_line
    
    lda more_options
    and #OPT_Z
    beq test_a

    mov r0,#work_buffer
    jsr str_empty
    bcc not_empty

    lda was_empty
    jne boucle_cat

    inc was_empty
    jmp test_a
    
not_empty:
    ldy #0
    sty was_empty
    
test_a:
    lda options_params
    and #OPT_A
    beq pas_opt_a
    
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
    
pas_opt_a:

    swi pipe_output

affiche_ligne:

    lda with_start_line
    beq not_with_start_line
    cmp #2
    beq not_with_start_line

    cmpw start_line,current_line
    bne no_print
    inc with_start_line

not_with_start_line:
    jsr option_numero
    swi pprint, work_buffer
    
    // if E with value, not $
    lda with_end_line
    beq test_e
    cmp #2
    beq pas_option_e
    cmpw end_line,current_line
    bne pas_option_e
    lda #1
    sta with_start_line
    jmp pas_option_e

test_e:
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
    jcs ok_close

no_print:
    jmp boucle_cat

help:
    swi pprint_lines,help_msg
    sec
    rts

ok_close:
    ldx #4
    swi file_close
    clc
    rts

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
    pstring("*cat <filename> [option]")
    pstring(" n = Numbers all lines")
    pstring(" e = $ At EOL / end line")
    pstring(" z = squeeze empty lines")
    pstring(" b = Numbers non empty lines")
    pstring(" p = Paginates output")
    pstring(" h = Hexdump")
    pstring(" s = Start address for hexdump")
    pstring("     or start line with value")
    pstring(" a = Do ASCII conversion")
    .byte 0

options_cat:
    pstring("benphsa")

more_options:
    .byte 0
options_more:
    pstring("z")

was_empty:
    .byte 0
start_line:
    .word 0
end_line:
    .word 0
with_start_line:
    .byte 0
with_end_line:
    .byte 0
current_line:
    .word 0
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
    and #OPT_S
    beq pas_opt_s
    ldx #4
    jsr CHKIN
    jsr CHRIN
    sta zr1l
    jsr CHRIN
    sta zr1h

pas_opt_s:
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
    cmp #23
    bne pas_opt_p

    lda #0
    sta cpt_ligne
    push r0
    swi screen_pause
    stc is_break
    pop r0
    ldc is_break
    rts

pas_opt_p:
    clc
    rts

cpt_ligne:
    .byte 0
is_break:
    .byte 0
}

//----------------------------------------------------
// str_empty : check if R0 is empty (size zero or
// only spaces)
// returns C=1 if empty
//----------------------------------------------------

str_empty:
{
    ldy #0
    lda (zr0l),y
    beq is_empty
    tay
loop:
    lda (zr0l),y
    cmp #32
    bne not_empty
    dey
    bne loop
is_empty:
    sec
    rts
not_empty:
    clc
    rts
}

//----------------------------------------------------
// param_more_options : extract options from params
// buffer in r0, list of options in r1, return in A
//----------------------------------------------------

param_more_options:
{
    lda nb_params
    sta cpt_params
    ldy #0
    mov r2,r0
    sty options
    lda (zr0l),y
    beq end
    lda (zr1l),y
    beq end

loop:
    lda (zr0l),y
    cmp #2
    bne not_option
    iny
    lda (zr0l),y
    cmp #'-'
    bne not_option
    
    // check if in list, get position
    iny
    lda (zr0l),y
    sta option_char

    ldy #0
    lda (zr1l),y
    tay

test_option:
    lda (zr1l),y
    cmp option_char
    beq found_option
    dey
    bpl test_option

    // not option, copy and loop
not_option:
    ldy #0
    lda (zr0),y
    tax
copy_param:
    mov a,(r0++)
    mov (r2++),a
    dex
    bpl copy_param
next_param:
    dec cpt_params
    bpl loop

    // end, return options
end:
    lda options
    rts

    // found ? set bit and ignore
found_option:
    dey
    lda options
    ora bits,y
    sta options
    ldy #0
    add r0,#3
    dec nb_params
    dec cpt_params
    bmi end
    bpl loop

cpt_params:
    .byte 0
options:
    .byte 0
option_char:
    .byte 0
bits:
    .byte 1,2,4,8,16,32,64,128
}

} // CAT namespace
