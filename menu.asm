//----------------------------------------------------
// menu : select between items
//
// options : 
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word menu
pstring("MENU")


menu:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd80
    .label menu_data = $cc00
    .label save_screen = $7D00

    .label OPT_L=1
    
    sec
    swi param_init,buffer,options_menu
    jcs error
    
    ldx nb_params
    jeq help
    
    ldy #0
    sty selected_item
    sty string_len
    sty string_storage
    mov menu_data_ptr,#menu_data
    jsr get_max_length
    jsr navigation
    
    lda selected_item
    cmp #$ff
    beq quit_menu
        
    jsr get_item
    mov r1, #string_storage
    swi str_cpy
    sta string_len
    tay
    lda #0
    sta (zr1l),y
    tay
    swi set_basic_string,return_string

quit_menu:
    lda #0
    sta saved
    sta zr0h
    ldx selected_item
    inx
    stx zr0l
    swi return_int

    clc
    rts

error:
    sec
    rts

options_menu:
    pstring("L")
selected_item:
    .byte 0
max_length:
    .byte 0
menu_data_ptr:
    .word 0
nb_items:
    .byte 0
saved:
    .byte 0
    
return_string:
    .text "SH$"
string_len:
    .byte 0
    .word string_storage
string_storage:
    .fill 64,0


// get_item : get item at selected_item position in R0
get_item:
{
    ldy #0
    sty pos
    mov menu_data_ptr,#menu_data
    mov r0,menu_data_ptr
boucle:
    lda pos
    cmp selected_item
    beq fin
    
    mov a,(r0)
    add r0,a
    inc r0
    inc pos
    bne boucle

fin:
    rts
pos:
    .byte 0
}

navigation:
{
    lda #1
    sta BLNSW
    swi cursor_unblink

boucle:
    jsr paint_menu
    swi key_wait
    cmp #RUNSTOP
    beq stop
    cmp #'Q'
    beq stop
    cmp #'X'
    bne not_stop
    
stop:
    lda #$ff
    sta selected_item
    jmp fin
    
not_stop:
    cmp #13
    beq fin
    cmp #DOWN
    bne pas_down
    
    inc selected_item
    lda selected_item
    cmp nb_items
    bne boucle
    lda #0
    sta selected_item
pas_down:
    cmp #UP
    bne boucle
    lda selected_item
    bne not_zero_up
    lda nb_items
    sta selected_item
not_zero_up:
    dec selected_item
    jmp boucle

fin:
    jsr restore_screen
    lda #0
    sta BLNSW
    swi cursor_unblink
    jsr CLRCHN
    clc
    rts
}


get_max_length:
{
    ldy #0
    sty max_length
    sty nb_items
    sty selected_item
    sec
boucle:
    swi param_process,params_buffer
    bcs fin_params
    swi str_len
    cmp max_length
    bcc not_bigger
    sta max_length

not_bigger:
    mov r1, menu_data_ptr
    swi str_cpy
    add r1,a
    mov menu_data_ptr,r1
    inc nb_items
    clc
    jmp boucle

fin_params:
    lda max_length
    rts
}

calc_start_position:
{
    lda options_params
    and #OPT_L
    beq pos_right
    
    // pos_left
    mov r0,#$0400
    rts
    
pos_right:
    sec
    mov r0,#$0400+38
    sec
    lda zr0l
    sbc max_length
    sta zr0l
    lda zr0h
    sbc #0
    sta zr0h
    rts
}

paint_menu:
{
    lda saved
    bne is_saved
    mov r1,#save_screen

is_saved:
    jsr calc_start_position
    mov screen_adr,r0
    clc
    lda zr0h
    adc #$d4
    sta zr0h
    mov color_adr,r0    
    
    ldy #0
    mov menu_data_ptr,#menu_data
    mov r0,menu_data_ptr
    sty cur_item
boucle:
    ldx #0
    lda #118
    jsr write_char
    mov a,(r0++)
    sta entry_len
    sta entry_length
boucle_entry:
    mov a,(r0++)
    ora #128
    jsr write_char
    dec entry_len
    bne boucle_entry
    
pad:
    lda entry_length
    cmp max_length
    beq ok_len
    lda #32+128
    jsr write_char
    inc entry_length
    jmp pad
    
ok_len:
    lda #116
    jsr write_char
    clc
    lda #40
    adc screen_adr
    sta screen_adr
    lda screen_adr+1
    adc #0
    sta screen_adr+1
    clc
    lda #40
    adc color_adr
    sta color_adr
    lda color_adr+1
    adc #0
    sta color_adr+1
    inc cur_item
    lda cur_item
    cmp nb_items
    bne boucle
fin_params:
    lda #1
    sta saved
    rts

write_char:
    pha
    lda saved
    bne already_saved
    jsr save_screen_data
already_saved:
    pla
    sta screen_adr:$0400,x
    lda cur_item
    cmp selected_item
    bne not_selected
selected:
    lda #7
    bne do_color
not_selected:
    lda #3
do_color:
    sta color_adr:$d800,x
    inx
    rts

save_screen_data:
    lda screen_adr
    sta read_screen
    sta read_color
    lda screen_adr+1
    sta read_screen+1
    clc
    adc #$d4
    sta read_color+1
    lda read_screen:$0400,x
    mov (r1++),a
    lda read_color:$d800,x
    mov (r1++),a
    rts

entry_len:
    .byte 0
entry_length:
    .byte 0
cur_item:
    .byte 0
}

restore_screen:
{
    mov r1,#save_screen
    jsr calc_start_position
    mov screen_adr,r0
    clc
    lda zr0h
    adc #$d4
    sta zr0h
    mov color_adr,r0
    ldy #0
    mov menu_data_ptr,#menu_data
    mov r0,menu_data_ptr
    sty cur_item
boucle:
    ldx #0
    mov a,(r1++)
    jsr write_char
    mov a,(r0++)
    sta entry_len
    sta entry_length
boucle_entry:
    mov a,(r0++)
    mov a,(r1++)
    jsr write_char
    dec entry_len
    bne boucle_entry
    
pad:
    lda entry_length
    cmp max_length
    beq ok_len
    mov a,(r1++)
    jsr write_char
    inc entry_length
    jmp pad
    
ok_len:
    mov a,(r1++)
    jsr write_char
    clc
    lda #40
    adc screen_adr
    sta screen_adr
    lda screen_adr+1
    adc #0
    sta screen_adr+1
    clc
    lda #40
    adc color_adr
    sta color_adr
    lda color_adr+1
    adc #0
    sta color_adr+1
    inc cur_item
    lda cur_item
    cmp nb_items
    jne boucle
fin_params:
    rts

entry_len:
    .byte 0
entry_length:
    .byte 0
cur_item:
    .byte 0
    
write_char:
    sta screen_adr:$0400,x
    mov a,(r1++)
    sta color_adr:$d800,x
    inx
    rts

}

//----------------------------------------------------
// help : display help messages
//----------------------------------------------------

help:
{
    swi pprint_lines,help_msg
    sec
    rts
    
help_msg:
    pstring("*MENU [ITEM OR FILE PATTERN] [-L]")
    pstring(" L = PLACE MENU ON LEFT")
    .byte 0
}


} // menu