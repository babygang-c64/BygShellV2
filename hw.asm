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
pstring("HW")

//-- Good practice : wrap your code in a namespace

.label params_buffer=$cd80

hw:
{
    .label OPT_D=1
    .label work_buffer = $ce00


    // test int2bcd
    
    mov r0,#12345
    mov r1,#work_buffer
    jsr int2str
    swi pprint_nl,work_buffer

    mov r0,#0
    jsr int2str
    swi pprint_nl,work_buffer

    mov r0,#42
    jsr int2str
    swi pprint_nl,work_buffer

    mov r0,#64738
    jsr int2str
    swi pprint_nl,work_buffer
    
    ldx #%11000111
    swi pprint_int,#12345

    ldx #%11000111
    swi pprint_int,#42

    ldx #%11000111
    swi pprint_int,#0

    ldx #%11000111
    swi pprint_int,#64738

    rts
        
int2str:
{
.label skip = zsave
.label res = zr7l
    lda zr0l
    ora zr0h
    bne not_zero
    ldy #1
    lda #$30
    sta (zr1l),y
    bne end
not_zero:
    ldx #1
    stx skip
    dex
    stx res
    stx res+1
    stx res+2
    ldy #16
    sed
loop:
    asl zr0l
    rol zr0h
    ldx #2
add_loop:
    lda res,x
    adc res,x
    sta res,x
    dex
    bpl add_loop
    dey
    bne loop
    cld
    
    iny
    inx
loop_str:
    lda res,x
    pha
    lsr
    lsr
    lsr
    lsr
    jsr digit
    pla
    and #$0f
    jsr digit
    inx
    cpx #3
    bne loop_str
    
    dey
end:
    tya
    ldy #0
    sta (zr1l),y
    rts

digit:
    bne out
    lda skip
    bne done
out:
    ora #$30
    sta (zr1l),y
    iny
    lsr skip
done:
    rts
}

    // test device status
    
    ldx #8
    mov r0,#work_buffer
    sec
    swi get_device_status
    swi pprint_nl

    ldx #9
    mov r0,#work_buffer
    sec
    swi get_device_status
    swi pprint_nl
    
    clc
    rts

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

msg_test:
    pstring("This is device 9")

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
    pstring("DTNM")

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
