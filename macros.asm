//===============================================================
// MACROS
//
// ZP pseudo registers macros, mostly for use with
// the pre-processor
//===============================================================

#importonce

//---------------------------------------------------------------
// ZP pseudo registers
//
// 8x16bits registers r0 to r7
// ztmp -> b0/b1 for swap
// r0 : $03
// r1 : $05
// r2 : $96
// r3 : $b0
// r4 : $b2
// r5 : $b4
// r6 : $f7
// r7 : $f9
//---------------------------------------------------------------

.label zr0 = $03
.label zr0l = zr0
.label zr0h = zr0+1
.label zr1 = $05
.label zr1l = zr1
.label zr1h = zr1+1
.label zr2 = $b4
.label zr2l = zr2
.label zr2h = zr2+1
.label zr3 = $b0
.label zr3l = zr3
.label zr3h = zr3+1
.label zr4 = $b2
.label zr4l = zr4
.label zr4h = zr4+1
.label zr5 = $f7
.label zr5l = zr5
.label zr5h = zr5+1
.label zr6 = $96
.label zr6l = zr6
.label zr6h = zr6+1
.label zr7 = $f9
.label zr7l = zr7
.label zr7h = zr7+1

.label zsrc=zr6
.label zdest=zr7
.label reg_zsrc=6
.label reg_zdest=7

.print "zsrc=$"+toHexString(zsrc)
.print "zdest=$"+toHexString(zdest)

.label ztmp = $fb
.label zsave = $fc

//===============================================================
// macros for pstring, plist, ppath data structures
//===============================================================

//---------------------------------------------------------------
// pstring(<string>)
//
// defines a pascal type string with length in first byte
// (0 to 254 characters strings)
//---------------------------------------------------------------

.macro pstring(string_data)
{
 .byte string_data.size()
 .text string_data
}

//---------------------------------------------------------------
// plist : list object, list of pstring strings
//---------------------------------------------------------------

.macro plist(ptr_work)
{
 nb_elem:     // nb d'éléments dans la liste
    .byte 0
 ptr_data:    // début des données
    .word ptr_work+1
 ptr_free:    // libre = après les données
    .word ptr_work+1
 ptr_last:    // dernier élément
    .word ptr_work+1
}

//---------------------------------------------------------------
// ppath : parsed path object
//
// path format :
// [<device>:][[<partition>][/ ou //<path>/]][:<filename>]
// device et partition à 0 si absent
// type path : présence des différents éléments dans le path
// bit 0 = présence device, bit 1 = présence partition
// bit 2 = présence path,   bit 3 = présence nom
//---------------------------------------------------------------

.namespace PPATH
{
    .label WITH_DEVICE=1
    .label WITH_PARTITION=2
    .label WITH_PATH=4
    .label WITH_NAME=8
}

.macro ppath(lgr_path)
{
type:
    .byte 0
    // device and partition
device:
    .byte 0
partition:
    .byte 0
    // path and filename
path:
    .byte 0
filename:
    .byte 0
    .fill (lgr_path - 5),0
}

//===============================================================
// Pseudo register macros
//---------------------------------------------------------------
// R0 -> R7 in ZP, starting at zr0 address
// Y is not always preserved, X is always preserved
//
// Parameters rule : 
//      destination = source 
// Naming rule : 
//      ST<ore>[R<egister>/W<ord>] to [R<egister>/W<ord>]
//===============================================================

// todo, cf 65ce02 : BSR, PHW, PLW

//---------------------------------------------------------------
// <instruction>_<destination><source>
//
// instructions : mov, add, swp, inc
//
// destination / source :
//
// r = registre
// w = word
// a = accumumateur
// i = indirect
//
// mov_rw
// mov_wr
// add_ra
//---------------------------------------------------------------

//---------------------------------------------------------------
// stw_w(word, word2) : (word) = (word2)
// preserves Y
//
// mov addr1, addr2
//---------------------------------------------------------------

.macro stw_w(word1, word2)
{
    lda word2
    sta word1
    lda word2+1
    sta word1+1
}

//---------------------------------------------------------------
// sti_w(word, word2) : (word) = word2
// preserves Y
//
// mov addr1, #addr2
//---------------------------------------------------------------

.macro sti_w(word1, word2)
{
    lda #<word2
    sta word1
    lda #>word2
    sta word1+1
}

//---------------------------------------------------------------
// sti_r(reg, word) : reg = word
// preserves Y
//
// mov r<n>, #addr
//---------------------------------------------------------------

.macro sti_r(reg, word_param)
{
    lda #<word_param
    sta reg
    lda #>word_param
    sta reg+1
}

//---------------------------------------------------------------
// sta_r(reg) : reg = a
// preserves Y, A, X
//
// mov r1, a
//---------------------------------------------------------------

