; Developed by Kristian Sloth Lauszus, 2020
; The code is released under the MIT License.

mod:
  ; Use fast functions if possible
  pha
  lda divisor
  cmp #2
  beq _mod2
  cmp #4
  beq _mod4
  cmp #8
  beq _mod8
  cmp #16
  beq _mod16
  pla
  ; Fallback to using a loop

_mod:
  sec             ; Set the carry bit
.loop:
  sbc divisor     ; Subtract x from the accumulator
  bcs .loop       ; Keep branching as long as the result is has not rolled over (carry bit is set)
  adc divisor     ; Add x back to the accumulator, so we get the number before it rolled over
  rts             ; The result is stored in the accumulator

_mod2:
  pla
mod2:
  ; x % 2 = x & (2 - 1)
  and #1
  rts

_mod4:
  pla
mod4:
  ; x % 4 = x & (4 - 1)
  and #3
  rts

_mod8:
  pla
mod8:
  ; x % 8 = x & (8 - 1)
  and #7
  rts

_mod16:
  pla
mod16:
  ; x % 16 = x & (16 - 1)
  and #15
  rts

mod10:
  pha
  lda #10
  sta divisor
  pla
  jsr _mod
  rts

; https://codebase64.org/doku.php?id=base:8bit_divide_by_constant_8bit_result
; div10_const:
;   ; Divide by 10
;   ; 17 bytes, 30 cycles
;   lsr       ; A =>> 1
;   sta temp  ; temp = A
;   lsr       ; A =>> 1
;   adc temp  ; A = A + temp + C
;   ror       ; A = (C << 7) | (A >> 1)
;   lsr       ; A =>> 1
;   lsr       ; A =>> 1
;   adc temp  ; A = A + temp + C
;   ror       ; A = (C << 7) | (A >> 1)
;   adc temp  ; A = A + temp + C
;   ror       ; A = (C << 7) | (A >> 1)
;   lsr       ; A =>> 1
;   lsr       ; A =>> 1
;   rts

div:
  ; Use fast functions if possible
  pha
  lda divisor
  cmp #2
  beq _div2
  cmp #4
  beq _div4
  cmp #8
  beq _div8
  cmp #16
  beq _div16
  pla
  ; Fallback to using a loop

_div:
  phx
  ldx #-1         ; X = -1
  sec             ; Set the carry bit
.loop:
  inx             ; X++
  sbc divisor     ; A -= divisor
  bcs .loop       ; Check if the value has overflowed
  txa             ; A = X
  plx
  rts             ; The result is stored in the accumulator

_div2:
  pla
div2:
  ; Shift right once
  lsr
  rts

_div4:
  pla
div4:
  ; Shift right twice
  lsr
  lsr
  rts

_div8:
  pla
div8:
  ; Shift right 3 times
  lsr
  lsr
  lsr
  rts

_div16:
  pla
div16:
  ; Shift right 4 times
  lsr
  lsr
  lsr
  lsr
  rts

div10:
  pha
  lda #10
  sta divisor
  pla
  jsr _div
  rts

mul:
  ; Use fast functions if possible
  pha
  lda divisor
  cmp #2
  beq _mul2
  cmp #4
  beq _mul4
  cmp #8
  beq _mul8
  cmp #16
  beq _mul16
  pla
  ; Fallback to using a loop

  phx
  ldx divisor
  sta divisor ; Re-use the variable to store the original value of A
  clc         ; Clear the carry bit
.loop:
  dex         ; X--
  beq .end    ; X > 0
  adc divisor ; A += divisor
  jmp .loop
.end:
  plx
  rts         ; The result is stored in the accumulator

_mul2:
  pla
mul2:
  ; Shift left once
  asl
  rts

_mul4:
  pla
mul4:
  ; Shift left twice
  asl
  asl
  rts

_mul8:
  pla
mul8:
  ; Shift right 3 times
  asl
  asl
  asl
  rts

_mul16:
  pla
mul16:
  ; Shift right 4 times
  asl
  asl
  asl
  asl
  rts

mul5:
  pha
  lda #5
  sta divisor
  pla
  jsr mul
  rts

atan2_quadrant:
  ; Used to get the quadrant identifier used for the atan2 functions below.
  ;   $00 = x
  ;   $01 = y
  ;
  ; The quadrant identifier will be stored in the Y register.
  ; Where the quadrants are defined as:
  ;      --- ---
  ;     | 1 | 0 |
  ;      --- ---
  ;     | 3 | 2 |
  ;      --- ---
  ldy #$00    ; Initialize Y = 0

  ; Check the x-value
  lda $00
  bpl .x_pos  ; Check if the x-value is position
  iny         ; Y is now 1
.x_pos:
  ; Check the y-value
  lda $01
  bpl .y_pos  ; Check if the y-value is position
  iny
  iny         ; Y is now 2 (if x was positive) or 3 (if x was negatvie)
.y_pos:
  rts

