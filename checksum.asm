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
pstring("CHECKSUM")

checksum:
{
    .label buffer1 = $cc00
    .label filename = $ce00
    .label params_buffer = $cd00
    
    .label OPT_Q=1

    sec
    swi param_init,buffer,options_checksum
    jcs error_params
    
    ldx nb_params
    jeq help

    swi pipe_init
    bcs error_params

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
    swi pipe_end
    lda crc_value
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
    pstring("*checksum <files...> [-q]")
    pstring(" q = Quiet mode")
    .byte 0

msg_error_params:
    pstring("Parameters")
msg_error_file_not_found:
    pstring("File not found")

options_checksum:
    pstring("Q")
    
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
    
    jmp process

do_calc:    
    ldy #0
calc:
    lda buffer1+1,y
    jsr updateCRC
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

no_data:
    ldy #0
    ldx #4
    swi file_close
    

    lda options_params
    and #OPT_Q
    bne pas_affichage
    swi pipe_output
    
    swi pprint,msg_crc
    mov r0,crc_value
    swi pprint_hex
    
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

msg_crc:
    pstring("CRC16=")
msg_bytes:
    pstring(" Bytes ")

checksum_file_not_found:
    jmp error_file_not_found

nb_bytes:
    .word 0
}

} // checksum

//------------------------------------
// CRC16 calculation (table-driven)
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

crc_value:
    .word 0

updateCRC:
    eor crc_value
    tax

    lda CRCTAB,x
    sta crc_value
    lda CRCTAB+1,x
    eor crc_value+1
    sta crc_value+1
    rts


// CRC16 lookup table (poly = $8005, reversed)
CRCTAB:
    .word $0000,$8005,$800F,$000A,$801B,$001E,$0014,$8011
    .word $8033,$0036,$003C,$8039,$0028,$802D,$8027,$0022
    .word $8073,$0076,$007C,$8079,$0068,$806D,$8067,$0062
    .word $0040,$8045,$804F,$004A,$805B,$005E,$0054,$8051
    .word $80E3,$00E6,$00EC,$80E9,$00F8,$80FD,$80F7,$00F2
    .word $00D0,$80D5,$80DF,$00DA,$80CB,$00CE,$00C4,$80C1
    .word $0080,$8085,$808F,$008A,$809B,$009E,$0094,$8091
    .word $80B3,$00B6,$00BC,$80B9,$00A8,$80AD,$80A7,$00A2
    .word $81C3,$01C6,$01CC,$81C9,$01D8,$81DD,$81D7,$01D2
    .word $01F0,$81F5,$81FF,$01FA,$81EB,$01EE,$01E4,$81E1
    .word $01A0,$81A5,$81AF,$01AA,$81BB,$01BE,$01B4,$81B1
    .word $8193,$0196,$019C,$8199,$0188,$818D,$8187,$0182
    .word $0100,$8105,$810F,$010A,$811B,$011E,$0114,$8111
    .word $8133,$0136,$013C,$8139,$0128,$812D,$8127,$0122
    .word $8173,$0176,$017C,$8179,$0168,$816D,$8167,$0162
    .word $0140,$8145,$814F,$014A,$815B,$015E,$0154,$8151
    .word $8303,$0306,$030C,$8309,$0318,$831D,$8317,$0312
    .word $0330,$8335,$833F,$033A,$832B,$032E,$0324,$8321
    .word $0360,$8365,$836F,$036A,$837B,$037E,$0374,$8371
    .word $8353,$0356,$035C,$8359,$0348,$834D,$8347,$0342
    .word $0380,$8385,$838F,$038A,$839B,$039E,$0394,$8391
    .word $83B3,$03B6,$03BC,$83B9,$03A8,$83AD,$83A7,$03A2
    .word $03E3,$83E6,$83EC,$03E9,$83F8,$03FD,$03F7,$83F2
    .word $83D0,$03D5,$03DF,$83DA,$03CB,$83CE,$83C4,$03C1
    .word $0280,$8285,$828F,$028A,$829B,$029E,$0294,$8291
    .word $82B3,$02B6,$02BC,$82B9,$02A8,$82AD,$82A7,$02A2
    .word $02E3,$82E6,$82EC,$02E9,$82F8,$02FD,$02F7,$82F2
    .word $82D0,$02D5,$02DF,$82DA,$02CB,$82CE,$82C4,$02C1
    .word $8243,$0246,$024C,$8249,$0258,$825D,$8257,$0252
    .word $0270,$8275,$827F,$027A,$826B,$026E,$0264,$8261
    .word $0220,$8225,$822F,$022A,$823B,$023E,$0234,$8231
    .word $8213,$0216,$021C,$8219,$0208,$820D,$8207,$0202
    .word $8607,$0602,$0608,$860D,$061C,$8619,$8613,$0616
    .word $0634,$8631,$863B,$063E,$862F,$062A,$0620,$8625
    .word $0664,$8661,$866B,$066E,$867F,$067A,$0670,$8675
    .word $8657,$0652,$0658,$865D,$064C,$8649,$8643,$0646
    .word $06C4,$86C1,$86CB,$06CE,$86DF,$06DA,$06D0,$86D5
    .word $86F7,$06F2,$06F8,$86FD,$06EC,$86E9,$86E3,$06E6
    .word $06A7,$86A2,$86A8,$06AD,$86BC,$06B9,$06B3,$86B6
    .word $8694,$0691,$069B,$869E,$068F,$868A,$8680,$0685
    .word $0786,$8783,$8789,$078C,$879D,$0798,$0792,$8797
    .word $87B5,$07B0,$07BA,$87BF,$07AE,$87AB,$87A1,$07A4
    .word $07E5,$87E0,$87EA,$07EF,$87FE,$07FB,$07F1,$87F4
    .word $87D6,$07D3,$07D9,$87DC,$07CD,$87C8,$87C2,$07C7
    .word $07C1,$87C4,$87CE,$07CB,$87DA,$07DF,$07D5,$87D0
    .word $87F2,$07F7,$07FD,$87F8,$07E9,$87EC,$87E6,$07E3
    .word $87A2,$07A7,$07AD,$87A8,$07B9,$87BC,$87B6,$07B3
    .word $0791,$8794,$879E,$079B,$878A,$078F,$0785,$8780