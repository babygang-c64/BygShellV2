//===============================================================
// BYG SHELL : Command line Shell
//
// 2024-2025 Babygang
//===============================================================


#import "kernal.asm"
#import "macros.asm"


* = $8000

.word start_cartridge
.word start_cartridge
.byte $c3,$c2,$cd
.text "80"

#import "bios_pp.asm"

.label work_buffer=$cf00

start_cartridge:

    stx $d016
    jsr $fda3
    jsr $fd50
    jsr $fd15
    jsr $ff5b
    cli

    jsr $e453
    jsr $e3bf
    jsr $e422


    // change basic IGONE hook to our routine
    
    lda #<basic_hook
    sta IGONE
    lda #>basic_hook
    sta IGONE+1
    
    // change IRQ hook to our routine
    
    sei
    lda #0
    sta k_flag
    lda #<irq_hook
    sta IIRQ
    lda #>irq_hook+1
    sta IIRQ+1
    cli
    
    // change basic IEVAL to our routine for $

    lda #<basic_ieval
    sta IEVAL
    lda #>basic_ieval
    sta IEVAL+1
    
    // BIOS reset and start message
    
    lda #7
    sta CURSOR_COLOR

    jsr bios.do_reset
    lda #23
    sta $d018
    swi pprint_nl,start_message
    lda #1
    sta CURSOR_COLOR
    jmp READY

start_message:
    .byte 16
    .byte $0d
    .text "*BYG-Shell v2.0"

basic_hook:
    jsr CHRGET
    php
    cmp #172
    beq process_shell
    cmp #42
    beq process_shell
    plp
    jmp GONE3

process_shell:
    plp
    jsr nchrget

    ldx #1
    
    cmp #$00
    bmi do_token
    
copy_command:
    sta buffer,x
    inx   
    jsr nchrget
    bcc copy_command

    cmp #$00
    bmi do_token

    cmp #45
    beq copy_command
    
    lda #0
    sta buffer,x
    dex
    stx buffer

    jsr exec_command
    sec
//    swi bank_basic
//    lda #55
//    sta $01
//    cli
    jmp NEWSTT

do_token:
    jsr token_lookup
    clc

next_token_char:
    jsr token_expand
    sta buffer,x
    bcs fin_token
    inx
    bne next_token_char

fin_token:
    clc
    bcc copy_command

//---------------------------------------------------------------
// nchrget : CHRGET for shell commands
//---------------------------------------------------------------

nchrget:
{
    ldy #0
    inc $7a
    bne nchrget2
    inc $7b
nchrget2:
    lda ($7a),y
    
    bmi nchrget_end
    
    beq nchrget_end
    cmp #$3a
    beq nchrget_end
    clc
    ldy #2
test_char:
    cmp special_char,y
    beq modif_char
    dey
    bpl test_char
    rts

modif_char:
    lda new_char,y
    rts

nchrget_end:
    sec
    rts

special_char:
    .byte 172,170,171
new_char:
    .text "*+-"
}

//---------------------------------------------------------------
// exec_command : load external command to $c000
//---------------------------------------------------------------

print_command:
{
    ldx #1
do_print:
    lda buffer,x
    beq fini
    jsr CHROUT
    inx
    bne do_print
fini:
    rts
}

exec_command:
{
    lda #MSG_NONE
    jsr SETMSG

    jsr prep_params
    
    jsr cache_check
    bcs already_loaded
    
    jsr internal_command_check
    bcs no_run

    ldy #0
    mov r0,#bin_device
    jsr bios.bios_ram_get_byte
    beq no_bin_configured
    tax
    bne device_ok

no_bin_configured:    
    ldx CURRDEVICE
    bne device_ok
    ldx #8
device_ok:
    lda #1
    ldy #1
    jsr SETLFS

    lda buffer
    ldx #<buffer+1
    ldy #>buffer+1
    jsr SETNAM
    lda #0
    jsr LOAD
    bcs load_error
    cpy #$a0
    bcc no_run

    jsr cache_check

already_loaded:
    jsr start_command

no_run:
    jmp exec_end
load_error:
    ldx #4
    jmp ERRORX

exec_end:
    lda #MSG_ALL
    jmp SETMSG

start_command:
    cpx #$c0
    bne under_basic
    jmp ($c000)

under_basic:
//    sei
//    lda #54
//    sta $01
//    clc
//    swi bank_basic
    jmp ($c000)

cache_check:
    ldx #$c0
    mov r0,#buffer
    mov r1,#$c002
    swi str_cmp
    bcs found
    ldx #$a0
    clc
    
//    sei
//    lda #54
//    sta $01

//    swi bank_basic 
    mov r0,#buffer
    mov r1,#$a002
    swi str_cmp
    bcs found
//    sec 
//    swi bank_basic
//    lda #55
//    sta $01
//    cli
    clc
    rts

found:
//    sec
//    lda #55
//    sta $01
//    cli
//    swi bank_basic
    sec
    rts
}