; Modified Konami's Castlevania II NES atan2 code, but expanded to return an 8-bit angle instead.
; https://www.reddit.com/r/programming/comments/3e7ghi/discrete_arctan_in_6502/ctdg687?utm_source=share&utm_medium=web2x
; https://bisqwit.iki.fi/kala/atan2_cv2.txt
atan2:
  ; Y = quadrant identifier
  ; Where the quadrants are defined as:
  ;      --- ---
  ;     | 1 | 0 |
  ;      --- ---
  ;     | 3 | 2 |
  ;      --- ---
  ;
  ; $00 = absolute x (xdiff)
  ; $01 = absolute y (ydiff)
  ; Only the most significant 3 bits of each coordinate are considered.
  ;
  ; $02 = used as a temporary variable
  ;
  ; Result = A = angle (00..FF)
  ;     When Y=0: A = (0x00 + ArctanTable[(xdiff & 0xF0) | (ydiff >> 4)])
  ;     When Y=1: A = (0x40 + ArctanTable[(ydiff & 0xF0) | (xdiff >> 4)])
  ;     When Y=2: A = (0xC0 + ArctanTable[(ydiff & 0xF0) | (xdiff >> 4)])
  ;     When Y=3: A = (0x80 + ArctanTable[(xdiff & 0xF0) | (ydiff >> 4)])
  ;
  ; The 8-bit lookup table is created with the following encoding:
  ;     yyyyxxxx
  ;
  ; An offset of z*90 deg is then added to the value depending on the quadrant used.
  ; Note however that the output angle uses the conventional quadrant encoding:
  ;      --- ---
  ;     | 1 | 0 |
  ;      --- ---
  ;     | 2 | 3 |
  ;      --- ---
  tya
  ; Check if we need to swap the xdiff and ydiff
  sec       ; Set carry flag
  sbc #$01  ; Carry gets cleared if Y = 0
  cmp #$02  ; Carry gets cleared if Y = 3
  bcs .no_swap
  ; Swap xdiff and ydiff if Y = 0 or Y = 3
  lda $00
  sta $02
  lda $01
  sta $00
  lda $02
  sta $01
  ; No need to swap if Y = 1 or Y = 2
.no_swap:
  ; Now we can look up the offset in the table where 0x40 corresponds to 90 deg
  lda .atan2_offsets,y
  sta $02

  ; Divide xdiff (Y = 1 or Y = 2) or ydiff (Y = 0 or Y = 3) by 16
  lda $00
  jsr div16
  sta $00

  ; Get the top 4-bits of ydiff (Y = 1 or Y = 2) or xdiff (Y = 0 or Y = 3)
  lda $01
  and #$F0

  ; Get the index for the loockup table by bitwise OR the two values
  ora $00

  ; Look up the result in the lookup table
  tay
  lda .atan2_lut,y

  ; Add the 'atan2_offsets' to the result, so we get the angle in the right quadrant
  clc
  adc $02

  rts

.atan2_lut:
  ; Perfectly matches round(0x80/pi * atan(((a>>4) + 0.059) / ((a&15) + 0.059))) where a = 0..255
  ;  or equivalently: round(0x80/pi * atan2((a>>4) + 0.059, (a&15) + 0.059))
  ; The script used for generating this lookup table can be found in atan2_lut.py
  .byte $20,$02,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .byte $3E,$20,$13,$0E,$0A,$08,$07,$06,$05,$05,$04,$04,$04,$03,$03,$03
  .byte $3F,$2D,$20,$18,$13,$10,$0D,$0C,$0A,$09,$08,$07,$07,$06,$06,$06
  .byte $3F,$32,$28,$20,$1A,$16,$13,$11,$0F,$0D,$0C,$0B,$0A,$09,$09,$08
  .byte $3F,$36,$2D,$26,$20,$1C,$18,$15,$13,$11,$10,$0E,$0D,$0C,$0B,$0B
  .byte $40,$38,$30,$2A,$24,$20,$1C,$19,$17,$15,$13,$11,$10,$0F,$0E,$0D
  .byte $40,$39,$33,$2D,$28,$24,$20,$1D,$1A,$18,$16,$14,$13,$12,$11,$10
  .byte $40,$3A,$34,$2F,$2B,$27,$23,$20,$1D,$1B,$19,$17,$16,$14,$13,$12
  .byte $40,$3B,$36,$31,$2D,$29,$26,$23,$20,$1E,$1C,$1A,$18,$17,$15,$14
  .byte $40,$3B,$37,$33,$2F,$2B,$28,$25,$22,$20,$1E,$1C,$1A,$19,$17,$16
  .byte $40,$3C,$38,$34,$30,$2D,$2A,$27,$24,$22,$20,$1E,$1C,$1B,$19,$18
  .byte $40,$3C,$39,$35,$32,$2F,$2C,$29,$26,$24,$22,$20,$1E,$1D,$1B,$1A
  .byte $40,$3C,$39,$36,$33,$30,$2D,$2A,$28,$26,$24,$22,$20,$1E,$1D,$1C
  .byte $40,$3D,$3A,$37,$34,$31,$2E,$2C,$29,$27,$25,$23,$22,$20,$1E,$1D
  .byte $40,$3D,$3A,$37,$35,$32,$2F,$2D,$2B,$29,$27,$25,$23,$22,$20,$1F
  .byte $40,$3D,$3A,$38,$35,$33,$30,$2E,$2C,$2A,$28,$26,$24,$23,$21,$20

