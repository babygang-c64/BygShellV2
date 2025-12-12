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
.label list_search=$0100+17
.label list_delete=$0100+19

//===============================================================
// bios_jmp : bios jump table
//===============================================================

bios_jmp:
    .word do_test
    .word do_list_init
    .word do_list_insert
    .word do_list_alloc
    .word do_list_search
    .word do_list_delete

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

.label NODE_OFFSET_NEXT = 0
.label NODE_OFFSET_LEN  = 2
.label NODE_OFFSET_DATA = 3

//---------------------------------------------------------------
// list_init : R0 = list root, R1 = heap start, 
//             X = blocks to allocate for list (high byte of size)
//---------------------------------------------------------------

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
// list_insert : R0 = list root, R1 = element to insert (pstring)
//               R1 structure: byte len, bytes data...
// Returns: C=0 OK, C=1 Error (Memory full)
//---------------------------------------------------------------

do_list_insert:
{
    ldy #0
    // Read length from R1
    lda (zr1),y 
    tax         // X = length of data
    
    push r0     // Save List Root
    push r1     // Save Data Source

    // Allocate memory: Needs X + 3 bytes (2 for Next ptr, 1 for Len)
    jsr do_list_alloc 
    bcc alloc_ok

    pop r1
    pop r0
    sec         // Allocation failed
    rts

alloc_ok:
    // R0 now points to the new allocated block
    
    // 1. Initialize new node
    // Next ptr = null ($0000)
    ldy #0
    tya
    sta (zr0),y // Next L
    iny
    sta (zr0),y // Next H
    iny
    
    // 2. Copy Data
    pop r1      // Restore source pointer
    
    // Write Length
    ldy #0
    lda (zr1),y // Get length
    ldy #NODE_OFFSET_LEN
    sta (zr0),y // Store length in node
    
    tax         // Use length as counter
    beq link_node // Handle empty string case

    // Copy string body
    // Simple copy using offsets logic
    ldy #NODE_OFFSET_DATA
    sty ztmp        // Offset counter
    
    // Helper variables
    mov r2, r1      // R2 = Source base
    
    // Adjust R2 to point to first data byte (skip length)
    inc r2
    
    ldy #0          // Y = 0 used for source indexing
    lax (zr1),y       // X = Length
copy_r1:
    lda (zr2),y     // Read from Source (R2+0)
    ldy ztmp        // Load Dest Offset
    sta (zr0),y     // Write to Dest (R0+Offset)
    inc ztmp
    ldy #0
    inc r2          // Advance Source Ptr
    dex
    bne copy_r1

link_node:
    // R3 = New Node (Currently in R0)
    mov r3, r0
    
    pop r0          // Restore List Root

    // 3. Append to list
    // Check if list is empty (Head == 0)
    ldy #LIST_OFFSET_HEAD
    jsr bios.bios_ram_get_byte
    sta zr2l
    iny 
    jsr bios.bios_ram_get_byte
    sta zr2h
    
    lda zr2l
    ora zr2h
    bne append_to_tail

    // List is empty: Head = NewNode (R3), Tail = NewNode (R3)
    ldy #LIST_OFFSET_HEAD
    lda zr3l
    sta (zr0),y
    iny
    lda zr3h
    sta (zr0),y
    
    // Update Tail as well
    ldy #LIST_OFFSET_TAIL
    lda zr3l
    sta (zr0),y
    iny
    lda zr3h
    sta (zr0),y
    
    clc
    rts

append_to_tail:
    // List not empty. 
    // 1. Read current Tail address
    ldy #LIST_OFFSET_TAIL
    jsr read_ptr_at_r0_to_r2  // R2 = Old Tail Address
    
    // 2. OldTail.Next = NewNode (R3)
    ldy #NODE_OFFSET_NEXT
    lda zr3l
    sta (zr2),y
    iny
    lda zr3h
    sta (zr2),y
    
    // 3. ListRoot.Tail = NewNode (R3)
    ldy #LIST_OFFSET_TAIL
    lda zr3l
    sta (zr0),y
    iny
    lda zr3h
    sta (zr0),y
    
    clc
    rts
}

//---------------------------------------------------------------
// list_alloc : R0 = list_root, X = len payload
// Returns: C=0, R0 = Allocated ptr
//          C=1, Full
//---------------------------------------------------------------

