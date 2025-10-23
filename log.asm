//----------------------------------------------------
// log : log messages to file
//
// options : 
// H = help
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word log
pstring("log")

log:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_H=1
    .label OPT_Q=2
    .label OPT_A=4
    .label OPT_C=8
    .label OPT_N=16

    lda #10
    sta nb_lignes_max
    ldy #0
    sty cpt_ligne
    
    sec
    swi param_init,buffer,options_log
    jcs error
    swi pipe_init
    jcs error

    //------------------------------------------------
    // help option
    //------------------------------------------------
    
    lda options_params
    and #OPT_H
    jne help

    //------------------------------------------------
    // clear log option
    //------------------------------------------------
    
    lda options_params
    and #OPT_C
    jne clear_log

    //------------------------------------------------
    // if params, process
    //------------------------------------------------

    lda nb_params
    bne no_tail
    
    //------------------------------------------------
    // no params = view tail of log
    //------------------------------------------------
    
    ldx #'N'
    swi param_get_value
    bcc no_value
    lda zr0l
    sta nb_lignes_max

no_value:
    ldy #0
    sec
    ldx nb_lignes_max
    jsr add_line

    mov r0,#log_name
    swi file_exists
    bcc file_ok
    
    mov r0,#msg_no_log
    jmp error_m
    
file_ok:
    clc
    lda options_params
    and #OPT_A
    beq not_a
    sec
not_a:
    jsr tail_log
    jmp ok_close

    //------------------------------------------------
    // params : register new log message
    //------------------------------------------------

no_tail:
    
    ldx #4
    mov r0,#log_name
    jsr open_for_append
    jcs error_write
    
    ldx #4
    jsr CHKOUT
    jsr get_date
    
    lda options_params
    and #OPT_Q
    bne date_no_print
    ldx #3
    jsr CHKOUT
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    swi pprint,date_time_string
date_no_print:

    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    ldx #4
    jsr CHKOUT
    lda #','
    jsr CHROUT
    swi pprint
    lda options_params
    and #OPT_Q
    bne item_no_print
    ldx #3
    jsr CHKOUT
    ldx #bios.COLOR_SUBTITLE
    swi theme_set_color
    lda #','
    jsr CHROUT
    swi pprint
item_no_print:

    clc
    jmp boucle_params

fin_params:
    ldx #4
    jsr CHKOUT
    lda #13
    jsr CHROUT
    lda options_params
    and #OPT_Q
    bne nl_no_print
    ldx #3
    jsr CHKOUT
    lda #13
    jsr CHROUT
nl_no_print:
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    jmp ok_close

help:
    swi pprint_lines,help_msg
    clc
    rts

ok_close:
    ldx #4
    swi file_close

fini:
    clc
    swi success
    rts


msg_no_log:
    pstring("No log file")
msg_open:
    pstring("Log open")
msg_write:
    pstring("Log write")
    
error_write:
    mov r0,#msg_write
    jmp error_m

error_open:
    mov r0,#msg_open

error_m:
    sec
    swi error
    jsr ok_close
    rts

error:
    clc
    swi error
    rts

help_msg:
    pstring("*log [<message>]")
    pstring(" a = view all")
    pstring(" n = last N lines")
    pstring(" q = quiet")
    pstring(" c = clear log")
    pstring(" h = Help")
    .byte 0

options_log:
    pstring("hqacn")

log_name:
    pstring(".log,s")

cpt_ligne:
    .byte 0
nb_lignes:
    .byte 0
nb_lignes_max:
    .byte 0

//----------------------------------------------------
// clear_log : delete log file
//----------------------------------------------------

clear_log:
{
    clc
    ldx #15
    swi file_open,clear_log_name
    swi file_close
    lda options_params
    and #OPT_Q
    bne quiet
    ldx #bios.COLOR_ACCENT
    swi theme_set_color
    swi pprint_nl,msg_clear
    ldx #bios.COLOR_TEXT
    swi theme_set_color
quiet:
    rts
    
clear_log_name:
    pstring("s:.log")
msg_clear:
    pstring("Log cleared")
}

//----------------------------------------------------
// tail_log : view last lines
//
// C=0 : last lines, C=1 : all lines
//----------------------------------------------------

