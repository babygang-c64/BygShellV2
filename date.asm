//----------------------------------------------------
// date : view / set date and time
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word date
pstring("date")

date:
{
    .label work_buffer = $ce00
    .label params_buffer = $cd00

    .label OPT_H=1
    .label OPT_Q=2

    sec
    swi param_init,buffer,options_date
    jcs error
    swi pipe_init
    jcs error

    lda options_params
    and #OPT_H
    bne help

    swi pipe_output

    ldx nb_params
    jeq view

    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params


    ldy #0
    mov a,(r0)
    cmp #6
    bne not_time
    jsr set_time
    jmp next_param
not_time:
    cmp #8
    bne error
    jsr set_date
    
next_param:
    clc
    jmp boucle_params

fin_params:
    jsr view
    swi pipe_end
    clc
    swi success
    rts

help:
    swi pprint_lines,help_msg
    clc
    rts

error:
    sec
    swi error
    rts

help_msg:
    pstring("*date [YYYYMMDD] [HHMMSS] [-options]")
    pstring(" q = Quiet mode")
    pstring(" h = Help")
    .byte 0

options_date:
    pstring("hq")

return_string:
    .text "SH$"
string_len:
    .byte 19
string_adr_storage:
    .word string_storage+1
string_storage:
date_time_string:
    pstring("YYYY/MM/DD HH:MM:SS")
    .byte 0

//------------------------------------------------------------
// view : view time and date
//------------------------------------------------------------

view:
{
    jsr view_date
    lda #32
    jsr chrout_cond
    jsr view_time
    lda #13
    jsr chrout_cond
    swi set_basic_string,return_string
    rts
}

chrout_cond:
{
    pha
    lda options_params
    and #OPT_Q
    bne no_print
    pla
    jmp CHROUT

no_print:
    pla
    rts
}

view_date:
{
    ldy #0
    ldx #1
    mov r0,#bios.date_time
    jsr print_segment
    jsr print_segment
    jsr print_slash
    jmp print_slash
print_slash:
    lda #'/'
    jsr chrout_cond
    inx
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
    jsr chrout_cond
    pla
    and #15
    clc
    adc #$30
    sta date_time_string,x
    inx
    jmp chrout_cond
}

view_time:
{
    ldx #12
    lda $dc0b
    bpl is_am
    and #$7f
    clc
    adc #$12
is_am:
    jsr print_bcd
    lda #':'
    inx
    jsr chrout_cond
    lda $dc0a
    jsr print_bcd
    lda #':'
    inx
    jsr chrout_cond
    lda $dc09
    jsr print_bcd
    lda $dc08
    rts
}

//------------------------------------------------------------
// set_date : set date, format YYYYMMDD
//------------------------------------------------------------

set_date:
{
    ldy #1
    ldx #0
    jsr update_2digits
    jsr update_2digits
    jsr update_2digits
    jmp update_2digits

update_2digits:
    jsr set_time.read_bcd_value
    sta bios.date_time,x
    inx
    rts
}

//------------------------------------------------------------
// set_time : set time of day, value in R0 : HHMMSS
//------------------------------------------------------------

set_time:
{
    ldy #1
    jsr read_bcd_value
    cmp #$12
    bcc is_am
    sec
    sbc #$12
    ora #$80
is_am:
    sta $dc0b
    jsr read_bcd_value
    sta $dc0a
    jsr read_bcd_value
    sta $dc09
    lda #0
    sta $dc08
    rts

read_bcd_value:
    lda (zr0l),y
    sec
    sbc #'0'
    asl
    asl
    asl
    asl
    sta temp
    iny
    lda (zr0l),y
    sec
    sbc #'0'
    ora temp
    iny
    rts
    
temp:
    .byte 0
}


} // DATE namespace
