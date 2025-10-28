//===============================================================
// BYG SHELL : Command line Shell
//
// 2024-2025 Babygang
//===============================================================


#import "kernal.asm"
#import "macros.asm"


* = $8000

.word start_cartridge   // cold start vector
.word start_cartridge   // warm start vector
.byte $c3,$c2,$cd
.text "80"

#import "bios_pp.asm"

.label work_buffer=$cf00

start_cartridge:

    stx $d016
    jsr reset_c64
    jsr $e3bf // sys init ram
    jsr $e422 // start message
    
    // change basic IGONE hook to our routine
    
    lda #<basic_hook
    sta IGONE
    lda #>basic_hook
    sta IGONE+1
    

    // change basic IEVAL to our routine for $

    lda #<basic_ieval
    sta IEVAL
    lda #>basic_ieval
    sta IEVAL+1
    
    // BIOS reset and start message
    
    jsr bios.do_reset
    lda #23
    sta $d018
    swi theme_accent
    swi pprint_nl,start_message
    swi theme_normal
    
    // change IRQ hook to our routine

    sei
    lda #0
    sta k_flag
    lda #<irq_hook
    sta IIRQ
    lda #>irq_hook
    sta IIRQ+1
    lda #%01111111
    sta $dc0d
    and $d011
    sta $d011
    sta $dc0d
    sta $dd0d
    lda #1
    sta $d01a
    lda #255
    sta $d012
    cli
    
    lda #<brk_hook
    sta CBINV
    lda #>brk_hook
    sta CBINV+1
    
    ldx #32
copy_hook:
    lda brk_hook,x
    sta brk_hook,x
    dex
    bpl copy_hook
    
    jmp READY

brk_hook:
    tsx
    lda $0105,x
    sec
    sbc #1
    sta zr0l
    lda $0106,x
    sbc #0
    sta zr0h
    lda #$37
    sta $01
    clc
    swi pprint_hex
    swi screen_pause
    jmp READY

start_message:
    .byte 16
    .byte $0d
    .encoding "petscii_mixed"
    .text "*BYG-Shell v"
    .encoding "ascii"
    .byte bios.VERSION_MAJ+$30
    .byte '.'
    .byte bios.VERSION_MIN+$30

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
    cmp #$b1
    bne not_supp
    
    ldy #1
    lda ($7a),y
    cmp #32
    beq ok_space
    cmp #$b1
    beq ok_space

    lda #'>'
    sta buffer,x
    inx
    lda #32
    bne copy_command
    
ok_space:
    lda #'>'
    bne copy_command

not_supp:
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

normal_char:
    clc
    ldy #3
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
    .byte 172,170,171,$b1
new_char:
    .text "*+->"
}

//---------------------------------------------------------------
// history_add : add command to history list
//---------------------------------------------------------------

history_add:
{
    jmp history.insert
}

//---------------------------------------------------------------
// exec_command : load external command to $c000
//---------------------------------------------------------------

exec_command:
{
    lda #MSG_NONE
    jsr SETMSG
    
    jsr history_add
    jsr prep_params
    
    jsr cache_check
    jcs already_loaded


    jsr internal_command_check
    jcs no_run

    
    //-----------------------------------------------------------
    // Find device for command :
    // check presence of value for BIN DEVICE
    // if not is there a currdevice ? if not try on device 8
    //-----------------------------------------------------------

    jsr currdevice.save
    jsr get_bin_device
    stx CURRDEVICE
    lda #1
    tay
    jsr SETLFS

    //-----------------------------------------------------------
    // Command name : check if we need to add path from 
    // BIN PATH
    //-----------------------------------------------------------

    mov r0,#buffer
    jsr get_bin_name
    
    lda work_buffer
    ldx #<work_buffer+1
    ldy #>work_buffer+1
    jsr SETNAM

    lda #0
    jsr LOAD
    bcs load_error
    
    // restore previous device or set to 8 if it was 0
    jsr currdevice.restore
    
    cpy #$a0
    bcc no_run

    jsr cache_check

already_loaded:
    jsr start_command

no_run:
    lda #MSG_ALL
    jmp SETMSG

load_error:
    jsr currdevice.restore
    ldx #4
    jmp ERRORX

start_command:
    cpx #$c0
    bne not_found
    jmp ($c000)

suffix_prg:
    pstring(",p")

cache_check:
    ldx #$c0
    mov r0,#buffer
    mov r1,#$c002
    swi str_cmp
    bcs found
    ldx #$a0
not_found:
    clc
    rts

found:
    sec
    rts
}

//---------------------------------------------------------------
// currdevice : save / restore
//---------------------------------------------------------------

