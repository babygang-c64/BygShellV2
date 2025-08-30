* = $1000

.const buffer = $cf80
.const LGRNAM = $b7

    ldx LGRNAM
    lda buffer,x
    beq message_std
    lda #<buffer
    clc
    adc #1
    adc LGRNAM
    sta boucle+1
    lda #>buffer
    sta boucle+2

message_std:
    ldx #0
boucle:
    lda message,x
    beq fin
    jsr $FFD2
    inx
    bne boucle
fin:
    lda #13
    jsr $FFD2
    clc
    rts

message:
    .byte 5
    .text "HELLO WORLD LOW"
    .byte 154,0