.macro sta_r(reg)
{
    sta reg
    lda #0
    sta reg+1
    lda reg
}

//---------------------------------------------------------------
// stw_r(reg, word) : reg = (word)
// preserves Y
//
// mov r<n>, addr
//---------------------------------------------------------------

.macro stw_r(reg, word_param)
{
    lda word_param
    sta reg
    lda word_param+1
    sta reg+1
}

//---------------------------------------------------------------
// str_w(word, reg) : (word) = reg
// preserves Y
//
// mov addr, r<n>
//---------------------------------------------------------------

.macro str_w(word, reg)
{
 lda reg
 sta word
 lda reg+1
 sta word+1
}

//---------------------------------------------------------------
// getbyte(reg)   : A = byte(reg)
// getbyte_r(reg) : A = byte(reg), reg++
// Y should be 0
// better be getnextbyte / getbyte
// mov a,(r0) / mov a,(r0++)
//---------------------------------------------------------------

.macro getbyte_r(reg)
{
    lda (reg),y
    inc reg
    bne pas_inc
    inc reg+1
pas_inc:
}

.macro getbyte(reg)
{
    lda (reg),y
}

//---------------------------------------------------------------
// setbyte(reg)   : byte(reg) = A
// setbyte_r(reg) : byte(reg) = A, reg++
// Y should be 0
// better be setbyte / setnextbyte
// mov (r0), a / mov (r0++), a
//---------------------------------------------------------------

.macro setbyte_r(reg)
{
    sta (reg),y
    inc reg
    bne pas_inc
    inc reg+1
pas_inc:
}

.macro setbyte(reg)
{
    sta (reg),y
}

//---------------------------------------------------------------
// subr_r : substract registers or address contents : 
// 
// reg1 = reg1 - reg2           : sub r0,r1
// (adr1) = (adr1) - (adr2)     : sub adr1,adr2
// reg1 = reg1 - (adr2)         : sub r1,adr2
// (adr1) = (adr1) - (reg2)     : sub adr1,r2
//---------------------------------------------------------------

.macro subr_r(reg1, reg2) {
    lda reg1
    sec
    sbc reg2
    sta reg1
    lda reg1+1
    sbc reg2+1
    sta reg1+1
}

//---------------------------------------------------------------
// subw_i : substract 16bits value to addresses contents or
// register
//
// (adr1) = (adr1) - value
// reg = reg - value
//---------------------------------------------------------------

.macro subw_i(adr1, value) {
    lda adr1
    sec
    sbc #<value
    sta adr1
    lda adr1+1
    sbc #>value
    sta adr1+1
}

//---------------------------------------------------------------
// subw_i8 : subtract 8-bit immediate value from 16-bit reg/mem
//
// reg = reg - imm8
// (adr) = (adr) - imm8
//---------------------------------------------------------------
.macro subw_i8(reg, imm8) {
    lda reg
    sec
    sbc #imm8
    sta reg
    bcs pas_dec
    dec reg+1
pas_dec:
}

//---------------------------------------------------------------
// sub_r(reg) : reg -= A
// Y preserved, A preserved
// sub reg, a
//---------------------------------------------------------------

.macro sub_r(reg)
{
    pha
    eor #$ff
    clc
    adc #1
    adc reg
    sta reg
    bcc pas_inc
    inc reg+1
pas_inc:
    pla
}


//---------------------------------------------------------------
// addi_w(addr) : (addr) += 8 bits immediate value
// Y preserved
// add addr, #<value>
//---------------------------------------------------------------

.macro addi_w(addr, value)
{
    clc
    lda #value
    adc addr
    sta addr
    bcc pas_inc
    inc addr+1
pas_inc:
}

//---------------------------------------------------------------
// addw_w(addr) : (addr) += 16 bits immediate value
// Y preserved
// add addr, #<value>
//---------------------------------------------------------------

.macro addw_w(addr, value)
{
    clc
    lda addr
    adc #<value
    sta addr
    lda addr+1
    adc #>value
    sta addr+1
}

//---------------------------------------------------------------
// adda_w(addr, add2) : (addr) += 16 bits att addr2
// Y preserved
// add addr, value at addr2
//---------------------------------------------------------------

.macro adda_w(addr, addr2)
{
    clc
    lda addr
    adc addr2
    sta addr
    lda addr+1
    adc addr2+1
    sta addr+1
}

//---------------------------------------------------------------
// addi_r(reg) : reg += 8 bits immediate value
// Y preserved
// add reg, #<value>
//---------------------------------------------------------------

.macro addi_r(reg, value)
{
    clc
    lda #value
    adc reg
    sta reg
    bcc pas_inc
    inc reg+1
pas_inc:    
}

