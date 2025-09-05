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
    sec
    swi param_process,params_buffer

    mov r1,#filename
    swi str_cpy

    ldx #4
    clc
    swi file_open
    jcs error

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
    
    jsr fill_screen
    
    jsr status_line
    jsr move_cursor
    
    lda #0
    sta BLNSW
wait:
    jsr navigation
    bcc wait
    
    clc
    rts

max:
    .byte 0
affiche:
    .byte 0
options_edit:
    pstring("H")

filename:
    pstring("----FILENAME----")

init:
    sty affiche
    sty progress
    sty cursor_x
    sty cursor_y
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
    jsr status_line
    jmp move_cursor

error:
    sec
    rts
    
cursor_x:
    .byte 0
cursor_y:
    .byte 0
max_x:
    .byte 39
max_y:
    .byte 23
current_line:
    .word 0
total_lines:
    .word 0
tmp_line:
    .word 0
progress:
    .byte 0

//====================================================
// Editor code
//====================================================

//----------------------------------------------------
// navigation : process the navigation keys
//----------------------------------------------------

navigation:
{
    swi key_wait
    cmp #LEFT
    bne not_left
    
    lda cursor_x
    cmp #0
    beq not_left
    dec cursor_x
    jmp nav_cursor
    
    // Cursor Right
not_left:
    cmp #RIGHT
    bne not_right

    lda cursor_x
    cmp #39
    beq not_right
    inc cursor_x
    jmp nav_cursor

    // Cursor UP ?
not_right:
    cmp #UP
    bne not_up

    lda cursor_y
    cmp #0
    beq scroll_up
    dec cursor_y
    jmp nav_cursor
    
scroll_up:
    lda current_line
    cmp #0
    bne do_scroll_up
    lda current_line+1
    cmp #0
    bne do_scroll_up
    jmp end
    
do_scroll_up:
    sei
    jsr unblink_cursor
    decw current_line
    jsr fill_screen
    jsr move_cursor
    lda #0
    sta BLNSW
    cli
    jmp end    

    // Cursor DOWN ?
not_up:
    cmp #DOWN
    bne not_down

    lda cursor_y
    cmp #23
    beq scroll_down
    
    lda total_lines+1
    bne not_small
    lda cursor_y
    cmp total_lines
    beq not_down

not_small:
    inc cursor_y
    jmp nav_cursor

scroll_down:
    lda current_line
    cmp total_lines
    bne do_scroll_down
    lda current_line+1
    cmp total_lines+1
    bne do_scroll_down
    jmp not_down
    
do_scroll_down:
    sei
    jsr unblink_cursor
    incw current_line
    jsr fill_screen
    jsr move_cursor
    lda #0
    sta BLNSW
    cli

    // CTRL+A or U = start of line
not_down:
    cmp #CTRLA
    beq start_of_line
    cmp #CTRLU
    bne not_start
start_of_line:
    lda #0
    sta cursor_x
    jmp nav_cursor

    // CTRL+O or E = end of line
not_start:
    cmp #CTRLO
    beq end_of_line
    cmp #CTRLE
    bne not_end
end_of_line:
    ldy #40
find_end:
    dey
    beq found_end
    lda (PNT),y
    cmp #32
    beq find_end
    iny
found_end:
    dey
    sty cursor_x
    jmp nav_cursor
    
not_end:

end:
    clc
    rts

nav_cursor:
    sei
    jsr unblink_cursor
    jsr status_cursor
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
    sta screen_write
    sta screen_write2
    lda #4
    sta screen_write+1
    sta screen_write2+1
    
    mov r0,current_line
    mov r1,r0
    jsr goto_line
    
    ldx #0
    ldy #0
    sty pos_y
    sty pos_x
    clc
    jsr PLOT
    
    ldy #0
next_line:
    mov a,(r0++)
    cmp #0
    beq pad_line
    tax

write_line:
    mov a,(r0++)
    cmp #$41
    bcc not_letter
    cmp #$5B
    bcs not_letter
    sec
    sbc #$40
    jmp not_uppercase

not_letter:
    cmp #97
    bcc not_uppercase
    cmp #122
    bcs not_uppercase
    sec
    sbc #$60
not_uppercase:
    sta screen_write:$0400
    incw screen_write
    incw screen_write2
    //jsr CHROUT
    inc pos_x
    lda pos_x
    cmp #40
    beq end_line
    dex
    bne write_line

pad_line:
    lda #32
    sta screen_write2:$0400
    incw screen_write
    incw screen_write2
    
    //jsr CHROUT
    inc pos_x
    lda pos_x
    cmp #40
    bne pad_line

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
    rts

not_total:
    mov r0,r1
    jsr goto_line

    jmp next_line

pos_x:
    .byte 0
pos_y:
    .byte 0
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
    lda zr0h
    adc #>lines_ptr
    sta zr0h
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
// status_cursor : print the cursor position in
// the status line
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
    sta zr0l
    ldx #%00000011
    swi pprint_int
    lda #','
    jsr CHROUT
    lda cursor_y
    sta zr0l
    swi pprint_int
    lda #RVSOFF
    jsr CHROUT
    lda #WHITE
    jsr CHROUT
    rts
}

//----------------------------------------------------
// status_line : print the bottom status line
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
    lda #':'
    jsr CHROUT
    
    mov r0,#filename
    swi pprint
    mov a,(r0)
    tay
    cpy #16
    beq ok_name
complete_name:
    lda #32
    jsr CHROUT
    iny
    cpy #16
    bne complete_name

ok_name:
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
    lda #'*'
    jsr status_changed
    clc
    rts
}

status_changed:
{
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
    lda #nb_bam
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
    sec
    rts
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
