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
    
    //-- init options
    sec
    swi param_init,buffer,options_dump
    jcs help

    swi pipe_init
    jcs error

    //-- parameter H = print help
    lda options_params
    and #OPT_H
    jne help


    sec
    swi param_process,params_buffer

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
    pstring("sifh")

msg_help:
    pstring("*dump [prefix] [option]")
    pstring(" -s : string variables")
    pstring(" -i : integer variables")
    pstring(" -f : float variables")
    pstring(" -h : show help")
    .byte 0

do_dump:
{
    mov r1,VARTAB
loop:
    cmpw r1,ARYTAB
    bcs end

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
    ldx #'%'
    jsr print_name
    ldy #2
    mov a,(r1)
    sta zr0h
    iny
    mov a,(r1)
    sta zr0l
    jsr print_int
    lda #13
    jsr CHROUT

is_float:
is_string:
is_other:
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
    beq end_print_name
    txa
    jsr CHROUT
end_print_name:
    lda #'='
    jmp CHROUT
    
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

}