//---------------------------------------------------------------
// addw_r(reg) : reg += 16 bits immediate value
// Y preserved
// add reg, #<value>
//---------------------------------------------------------------

.macro addw_r(reg, value)
{
    clc
    lda #<value
    adc reg
    sta reg
    lda reg+1
    adc #>value
    sta reg+1    
}

//---------------------------------------------------------------
// add_r(reg) : reg += A
// Y preserved
// add reg, a
//---------------------------------------------------------------

.macro add_r(reg)
{
    clc
    adc reg
    sta reg
    bcc pas_inc
    inc reg+1
pas_inc:    
}

//---------------------------------------------------------------
// addr_r(regdest, reg) : regdest += reg
// Y preserved
// ADD regdest, reg
//---------------------------------------------------------------

.macro addr_r(regdest, reg)
{
    clc
    lda regdest
    adc reg
    sta regdest
    lda regdest+1
    adc reg+1
    sta regdest+1
}

//---------------------------------------------------------------
// add8(adr) : (adr) = (adr)+A
// Y preserved
// ADD addr ,a
//---------------------------------------------------------------

.macro add8(adr)
{
    clc
    adc adr
    sta adr
    bcc pas_inc
    inc adr+1
pas_inc:    
}

//---------------------------------------------------------------
// stc(dest) : store carry to dest
// X, Y preserved
//---------------------------------------------------------------

.macro stc(dest)
{
    lda #0
    rol
    sta dest
}

//---------------------------------------------------------------
// ldc(addr) : get carry from addr (0 or 1)
// X, Y preserved
//---------------------------------------------------------------

.macro ldc(addr)
{
    lda addr
    ror
}

//---------------------------------------------------------------
// jeq(addr) : beq long
//---------------------------------------------------------------

.macro jeq(addr)
{
    bne no_jump
    jmp addr
no_jump:
}

//---------------------------------------------------------------
// jne(addr) : bne long
//---------------------------------------------------------------

.macro jne(addr)
{
    beq no_jump
    jmp addr
no_jump:
}

//---------------------------------------------------------------
// jcc(addr) : bcc long
//---------------------------------------------------------------

.macro jcc(addr)
{
    bcs no_jump
    jmp addr
no_jump:
}

//---------------------------------------------------------------
// jcs(addr) : bcs long
//---------------------------------------------------------------

.macro jcs(addr)
{
    bcc no_jump
    jmp addr
no_jump:
}

//---------------------------------------------------------------
// push_r(reg) : push reg or value at address on stack
// Y preserved
//---------------------------------------------------------------

.macro push_r(reg)
{
    lda reg
    pha
    lda reg+1
    pha
}

//---------------------------------------------------------------
// pop_r(reg) : pop reg / word from stack
// Y preserved
//---------------------------------------------------------------

.macro pop_r(reg)
{
    pla
    sta reg+1
    pla
    sta reg
}

//---------------------------------------------------------------
// str_r(reg_dest, reg) : reg_dest = reg
// Y preserved
//---------------------------------------------------------------

.macro str_r(reg_dest, reg)
{
    lda reg
    sta reg_dest
    lda reg+1
    sta reg_dest+1
}

//---------------------------------------------------------------
// sts_r(reg_dest, reg) : reg_dest = word at the address in reg
//
// mov r0, (r1)
//---------------------------------------------------------------

.macro sts_r(reg_dest, reg)
{
    ldy #0
    lda (reg),y
    sta ztmp
    iny
    lda (reg),y
    sta reg_dest+1
    lda ztmp
    sta reg_dest
    dey
}

//---------------------------------------------------------------
// stir_s(reg_dest, reg) : ((reg_dest)) = reg
// stores reg at address in (reg_dest)
//
// movi (r1), r0
//---------------------------------------------------------------

.macro stir_s(reg_dest, reg)
{
    ldy #0
    lda (reg_dest),y
    sta ztmp
    iny
    lda (reg_dest),y
    sta ztmp+1
    dey
    lda reg
    sta (ztmp),y
    iny
    lda reg+1
    sta (ztmp),y
    dey
}

//---------------------------------------------------------------
// str_s(reg_dest, reg) : (reg_dest) = reg
// stores reg at address in reg_dest
//
// mov (r1), r0
//---------------------------------------------------------------

.macro str_s(reg_dest, reg)
{
    ldy #0
    lda reg
    sta (reg_dest),y
    iny
    lda reg+1
    sta (reg_dest),y
    dey
}

//---------------------------------------------------------------
// sxy() : swap X and Y, preserves A
//---------------------------------------------------------------

.macro sxy()
{
    stx ztmp
    sty ztmp+1
    ldx ztmp+1
    ldy ztmp
}

//---------------------------------------------------------------
// swapr_r(reg1, reg2) : swaps reg1, reg2
// Y preserved
// swap r0, r1
//---------------------------------------------------------------

