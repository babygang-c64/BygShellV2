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
    .label params_buffer = $cd00
    .label lines_ptr = $7800
    .label buffer_edit = $7780  // relocate ?

    .label OPT_N=1
    
    sec
    swi param_init,buffer,options_edit
    jcs error
    
    ldx nb_params
//    jeq help

    // editor init
    ldy #0
    jsr init

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

    pop r0
    ldx #4
    clc
    swi file_open
    jcs error

    jsr status_line

    ldx #4
    jsr CHKIN

get_lines:
    swi file_readline, work_buffer
    jcs ok_close

    //swi pprint_nl
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
    
    lda #0
    jsr fill_screen
    
    jsr status_line
    jsr navigation.nav_cursor
    
    lda #0
    sta BLNSW
    
main_loop:
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
    jsr bam_init
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
    
    //--------------------------------
    // Master key CTRL+K
    //--------------------------------
    
    lda master_key
    bne process_masterkey

    lda current_key
    cmp #CTRLK
    jne not_master
    
    lda #1
    sta master_key
    lda #77+128
    sta $0400+38+40*24
    clc
    rts

process_masterkey:
    lda current_key
    cmp #CTRLK
    bne not_cancel_master

cancel_master:
    lda #0
    sta master_key
    lda #32+128
    sta $0400+38+40*24
    clc
    rts

not_cancel_master:    
    //--------------------------------
    // MASTER-T : go to top
    //--------------------------------
    cmp #'T'
    bne not_top
    
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
not_top:
    cmp #'+'
    bne not_set_mark
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
not_set_mark:
    cmp #'-'
    bne not_goto_mark
    mov current_line,mark_line
    lda #0
    sta cursor_y
    lda mark_x
    sta cursor_x
    lda mark_view_offset
    sta view_offset
    jsr cancel_master
    jmp update_and_go
    
not_goto_mark:
    jmp cancel_master

not_master:
    //--------------------------------
    // CTRL-X : Quit editor
    //--------------------------------

    cmp #CTRLX
    beq quit
    cmp #RUNSTOP
    beq quit
    bne no_quit

quit:
    sec
    rts

no_quit:
    //--------------------------------
    // CTRL-S : save
    //--------------------------------

    cmp #CTRLS
    bne not_save
    jsr save_file
    jmp nav_cursor

not_save:

    //--------------------------------
    // Cursor Left
    //--------------------------------

    cmp #LEFT
    bne not_left

cursor_left:
    lda cursor_x
    cmp #0
    bne ok_dec

    lda view_offset
    beq not_ok_left
    dec view_offset
    jmp update_screen
not_ok_left:
    clc
    rts

ok_dec:
    dec cursor_x
    jmp nav_cursor
    
    //--------------------------------
    // Cursor Right
    //--------------------------------
not_left:
    cmp #RIGHT
    bne not_right
    
    lda cursor_x
    ldy cursor_y
    cmp lines_length,y
    bne cursor_right
    ldy #0
    sty cursor_x
    jmp cursor_down

cursor_right:
    ldy #0
    lda cursor_x
    cmp #39
    bne ok_inc
    
    lda view_offset
    cmp #80
    beq not_right
    inc view_offset
    jmp update_screen

ok_inc:
    inc cursor_x
    jmp nav_cursor

    //--------------------------------
    // Cursor UP ?
    //--------------------------------
not_right:
    cmp #UP
    bne not_up

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
not_up:
    cmp #DOWN
    bne not_down

cursor_down:
    lda cursor_y
    cmp #23
    beq scroll_down
    
    lda total_lines+1
    bne not_small

    ldx total_lines
    dex
    cpx cursor_y
    jeq end

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
    clc
    rts
    
do_scroll_down:
    incw current_line
    jsr check_edit_end
    jmp update_and_go

    //--------------------------------
    // CTRL+A = start of line
    //--------------------------------
not_down:
    cmp #CTRLA
    bne not_start

    lda #0
    sta cursor_x
    jmp nav_cursor

    //--------------------------------
    // CTRL+E = end of line
    //--------------------------------
not_start:
    cmp #CTRLE
    bne not_end

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
    sty cursor_x
    jmp nav_cursor
    
    //--------------------------------
    // CTRL+W : next word
    //--------------------------------
