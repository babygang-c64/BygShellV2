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

    lda #<basic_hook
    sta VECT_BASICEXEC
    lda #>basic_hook
    sta VECT_BASICEXEC+1
    
    jsr bios.do_reset
    lda #23
    sta $d018
    swi pprint,start_message
    jmp READY

start_message:
    .byte 16
    .byte $0d
    .text "*BYG SHELL V2.0"

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
    cpy #$c0
    bcc no_run

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
    jmp ($c000)
    
cache_check:
    mov r0,#buffer
    mov r1,#$c002
    swi str_cmp
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
    .byte 0

internal_commands_jump:
    .word do_help
    .word do_memory

internal_commands_help:
    pstring("*HELP (COMMAND) : HELP ON COMMANDS")
    pstring("*M <START> (END): MEM DUMP")
    pstring("*<COMMAND>      : RUN EXTERNAL COMMAND")
    .byte 0

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
    sec
    rts

.label stop_address = vars
.label nb_bytes = vars+1
.label bytes = vars+2

}
shell_top:
.fill $a000-*, $00
