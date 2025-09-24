//===============================================================
// BYG BIOS : BIOS functions for BYG Shell system
//---------------------------------------------------------------
// Calling rules : command # in A, parameter in R0,
// returns C=0 if OK, C=1 if KO
//===============================================================

#importonce

.encoding "ascii"

* = * "bios vectors"

.label vars=$02a7
.label buffer=$cf80
.label nb_params=$02ff
.label options_params=$02fe
.label scan_params=$02fd
.label k_flag=$02fc
.label directory_ptr=$02fa
.label options_values=$02e0

// temp dir and work vars

.label is_filter=$cfff
.label type=$cffe
.label in_quotes=$cffd
.label tmpC=$cffc
.label directory_root=$a800

// Under BASIC ROM

.label clipboard=$a000
.label history=$a100

// flags definitions

.label K_FLAG_ON=128
.label K_FLAG_CLIPBOARD=64

.label OPT_PIPE=$80

.namespace bios 
{
//===============================================================
// BIOS functions list
//===============================================================

.label bios_exec=$cf68
.label bios_ram_get_byte=bios_exec+5

.label reset=9
.label str_split=11
.label str_len=13
.label pprint=15
.label str_next=17
.label param_next=17
.label file_open=19
.label file_close=21
.label file_readline=23
.label param_init=25
.label error=27
.label pprint_int=29
.label pprint_hex=31
.label key_wait=33
.label buffer_read=35
.label pprint_lines=37
.label str_cmp=39
.label get_device_status=41
.label pprinthex8a=43
.label file_load=45
.label lines_find=47
.label lines_goto=49
.label pprint_nl=51
.label hex2int=53
.label pprint_hex_buffer=55
.label param_top=57
.label pipe_init=59
.label pipe_end=61
.label pipe_output=63
.label str_pat=65
.label str_expand=67
.label is_filter=69
.label str_cpy=71
.label str_cat=73
.label str_ins=75
.label directory_open=77
.label directory_get_entry=79
.label directory_close=81
.label param_process=83
.label set_basic_string=85
.label param_get_value=87
.label mult10=89
.label str_del=91
.label bam_init=93
.label bam_next=95
.label bam_get=97
.label node_insert=99
.label node_delete=101
.label return_int=103
.label cursor_unblink=105
.label malloc=107
.label get_basic_string=109
.label copy_ram_block=111
.label success=113
.label file_exists=115
.label str_chr=117
.label str_rchr=119
.label str_pad=121
.label node_append=123
.label node_push=123
.label node_remove=125
.label node_pop=125
.label str_ltrim=127
.label node_goto=129
.label ascii_to_screen=131
.label screen_to_ascii=133
.label screen_write_line=135
.label screen_write_all=137
.label str_rtrim=139
.label int2str=141
.label get_basic_int=143
.label buffer_write=145

//===============================================================
// bios_jmp : bios jump table
//===============================================================

bios_jmp:
    .word do_reset
    .word do_str_split
    .word do_str_len
    .word do_pprint
    .word do_str_next
    .word do_file_open
    .word do_file_close
    .word do_file_readline
    .word do_param_init
    .word do_error
    .word do_pprint_int
    .word do_pprint_hex
    .word do_key_wait
    .word do_buffer_read
    .word do_pprint_lines
    .word do_str_cmp
    .word do_get_device_status
    .word do_pprinthex8a_swi
    .word do_file_load
    .word do_lines_find
    .word do_lines_goto
    .word do_pprint_nl
    .word do_hex2int
    .word do_pprint_hex_buffer
    .word do_param_top
    .word do_pipe_init
    .word do_pipe_end
    .word do_pipe_output
    .word do_str_pat
    .word do_str_expand
    .word do_is_filter
    .word do_str_cpy
    .word do_str_cat
    .word do_str_ins
    .word do_directory_open
    .word do_directory_get_entry
    .word do_directory_close
    .word do_param_process
    .word do_set_basic_string
    .word do_param_get_value
    .word do_mult10
    .word do_str_del
    .word do_bam_init
    .word do_bam_next
    .word do_bam_get
    .word do_node_insert
    .word do_node_delete
    .word do_return_int
    .word do_cursor_unblink
    .word do_malloc
    .word do_get_basic_string
    .word do_copy_ram_block
    .word do_success
    .word do_file_exists
    .word do_str_chr
    .word do_str_rchr
    .word do_str_pad
    .word do_node_append
    .word do_node_remove
    .word do_str_ltrim
    .word do_node_goto
    .word do_ascii_to_screen
    .word do_screen_to_ascii
    .word do_screen_write_line
    .word do_screen_write_all
    .word do_str_rtrim
    .word do_int2str
    .word do_get_basic_int
    .word do_buffer_write

* = * "BIOS code"

    // bios_exec : executes BIOS function, function # in A

bios_exec_ref:
    sta bios_exec+4
    jmp (bios_jmp)

ram_get_byte:
    sei
    dec $01
    lda (zr0l),y
    inc $01
    cli
    rts
end_ref:

//===============================================================
// bios functions and variables
//===============================================================

//---------------------------------------------------------------
// reset : startup cleansing
//
// reset of cache
// copy bios exec code
//---------------------------------------------------------------

do_reset:
{
    lda #0
    sta $c002
    ldx #end_ref-bios_exec_ref
copy_bios_exec:
    lda bios_exec_ref,x
    sta bios_exec,x
    dex
    bpl copy_bios_exec
    clc
    rts
}

//---------------------------------------------------------------
// error : error message, also closes pipe output
//
// Input : r0: PSTRING of error message or default if C=0
// r1=error number, -1 by default
// 
//---------------------------------------------------------------

do_error:
{
    bcs not_default
    mov r0, #error_default
    mov r1,#$ffff
not_default:
    push r1
    lda CURSOR_COLOR
    pha
    lda #7
    sta CURSOR_COLOR
    swi pprint
    swi pprint_nl,error_msg
    pla
    sta CURSOR_COLOR
    jsr do_pipe_end
    pop r0
    jsr do_return_int
    sec
    rts

error_default:
    pstring("Shell")
error_msg:
    pstring(" error")
}

//---------------------------------------------------------------
// success : return OK
//
// Input : r0: return value if C=1 or default 0 if C=0
// 
//---------------------------------------------------------------

do_success:
{
    bcs not_default
    mov r0,#0
not_default:
    jsr do_return_int
    clc
    rts
}

//---------------------------------------------------------------
// set_basic_string
//
// input : R0 = variable descriptor
//---------------------------------------------------------------

do_set_basic_string:
{
    push TXTPTR
    
    // lookup variable with name
    mov TXTPTR,r0
    jsr PTRGET

    sta FORPNT
    sty FORPNT+1
    push r0
    add r0, #3
    mov $64,r0
    jsr COPY
    pop r0
    
    pop TXTPTR
    clc
    rts
}

//---------------------------------------------------------------
// get_basic_string
//
// input : R0 = variable descriptor, R1 = pstring for storage
//         C=0 = copy string to storage, C=1 return X=length
//         and R0 = string location
// output : R0 = variable address
//---------------------------------------------------------------

do_get_basic_string:
{
    stc tmpC
    push TXTPTR
    
    mov TXTPTR,r0
    jsr PTRGET
    
    
is_ok:
    // length
    ldy #2
    lda ($5f),y
    tax
    // address of string, move to r0
    iny
    lda ($5f),y
    sta zr0l
    iny
    lda ($5f),y
    sta zr0h
    ldy #0

    lda tmpC
    bne end
    
    // copy to r1, start with length
    txa
    mov (r1),a
copie:
    mov a,(r0)
    iny
    mov (r1),a
    dex
    bne copie

end:
    pop TXTPTR
    clc
    rts
}

//===============================================================
// directory routines :
//
// directory_open
// directory_set_filter
// directory_get_entry
// directory_close
// 
// Uses channel #9 : 9,<device>,0
//===============================================================

//---------------------------------------------------------------
// directory_open : reads directory
//
// output C=1 = error
//---------------------------------------------------------------

do_directory_open:
{
    clc
    ldx #9
    swi file_open,dirname

    jsr chkin_skip2    
    clc
    rts

dirname:
    pstring("$")
}

chkin_skip2:
{
    ldx #9
    jsr CHKIN
skip2:
    // skip 2 bytes
    jsr CHRIN
    jmp CHRIN
}

//---------------------------------------------------------------
// directory_get_entry : reads one directory entry, output in r0
//
//
// input : C=1 filter test with R1, C=0 no filter
//
// ouput : C=1 : end, R0 = name, A = type
//---------------------------------------------------------------

do_directory_get_entry:
{
    stc is_filter
    push r0
    
get_entry:
    ldy #0
    sty in_quotes
    sty type
    tya
    mov (r0++),a

    jsr chkin_skip2
    
    lda STATUS
    bne fini
    
    jsr chkin_skip2.skip2
    
    ldx #0
read_name:
    jsr CHRIN
    beq end_name
    cmp #34
    bne not_quote

    inc in_quotes
    jmp read_name

not_quote:
    ldy in_quotes
    beq read_name
    cpy #1
    beq next_char
    ldy type
    bne read_name
    cmp #32
    beq read_name
    sta type
    jmp read_name

fini:
    pop r0
    sec
    rts

next_char:
    ldy #0
    inx
    mov (r0++),a
    jmp read_name

end_name:
    pop r0
    txa
    ldy #0
    mov (r0),a
    
    ldc is_filter
    bcc no_filter

    swi str_pat
    lda #0
    bcc no_filter
    lda #1

no_filter:
    ldx type
    clc
    rts

}

//---------------------------------------------------------------
// directory_close : closes directory
//---------------------------------------------------------------

do_directory_close:
{
    ldx #9
    swi file_close
    clc
    rts
}


//===============================================================
// Parameters routines
//
// param_init
// param_top
// param_scan
// param_next
// param_get_value
// pipe_init
// pipe_output
// pipe_end
//===============================================================

//---------------------------------------------------------------
// param_get_value : returns int value of parameter if it exists
//
// input : X = parameter name
// ouput : R0 = value, C=1 if found, C=0 if not found
//         if not found R0 = 0
//
// options values format :
//  Option name : 1 byte
//  Option value : 1 word
// ends with zero
//---------------------------------------------------------------

do_param_get_value:
{
    ldy #0
lookup:
    txa
    cmp options_values,y
    beq found

    // if zero : end of values
    lda options_values,y
    beq not_found

    iny
    iny
    iny
    jmp lookup

found:
    iny
    lda options_values,y
    sta zr0l
    iny
    lda options_values,y
    sta zr0h
    sec
    ldy #0
    rts

not_found:
    mov r0,#0
    ldy #0
    clc
    rts
}

//---------------------------------------------------------------
// pipe_init : check if there is a pipe option, if yes open the
//             output file
//
// Pipe file channel is 5
//
// input : should call param_init before
// output : C=0 OK, C=1 Error
// todo ? flag to bypass nb_params check for CMD > OUT syntax
//---------------------------------------------------------------

do_pipe_init:
{
    jsr check_pipe_option
    bcs error

    // get output name = last parameter in buffer
    ldx nb_params
    swi lines_goto, buffer
    
    // open file for write
    ldx #5
    sec
    swi file_open
    bcs error
    jsr do_pipe_output

no_pipe_option:
    clc
    rts

check_pipe_option:
    lda options_params
    and #OPT_PIPE
    beq no_pipe_option
    
    ldx nb_params
    cpx #2
    bpl no_pipe_option
    sec
    rts
    
error:
    sec
    swi error, error_pipe_msg
    rts

error_pipe_msg:
    pstring("Pipe option")
}

//---------------------------------------------------------------
// pipe_end : close output file
//---------------------------------------------------------------

do_pipe_end:
{
    lda options_params
    and #OPT_PIPE
    beq pas_option_pipe

    ldx #5
    swi file_close
    jsr CLRCHN

pas_option_pipe:
    clc
    rts    
}

//---------------------------------------------------------------
// pipe_output : make sure to prrint to output file
//---------------------------------------------------------------

do_pipe_output:
{
    lda options_params
    and #OPT_PIPE
    beq pas_option_pipe

    ldx #5
    jsr CHKOUT
pas_option_pipe:
    clc
    rts
}

//---------------------------------------------------------------
// param_process : returns in R0 each param, including 
//                 directory mapping
//
// input : C=1 for init, C=0 after, R0 = work buffer
// output : C=1 for finished, R0 = current parameter
//---------------------------------------------------------------

do_param_process:
{
    bcc pas_init
    
    // init

    lda nb_params
    sta scan_params
    inc scan_params
    
    // if pipe output ignore last parameter
    
    lda options_params
    and #OPT_PIPE
    beq pas_init
    dec scan_params

pas_init:
    // save work buffer address into r4
    mov r4,r0

    jsr dec_params
    lda scan_params
    and #$7f
    jeq fini    
    
    // read param value in r0
    tax
    swi lines_goto,buffer
    swi is_filter
    jcc no_filter

    //-- filter detected

    mov r2,r0

    // already in opened directory ? goto get entry
    lda scan_params
    and #$80
    beq start_dir
    jmp deja_dir

start_dir:
    // indicate that we're in dir and open dir
    lda scan_params
    ora #$80
    sta scan_params
    
    // init directory pointer and data pool
    
    mov directory_ptr,#directory_root
    mov directory_root,#0
    
    // open directory and ignore disk name
    swi directory_open
    mov r1,r0
    mov r0,r4
    clc
    swi directory_get_entry

    // read all matching directory entries
    
read_all_dir:
    mov r1,r2
    mov r0,r4

    sec
    swi directory_get_entry
    bcs all_read
    cmp #0
    beq read_all_dir
    
    mov r1,directory_ptr
    swi str_len
    tax
copy_entry:
    mov a,(r0++)
    mov (r1++),a
    incw directory_ptr 
    dex
    bpl copy_entry

    jmp read_all_dir
    
all_read:
    swi directory_close

    mov r1,directory_ptr
    lda #0
    mov (r1),a
    mov directory_ptr,#directory_root

    // inside directory scan : get next entry
deja_dir:
    inc scan_params
        
    // return result in work buffer
    mov r1,r4
    mov r0,directory_ptr
    
    // get directory entry
    ldy #0

    jsr bios_ram_get_byte
    cmp #0
    beq fini_dir
    tax
copy_dir_entry:
    jsr bios_ram_get_byte
    mov (r1++),a
    incw directory_ptr
    inc r0
    dex
    bpl copy_dir_entry

    mov r0,r4

no_filter:
    clc
    rts

    // end of diretory = move to next parameter
fini_dir:
    
    // remove dir param from scan_params and 
    // decrement scan_params = params number
    lda scan_params
    and #$7f
    sta scan_params
    dec scan_params

    clc
    jmp do_param_process

fini:
    sec
    rts
    
dec_params:
    lda scan_params
    bmi dec_keep_flag
    dec scan_params
    rts
dec_keep_flag:
    and #$7f
    sec
    sbc #1
    ora #$80
    sta scan_params
    rts
}

//---------------------------------------------------------------
// param_top : get the 1st parameter after command name
//---------------------------------------------------------------

do_param_top:
{
    swi param_next, buffer
    rts    
}

//---------------------------------------------------------------
// param_next : move to next parameter
// input : R0 = current parameter
// output : R0 on next parameter, C=1 if end
// 
// this only redirects to str_next
//---------------------------------------------------------------

//---------------------------------------------------------------
// param_init : parameters and options init
//
// input : R0 = command start, C=0 : pas d'options, sinon 
// R1 = options PSTRING
// output : R0 = 1st parameter, A : options, X = Nb of params
// 
// options detected if string starts with - and with > for the
// global OPT_PIPE option
//---------------------------------------------------------------

do_param_init:
{
    stc avec_options
    ldy #0
    sty options_params
    sty nb_params
    sty append_mode
    sty ptr_values
    sty options_values
    
    swi str_next
    jcs fin_params

    mov r2, r0
process_params:
    sty lgr_param
    mov r3, r2
    swi str_len
    jeq fin_params

    tax
    inc r0
    inc r2

lecture_param:
    mov a, (r0)
    cmp #'-'
    beq process_option
    
    cmp #'>'
    beq process_option_pipe
    
    inc nb_params

copy_param:
    mov a, (r0++)
    mov (r2++), a
    inc lgr_param
    dex
    bne copy_param

    lda lgr_param
    mov (r3), a
    jmp process_params

process_option:
    inc r0
    mov a, (r0)
    cmp #'='
    bne no_value
    jsr extract_value
no_value:
    jsr lookup_option
    bcs option_error
    dex
    bne process_option
    dec r2
    jmp process_params

process_option_pipe:
    inc r0
    mov a,(r0)
    cmp #'>'
    bne not_append_mode
    lda #1
    sta append_mode
    inc r0
    dex
not_append_mode:
    dec r2
    lda #OPT_PIPE
    ora options_params
    sta options_params
    dex
    bne option_error
    jmp process_params

fin_params:
    lda #0
    mov (r2), a
    
    jsr update_output_name
    
    lda options_params
    ldx nb_params
    clc
    rts
    
lookup_option:
    cmp #'-'
    bne lookup_ok
    rts
lookup_ok:
    sta last_option
    pha
    mov a, (r1)
    tay
    pla
test_option:
    cmp (zr1),y
    beq ok_option
    dey
    bne test_option
    rts

ok_option:
    dey
    lda options_params
    jsr set_bit
    sta options_params
    ldy #0
    clc
    rts
option_error:
    sec
    swi error,msg_option_error
    rts

//-- extract_value : if option with =,
//-- retrieve option and value

extract_value:
    push r1

    mov r1, #0
    inc r0
    dex
    dex

read_number:
    mov a,(r0++)
    jsr is_digit
    bcc end_number
    jsr do_mult10
    sec
    sbc #$30
    add r1, a
    dex
    bne read_number
    inx
    
end_number:    
    ldy ptr_values
    lda last_option
    sta options_values,y
    iny
    lda zr1l
    sta options_values,y
    iny
    lda zr1h
    sta options_values,y
    iny
    sty ptr_values
    lda #0
    sta options_values,y
    tay
    
    pop r1
    
    mov a,(r0)
    rts

//-- update output name if present :
//-- insert @: in from of name
//-- add ,s,w or ,s,a to name

update_output_name:
    lda options_params
    and #OPT_PIPE
    bne do_update
    rts
    
do_update:
    ldx nb_params
    swi lines_goto, buffer
    
    // insert prefix
    ldx #1
    mov r1,#prefix_pipe
    swi str_ins

    // add suffix
    mov r1,#suffix_pipe
    swi str_cat
    
    // if append, update suffix
    lda append_mode
    beq not_append
    
    swi str_len
    tay
    lda #'A'
    mov (r0),a
    ldy #0
not_append:
    rts

.label avec_options = vars+4
.label lgr_param = vars+5
.label append_mode = vars+6
.label last_option = vars+7
.label ptr_values = vars+8

// "@:"
prefix_pipe:
    .byte 2
    .byte 64
    .byte ':'
suffix_pipe:
    pstring(",S,W")
msg_option_error:
    pstring("Invalid option")
}

//===============================================================
// I/O routines
//
// pprint
// pprint_nl
// file_open
// file_close
// file_readline
// buffer_read
// key_wait
// file_load
// pprint_hex_buffer
// cursor_unblink
// line_to_screen
//
// helpers :
// 
// ascii_to_screen
// screen_write_line
// screen_write_all
//===============================================================


//----------------------------------------------------
// screen_write_all : write Y lines to screen
// 
// input : r0 = nodes starting line number
//         r1 = nodes root
//         Y = number of lines to fill
//----------------------------------------------------

do_screen_write_all:
{
    sty pos_y
    ldy #0
    mov current_line,r0
    mov lines_root,r1
    mov r0,(r1)
    mov total_lines,r0
    mov screen_pos,#$0400

draw:
    incw current_line
    mov r0,current_line
    mov r1,lines_root
    jsr do_node_goto
    
    mov r1,screen_pos
    jsr do_screen_write_line
    mov screen_pos,r1
    
    dec pos_y
    beq fin

    cmpw total_lines,current_line
    bne draw

    inc $d020

no_more_lines:
    // fill remaining screen space while Y not 0
    mov r1,screen_pos
    mov r0,#filler
    jsr do_screen_write_line
    mov screen_pos,r1
    
    dec pos_y
    bne no_more_lines
fin:
    rts

filler:
    pstring(" ")

    .label current_line = vars+2
    .label lines_root = vars+4
    .label screen_pos = vars+6
    .label total_lines = vars+8
    .label pos_y = vars+10
}

//----------------------------------------------------
// screen_write_line : write a line to screen
//
// input : R0 pstring to write, R1 screen position
//         X = view_offset
//
// output : A = string length (r0)
//
// preserves Y,X
//----------------------------------------------------

do_screen_write_line:
{
    stx view_offset
    tya
    pha

    lda #40
    sta pos_x

    ldy #0
    mov a,(r0++)
    pha

    sec
    sbc view_offset
    tax
    
    cmp #0
    beq pad_line
    bmi pad_line

write_line:
    ldy view_offset
    txa
    pha
    mov a,(r0++)
    tax
    swi ascii_to_screen
    ldy #0
    mov (r1++),a
    pla
    tax

    dec pos_x
    beq end_line
    dex
    bne write_line

pad_line:
    lda #32
    mov (r1++),a
    
    dec pos_x
    bne pad_line

end_line:
    pla
    tax // lgr
    pla
    tay // original Y
    txa
    ldx view_offset
    rts
    
.label pos_x=vars
.label view_offset=vars+1
}


//----------------------------------------------------
// ascii_to_screen : convert character in X for screen
// 
// input : X, output : A and X
//----------------------------------------------------

do_ascii_to_screen:
{
    txa
    cmp #97
    bcc not_lowercase
    cmp #123
    bcs not_lowercase
    sec
    sbc #$60
not_lowercase:
    tax
    rts
}

//----------------------------------------------------
// screen_to_ascii : convert character in X to ASCII
//
// input : X, output : A and X
//----------------------------------------------------

do_screen_to_ascii:
{
    txa
    cmp #65
    bcc not_lowercase
    cmp #65+26
    bcs not_lowercase
    clc
    adc #$20
    tax
    rts

not_lowercase:
    cmp #65+128
    bcc not_uppercase
    cmp #65+26+128
    bcs not_uppercase
    sec
    sbc #$80
not_uppercase:
    tax
    rts
}

//----------------------------------------------------
// screen_to_petscii 
//----------------------------------------------------

screen_to_petscii:
{
    cmp #1
    bcc not_letter
    cmp #1+26
    bcs not_letter
    clc
    adc #$40
    rts

not_letter:
    cmp #65
    bcc not_uppercase
    cmp #65+26
    bcs not_uppercase
    clc
    adc #$20
not_uppercase:
    rts
}

//----------------------------------------------------
// ascii_to_petscii : convert character 
//
// input : A, output : A
//----------------------------------------------------

ascii_to_petscii:
{
    cmp #$41
    bcc not_lowercase
    cmp #$5a
    bcs not_lowercase
    clc
    adc #$20
    rts

not_lowercase:
    cmp #$61
    bcc not_uppercase
    cmp #$7a
    bcs not_uppercase
    sec
    sbc #$20
not_uppercase:
    rts
}

//----------------------------------------------------
// cursor_unblink : unblink cursor, restore character
// behind cursor if needed
//----------------------------------------------------

do_cursor_unblink:
{
    lda #1
    sta BLNSW
    lda BLNON
    beq blink_off
    
    ldy #0
    sty BLNON
    lda GDBLN
    ldx GDCOL
    jsr DSPP
blink_off:
    clc
    rts
}

//---------------------------------------------------------------
// pprint_hex_buffer : hexdump buffer in r0, address r1
//---------------------------------------------------------------

do_pprint_hex_buffer:
{
    swi str_len 
    sta nb_total
    inc r0

aff_line:
    push r0
    mov r0, r1
    sec
    swi pprint_hex
    pop r0
    lda #32
    jsr CHROUT

    push r0
    ldx #8
aff_bytes:
    lda nb_total
    bne pas_fini_hex

    lda #'.'
    jsr CHROUT
    jsr CHROUT
    jmp suite_hex

pas_fini_hex:
    dec nb_total
    mov a, (r0++)
    tay
    swi pprinthex8a

suite_hex:
    lda #32
    jsr CHROUT
    dex
    bne aff_bytes

    pop r0
    dec r0
    ldx #8
    jsr print_hex_text

    add r1, #8
    clc
    rts

print_hex_text:
    swi str_len
    sta nb_total
    inc r0
    
    ldx #8
aff_txt:
    lda nb_total
    beq aff_txt_fini
    mov a, (r0++)
    dec nb_total

aff_txt_fini:
    cmp #$20
    bpl pas_moins
    lda #'.'
pas_moins:
    cmp #$80
    bcc pas_plus
    cmp #$a0
    bpl pas_plus
    lda #'.'
pas_plus:
    jsr CHROUT
    dex
    bne aff_txt
    rts

.label nb_total = zr7l
}

//----------------------------------------------------
// file_load : load file from disk to memory
//
// Input R0 filename, C=1 = use load address in R1
// Output C=1 error, C=0 OK
//----------------------------------------------------

do_file_load:
{    
    stc with_load_address
    
    lda with_load_address
    eor #1
    tay    
    ldx CURRDEVICE
    bne device_ok
    ldx #8
device_ok:
    lda #2
    jsr SETLFS

    ldy #0
    mov a,(r0++)
    ldx zr0l
    ldy zr0h
    jsr SETNAM
    dec r0

    lda with_load_address
    beq suite_load
    ldx zr1l
    ldy zr1h

suite_load:
    lda #0
    jsr LOAD
    bcs load_error
    clc
    rts

load_error:
    sec
    rts

.label with_load_address = vars
}

//----------------------------------------------------
// buffer_read : buffered file read
//
// entrée : R0 = buffer de lecture (pstring)
// longueur buffer = pstring, longueur = max buffer
// C=0 lecture normale, C=1 arrêt si 0d ou 0a (ligne)
// X = id fichier
//
// sortie : buffer à jour et longueur à jour
// C=0 si pas fini, C=1 si EOF
//----------------------------------------------------

do_buffer_read:
{
    stc tmpC
    jsr CHKIN

    swi str_len
    sta lgr_max
    sty nb_lu

lecture:
    jsr READST
    bne fin_lecture
    jsr CHRIN

    ldy tmpC
    beq pas_test
    cmp #13
    beq fin_buffer
    cmp #10
    beq fin_buffer

pas_test:
    ldy nb_lu
    iny
    sta (zr0),y
    inc nb_lu
    cpy lgr_max
    beq fin_buffer
    bne lecture

fin_buffer:
    lda nb_lu
    ldy #0
    sta (zr0),y
    jsr READST
    bne fin_lecture

    clc
    rts

fin_lecture:
    and #$40
    beq pas_erreur
    // erreur lecture à gérer
    //swi error, msg_error.read_error
    // fin de fichier

pas_erreur:
    lda nb_lu
    ldy #0
    sta (zr0),y
    sec
    rts

.label nb_lu = vars
.label lgr_max = vars+1
}

//----------------------------------------------------
// buffer_write : buffered file write
//
// input : R0 = pstring of data buffer
//         X = file channel
//----------------------------------------------------

do_buffer_write:
{
    jsr CHKOUT
    swi str_len
    tax
    iny
ecriture:
    lda (zr0),y
    jsr CHROUT
    iny
    dex
    bne ecriture
    ldy #0
    rts
}

//---------------------------------------------------------------
// key_wait : wait for keypress
//
// output : A = key pressed, C=1 : is a stop key
// stop keys : RUN/STOP, Q, X
//---------------------------------------------------------------

do_key_wait:
{
    txa
    pha
    ldx DFLTI
    lda #0
    sta DFLTI
wait_key:
    jsr GETIN
    beq wait_key
    sta zsave
    stx DFLTI
    cmp #RUNSTOP
    beq stop
    cmp #'Q'
    beq stop
    cmp #'X'
    beq stop
    clc
no_stop:
    pla
    tax
    lda zsave
    rts
stop:
    sec
    bcs no_stop
}

//----------------------------------------------------
// pprint_nl : print PSTRING using basic ROM + CR
// 
// input : R0 = PSTRING
//----------------------------------------------------

do_pprint_nl:
{
 jsr do_pprint
 lda #13
 jsr CHROUT
 clc
 rts    
}

//----------------------------------------------------
// pprint : print PSTRING using basic ROM
// 
// input : R0 = PSTRING
//----------------------------------------------------

do_pprint_rom:
{
    ldy #0
    mov a, (r0++)
    tax
    mov $22, r0
    jsr STRPRT4
    dec r0
    clc
    rts
}

do_pprint:
{
    ldy #0
    push r0
    mov a, (r0)
    beq vide
    tax
boucle:
    iny
    lda (zr0),y
    jsr ascii_to_petscii
    jsr CHROUT
    dex
    bne boucle
vide:
    ldy #0
    pop r0
    clc
    rts
}

//----------------------------------------------------
// file_exists : test if files exists using file_open
//
// input : r0 = pstring name
// output : C=0 file exists, C=1 file does not exist
//----------------------------------------------------

do_file_exists:
{
    ldx #6
    clc
    jsr do_file_open
    php
    ldx #6
    jsr do_file_close
    plp
    rts
}

//----------------------------------------------------
// file_open : file open for reading / writing
//
// r0 : pstring name, X = channel
// C=0 : read, C=1 : read/write
// output : C=0 OK, C=1 KO
// file is opened in X,<device>,X
//----------------------------------------------------

do_file_open:
{
    stc read_write
    stx canal

    // set name
    ldy #0
    mov a, (r0++)
    ldx zr0l
    ldy zr0h
    jsr SETNAM

    // if directory, secondary = 0
    ldy #0
    mov a, (r0)
    cmp #'$'
    beq is_dir
    ldy canal
is_dir:

    // open X,dev,X (ou 0 si directory)
    // canal secondaire = identique à primaire, attention
    // si 0 ou 1 ça force read / write sur du PRG
    lda canal
    ldx CURRDEVICE
    jsr SETLFS

    jsr OPEN
    jsr READST
    bne error
    
    ldc read_write
    bne not_only_read

    // passe en lecture
    ldx canal
    jsr CHKIN

not_only_read:

    jsr do_get_device_status
    bcs error

    clc
    rts

error:
    ldx canal
    jsr do_file_close
    sec
    rts

.label canal = vars
.label read_write = vars+1
}

//----------------------------------------------------
// get_device_status : current device status
//
// R0 = status (2 bytes) C=0:OK, C=1:KO
//----------------------------------------------------

do_get_device_status:
{
    lda #0
    sta STATUS

    jsr LISTEN     // call LISTEN
    lda #$6F       // secondary address 15 (command channel)
    jsr SECOND     // call SECLSN (SECOND)
    jsr UNLSTN     // call UNLSTN
    lda STATUS
    //bne devnp       // device not present

    lda CURRDEVICE
    jsr TALK
    lda #$6F      // secondary address 15 (error channel)
    jsr TKSA

    jsr IECIN     // call IECIN (get byte from IEC bus)
    sta zr0l
    jsr IECIN
    sta zr0h

    jsr UNTLK
    lda zr0l
    cmp #$30
    bne status_ko
    lda zr0h
    cmp #$30
    bne status_ko
    clc
    rts
status_ko:
    sec
    rts
}

//----------------------------------------------------
// file_close : closes file and resets I/O
// input : X = channel to close
//----------------------------------------------------

do_file_close:
{
    txa
    jsr CLOSE
    
    lda options_params
    and #OPT_PIPE
    bne option_pipe

    jsr CLRCHN

option_pipe:
    clc
    rts
}

//----------------------------------------------------
// file_readline : reads one line from file
//
// r0 = input buffer
// sortie : work_buffer, A = longueur
// c=0 : ok, c=1 : fin de fichier
// lecture de 255 octets max
//----------------------------------------------------

do_file_readline:
{
    ldy #0
    tya
    mov (r0), a
    iny

boucle_lecture:
    jsr READST
    bne fin_lecture
    jsr CHRIN
    cmp #13
    beq fin_ligne
    cmp #10
    beq fin_ligne
    sta (zr0),y
    iny
    bne boucle_lecture
    
    // todo ici  : erreur dépassement buffer
erreur:
    //swi error, msg_error.buffer_overflow
    sec
    rts

fin_ligne:
    dey
    tya
    ldy #0
    sta (zr0),y
    clc
    rts

fin_lecture:
    jsr fin_ligne
    sec
    rts
}

//===============================================================
// Memory management routines
//
// memory allocation uses a BAM structure of 255 bytes blocs
// each bloc has a bytes free byte + 255 bytes
//
// BAM structure :
//
// bam_root
// 1 byte : bam length = n
// 1 byte : bam free = n*8
// 1 byte : bam allocated = 0
// n bytes : bam 
//
// bam_init : reset bam
// bam_next : get 1st or next allocated block
//===============================================================

.label bam_length=0
.label bam_free=1
.label bam_allocated=2
.label bam_start=3

//---------------------------------------------------------------
// bam_init : reset bam
//
// input : R0 = bam root address, x = bam length
//---------------------------------------------------------------

do_bam_init:
{
    ldy #0
    txa
    mov (r0++),a
    asl
    rol
    rol
    mov (r0++),a
    tya
    mov (r0++),a
clear_bam:
    mov (r0++),a
    dex
    bne clear_bam
    clc
    rts    
}

//----------------------------------------------------
// bam_next : get first / next allocated block
//
// input : C=1 start, C=0 continue, r0=bam root
// r1=memory start, r2=used for storage
// output : R0 = block, C=1 KO, C=0 OK
//----------------------------------------------------

do_bam_next:
{
    bcc not_first
    lda #0
    sta bit_bam
    sta pos_bam

    lda #bam_start
    add r0,a

not_first:
    ldy pos_bam
    mov a,(r0)
    
    ldx bit_bam
    cpx #8
    beq not_found
    
    and bit_list,x
    bne found

    inc zr1h
    inx
    stx bit_bam
    ldx bit_bam
    cpx #8
    bne not_first

not_found:
    ldy #0
    sty bit_bam
    inc pos_bam

    // r0 on bam_allocated, get value then restore r0
    dec r0
    mov a,(r0)
    inc r0
    cmp pos_bam
    bne not_first
    
    sec
    rts
    
found:
    inc bit_bam
    mov r0,r1
    clc
    rts

.label pos_bam = zr2l
.label bit_bam = zr2h
}

//----------------------------------------------------
// bam_get : allocate one block if possible
//
// input : R0 = bam root, R1 = memory start
// output : R0 = allocated block, C=1 = KO, C=0 = OK
//----------------------------------------------------

do_bam_get:
{
    // if no more blocks free = error
    ldy #bam_free
    mov a,(r0)
    dey
    cmp #0
    beq error
    
    // lookup for space in bam
    ldy #bam_start
bam_next:
    mov a,(r0)
    cmp #$ff
    bne new_block
    
    // target new block address = +8 pages for each
    // bam entry
    add r1, #$0800
    iny
    bne bam_next

    // new block possible, find which one (bit number)
    // and mark bit for block is allocated
new_block:
    sty save_y
    jsr next_free_bit
    sty found_bit
    ldy save_y
    mov a,(r0)
    ldy found_bit
    jsr set_bit
    ldy save_y
    mov (r0),a

    // dec bam_free, inc bam_allocated
    ldy #bam_free
    mov a,(r0)
    sec
    sbc #1
    mov (r0),a

    ldy #bam_allocated
    mov a,(r0)
    clc
    adc #1
    mov (r0),a

    // adjust target address with block position
    lda found_bit
    clc
    adc zr1h
    sta zr1h

    // write number of free bytes in new block = 255
    ldy #0
    lda #255
    mov (r1),a
    mov r0,r1
    clc
    rts

error:
    inc $d020
    jmp error

.label found_bit=vars
.label save_y=vars+1
}

//----------------------------------------------------
// malloc : return R0 to space with free X bytes
//
//
// input : X = number of bytes to allocate,
//         R0 = bam_root address, R1 = memory_start
// output : C=1 KO, C=0 OK
//----------------------------------------------------

do_malloc:
{
   stx how_much
   // lookup all allocated blocks first to see if one
   // has enough space left

    mov save0,r0
    mov save1,r1
   
   ldy #bam_start

scan_bam:
    mov a,(r0)
    cmp #0
    beq new_block
    
    ldy #0
    sec

test_bam:

//    mov r0,#bam_root
//    mov r1,#memory_start
    swi bam_next
    bcs new_block

    ldy #0
    mov a,(r0)
    cmp how_much
    bcc test_bam

    // OK size :
    // existing block with enough size
    // calculate position and new free
    // size
    
    // target position
    sta bam_available
    lda #0
    sec
    sbc bam_available
    pha
    
    // size
    sec
    lda bam_available
    sbc how_much
    mov (r0),a
    
    pla
    clc
    add r0,a

    clc
    rts
    
    // no space free in allocated blocs, allocate a new block,
    // the new block free space is 255-X

new_block:
    mov r0,save0
    mov r1,save1
    swi bam_get

    lda #255
    sec
    sbc how_much
    mov (r0),a
    inc r0
    clc
    rts

.label how_much = vars+2
.label bam_available = vars+3
.label save0 = vars+4
.label save1 = vars+6
}

//----------------------------------------------------
// copy_ram_block : copy block of RAM under basic ROM
//
// input : r0 = address of block to copy,
//         r1 = destination
//----------------------------------------------------

do_copy_ram_block:
{
    ldy #0
copy:
    jsr bios_ram_get_byte
    mov (r1),a
    iny
    bne copy
    rts
}

//===============================================================
// Nodes : routines to manage list of pointers
//
// node_delete : delete existing node at given position
// node_insert : insert new node at given position
// node_append / push : append new node at end
// node_remove / pop  : remove node at end
// node_goto : goto specified node
//
// Data structure (through r1) :
//
// total_entries = word
// entries = words
//
// uses ztmp
//===============================================================

//---------------------------------------------------------------
// node_goto : goto node
//
// input : r1 = root entry, r0 = node number
// output : r0 = node value, r1 = node address
//---------------------------------------------------------------

do_node_goto:
{
    asl zr0l
    rol zr0h
    add r0,r1

    mov r1,r0
    mov r0,(r1)
    rts
}

//---------------------------------------------------------------
// node_append / push : append node at end
//
// input : r1 = root entry, r0 = new node value
//---------------------------------------------------------------

do_node_append:
{
    push r0
    mov r0, (r1)
    jsr node_precalc
    pop r0
    mov (r2),r0
    incw r1
    rts
}

//---------------------------------------------------------------
// node_remove / pop : remove last node and get value
//
// input : r1 = root entry
// output : r0 = value of last node
//---------------------------------------------------------------

do_node_remove:
{
    mov r0, (r1)
    jsr node_precalc
    mov r0, (r2)
    decw r1
    rts
}

//---------------------------------------------------------------
// node_calc_nb : calculates number of moves for copy
//
// input : r0 = line position to process
// r1 = root entry = contains total number of values
// output : r3 = number of moves
//---------------------------------------------------------------

node_calc_nb:
{
    // tmp_line = how many lines to copy
    ldy #0
    lda (zr1l),y
    sta zr3l
    iny
    lda (zr1l),y
    sta zr3h
    dey

    sec
    lda zr3l
    sbc zr0l
    sta zr3l
    lda zr3h
    sbc zr0h
    sta zr3h
    rts
}

//---------------------------------------------------------------
// node_precalc : calculates position of node in list =
// r2 =  2 * r0 + 2 + r1
//
//---------------------------------------------------------------

node_precalc:
{
    asl zr0l
    rol zr0h
    add r0,#2
    clc
    lda zr1l
    adc zr0l
    sta zr0l
    lda zr1h
    adc zr0h
    sta zr0h
    mov r2,r0
    rts
}

//---------------------------------------------------------------
// node_copy : copy sequence for insert / delete
//---------------------------------------------------------------

node_copy:
{    
    stc sens
    ldy #0
copie:
    lda (zr0l),y
    sta (zr2l),y
    iny
    lda (zr0l),y
    sta (zr2l),y
    dey

    lda sens
    bne supp_line

    dec r0
    dec r0
    dec r2
    dec r2    
    jmp suite_copie

supp_line:
    inc r0
    inc r0
    inc r2
    inc r2

suite_copie:
    dec r3
    lda zr3l
    bne copie
    lda zr3h
    bne copie
    rts

.label sens = vars
}

//---------------------------------------------------------------
// node_delete : insert node at position r0 in list described 
// at r1
//---------------------------------------------------------------

do_node_delete:
{
    jsr node_calc_nb
    push r0    

    // r0 = read, r2 = write = pos to suppress
    jsr node_precalc
    inc r0
    inc r0
    
    sec
    jsr node_copy

    mov r0,(r1)
    dec r0
    mov (r1),r0

    pop r0
    clc
    rts
}

//----------------------------------------------------
// node_insert : insert node at position r0 in list 
// described at r1
//----------------------------------------------------

do_node_insert:
{
    jsr node_calc_nb
    push r0

    lda zr3l
    bne ok_insert
    lda zr3h
    beq no_need
    
ok_insert:
    // r0 = read = total, r2 = write = read + 1 
    mov r0, (r1)
    jsr node_precalc
    dec r0
    dec r0

    clc
    jsr node_copy

no_need:
    mov r0,(r1)
    inc r0
    mov (r1),r0

    pop r0
    clc
    rts
}

//===============================================================
// pstring routines
//
// str_split
// str_cmp
// str_cpy
// str_cat
// str_ins
// str_pat
// str_expand
// str_next
// lines_find
// lines_goto
// is_filter
// str_del
// str_chr
// str_rchr
// str_pad
//
// missing from v1 :
//
// str_empty
// str_ncpy
//===============================================================

//---------------------------------------------------------------
// str_pad : truncate or completes string to length X
//
// input : r0 = pstring, X = target length
//---------------------------------------------------------------

do_str_pad:
{
    stx ztmp
    ldy #0
    lda (zr0),y
    cmp ztmp
    beq do_str_chr.end
    sta (zr0),y
    tay
    lda #32
pad:
    cpy ztmp
    bcs do_str_chr.end
    sta (zr0),y
    iny
    bne pad
pb:
    sec
    rts
}


//---------------------------------------------------------------
// str_chr : lookup X in pstring R0, C=1 if found and
// Y = position
//---------------------------------------------------------------

do_str_chr:
{
    stx ztmp
    ldy #0
    lda (zr0),y
    beq pas_trouve
    sta longueur
    iny
    lda ztmp
recherche:
    cmp (zr0),y
    beq trouve
    iny
    dec longueur
    bne recherche
pas_trouve:
end:
    clc
    rts
trouve:
    sec
    rts
.label longueur = vars
}

//---------------------------------------------------------------
// str_rchr : reverse lookup X in pstring R0, C=1 if find and
// Y = position
//---------------------------------------------------------------

do_str_rchr:
{
    stx ztmp
    ldy #0
    lda (zr0),y
    beq do_str_chr.pas_trouve
    tay
    lda ztmp
recherche:
    cmp (zr0),y
    beq do_str_chr.trouve
    dey
    bne recherche
    beq do_str_chr.pas_trouve
}

//---------------------------------------------------------------
// str_del : supprime Y caractères à partir de la position X
// entrée : R0 = pstring
// todo : contrôle erreurs / dépassements
//---------------------------------------------------------------

do_str_del:
{
    // 0 123456789 : 3, 4 -> 0 123 4567 89 -> 0 12389
    
    // début Y+1
    sty nb_supp
    inx
    stx pos_ecriture
    txa
    clc
    adc nb_supp
    sta pos_lecture
    
    swi str_len
    sec
    sbc pos_ecriture
    sbc nb_supp
    tax

copie:
    ldy pos_lecture
    mov a, (r0)
    ldy pos_ecriture
    mov (r0), a
    inc pos_ecriture
    inc pos_lecture
    dex
    bpl copie

    // maj longueur
    ldy #0
    mov a, (r0)
    sec
    sbc nb_supp
    mov (r0), a    
    clc
    rts

.label nb_supp = vars
.label pos_lecture = vars+1
.label pos_ecriture = vars+2
}

//---------------------------------------------------------------
// str_cpy : copie pstring en r0 vers destination en r1
// en sortie A = longueur + 1 = longueur copiée
//---------------------------------------------------------------

do_str_cpy:
{
    swi str_len
    pha
    tay
copie:
    lda (zr0),y
    sta (zr1),y
    dey
    bpl copie
    pla
    clc
    adc #1
    ldy #0
    rts
}

//---------------------------------------------------------------
// str_cat : ajoute une chaine
// r0 = r0 + r1
// sortie Y = 0
//---------------------------------------------------------------

do_str_cat:
{
    // pos_new = écriture = lgr + 1
    ldy #0    
    lda (zr0),y
    tay
    iny
    sty pos_new

    // pos_copie = lecture = 1
    // lgr_ajout = nb de caractères à copier
    ldy #0
    lda (zr1),y
    sta lgr_ajout
    iny
    sty pos_copie

copie:
    ldy pos_copie
    lda (zr1),y
    ldy pos_new
    sta (zr0),y
    inc pos_new
    inc pos_copie
    dec lgr_ajout
    bne copie

    // mise à jour longueur = position écriture suivante - 1
    dec pos_new
    lda pos_new
    ldy #0
    sta (zr0),y
    clc
    rts

.label pos_copie = vars
.label pos_new = vars+1
.label lgr_ajout = vars+2
}

//---------------------------------------------------------------
// str_ins : insère dans r0 la chaine r1 en position X
//
// R0 is preserved, use X=1 for 1st char of pstring
//---------------------------------------------------------------

do_str_ins:
{
    // 1. décale la fin de chaine pour faire de la place
    // 2. copie r1 en position X
    // 3. mise à jour lgr = +lgr r1

    stx pos_copie
    swi str_len
    sta pos_lecture
    push r0
    mov r0, r1
    swi str_len
    sta lgr_r1
    pop r0
    lda pos_lecture
    clc
    adc lgr_r1
    sta pos_ecriture
    lda pos_lecture
    sec
    sbc pos_copie
    tax
    lda #1
    sta pos_lecture_copie

decale:
    ldy pos_lecture
    mov a, (r0)
    ldy pos_ecriture
    mov (r0), a
    dec pos_lecture
    dec pos_ecriture
    dex
    bpl decale

    ldx lgr_r1
copie:
    ldy pos_lecture_copie
    mov a, (r1)
    ldy pos_copie
    mov (r0), a
    inc pos_lecture_copie
    inc pos_copie
    dex
    bne copie

    swi str_len
    clc
    adc lgr_r1
    mov (r0), a
    ldy #0
    
    clc
    rts

.label pos_lecture = vars
.label pos_ecriture = vars+1
.label pos_copie = vars+2
.label pos_lecture_copie = vars+3
.label lgr_r1 = vars+4
}

//---------------------------------------------------------------
// is_filter : C=1 if string in R0 contains filter chars (? or *)
//---------------------------------------------------------------

do_is_filter:
{
    swi str_len
    tay
test_str:
    lda (zr0),y
    cmp #'*'
    beq filtre_trouve    
    cmp #'#'
    beq filtre_trouve    
    dey
    bne test_str
    clc
    rts
filtre_trouve:
    sec
    rts
}

//---------------------------------------------------------------
// str_expand : expands quoted string
//
// input : R0 string to expand, R1 destination
// sortie : C=1 if quoted string, otherwise C=0
//
// - surrounding quotes are suppressed
// - %% is changed to %
// - %' is changed to double quotes
// - %$ is replaced with value of SH$ variable
// - if the character following % is not recognized,
//   "?" is inserted
//---------------------------------------------------------------

do_str_expand:
{
    push r7
    txa
    pha
    ldy #0
    push r1
    mov a,(r0++)
    beq fini
    tax
    mov a,(r0)
    cmp #34
    beq quoted
    
    inc r1
copy_same:
    lda (zr0),y
    sta (zr1),y
    iny
    dex
    bne copy_same

fini:
    pop r1
    jsr write_length
    pla
    tax
    pop r7
    clc
    rts

write_length:
    tya
    ldy #0
    mov (r1), a
    rts

quoted:
    inc r1
    inc r0
    dex
    ldy #0
    sty pos_write
    sty pos_read

copy_expand:
    ldy pos_read
    lda (zr0),y
    cmp #'%'
    beq do_special
    cmp #34
    beq fin_expand

copy_next:
    ldy pos_write
    sta (zr1),y
    inc pos_read
    inc pos_write
    dex
    bne copy_expand

fin_expand:
    pop r1
    ldy pos_write
    jsr write_length
    pla
    tax
    pop r7
    sec
    rts

do_special:
    inc r0
    lda (zr0),y
    cmp #'%'
    beq copy_next
    cmp #'$'
    beq add_sh_string
    cmp #39
    bne not_quote
    lda #34
    jmp copy_next

not_quote:
    lda #'?'
    jmp copy_next

add_sh_string:
    txa
    pha
    push r0
    sec
    swi get_basic_string, sh_string
    cpx #0
    beq empty_string
    
    ldy #0
copy_sh:
    lda (zr0l),y
    iny
    sty zsave
    ldy pos_write
    sta (zr1l),y
    inc pos_write
    ldy zsave
    dex
    bne copy_sh

empty_string:
    inc pos_read
    pop r0
    pla
    tax
    jmp copy_expand

.label pos_write = zr7l
.label pos_read = zr7h
    
sh_string:
    .text "SH$"
}

//---------------------------------------------------------------
// str_pat : string pattern matching, 
// 
// 
// input :
//  r0 : address of pstring to test
//  r1 : pstring pattern, * = multiple characters, 
//       # = 1 character
// output : 
//  C=1 if found, C=0 if not found
//---------------------------------------------------------------


do_str_pat:
{
// Variables definitions
.label string_len = vars
.label pattern_len = vars + 1
.label s_idx = vars + 2
.label p_idx = vars + 3
.label star_pos = vars + 4
.label match_pos = vars + 5
.label temp = vars + 6

// Function to match pattern in zr1l against string in zr0l
wildcard_match:
    ldy #0              // Load lengths
    lda (zr0l),y
    sta string_len
    lda (zr1l),y
    sta pattern_len
    
    lda #0              // Initialize indices
    sta s_idx
    sta p_idx
    lda #$ff            // Initialize star_pos to -1
    sta star_pos

loop:
    lda s_idx           // While s_idx < string_len
    cmp string_len
    bcc continue
    jmp end_string

continue:
    lda p_idx           // If p_idx >= pattern_len, skip to not_normal
    cmp pattern_len
    bcs not_normal
    
    ldy p_idx           // Load pattern char
    iny
    lda (zr1l),y
    sta temp            // Store in temp
    
    cmp #'#'            // If '#', match any char
    beq match_char
    
    ldy s_idx           // Load string char
    iny
    lda (zr0l),y
    cmp temp            // Compare with pattern char
    beq match_char
    jmp not_normal      // No match, go to not_normal

match_char:
    inc s_idx           // Advance both indices
    inc p_idx
    jmp loop            // Continue loop

not_normal:
    lda p_idx           // If p_idx >= pattern_len, skip to not_star
    cmp pattern_len
    bcs not_star
    
    ldy p_idx           // Load pattern char
    iny
    lda (zr1l),y
    cmp #'*'            // If not '*', go to not_star
    bne not_star
    
    lda p_idx           // Record star position
    sta star_pos
    lda s_idx           // Record current string position for backtracking
    sta match_pos
    inc p_idx           // Advance past '*'
    jmp loop            // Continue loop

not_star:
    lda star_pos        // If no star_pos, no match
    cmp #$ff
    beq no_match
    
    lda star_pos        // Backtrack: set p_idx to star_pos + 1
    clc
    adc #1
    sta p_idx
    inc match_pos       // Advance match_pos
    lda match_pos
    sta s_idx           // Set s_idx to new match_pos
    jmp loop            // Continue loop

no_match:
    clc                 // Clear carry for no match
    rts

end_string:
    // Consume any trailing '*' in pattern
post_loop:
    lda p_idx
    cmp pattern_len
    bcs check_match
    ldy p_idx
    iny
    lda (zr1l),y
    cmp #'*'
    bne check_match
    inc p_idx
    jmp post_loop

check_match:
    lda p_idx           // If p_idx == pattern_len, match
    cmp pattern_len
    beq yes_match
    clc                 // No match
    rts

yes_match:
    sec                 // Set carry for match
    rts
}

//----------------------------------------------------
// lines_goto : goto specific pstring in list
// 
// input : R0 = start of list, X = position
// output : C=1 : found, C=0 : not found
//----------------------------------------------------

do_lines_goto:
{
    cpx #0
    beq do_lines_find.found
    swi str_next
    bcs do_lines_find.not_found
    dex
    bcc do_lines_goto
}

//----------------------------------------------------
// lines_find : find an entry in a list of pstrings
//
// input : R0 = 1st pstring of list, R1 = key
// output : C=1 : found, C=0 : not found, X = index
//----------------------------------------------------

do_lines_find:
{
    ldx #0
check:
    swi str_cmp
    bcs found
    inx
    swi str_next
    bcs not_found
    bcc check

found:
    sec
    rts
not_found:
    clc
    rts
}

//----------------------------------------------------
// str_split : découpe une pstring en fonction d'un
// séparateur
// entrée = r0 pstring, X = séparateur, 
// C=1 gère les guillemets, C=0 ignore les guillemets
// en sortie = r0 pstring découpée, A = nb d'éléments
// C=0 pas de découpe, C=1 découpe effectuée
//----------------------------------------------------

do_str_split:
{
    stc quotes
    stx separateur
    swi str_len
    sta lgr_total
    sty decoupe
    sty nb_items
    iny
    sty lgr_en_cours
    dey
    mov r1, r0
    inc r0
    
parcours:
    lda lgr_total
    beq fini
    mov a, (r0++)
    cmp #34
    bne test_sep
    lda quotes
    eor #$80
    sta quotes
    
test_sep:
    cmp separateur
    bne pas_process_sep
    lda quotes
    beq no_quotes
    bmi pas_process_sep

no_quotes:
    lda #1
    sta decoupe
    jsr process_sep

pas_process_sep:
    inc lgr_en_cours
    dec lgr_total
    bne parcours

    // traitement dernier
    jsr process_sep

fini:
    ldc decoupe
    lda nb_items
    rts

process_sep:
    ldx lgr_en_cours
    dex
    txa
    mov (r1), a
    mov r1, r0
    dec r1
    ldx #0
    stx lgr_en_cours
    inc nb_items
    rts

.label separateur = vars
.label lgr_total = vars+1
.label lgr_en_cours = vars+2
.label decoupe = vars+3
.label nb_items = vars+4
.label quotes = vars+5
}

//---------------------------------------------------------------
// str_cmp : compare 2 pstrings, r0 vs r1, C=1 si OK
//---------------------------------------------------------------

do_str_cmp:
{
    // si pas même longueur = KO
    mov a,(r0)
    cmp (zr1),y
    bne comp_ko
    tay
    bne do_comp
    mov a,(r1)
    beq comp_ok

do_comp:
    lda (zr0),y
    cmp (zr1),y
    bne comp_ko
    dey
    bne do_comp
comp_ok:
    sec
    rts
comp_ko:
    clc
    rts
}

//---------------------------------------------------------------
// str_len : returns in A the length of pstring in R0
//---------------------------------------------------------------

do_str_len:
{
    ldy #0
    mov a, (r0)
    rts
}

//---------------------------------------------------------------
// str_rtrim : removes spaces at the end of R0
//---------------------------------------------------------------

do_str_rtrim:
{
    ldy #0
    mov a,(r0)
    tay
    beq fini
look:
    mov a,(r0)
    cmp #32
    bne adjust
    dey
    bne look
adjust:
    tya
    ldy #0
    mov (r0),a
fini:
    rts
}

//---------------------------------------------------------------
// str_ltrim : removes spaces at the start of R0
//---------------------------------------------------------------

do_str_ltrim:
{
    push r0
    push r1
    txa
    pha
    mov r1,r0
    inc r1
    ldy #0
    mov a, (r0++)
    sta length
    sty new_length
    beq fini
    
    // r1 write, r0 read
spaces:
    mov a,(r0)
    cmp #32
    bne no_spaces
    inc r0
    dec length
    beq fini
    bne spaces
no_spaces:
    mov (r1++),a
    inc r0
    inc new_length
    dec length
    beq fini
    mov a,(r0)
    jmp no_spaces
    
fini:
    pla
    tax
    pop r1
    pop r0
    lda new_length
    mov (r0),a
    rts

.label length = vars
.label new_length = vars + 1
}

//---------------------------------------------------------------
// str_next : input R0, moves R0 to next PSTRING in memory
// input : R0
// output : R0 = next PSTRING, C=0 if more, C=1 if finished
//          A = next string length
//---------------------------------------------------------------

do_str_next:
{
    ldy #0
    mov a, (r0++)
    add r0, a
    clc
    mov a, (r0)
    bne pas_fini
    sec
pas_fini:
    rts  
}

//===============================================================
// pprint routines : print functions for pstrings and other
//
// pprint
// pprint_nl
// pprint_int
// pprint_hex
// pprint_lines
//===============================================================

//---------------------------------------------------------------
// pprint_lines : print a series of PSTRING
// 
// input : R0 = 1st PSTRING, stops with 0
//---------------------------------------------------------------

do_pprint_lines:
{
    swi str_len
    beq fini
print_lines:
    swi pprint_nl
    swi str_next
    bcc print_lines
fini:
    clc
    rts
}

//---------------------------------------------------------------
// pprint_int : integer print
// integer in r0
// X = format for printing , %PL123456
// bit 7 = padding with spaces (if not set padding with 0)
// bit 6 = suppress leading spaces
//---------------------------------------------------------------

do_pprint_int:
{
    lda #6
    sta int_conv
    lda #$30
    sta int_conv+1
    sta int_conv+2
    sta int_conv+3
    sta int_conv+4
    sta int_conv+5
    sta int_conv+6

    stx format
    txa
    and #%10000000
    sta padding_space
    lda format
    and #%01000000
    sta write_space
    lda #%00100000
    sta test_format
    lda #1
    sta do_padding
    txa
    pha
    mov r1, #int_conv
    jsr bios.do_int2str

    ldx #0
suite_affiche:
    lda format
    and test_format
    beq pas_affiche
    lda int_conv+1,x
    cmp #$30
    bne pas_test_padding

    lda padding_space
    bmi test_padding
    lda int_conv+1,x
    bne affiche

test_padding:
    lda do_padding
    beq padding_fini

    lda write_space
    beq pas_affiche

    lda #32
    bne affiche
padding_fini:
    lda #$30
affiche:
    jsr CHROUT
pas_affiche:
    clc
    lsr test_format
    inx
    cpx #6
    bne suite_affiche
    pla
    tax
    mov r0,#int_conv
    rts

pas_test_padding:
    jsr CHROUT
    lda #0
    sta do_padding
    jmp pas_affiche

.label format = vars
.label test_format = vars+1
.label padding_space = vars+2
.label write_space = vars+3
.label do_padding = vars+4
.label int_conv = vars+8
}

//---------------------------------------------------------------
// mult10 : multiply R1 by 10, result in R1
//---------------------------------------------------------------

do_mult10:
{
    pha

    lda zr1h
    pha
    
    lda zr1l
    jsr mult2
    jsr mult2
    adc zr1l
    sta zr1l
    pla
    adc zr1h
    sta zr1h
    jsr mult2

    pla
    rts

mult2:
    asl zr1l
    rol zr1h
    rts
}

//---------------------------------------------------------------
// int2str : convert int in r0 to pstring in r1
// target buffer for pstring r1 should be 16 bytes at least
//---------------------------------------------------------------

do_int2str:
{
    jsr int2bcd
    ldy #0
    lda #6
    sta (zr1),y
    iny
    lda bcd_buffer+2
    jsr conv_bcd
    lda bcd_buffer+1
    jsr conv_bcd
    lda bcd_buffer+0
    jsr conv_bcd
    ldy #0
    rts

conv_bcd:
    tax
    lsr
    lsr
    lsr
    lsr
    ora #$30
    sta (zr1),y
    iny
    txa
    and #$0f
    ora #$30
    sta (zr1),y
    iny
    rts

int2bcd:
    lda #0
    sta bcd_buffer
    sta bcd_buffer+1
    sta bcd_buffer+2
    sed
    ldy #0
    ldx #6
calc1:
    asl zr0l
    rol zr0h
    adc bcd_buffer+0
    sta bcd_buffer+0
    dex
    bne calc1

    ldx #7
cbit7:
    asl zr0l
    rol zr0h
    lda bcd_buffer+0
    adc bcd_buffer+0
    sta bcd_buffer+0
    lda bcd_buffer+1
    adc bcd_buffer+1
    sta bcd_buffer+1
    dex
    bne cbit7

    ldx #3
cbit13:
    asl zr0l
    rol zr0h
    lda bcd_buffer+0
    adc bcd_buffer+0
    sta bcd_buffer+0
    lda bcd_buffer+1
    adc bcd_buffer+1
    sta bcd_buffer+1
    lda bcd_buffer+2
    adc bcd_buffer+2
    sta bcd_buffer+2
    dex
    bne cbit13
    cld
    rts

// 3 bytes
.label bcd_buffer = vars+5
}

//---------------------------------------------------------------
// do_pprint_hex : affiche en hexa format $xxxx la valeur en r0
// si C=1, n'affiche pas le préfixe
//---------------------------------------------------------------

do_pprint_hex:
{
    stx ztmp
    bcs no_prefix
    lda #'$'
    jsr CHROUT
no_prefix:
    lda zr0h
    jsr do_pprinthex8a
    jsr do_pprinthex8
    ldx ztmp
    rts
}

//---------------------------------------------------------------
// hex2int : conversion pstring 16bits hexa en entier
// entrée : pstring dans R0, sortie : R0 = valeur
// do_hex2int.conv_hex_byte
//---------------------------------------------------------------

do_hex2int:
{
    ldy #0
    mov a, (r0++)
    cmp #4
    bne pas4car

    jsr conv_hex_byte
    pha
    jsr conv_hex_byte
    sta zr0l
    pla
    sta zr0h
    clc
    rts
pas4car:
    sec
    rts

conv_hex_byte:
    jsr conv_hex_nibble
    asl
    asl
    asl
    asl
    sta ztmp
    jsr conv_hex_nibble
    ora ztmp
    rts

conv_hex_nibble:
    mov a,(r0++)
    sec
    sbc #$30
    cmp #10
    bcc pasAF
    sec
    sbc #7
pasAF:
    rts
}

//---------------------------------------------------------------
// a2hex : conversion 8 bits en hexa
// entrée : A, sortie hexl / hexh
//---------------------------------------------------------------

.label hexl = zr7l
.label hexh = zr7h

a2hex:
{
    pha
    lsr
    lsr
    lsr
    lsr
    jsr process_nibble
    sta hexl
    pla
    and #15
process_nibble:
    cmp #10
    clc
    bmi pas_add
    adc #7
pas_add:
    adc #$30
    sta hexh
    clc
    rts
}

//---------------------------------------------------------------
// do_pprinthex8 : affiche en hexa la valeur dans r0l
//---------------------------------------------------------------

do_pprinthex8:
    lda zr0l
do_pprinthex8a:
{
    jsr a2hex
    lda hexl
    jsr CHROUT
    lda hexh
    jsr CHROUT
    clc
    rts
}
do_pprinthex8a_swi:
{
    tya
    ldy #0
    jmp do_pprinthex8a
}


//---------------------------------------------------------------
// get_basic_int : get int value from BASIC variable
//
// input : R0 pointer to variable name
// output : R0 value of variable
//---------------------------------------------------------------

do_get_basic_int:
{
    push TXTPTR

    mov TXTPTR,r0
    jsr PTRGET
    ldy #3
    lda ($5f),y
    sta zr0l
    dey
    lda ($5f),y
    sta zr0h

    pop TXTPTR
    clc
    rts
}

//---------------------------------------------------------------
// return_int : return int value to variable SH%
//
// input : r0 = value
//---------------------------------------------------------------

do_return_int:
{
    push TXTPTR

    mov TXTPTR,#return_var_int
    jsr PTRGET
    ldy #2
    lda zr0h
    sta ($5f),y
    iny
    lda zr0l
    sta ($5f),y
    ldy #0

    pop TXTPTR    
    clc
    rts

return_var_int:
    .text "SH%"
    .byte 0
}


} // namespace bios

