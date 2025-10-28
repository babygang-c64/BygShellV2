//----------------------------------------------------
// mdview : navigate markdown files
//
// options : 
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word mdview
pstring("mdview")

mdview:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_A=1

    sec
    swi param_init,buffer,options_mdview
    jcs error

    ldx nb_params
    jeq help

    ldy #0
    jsr init_mdview
    
    sec
    swi param_process,params_buffer
    
    jsr load_document

view_loop:
    jsr view_lines
    jsr navigate
    bcc view_loop

end:
    jsr CLRCHN
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    clc
    swi success
    rts
    
help:
    swi pprint_lines,help_msg
    clc
    rts

msg_open:
    pstring("File open")

error_open:
    mov r0,#msg_open
    sec
    bcs do_error
error:
    clc
do_error:
    swi error
    rts


help_msg:
    pstring("*mdview <filename> [-a]")
    pstring(" a = Convert ASCII")
    .byte 0

options_mdview:
    pstring("a")

nodes_root:
    .word 0
data_root:
    .word 0
next_data:
    .word 0
current_line:
    .word 0
total_lines:
    .word 0

//----------------------------------------------------
// init_mdview : setup memory for lines and content
//
// nodes_root at STREND for 2 blocks, 
// with 0 allocated nodes
// data_root at STREND+$0200
// next_data ptr at data_root
// string data : pstring
//----------------------------------------------------

init_mdview:
{
    mov nodes_root,STREND
    mov data_root,STREND
    inc data_root+1
    inc data_root+1
    mov next_data,data_root
    ldy #0
    sty is_code
    mov r0,nodes_root
    tya
    mov (r0),a
    iny
    mov (r0),a
    dey
    mov current_line,#1
    mov total_lines,#0
    rts
}

//----------------------------------------------------
// load_document : open and load markdown document
//
// storage : pointers to lines in node list at
// nodes_root, lines data at data_root as this :
// 1 byte : type, bitmap
//      7 = has link
//      6 = reserved
//      5 = code block
//      4 = citation
//      3 = title 3
//      2 = title 2
//      1 = title 1
//      0 = text
// 1 byte : max length (for code block)
//----------------------------------------------------

load_document:
{
    ldx #4
    clc
    swi file_open
    jcs error_open

    ldx #4
    jsr CHKIN

boucle_load:
    ldx #4
    swi file_readline, work_buffer
    bcs ok_close
    
    lda options_params
    and #OPT_A
    beq not_opt_a
    
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv
    
not_opt_a:

    mov r1,next_data
    mov r0,#work_buffer
    jsr preprocess_and_store
    bcs no_store

    push r1
    // add node and line data
    mov r1,nodes_root
    mov r0,next_data
    swi node_append
    pop r1

    mov next_data,r1    
    incw total_lines
no_store:
    jmp boucle_load
    
ok_close:
    ldx #4
    swi file_close
    rts
}

//----------------------------------------------------
// preprocess_and_store : pre-process an input line
// and store the data
// input : r0 = pstring, r1 = data store
//----------------------------------------------------

.label TYPE_TEXT = 0
.label TYPE_TITLE1 = 1
.label TYPE_TITLE2 = 2
.label TYPE_TITLE3 = 3
.label TYPE_CITATION = 4
.label TYPE_LIST = 5
.label TYPE_CODE = 6
.label TYPE_LINK = 7
.label TYPE_LINE = 8

preprocess_and_store:
{
    lda is_code
    beq not_in_code_block
    jmp process_code

not_in_code_block:
    ldy #0
    mov a,(r0)
    beq force_text
    iny
    mov a,(r0)
    cmp #'#'
    beq found_title
    cmp #39
    beq found_apost
    cmp #'>'
    beq found_citation
    cmp #'-'
    beq found_list

force_text:
    lda #TYPE_TEXT
    ldx #0
is_text:
    // is text
    ldy #0
    mov (r1++),a
    tax
    mov (r1++),a
    swi str_cpy
    add r1,a
    clc
    rts

found_citation:
    lda #TYPE_CITATION
    jmp is_text
    
found_list:
    iny
    mov a,(r0)
    cmp #'-'
    bne is_list
    iny
    mov a,(r0)
    cmp #'-'
    bne is_list
    lda #TYPE_LINE
    jmp is_text
is_list:
    lda #TYPE_LIST
    jmp is_text
    
found_title:
    iny
    mov a,(r0)
    cmp #'#'
    beq found_title2
    lda #TYPE_TITLE1
    jmp is_text
found_title2:
    iny
    mov a,(r0)
    cmp #'#'
    beq found_title3
    lda #TYPE_TITLE2
    jmp is_text
found_title3:
    lda #TYPE_TITLE3
    jmp is_text
    
found_apost:
    ldy #0
    mov a,(r0)
    cmp #3
    bne is_text
    
    lda #1
    sta is_code
    mov first_code,r1
    lda #0
    sta maxlen_code
    sec
    rts

end_code:
    lda #0
    sta is_code
    mov r2,first_code
    
copy_maxlen:
    ldy #1
    lda maxlen_code
    mov (r2),a
    iny
    mov a,(r2)
    ldy #0
    add r2,a
    add r2,#3
    cmpw r2,r1
    bne copy_maxlen
    sec
    rts
    
process_code:
    ldy #0
    mov a,(r0)
    cmp #3
    bne not_apost
    iny
    mov a,(r0)
    cmp #39
    bne not_apost
    jmp end_code

not_apost:
    ldy #0
    mov a,(r0)
    cmp maxlen_code
    bcc not_more
    sta maxlen_code
    cmp #3
    bne not_more
    iny
    mov a,(r0)
    cmp #39
    bne not_more
    jmp end_code
    
not_more:
    lda #TYPE_CODE
    jmp is_text
    
first_code:
    .word 0
}