.atan2_offsets:
  ; The offsets are simply a list of 0, 90, 270, 180 degrees
  .byte $00,$40,$C0,$80

; Original 6-bit version with comments:
; atan2:
;   ; Y = quadrant identifier
;   ; Where the quadrant is are defined as:
;   ;      --- ---
;   ;     | 1 | 0 |
;   ;      --- ---
;   ;     | 3 | 2 |
;   ;      --- ---
;   ;
;   ; $00 = absolute x (xdiff)
;   ; $01 = absolute t (ydiff)
;   ; Only the most significant 3 bits of each coordinate are considered.
;   ;
;   ; $02 = used as a temporary variable
;   ;
;   ; Result = A = angle (00..3F)
;   ;     When Y=0: A = (0x00 + ArctanTable[xdiff/32*8 + ydiff/32])
;   ;     When Y=1: A = (0x10 + ArctanTable[ydiff/32*8 + xdiff/32])
;   ;     When Y=2: A = (0x30 + ArctanTable[ydiff/32*8 + xdiff/32]) & 0x3F
;   ;     When Y=3: A = (0x20 + ArctanTable[xdiff/32*8 + ydiff/32])
;   ;
;   ; This can be achieved using the following bitwise operators:
;   ;     When Y=0: A = (0x00 + ArctanTable[(xdiff >> 2) & 0xF8) | (ydiff >> 5)])
;   ;     When Y=1: A = (0x10 + ArctanTable[(ydiff >> 2) & 0xF8) | (xdiff >> 5)])
;   ;     When Y=2: A = (0x30 + ArctanTable[(ydiff >> 2) & 0xF8) | (xdiff >> 5)]) & 0x3F
;   ;     When Y=3: A = (0x20 + ArctanTable[(xdiff >> 2) & 0xF8) | (ydiff >> 5)])
;   ;
;   ; The 6-bit lookup table is created with the following encoding:
;   ;     00yyyxxx
;   ;
;   ; An offset of z*90 deg is then added to the value depending on the quadrant used.
;   ; Note however that the output angle uses the conventional quadrant encoding:
;   ;      --- ---
;   ;     | 1 | 0 |
;   ;      --- ---
;   ;     | 2 | 3 |
;   ;      --- ---
;   tya
;   ; Check if we need to swap the xdiff and ydiff
;   sec       ; Set carry flag
;   sbc #$01  ; Carry gets cleared if Y = 0
;   cmp #$02  ; Carry gets cleared if Y = 3
;   bcs .no_swap
;   ; Swap xdiff and ydiff if Y = 0 or Y = 3
;   lda $00
;   sta $02
;   lda $01
;   sta $00
;   lda $02
;   sta $01
;   ; No need to swap if Y = 1 or Y = 2
; .no_swap:
;   ; Now we can look up the offset in the table where 0x10 corresponds to 90 deg
;   lda .atan2_offsets,y
;   sta $02

;   ; Divide xdiff (Y = 1 or Y = 2) or ydiff (Y = 0 or Y = 3) by 32
;   lda $00
;   jsr div16
;   lsr
;   sta $00

;   ; This effectly divides ydiff (Y = 1 or Y = 2) or xdiff (Y = 0 or Y = 3)
;   ; by 32 and then multiplies by 8
;   lda $01
;   lsr
;   lsr
;   and #$F8

;   ; Finally we combine the two values into a 6-bit value by adding them together:
;   ;   (xdiff/32*8) + (ydiff/32)
;   clc
;   adc $00

;   ; Look up the result in the lookup table
;   tay
;   lda .atan2_lut,y

;   ; Add the 'atan2_offsets' to the result, so we get the angle in the right quadrant
;   clc
;   adc $02

;   ; Make sure the output angle is 6-bits
;   and #$3F

;   rts

; .atan2_lut:
;   ; Perfectly matches round(0x20/pi * atan(((a>>3) + 0.11) / ((a&7) + 0.11))) where a = 0..63
;   ;  or equivalently: round(0x20/pi * atan2((a>>3) + 0.11, (a&7) + 0.11))
;   .byte $08,$01,$01,$00,$00,$00,$00,$00,$0F,$08,$05,$03,$03,$02,$02,$02
;   .byte $0F,$0B,$08,$06,$05,$04,$03,$03,$10,$0D,$0A,$08,$07,$06,$05,$04
;   .byte $10,$0D,$0B,$09,$08,$07,$06,$05,$10,$0E,$0C,$0A,$09,$08,$07,$06
;   .byte $10,$0E,$0D,$0B,$0A,$09,$08,$07,$10,$0E,$0D,$0C,$0B,$0A,$09,$08

; .atan2_offsets:
;   ; The offsets are simply a list of 0, 90, 270, 180 degrees
;   .byte $00,$10,$30,$20
