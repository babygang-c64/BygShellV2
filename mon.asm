//----------------------------------------------------
// mon : starts jiffymon
//----------------------------------------------------

#import "bios_entries_pp.asm"
#import "macros.asm"
#import "kernal.asm"

* = $c000

.word mon
pstring("mon")

mon:
{
    .label jiffymon = $e000
    
    sei
    lda #$35
    sta $01
    lda $e000
    cmp #$78
    bne not_loaded
    jmp $e000
    
not_loaded:
    lda #$37
    sta $01
    cli
    swi pprint_nl,error
    sec
    rts
    
error:
    pstring("Monitor not loaded")
}
