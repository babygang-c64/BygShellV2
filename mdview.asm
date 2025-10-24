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
//----------------------------------------------------

init_mdview:
{
    mov nodes_root,STREND
    mov data_root,STREND
    inc data_root+1
    inc data_root+1
    mov next_data,data_root
    ldy #0
    mov r0,nodes_root
    tya
    mov (r0),a
    iny
    mov (r0),a
    dey
    mov current_line,#1
    mov total_lines,#0
    sec
    jmp format_print_line
}

//----------------------------------------------------
// load_document : open and load markdown document
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

    // add node and line 
    mov r1,nodes_root
    mov r0,next_data
    swi node_append

    mov r1,next_data
    swi str_cpy,#work_buffer
    add r1,a
    mov next_data,r1
    
    incw total_lines
    
    jmp boucle_load
    
ok_close:
    ldx #4
    swi file_close
    rts
}

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
    
//    swi pprint
    jsr format_print_line
    
    cmpw line_y,total_lines
    beq end_loop

    incw line_y
    inc pos_y
    lda pos_y
    cmp #25
    beq end_loop
    lda #13
    jsr CHROUT
    jmp loop
end_loop:
    rts

line_y:
    .word 0
pos_y:
    .byte 0
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
    beq key_found
    cmp current_key
    beq key_found
    inx
    inx
    inx
    bne test_key
    jmp navigate

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
// format_print : format line of text and print
//
// c=1 init
//----------------------------------------------------

format_print_line:
{
    bcc not_init
    ldy #0
    sty is_code
    rts

not_init:
    lda #bios.COLOR_TEXT
    sta color
    ldy #0
    mov a,(r0)
    tax
    iny
    mov a,(r0)
    cmp #'#'
    beq process_title
    cmp #'>'
    beq process_citation
    cmp #'-'
    beq process_list
    cmp #39
    beq process_apost
    
    // standard line
    ldy #0
    ldx color
    swi theme_set_color
    swi pprint
    rts
    
    // title formating
process_title:
    dex
    lda #bios.COLOR_TITLE
    sta color
    iny
    mov a,(r0)
    cmp #'#'
    bne end_title
    iny
    dex
    lda #bios.COLOR_SUBTITLE
    sta color
    mov a,(r0)
    cmp #'#'
    bne end_title
    iny
    dex
    lda #bios.COLOR_CONTENT
end_title:
    jmp color_and_print

    // citation formating
process_citation:
    dex
    lda #bios.COLOR_NOTES
    sta color
    iny
    lda #32
    jsr CHROUT
    jsr CHROUT
    jmp color_and_print

process_list:
process_apost:
color_and_print:
    stx lgr
    ldx color
    swi theme_set_color
    ldx lgr
print_loop:
    mov a,(r0)
    jsr CHROUT
    iny
    dex
    bne print_loop
    ldy #0
    rts

lgr:
    .byte 0
is_code:
    .byte 0
color:
    .byte 0
}

} // MDVIEW namespace
