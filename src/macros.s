; Developed by Kristian Sloth Lauszus, 2020
; The code is released under the MIT License.

  .macro SET_BITS,X,MASK
    lda \X
    ora #\MASK  ; A |= M
    sta \X
  .endm

  .macro CLEAR_BITS,X,MASK
    lda \X
    and #~\MASK ; A &= ~M
    sta \X
  .endm

  .macro TOGGLE_BITS,X,MASK
    lda \X
    eor #\MASK  ; A ^= M
    sta \X
  .endm

  .macro INV
    eor #$FF    ; Flip all bits
    clc         ; Make sure the carry flag is cleared before the addition
    adc #1      ; Add one back
  .endm

  .macro ABS
    bpl \@.end  ; If A >= 0, then just return
    INV
    \@.end:
  .endm
