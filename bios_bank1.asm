//===============================================================
// BYG SHELL : Command line Shell - BIOS BANK 1
//
// 2024-2025 Babygang
//===============================================================


#import "kernal.asm"
#import "macros.asm"


* = $8000

.word start_cartridge   // cold start vector
.word start_cartridge   // warm start vector
.byte $c3,$c2,$cd
.text "80"

.namespace bios 
{

// Under cartridge ROM

.label datapool_size = 16
.label datapool_root   = $8000

    // RAM entry points

    .label bios_exec=$cf40      // SWI entry point
    .label bios_ram_get_byte=bios_exec+6


//===============================================================
// BIOS functions list
//===============================================================

.label test=$0100+9
.label list_init=$0100+11
.label list_insert=$0100+13
.label list_alloc=$0100+15

//===============================================================
// bios_jmp : bios jump table
//===============================================================

bios_jmp:
    .word do_test
    .word do_list_init
    .word do_list_insert
    .word do_list_alloc

do_test:
    inc $d020
    rts

//===============================================================
// list : chained list
//
// list_init
// list_insert
// list_delete
//===============================================================

//---------------------------------------------------------------
// list_init : R0 = list root, R1 = heap start, 
//             X = blocks to allocate for list
//
// list_root :
// list_head = 1 word   - head of used nodes
// list_tail = 1 word   - tail of used nodes
// list_free = 1 word   - head of freed nodes
// list_heap = 1 word   - next free heap location
// list_max  = 1 byte   - high byte of max heap + 1
//---------------------------------------------------------------

.label LIST_OFFSET_HEAD = 0
.label LIST_OFFSET_TAIL = 2
.label LIST_OFFSET_FREE = 4
.label LIST_OFFSET_HEAP = 6
.label LIST_OFFSET_HEAP_MAX = 8

do_list_init:
{
    ldy #0
    tya
raz:
    sta (zr0),y
    iny
    cpy #6
    bne raz
    lda zr1l
    sta (zr0),y
    iny
    lda zr1h
    sta (zr0),y
    iny
    txa
    sec
    adc zr1h
    sta (zr0),y
    ldy #0
    rts
}

//---------------------------------------------------------------
// list_insert : R0 = list root, R1 = element to insert
//---------------------------------------------------------------

do_list_insert:
{
    ldy #0
    mov a,(r1)
    tax
    push r0

    jsr do_list_alloc
    bcc alloc_ok

    pop r0
    sec
    rts

    // allocation OK, write at r0 : 
    // next element = word 0
    // copy of r1
    // save allocation in r2

alloc_ok:
    mov r2,r0
    ldy #0
    tya
    mov (r0++),a
    mov (r0++),a
    mov a,(r1)
    tay
copy_r1:
    mov a,(r1)
    mov (r0),a
    dey
    bpl copy_r1

    // update head / tail

    pop r0
    // if head is null, new head = r2
    ldy #LIST_OFFSET_HEAD
    lda (zr0l),y
    iny
    ora (zr0l),y
    bne already_head

    dey
    lda zr2l
    sta (zr0),y
    iny
    lda zr2h
    sta (zr0),y
    ldy #LIST_OFFSET_TAIL
    lda zr2l
    sta (zr0),y
    iny
    lda zr2h
    sta (zr0),y
    
already_head:
    // and insert in tail
    clc
    rts
}

//---------------------------------------------------------------
// list_alloc : R0 = list_root, X = longueur pstring
//
// C=0 OK, R0 = target
// C=1 full
//---------------------------------------------------------------

do_list_alloc:
{
    push r0
    // read list_free
    ldy #LIST_OFFSET_FREE
    jsr read_r0_at_r0
    
test_free:
    lda zr0l
    ora zr0h
    bne has_free

    // no free element or no free element big enough,
    // try to allocate from heap
no_free:
    pop r0
    ldy #LIST_OFFSET_HEAP_MAX
    jsr bios.bios_ram_get_byte
    sta ztmp
    ldy #LIST_OFFSET_HEAP
    jsr read_r0_at_r0
    push r0
    txa
    clc
    add r0,a
    add r0,#3
    lda zr0h
    cmp ztmp
    beq no_more_space

    // allocation OK, update next free heap position,
    // return heap position

    lda zr0l
    sta (zr0l),y
    iny
    lda zr0h
    sta (zr0l),y
    pop r0
    clc
    rts

    // heap full, C=1
no_more_space:
    pop r0
    sec
    rts
    
    // if free elements, look for one with X chars available
has_free:
    ldy #2
    mov r0,r2
    jsr bios.bios_ram_get_byte
    sta ztmp
    cpx ztmp
    bcs length_ok
    
    // length not ok, try next one
    ldy #0
    jsr read_r2_at_r0
    jmp test_free

length_ok:
    clc
    rts

read_r2_at_r0:
    jsr bios.bios_ram_get_byte
    sta zr2l
    iny
    jsr bios.bios_ram_get_byte
    sta zr2h
    rts

read_r0_at_r0:
    jsr bios.bios_ram_get_byte
    pha
    iny
    jsr bios.bios_ram_get_byte
    sta zr0h
    pla
    sta zr0l
    rts
}

}

start_cartridge:
    brk


bank1_top:
.fill $a000-*, $00
