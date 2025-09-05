//===============================================================
// BYG BIOS : BIOS functions for BYG Shell system
//---------------------------------------------------------------
// Calling rules : command # in A, parameter in R0,
// returns C=0 if OK, C=1 if KO
//===============================================================

#importonce

.encoding "ascii"

* = * "bios vectors"

.label vars=$cf00
.label buffer=$cf80
.label nb_params=$cfff
.label options_params=$cffe
.label scan_params=$cffd
.label options_values=$cfe0
.label OPT_PIPE=$80

.namespace bios 
{
//===============================================================
// BIOS functions list
//===============================================================

.label bios_exec=$cf70

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

* = * "BIOS code"

    // bios_exec : executes BIOS function, function # in A

bios_exec_ref:
    sta bios_exec+4
    jmp (bios_jmp)

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
    ldx #5
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
//---------------------------------------------------------------

do_error:
{
    bcs not_default
    mov r0, #error_default
not_default:
    lda CURSOR_COLOR
    pha
    lda #7
    sta CURSOR_COLOR
    swi pprint
    swi pprint_nl,error_msg
    pla
    sta CURSOR_COLOR
    jsr do_pipe_end
    sec
    rts
error_default:
    pstring("SHELL")
error_msg:
    pstring(" ERROR")
}


//---------------------------------------------------------------
// set_basic_string
//
// R0 = descripteur variable
//---------------------------------------------------------------

do_set_basic_string:
{
    lda $7a
    pha
    lda $7b
    pha
    
    mov $7a,r0
    jsr $b08b
    sta $49
    sty $4a
    push r0
    add r0, #3
    mov $64,r0
    jsr $aa52
    pop r0
    
    pla
    sta $7b
    pla
    sta $7a
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
// Uses channel #7 : 7,<device>,0
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
    
    ldx #9
    jsr CHKIN
    
    // skip 2 bytes
    jsr CHRIN
    jsr CHRIN
    clc
    rts

dirname:
    pstring("$")
}

//---------------------------------------------------------------
// directory_get_entry : reads one directory entry, output in r0
//
// ouput :
// C=1 : end, R0 = name, A = type
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

    ldx #9
    jsr CHKIN
    // skip 2 bytes
    jsr CHRIN
    jsr CHRIN
    
    lda STATUS
    bne fini
    
    // size
    jsr CHRIN
    jsr CHRIN
    
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

fini:
    pop r0
    sec
    rts

.label in_quotes=vars
.label type=vars+1
.label is_filter=vars+2
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
// param_get_value : returns value of parameter if it exists
//
// input : X = parameter name
// ouput : R0 = value, C=1 if found, C=0 if not found
//---------------------------------------------------------------

do_param_get_value:
{
    ldy #0
lookup:
    txa
    cmp options_values,y
    beq found
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
    ldy #0
    sec
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
// input : should call param_init before
// output : C=0 OK, C=1 Error
// todo ? flag to bypass nb_params check for CMD > OUT syntax
//---------------------------------------------------------------

do_pipe_init:
{
    jsr check_pipe_option
    bcs error
    
option_ok:
    lda options_params
    and #OPT_PIPE
    beq ok

    // get output name = last parameter
    ldx nb_params
    swi lines_goto, buffer
    
    // open file for write
    ldx #5
    sec
    swi file_open
    bcs error
    jsr do_pipe_output
ok:
    clc
    rts

check_pipe_option:
    lda options_params
    and #OPT_PIPE
    beq ok
    
    ldx nb_params
    cpx #2
    bpl ok
    sec
    rts
    
error:
    sec
    swi error, error_pipe_msg
    rts

error_pipe_msg:
    pstring("PIPE OPTION")
}

//---------------------------------------------------------------
// pipe_end : close output file
//---------------------------------------------------------------

do_pipe_end:
{
    lda options_params
    and #OPT_PIPE
    beq pas_option_pipe

    lda #3
    jsr CLRCHN
    ldx #5
    swi file_close
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
    lda options_params
    and #OPT_PIPE
    beq pas_init
    dec scan_params
    lda scan_params

pas_init:
    mov r4, r0

    jsr dec_params
    and #$7f
    jeq fini    
    
    tax
    swi lines_goto,buffer
    swi is_filter
    bcc no_filter

    lda scan_params
    and #$80
    bne deja_dir
    
    // filter : open dir
    lda scan_params
    ora #$80
    sta scan_params
    
    push r0
    swi directory_open
    clc
    mov r0,r4
    swi directory_get_entry
    pop r0

deja_dir:
    inc scan_params
    mov r1,r0
next_dir:
    sec
    mov r0, r4
    swi directory_get_entry
    bcs fini_dir
    cmp #0
    beq next_dir

no_filter:
    clc
    rts

fini_dir:
    swi directory_close
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
    ldy scan_params
    lda scan_params
    and #$7f
    sta scan_params
    dec scan_params
    tya
    and #$80
    ora scan_params
    sta scan_params
    ldy #0
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
    .label OPT_PIPE=128

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
    jsr mult10
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

prefix_pipe:
    .byte 2
    .byte 64
    .byte ':'
    pstring("@:")
suffix_pipe:
    pstring(",S,W")
msg_option_error:
    pstring("INVALID OPTION")
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
//===============================================================

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

    lda #13
    jsr CHROUT
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
// entrée : R0 = buffer de lecture (pstring)
// longueur buffer = pstring, longueur = max buffer
// C=0 lecture normale, C=1 arrêt si 0d ou 0a (ligne)
// X = id fichier
// sortie : buffer à jour et longueur à jour
// C=0 si pas fini, C=1 si EOF
//----------------------------------------------------

do_buffer_read:
{
    stc lecture_ligne
    jsr CHKIN

    swi str_len
    sta lgr_max
    sty nb_lu
lecture:
    jsr READST
    bne fin_lecture
    jsr CHRIN
    ldy lecture_ligne
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
    jsr CLRCHN
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
    jsr CLRCHN
    sec
    rts

.label lecture_ligne = vars
.label nb_lu = vars+1
.label lgr_max = vars+2
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
// file_open : ouverture fichier en lecture
// r0 : pstring nom, X = canal
// C=0 : lecture, C=1 : read/write
// retour C=0 OK, C=1 KO
// le fichier est ouvert en X,<device>,X
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
//
// manque :
//
// str_empty
// str_del
// str_chr
// str_rchr
// str_ncpy
//===============================================================

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
    cmp #'?'
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
//---------------------------------------------------------------

do_str_expand:
{
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
    clc
    rts

write_length:
    tya
    ldy #0
    mov (r1), a
    rts

quoted:
    inc r0
    inc r1
    dex

copy_expand:
    lda (zr0),y
    cmp #'%'
    beq do_special
    cmp #34
    beq fin_expand

copy_next:
    sta (zr1),y
    iny
    dex
    bne copy_expand

fin_expand:
    pop r1
    jsr write_length
    pla
    tax
    sec
    rts

do_special:
    inc r0
    lda (zr0),y
    cmp #'%'
    beq copy_next
    cmp #39
    bne not_quote
    lda #34
    jmp copy_next
not_quote:
    lda #'?'
    jmp copy_next
}

//---------------------------------------------------------------
// str_pat : pattern matching, C=1 si OK, C=0 sinon
// r0 : chaine à tester
// r1 : pattern
//---------------------------------------------------------------

do_str_pat:
{
    .label zstring = zr0
    .label zwild = zr1
    .label multiple = '*'
    .label single = '#'


    
    ldy #0
    lax (zstring),y
    inx
    stx lgr_string
    lax (zwild),y
    inx
    stx lgr_wild
    
    lda lgr_string
    cmp lgr_wild
    bpl lgr_ok
    clc
    rts
    
lgr_ok:
    iny
    sty pos_wild
    sty pos_string
    sty pos_cp
    sty pos_mp

while1:
    lda pos_string
    cmp lgr_string
    beq end_while1

    ldy pos_wild
    lda (zwild),y
    cmp #multiple
    beq end_while1

    ldy pos_wild
    lda (zwild),y
    ldy pos_string
    cmp (zstring),y
    beq suite_while1
    cmp #single
    beq suite_while1
    clc
    rts

suite_while1:
    inc pos_wild
    inc pos_string
    jmp while1

end_while1:

while2:
    lda pos_string
    cmp lgr_string
    beq end_while2

    ldy pos_wild
    //cmp lgr_wild
    //beq pas_etoile
    lda (zwild),y
    cmp #multiple
    bne pas_etoile

    inc pos_wild
    lda pos_wild
    cmp lgr_wild
    bne suite
    sec
    rts
suite:
    lda pos_wild
    sta pos_mp
    ldy pos_string
    iny
    sty pos_cp
    jmp while2

pas_etoile:
    ldy pos_wild
    //cpy lgr_wild
    //beq end_while2

    lda (zwild),y
    cmp #single
    beq ok_comp
    ldy pos_string
    cpy lgr_string
    beq end_while2
    cmp (zstring),y
    beq ok_comp
    
not_ok_comp:
    lda pos_mp
    sta pos_wild
    inc pos_cp
    lda pos_cp
    sta pos_string
    jmp while2

ok_comp:
    inc pos_wild
    inc pos_string
    lda pos_wild
    cmp lgr_wild
    beq ok_wild
    bcs ko_inc
ok_wild:
    lda pos_string
    cmp lgr_string
    beq ok_string
    bcs ko_inc
ok_string:
    jmp while2
ko_inc:
    sec
    rts
end_while2:

while3:
    ldy pos_wild
    cpy lgr_wild
    beq fini_wild
    lda (zwild),y
    cmp #multiple
    bne end_while3
    inc pos_wild
    jmp while3

end_while3:
    lda pos_wild
    cmp lgr_wild
    beq fini_wild
    clc
    rts
fini_wild:
    sec
    rts

.label lgr_string = vars
.label lgr_wild = vars+1
.label pos_wild = vars+2
.label pos_string = vars+3
.label pos_cp = vars+4
.label pos_mp = vars+5
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
    swi str_len
    cmp (zr1),y
    bne comp_ko
    tay
do_comp:
    lda (zr0),y
    cmp (zr1),y
    bne comp_ko
    dey
    bne do_comp
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
// pprint_int
// pprint_path
// pprint
// pprint_nl
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
    getbyte_r(0)
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
// set_bit : sets bit #Y to 1 into A
//---------------------------------------------------------------

set_bit:
{
    ora bit_list,y
    rts
bit_list:
    .byte 1,2,4,8,16,32,64,128
}

//---------------------------------------------------------------
// which bit ? returns bit number of A into Y
// returns 1 to 7, 0 if not found
//---------------------------------------------------------------

which_bit:
{
    ldy #7
lookup_bit:
    and set_bit.bit_list,y
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

//---------------------------------------------------------------
// mult10 : multiply R1 by 10, result in R1
//---------------------------------------------------------------

mult10:
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