tail_log:
{
    stc is_all_lines

    ldy #0
    ldx #4
    clc
    swi file_open,log_name
    jcs error_open

    swi pipe_output

boucle_tail:
    ldx #4
    jsr CHKIN
    swi file_readline, work_buffer
    bcs view_and_close

    lda is_all_lines
    beq no_print
    
    jsr view_lines.print_single_line
    
    jmp boucle_tail

no_print:
    clc
    mov r0,#work_buffer
    jsr add_line
    jmp boucle_tail

view_and_close:
    ldx #4
    swi file_close
    lda is_all_lines
    bne not_all_lines
    jsr view_lines

not_all_lines:
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    rts

is_all_lines:
    .byte 0
}

//----------------------------------------------------
// add_line : add line in r0 to work buffer, if
// max lines then move out the first one before
//
// if C=1 init, X = max_lines
// uses the free BASIC RAM between STREND and FRETOP
//----------------------------------------------------

add_line:
{
    jcs init
    lda stored_lines
    cmp max_lines
    beq is_max
    inc stored_lines
    jmp insert

is_max:
    ldy #0
    mov r1,STREND
    mov a,(r1)
    add r1,a
    inc r1    
    mov r2,next_space
    sub r2,r1
    mov cpt_copy,r2
    mov r2,STREND
copy:
    mov a,(r1++)
    mov (r2++),a
    decw cpt_copy
    bne copy
    mov next_space,r2
insert:
    mov r1,next_space
    swi str_cpy
    add r1,a
    mov next_space,r1
    tya
    mov (r1),a
    rts

init:
    stx max_lines
    ldy #0
    sty stored_lines
    mov next_space,STREND
    rts

max_lines:
    .byte 0
stored_lines:
    .byte 0
next_space:
    .word 0
cpt_copy:
    .word 0
}

//----------------------------------------------------
// view_lines : print all stored lines
//----------------------------------------------------

view_lines:
{
    mov r0,STREND
    ldx add_line.stored_lines
    jeq end

loop:
    push r0
    stx save_x

    mov r1,#work_buffer
    swi str_cpy

    jsr print_single_line

    ldx save_x
    pop r0
    mov a,(r0)
    add r0,a
    inc r0
    dex
    jne loop
end:
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    rts

print_single_line:
    ldx #','
    swi str_split,work_buffer
    sta nb_split
    dec nb_split
    mov r0,#work_buffer
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    swi pprint
    ldx #bios.COLOR_SUBTITLE
    swi theme_set_color
print_all:
    lda #','
    jsr CHROUT
    swi str_next
    swi pprint
    dec nb_split
    bne print_all
    lda #13
    jmp CHROUT
save_x:
    .byte 0
nb_split:
    .byte 0
}

//------------------------------------------------------------
// get_date : view time and date, store to date_time_string
//------------------------------------------------------------

date_time_string:
    pstring("YYMMDD-HHMMSS")
    .byte 0

get_date:
{
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    jsr view_date

    ldx #bios.COLOR_SUBTITLE
    swi theme_set_color
    lda #'-'
    jsr CHROUT
    jsr view_time
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    rts
}

view_date:
{
    ldy #1
    ldx #1
    mov r0,#bios.date_time
    jsr print_segment
    jsr print_segment
    jmp print_segment
print_segment:
    jsr bios.bios_ram_get_byte
    iny
    jmp print_bcd
}

print_bcd:
{
    pha
    lsr
    lsr
    lsr
    lsr
    clc
    adc #$30
    sta date_time_string,x
    inx
    jsr CHROUT
    pla
    and #15
    clc
    adc #$30
    sta date_time_string,x
    inx
    jmp CHROUT
}

view_time:
{
    ldx #8
    lda $dc0b
    bpl is_am
    and #$7f
    clc
    adc #$12
is_am:
    jsr print_bcd
    lda $dc0a
    jsr print_bcd
    lda $dc09
    jsr print_bcd
    lda $dc08
    rts
}

//------------------------------------------------------------
// open_for_append : open file for write or append
// R0 = filename, uses work_buffer
//------------------------------------------------------------

open_for_append:
{
    stx channel
    mov r1,#work_buffer
    swi str_cpy
    swi file_exists,work_buffer
    bcc open_for_append

    mov r1,#suffix_write
    jmp do_open

open_for_append:
    mov r1,#suffix_append

do_open:
    swi str_cat,work_buffer
    ldx channel
    sec
    swi file_open
    rts

channel:
    .byte 0
suffix_write:
    pstring(",w")

suffix_append:
    pstring(",a")
}



} // LOG namespace
