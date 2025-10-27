//----------------------------------------------------
// checksum : calculates checksums on files
//
// options : 
// Q = Quiet mode
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word checksum
pstring("checksum")

checksum:
{
    .label buffer1 = $cc00
    .label filename = $ce00
    .label params_buffer = $cd00
    
    .label OPT_Q=1
    .label OPT_T=2
    .label OPT_V=4
    .label OPT_C=8

    sec
    swi param_init,buffer,options_checksum
    jcs error_params
    
    ldx nb_params
    jeq help

    swi pipe_init
    jcs error_params

    ldx #'V'
    swi param_get_value
    bcc not_v

not_v:
    jsr initCRC_total
    mov do_checksum.nb_bytes_total,#0

    // parameters loop
    ldy #0
    sec
boucle_params:
    swi param_process,params_buffer
    bcs end

    mov r1,#filename
    swi str_cpy
    jsr do_checksum
    
    clc
    jmp boucle_params

end:
    lax options_params
    and #OPT_T
    beq not_total
    txa
    and #OPT_Q
    bne not_total

    swi pipe_output
    
    mov r0,crc_total_value
    jsr do_checksum.print_crc

    lda #32
    jsr CHROUT

    mov r0,do_checksum.nb_bytes_total
    ldx #%10011111
    swi pprint_int
    swi pprint,do_checksum.msg_bytes
    
    swi pprint_nl,msg_total

not_total:
    swi pipe_end
    mov r0,crc_value
    swi return_int
    clc
    rts

error_params:
    mov r0,#msg_error_params
    mov r1,#$fffd
    bvc error
error_file_not_found:
    mov r0,#msg_error_file_not_found
    mov r1,#$fffc
    bvc error
error:
    sec
    swi error
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

help_msg:
    pstring("*checksum <files...> [options]")
    pstring(" q = Quiet mode")
    pstring(" t = Total checksum")
    pstring(" v = Compare to value")
    pstring(" c = Compare to CRC file")
    .byte 0

msg_error_params:
    pstring("Parameters")
msg_error_file_not_found:
    pstring("File not found")
msg_total:
    pstring("--TOTAL--")
options_checksum:
    pstring("qtvc")
    
do_checksum:
{
    mov nb_bytes,#0
    ldx #4
    clc
    swi file_open
    jcs checksum_file_not_found

    jsr initCRC
    
    lda #200
    sta buffer1

process:
    clc
    ldx #4
    swi buffer_read,buffer1
    bcs end_process
    jsr do_calc
    
    lda buffer1
    add nb_bytes,a
    lda buffer1
    add nb_bytes_total,a
    
    jmp process

do_calc:    
    ldy #0
calc:
    lda buffer1+1,y
    jsr updateCRC
    lda buffer1+1,y
    jsr updateCRC_total
    iny
    cpy buffer1
    bne calc
    rts

end_process:
    lda buffer1
    beq no_data

    jsr do_calc
    lda buffer1
    add nb_bytes,a
    lda buffer1
    add nb_bytes_total,a

no_data:
    ldy #0
    ldx #4
    swi file_close
    
    lda options_params
    and #OPT_Q
    bne pas_affichage
    swi pipe_output
    
    mov r0,crc_value
    jsr print_crc

    lda #32
    jsr CHROUT

    mov r0,nb_bytes
    ldx #%10011111
    swi pprint_int
    swi pprint,msg_bytes
    
    swi pprint_nl,filename
pas_affichage:
    clc
    rts

print_crc:
    push r0
    swi pprint,msg_crc
    pop r0
    swi pprint_hex
    rts

msg_crc:
    pstring("CRC16=")
msg_bytes:
    pstring(" Bytes ")

checksum_file_not_found:
    jmp error_file_not_found

nb_bytes:
    .word 0
nb_bytes_total:
    .word 0
}

} // checksum

//------------------------------------
// CRC16 calculation
//------------------------------------
// Input:
//   A = byte to process
//   R2 = current CRC value
// Output:
//   R2 = updated CRC
//------------------------------------

initCRC:
    mov crc_value,#$ffff
    rts

initCRC_total:
    mov crc_total_value,#$ffff
    rts

crc_value:
    .word 0
crc_total_value:
    .word 0

updateCRC:
    ldx #8
    eor crc_value+1
bitloop:
    asl crc_value
    rol
    bcc no_add
    eor #$10
    pha
    lda crc_value
    eor #$21
    sta crc_value
    pla
no_add:
    dex
    bne bitloop
    sta crc_value+1
    rts

updateCRC_total:
    ldx #8
    eor crc_total_value+1
bitloop_total:
    asl crc_total_value
    rol
    bcc no_add_total
    eor #$10
    pha
    lda crc_total_value
    eor #$21
    sta crc_total_value
    pla
no_add_total:
    dex
    bne bitloop_total
    sta crc_total_value+1
    rts
