//----------------------------------------------------
// xform : process delimited / text file line by line
//
// options : 
// F = use file for commands
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word xform
pstring("XFORM")

xform:
{
    .label actions_list = $cb00
    .label commands_list = $cc00
    .label buffer_line = $cd00
    .label work_buffer = $ce00
    
    .label OPT_F=1

    sec
    swi param_init,buffer,options_xform
    jcs error_params
    
    ldx nb_params
    jeq help

    swi pipe_init
    jcs error_params

    // 1st parameter is file to process
    mov nb_output,#0
    mov commands_list,#0
    ldy #0
    sty action_to_process
    sty sep_value
    sty sep_done
    sty nb_columns
    sty sel_columns
    sty is_skip
    sty is_head
    sty inc_param
    sty nb_lines

    // then commands
    ldx #2
    stx pos_param
    inc nb_params

    lda options_params
    and #OPT_PIPE
    beq no_pipe
    dec nb_params

no_pipe:
    ldy #0
    sty actions_list
    mov update_actions, #actions_list

    //------------------------------------------------
    // process all parameters to build the action list
    //------------------------------------------------

params:
    cpx nb_params
    jeq end_params

    swi lines_goto, buffer

    //------------------------------------------------
    // parameter ? process it and loop
    //------------------------------------------------
    
    lda action_to_process
    beq command_check

    jsr process_param

    jmp suite

    //------------------------------------------------
    // command lookup
    //------------------------------------------------

command_check:
    jsr lookup_action
    bcc command_found
    
    lda #'['
    jsr CHROUT
    swi pprint
    lda #']'
    jsr CHROUT
    jmp error_params
    
command_found:
    // if found, store action code in list
    
    // case of presence of SKIP command
    cmp #id_skip
    beq test_skip
    cmp #id_head
    beq test_head
    bne not_skip

test_head:
    lda inc_param
    sta pos_head
    inc pos_head
    lda #1
    sta is_head

    lda #id_head
    bne not_skip
    
test_skip:
    lda inc_param
    sta pos_skip
    inc pos_skip
    lda #1
    sta is_skip
    lda #id_skip

not_skip:
    jsr action_list_add

    // store param type for next loop
    stx action_to_process

    jmp suite

not_found:
    // error todo

suite:
    inc pos_param
    ldx pos_param
    jmp params

end_params:

    lda #0
    jsr action_list_add

    ldx #1
    swi lines_goto, buffer

    ldx #4
    clc
    swi file_open
    jcs error_file_not_found
    
    lda is_skip
    beq process_lines

    lda is_skip
    ldx pos_skip
    lda actions_list,x
    sta skip_lines
    
process_lines:
    lda #0
    sta sep_done
    ldx #4
    jsr CHKIN
    swi file_readline, buffer_line
    bcs end
    
    lda is_skip
    beq no_skip
    
    lda skip_lines
    beq no_skip

    dec skip_lines
    jmp process_next_line

no_skip:
    swi pipe_output
    jsr process_line

process_next_line:
    inc nb_lines
    lda is_head
    beq not_head
    ldx pos_head
    lda actions_list,x
    cmp nb_lines
    beq end

not_head:
    jmp process_lines
    
end:
    ldx #4
    swi file_close

    swi pipe_end
    lda nb_output
    swi return_int
    clc
    rts

print_enc:
    lda #'['
    jsr CHROUT
    swi pprint
    lda #']'
    jsr CHROUT
    lda #13
    jmp CHROUT
    
pos_param:
    .byte 0
action_to_process:
    .byte 0
is_skip:
    .byte 0
is_head:
    .byte 0
pos_skip:
    .byte 0
pos_head:
    .byte 0
inc_param:
    .byte 0
nb_lines:
    .byte 0


error_params:
    mov r0,#msg_error_params
    mov r1,#$fffd
    jmp error

error_file_not_found:
    mov r0,#msg_error_file_not_found
    mov r1,#$fffc
    jmp error

error:
    sec
    swi error
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

save_x:
    .byte 0
update_actions:
    .word 0
nb_output:
    .word 0

help_msg:
    pstring("*xform <file> <processes..> [-f <ini>]")
    pstring(" f = Use ini file")
    .byte 0

msg_error_params:
    pstring(" Unknown command")
msg_error_file_not_found:
    pstring("File not found")

options_xform:
    pstring("F")
    
.label act_no_param=0
.label act_col_list=1
.label act_string=2
.label act_int=3
.label act_pstring=4

actions:
    pstring("END")
    pstring("HEAD")
    pstring("SEP")
    pstring("SEL")
    pstring("WRITE")
    pstring("ECHO")
    pstring("WRITEC")
    pstring("SKIP")
    pstring("NL")
    .byte 0

.label id_skip = 7
.label id_head = 1

actions_params:
    .byte act_no_param
    .byte act_int
    .byte act_int
    .byte act_col_list
    .byte act_no_param
    .byte act_pstring
    .byte act_no_param
    .byte act_int
    .byte act_no_param

actions_jmp:
    .word do_end
    .word do_head
    .word do_sep
    .word do_sel
    .word do_write
    .word do_echo
    .word do_writec
    .word do_skip
    .word do_nl
    
do_end:
    clc
    rts

sep_value:
    .byte 0
sep_done:
    .byte 0
nb_columns:
    .byte 0

//----------------------------------------------------
// sep : define separator, split input if needed
//----------------------------------------------------

do_sep:
{
    inc process_line.pos_x  // pass SEP and read value
    ldx process_line.pos_x
    lda actions_list,x
    sta sep_value
    tax
    lda sep_done
    bne was_done

    swi str_split
    sta nb_columns
    lda #1
    sta sep_done

was_done:
    rts
}

//----------------------------------------------------
// skip : skip first lines
// head : process only N lines
//----------------------------------------------------

do_head:
do_skip:
{
    inc process_line.pos_x  // pass SKIP and value
    rts
}

skip_lines:
    .byte 0

//----------------------------------------------------
// sel : select columns for operation
//----------------------------------------------------

do_sel:
{
    ldy #0
next_col:
    inc process_line.pos_x
    ldx process_line.pos_x
    lda actions_list,x
    sta sel_columns,y
    iny
    cmp #0
    bne next_col
    tay
    rts
}

sel_columns:
    .fill 32,0


//----------------------------------------------------
// nl : write newline
//----------------------------------------------------

do_nl:
{
    lda #13
    jmp CHROUT
}

//----------------------------------------------------
// echo : write pstring
//----------------------------------------------------

do_echo:
{
    inc process_line.pos_x
    ldx process_line.pos_x
    ldy actions_list,x
write:
    inc process_line.pos_x
    ldx process_line.pos_x
    lda actions_list,x
    jsr CHROUT
    dey
    bne write
    ldy #0
    rts
}


//----------------------------------------------------
// writec : write selected columns without newline
//----------------------------------------------------

do_writec:
{
    sec
    jmp do_write
}

//----------------------------------------------------
// write : write selected columns
//----------------------------------------------------

do_write:
{
    stc write_nl
    lda #1
    sta pos_col
    lda #0
    sta was_write
    incw nb_output
    mov r0,#buffer_line
    lda nb_columns
    sta nb_col

next_col:
    ldy #0
test_col:
    lda sel_columns,y
    beq not_selected
    cmp pos_col
    beq selected
    iny
    bne test_col
    ldy #0

selected:
    lda was_write
    beq write
    lda sep_value
    beq write
    
    jsr CHROUT

write:
    swi pprint
    lda #1
    sta was_write

not_selected:
    swi str_next
    inc pos_col
    dec nb_col
    bne next_col

list_end:
    lda write_nl
    bne no_nl
    lda #13
    jsr CHROUT
no_nl:
    rts

pos_col:
    .byte 0
was_write:
    .byte 0
nb_col:
    .byte 0
write_nl:
    .byte 0
}

//----------------------------------------------------
// process_line : perform actions list on R0
//----------------------------------------------------

process_line:
{
    ldx #0
    stx pos_x

next_action:
    ldx pos_x
    lda actions_list,x
    beq end_action
    
    asl
    tay
    lda actions_jmp,y
    sta action_addr
    iny
    lda actions_jmp,y
    sta action_addr+1

    ldy #0
    clc
    jsr action_addr:$fce2
    
    inc pos_x
    jmp next_action

end_action:
    rts
    
pos_x:
    .byte 0
}

//----------------------------------------------------
// lookup_action : find action
// input : R0 = pararmeter string
//
// output : C=0 OK, C=1 KO, A = action ID, 
// X= parameters type
//----------------------------------------------------

lookup_action:
{
    mov r1, #actions
    ldx #0
    ldy #0
test_action:
    mov a,(r1)
    beq end_of_list
    swi str_cmp
    bcs found
    inx
    mov a,(r1)
    clc
    add r1,a
    inc r1
    jmp test_action

found:
    txa
    pha
    lda actions_params,x
    tax
    pla
    clc
    rts

end_of_list:
    sec
    rts
}

//----------------------------------------------------
// action_list_add : add byte in A to action_list
//----------------------------------------------------

action_list_add:
{
    pha
    mov r1,update_actions
    pla
    mov (r1),a
    incw update_actions
    inc inc_param
    rts
}

//----------------------------------------------------
// action_list_copy_string : add pstring to 
// action_list
//----------------------------------------------------

action_list_copy_string:
{
    push r0
    mov r1,update_actions
    ldy #0
    mov a,(r0)
    tax
copy:
    mov a,(r0++)
    mov (r1++),a
    incw update_actions

    dex
    bpl copy
    
    pop r0
    rts
}

//----------------------------------------------------
// is_digit : C=1 if A is a digit, else C=0
//----------------------------------------------------

is_digit:
{
    pha
    clc
    adc #$ff-'9'
    adc #'9'-'0'+1
    pla
    rts
}

//----------------------------------------------------
// process_param : process current param
//----------------------------------------------------

process_param:
{
    lda action_to_process
    cmp #act_int
    bne not_act_int
    
    //------------------------------------------------
    // integer : convert value to int
    //------------------------------------------------

    ldy #1
    mov a,(r0)
    ldy #0
    jsr is_digit
    bcc not_digit
    swi str2int
    lda zr1l
not_digit:
    jsr action_list_add
    jmp no_action

not_act_int:
    cmp #act_col_list
    bne not_act_list

    //------------------------------------------------
    // list of integers : split and store, add 0
    //------------------------------------------------

    mov r1,#work_buffer
    swi str_cpy
    push r0
    mov r0,#work_buffer
    
    ldx #','
    swi str_split
    tax
add_int:
    swi str2int
    lda zr1l
    jsr action_list_add
    swi str_next
    dex
    bne add_int
    
    lda #0
    jsr action_list_add
    pop r0

    //------------------------------------------------
    // pstring
    //------------------------------------------------

not_act_list:
    cmp #act_pstring
    bne no_action
    
    jsr action_list_copy_string
    
no_action:
    ldy #0
    sty action_to_process
    rts
}


} // xform