is_code:
    .byte 0
maxlen_code:
    .byte 0

//----------------------------------------------------
// view_lines : from current_line, browse content
//----------------------------------------------------

view_lines:
{
    lda #147
    jsr CHROUT

    lda #0
    sta pos_y
    mov line_y,current_line

loop:
    mov r1,nodes_root
    mov r0,line_y
    swi node_goto
    lda #0
    sta is_nl
    jsr format_print_line
    
    cmpw line_y,total_lines
    beq end_loop

    inc pos_y
    incw line_y
    lda pos_y
    cmp #25
    beq end_loop

    lda is_nl
    beq do_nl
    lda #0
    sta is_nl
    beq loop
do_nl:
    lda #13
    jsr CHROUT
    jmp loop

end_loop:
    rts

is_nl:
    .byte 0
line_y:
    .word 0
pos_y:
    .byte 0
}

//----------------------------------------------------
// has_accent : check if there is a *xxx* format in
// string in R0
// return : C=1 if found
//----------------------------------------------------

has_accent:
{
    ldy #0
    lda (zr0),y
    tay
    ldx #0
loop:
    lda (zr0),y
    cmp #'*'
    bne not_accent
    inx
not_accent:
    dey
    bne loop
    cpx #2
    rts
}

//----------------------------------------------------
// navigate : document navigation
//----------------------------------------------------

navigate:
{
    swi key_wait
    sta current_key
    bcc key_jump
    rts

    // A = key pressed, lookup in nav_keys and jump
key_jump:
    ldx #0
test_key:
    lda nav_keys,x
    beq end_found
    cmp current_key
    beq key_found
    inx
    inx
    inx
    bne test_key
end_found:
    clc
    rts

key_found:
    lda nav_keys+1,x
    sta key_jump_addr
    lda nav_keys+2,x
    sta key_jump_addr+1
    jmp key_jump_addr:$FCE2

    //------------------------------------------------
    // space : move one page down
    //------------------------------------------------
    
key_space:
    mov r0,current_line
    add r0,#25
    cmpw r0,total_lines
    bcs navigate
    mov current_line,r0
    clc
    rts
    
    //------------------------------------------------
    // home : go top
    //------------------------------------------------

key_home:
    mov current_line,#1
    clc
    rts

    //------------------------------------------------
    // backspace : go one page up
    //------------------------------------------------

key_backspace:
    mov r0,#1
    cmpw current_line,r0
    beq key_home
    mov r0,current_line
    sub r0,#25
    mov current_line,r0
    clc
    rts

nav_keys:
    .byte 32
    .word key_space
    .byte DOWN
    .word key_space
    .byte HOME
    .word key_home
    .byte BACKSPACE
    .word key_backspace
    .byte UP
    .word key_backspace
    .byte 0

current_key:
    .byte 0
}

//----------------------------------------------------
// format_print_line : format line of text and print
//----------------------------------------------------

format_print_line:
{
    ldy #0
    mov a,(r0)
    sta type
    tay
    lda colors,y
    tax
    swi theme_set_color
    lda type
    asl
    tax
    lda jmp_type,x
    sta addr_jmp
    lda jmp_type+1,x
    sta addr_jmp+1
    jmp addr_jmp:$FCE2

print_text:
    ldy #2
    mov a,(r0)
    cmp #0
    bne not_empty
    rts
not_empty:
    tax
    iny

print_remaining:
    mov a,(r0)
    jsr CHROUT
    iny
    dex
    bne print_remaining
    rts

print_title1:
    ldy #2
    lda #40
    sec
    sbc (zr0l),y
    lsr
    tax
    jsr spaces
    jmp print_after1
    
print_title2:
    ldy #2
    mov a,(r0)
    tax
    dex
    ldy #5
    jmp print_remaining

print_title3:
    ldy #2
    mov a,(r0)
    tax
    dex
    ldy #6
    jmp print_remaining

print_citation:
    lda #32
    jsr CHROUT
    jmp print_after1

print_code:
    lda #RVSON
    jsr CHROUT
    ldy #1
    sec
    lda (zr0l),y
    iny
    sbc (zr0l),y
    tax
    stx lgr

    jsr print_text
    ldx lgr
    beq no_spaces
    jsr spaces
no_spaces:
    lda #RVSOFF
    jmp CHROUT

spaces:
    lda #32
    jsr CHROUT
    dex
    bne spaces
    rts

print_lines:
    ldy #40
line:
    lda #$c0
    jsr CHROUT
    dey
    bne line
    dex
    dex
    dex
    lda #1
    sta view_lines.is_nl
    rts
    
print_list:
    ldx #bios.COLOR_CONTENT
    swi theme_set_color
    lda #'-'
    jsr CHROUT
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    jmp print_after1

print_after1:
    ldy #2
    mov a,(r0)
    tax
    dex
    ldy #4
    jmp print_remaining

lgr:
    .byte 0
type:
    .byte 0

colors:
    .byte bios.COLOR_TEXT
    .byte bios.COLOR_TITLE
    .byte bios.COLOR_SUBTITLE
    .byte bios.COLOR_CONTENT
    .byte bios.COLOR_NOTES
    .byte bios.COLOR_TEXT
    .byte bios.COLOR_NOTES
    .byte bios.COLOR_TEXT
    .byte bios.COLOR_SUBTITLE

jmp_type:
    .word print_text
    .word print_title1
    .word print_title2
    .word print_title3
    .word print_citation
    .word print_list
    .word print_code
    .word print_text
    .word print_lines
}

} // MDVIEW namespace