//---------------------------------------------------------------
// prep_params : split and count parameters
//---------------------------------------------------------------

prep_params:
{
    ldx #32
    sec
    swi str_split,buffer
    sta nb_params
    rts
}

//---------------------------------------------------------------
// token_lookup : find basic token
//
// input : A = token
// output : Y = token pos in RESLST, no check if token exists
//          C = 1 = ignore token (for print), else C = 0
//---------------------------------------------------------------

token_lookup:
{
    stx ztmp
    and #$7f
    tax
    ldy #0
test_next:
    lda RESLST,y
    bmi fin_token
    iny
    bne test_next
fin_token:
    iny
    dex
    bne test_next
    ldx ztmp
    rts 
}

//---------------------------------------------------------------
// token_expand : expand token until finished
//
// input : Y = pos in RESLST
// output : A = token char, C=0 = continue, C=1 = end
//---------------------------------------------------------------

token_expand:
{
    lda RESLST,y
    bmi expand_end
    iny
    rts
expand_end:
    and #$7f
    sec
    rts
}

//---------------------------------------------------------------
// internal command check : if found, execute and returns C=1
//---------------------------------------------------------------

internal_command_check:
{
    mov r0, #internal_commands
    mov r1, #buffer
    swi lines_find
    bcc not_found

found:
    dec nb_params
    txa
    asl
    tax
    lda internal_commands_jump,x
    sta zr0l
    lda internal_commands_jump+1,x
    sta zr0h
    jmp (zr0)

not_found:
    clc
    rts
}

//---------------------------------------------------------------
// list of internal commands
//---------------------------------------------------------------

internal_commands:
    pstring("HELP")
    pstring("M")
    pstring("ENV")
    .byte 0

internal_commands_jump:
    .word do_help
    .word do_memory
    .word do_env

internal_commands_help:
    pstring("*Help [Command] : Help on commands")
    pstring("*M <start> [end]: Memory hexdump/write")
    pstring("*ENV            : View env info")
    pstring("*<Command>      : Run external command")
    .byte 0

//---------------------------------------------------------------
// env : view env info : clipboard, sh%, sh$
//---------------------------------------------------------------

do_env:
{
    .label OPT_D=1
    .label OPT_P=2

    lda nb_params
    beq no_params
    
    sec
    swi param_init,buffer,options_env


    //-----------------------------------------------------------
    // -P = read and store BIN PATH
    //-----------------------------------------------------------
    lda options_params
    and #OPT_P
    beq no_path
    
    sec
    swi param_process,work_buffer
    mov r1,#bin_path
    swi str_cpy
    
    //-----------------------------------------------------------
    // -D = read and store BIN DEVICE
    //-----------------------------------------------------------
no_path:
    lda options_params
    and #OPT_D
    beq no_params
    
    sec
    swi param_process,work_buffer
    swi str2int
    lda zr1l
    sta bin_device
    
no_params:
    swi pprint,msg_clipboard
    lda k_flag
    and #K_FLAG_CLIPBOARD
    beq no_clipboard
    
    jsr paste_buffer
    jsr carriage_return
    jmp env_sh_string

no_clipboard:
    swi pprint_nl,msg_none

env_sh_string:
    swi pprint,msg_sh_string    
    sec
    swi get_basic_string, sh_string
    cpx #0
    beq empty_sh_string
    ldy #0
print_sh_string:
    mov a,(r0++)
    jsr CHROUT
    dex
    bne print_sh_string
    jsr carriage_return

    jmp end

empty_sh_string:
    swi pprint_nl,msg_none
    
end:
    swi pprint,msg_sh_int
    swi get_basic_int,var_int_sh_desc
    ldx #%10011111
    swi pprint_int
    jsr carriage_return
    
    swi pprint,msg_device
    lda CURRDEVICE
    bne is_value_device
    swi pprint_nl,msg_none
    jmp next_bin_device

is_value_device:
    jsr print_int8

next_bin_device:
    swi pprint,msg_bin
    swi pprint,msg_device
    mov r0,#bin_device
    jsr bios.bios_ram_get_byte
    cmp #0
    bne is_value_bin_device
    swi pprint_nl,msg_none
    jmp next_bin_path
    
is_value_bin_device:
    jsr print_int8

next_bin_path:
    swi pprint,msg_bin
    swi pprint,msg_path
    mov r0,#bin_path
    jsr bios.bios_ram_get_byte
    cmp #0
    beq no_path_data
    tax
    iny
boucle_path:
    jsr bios.bios_ram_get_byte
    jsr CHROUT
    iny
    dex
    bne boucle_path
    ldy #0
    beq carriage_return

no_path_data:
    swi pprint,msg_none
carriage_return:
    lda #13
    jsr CHROUT
    sec
    rts
    
print_int8:
    ldy #0
    sty zr0h
    sta zr0l
    ldx #%10011111
    swi pprint_int
    jmp carriage_return

options_env:
    pstring("DP")
sh_string:
    .text "SH$"
    .byte 0
msg_clipboard:
    pstring("Clipboard : ")
msg_sh_string:
    pstring("SH$ : ")
msg_sh_int:
    pstring("SH% : ")
msg_bin:
    pstring("BIN ")
msg_path:
    pstring("Path : ")
msg_device:
    pstring("Device : ")
msg_none:
    pstring("(None)")
var_int_sh_desc:
    .text "SH%"
    .byte 0
}

