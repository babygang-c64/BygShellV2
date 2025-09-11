//----------------------------------------------------
// edit : edit files
//
// options : 
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word edit
pstring("EDIT")


edit:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd80
    .label lines_ptr = $7800

    .label OPT_N=1
    
    sec
    swi param_init,buffer,options_edit
    jcs error
    
    // editor init
    ldy #0
    jsr init

    ldx nb_params
    bne load_file

    // no input file = new blank file
    
    mov r1,#filename
    mov r0,#default_filename
    swi str_cpy

    jsr status_line

empty_file:
    mov r0,#new_file
    jsr string_add
    mov r1,tmp_line
    mov (r1), r0
    incw tmp_line
    incw tmp_line
    incw total_lines

    jmp blank_file
    

load_file:
    // load file
    
    ldy #0
    mov r1,#filename
    mov r0,#file_prefix
    swi str_cpy
    
    sec
    swi param_process,params_buffer
    push r0
    
    mov r1, r0
    mov r0,#filename
    swi str_cat
    mov r1,#file_suffix
    swi str_cat

    jsr status_line

    pop r0
    ldx #4
    clc
    swi file_open
    jcs empty_file

    ldx #4
    jsr CHKIN

get_lines:
    swi file_readline, work_buffer
    jcs ok_close

    jsr string_add

    // store line ptr
    mov r1,tmp_line
    mov (r1), r0
    incw tmp_line
    incw tmp_line
    
    incw total_lines
    inc progress
    lda progress
    cmp #8
    bne get_lines
    lda #0
    sta progress
    jsr status_line
    jmp get_lines
    
ok_close:
    ldx #4
    swi file_close

    mov r0,#tmp_line
    lda #0
    mov (r0++),a
    mov (r0),a

blank_file:
    jsr fill_screen
    jsr status_line
    jsr navigation.nav_cursor
    
    lda #0
    sta BLNSW
    
main_loop:
    mov r0,current_line
    lda cursor_y
    add r0,a
    mov cursor_line,r0
    jsr navigation
    bcc main_loop

    cmp #RUNSTOP
    beq no_save
    jsr save_file

no_save:
    jsr unblink_cursor
    lda #147
    jsr CHROUT
    jsr CLRCHN
    clc
    rts

max:
    .byte 0
affiche:
    .byte 0
options_edit:
    pstring("H")

filename:
    pstring("@S:----FILENAME----,S,W")
file_prefix:
    pstring("@S:")
file_suffix:
    pstring(",W")
default_filename:
    pstring("@S:TMP,W")
new_file:
    pstring("")


init:
    sty view_offset
    sty master_key
    sty is_editing
    sty is_edited
    sty affiche
    sty progress
    sty cursor_x
    sty cursor_y
    sty block_set
    sty current_line
    sty current_line+1
    sty total_lines
    sty total_lines+1
    sty lines_ptr
    sty lines_ptr+1
    ldx #nb_bam
    mov r0,#bam_root
    swi bam_init
    mov tmp_line,#lines_ptr
    lda #147
    jsr CHROUT
    jmp move_cursor

error:
    sec
    rts
    
master_key:
    .byte 0
cursor_x:
    .byte 0
cursor_y:
    .byte 0
mark_x:
    .byte 0
mark_view_offset:
    .byte 0
mark_line:
    .byte 0
block_set:
    .byte 0
block_start_x:
    .byte 0
block_start_line:
    .byte 0
block_end_x:
    .byte 0
block_end_line:
    .byte 0
current_line:
    .word 0
total_lines:
    .word 0
cursor_line:
    .word 0
cursor_line_ptr:
    .word 0
cmp_line:
    .word 0
tmp_line:
    .word 0
progress:
    .byte 0
view_offset:
    .byte 0
is_editing:
    .byte 0
is_edited:
    .byte 0
edited_line:
    .word 0
lines_length:
    .fill 24,0

//----------------------------------------------------
// save_file : save the file to disk
//----------------------------------------------------

