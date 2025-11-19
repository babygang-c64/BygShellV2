    // bios_exec : executes BIOS function, function # in A

#import "macros.asm"

.namespace bios_exec
{
* = $cf40
exec:
    sta exec+4
    jmp ($8000)

ram_get_byte:
    sei
    dec $01
    lda (zr0l),y
    inc $01
    cli
    rts
    
exec_bank:
    sei
    pha
    lda $de00
    sta restore
    lda bank_target:#0
    sta $de00
    pla
    jsr exec
    pha
    lda restore:#0
    sta $de00
    pla
    cli
    rts
}