not_end:
    cmp #CTRLW
    bne not_ctrlw
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
    sty cursor_x
    jmp nav_cursor

    //--------------------------------
    // other key ? start edit
    //--------------------------------
not_ctrlw:
    lda is_editing
    bne already_editing
    inc is_editing
    lda #1
    sta is_edited
    jsr status_changed

    jsr edit_line_init

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
    beq not_edited

    ldx work_buffer
    inx
    jsr malloc
    mov new_line,r0
    mov r1,r0
    
    mov r0,#work_buffer
    swi str_cpy
    
    mov r0, goto_line.ptr
    
    ldy #0
    lda new_line
    sta (zr0l),y
    iny
    lda new_line+1
    sta (zr0l),y
    dey
       
    lda #0
    sta is_editing

not_edited:
    rts

new_line:
    .word 0
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
    bne not_backspace
    
    //------------------------------------
    // Backspace
    //------------------------------------

    // Backspace : if at end and not zero, decrease length
    lda work_buffer
    beq backspace_suppress_line
    
    // check if at end
    lda cursor_x
    clc
    adc view_offset
    cmp work_buffer
    beq backspace_at_end
    
    // not at end : suppress within string or join lines
    lda view_offset
    bne not_backspace_start
    lda cursor_x
    bne not_backspace_start
    
    // at start : join with previous line except if first line
    inc $d020
    jmp end
    
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
    lda current_line
    clc
    adc cursor_y
    bne backspace_not_zero
    lda current_line+1
    adc #0
    bne backspace_not_zero
    jmp end

backspace_not_zero:
    jsr suppress_line_at_cursor
    jmp navigation.update_and_go
    
not_backspace:

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

    lda cursor_x
    clc
    adc view_offset
    tax
    inx
    lda navigation.current_key
    sta work_buffer,x
    jsr update_current_line
    jmp navigation.cursor_right

insert_char:
    pstring(" ")

}

//----------------------------------------------------
// suppress_line_at_cursor : mark line as zero bytes, 
// suppress line from lines list, goto line-1
//----------------------------------------------------

suppress_line_at_cursor:
{
    jsr goto_line_at_cursor
    lda #0
    sta tmp_line
    sta tmp_line+1
    mov (r0),a

    mov r0,current_line
    lda cursor_y
    add r0,a
    mov cmp_line,r0
    
    mov r0,#lines_ptr
    mov r1,#lines_ptr
    
again:
    // not current line ?
    lda tmp_line
    cmp cmp_line
    bne not_current_line
    lda tmp_line+1
    cmp cmp_line+1
    bne not_current_line
    
    // current_line
    inc r1
    inc r1

not_current_line:
    // copy from r1 to r0
    mov a,(r1++)
    mov (r0++),a
    mov a,(r1++)
    mov (r0++),a

suite:
    incw tmp_line
    lda tmp_line
    cmp total_lines
    bne again
    lda tmp_line+1
    cmp total_lines+1
    bne again

    decw total_lines
    rts
}

//----------------------------------------------------
// edit_line_init : start editing line
//
// edited_line = source of line to edit
// update line reference with work_buffer
// copy source line to work_buffer
//----------------------------------------------------

edit_line_init:
{
    jsr goto_line_at_cursor
    
    // ici r0 = edited_line
    
    mov edited_line,r0
    
    mov r1,goto_line.ptr
    
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
    
    rts
}

//----------------------------------------------------
// goto_line_at_cursor : get line at cursor in r0
//----------------------------------------------------