currdevice:
{
save:
    lda CURRDEVICE
    sta save_currdevice
    rts

restore:
    lda save_currdevice
    bne not_zero_device
    lda #8
not_zero_device:
    sta CURRDEVICE
    rts
}

//---------------------------------------------------------------
// get_bin_name : check if we need to add path from BIN PATH to
// name in buffer, return result in R0 in work_buffer
//---------------------------------------------------------------

get_bin_name:
{
    push r0
    ldy #0
    mov r0,#bin_path
    jsr bios.bios_ram_get_byte
    beq no_bin_path

    // copy path prefix to work_buffer
    tax
    mov r1,#work_buffer
copy_path_prefix:
    jsr bios.bios_ram_get_byte
    mov (r1),a
    iny
    dex
    bpl copy_path_prefix

no_bin_path:
    // and add filename from buffer
    ldy #0
    pop r1
    swi str_cat,work_buffer
    mov r0,#work_buffer
    rts
}

//---------------------------------------------------------------
// get_bin_device : find device to use, check presence of 
// value for BIN DEVICE if not is there a currdevice ? 
// if not try on device 8
//
// return device to use in X
//---------------------------------------------------------------

get_bin_device:
{
    ldy #0
    mov r0,#bin_device
    jsr bios.bios_ram_get_byte
    cmp #0
    beq no_bin_device
    tax
    rts
    
no_bin_device:    
    ldx CURRDEVICE
    bne device_ok
    ldx #8
device_ok:
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
    lda nb_params
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
    pstring("help")
    pstring("m")
    pstring("env")
    pstring("kill")
    pstring("run")
    .byte 0

internal_commands_jump:
    .word do_help
    .word do_memory
    .word do_env
    .word do_kill
    .word do_run

internal_commands_help:
    pstring("*help <cmd>")

//---------------------------------------------------------------
// kill/run : kill cartridge, reset
//---------------------------------------------------------------

reset_c64:
{
    jsr $fda3   // prepare IRQ
    jsr $fd50   // init memory
    jsr $fd15   // init I/O
    jsr $ff5b   // init video
    cli

    jmp $e453 // sys init basic vectors
}

do_run:
{
    lda $0805
    cmp #$9e
    bne do_kill.not_sys
    
    mov $7a,#$0806
    jsr $ad8a
    jsr $b7f7

    mov $0805,$14
    mov $0807,$2d

    sei
    jsr $fda3
    jsr $fd50
    jsr $fd15
    jsr $ff5b
    jsr reset_c64
    mov r0,$0805
    mov $2d,$0807
    sec
}
do_kill:
{
    bcs run
not_sys:
    mov r0,#$fce2
run:
    mov $02e5,r0
    ldx #4
copy:
    lda kill_routine,x
    sta $02e0,x
    dex
    bpl copy
    jmp $02e0
kill_routine:
    sei
    stx $de00
    .byte $4c
}

//---------------------------------------------------------------
// env : set env info
// 
// bin device, bin path
//---------------------------------------------------------------

do_env:
{
    .label OPT_D=1
    .label OPT_P=2
    .label OPT_U=4

    sec
    swi param_init,buffer,options_env

    lax options_params
    and #OPT_P+OPT_D
    beq done
    txa
    and #OPT_U
    bne handle_unset

    sec
    swi param_process,work_buffer
    ldy #0
    
    lda options_params
    and #OPT_P
    beq handle_device

    //-----------------------------------------------------------
    // -P = read and store BIN PATH, convert ; to :
    //-----------------------------------------------------------

    mov a,(r0)
    tay
    mov a,(r0)
    cmp #';'
    bne no_conv
    lda #':'
    mov (r0),a
no_conv:
    mov r1,#bin_path
    swi str_cpy

done:
    sec
    rts

    //-----------------------------------------------------------
    // -D = read and store BIN DEVICE
    //-----------------------------------------------------------
handle_device:
    swi str2int
    lda zr1l
    sta bin_device
    sec
    rts

    //-----------------------------------------------------------
    // -U = unset value
    //-----------------------------------------------------------

handle_unset:
    ldy #0
    lax options_params
    and #OPT_P
    beq unset_device
    sty bin_path
    txa
    and #OPT_D
    beq done
unset_device:
    sty bin_device
    sec
    rts

carriage_return:
    lda #13
    jmp CHROUT

options_env:
    pstring("dpu")
}

//---------------------------------------------------------------
// help : internal help command
//---------------------------------------------------------------

do_help:
{
.label nb_lines = zr1l

    lda nb_params
    bne help_with_file

help_help:
    swi pprint_nl,internal_commands_help
    sec
    rts

help_with_file:
    jsr currdevice.save
    mov r0, #buffer
    swi str_next

    jsr get_bin_name
    
    mov r1,#suffix_help
    swi str_cat
    
    push r0
    jsr get_bin_device
    stx CURRDEVICE
    pop r0
    clc
    ldx #4
    swi file_open
    bcs not_found

    jsr help_init
help_file:
    jsr CHRIN
    cmp #$0a
    bne do_color
    jsr do_env.carriage_return
    jmp help_continue
do_color:
    jsr change_color
    swi file_readline, work_buffer
    bcs help_end
    ldx #bios.do_str_conv.ASCII_TO_PETSCII
    swi str_conv
    swi pprint_nl, work_buffer
help_continue:
    dec nb_lines
    bne help_file
    swi screen_pause
    bcs help_end
    jsr help_init
    bne help_file

help_init:
    ldx #4
    jsr CHKIN
    lda #23
    sta nb_lines
    rts
    
help_end:
    swi theme_normal
    ldx #4
    swi file_close
    jsr currdevice.restore

help_return:
    sec
    rts
not_found:
    sec
    mov r1,#$fffe
    swi error,error_help
    rts
    
lookup:
    mov r1, r0
    mov r0, #internal_commands
    
    swi lines_find
    jcc help_help
    mov r0, #internal_commands_help
    swi lines_goto
    swi pprint_nl
    sec
    rts

change_color:
    ldx #5
test_color:
    cmp color_chars,x
    beq color_ok
    dex
    bpl test_color
    jmp CHROUT
color_ok:
    inx
    inx
    jmp bios.do_theme.set_color

suffix_help:
    pstring(".hlp")
error_help:
    pstring("Not found")

color_chars:
    .text "_:#-*="
}

//---------------------------------------------------------------
// memory : memory dump
// parameters : 1st = start address (hex)
// 2nd if present = end address, else prints 8 bytes 
// of memory max
// View RAM under BASIC
//---------------------------------------------------------------

do_memory:
{
    lda #8
    sta bytes
    lda nb_params
    bne ok_params

    sec
    rts
    
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
    .encoding "petscii_mixed"
    lda #'m'
    .encoding "ascii"
    jsr CHROUT
    lda #' '
    jsr CHROUT
    mov r1, r0
    ldy #7
prep_buffer:
    jsr bios.bios_ram_get_byte
    sta bytes+1,y
    dey
    bpl prep_buffer
    iny
    add r0,#8
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
    jsr do_env.carriage_return
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

do_irq_sub:
    jmp (irq_sub)

irq_hook:
{
    lda irq_sub+1
    beq no_sub

stop:
    inc $d020
    jsr do_irq_sub
    dec $d020

no_sub:

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
    asl $d019
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
    
    ldx #ctrl_keys_hi-ctrl_keys
    lda KEYPRESS
lookup_kkey:
    cmp ctrl_keys,x
    beq key_found
    dex
    bpl lookup_kkey
    bmi end_irq
key_found:
    jsr goto_key
    jmp end_irq

goto_key:
    lda ctrl_keys_hi,x
    pha
    lda ctrl_keys_lo,x
    pha 
    swi cursor_unblink
    rts

ctrl_keys:
    .byte $0a   // A
    .byte $0e   // E
    .byte 42    // L
    .byte $1f   // V
    .byte $00   // Backspace
    .byte $14   // C
    .byte $33   // Home
    .byte 13    // S
    .byte $11   // R
    .byte $1c   // B
ctrl_keys_hi:
    .byte >do_key_a-1
    .byte >do_key_e-1
    .byte >do_key_c-1
    .byte >do_key_v-1
    .byte >do_key_backspace-1
    .byte >do_key_d-1
    .byte >do_key_home-1
    .byte >do_key_up_arrow-1
    .byte >do_key_r-1
    .byte >do_delete_to_start-1
ctrl_keys_lo:
    .byte <do_key_a-1
    .byte <do_key_e-1
    .byte <do_key_c-1
    .byte <do_key_v-1
    .byte <do_key_backspace-1
    .byte <do_key_d-1
    .byte <do_key_home-1
    .byte <do_key_up_arrow-1
    .byte <do_key_r-1
    .byte <do_delete_to_start-1

    //-----------------------------------
    // A = goto start of logical line
    //-----------------------------------

do_key_a:
    ldx PNTR
go_back:
    lda #LEFT
    jsr CHROUT
    dex
    bne go_back
    rts

    //-----------------------------------
    // E = goto end of logical line
    //     jmp goto_end_of_line
    //-----------------------------------

    //-----------------------------------
    // C = copy buffer to $a000
    //-----------------------------------

do_key_c:    
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
    dex
    bne copie
    rts

    //-----------------------------------
    // V = paste buffer from $a000
    // jmp paste_buffer
    // R = paste buffer from $a100
    //-----------------------------------
    
    //-----------------------------------
    // BACKSPACE = delete to end of line
    //-----------------------------------
    
do_key_backspace:
    lda PNTR
    pha
    jsr goto_end_of_line
    pla
    sta ztmp
    txa
    sec
    sbc ztmp
    tay
del_y:
    jmp bios.backspace_y

    //-----------------------------------
    // delete to start of line
    //-----------------------------------

do_delete_to_start:
    ldy PNTR
    bne del_y
    rts

    //-----------------------------------
    // D = copy whole current line
    //-----------------------------------

do_key_d:    
    lda k_flag
    ora #K_FLAG_CLIPBOARD
    sta k_flag

    ldy LNMX
find_end:
    lda (PNT),y
    cmp #32
    bne found_end
    dey
    bpl find_end
    lda #0
    sta clipboard
    rts

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
    rts
    
    //-----------------------------------
    // HOME = clear screen except current 
    // line
    //-----------------------------------

do_key_home:
    mov r0,#$0400
    clc
    jmp bios.do_screen_clear

    //-----------------------------------
    // UP-ARROW = swap screens
    //-----------------------------------

do_key_up_arrow:
    ldx #25
    mov r0,#swap_screen
    mov r1,#$0400
    mov r2,#$d800
swap_line:
    ldy #39
swap_char:
    jsr bios.bios_ram_get_byte
    sei
    sta ztmp
    mov a,(r1)
    mov (r0),a
    lda ztmp
    mov (r1),a
    lda #1
    mov (r2),a
    dey
    bpl swap_char
    add r0,#40
    add r1,#40
    add r2,#40
    dex
    bne swap_line
end:
    rts
}

//------------------------------------------------------------
// paste_buffer : paste buffer content
//------------------------------------------------------------

.label do_key_r = history.get

do_key_v:
paste_buffer:
{
    mov r0,#clipboard
    sec
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

//------------------------------------------------------------
// goto_end_of_line : from the cursor position, move to the
// end of logical line, move left if past end of line
// X = end of line
//------------------------------------------------------------

do_key_e:
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
// history : history of commands
//
// history buffer : 
//
// Byte 0 : total number of commands in history
// Byte 1 : value for history walk through (total to 
//      0 and loop)
// Byte 2 and + : last commands, 1 pstring for each
//------------------------------------------------------------

history:
{
.label max_history=15

    //--------------------------------------------------------
    // goto : goto pstring at position X, returns address in
    // R0, moves using pstring lengths in 1st byte
    //--------------------------------------------------------

goto:
    ldy #0
    mov r0,#history_buffer+2
    cpx #0
    beq found
do_goto:
    jsr bios.bios_ram_get_byte
    // add length + 1
    sec
    adc zr0l
    sta zr0l
    bcc no_inc
    inc zr0h
no_inc:
    dex
    bne do_goto
found:
    rts

    //--------------------------------------------------------
    // insert : add command pstring at buffer to history, if
    // max_history is reached then older record is removed
    //--------------------------------------------------------

insert:
    // read number of entries
    mov r0,#history_buffer
    ldy #0
    jsr bios.bios_ram_get_byte
    tax
    stx ztmp
    cmp #max_history
    beq hist_max
    
    // if not max, increment and store
    
store_value:
    // increment number of commands in history

    ldx ztmp
    inx
    stx history_buffer
    stx history_buffer+1

    // copy value in buffer to history entry

only_store:
    dex
    jsr goto
    
    mov r1,r0
    swi str_cpy,#buffer
    rts
    
    // max reached, move oldest entry out
    // r0 = read, r1 = write, r2 = length

hist_max:
    jsr goto
    sub r0,#history_buffer+2
    mov r2,r0
    ldx #1
    jsr goto
    mov r1,#history_buffer+2
move_data:
    jsr bios.bios_ram_get_byte
    mov (r1++),a
    inc r0
    dec r2
    bne move_data
    
    // store entry at last position = max - 1
    // without incrementing number of entries

    ldx #max_history
    jmp only_store


    //--------------------------------------------------------
    // get : retrieve and print one history entry
    //--------------------------------------------------------

get:
    jsr irq_hook.do_delete_to_start
    iny // y=1, was 0 with delete_to_start
    mov r0,#history_buffer
    jsr bios.bios_ram_get_byte
    tax
    beq no_history
    dex
    stx history_buffer+1
    jsr history.goto
    lda #'*'
    jsr CHROUT
    clc
    jmp pprint_ram
no_history:
    dey
    jsr bios.bios_ram_get_byte
    sta history_buffer+1
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
