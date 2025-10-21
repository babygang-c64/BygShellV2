//----------------------------------------------------
// sys : system info
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word sys
pstring("sys")

sys:
{
    .label params_buffer = $cd00
    .label work_buffer = $ce00
    .label OPT_C=1
    .label OPT_L=2
    .label OPT_H=4
    .label OPT_T=8
    
    //-- init options
    sec
    swi param_init,buffer,options_sys
    bcs help

    // no option = show info
    lda options_params
    bne with_options

    jsr env.list
    jmp end
    
with_options:

    lda options_params
    and #OPT_T
    beq not_time
    
    jsr set_time
    jmp end
    
not_time:
    //-- help option
    lda options_params
    and #OPT_H
    bne help

    lda options_params
    and #OPT_C
    beq not_clear

    jsr history.clear

not_clear:
    lda options_params
    and #OPT_L
    beq not_list

    swi pipe_init
    swi pipe_output
    jsr history.list

not_list:
end:
    swi pipe_end
    clc
    swi success
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts
    
    //-- options available
options_sys:
    pstring("clht")

msg_help:
    pstring("*sys [options]")
    pstring(" show system info")
    pstring(" h = show help")
    pstring(" l = list history")
    pstring(" c = clear history")
    pstring(" t = set time of day (HHMMSS)")
    .byte 0

check_reu:
{
    lda #0
    sta reu.control
    lda #<reu_test
    sta reu.c64base
    lda #>reu_test
    sta reu.c64base + 1
    lda #0
    sta reu.reubase
    sta reu.reubase + 1
    sta reu.reubase + 2
    lda #<$0008
    sta reu.translen
    lda #>$0008
    sta reu.translen + 1
    lda #%10010001 // REU -> c64
    // lda #%10010000;  c64 -> REU with immediate execution
    sta reu.command
    
    ldx #7
test:
    lda reu_test,x
    cmp reu_test_ref,x
    bne found
    dex
    bpl test
    clc
    rts
found:
    sec
    rts

reu_test:
    .byte $55,$FF,$AA,$18
    .byte $55,$FF,$AA,$81
reu_test_ref:
    .byte $55,$FF,$AA,$18
    .byte $55,$FF,$AA,$81
}

//------------------------------------------------------------
// set_time : set time of day
//------------------------------------------------------------

set_time:
{
    sec
    swi param_process,buffer
    bcs end_param
    
    ldy #1
    jsr read_value
    cmp #$12
    bcc is_am
    sec
    sbc #$12
    ora #$80
is_am:
    sta $dc0b
    jsr read_value
    sta $dc0a
    jsr read_value
    sta $dc09
    lda #0
    sta $dc08
    rts

read_value:
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
    
end_param:
    rts
temp:
    .byte 0
}

//------------------------------------------------------------
// env : environment
//------------------------------------------------------------

env:
{

box_vert:
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    lda #221
    jmp CHROUT

box_hor38:
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    ldx #38
hor38:
    lda #192
    jsr CHROUT
    dex
    bne hor38
    rts

box_hor_start:
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    lda #176
    jsr CHROUT
    jsr box_hor38
    lda #174
    jmp CHROUT

box_hor_middle:
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    lda #171
    jsr CHROUT
    jsr box_hor38
    lda #179
    jmp CHROUT
    
box_hor_end:
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    lda #171
    jsr CHROUT
    jsr box_hor38
    lda #189
    jmp CHROUT

line_sep:
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    lda #171
    jsr CHROUT
    lda #13
    jsr CHROUT
    ldx #bios.COLOR_CONTENT
    swi theme_set_color
    rts

vert_sep:
    txa
    pha
    ldx #bios.COLOR_TITLE
    swi theme_set_color
    jsr box_vert
    pla
    tax
    swi theme_set_color
    rts

list:
    jsr carriage_return

    ldx #bios.COLOR_ACCENT
    jsr vert_sep

    //-- Version
    swi pprint,#msg_byg_shell
    lda #$30+bios.VERSION_MAJ
    jsr CHROUT
    lda #'.'
    jsr CHROUT
    lda #$30+bios.VERSION_MIN
    jsr CHROUT
    jsr carriage_return

    // kernal version
    
    lda $e49c
    cmp #$4a
    bne not_jiffy
    lda #$46
    cmp $e49e
    bne not_jiffy
    cmp $e49f
    bne not_jiffy
    
    // jiffy / jaffydos
    ldx #bios.COLOR_TEXT
    jsr vert_sep
    lda $e49c
    clc
    adc #$80
    jsr CHROUT
    ldx #1
is_jiffy:
    lda $e49c,x
    jsr CHROUT
    inx
    cpx #13
    bne is_jiffy
    jsr carriage_return

not_jiffy:

    // SID type
    
    ldx #bios.COLOR_TEXT
    jsr vert_sep
    swi pprint,#msg_sid_type

    jsr test_sid_model
    mov r0,#msg_8580
    bcc sid8580
    mov r0,#msg_6581
sid8580:
    swi pprint_nl

    // REU check
    
    ldx #bios.COLOR_TEXT
    jsr vert_sep
    swi pprint,#msg_reu

    mov r0,#msg_none
    jsr check_reu
    bcc no_reu
    mov r0,#msg_reu_128k
    lda reu.status
    and #%00001000
    beq no_reu
    mov r0,#msg_reu_256k
no_reu:
    swi pprint_nl
    
    jsr line_sep

    // current device

    ldx #bios.COLOR_CONTENT
    jsr vert_sep
    swi pprint,msg_device
    lda CURRDEVICE
    jsr print_int2_or_none
    jsr carriage_return
    
    // Path and device for BIN
    
    ldx #bios.COLOR_CONTENT
    jsr vert_sep
    swi pprint,#msg_bin_device
    mov r0,#bios.bin_device
    jsr bios.bios_ram_get_byte
    jsr print_int2_or_none
    jsr carriage_return

    ldx #bios.COLOR_CONTENT
    jsr vert_sep
    swi pprint,#msg_path
    mov r0,#bios.bin_path
    sec
    jsr print_ram_or_none

    jsr line_sep

    // Clipboard content
    
    ldx #bios.COLOR_NOTES
    jsr vert_sep
    swi pprint,msg_clipboard    
    mov r0,#bios.clipboard
    sec
    jsr print_ram_or_none

    //-- History count

    ldx #bios.COLOR_NOTES
    jsr vert_sep
    swi pprint,msg_history
    mov r0,#bios.history_buffer
    jsr bios.bios_ram_get_byte
    jsr print_int8
    jsr carriage_return
    jsr line_sep

    //-- sh$ string
    ldx #bios.COLOR_NOTES
    jsr vert_sep
    swi pprint,msg_sh_string    
    sec
    mov r1,#work_buffer
    swi get_basic_string, sh_string
    cpx #0
    bne is_sh_string
    swi pprint_nl,msg_none
    jmp not_sh_string
    
is_sh_string:
    txa // length in A, R0 is string start (no length byte)
    ldy #$ff // is incremented
    ldx #0 // no screen to petscii conv
    jsr pprint_ram.basic
    jsr carriage_return

    //-- sh% integer
not_sh_string:
    ldx #bios.COLOR_NOTES
    jsr vert_sep
    swi pprint,msg_sh_int
    swi get_basic_int,var_int_sh_desc
    jsr print_int16
    jsr carriage_return

    // Theme

    jsr line_sep
    ldx #bios.COLOR_NOTES
    jsr vert_sep
    swi pprint,msg_theme
    mov r0,#bios.theme_name
    clc
    jsr pprint_ram
    lda #32
    jsr CHROUT
    jsr theme_colors
    jsr carriage_return

    // uptime, via ti$ for now

    ldx #bios.COLOR_NOTES
    jsr vert_sep
    swi pprint,msg_uptime

    lda $dc0b
    bpl is_am
    and #$7f
    clc
    adc #$12
is_am:
    jsr print_bcd
    lda #':'
    jsr CHROUT
    lda $dc0a
    jsr print_bcd
    lda #':'
    jsr CHROUT
    lda $dc09
    jsr print_bcd
    lda $dc08

end_env:
    ldx #bios.COLOR_TEXT
    swi theme_set_color
    jsr carriage_return
    rts

print_bcd:
    pha
    lsr
    lsr
    lsr
    lsr
    clc
    adc #$30
    jsr CHROUT
    pla
    and #15
    clc
    adc #$30
    jmp CHROUT
    
theme_colors:
    ldx #bios.COLOR_NOTES
    swi theme_set_color
    lda #179
    jsr CHROUT
    lda #RVSON
    jsr CHROUT
    theme_item('T',bios.COLOR_TEXT)
    theme_item('A',bios.COLOR_ACCENT)
    theme_item('t',bios.COLOR_TITLE)
    theme_item('S',bios.COLOR_SUBTITLE)
    theme_item('C',bios.COLOR_CONTENT)
    theme_item('N',bios.COLOR_NOTES)
    ldx #bios.COLOR_NOTES
    swi theme_set_color
    lda #RVSOFF
    jsr CHROUT
    lda #171
    jmp CHROUT

print_ram_or_none:
    jsr pprint_ram
    cmp #0
    bne carriage_return
    swi pprint,msg_none

carriage_return:
    lda #13
    jmp CHROUT

print_int2_or_none:
    cmp #0
    bne print2
    swi pprint,msg_none
    rts
print2:
    ldy #0
    sty zr0h
    sta zr0l
    ldx #%11000011
    swi pprint_int
    rts
print02:
    ldy #0
    sty zr0h
    sta zr0l
    ldx #%00000011
    swi pprint_int
    rts

print_int8:
    ldy #0
    sty zr0h
    sta zr0l
print_int16:
    ldx #%11011111
    swi pprint_int
    rts

msg_byg_shell:
    pstring("BYG-Shell v")
msg_clipboard:
    pstring("Clipboard  : ")
msg_sh_string:
    pstring("Status sh$ : ")
msg_sh_int:
    pstring("Status sh% : ")
msg_bin_device:
    pstring("BIN Device : ")
msg_path:
    pstring("BIN Path   : ")
msg_device:
    pstring("Curr device: ")
msg_theme:
    pstring("Theme      : ")
msg_uptime:
    pstring("Time of day: ")
msg_history:
    pstring("History #  : ")
msg_none:
    pstring("(None)")
msg_sid_type:
    pstring("Sid : ")
msg_6581:
    pstring("6581")
msg_8580:
    pstring("8580")
msg_reu:
    pstring("REU : ")
msg_reu_128k:
    pstring("Found, 128Kb")
msg_reu_256k:
    pstring("Found, 256Kb+")
var_int_sh_desc:
    .text "SH%"
    .byte 0
sh_string:
    .text "SH$"
    .byte 0
}

//------------------------------------------------------------
// history : history of commands
//------------------------------------------------------------

history:
{
clear:
    ldy #0
    sty bios.history_buffer
    sty bios.history_buffer+1
    sty bios.history_buffer+2
    rts

goto:
    ldy #0
    mov r0,#bios.history_buffer+2
    cpx #0
    beq found
do_goto:
    jsr bios.bios_ram_get_byte
    inc r0
    add r0,a
    dex
    bne do_goto
found:
    rts

list:
    ldy #0
    sty pos_histo
    mov r0,#bios.history_buffer
    jsr bios.bios_ram_get_byte
    sta nb_histo
    cmp #0
    bne next
    rts
next:
    jsr get
    dec nb_histo
    bne next
    rts

nb_histo:
    .byte 0
pos_histo:
    .byte 0

get:
    ldx pos_histo
    jsr history.goto
    inc pos_histo
    lda #'*'
    jsr CHROUT
    clc
    jsr pprint_ram
    lda #13
    jmp CHROUT
}

//------------------------------------------------------------
// pprint_ram : print pstring under basic ROM
//
// input : R0 = pstring, C=0 no conversion, 
// C=1 screen to petscii conversion
//
// uses R7 and indirectly ztmp / zsave
//------------------------------------------------------------

pprint_ram:
{
    stc zr7l
    ldy #0
    jsr bios.bios_ram_get_byte
basic:
    sta zr7h
    cmp #0
    beq no_print
    iny
print:
    jsr bios.bios_ram_get_byte
    ldx zr7l
    beq no_conv
    tax
    swi screen_to_petscii
no_conv:
    jsr CHROUT
    iny
    dec zr7h
    bne print
    ldy #0
    jsr bios.bios_ram_get_byte
no_print:
    rts
}

//---------------------------------------------------------------
// test_sid_model : check sid model, Soundemon / Daglem method
//
// return : C=0 8580, C=1 6581
//---------------------------------------------------------------

test_sid_model:
{
    sei
	lda #$ff
wait:
	cmp $d012
	bne wait
	
	sta $d412
	sta $d40e
	sta $d40f
	lda #$20
	sta $d412
	lda $d41b
	lsr
	rts
}

}

.macro theme_item(char,color)
{
    ldx #color
    swi theme_set_color
    lda #char
    jsr CHROUT
}
