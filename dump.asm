//----------------------------------------------------
// dump : dump BASIC variables
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word dump
pstring("dump")

dump:
{
    .label params_buffer = $cd00
    .label work_buffer = $ce00
    .label OPT_S = 1
    .label OPT_I = 2
    .label OPT_F = 4
    .label OPT_H = 8
    .label OPT_P = 16
    .label OPT_N = 32
    
    //-- init options
    sec
    swi param_init,buffer,options_dump
    jcs help

    //-- parameter H = print help
    lda options_params
    and #OPT_H
    jne help

    jsr define_type_filter
    sec
    jsr option_pagination

    swi pipe_init
    jcs error

    sec
    swi param_process,params_buffer

    swi pipe_output
    jsr do_dump

end:
    swi pipe_end
    clc
    swi success
    rts

error:
    clc
    swi error
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts
    
    //-- options available
options_dump:
    pstring("sifhpn")

msg_help:
    pstring("*dump [options]")
    pstring(" -s : string variables")
    pstring(" -i : integer variables")
    pstring(" -f : float variables")
    pstring(" -n : show names only")
    pstring(" -p : paginate output")
    pstring(" -h : show help")
    .byte 0

filter_int:
    .byte 0
filter_string:
    .byte 0
filter_float:
    .byte 0

option_pagination:
{
    lda options_params
    and #OPT_P
    jne no_paginate
no_paginate:
    rts
}

define_type_filter:
{
    lda options_params
    and #OPT_I+OPT_S+OPT_F
    bne is_something
    lda #1
    sta filter_int
    sta filter_string
    sta filter_float
    rts
is_something:
    lda options_params
    and #OPT_I
    sta filter_int

    lda options_params
    and #OPT_S
    sta filter_string

    lda options_params
    and #OPT_F
    sta filter_float
    rts
}

do_dump:
{
    mov r1,VARTAB
loop:
    cmpw r1,ARYTAB
    jcs end

    ldy #0
    sty INDEX1
    iny

get_name:
    mov a,(r1)
    asl
    ror INDEX1
    lsr
    sta VARNAM,y
    dey
    bpl get_name
    
    bit INDEX1
    beq is_float
    bpl is_string
    bvc is_other

is_int:
    lda filter_int
    beq next_var_no_cr
    
    ldx #'%'
    jsr print_name
    bcs next_var
    ldy #2
    mov a,(r1)
    sta zr0h
    iny
    mov a,(r1)
    sta zr0l
    jsr print_int
    jmp next_var

is_string:
    lda filter_string
    beq next_var_no_cr
    
    ldx #'$'
    jsr print_name
    bcs next_var
    
    lda #34
    jsr CHROUT
    
    ldy #$04
    mov a,(r1)
    sta INDEX1+1
    dey
    mov a,(r1)
    sta INDEX1
    dey
    mov a,(r1)
    jsr STRPRT2    
    lda #34
    jsr CHROUT
    jmp next_var

is_float:
    lda filter_float
    beq next_var_no_cr

    ldx #0
    jsr print_name
    bcs next_var
    
    mov $5f,r1
    jsr $B185
    jsr $BBA2
    jsr $BDD7
    jmp next_var
is_other:
    
    // next variable = skip 7 bytes
next_var:
    lda #13
    jsr CHROUT
    clc
    jsr option_pagination
    bcs end

next_var_no_cr:
    // check run/stop
    jsr STOP
    beq end

    add r1,#7
    jmp loop

end:
    rts

print_name:
    lda VARNAM
    jsr CHROUT
    lda VARNAM+1
    jsr CHROUT
    cpx #0
    bne not_zero
    ldx #32
not_zero:
    txa
    jsr CHROUT
end_print_name:
    lda options_params
    and #OPT_N
    beq with_value
    sec
    rts
with_value:
    lda #'='
    jsr CHROUT
    clc
    rts
    
print_int:
    lda zr0h
    bmi is_negative
non_negative:
    ldx #%11011111
    swi pprint_int
    rts
is_negative:
    sec
    lda #0
    sbc zr0l
    sta zr0l
    lda #0
    sbc zr0h
    sta zr0h
    lda #'-'
    jsr CHROUT
    jmp non_negative
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

}
