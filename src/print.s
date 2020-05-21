; Developed by Kristian Sloth Lauszus, 2020
; The code is released under the MIT License.

  .macro PRINT_STR,STR
      ldx #0
    \@loop:
      lda \STR,x
      beq \@end
      jsr print_char
      inx
      jmp \@loop
    \@end:
  .endm

; str = c < 10 ? c + '0' : c + 'A' - 10;
print_num:
  cmp #10               ; A < 10
  clc                   ; Make sure the carry flag is cleared before the addition(s)
  bmi .lt_10
  adc #('A' - 10 - '0') ; num = A + 'A' - 10 - '0'
.lt_10:
  adc #'0'              ; Add '0' to the number
  jsr print_char        ; Now print it as an ASCII character
  rts

print_i8_dec:
  pha
  lda #10
  sta divisor
  pla
  bpl print_u8    ; If A >= 0, then just print it as a normal number
  pha             ; Store the accumulator in the stack
  lda #'-'
  jsr print_char  ; print('-')
  pla             ; Pop the accumulator from the stack
  eor #$FF        ; Flip all bits
  clc             ; Make sure the carry flag is cleared before the addition
  adc #1          ; Add one back
  ; Fallthrough to 'print_u8'

print_u8:
  phx
  ; do {
  ;   c = A % base;
  ;   A /= base;
  ; } while (A != 0);
  ldx #0            ; i = 0
.digit_loop:
  pha               ; Store the original value
  jsr mod           ; Extract the bottom digit
  sta print8_num,x  ; Store the value in RAM
  pla               ; Restore the value before the modulus operator
  jsr div           ; Divide by 10, as we have now extracted the digit
  inx               ; i++
  cmp #0            ; A == 0
  bne .digit_loop   ; If the result is not 0, then keep looping

  ; Print the digits backward
  dex               ; for (x = i-1; x >= 0; i--)
.print_loop:
  lda print8_num,x  ; A = num[X]
  jsr print_num     ; print(A)
  dex               ; X--
  bpl .print_loop   ; Check if X is still positive

  plx
  rts

print_bin:
  pha

  ldy #7          ; Y = 7
.loop:
  asl             ; A =<< 1 (C <- [76543210] <- 0)
  pha
  bcs .high   ; Check carry bit
  lda #'0'        ; The MSB was low
  jmp .shift
.high:
  lda #'1'        ; The MSB was high
.shift:
  jsr print_char
  pla
  dey             ; Y--
  bpl .loop   ; Check if Y is still positive

  pla
  rts

print_u8_bin:
  pha
  lda #'0'
  jsr print_char
  lda #'b'
  jsr print_char
  lda #2
  sta divisor
  pla
  jsr print_u8
  rts

print_u8_dec:
  pha
  lda #10
  sta divisor
  pla
  jsr print_u8
  rts

print_u8_hex:
  pha
  lda #'0'
  jsr print_char
  lda #'x'
  jsr print_char
  lda #16
  sta divisor
  pla
  jsr print_u8
  rts

  ;lda #143
  ;jsr print_u8_dec
  ;lda #' '
  ;jsr print_char
  ;lda #$A3
  ;jsr print_u8_hex
  ;lda #' '
  ;jsr print_char

  ;lda #$AB
  ;jsr print_u8_hex
  ;lda #' '
  ;jsr print_char

  ;lda #-128
  ;jsr print_i8_dec
  ;lda #' '
  ;jsr print_char
