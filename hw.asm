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
    .label my_list_heap = $8000

    mov r0,#chaine_couleur
    swi pprint_color
    lda #13
    jsr CHROUT

    ldx #2
    mov r0,#my_list_root
    mov r1,#my_list_heap
    swi list_init
    
//    ldx retour
//    mov r0,#my_list_root
//    swi list_alloc

    mov r0,#my_list_root
    mov r1,#retour
    swi list_insert

    mov r0,#my_list_root
    mov r1,#chaine2
    swi list_insert

    mov r0,#my_list_root
    mov r1,#chaine3
    swi list_insert

    mov r0,#my_list_root
    mov r1,#chaine4
    swi list_insert
    
    mov r0,#my_list_root
    mov r1,#chaine2
    swi list_search
    stc $0428
    mov $0400,r0

    mov r0,#my_list_root
    mov r1,#chaine4
    swi list_search
    stc $0428+1
    mov $0402,r0

    mov r0,#my_list_root
    mov r1,#my_list_root
    swi list_search
    stc $0428+2
    mov $0404,r0

    rts

retour:
    pstring("retour ok")
chaine2:
    pstring("pstring2")
chaine3:
    pstring("troisieme")
chaine4:
    pstring("et quatre")
chaine_couleur:
    pstring("un %2deux%4 100%% trois%3")


my_list_root:
{
    .word 0
    .word 0
    .word 0
    .word 0
    .byte 0
}

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


