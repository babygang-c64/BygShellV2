//----------------------------------------------------
// sid : play sid files
//
// options : 
// I = Info
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word sid
pstring("sid")

sid:
{
    .label buffer1 = $ce00
    .label buffer2 = $cc00
    .label params_buffer = $cd00
    
    .label OPT_I=1
    .label OPT_P=2
    .label OPT_S=4

    sec
    swi param_init,buffer,options_sid
    jcs error

    lda options_params
    and #OPT_S
    beq no_stop

    sei
    lda #0
    sta $d418
    sta bios.irq_sub+1
    cli
    clc
    rts
    
no_stop:
    ldx nb_params
    jeq help

    swi pipe_init
    jcs error


    ldy #0
    sec
    swi param_process,params_buffer
    
    clc
    ldx #3
    swi file_open
    jcs error_not_found
    
    jsr sid_get_info
    jcs error_sid
    
    lda options_params
    and #OPT_I
    beq no_info
    
    jsr sid_print_info
    
no_info:
    jsr fin_params
    
    lda options_params
    and #OPT_P
    beq not_play
    
    jsr get_load_address
    
    // adjust load address
    mov r0,load_address
    lda buffer1+VERSION
    cmp #2
    bne not_v2b
    sub r0,#$7c
    jmp was_v2
not_v2b:
    sub r0,#$76
was_v2:
    mov load_address,r0 

    ldy #0
    sec
    swi param_process,params_buffer

    sec
    mov r1, load_address
    swi file_load

    lda #0
    jsr init_sid
    
    sei
    mov bios.irq_sub,play_address
    cli

not_play:
    clc
    rts


fin_params:
    ldx #3
    swi file_close
    swi pipe_end
    clc
    rts

error_not_found:
    clc
    mov r0,#error_not_found_msg
    bcc error
error_sid:
    clc
    mov r0,#error_msg

error:
    jsr fin_params
    swi error
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

error_not_found_msg:
    pstring("File not found")

error_msg:
    pstring("Not a PSID file")

help_msg:
    pstring("*sid <file> [-i]")
    pstring(" i = Show SID file info")
    pstring(" p = Play SID")
    pstring(" s = Stop")
    .byte 0

options_sid:
    pstring("ips")

sid_get_info:
{
    ldx #3
    clc
    lda #128
    sta buffer1
    swi buffer_read, buffer1

    ldx #3
test_sid:
    lda buffer1+1,x
    cmp psid_id,x
    bne sid_ko
    dex
    bpl test_sid
    
    clc
    rts

sid_ko:
    sec
    rts

psid_id:
    .text "PSID"
    
}

get_load_address:
{
    lda buffer1+LOAD_ADDRESS
    sta zr0h
    lda buffer1+LOAD_ADDRESS+1
    sta zr0l
    
    lda zr0h
    bne not_zero
    lda zr0l
    bne not_zero
    
    lda buffer1+VERSION
    cmp #2
    bne not_v2
    
    mov r0,buffer1+DATA_START_V2
    jmp not_zero
    
not_v2:
    mov r0,buffer1+DATA_START

not_zero:
    mov load_address,r0
    
    lda buffer1+INIT_ADDRESS
    sta init_address+1
    lda buffer1+INIT_ADDRESS+1
    sta init_address

    lda buffer1+PLAY_ADDRESS
    sta play_address+1
    lda buffer1+PLAY_ADDRESS+1
    sta play_address

    rts    
}

sid_print_info:
{
    swi pprint, msg_name
    ldx #NAME
    jsr print_32max

    swi pprint, msg_author
    ldx #AUTHOR
    jsr print_32max

    swi pprint, msg_release
    ldx #RELEASED
    jsr print_32max
    lda #13
    jsr CHROUT

    swi pprint, msg_psid_version
    lda buffer1+VERSION
    clc
    adc #'0'
    jsr CHROUT
    lda #13
    jsr CHROUT

    swi pprint, msg_load
    jsr get_load_address

    clc
    swi pprint_hex
    lda #13
    jsr CHROUT

    swi pprint, msg_start
    lda buffer1+INIT_ADDRESS
    sta zr0h
    lda buffer1+INIT_ADDRESS+1
    sta zr0l
    clc
    swi pprint_hex
    lda #13
    jsr CHROUT

    swi pprint, msg_play
    lda buffer1+PLAY_ADDRESS
    sta zr0h
    lda buffer1+PLAY_ADDRESS+1
    sta zr0l
    clc
    swi pprint_hex
    lda #13
    jsr CHROUT

    swi pprint,msg_song
    lda buffer1+START_SONG
    sta zr0h
    lda buffer1+START_SONG+1
    sta zr0l
    ldx #%10000111
    swi pprint_int
    lda #'/'
    jsr CHROUT
    lda buffer1+SONGS
    sta zr0h
    lda buffer1+SONGS+1
    sta zr0l
    ldx #%10000111
    swi pprint_int
    lda #13
    jsr CHROUT

    rts

print_32max:
    lda #0
    sta buffer2
    ldy #1
copy:
    lda buffer1,x
    sta buffer2,y
    beq print_end
    inc buffer2
    inx
    iny
    cpy #33
    bne copy
print_end:
    ldx #bios.ASCII_TO_PETSCII
    swi str_conv,buffer2
    swi pprint_nl,buffer2
    rts

msg_psid_version:
    pstring("PSID v")
msg_name:
    pstring("Name  :")
msg_author:
    pstring("Author:")
msg_release:
    pstring("Rel.  :")
msg_load:
    pstring("Load  :")
msg_start:
    pstring("Init  :")
msg_play:
    pstring("Play  :")
msg_song:
    pstring("Song  :")

}

// offsets + 1 of info inside PSID structure

.label VERSION = 6
.label DATA_OFFSET = 7
.label LOAD_ADDRESS = 9
.label INIT_ADDRESS = $0b
.label PLAY_ADDRESS = $0d
.label SONGS = $0f
.label START_SONG = $11
.label NAME = $17       // 32 chars max
.label AUTHOR = $37     // 32 chars max
.label RELEASED = $57   // 32 chars max
.label DATA_START = $77
.label DATA_START_V2 = $7d

load_address:
    .word 0
    
init_sid:
    jmp init_address:$fce2
play_sid:
    jmp play_address:$fce2
}