save_file:
{
    lda is_edited
    jeq not_changed

    lda #211
    sta $0400+39+40*24
    lda #7
    sta $d800+39+40*24

//    jsr check_edit_end

    mov r0,#filename
    ldx #5
    sec
    swi file_open
    bcs error
    ldx #5
    jsr CHKOUT

    lda #0
    sta current_line
    sta current_line+1

write_line:
    mov r0,current_line
    jsr goto_line
    swi pprint_nl
    lda color_pos
    and #3
    tax
    lda color_cycle,x
    sta $d800+39+40*24
    inc color_pos

    incw current_line
    lda current_line
    cmp total_lines
    bne write_line
    lda current_line+1
    cmp total_lines+1
    bne write_line
    
    ldx #5
    swi file_close
    lda #0
    sta is_edited
    sta current_line
    sta current_line+1
    lda #'-'+$80
    sta $0400+39+40*24
    lda #15
    sta $d800+39+40*24


not_changed:
    clc
    rts

color_pos:
    .byte 0
color_cycle:
    .byte 7,2,1
}

//====================================================
// Editor code
//====================================================

//----------------------------------------------------
// navigation : process the navigation keys
//----------------------------------------------------

navigation:
{
    swi key_wait
    sta current_key
    lda master_key
    bne process_masterkey

    jmp key_jump
    
    //--------------------------------
    // Master key CTRL+K
    //--------------------------------

press_master_key:    
    lda #1
    sta master_key
    lda #77+128
update_master_key_indicator:
    sta $0400+38+40*24
    clc
    rts

    //--------------------------------
    // Master Key : 2nd key press
    //--------------------------------

process_masterkey:
    jmp key_jump_masterkey

cancel_master:
    lda #0
    sta master_key
    lda #32+128
    jmp update_master_key_indicator

    //--------------------------------
    // MASTER-T : go to top
    //--------------------------------

master_t:    
    lda #0
    sta current_line
    sta current_line+1
    sta view_offset
    sta cursor_x
    sta cursor_y
    jsr update_screen
    jmp cancel_master

    //--------------------------------
    // MASTER-+ : set mark
    //--------------------------------

master_set_mark:
    mov r0,current_line
    lda cursor_y
    add r0,a
    mov mark_line,r0
    lda cursor_x
    sta mark_x
    lda view_offset
    sta mark_view_offset
    jmp cancel_master
    
    //--------------------------------
    // MASTER-- : goto mark
    //--------------------------------

master_goto_mark:
    mov current_line,mark_line
    lda #0
    sta cursor_y
    lda mark_x
    sta cursor_x
    lda mark_view_offset
    sta view_offset
    jsr cancel_master
    jmp update_and_go
    
    //--------------------------------
    // CTRL-X : Quit editor
    //--------------------------------

quit:
save_and_quit:
    sec
    rts

    //--------------------------------
    // CTRL-S : save
    //--------------------------------

save_file:
    jsr save_file
    jmp nav_cursor

    //--------------------------------
    // Cursor Left
    //--------------------------------

cursor_left:
    lda cursor_x
    cmp #0
    bne ok_dec

    lda view_offset
    beq left_at_start
    dec view_offset
    jmp update_screen
    
    // 1st position ? ok if not 1st line
left_at_start:
    lda cursor_y
    bne start_ok
    lda current_line
    ora current_line+1
    bne start_ok
    
not_ok_left:
    clc
    rts

start_ok:
    // move at end of previous line
    mov r0,current_line
    lda cursor_y
    add r0,a
    dec r0
    
    jsr goto_line
    mov a,(r0)
    sta cursor_x
    
    jmp cursor_up

ok_dec:
    dec cursor_x
    jmp nav_cursor
    
    //--------------------------------
    // Cursor Right
    //--------------------------------

cursor_right:    
    lda cursor_x
    ldy cursor_y
    cmp lines_length,y
    bne ok_cursor_right
    ldy #0
    sty cursor_x
    jmp cursor_down

ok_cursor_right:
    ldy #0
    lda cursor_x
    cmp #39
    bne ok_inc
    
    lda view_offset
    cmp #80
    beq not_ok_left
    inc view_offset
    jmp update_screen

ok_inc:
    inc cursor_x
    jmp nav_cursor

    //--------------------------------
    // Cursor UP ?
    //--------------------------------

cursor_up:
    lda cursor_y
    cmp #0
    beq scroll_up
    dec cursor_y
    jsr adjust_cursor_x
    jsr check_edit_end
    jmp nav_cursor
    
scroll_up:
    lda current_line
    cmp #0
    bne do_scroll_up
    lda current_line+1
    cmp #0
    bne do_scroll_up
    clc
    rts

do_scroll_up:
    decw current_line
    jsr check_edit_end
update_and_go:
    jsr update_screen
    jsr adjust_cursor_x
    jmp nav_cursor

    //--------------------------------
    // Cursor DOWN ?
    //--------------------------------

cursor_down:
    lda cursor_y
    cmp #23
    beq scroll_down
    
    lda total_lines+1
    bne not_small

    ldx total_lines
    dex
    cpx cursor_y
    beq end2

not_small:
    inc cursor_y
    jsr adjust_cursor_x
    jsr check_edit_end
    jmp nav_cursor

scroll_down:
    lda cmp_line
    cmp total_lines
    bne do_scroll_down
    lda cmp_line+1
    cmp total_lines+1
    bne do_scroll_down
end2:
    clc
    rts
    
do_scroll_down:
    incw current_line
    jsr check_edit_end
    jmp update_and_go

    //--------------------------------
    // CTRL+A = start of line
    //--------------------------------

start_of_line:
    ldy #0
update_x_and_nav:
    sty cursor_x
    jmp nav_cursor

    //--------------------------------
    // CTRL+E = end of line
    //--------------------------------

end_of_line:
    ldy #40
find_end:
    dey
    beq found_end
    lda (PNT),y
    cmp #32
    bne found_the_end
    beq find_end
found_the_end:
    cpy #39
    beq found_end
    iny
found_end:
    jmp update_x_and_nav
    
    //--------------------------------
    // CTRL+W : next word
    //--------------------------------

next_word:
    ldy cursor_x
search_word:
    lda (PNT),y
    cmp #32
    beq found_word
    iny
    cpy #39
    bne search_word
    clc
    rts

found_word:
    iny
    lda (PNT),y
    cmp #32
    beq end
    jmp update_x_and_nav

    //--------------------------------
    // other key ? start edit
    //--------------------------------

default_keypress:
    lda is_editing
    bne already_editing
    
    jsr init_line_edit

already_editing:
    jsr edit_line_process

    //--------------------------------
    // end, return
    //--------------------------------
        
end:
    clc
    rts

    //--------------------------------
    // nav_cursor : change cursor
    // position
    //--------------------------------

nav_cursor:
    sei
    jsr unblink_cursor
    jsr status_cursor
    jsr move_cursor
    lda #0
    sta BLNSW
    cli
    rts

current_key:
    .byte 0

    // Navigation keys / endpoint combinations

nav_keys:
    // Master key for combinations
    .byte CTRLK
    .word press_master_key
    // Quit and save if needed
    .byte CTRLX
    .word save_and_quit
    // Quit without saving
    .byte RUNSTOP
    .word quit
    // Save file
    .byte CTRLS
    .word save_file
    // Cursor left
    .byte LEFT
    .word cursor_left
    // Cursor right
    .byte RIGHT
    .word cursor_right
    // Cursor up
    .byte UP
    .word cursor_up
    // Cursor down
    .byte DOWN
    .word cursor_down
    // Next word
    .byte CTRLW
    .word next_word
    // Start of line
    .byte CTRLA
    .word start_of_line
    // End of line
    .byte CTRLE
    .word end_of_line
    // Not found = default keypress
    .byte 0
    .word default_keypress

    // When masterkey has been pressed before
nav_keys_master:
    .byte 'T'
    .word master_t
    .byte '+'
    .word master_set_mark
    .byte '-'
    .word master_goto_mark
    .byte 0
    .word cancel_master

    // A = key pressed, lookup in nav_keys and jump
key_jump:
    ldx #0
test_key:
    lda nav_keys,x
    beq key_found
    cmp current_key
    beq key_found
    inx
    inx
    inx
    bne test_key

key_found:
    lda nav_keys+1,x
    sta key_jump_addr
    lda nav_keys+2,x
    sta key_jump_addr+1
    jmp key_jump_addr:default_keypress
    
key_jump_masterkey:
    ldx #nav_keys_master-nav_keys
    bne test_key
}