do_list_alloc:
{
    push r0
    stx ztmp // Save requested payload length
    
    // 1. Try Free List
    ldy #LIST_OFFSET_FREE
    jsr read_ptr_at_r0_to_r2 // R2 = First Free Block
    
    lda zr2l
    ora zr2h
    beq try_heap // No free blocks
    
    // Found a free block. Remove it from free list.
    // New Free Head = FreeBlock->Next
    ldy #NODE_OFFSET_NEXT
    jsr read_ptr_at_r2_to_r3 // R3 = Next Free
    
    pop r0 // Get Root
    push r0
    
    ldy #LIST_OFFSET_FREE
    lda zr3l
    sta (zr0),y
    iny
    lda zr3h
    sta (zr0),y
    
    mov r0, r2 // Return the block
    jmp alloc_success

try_heap:
    // 2. Allocate from Heap
    pop r0 // Get Root
    push r0
    
    // Check Space
    // Heap Ptr + Size <= Heap Max Page
    ldy #LIST_OFFSET_HEAP
    jsr read_ptr_at_r0_to_r2 // R2 = Current Heap Ptr
    
    mov r3, r2 // Save current heap ptr as result
    
    // Calculate required size: X (payload) + 3 (header)
    lda ztmp
    clc
    adc #3
    sta zsave // Store total size in zsave
    
    // Advance Heap Ptr
    lda zr2l
    clc
    adc zsave // Add total size
    sta zr2l
    lda zr2h
    adc #0
    sta zr2h
    
    // Check against Max
    ldy #LIST_OFFSET_HEAP_MAX
    jsr bios.bios_ram_get_byte
    cmp zr2h
    bcc heap_full
    beq heap_full

    // Update Heap Ptr in Root
    ldy #LIST_OFFSET_HEAP
    lda zr2l
    sta (zr0),y
    iny
    lda zr2h
    sta (zr0),y
    
    mov r0, r3 // Result

alloc_success:
    pop r3 // Clean stack
    clc
    rts

heap_full:
    pop r0
    sec
    rts
}

//---------------------------------------------------------------
// list_search : R0 = list root, R1 = pattern (pstring)
// Returns: C=0 Found (R0 = Node Ptr), C=1 Not Found
//---------------------------------------------------------------

do_list_search:
{
    // Start at Head
    ldy #LIST_OFFSET_HEAD
    jsr read_ptr_at_r0_to_r2  // R2 = Current Node
    
search_loop:
    // Check if R2 (Current) is NULL
    lda zr2l
    ora zr2h
    beq not_found

    // Compare Node Data with Pattern (R1)
    // 1. Compare Lengths
    ldy #NODE_OFFSET_LEN
    jsr bios_read_r2_y_to_a // A = Node.Len
    ldy #0
    cmp (zr1),y                // Compare with Pattern.Len
    bne next_node              // Length diff -> Next

    tax                        // X = Len
    beq found                  // Zero length matches zero length

    // 2. Compare Bytes
    // Save pointers
    push r2
    push r1
    
    // Adjust pointers to data start
    inc r1

    // Node data offset is +3, but R2 is base.
    ldy #NODE_OFFSET_DATA
    sty ztmp // Node offset
    
cmp_loop:
    ldy ztmp
    jsr bios_read_r2_y_to_a  // Read Node[y]
    pha
    ldy #0
    lda (zr1),y              // Read Pattern (Direct)
    sta zsave                // Store pattern char in zsave
    pla
    cmp zsave                // Compare
    bne match_fail
    
    // Advance
    inc r1
    inc ztmp
    dex
    bne cmp_loop

    // Match Success
found:
    pop r1
    pop r2
    mov r0, r2  // Return Node in R0
    clc
    rts

match_fail:
    pop r1
    pop r2
    
next_node:
    // Move to Next Node: R2 = R2->Next
    ldy #NODE_OFFSET_NEXT
    jsr read_ptr_at_r2_to_r2
    jmp search_loop

not_found:
    sec
    rts
}

//---------------------------------------------------------------
// list_delete : R0 = list root, R1 = node to delete
// Returns: C=0 OK, C=1 Not found/Error
//---------------------------------------------------------------

