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
    .label OPT_T=2
    .label OPT_S=4
    
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

    lda options_params
    and #OPT_S
    beq not_opt_s

    ldx nb_params
    bne not_opt_s
    
    stx theme_id
    jmp restart

not_opt_s:
    //-- no parameters = print help
    ldx nb_params
    jeq help

    jsr save_colors

    sec
    swi param_process,params_buffer
    mov r1,r0
    mov r0,#themes
    swi lines_find
    jcc not_found

view_theme:
    mov r0,#themes_colors
    txa
    stx theme_id
    asl
    asl
    add r0,a
    sec
    swi theme
    
    // T = test theme, S = select theme
    
    
    lda options_params
    and #OPT_S+OPT_T
    beq end
    
    jsr test_theme

    swi key_wait
    bcs selected
    sta last_key
    cmp #RETURN
    beq selected
    
    lda options_params
    and #OPT_S
    beq not_s

    lda last_key
    cmp #UP
    bne not_up
    
    ldx theme_id
    beq restart
    dec theme_id
    jmp up 
    
not_up:
    inc theme_id
up:
    ldx theme_id
restart:
    swi lines_goto,#themes
    bcs next_ok
    ldx #0
    stx theme_id
    jmp restart
next_ok:
    mov r1,r0
    ldx theme_id
    jmp view_theme
    
not_s:
    jsr restore_colors
    
selected:
    lda #147
    jsr CHROUT
    jsr CLRCHN

end:
    clc
    swi success
    rts

not_found:
    jsr restore_colors
    sec
    swi error,msg_not_found
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts

save_colors:
    mov r0,#saved
    clc
    swi theme
    rts
    
restore_colors:
    mov r0,#themes_colors
    sec
    swi theme
    rts 
    
saved:
    .word 0
    .word 0

theme_id:
    .byte 0
last_key:
    .byte 0

    //-- options available
options_theme:
    pstring("lts")

msg_not_found:
    pstring("Theme not found")

msg_help:
    pstring("*theme <theme> [options]")
    pstring(" -l : list themes")
    pstring(" -t : test themes")
    pstring(" -s : select")
    .byte 0

test_theme:
{
    lda #147
    jsr CHROUT
    jsr nl
    jsr nl
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    swi pprint,msg_title
    mov r0,r1
    swi pprint_nl
    jsr nl
    ldx #bios.COLOR_SUBTITLE
    swi theme_set_color
    swi pprint_lines,msg_subtitle
    jsr nl
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    swi pprint_lines,msg_text
    jsr nl
    ldx #bios.COLOR_NOTES
    swi theme_set_color
    swi pprint_lines,msg_notes
    jsr nl
    ldx #bios.COLOR_ACCENT
    swi theme_set_color
    swi pprint_lines,msg_accent

    ldx #bios.COLOR_CONTENT
    swi theme_set_color
    ldx #0
    ldy #0
status:
    cpy msg_status
    beq status_done
    lda msg_status+1,y
    ora #$80
    sta $0400,x
    lda CURSOR_COLOR
    sta $d800,x
    inx
    iny
    bne status
status_done:
    lda #32+128
    sta $0400,x
    lda CURSOR_COLOR
    sta $d800,x
    inx
    cpx #39
    bne status_done
    ldx #bios.COLOR_ACCENT
    swi theme_get_color
    ldx #5
do_accent:
    sta $d800,x
    inx
    cpx #11
    bne do_accent

    ldx #bios.COLOR_TEXT
    swi theme_set_color
    rts

nl:
    lda #13
    jmp CHROUT
    
msg_title:
    pstring("### Title color for theme ")
msg_subtitle:
    pstring("Subtitle:")
    pstring("What is the demoscene ?")
    .byte 0
msg_text:
    pstring("Text:")
    pstring("The scene started with the home")
    pstring("computer revolution of the early")
    pstring("1980s, and the subsequent advent")
    pstring("of software cracking.")
    .byte 0
msg_notes:
    pstring("Notes:")
    pstring(@"  ldx #bios.COLOR\$a4NOTES")
    pstring(@"  swi theme\$a4set\$a4color")
    pstring(@"  swi pprint\$a4lines,msg\$a4notes")
    .byte 0
msg_accent:
    pstring("[Return = select, up/down = move]")
    pstring("(accent)")
    .byte 0
msg_status:
    pstring("Theme File Edit View Text Window Help")
}

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
