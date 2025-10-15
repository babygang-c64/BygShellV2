//----------------------------------------------------
// scratch : save / load / view scratch screen
//
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word scratch
pstring("scratch")

scratch:
{
    .label params_buffer = $cd00
    .label work_buffer = $ce00
    .label OPT_S = 1
    .label OPT_L = 2
    .label OPT_V = 4
    .label OPT_N = 8
    
    //-- init options
    sec
    swi param_init,buffer,options_scratch
    jcs help

    swi pipe_init
    jcs error

    //-- no parameters = print help
    ldx nb_params
    jeq help

    ldy #0
    sty work_buffer

    sec
    swi param_process,params_buffer
    ldx #'.'
    swi str_chr
    bcs has_extension
    mov r1,#msg_file_extension
    swi str_cat

has_extension:
    lda options_params
    and #OPT_S
    beq not_save
    
    push r0
    swi str_cpy,msg_file_prefix,work_buffer
    pop r1
    swi str_cat,work_buffer
    lda options_params
    and #OPT_N
    beq with_rewrite
    
    swi file_exists
    bcc write_error
    
with_rewrite:
    swi str_cat,work_buffer,msg_file_suffix
    jsr do_save
    jmp end
    
not_save:
    lda options_params
    and #OPT_V
    beq not_view
    
    jsr do_view
    jmp end
    
not_view:
    jsr do_load

end:
    swi pipe_end
    clc
    swi success
    rts

msg_file_prefix:
    pstring("@:")
msg_file_suffix:
    pstring(",s,w")
msg_file_extension:
    pstring(".sws")

msg_error_write:
    pstring("Write")
msg_error_read:
    pstring("File not found")

read_error:
    sec
    mov r0,#msg_error_read
    jmp error

write_error:
    sec
    mov r0,#msg_error_write

error:
    swi error
    ldx #4
    swi file_close
    rts

help:
    swi pprint_lines, msg_help
    clc
    rts
    
    //-- options available
options_scratch:
    pstring("slvn")

msg_help:
    pstring("*scratch <file> [option]")
    pstring(" -s : save (default)")
    pstring(" -l : load")
    pstring(" -v : view")
    pstring(" -n : don't force replace")
    .byte 0

do_view:
{
    ldx #4
    clc
    swi file_open
    jcs read_error

    ldx #4
    jsr CHKIN

    lda #25
    sta lines
swap_line:
    ldy #40
    sty work_buffer
swap_char:
    jsr CHRIN
    sta work_buffer,y
    dey
    bne swap_char

    swi pipe_output
    ldx #bios.SCREEN_TO_PETSCII
    swi str_conv,work_buffer
    swi pprint_nl,work_buffer
    dec lines
    bne swap_line

    ldx #4
    swi file_close
    rts

read:
    .byte 0
lines:
    .byte 0
columns:
    .byte 0
}

do_save:
{
    ldx #4
    clc
    swi file_open
    jcs write_error

    ldx #4
    jsr CHKOUT

    ldx #25
    mov r0,#bios.swap_screen
swap_line:
    ldy #39
swap_char:
    jsr bios.bios_ram_get_byte
    jsr CHROUT
    dey
    bpl swap_char
    add r0,#40
    dex
    bne swap_line

    ldx #4
    swi file_close
    rts
}

do_load:
{
    ldx #4
    clc
    swi file_open
    jcs read_error

    ldx #4
    jsr CHKIN

    ldx #25
    mov r0,#bios.swap_screen
swap_line:
    ldy #39
swap_char:
    jsr CHRIN
    mov (r0),a
    dey
    bpl swap_char
    add r0,#40
    dex
    bne swap_line

    ldx #4
    swi file_close
    rts
}

}
