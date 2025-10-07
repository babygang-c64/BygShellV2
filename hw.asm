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


    // test memory
    swi bam_init, bam_root

    // alloc test

    ldx value5
    inx
    swi malloc, bam_root
    mov $1002,r0
    mov r1,r0
    swi str_cpy,value5

    ldx value2
    inx
    swi malloc, bam_root
    mov $1004,r0
    mov r1,r0
    swi str_cpy,value2



    mov $1000, #bam_root
    mov r0, $1002
    mov r1, #bam_root
    swi free
    rts

value1:
    pstring("test value 1 this is also a smaller value than next one")
value2:
    pstring("and test number 2 with different value which is way longer than the first one")
value3:
    pstring("ok and now third one should be even longer just to test the allocation process to see what's going on, you know we want to use a lot of space to need another block of data!")
value4:
    pstring("au debut c'etait le debut et plus vite c'etait la suite... c'est du bashung non ?")

value5:
    pstring("small")
bam_root:
    bam($2000,8)


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
