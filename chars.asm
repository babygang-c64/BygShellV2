//----------------------------------------------------
// chars : char map / color map / petscii map
//
// options : 
// C = show color map
// P = show PETSCII map
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word chars
pstring("chars")

chars:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_C=1
    .label OPT_H=2
    .label OPT_P=4
    
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
    lda options_params
    and #OPT_P
    beq not_p
    
    jsr petscii_map
    jmp end
    
not_p:
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
    .byte 6,5,7,3
//    .byte 3,8,15,1

help_msg:
    pstring("*chars [option]")
    pstring(" c = List of colors")
    pstring(" p = PETSCII chars")
    pstring(" h = Help")
    .byte 0

options_chars:
    pstring("chp")

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

    ldx #bios.COLOR_TEXT
    swi theme_get_color
    sta box_draw.write_color

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
    ldx #bios.COLOR_TEXT
    swi theme_get_color
    sta box_draw.write_color

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

    ldx #bios.COLOR_TEXT
    swi theme_get_color
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
    tax
    swi theme_get_color
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
    pstring(" --- 00 -  0 - Black")
    pstring(" --- 01 -  1 - White")
    pstring(" --- 02 -  2 - Red")
    pstring(" --- 03 -  3 - Cyan")
    pstring(" --- 04 -  4 - Purple")
    pstring(" --- 05 -  5 - Green")
    pstring(" --- 06 -  6 - Blue")
    pstring(" --- 07 -  7 - Yellow")
    pstring(" --- 08 -  8 - Orange")
    pstring(" --- 09 -  9 - Brown")
    pstring(" --- 0A - 10 - Pink")
    pstring(" --- 0B - 11 - Dark Grey")
    pstring(" --- 0C - 12 - Middle Grey")
    pstring(" --- 0D - 13 - Light Green")
    pstring(" --- 0E - 14 - Light Blue")
    pstring(" --- 0F - 15 - Light Grey")
    .byte 0
}

petscii_map:
{
    mov r1,#petscii_data
    ldy #0
loop:
    lda (zr1l),y
    beq end
    push r1
    jsr write_line
    pop r1
    lda (zr1l),y
    add r1,a
    inc r1
    jmp loop

end:
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    rts
    
write_line:
    ldy #0
    sty wrote
    lda (zr1l),y
    sta nb_total
    inc r1

write_loop:
    lda (zr1l),y
    cmp #':'
    bne no_color1

    ldx #bios.COLOR_TITLE
    swi theme_set_color
    jmp next_char

no_color1:
    cmp #'*'
    bne no_color3
    
    ldx #bios.COLOR_CONTENT
    swi theme_set_color
    jmp next_char

no_color3:
    cmp #';'
    bne no_color2

    ldx #bios.COLOR_SUBTITLE
    swi theme_set_color
    lda #32
    
no_color2:
    jsr CHROUT
    inc wrote

next_char:
    inc r1
    dec nb_total
    bne write_loop

    lda wrote
    cmp #40
    beq no_nl
    swi pprint_nl
no_nl:
    lda wrote
    rts
    
nb_total:
    .byte 0
wrote:
    .byte 0
line:
    .byte 0
petscii_data:
    pstring("*PETSCII control chars")
    pstring(" ")
    pstring(":03;Stop   :05;White  :08;Disable shift+cmd")
    pstring(":09;Enable shift+cmd :0D;Return")
    pstring(":0E;Lowercase charset          :11;Down")
    pstring(":12;Rvs On :13;Home   :14;Delete :1C;Red")
    pstring(":1D;Right  :1E;Green  :1F;Blue   :81;Orange")
    pstring(":83;Shift run/stop   :85;F1     :86;F3")
    pstring(":87;F5     :88;F7     :89;F2     :8A;F4")
    pstring(":8B;F6     :8C;F8     :8D;Shift Return")
    pstring(":8E;Uppercase charset          :90;Black")
    pstring(":91;Up     :92;RvsOff :93;Clear  :94;Insert")
    pstring(":95;Brown  :96;Pink   :97;DarkGr :98;Grey")
    pstring(":99;LGreen :9A;LBlue  :9B;LGrey  :9C;Purple")
    pstring(":9D;Left   :9E;Yellow :9F;Cyan")
    pstring(" ")
    pstring("*Lowercase / Uppercase ")
    pstring(" ")
    pstring(":41-5A;a-z :C1-D1;A-Z")
    .byte 0
}

} // chars
