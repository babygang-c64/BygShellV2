//----------------------------------------------------
// hw : hello world external command example
//
//----------------------------------------------------

//----------------------------------------------------
// Imports: 
// - BIOS call entries
// - Macros for pseudo instructions support 
//   (you have to run pkick.py to pre-process)
// - Kernal entry points
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

//-- Start address for external commands is always $C000
//-- In $CF00 there is an internal variables space, with
//-- parameter infos stored starting at $CF80 as a list 
//-- of PSTRINGS
//-- In $CFFE / $CFFF you have the options and parameters
//-- number

* = $c000

//-- First word is the start address, then a PSTRING of the
//-- command name for use with the command cache

.word hw
pstring("hw")

//-- Good practice : wrap your code in a namespace

.label params_buffer=$cd80

hw:
{
    .label OPT_D=1
    .label work_buffer = $ce00


    jsr history.init

    mov r0,#str1
    jsr history.insert
    mov r0,#str2
    jsr history.insert
    jsr view

    mov r0,#str3
    jsr history.insert
    mov r0,#str4
    jsr history.insert
    jsr view

    mov r0,#str1
    jsr history.insert
    jsr view

    mov r0,#str3
    jsr history.insert
    jsr view
    
    mov r0,#str2
    jsr history.insert
    jsr view

    clc
    jmp CLRCHN

view:
{
    swi pprint_nl,msg_line
    lda $1000
    ora #$30
    jsr CHROUT
    lda #13
    jsr CHROUT
    ldx $1000
    mov r0,#$1002
next_view:
    swi pprint_nl
    swi str_next
    dex
    bne next_view
    swi screen_pause
    rts
}

msg_line:
    pstring("--------------------")
str1:
    pstring("test value 1")
str2:
    pstring("what's up doc ?")
str3:
    pstring("this is the test value 2")
str4:
    pstring("last test value is number four")



    //-- init options
    sec
    swi param_init,buffer,options_hw
    jcs help

    //-- no parameters = print help
    ldx nb_params
    bne params_present
    lda options_params
    beq help

params_present:

    // message = 1st parameter, buffer is the parameters buffer
    // at $CF80.
    swi param_top

    //-- check options for OPT_D
    lda options_params
    and #OPT_D
    beq no_option_d
    
    mov r0,#default_message
    
    //-- print the message
no_option_d:

    mov r1, #work_buffer
    swi str_expand

    swi pprint_nl, work_buffer

    //-- return with C=0 : OK
    clc
    swi success
    rts

help:
    swi pprint_lines, help_hw
    clc
    rts

    //-- return with C=1 : ERROR
    sec
    swi error
    rts

default_message:
    pstring("Hello World !")
    
    //-- options available
options_hw:
    pstring("dtnm")

help_hw:
    pstring("*hw [message] [-d] : Prints message")
    pstring(" d = Print default message")
    .byte 0
return_string:
    .text "SH$"
string_len:
    .byte 0
string_storage:
    .word 0

}

//------------------------------------------------------------
// history : history of commands
//------------------------------------------------------------


history:
{
.label history_buffer=$1000
.label max_history=4

init:
    lda #0
    sta history_buffer
    sta history_buffer+1
    rts

goto:
    ldy #0
    mov r0,#history_buffer+2
    cpx #0
    beq found
do_goto:
    jsr bios.bios_ram_get_byte
    sec
    adc zr0l
    sta zr0l
    bcc pas_inc
    inc zr0h
pas_inc:
    dex
    bne do_goto
found:
    rts

insert:
    ldy #0
    push r0
    mov r0,#history_buffer
    jsr bios.bios_ram_get_byte
    tax
    stx ztmp
    cmp #max_history
    beq hist_max
    jsr goto
store_value:
    ldx ztmp
    inx
    stx history_buffer
    stx history_buffer+1
only_store:
    mov r1,r0
    pop r0
    swi str_cpy
    rts
    
hist_max:
    jsr goto
    sub r0,#history_buffer+2
    mov r2,r0
    ldx #1
    jsr goto
    mov r1,#history_buffer+2
move_data:
    jsr bios.bios_ram_get_byte
    mov (r1++),a
    inc r0
    dec r2
    bne move_data
    ldx #max_history-1
    jsr goto
    jmp only_store
}