//----------------------------------------------------
// check_edit_end : wrap-up after editing line
//
// find space for edited line, copy the line and
// update the pointer
//----------------------------------------------------

check_edit_end:
{
    lda is_editing
    sta $1004
    beq not_edited

force:
    ldx work_buffer
    inx
    jsr malloc
    mov new_line,r0
    mov $1000,r0
    mov r1,r0

    // copy editing line to new space    
    mov r0,#work_buffer
    swi str_cpy
    
    // update pointer in list
    mov r0, cursor_line_ptr
    mov $1002,r0
    lda new_line
    sta (zr0l),y
    iny
    lda new_line+1
    sta (zr0l),y
    dey
    
    // add trailing zero
    mov r0,new_line
    mov a,(r0)
    tay
    iny
    lda #0
    mov (r0),a
    tay
    sta is_editing

not_edited:
    rts

new_line:
    .word 0
}

//----------------------------------------------------
// init_line_edit
//----------------------------------------------------

init_line_edit:
{
    lda #1
    sta is_editing
    sta is_edited
    jsr status_changed

    // copy line to work buffer except when return key
    lda navigation.current_key
    cmp #RETURN
    beq is_return

    jsr goto_line_at_cursor
    
    // ici r0 = edited_line
    
    mov edited_line,r0
    
    mov r1,cursor_line_ptr
    
    // manque : mov (r1),#addr
    ldy #0
    lda #<work_buffer
    sta (zr1l),y
    iny
    lda #>work_buffer
    sta (zr1l),y
    dey

    // copy OK
    mov edited_line, r0
    mov r1,#work_buffer
    swi str_cpy
    ldy work_buffer
    lda #0
    sta work_buffer+1,y
    tay
    rts
    
is_return:
    mov r0, cursor_line
    asl zr0l
    rol zr0h
    clc
    lda zr0l
    adc #<lines_ptr
    sta cursor_line_ptr
    lda zr0h
    adc #>lines_ptr
    sta cursor_line_ptr+1
    
    // when return key is the first edit key,
    // is_editing = 2

    inc is_editing
    rts
}