goto_line_at_cursor:
{
    mov r0,current_line
    lda cursor_y
    add r0, a
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
    dex
    bne paint

pad_line:
    lda #32
paint_pad:
    ldx cpt_x
    cpx #40
    beq fin
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
// output : line buffer in R0
//----------------------------------------------------

goto_line:
{
    asl zr0l
    rol zr0h
    clc
    lda zr0l
    adc #<lines_ptr
    sta zr0l
    sta ptr

    lda zr0h
    adc #>lines_ptr
    sta zr0h
    sta ptr+1
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
ptr:
    .word 0
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
    lda cursor_x
    clc
    adc view_offset
    sta zr0l
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
    cpy #21
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

status_line:
{
    ldx #24
    ldy #0
    clc
    jsr PLOT
    lda #LIGHT_GRAY
    jsr CHROUT
    lda #RVSON
    jsr CHROUT
    
    ldy CURRDEVICE
    swi pprinthex8a

    jsr print_name

    lda #32
    jsr CHROUT

    lda #'('
    jsr CHROUT
    ldy #0
    sty zr0h
    lda cursor_x
    sta zr0l
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
    
    mov r0,current_line
    ldx #%11001111
    swi pprint_int
    lda #'/'
    jsr CHROUT
    mov r0,total_lines
    swi pprint_int

    lda #32
    jsr CHROUT
    jsr CHROUT

    lda #RVSOFF
    jsr CHROUT
    lda #WHITE
    jsr CHROUT
    jsr status_changed
    clc
    rts
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
//====================================================

.label memory_start=$0800
.label nb_bam=14

bam:
    .fill nb_bam,0
bam_free:
    .byte nb_bam*8
bam_allocated:
    .byte 0

//---------------------------------------------------------------
// bam_init : reset bam
//---------------------------------------------------------------

bam_init:
    ldy #0
    tya
clear_bam:
    sta bam,y
    iny
    cpy #nb_bam
    bne clear_bam
    lda #nb_bam*8
    sta bam_free
    ldy #0
    sty bam_allocated
    rts
    
//---------------------------------------------------------------
// set_bit : sets bit #Y to 1 into A
//---------------------------------------------------------------

bit_list:
    .byte 1,2,4,8,16,32,64,128

set_bit:
{
    ora bit_list,y
    rts
}

//---------------------------------------------------------------
// next_free_bit : lookup for 1st unset bit in A, return into Y
//---------------------------------------------------------------

next_free_bit:
{
    ldy #7
    sta ztmp
lookup:
    and bit_list,y
    beq is_free
    lda ztmp
    dey
    bpl lookup
is_free:
    rts
}

//----------------------------------------------------
// bam_next : get first / next allocated block
//
// input : C=1 start, C=0 continue
// output : R0 = block, C=1 KO, C=0 OK
//----------------------------------------------------

bam_next:
{
    bcc not_first
    mov r0, #memory_start
    lda #0
    sta bit_bam
    sta pos_bam

not_first:
    ldx pos_bam
    lda bam,x
    ldy bit_bam
    cpy #8
    beq not_found
    
    and bit_list,y
    bne found

    inc zr0h
    iny
    sty bit_bam
    ldy bit_bam
    cpy #8
    bne not_first

not_found:
    ldy #0
    sty bit_bam
    inc pos_bam
    
    lda pos_bam
    lda bam_allocated
    
    lda pos_bam
    cmp bam_allocated
    bne not_first
    
    sec
    rts
    
found:
    inc bit_bam
    clc
    rts

pos_bam:
    .byte 0
bit_bam:
    .byte 0
}

//----------------------------------------------------
// bam_get : allocate one block if possible
//
// output : R0 = allocated block, C=1 = KO, C=0 = OK
//----------------------------------------------------

bam_get:
{
    lda bam_free
    beq error
    
    mov r0, #memory_start
    ldx #0
    
bam_next:
    lda bam,x
    cmp #$ff
    bne new_block
    
    add r0, #$0800
    inx
    bne bam_next

new_block:
    jsr next_free_bit
    lda bam,x
    jsr set_bit
    sta bam,x

    dec bam_free
    inc bam_allocated
    
    tya
    clc
    adc zr0h
    sta zr0h
    
    ldy #0
    lda #255
    mov (r0),a
    clc
    rts

error:
    inc $d020
    jmp error
}

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
   mov r0,#memory_start

scan_bam:
    lda bam,y
    beq new_block
    
    sec
test_bam:
    jsr bam_next
    bcs new_block
    
    ldy #0
    mov a,(r0)
    cmp how_much
    bcc test_bam

ok_size:
    sta bam_available
    lda #0
    sec
    sbc bam_available
    pha
    
    sec
    lda bam_available
    sbc how_much
    sta bam_available
    mov (r0),a
    
    pla
    clc
    add r0,a

    clc
    rts
    
    // no space free in allocated blocs, allocate a new block,
    // the new block free space is 255-X

new_block:
    jsr bam_get
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

}
