//----------------------------------------------------
// lsblk : list and identify the attached devices
//
// returns nb of devices in SH% and devices list 
// in SH$
//
// options : 
// Q = Quiet mode
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word lsblk
pstring("LSBLK")

lsblk:
{
    .label params_buffer = $cd00
    
    .label OPT_Q=1
    .label OPT_H=2

    sec
    swi param_init,buffer,options_lsblk
    jcs error
    
    lda options_params
    and #OPT_H
    bne help
    
    // swi pipe_init
    // jcs error

    ldy #0
    clc
    mov r0,#buffer1
    jsr do_lsblk
    mov r0,a
    swi return_int
    mov r0,#buffer1
    mov a,(r0)
    sta string_len
    swi set_basic_string,return_string

end:
    // swi pipe_end
    jsr CLRCHN
    clc
    rts

error:
    sec
    swi error
    rts

help:
    swi pprint_lines,help_msg
    sec
    rts

help_msg:
    pstring("*lsblk [-qh]")
    pstring(" List attached devices")
    pstring(" q = Quiet mode")
    pstring(" h = Help")
    .byte 0

options_lsblk:
    pstring("QH")

return_string:
    .text "SH$"
string_len:
    .byte 0
    .word buffer1
buffer1:
    .fill 80,0

buffer_int2str:
    pstring("0123456789ABCDEF")

//---------------------------------------------------------------
// lsblk : scan devices for disks, try to identify disk type
// 
// input : C=1 quiet mode, R0 = pstring for devices return
// output : A = nb of devices, X = 1st device found
//          updated pstring of devices
//---------------------------------------------------------------
// 00 - No serial device available
// 01 - foreign drive (MSD, Excelerator, Lt.Kernal, etc.)
// 41 - 1541 drive
// 71 - 1571 drive
// 81 - 1581 drive
// e0 - FD drive
// c0 - HD drive
// f0 - RD drive
// 80 - RAMLink
// if %11xxxxxx : has CMD abilities
//---------------------------------------------------------------

do_lsblk:
{
    stc affichage_lecteurs

    //-- raz liste et nb de devices
    ldy #0
    mov r2,r0
    sty first_device
    sty nb_devices
    tya
    mov (r2),a
    ldy #31

raz_devices:
    sta devices,y
    dey
    bpl raz_devices

    lda #8
    sta cur_device

test_listen:
    lda cur_device
    ldy #0
    sty STATUS
    jsr LISTEN
    lda #$ff
    jsr SECOND
    lda STATUS
    bpl dev_present
    jsr UNLSTN

next_device:
    inc cur_device
    lda cur_device
    cmp #31
    beq fin_test_listen
    bne test_listen

dev_present:
    lda first_device
    bne premier_deja_trouve
    lda cur_device
    sta first_device
premier_deja_trouve:
    ldy cur_device
    tya
    sta devices,y
    inc nb_devices
    bne next_device

fin_test_listen:

    //-- après test listen, recherche type drive
    ldy #8
    lda devices,y
    jeq boucle_drive

test_type_drive:

    sta cur_device
    jsr open_cmd
    ldx #<cmdinfo // test CMD drive
    ldy #>cmdinfo
    jsr send_cmd

    // retour commande, est-ce FD ?
    jsr CHRIN
    cmp #'F'
    bne pas_fd
    jsr CHRIN
    cmp #'D'
    bne test_cbm15xx

    lda #$e0
    jmp next_drive

pas_fd:
    // est-ce HD ?
    cmp #'H'
    bne pas_hd
    jsr CHRIN
    cmp #'D'
    bne test_cbm15xx

    lda #$c0
    jmp next_drive

pas_hd:
    // est-ce RL / RD ?
    cmp #'R'
    bne test_cbm15xx
    jsr CHRIN
    cmp #'D'
    bne pas_rd

    lda #$f0
    jmp next_drive

pas_rd:
    cmp #'L'
    bne test_cbm15xx

    lda #$80
    jmp next_drive


    //-- test 1541/1571
test_cbm15xx:
    mov r0, #cbminfo
    jsr send_test_next

    jsr CHRIN
    cmp #'5'
    bne test_cbm1581
    jsr CHRIN
    cmp #'4'
    bne pas_1541

    lda #41
    jmp next_drive

pas_1541:
    cmp #'7'
    bne test_cbm1581

    lda #71
    jmp next_drive

test_cbm1581:
    mov r0, #info1581
    jsr send_test_next

    jsr CHRIN
    cmp #'5'
    bne pas_cbm1581
    jsr CHRIN
    cmp #'8'
    bne pas_cbm1581

    lda #81
    jmp next_drive

    // other, valeur $01
pas_cbm1581:
    lda #1

next_drive:
    ldy cur_device
    sta devices,y
    jsr close_cmd

boucle_drive:
    inc cur_device
    lda cur_device
    cmp #31
    beq fin_lsblk
    ldy cur_device
    lda devices,y
    beq boucle_drive

    jmp test_type_drive

    // fin des tests, affiche la liste si pas en
    // mode silencieux
fin_lsblk:
    lda affichage_lecteurs
    bne pas_affichage
    jsr affiche_lecteurs

pas_affichage:
    mov r0, #devices
    lda nb_devices
    ldx first_device
    clc
    rts

send_test_next:
    jsr close_cmd
    jsr open_cmd
    ldx zr0l
    ldy zr0h
    jmp send_cmd


    // affichage des types de lecteurs identifiés
affiche_lecteurs:
    // swi pipe_output
    lda #0
    sta cur_device

aff_suivant:
    ldy cur_device
    lda devices,y
    beq pas_present

    // affiche numero:type
    pha
    tya
    jsr aff_numero_drive
    lda #':'
    jsr print_and_add_char
    pla
    jsr affiche_type

pas_present:
    inc cur_device
    lda cur_device
    cmp #31
    bne aff_suivant

fin_aff_total:
    lda #13
    jmp CHROUT

affiche_type:
    cmp #1
    bne aff_pas_autre
    swi pprint, msg_type_other
    mov r1,#msg_type_other
    mov r0,r2
    swi str_cat
    jmp fin_aff_type

aff_pas_autre:
    cmp #$80
    bne aff_pas_ram
    swi pprint, msg_type_ramlink
    mov r0,r2
    mov r1,#msg_type_ramlink
    swi str_cat
    jmp fin_aff_type

aff_pas_ram:
    cmp #$c0
    bne aff_15xx
    cmp #$e0
    bne aff_15xx
    cmp #$f0
    bne aff_15xx
    tax
    lda #32
    jsr print_and_add_char
    txa
    cmp #$e0
    bne aff_pas_e
    lda #'F'
    jsr print_and_add_char
    jmp aff_fin_hd
aff_pas_e:
    cmp #$c0
    bne aff_pas_c
    lda #'H'
    jsr print_and_add_char
    jmp aff_fin_hd
aff_pas_c:
    lda #'R'
    jsr print_and_add_char
aff_fin_hd:
    lda #'D'
    jsr print_and_add_char
    lda #32
    jsr print_and_add_char
    jmp fin_aff_type

aff_15xx:
    pha
    swi pprint,msg_type_15
    mov r0,r2
    mov r1,#msg_type_15
    swi str_cat
    pla
    cmp #41
    bne aff_pas41
    lda #'4'
    jmp fin_aff_15xx
aff_pas41:
    cmp #71
    bne aff_pas71
    lda #'7'
    jmp fin_aff_15xx
aff_pas71:
    lda #'8'
fin_aff_15xx:
    jsr print_and_add_char
    lda #'1'
    jsr print_and_add_char

fin_aff_type:
    lda #32
    jmp print_and_add_char

    //-- ouverture pour envoi commande
open_cmd:
    lda #$0f // 15,dev,15
    tay
    ldx cur_device
    jsr SETLFS
    lda #7 // longueur commande m-r
    rts

    //-- envoi commande
send_cmd:
    jsr SETNAM
    jsr OPEN
    ldx #$0f  // 15
    jmp CHKIN // redirect input

    //-- fermeture cmd
close_cmd:
    ldx #15
    txa
    jsr CLOSE
    jmp CLRCHN

aff_numero_drive:
    sta zr0l
    lda #0
    sta zr0h
    ldx #%00000011
    swi pprint_int
    ldy #5
    mov a,(r0)
    jsr print_and_add_char.no_print
    iny
    mov a,(r0)
    jsr print_and_add_char.no_print
    ldy #0
    rts

cmdinfo: // CMD info at $fea4 in drive ROM
    .text "M-R"
    .byte $a4,$fe,$02,$0d
cbminfo: // 1541, 1571, info at $e5c5
    .text "M-R"
    .byte $c5,$e5,$02,$0d
info1581: // 1581, info at $a6e8
    .text "M-R"
    .byte $e8,$a6,$02,$0d

msg_type_other:
    pstring("OTHR")
msg_type_ramlink:
    pstring("RAML")
msg_type_15:
    pstring("15")

first_device:
    .byte 0
cur_device:
    .byte 0
affichage_lecteurs:
    .byte 0
nb_devices:
    .byte 0
devices:
    .fill 32,0
}

//---------------------------------------------------------------
// print_and_add_char : add single character A to pstring in R2
// and print it
//---------------------------------------------------------------

print_and_add_char:
{
    jsr CHROUT
no_print:
    sty save_y
    pha
    ldy #0
    mov a,(r2)
    tay
    iny
    pla
    mov (r2),a
    tya
    ldy #0
    mov (r2),a
    ldy save_y
    rts
save_y:
    .byte 0
}

}