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

    .label OPT_L=1

    sec
    swi param_init,buffer,options_head
    jcs error
    
    lda #147
    jsr CHROUT
    
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

    inc box_draw.write_y
    lda box_draw.write_y
    and #3
    tay
    lda current_color,y
    sta box_draw.write_color

    lda #4
    sta box_draw.write_x
    ldx #16
    lda current_char
    bne boucle_chars
    
    clc
    rts
error:
    sec
    rts

current_char:
    .byte 0
current_color:
    .byte 3,8,15,1

help_msg:
    pstring("*CHARS [-L]")
    pstring(" L = LIST OF CHARS")
    .byte 0

options_head:
    pstring("L")

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

} // chars
