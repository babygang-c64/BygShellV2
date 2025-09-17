//----------------------------------------------------
// head : print head of file(s)
//
// options : 
// N = number of lines to print
// Q = don't print filename
// V = always print filename
// P = paginate
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word chars
pstring("CHARS")

chars:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_C=1
    .label OPT_H=2
    
    sec
    swi param_init,buffer,options_chars
    jcs error

    lda options_params
    and #OPT_H
    bne help

    lda #147
    jsr CHROUT
    
    lda options_params
    and #OPT_C
    beq not_c
    
    jsr color_map
    jmp end
    
not_c:
    jsr char_map

end:
    ldy #0
    ldx #21
    jsr move_cursor
    clc
    swi success
    rts

help:
{
    swi pprint_lines, help_msg
    sec
    rts
}

move_cursor:
{
    clc
    jmp PLOT
}

error:
    sec
    swi error
    rts

pos_y:
    .byte 0
hex_value:
    .byte 0
hex_values:
    .text "0123456789"
    .byte 1,2,3,4,5,6
current_char:
    .byte 0
current_color:
    .byte 3,8,15,1

help_msg:
    pstring("*CHARS [-CH]")
    pstring(" C = LIST OF COLORS")
    pstring(" H = HELP")
    .byte 0

options_chars:
    pstring("CH")

    // box draw structure :
    // start_x, start_y
    // width, height
    // color, reverse

box_chars:
    .byte 3,2,34,18,1,0

box_draw:
{
    .label pos_x=0
    .label pos_y=1
    .label lgr_x=2
    .label lgr_y=3
    .label color=4
    .label reverse=5

    mov r1,#write_box
    ldy #reverse
copy:
    mov a,(r0)
    mov (r1),a
    dey
    bpl copy

    mov r1,r0

    ldx write_lgr_x
    dex
    stx add_x
    ldx write_lgr_y
    dex
    stx add_y
    ldx write_lgr_x
    dex
boucle_haut:
    ldy #pos_y
    mov a,(r1)
    sta write_y
    inc write_x
    lda #64
    jsr write_char

    lda write_y
    clc
    adc add_y
    sta write_y
    
    lda #64
    jsr write_char
    
    dex
    bne boucle_haut
    
    ldy #pos_y
    mov a,(r1)
    tax
    inx
    sta write_y
    ldx add_y
    dex
boucle_bord:
    ldy #pos_x
    mov a,(r1)
    sta write_x
    inc write_y
    
    lda #93
    jsr write_char
    
    lda write_x
    clc
    adc add_x
    sta write_x
    
    lda #93
    jsr write_char

    dex
    bne boucle_bord
    
    ldy #pos_x
    mov a,(r1)
    sta write_x
    iny
    mov a,(r1)
    sta write_y
    lda #112
    jsr write_char
    lda write_y
    clc
    adc add_y
    sta write_y
    lda #109
    jsr write_char
    lda write_x
    clc
    adc add_x
    sta write_x
    lda #125
    jsr write_char
    ldy #pos_y
    mov a,(r1)
    sta write_y
    lda #110
    jsr write_char

    rts

write_char:
    pha
    lda write_y
    asl
    tay
    lda screen_adr,y
    sta zr0l
    lda screen_adr+1,y
    sta zr0h
    ldy write_x
    lda write_reverse
    beq no_reverse
    pla
    ora #$80
    jmp do_write
no_reverse:
    pla
do_write:
    mov (r0),a
    clc
    lda zr0h
    adc #$d4
    sta zr0h
    lda write_color
    mov (r0),a
    rts

add_x:
    .byte 0
add_y:
    .byte 0
write_box:
write_x:
    .byte 0
write_y:
    .byte 0
write_lgr_x:
    .byte 0
write_lgr_y:
    .byte 0
write_color:
    .byte 0
write_reverse:
    .byte 0

screen_adr:
    .for(var y = 0; y < 25; y++)
    { .word $0400+40*y }
    
}

char_map:
{
    mov r0,#box_chars
    jsr box_draw
    lda #0
    sta current_char
    lda #4
    sta box_draw.write_x
    lda #3
    sta box_draw.write_y

    ldx #16
boucle_chars:
    lda current_char
    jsr box_draw.write_char
    inc box_draw.write_x
    inc box_draw.write_x
    inc current_char
    dex
    bne boucle_chars

    lda #1
    sta box_draw.write_color
    lda #2
    sta box_draw.write_x
    lda #'0'
    jsr box_draw.write_char
    lda #38
    sta box_draw.write_x
    lda #'0'
    jsr box_draw.write_char

    lda box_draw.write_y
    sec
    sbc #3
    tay
    dec box_draw.write_x
    lda hex_values,y
    sta hex_value
    jsr box_draw.write_char
    lda #1
    sta box_draw.write_x
    lda hex_value
    jsr box_draw.write_char

    lda box_draw.write_y
    sta pos_y
    sec
    sbc #3
    asl
    clc
    adc #4
    sta box_draw.write_x
    lda #1
    sta box_draw.write_y
    lda hex_value
    jsr box_draw.write_char
    lda #20
    sta box_draw.write_y
    lda hex_value
    jsr box_draw.write_char

    lda pos_y
    sta box_draw.write_y
    inc box_draw.write_y
    lda box_draw.write_y
    and #3
    tay
    lda current_color,y
    pha
    sta box_draw.write_color
    lda #37
    sta box_draw.write_x
    pla
    sta box_draw.write_color

    lda #4
    sta box_draw.write_x
    ldx #16
    lda current_char
    jne boucle_chars
    rts
} 

color_map:
{

    ldy #0
    ldx #2
    sty color
    jsr move_cursor
    swi pprint_lines,color_names

    ldx #2
    
boucle:
    lda #1
    sta box_draw.write_x
    stx box_draw.write_y
    lda color
    sta box_draw.write_color
    lda #228
    jsr box_draw.write_char
    inc box_draw.write_x
    lda #228
    jsr box_draw.write_char
    inc box_draw.write_x
    lda #228
    jsr box_draw.write_char
 
    inc color
    inx
    cpx #18
    bne boucle
    rts

color:
    .byte 0

color_names:
    pstring(" --- 00 -  0 - BLACK")
    pstring(" --- 01 -  1 - WHITE")
    pstring(" --- 02 -  2 - RED")
    pstring(" --- 03 -  3 - CYAN")
    pstring(" --- 04 -  4 - PURPLE")
    pstring(" --- 05 -  5 - GREEN")
    pstring(" --- 06 -  6 - BLUE")
    pstring(" --- 07 -  7 - YELLOW")
    pstring(" --- 08 -  8 - ORANGE")
    pstring(" --- 09 -  9 - BROWN")
    pstring(" --- 0A - 10 - PINK")
    pstring(" --- 0B - 11 - DARK GREY")
    pstring(" --- 0C - 12 - MIDDLE GREY")
    pstring(" --- 0D - 13 - LIGHT GREEN")
    pstring(" --- 0E - 14 - LIGHT BLUE")
    pstring(" --- 0F - 15 - LIGHT GREY")
    .byte 0
}

} // chars