//===============================================================
// call_bios : call bios function with word parameter in r0
//===============================================================

.macro call_bios(bios_func, word_param)
{
    mov r0, #word_param
    lda #bios_func
    jsr bios.bios_exec
}

//===============================================================
// call_bios2 : call bios function with parameters in r0, r1
//===============================================================

.macro call_bios2(bios_func, word_param, word_param2)
{
    mov r0, #word_param
    mov r1, #word_param2
    lda #bios_func
    jsr bios.bios_exec
}

//===============================================================
// bios : call bios function without parameters
//===============================================================

.macro bios(bios_func)
{
    lda #bios_func
    jsr bios.bios_exec
}


//===============================================================
// Helper functions
//===============================================================

//---------------------------------------------------------------
// next_free_bit : lookup for 1st unset bit in A, return into Y
//---------------------------------------------------------------

next_free_bit:
{
    ldy #7
    sta ztmp
lookup:
    and bit_list,y
    beq is_free
    lda ztmp
    dey
    bpl lookup
is_free:
    rts
}

//---------------------------------------------------------------
// set_bit : sets bit #Y to 1 into A
//---------------------------------------------------------------

set_bit:
{
    ora bit_list,y
    rts
}

bit_list:
    .byte 1,2,4,8,16,32,64,128

//---------------------------------------------------------------
// which bit ? returns bit number of A into Y
// returns 1 to 7, 0 if not found
//---------------------------------------------------------------

which_bit:
{
    ldy #7
lookup_bit:
    and bit_list,y
    bne found
    bpl lookup_bit
found:
    iny
    rts
}

//---------------------------------------------------------------
// is_digit : C=1 if A is a digit, else C=0
//---------------------------------------------------------------

is_digit:
{
    pha
    clc
    adc #$ff-'9'
    adc #'9'-'0'+1
    pla
    rts
}

