//----------------------------------------------------
// touch : create empty files
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word touch
pstring("touch")

.label params_buffer=$cd80

touch:
{
    .label work_buffer = $ce00
    .label OPT_P = 1
    .label OPT_S = 2
    .label OPT_B = 4
    .label OPT_T = 8


    //-- init options
    sec
    swi param_init,buffer,options_touch
    jcs help

    //-- no parameters = print help
    ldx nb_params
    jeq help

    ldy #0
    sec
boucle_params:
    swi param_process,params_buffer
    bcs fin_params

    jsr do_touch
    clc
    jmp boucle_params

fin_params:

    clc
    swi success
    rts

do_touch:
    ldy #0
    mov r1,#work_buffer
    swi str_cpy

    swi file_exists
    jcc error_exists

    lda options_params
    and #OPT_P
    beq add_suffix
    
    swi str_cat,work_buffer,prg_suffix
    jmp ok_suffix


add_suffix:
    swi str_cat,work_buffer,seq_suffix

ok_suffix:
    swi str_cat,work_buffer,write_suffix

    ldx #5
    sec
    swi file_open,work_buffer
    ldx #5
    jsr CHKOUT
    
    // fill file ?
    lda options_params
    and #OPT_S
    beq no_fill
    
    // fill size
    ldx #'s'
    swi param_get_value
    mov fill_size,r0

    // fill byte
    lda #33
    sta fill_byte

    lda options_params
    and #OPT_B
    beq no_fill_byte
    
    ldx #'b'
    swi param_get_value
    lda zr0l
    sta fill_byte

    // fill loop
no_fill_byte:
    lda fill_byte
    jsr CHROUT
    decw fill_size
    lda fill_size+1
    bne no_fill_byte 
    lda fill_size
    bne no_fill_byte 

no_fill:
    lda options_params
    and #OPT_T
    beq no_text
    
    lda #10
    jsr CHROUT
no_text:
    ldx #5
    swi file_close

    clc
    rts

error_exists:
    sec
    swi error,msg_error_exists,$fffd
    rts

msg_error_exists:
    pstring("File exists")
write_suffix:
    pstring(",w")
seq_suffix:
    pstring(",s")
prg_suffix:
    pstring(",p")

help:
    swi pprint_lines, help_hw
    clc
    rts

    clc
    swi error
    rts

    
    //-- options available
options_touch:
    pstring("psbt")

help_hw:
    pstring("*touch <file> : Create empty file")
    pstring(" -p : create PRG file")
    pstring(" -s : size in bytes")
    pstring(" -b : filler byte")
    pstring(" -t : text file")
    .byte 0

fill_byte:
    .byte 33
fill_size:
    .word 0

}
