//----------------------------------------------------
// help : print help files
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word help
pstring("help")

help:
{
    .label work_buffer = $ce00
    .label line_buffer = $ce80
    .label params_buffer = $cd00
    .label search_string = $cc80

    .label OPT_H=1
    .label OPT_I=2
    
    sec
    swi param_init,buffer,options_help
    jcs error

    //------------------------------------------------
    // help option
    //------------------------------------------------
    
    opt OPT_H, jmp show_help
    opt OPT_I, jmp show_index

    lda nb_params
    jeq show_index
    
    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    jsr do_help
    bcs error

    clc
    jmp boucle_params

fin_params:
    jsr CLRCHN
    clc
    swi success
    rts

show_help:
    swi pprint_lines,help_msg
    clc
    rts

error:
    clc
    swi error
    rts

help_msg:
    pstring("*help [topic] [-options]")
    pstring(" h : show help")
    pstring(" i : show index")
    .byte 0

options_help:
    pstring("hir")
index_file:
    pstring(".index.hlp")
index_file_write:
    pstring("@:.index.hlp,s,w")

//---------------------------------------------------------------
// currdevice : save / restore
//---------------------------------------------------------------

currdevice:
{
save:
    lda CURRDEVICE
    sta save_currdevice
    rts

restore:
    lda save_currdevice
    bne not_zero_device
    lda #8
not_zero_device:
    sta CURRDEVICE
    rts

save_currdevice:
    .byte 0
}

//---------------------------------------------------------------
// get_bin_name : check if we need to add path from BIN PATH to
// name in buffer, return result in R0 in work_buffer
//---------------------------------------------------------------

get_bin_name:
{
    push r0
    ldy #0
    mov r0,#bios.bin_path
    jsr bios.bios_ram_get_byte
    beq no_bin_path

    // copy path prefix to work_buffer
    tax
    mov r1,#work_buffer
copy_path_prefix:
    jsr bios.bios_ram_get_byte
    mov (r1),a
    iny
    dex
    bpl copy_path_prefix

no_bin_path:
    // and add filename from buffer
    ldy #0
    pop r1
    swi str_cat,work_buffer
    mov r0,#work_buffer
    rts
}

//---------------------------------------------------------------
// get_bin_device : find device to use, check presence of 
// value for BIN DEVICE if not is there a currdevice ? 
// if not try on device 8
//
// return device to use in X
//---------------------------------------------------------------

get_bin_device:
{
    ldy #0
    mov r0,#bios.bin_device
    jsr bios.bios_ram_get_byte
    cmp #0
    beq no_bin_device
    tax
    rts
    
no_bin_device:    
    ldx CURRDEVICE
    bne device_ok
    ldx #8
device_ok:
    rts
}

//---------------------------------------------------------------
// help : view help file content
//
// input : r0 = topic
//---------------------------------------------------------------

do_help:
{
    jsr currdevice.save
    jsr get_bin_name
    
    mov r1,#suffix_help
    swi str_cat
    
    push r0
    jsr get_bin_device
    stx CURRDEVICE
    pop r0
    clc
    ldx #4
    swi file_open
    bcc found
    inc $d020
    rts

found:
    jsr help_init

help_file:
    jsr CHRIN
    cmp #$0a
    bne do_color
    lda #13
    jsr CHROUT
    jmp help_continue

do_color:
    jsr change_color
    swi file_readline, work_buffer
    bcs help_end
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
    swi pprint_nl, work_buffer

help_continue:
    dec nb_lines
    bne help_file

    swi screen_pause
    bcs help_end
    jsr help_init
    bne help_file

help_init:
    ldx #4
    jsr CHKIN
    lda #23
    sta nb_lines
    rts
    
help_end:
    swi theme_normal
    ldx #4
    swi file_close
    jsr currdevice.restore

help_return:
    clc
    rts

change_color:
    ldx #5
test_color:
    cmp color_chars,x
    beq color_ok
    dex
    bpl test_color
    jmp CHROUT
color_ok:
    inx
    inx
    swi theme_set_color
    rts

suffix_help:
    pstring(".hlp")
error_help:
    pstring("Not found")

nb_lines:
    .word 0

color_chars:
    .text "_:#-*="
}

//---------------------------------------------------------------
// build_index : rebuild index file
//
// contents : lines couples help filename / first line
//---------------------------------------------------------------

build_index:
{
    // read directory
    ldy #0
    sty nb_entries
    mov r1,STREND
    mov start_entries,r1
    mov next_space,r1
    tya
    mov (r1),a

    swi directory_open
dir_loop:
    sec
    mov r1,#dir_filter
    swi directory_get_entry,work_buffer
    bcs dir_end
    cmp #0
    beq dir_loop

    jsr insert    
    jmp dir_loop

dir_end:
    swi directory_close
    
    // loop directory entries
    
    mov start_titles,next_space
    incw next_space

    mov r0,start_entries
entries_loop:
    mov a,(r0)
    cmp #0
    beq entries_end
    
    inc nb_entries

    push r0
    clc
    ldx #4
    swi file_open
    
    ldx #4
    jsr CHKIN
    ldx #4
    swi file_readline,work_buffer

    swi pprint_nl,work_buffer
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
    jsr insert

    ldx #4
    swi file_close
    pop r0
    
    mov a,(r0)
    add r0,a
    inc r0
    jmp entries_loop

entries_end:

    ldx #4
    sec
    swi file_open,dir_index
    mov r0, start_entries
    mov r1, start_titles

    ldx #4
    jsr CHKOUT

write_loop:
    ldy #0
    sty past_dot
    ldx #12
    mov a,(r0++)
    sta lgr
name_loop:
    lda past_dot
    bne is_past_dot
    mov a,(r0++)
    dec lgr
    beq name_end
    cmp #'.'
    bne name_print
    inc past_dot
is_past_dot:
    lda #32
name_print:
    cpx #0
    beq no_name_print
    jsr CHROUT
    dex
no_name_print:
    dex
    bne name_loop
name_still:
    lda lgr
    beq name_end
    inc r0
    dec lgr
    bne name_still
name_end:

    lda #13
    jsr CHROUT
ok_desc:
    dec nb_entries
    bne write_loop
    
    ldx #4
    swi file_close

exists:
    rts

past_dot:
    .byte 0
lgr:
    .byte 0

error_open:
    inc $d020
    jmp error_open
error_open2:
    inc $d021
    jmp error_open2

insert:
    mov r1,next_space
    swi str_cpy
    add r1,a
    mov next_space,r1
    tya
    mov (r1),a
    rts

dir_filter:
    pstring("*.hlp")
dir_index:
    pstring(".index.hlp,s,w")

start_entries:
    .word 0
start_titles:
    .word 0
next_space:
    .word 0
nb_entries:
    .byte 0
}

//---------------------------------------------------------------
// read_index : read index file into memory
//---------------------------------------------------------------

read_index:
{
    jsr currdevice.save
    jsr get_bin_device
    stx CURRDEVICE
    lda #0
    sta after_load
    tay
    jsr SETLFS

    lda index_file
    ldx #<index_file+1
    ldy #>index_file+1
    jsr SETNAM

    lda #0
    ldx STREND
    ldy STREND+1
    jmp LOAD
}

after_load:
    .byte 0

//---------------------------------------------------------------
// move_cursor : move cursor to x,y
//---------------------------------------------------------------

move_cursor:
{
    ldy cursor_x
    ldx cursor_y
    clc
    jsr PLOT
    clc
    rts
}
cursor_x:
    .byte 0
cursor_y:
    .byte 0

//---------------------------------------------------------------
// show index : view index content, navigate
//---------------------------------------------------------------

show_index:
{
    jsr read_index
    bcs error
    lda #1
    sta pos_index
do_show:
    ldy #0
    mov r0,STREND
    mov top_entries,r0
    mov a,(r0)
    sta nb_entries
    incw top_entries
    jsr draw_index_screen
help_loop:
    jsr navigate
    bcs quit
    jsr draw_index_screen
    jmp help_loop

quit:
    jsr CLRCHN
    lda #147
    jsr CHROUT
    clc
    rts

error:
    sec
    rts

goto_line:
    ldy #0
    asl
    tax
    mov r0,top_entries
    cpx #0
    bne loop_line
    rts
loop_line:
    mov a,(r0++)
    add r0,a
    dex
    bne loop_line
    rts
    
draw_index_screen:
    ldy #0
    sty cursor_x
    sty cursor_y
    lda #147
    jsr CHROUT
    ldx #bios.COLOR_CONTENT
    swi theme_set_color
    lda #RVSON
    jsr CHROUT
    swi pprint,title_index
    ldy #0
    sty zr0h
    ldx nb_entries
    dex
    stx zr0l
    ldx #%10011111
    swi pprint_int
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    lda #RVSOFF
    jsr CHROUT
    lda #$dd
    sta $0400+40-6
    rts

paint_screen:
    jsr goto_line
paint_line:
    inc cursor_y
    lda cursor_y
    cmp #24
    beq paint_end
    lda #0
    sta cursor_x
    jsr move_cursor
    lda after_load
    bne no_conv_name
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
no_conv_name:
    swi pprint
    mov a,(r0++)
    add r0,a
    lda #10
    sta cursor_x 
    jsr move_cursor
    lda after_load
    bne no_conv_desc
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
no_conv_desc:
    swi pprint
    mov a,(r0++)
    add r0,a
    inc current_line
    lda current_line
    cmp nb_entries
    bne paint_line
paint_end:
    rts

navigate:
    lda #0
    sta start_line
    sta current_line
cont_navigate:
    jsr paint_screen
    jsr paint_selected
key_loop:
    swi key_wait
    bcc no_quit
    rts

no_quit:
    cmp #DOWN
    beq is_down

    cmp #UP
    beq is_up
    cmp #13
    beq is_select
    cmp #32
    beq is_select
    jmp key_loop
    
is_select:
    lda #1
    sta after_load
    lda #147
    jsr CHROUT
    ldx pos_index
    dex
    txa
    jsr goto_line
    jsr do_help
    swi screen_pause
    clc
    rts
    
is_down:
    lda pos_index
    cmp #23
    beq key_loop
    jsr unpaint_selected
    inc pos_index
    jsr paint_selected
    jmp key_loop
    
is_up:
    lda pos_index
    cmp #1
    beq key_loop
    jsr unpaint_selected
    dec pos_index
    jsr paint_selected
    jmp key_loop
    
paint_selected:
    ldx #bios.COLOR_ACCENT
    swi theme_get_color
selected_bar:
    sta rvs_color
    lda pos_index
    asl
    tay
    lda screen_adr,y
    sta zr0l
    lda screen_adr+1,y
    sta zr0h
    ldy #39
reverse:
    lda (zr0l),y
    eor #$80
    sta (zr0l),y
    lda zr0h
    pha
    clc
    adc #$d4
    sta zr0h
    lda rvs_color
    sta (zr0l),y
    pla
    sta zr0h
    dey
    bpl reverse
    rts

unpaint_selected:
    ldx #bios.COLOR_TEXT
    swi theme_get_color
    sta rvs_color
    jmp selected_bar

rvs_color:
    .byte 0
top_entries:
    .word 0
pos_index:
    .byte 3
nb_entries:
    .byte 0
current_line:
    .byte 0
start_line:
    .byte 0
title_index:
    pstring("HELP INDEX                        -")
}

screen_adr:
    .for(var y = 0; y < 25; y++)
    { .word $0400+40*y }
    


} // help namespace