do_list_delete:
{
    push r0 // Save root
    mov r3, r0 // R3 = Previous Node Pointer (or location holding pointer)
    
    ldy #LIST_OFFSET_HEAD
    jsr read_ptr_at_r0_to_r2 // R2 = Current Node (Head)
    
    // If Head is null, empty list
    lda zr2l
    ora zr2h
    jeq del_not_found
    
    // Check if Head is the node to delete
    lda zr2l
    cmp zr1l
    bne find_predecessor
    lda zr2h
    cmp zr1h
    bne find_predecessor
    
    // Deleting Head
    // New Head = Head->Next
    ldy #NODE_OFFSET_NEXT
    jsr read_ptr_at_r2_to_r3 // R3 = Head->Next
    
    pop r0 // Restore Root
    push r0
    ldy #LIST_OFFSET_HEAD
    lda zr3l
    sta (zr0),y
    iny
    lda zr3h
    sta (zr0),y
    
    // If list became empty (New Head is NULL), tail must be cleared too
    lda zr3l
    ora zr3h
    bne free_node
    
    // List is now empty, fix tail
    ldy #LIST_OFFSET_TAIL
    lda #0
    sta (zr0),y
    iny
    sta (zr0),y
    jmp free_node

find_predecessor:
    // Loop to find node R1, keeping track of Previous (R3)
    // R2 is current.
    
    mov r3, r2 // Prev = Current
    
    // Current = Current->Next
    ldy #NODE_OFFSET_NEXT
    jsr read_ptr_at_r2_to_r2
    
    // Check End of List
    lda zr2l
    ora zr2h
    jeq del_not_found
    
    // Check Match
    lda zr2l
    cmp zr1l
    bne find_predecessor
    lda zr2h
    cmp zr1h
    bne find_predecessor
    
    // Found it at R2. Prev is R3.
    // Prev->Next = Current->Next
    
    // Get Current->Next into R4
    ldy #NODE_OFFSET_NEXT
    jsr bios.bios_ram_get_byte
    sta zr4l
    iny
    jsr bios.bios_ram_get_byte
    sta zr4h
    
    // Write R4 to Prev->Next
    ldy #NODE_OFFSET_NEXT
    lda zr4l
    sta (zr3),y
    iny
    lda zr4h
    sta (zr3),y
    
    // If we deleted the Tail (Next was NULL), Prev becomes the new Tail
    lda zr4l
    ora zr4h
    bne free_node
    
    // Update Tail in Root
    pop r0 // Get Root
    push r0
    ldy #LIST_OFFSET_TAIL
    lda zr3l // Prev
    sta (zr0),y
    iny
    lda zr3h
    sta (zr0),y

free_node:
    pop r0 // Restore Root
    
    // Add R1 (Deleted Node) to Free List
    // R1->Next = Root->Free
    ldy #LIST_OFFSET_FREE
    jsr read_ptr_at_r0_to_r2 // R2 = Old Free Head
    
    ldy #NODE_OFFSET_NEXT
    lda zr2l
    sta (zr1),y
    iny
    lda zr2h
    sta (zr1),y
    
    // Root->Free = R1
    ldy #LIST_OFFSET_FREE
    lda zr1l
    sta (zr0),y
    iny
    lda zr1h
    sta (zr0),y
    
    clc
    rts

del_not_found:
    pop r0
    sec
    rts
}

//---------------------------------------------------------------
// Helpers
//---------------------------------------------------------------

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

// Read Word at (R0)+Y into R2
read_ptr_at_r0_to_r2:
    jsr bios.bios_ram_get_byte
    sta zr2l
    iny
    jsr bios.bios_ram_get_byte
    sta zr2h
    rts

// Read Word at (R2)+Y into R2 (Follow pointer)
read_ptr_at_r2_to_r2:
    jsr bios_read_r2_y_to_a
    pha 
    iny
    jsr bios_read_r2_y_to_a
    sta zr2h
    pla
    sta zr2l
    rts

// Read Word at (R2)+Y into R3
read_ptr_at_r2_to_r3:
    jsr bios_read_r2_y_to_a
    pha 
    iny
    jsr bios_read_r2_y_to_a
    sta zr3h
    pla
    sta zr3l
    rts

// Read Byte at (R2)+Y
bios_read_r2_y_to_a:
    // Wraps bios call which likely reads (ZR0),Y
    lda zr0l; pha; lda zr0h; pha // Save R0
    lda zr2l; sta zr0l
    lda zr2h; sta zr0h
    
    jsr bios.bios_ram_get_byte
    sta zdest // Save result in zdest
    
    pla; sta zr0h; pla; sta zr0l // Restore R0
    lda zdest
    rts




}

start_cartridge:
    brk



bank1_top:
.fill $a000-*, $00
