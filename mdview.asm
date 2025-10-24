//----------------------------------------------------
// mdview : navigate markdown files
//
// options : 
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word mdview
pstring("mdview")

mdview:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_A=1

    sec
    swi param_init,buffer,options_mdview
    jcs error

    ldx nb_params
    jeq help

    ldy #0
    sec
    swi param_process,params_buffer

    ldx #4
    clc
    swi file_open
    jcs error_open

boucle_load:
    swi file_readline, work_buffer
    bcs ok_close

    lda options_params
    and #OPT_A
    beq not_opt_a
    
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
    
not_opt_a:
    clc
    mov r0,#work_buffer
    jsr add_line
    jmp boucle_load
    ldx #4
    swi file_close
    
    clc
    swi success
    rts
    
help:
    swi pprint_lines,help_msg
    clc
    rts

msg_open:
    pstring("File open")

error_open:
    mov r0,#msg_open
    sec
    bcs do_error
error:
    clc
do_error:
    swi error
    rts


help_msg:
    pstring("*mdview <filename> [-a]")
    pstring(" a = Convert ASCII")
    .byte 0

options_mdview:
    pstring("a")

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

view_lines:
{
    mov r0,STREND
    ldx add_line.stored_lines
    beq end
loop:
    swi pprint_nl
    add r0,a
    inc r0
    dex
    bne loop
end:
    rts
}

} // MDVIEW namespace