//----------------------------------------------------
// adjust_cursor_x : when changing line, check if we
// need to adjust cursor_x according to line length
//----------------------------------------------------

adjust_cursor_x:
{
    ldx cursor_y
    lda lines_length,x
    sec
    sbc view_offset
    cmp cursor_x
    bcc adjust
    rts
adjust:
    sta cursor_x
    rts
}

//----------------------------------------------------
// edit_line_process : process the keys to edit when
// within a line
//----------------------------------------------------

edit_line_process:
{
    lda navigation.current_key
    cmp #BACKSPACE
    jne not_backspace
    
    //------------------------------------
    // Backspace
    //------------------------------------

    // Backspace : if at end and not zero, decrease length
    lda work_buffer
    beq backspace_suppress_line
    
    // check if at end
    jsr get_true_x
    cpx work_buffer
    beq backspace_at_end
    
    // not at end : suppress within string or join lines
    lda view_offset
    bne not_backspace_start
    lda cursor_x
    bne not_backspace_start
    
    // at start : join with previous line except if first line : wip
    
    lda cursor_line
    bne not_first
    lda cursor_line+1
    jeq end

not_first:
    // if previous line is empty, just suppress it, if not join lines
    
    ldx cursor_y
    dex
    lda lines_length,x
    beq go_suppress

    jsr join_lines

go_suppress:
    jsr check_edit_end
    ldx cursor_y
    dex
    lda lines_length,x
    sta cursor_x
    ldy #0
    sty view_offset
    mov r0,cursor_line
    dec r0
    jsr suppress_line
    jsr update_screen
    jmp navigation.cursor_up
    
    // not at start : remove from string
not_backspace_start:
    mov r0,#work_buffer
    ldy #1
    ldx cursor_x
    dex
    swi str_del
    inc work_buffer

backspace_at_end:
    dec work_buffer
    ldx cursor_y
    dec lines_length,x
    jsr update_current_line
    jmp navigation.cursor_left
    
backspace_suppress_line:
    lda cursor_line
    bne backspace_not_zero
    lda cursor_line+1
    bne backspace_not_zero
    jmp end

    // suppression d'une ligne vide
backspace_not_zero:
    mov r0,cursor_line
    jsr suppress_line
    lda #0
    sta is_editing
    jmp navigation.update_and_go
    
not_backspace:
    cmp #RETURN
    beq return

    //------------------------------------
    // insert standard character
    //------------------------------------

    // if at end, increase length and insert
    lda work_buffer
    sec
    sbc view_offset
    cmp cursor_x
    bne insert_car_not_end

    inc work_buffer
    ldx work_buffer
    lda navigation.current_key
    jsr screen_to_ascii
    sta work_buffer,x
insert_end:
    ldx cursor_y
    inc lines_length,x
    jsr update_current_line
    jmp navigation.cursor_right

insert_car_not_end:
    lda navigation.current_key
    jsr screen_to_ascii
    sta insert_char+1
    mov r0, #work_buffer
    mov r1, #insert_char
    ldx cursor_x
    inx
    swi str_ins
    jmp insert_end

end_with_update:
    jsr update_current_line
end:
    clc
    rts

    jsr get_true_x
    inx
    lda navigation.current_key
    sta work_buffer,x
    jsr update_current_line
    jmp navigation.cursor_right

    //------------------------------------
    // Return key pressed : 
    // check if was editing, split line,
    // add new line which is work_buffer
    //------------------------------------
return:
    lda is_editing
    cmp #2
    beq return_key_alone
    jsr check_edit_end
    lda #1
    sta is_editing

return_key_alone:
    mov r0,cursor_line
    jsr insert_line
    mov r0,cursor_line
    inc r0
    jsr goto_line
    mov r0,cursor_line_ptr
    lda #<work_buffer
    mov (r0++),a
    lda #>work_buffer
    mov (r0),a
    jsr get_true_x
    jsr split_line
    ldy #0
    sty cursor_x
    sty view_offset
    incw cursor_line_ptr
    incw cursor_line_ptr
    jsr check_edit_end
    jsr update_screen
    jmp navigation.cursor_down

insert_char:
    pstring(" ")

}

