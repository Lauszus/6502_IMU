; Developed by Kristian Sloth Lauszus, 2020
; The code is released under the MIT License.
;
; Handtuned delay functions

delay_1s:
  jsr delay_500ms
  jsr delay_500ms
  rts             ; 6 clock cycles

delay_500ms:
  jsr delay_400ms
  jsr delay_100ms
  rts             ; 6 clock cycles

delay_400ms:
  jsr delay_200ms
  jsr delay_200ms
  rts             ; 6 clock cycles

delay_300ms:
  jsr delay_200ms
  jsr delay_100ms
  rts             ; 6 clock cycles

delay_200ms:
  jsr delay_100ms
  jsr delay_100ms
  rts             ; 6 clock cycles

; https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/MC6800-AssemblyLProg.pdf
; (3+3+2)+(2+(2+3)*100+2+3)*197+(4+4+6) = 99901 us = ~100 ms
delay_100ms:
  phx       ; 3 clock cycles
  phy       ; 3 clock cycles
  ldx #197  ; 2 clock cycles
.x:
  ldy #100  ; 2 clock cycles
.y:
  dey       ; 2 clock cycles
  bne .y    ; 2/3 clock cycles
  dex       ; 2 clock cycles
  bne .x    ; 2/3 clock cycles
  plx       ; 4 clock cycles
  ply       ; 4 clock cycles
  rts       ; 6 clock cycles

; https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/MC6800-AssemblyLProg.pdf
; (3+3+2)+(2+(2+3)*10+2+2)*178+(4+4+6) = 9990 us = ~10 ms
delay_10ms:
  phx       ; 3 clock cycles
  phy       ; 3 clock cycles
  ldx #178  ; 2 clock cycles
.x:
  ldy #10   ; 2 clock cycles
.y:
  dey       ; 2 clock cycles
  bne .y    ; 2/3 clock cycles
  dex       ; 2 clock cycles
  bne .x    ; 2/3 clock cycles
  plx       ; 4 clock cycles
  ply       ; 4 clock cycles
  rts       ; 6 clock cycles

; https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/MC6800-AssemblyLProg.pdf
; (3+2)+(2+3)*197+(4+6) = 1000 us = 1 ms
delay_1ms:
  phx       ; 3 clock cycles
  ldx #197  ; 2 clock cycles
.x:
  dex       ; 2 clock cycles
  bne .x    ; 2/3 clock cycles
  plx       ; 4 clock cycles
  rts       ; 6 clock cycles
