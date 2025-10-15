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
    sec
    swi error,msg_not_found
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
    pstring("classic")
    pstring("solar")
    pstring("monokai")
    pstring("xterm")
    pstring("zenburn")
    pstring("paper")
    pstring("green")
    pstring("amber")
    pstring("dracula")
    pstring("gruvbox")
    pstring("dark")
    pstring("nord")
    pstring("one-dark")
    pstring("tokyo")
    pstring("cattppuccin")
    pstring("everforest")
    pstring("rosepine")
    pstring("kanagawa")
    pstring("c128")
    pstring("c16")
    pstring("plus4")
    pstring("sx64")
    .byte 0

themes_colors:
    .word $71E6,$3F5E  // Classic        - blue bg, white text, light-blue accents
    .word $E100,$3D5C  // Solarized      - dark-blue bg, light-grey text, cyan/yellow subs
    .word $7A00,$2F4E  // Monokai        - black bg, light-orange text, green accent
    .word $1500,$3C7E  // XTerm          - black bg, light-grey text, cyan accent
    .word $9C00,$4D5E  // Zenburn        - olive bg, grey text, pale-green titles
    .word $20F1,$044D  // Paper Light    - light-grey bg, black text, blue title, grey accents
    .word $3500,$2D5E  // Retro Green    - black bg, green text, cyan titles
    .word $A800,$4C7E  // Amber          - black bg, orange text, yellow accents
    .word $E400,$2F5C  // Dracula        - black bg, magenta text, cyan/yellow subs
    .word $9C00,$4A7E  // Gruvbox        - black bg, beige text, orange accent
    .word $C100,$3D7E  // Dark           - black bg, white text, cyan accents
    .word $B1E6,$4F5C  // Nord           - dark-blue bg, snow white, frost blue accents
    .word $7100,$2F5E  // One Dark       - very dark blue bg, grey text, blue accents
    .word $4100,$2F6E  // Tokyo Night    - deep blue bg, light-blue text, purple accents
    .word $E1F6,$7F4C  // Catppuccin     - mauve bg, text white, peach accents
    .word $5100,$3D5E  // Everforest     - dark-green bg, light-grey text, green accents
    .word $E1B6,$7F4C  // Rose Pine      - purple bg, rose text, gold accents
    .word $A100,$3F4E  // Kanagawa       - dark bg, peach text, dragon blue 
    .word $D5B0,$3C7E  // Boot128: fond gris foncé, texte vert clair, accent vert, bord=fond
    .word $15F0,$3C7E  // BootC16: fond gris clair, texte noir, accent blanc, bord=fond
    .word $71F0,$3C7E  // Plus4: fond blanc, texte noir, accent jaune, bord=fond
    .word $36F1,$3C7E  // SX64: fond blanc, texte bleu, accent cyan, bord=fond
}