//----------------------------------------------------
// split line : split current line on X, remainder in
// work_buffer
//----------------------------------------------------

split_line:
{
    jsr goto_line_at_cursor
    push r0
    txa
    add r0, a
    mov r1, #work_buffer
    ldy #1
copy:
    mov a,(r0)
    cmp #0
    beq end_copy
    mov (r1),a
    iny
    bne copy
end_copy:
    dey
    tya
    ldy #0
    mov (r1),a
    tay
    iny
    lda #0
    mov (r1),a
    
    // mark end and length of left side of split
    pop r0
    txa
    tay
    iny
    lda #0
    mov (r0),a
    ldy #0
    txa
    mov (r0),a
    rts
}

//----------------------------------------------------
// get_true_x
//----------------------------------------------------

get_true_x:
{
    lda cursor_x
    clc
    adc view_offset
    tax
    rts
}

//----------------------------------------------------
// join_lines : insert previous line in work_buffer
//----------------------------------------------------

join_lines:
{
    mov r0,cursor_line_ptr
    dec r0
    dec r0
    mov a,(r0++)
    sta zr1l
    mov a,(r0)
    sta zr1h
    mov r0,#work_buffer
    
    ldx #1
    swi str_ins
    ldy work_buffer
    lda #0
    sta work_buffer+1,y
    tay
    rts
}

//----------------------------------------------------
// goto_line_at_cursor : get line at cursor in r0
//----------------------------------------------------

goto_line_at_cursor:
{
    mov r0,cursor_line
    jmp goto_line
}

//----------------------------------------------------
// update_current_line : repaint just the current line
//----------------------------------------------------

