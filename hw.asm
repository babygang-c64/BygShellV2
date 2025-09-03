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

.label params_buffer=$ce00

hw:
{
    .label OPT_D=1
    .label work_buffer = $ce00

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
    rts


help:
    swi pprint_lines, help_hw
    clc
    rts

    //-- return with C=1 : ERROR
    sec
    rts

default_message:
    pstring("HELLO WORLD!")
    
    //-- options available
options_hw:
    pstring("DTNM")

help_hw:
    pstring("*HW [MESSAGE] [-D] : PRINTS MESSAGE")
    pstring(" D = PRINT DEFAULT MESSAGE")
    .byte 0
}
