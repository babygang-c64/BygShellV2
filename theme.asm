//----------------------------------------------------
// theme : change theme
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word theme
pstring("theme")

theme:
{
    .label params_buffer = $cd00
    .label OPT_L=1
    
    //-- init options
    sec
    swi param_init,buffer,options_theme
    jcs help

    lda options_params
    and #OPT_L
    beq not_list
    
    swi pprint_lines,themes
    jmp end
    
not_list:

    //-- no parameters = print help
    ldx nb_params
    jeq help

    sec
    swi param_process,params_buffer
    mov r1,r0
    mov r0,#themes
    swi lines_find
    bcc not_found

    mov r0,#themes_colors
    txa
    asl
    asl
    add r0,a
    sec
    swi theme

end:
    clc
    swi success
    rts

not_found:
    mov r0,msg_not_found
    clc
    swi error
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts
    
    //-- options available
options_theme:
    pstring("l")

msg_not_found:
    pstring("Theme not found")

msg_help:
    pstring("*theme <theme> [options]")
    pstring(" -l : list themes")
    .byte 0

themes:
    pstring("normal")
    pstring("ocean")
    pstring("retro")
    pstring("neon")
    pstring("forest")
    pstring("mono")
    .byte 0
themes_colors:
    .word $71E6,$3fe6
    .word $6e13,$7cfa
    .word $4b07,$1f3c
    .word $067d,$a28f
    .word $5c3f,$d71a
    .word $0b1f,$c37e
}