//---------------------------------------------------------------
// help : internal help command
//---------------------------------------------------------------

do_help:
{
    lda nb_params
    beq help_help

    mov r0, #buffer
    swi str_next

lookup:
    mov r1, r0
    mov r0, #internal_commands
    
    swi lines_find
    bcc help_help
    mov r0, #internal_commands_help
    swi lines_goto
    swi pprint_nl
    sec
    rts
    
help_help:    
    swi pprint_lines,internal_commands_help
    sec
    rts
}

//---------------------------------------------------------------
// memory : memory dump
// parameters : 1st = start address (hex)
// 2nd if present = end address, else prints 8 bytes 
// of memory max
//---------------------------------------------------------------

do_memory:
{
    lda #8
    sta bytes
    lda nb_params
    bne ok_params
    mov r0, #buffer
    jmp do_help.lookup
    
ok_params:
    cmp #1
    beq juste_8
    mov r0, #buffer
    swi str_next
    push r0

    swi str_next
    mov a,(r0)
    cmp #2
    jeq not_address

    swi hex2int
    mov stop_address, r0
    pop r0
    swi hex2int
    jmp boucle_hex
    
juste_8:
    mov r0, #buffer
    swi str_next
    swi hex2int
    push r0
    add r0, #8
    mov stop_address, r0
    pop r0

boucle_hex:
    lda #'*'
    jsr CHROUT
    lda #'M'
    jsr CHROUT
    lda #' '
    jsr CHROUT
    mov r1, r0
    ldx #0

prep_buffer:
    mov a, (r0++)
    sta bytes+1,x
    inx
    cpx #8
    bne prep_buffer
    push r0
    mov r0, #bytes
    swi pprint_hex_buffer
    pop r0

    // check run/stop
    jsr STOP
    beq fin_hex

    // il en reste ?
    lda zr0h
    cmp stop_address+1
    bcc boucle_hex
    lda zr0l
    cmp stop_address
    bcc boucle_hex

fin_hex:
    lda #13
    jsr CHROUT
    sec
    rts

not_address:
    pop r0
    lda #8
    sta nb_bytes

    mov r0, #buffer
    swi str_next

    mov r1,r0
    swi hex2int
    mov r2,r0

    mov r0, r1
    swi str_next
    mov r1,r0

boucle_write:
    inc r0
    jsr bios.do_hex2int.conv_hex_byte
    mov (r2++),a

    mov r0,r1
    swi str_next
    bcs fini
    
    dec nb_bytes
    beq fini

    mov r1,r0
    jmp boucle_write

fini:
    jmp fin_hex

.label stop_address = vars
.label nb_bytes = vars+1
.label bytes = vars+2

}

//---------------------------------------------------------------
// irq_hook : check for specific key presses
//---------------------------------------------------------------

