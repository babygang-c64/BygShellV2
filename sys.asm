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
    .label OPT_C=1
    .label OPT_L=2
    .label OPT_H=4
    
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
    pstring("clh")

msg_help:
    pstring("*sys [options]")
    pstring(" show system info")
    pstring(" h = show help")
    pstring(" l = list history")
    pstring(" c = clear history")
    .byte 0


//------------------------------------------------------------
// env : environment
//------------------------------------------------------------

env:
{
list:
    //-- clipboard content
    swi pprint,msg_clipboard    
    mov r0,#bios.clipboard
    sec
    jsr print_ram_or_none
    
    //-- history
    swi pprint,msg_history
    mov r0,#bios.history_buffer
    jsr bios.bios_ram_get_byte
    jsr print_int8

    //-- sh$ string
    swi pprint,msg_sh_string    
    sec
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
    swi pprint,msg_sh_int
    swi get_basic_int,var_int_sh_desc
    jsr print_int16

    //-- Current device
    swi pprint,msg_device
    lda CURRDEVICE
    bne is_value_device
    swi pprint_nl,msg_none
    jmp next_bin_device

is_value_device:
    jsr print_int8

    //-- bin device
next_bin_device:
    swi pprint,msg_bin
    swi pprint,msg_device
    mov r0,#bios.bin_device
    jsr bios.bios_ram_get_byte
    cmp #0
    bne is_value_bin_device
    swi pprint_nl,msg_none
    jmp next_bin_path
    
is_value_bin_device:
    jsr print_int8

    //-- bin path
next_bin_path:
    swi pprint,msg_bin
    swi pprint,msg_path
    mov r0,#bios.bin_path
    clc
    jsr print_ram_or_none

end_env:
    rts

print_ram_or_none:
    jsr pprint_ram
    cmp #0
    bne carriage_return
    swi pprint,msg_none

carriage_return:
    lda #13
    jmp CHROUT

print_int8:
    ldy #0
    sty zr0h
    sta zr0l
print_int16:
    ldx #%10011111
    swi pprint_int
    jmp carriage_return

sh_string:
    .text "SH$"
    .byte 0
msg_clipboard:
    pstring("Clip:")
msg_sh_string:
    pstring("SH$ :")
msg_sh_int:
    pstring("SH% :")
msg_bin:
    pstring("BIN ")
msg_path:
    pstring("Path:")
msg_device:
    pstring("Dev :")
msg_history:
    pstring("Hist:")
msg_none:
    pstring("-")
var_int_sh_desc:
    .text "SH%"
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


}