update_current_line:
{
    sei
    jsr unblink_cursor

    lda cursor_y
    mov r1,a
    swi mult10

    mov r0, #$0400

    // manque add rN,rM
    ldx #4
add4:
    clc
    lda zr0l
    adc zr1l
    sta zr0l
    lda zr0h
    adc zr1h
    sta zr0h
    dex
    bne add4
    mov r1, r0
    
    jsr goto_line_at_cursor
    
    mov a,(r0++)
    
    ldx cursor_y
    sta lines_length,x
    
    tax
    stx cpt_x
    cmp #0
    beq pad_line

    ldy #0
    sty cpt_x
paint:
    mov a,(r0++)
    jsr ascii_to_screen
    mov (r1++),a
    inc cpt_x
    lda cpt_x
    cmp #40
    beq fin
    dex
    bne paint

pad_line:
    lda #32
paint_pad:
    ldx cpt_x
    cpx #40
    beq fin
    bcs fin
    mov (r1++),a
    inc cpt_x
    bne paint_pad
fin:
    jmp update_screen.end

cpt_x:
    .byte 0
}

//----------------------------------------------------
// update_screen : repaint the screen
//----------------------------------------------------

update_screen:
{
    sei
    jsr unblink_cursor
    jsr fill_screen
end:
    jsr move_cursor
    lda #0
    sta BLNSW
    cli
    clc
    rts
}

//----------------------------------------------------
// unblink cursor
//----------------------------------------------------

unblink_cursor:
{
    lda #1
    sta BLNSW
    lda BLNON
    beq blink_off
    
    ldy #0
    sty BLNON
    lda GDBLN
    ldx GDCOL
    jmp DSPP
blink_off:
    rts
}
//----------------------------------------------------
// fill_screen : print all lines starting at 
// current_line on screen
//----------------------------------------------------

fill_screen:
{
    lda #0
    sta pos_x
    sta pos_y
    sta max_offset
    sta screen_write
    sta screen_write2
    lda #4
    sta screen_write+1
    sta screen_write2+1
    
    mov r0,current_line
    mov r1,r0
    jsr goto_line
    
    ldy #0
next_line:
    mov a,(r0++)
    
    ldy pos_y
    sta lines_length,y
    ldy #0

    cmp max_offset
    bcc smaller
    sta max_offset
smaller:
    
    sec
    sbc view_offset
    tax
    
    cmp #0
    beq do_pad_line
    bmi do_pad_line
    jmp write_line

write_line:
    ldy view_offset
    mov a,(r0++)

    jsr ascii_to_screen

    sta screen_write:$0400
    incw screen_write
    incw screen_write2
    inc pos_x
    lda pos_x
    cmp #40
    beq end_line
    dex
    bne write_line

do_pad_line:
    jsr pad_line

end_line:
    ldy #0
    sty pos_x
    inc pos_y
    lda pos_y
    cmp #24
    beq end_screen
    
    inc r1
    lda zr1l
    cmp total_lines
    bne not_total
    lda zr1h
    cmp total_lines+1
    bne not_total
end_screen:
// here fill to bottom of screen
    lda pos_y
    cmp #24
    beq fin
    inc pos_y
    lda #0
    sta pos_x
    jsr pad_line
    jmp end_screen
fin:
    rts
    
pad_line:
    lda #32
    sta screen_write2:$0400
    incw screen_write
    incw screen_write2
    
    inc pos_x
    lda pos_x
    cmp #40
    bne pad_line
    rts

not_total:
    mov r0,r1
    jsr goto_line

    jmp next_line

pos_x:
    .byte 0
pos_y:
    .byte 0
max_offset:
    .byte 0
}

//----------------------------------------------------
// ascii_to_screen : convert character in A for screen
//----------------------------------------------------

ascii_to_screen:
{
    cmp #97
    bcc not_lowercase
    cmp #123
    bcs not_lowercase
    sec
    sbc #$60
not_lowercase:
    rts
}

//----------------------------------------------------
// screen_to_ascii : convert character in A to ASCII
//----------------------------------------------------