.macro swapr_r(reg1, reg2)
{
 lda reg1
 pha
 lda reg2
 sta reg1
 pla
 sta reg2

 lda reg1+1
 pha
 lda reg2+1
 sta reg1+1
 pla
 sta reg2+1
}

//---------------------------------------------------------------
// swapw_w(adr1, adr2) : swaps word content of adr1 with adr2
// Y preserved
// swap adr1, adr2
//---------------------------------------------------------------

.macro swapw_w(adr1, adr2)
{
 lda adr1
 pha
 lda adr2
 sta adr1
 pla
 sta adr2

 lda adr1+1
 pha
 lda adr2+1
 sta adr1+1
 pla
 sta adr2+1
}

//---------------------------------------------------------------
// dec_r(reg) : reg--
// Y preserved
// dec r0
//---------------------------------------------------------------

.macro dec_r(reg)
{
    lda reg
    bne pas_zero
    dec reg+1
pas_zero:
    dec reg
}

//---------------------------------------------------------------
// inc_r(reg) : reg++
// Y preserved
// inc r0
//---------------------------------------------------------------

.macro inc_r(reg)
{
    inc reg
    bne pas_zero
    inc reg+1
pas_zero:
}

//---------------------------------------------------------------
// inc_w(addr) : (addr)++
// incw <addr> / inw <addr>
//---------------------------------------------------------------

.macro inc_w(addr)
{
    inc addr
    bne pas_zero
    inc addr+1
pas_zero:
}

//---------------------------------------------------------------
// dec_w(addr) : (addr)--
// decw <addr> / dew <addr>
//---------------------------------------------------------------

.macro dec_w(addr)
{
    lda addr
    bne pas_zero
    dec addr+1
pas_zero:
    dec addr
}

//---------------------------------------------------------------
// swp : swap nybbles of register A
//---------------------------------------------------------------

.macro swp()
{
    asl
    adc #$80
    rol
    asl
    adc #$80
    rol
}

//===============================================================
// Compare and branch
//===============================================================

//---------------------------------------------------------------
// CMPW : 16bits compare
//
// cmpw adr1,adr2 or cmpw r1,adr or cmpw r1,r2 ...
//---------------------------------------------------------------

.macro cmpw(adr1,adr2)
{
    lda adr1+1
    cmp adr2+1
    bne done
    lda adr1
    cmp adr2
done:
}

//---------------------------------------------------------------
// CMPW_RI : 16bits compare with immediate value
//
// cmpw_ri adr1,#$1001 or cmpw_ri r1,#$2000
//---------------------------------------------------------------

.macro cmpw_ri(adr1,adr2)
{
    lda adr1+1
    cmp #adr2+1
    bne done
    lda adr1
    cmp #adr2
done:
}

//---------------------------------------------------------------
// CMPW_IR : 16bits compare with immediate value
//
// cmpw_ir #$2000,adr1 or cmpw_ir #$c000,r1
//---------------------------------------------------------------

.macro cmpw_ir(adr1,adr2)
{
    lda #adr1+1
    cmp adr2+1
    bne done
    lda #adr1
    cmp adr2
done:
}

//---------------------------------------------------------------
// BEQW : compare and branch if equal 
//
// ex : beqw r0,$1000,bingo    beq r2,r3,equal
//---------------------------------------------------------------

.macro beqw(adr1, adr2, branch)
{
    cmpw(adr1,adr2)
    beq branch
}

//---------------------------------------------------------------
// BLT : compare and branch if less than
//
// blt r0,r1,less_than
//---------------------------------------------------------------

.macro blt(adr1, adr2, branch)
{
    cmpw(adr1,adr2)
    bcc branch
}

//---------------------------------------------------------------
// BLE : compare and branch if less than or equal
//
// ble r0,r1,less_than_or_equal
//---------------------------------------------------------------

.macro ble(adr1, adr2, branch)
{
    cmpw(adr1,adr2)
    bcc branch
    beq branch
}

//---------------------------------------------------------------
// BGT : compare and branch if greater than
//
// bgt r0,r1,less_than
//---------------------------------------------------------------

.macro bgt(adr1, adr2, branch)
{
    cmpw(adr1,adr2)
    bcs branch
}

//---------------------------------------------------------------
// BGE : compare and branch if greater than or equal
//
// bge r0,r1,less_than_or_equal
//---------------------------------------------------------------

.macro bge(adr1, adr2, branch)
{
    cmpw(adr1,adr2)
    bcs branch
    beq branch
}

//===============================================================
// General purpose macros
//===============================================================

//---------------------------------------------------------------
// breakpoint : wait
//---------------------------------------------------------------

.macro breakpoint()
{
wait:
    inc $d020
    jmp wait    
}