irq_hook:
{
    jsr $ffea
    lda $cc
    bne lbl_ea61
    dec $cd
    bne lbl_ea61
    lda #$14
    sta $cd
    ldy $d3
    lsr $cf
    ldx $0287
    lda ($d1),y
    bcs lbl_ea5c
    inc $cf
    sta $ce
    jsr $ea24
    lda ($f3),y
    sta $0287
    ldx $0286
    lda $ce
lbl_ea5c:
    eor #$80
    jsr $ea1c
lbl_ea61:
    // removed K7 sense
    
    // scan keyboard
    jsr $ea87


    lda KEYPRESS
    cmp #64
    beq end_irq
    cmp #$25
    beq ctrl_k

    lda k_flag
    and #255-K_FLAG_CLIPBOARD
    bne special_keys

end_irq:
    jmp $ea7e
    
ctrl_k:
    lda SHFLAG
    cmp #4
    bne end_irq

    lda #64
    sta KEYPRESS

    lda k_flag
    bmi end_irq
    
    lda k_flag
    and #K_FLAG_CLIPBOARD
    ora #K_FLAG_ON
    ora CURSOR_COLOR
    sta k_flag

    lda #5
    sta CURSOR_COLOR
    jmp end_irq

special_keys:
    lda k_flag
    and #$0f
    sta CURSOR_COLOR
    lda k_flag
    and #K_FLAG_CLIPBOARD
    sta k_flag
    dec NDX
    lda KEYPRESS
    
    cmp #$0a
    bne not_a

    //-----------------------------------
    // A = goto start of logical line
    //-----------------------------------

    swi cursor_unblink
    ldx PNTR
go_back:
    lda #LEFT
    jsr CHROUT
    dex
    bne go_back
    jmp end_irq

not_a:
    //-----------------------------------
    // E = goto end of logical line
    //-----------------------------------

    cmp #$0e
    bne not_e
    
    jsr goto_end_of_line
    jmp end_irq

    //-----------------------------------
    // C = copy buffer to $a000
    //-----------------------------------
    
not_e:
    cmp #$14
    bne not_c
    
    lda k_flag
    ora #K_FLAG_CLIPBOARD
    sta k_flag

    ldx PNTR
    stx clipboard
    ldy #0
copie:
    lda (PNT),y
    iny
    sta clipboard,y
    dey
    iny
    dex
    bne copie
    jmp end_irq

    //-----------------------------------
    // V = paste buffer from $a000
    //-----------------------------------
    
not_c:
    cmp #$1f
    bne not_v
    
    swi cursor_unblink
    jsr paste_buffer
    jmp end_irq

    //-----------------------------------
    // BACKSPACE = delete to end of line
    //-----------------------------------
    
not_v:
    cmp #0
    bne not_delete

    lda PNTR
    pha
    jsr goto_end_of_line
    pla
    sta ztmp
    txa
    sec
    sbc ztmp
    tay
supp_end:
    lda #BACKSPACE
    jsr CHROUT
    dey
    bne supp_end
    
    jmp end_irq

not_delete:

    //-----------------------------------
    // D = copy whole current line
    //-----------------------------------
    
    cmp #$12
    bne not_d
    
    lda k_flag
    ora #K_FLAG_CLIPBOARD
    sta k_flag

    swi cursor_unblink

    ldy LNMX
find_end:
    lda (PNT),y
    cmp #32
    bne found_end
    dey
    bpl find_end
    lda #0
    sta clipboard
    jmp end_irq

found_end:
    iny
    sty clipboard
    sty ztmp
    ldx #1
    ldy #0
copy_line:
    lda (PNT),y
    sta clipboard,x
    inx
    iny
    cpy ztmp
    bne copy_line
    
not_d:
end:
    jmp end_irq

}

//------------------------------------------------------------
// paste_buffer : paste buffer content
//------------------------------------------------------------

paste_buffer:
{
    ldy #0
    lda #<clipboard
    sta zr0l
    lda #>clipboard
    sta zr0h
    jsr bios.bios_ram_get_byte
    tax
    ldy #1
paste:
    jsr bios.bios_ram_get_byte
    jsr bios.screen_to_petscii
    jsr CHROUT
    iny
    dex
    bne paste
    rts
}

//------------------------------------------------------------
// goto_end_of_line : from the cursor position, move to the
// end of logical line, move left if past end of line
// X = end of line
//------------------------------------------------------------

goto_end_of_line:
{
    swi cursor_unblink
    ldy LNMX
find_end_e:
    lda (PNT),y
    cmp #32
    bne found_end_e
    dey
    bpl find_end_e

found_end_e:
    iny
    tya
    tax
    sec
    sbc PNTR
    tay
    bmi goto_left
go_forward:
    lda #RIGHT
    jsr CHROUT
    dey
    bne go_forward
    rts
goto_left:
    lda #LEFT
    jsr CHROUT
    iny
    bne goto_left
    rts
}

//------------------------------------------------------------
// basic_ieval : IEVAL hook for hex numbers
//------------------------------------------------------------

basic_ieval:
{
    lda #0
    sta $0d
    jsr CHRGET
    cmp #'$'
    beq test_dollar
not_ok_dollar:
    jsr CHRGOT
    jmp $ae8d
test_dollar:
    lda PNTR
    bne not_ok_dollar
process_dollar:
    ldx #2
    ldy #3
    lda ($7a),y
    cmp #$30
    bcc not_num
    cmp #$3a
    bcc not_num2
    cmp #$41
    bcc not_num
    cmp #$47
    bcc not_num2
not_num:
    lda #0
    pha
    dex
not_num2:
    jsr CHRGET
    cmp #$40
    bcc not_alpha
    adc #8
not_alpha:
    asl
    asl
    asl
    asl
    sta $fe
    jsr CHRGET
    bcc not_alpha2
    adc #8
not_alpha2:
    and #15
    ora $fe
    pha
    dex
    bne not_num2
    pla
    sta $63
    pla
    sta $62
    ldx #$90
    sec
    jsr $bc49
    jmp CHRGET
    
}

shell_top:
.fill $a000-*, $00