screen_to_ascii:
{
    cmp #65
    bcc not_lowercase
    cmp #65+26
    bcs not_lowercase
    clc
    adc #$20
    rts

not_lowercase:
    cmp #65+128
    bcc not_uppercase
    cmp #65+26+128
    bcs not_uppercase
    sec
    sbc #$80
not_uppercase:
    rts
}

//----------------------------------------------------
// goto_line : get pointer of specific line
//
// input : line number in R0
// output : line buffer in R0, ptr to line in 
// cursor_line_ptr
//----------------------------------------------------

goto_line:
{
    asl zr0l
    rol zr0h
    clc
    lda zr0l
    adc #<lines_ptr
    sta zr0l
    sta cursor_line_ptr

    lda zr0h
    adc #>lines_ptr
    sta zr0h
    sta cursor_line_ptr+1
    ldy #0
    lda (zr0l),y
    pha
    iny
    lda (zr0l),y
    dey
    sta zr0h
    pla
    sta zr0l    
    rts
}

//----------------------------------------------------
// status_cursor : print the cursor position and line
// number in the status line
//----------------------------------------------------

status_cursor:
{
    ldx #24
    ldy #21
    clc
    jsr PLOT
    lda #LIGHT_GRAY
    jsr CHROUT
    lda #RVSON
    jsr CHROUT
    ldy #0
    sty zr0h
    jsr get_true_x
    stx zr0l
    ldx #%00000011
    swi pprint_int
    lda #','
    jsr CHROUT
    lda cursor_y
    sta zr0l
    swi pprint_int
    lda #')'
    jsr CHROUT
    lda #32
    jsr CHROUT
    
    ldx cursor_y
    mov r0,current_line
    inx
    txa
    add r0,a
    mov cmp_line,r0
    ldx #%11001111
    swi pprint_int
    lda #'/'
    jsr CHROUT
    mov r0,total_lines
    swi pprint_int

    lda #RVSOFF
    jsr CHROUT
    lda #WHITE
    jsr CHROUT
    rts
}

print_name:
{
    // name part : 17c padded with spaces
    ldy #0
    lda filename
    sec
    sbc #4
    tax
    mov r0,#filename
    inc r0
    inc r0
    inc r0
print:
    mov a,(r0++)
    jsr CHROUT 
    dex
    bne print
    lda filename
    cmp #21
    beq ok_name
    tay
complete_name:
    lda #' '
    jsr CHROUT
    iny
    cpy #22
    bne complete_name
ok_name:
    ldy #0
    rts
}

//----------------------------------------------------
// status_line : print the bottom status line
// 08:      = device
// filename = name padded to 16c
// space    = filler
// (99,99)  = cursor X/Y
// space    = filler
// 9999/9999= current line / total lines
// space    = filler
//----------------------------------------------------

status_rvson:
{
    lda #LIGHT_GRAY
    jsr CHROUT
    lda #RVSON
    jmp CHROUT
}

status_rvsoff:
{
    lda #WHITE
    jsr CHROUT
    lda #RVSOFF
    jmp CHROUT
}

status_line:
{
    ldx #24
    ldy #0
    clc
    jsr PLOT
    jsr status_rvson
    
    ldy CURRDEVICE
    swi pprinthex8a
    jsr print_name

    lda #'('
    jsr CHROUT
    jsr status_cursor
    jsr status_rvson
    lda #32
    jsr CHROUT
    jsr CHROUT

    jsr status_rvsoff
    
    jmp status_changed
}

status_changed:
{
    lda is_edited
    beq not_editing
    lda #'*'
    bne update
not_editing:
    lda #'-'
update:
    ora #$80
    sta $0400+39+40*24
    lda #15
    sta $d800+39+40*24
    clc
    rts
}

move_cursor:
{
    ldy cursor_x
    ldx cursor_y
    clc
    jsr PLOT
    clc
    rts
}

//====================================================
// memory management
//
// blocks allocation, memory starts at $0800 to $77ff
//  BAM bitmap for 128 x 256 bytes blocks
//
//
// 1 block =
//  - byte max free space
//  - lines :
//      pstring
//      zero ending string
//
// lines : list of block pointers at $7800
//
// BAM structure : cf BIOS
//====================================================

