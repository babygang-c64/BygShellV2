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
    .label OPT_C=8
    
    //-- init options
    sec
    swi param_init,buffer,options_theme
    jcs help

    lda options_params
    and #OPT_C
    beq not_current
    
    swi pprint,#msg_current
    ldy #0
    mov r0,#bios.theme_name
    jsr bios.bios_ram_get_byte
    tax
print_ram:
    iny
    jsr bios.bios_ram_get_byte
    jsr CHROUT
    dex
    bne print_ram
    lda #']'
    jsr CHROUT
    jsr test_theme.nl
    jmp end
    
not_current:
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
    pstring("ltsc")

msg_not_found:
    pstring("Theme not found")

msg_help:
    pstring("*theme <theme> [options]")
    pstring(" -l : list themes")
    pstring(" -t : test themes")
    pstring(" -s : interactive select")
    pstring(" -c : current theme")
    .byte 0

msg_current:
    pstring("Current theme is [")

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

    mov r1,#bios.theme_name
    swi str_cpy
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

    ldx #bios.COLOR_CONTENT
    swi theme_set_color
    swi pprint_lines,msg_content
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
    cpx #40
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
    
msg_content:
    pstring("Content:")
    pstring("Used for menu items too")
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
    pstring("solar-dark")
    pstring("solar")
    pstring("monokai")
    pstring("xterm")
    pstring("zenburn")
    pstring("paper")
    pstring("matrix")
    pstring("amber")
    pstring("one-dark")
    pstring("tomorrow")
    pstring("c128")
    pstring("sx64")
    pstring("amiga")
    pstring("sepia")
    pstring("simon")
    .byte 0

    // colors : accent - text - border - background
    //          content - notes - title - subtitle

themes_colors:
    .word $71E6,$3F5E  // Classic
    .word $3F00,$C5E3  // Solarized dark
    .word $3FBB,$1E7D  // Solarized
    .word $4FBB,$FD38  // Monokai
    .word $E100,$F573  // XTerm
    .word $DFBB,$C573  // Zenburn
    .word $6011,$B548  // Paper light
    .word $D500,$5f17  // Matrix
    .word $8799,$F87F  // Retro amber
    .word $EF00,$CD84  // One dark
    .word $2F00,$C57E  // Tomorrow night
    .word $5D50,$D1FB  // C128
    .word $E631,$FBE4  // SX64
    .word $8166,$FE1C  // Amiga
    .word $8719,$C573  // Sepia
    .word $D0CB,$5F17  // Simons basic
}