.label memory_start=$0800
.label nb_bam=14

bam_root:
        bam_length:
            .byte nb_bam
        bam_free:
            .byte nb_bam*8
        bam_allocated:
            .byte 0
        bam:
            .fill nb_bam,0

//----------------------------------------------------
// malloc : return R0 to space with free X bytes
//
// output : C=1 KO, C=0 OK
//----------------------------------------------------

malloc:
{
   stx how_much
   // lookup all allocated blocks first to see if one
   // has enough space left
   
   ldy #0

scan_bam:
    lda bam,y
    beq new_block
    
    sec
test_bam:
    mov r0,#bam_root
    mov r1,#memory_start
    swi bam_next
    bcs new_block
    
    ldy #0
    mov a,(r0)
    cmp how_much
    bcc test_bam

    // existing block with enough size
    // calculate position and new free
    // size

ok_size:
    // target position
    sta bam_available
    lda #0
    sec
    sbc bam_available
    pha
    
    // size
    sec
    lda bam_available
    sbc how_much
    mov (r0),a
    
    pla
    clc
    add r0,a

    clc
    rts
    
    // no space free in allocated blocs, allocate a new block,
    // the new block free space is 255-X

new_block:
    mov r0,#bam_root
    mov r1,#memory_start
    swi bam_get

    lda #255
    sec
    sbc how_much
    mov (r0),a
    inc r0
    
    clc
    rts

how_much:
    .byte 0
bam_available:
    .byte 0
}

//----------------------------------------------------
// string_add : add one pstring to memory
//
// input : r0 = pstring
// output : pstring is stored, with a trailing zero
//----------------------------------------------------

string_add:
{
    // alloc space for string length + 2 (lenght byte
    // and trailing zero)

    mov a, (r0)
    tax
    inx
    inx
    push r0
    jsr malloc

    mov r1, r0
    pop r0
    swi str_cpy

    // add a zero at target (r1) + strlen + 1
    mov a, (r1)
    tay
    iny
    lda #0
    sta (zr1l),y
    tay
    mov r0, r1
    rts
}

//----------------------------------------------------
// suppress_line : suppress line from list
//
// input : r0 = line # to suppress
//----------------------------------------------------

insdel_calc_nb:
{
    // tmp_line = how many lines to copy
    sec
    lda total_lines
    sbc zr0l
    sta tmp_line
    lda total_lines+1
    sbc zr0h
    sta tmp_line+1
    decw tmp_line
    rts
}

suppress_line:
{
    jsr insdel_calc_nb
    push r0    

    // r0 = read, r1 = write = pos to suppress
    jsr insdel_precalc
    inc r0
    inc r0

    sec
    jsr insdel_copy

    decw total_lines
    pop r0
    rts
}

insdel_precalc:
{
    asl zr0l
    rol zr0h
    clc
    lda #<lines_ptr
    adc zr0l
    sta zr0l
    lda #>lines_ptr
    adc zr0h
    sta zr0h
    mov r1,r0
    rts    
}
insdel_copy:
{
    stc sens
    ldy #0
copie:
    lda (zr0l),y
    sta (zr1l),y
    iny
    lda (zr0l),y
    sta (zr1l),y
    dey
    
    lda sens
    bne supp_line

    dec r0
    dec r0
    dec r1
    dec r1    
    jmp suite_copie

supp_line:
    inc r0
    inc r0
    inc r1
    inc r1

suite_copie:
    decw tmp_line
    lda tmp_line
    bne copie
    lda tmp_line+1
    bne copie
    rts

sens:
    .byte 0
}

//----------------------------------------------------
// insert_line : insert line in list
//
// input : r0 = line # to insert to
//----------------------------------------------------

insert_line:
{
    jsr insdel_calc_nb
    push r0

    lda tmp_line
    bne ok_insert
    lda tmp_line+1
    beq no_need
    
ok_insert:
    // r0 = read = total, r1 = write = read + 1 
    mov r0, total_lines
    jsr insdel_precalc
    dec r0
    dec r0

    clc
    jsr insdel_copy

no_need:
    incw total_lines
    pop r0
    rts
}

} // edit

