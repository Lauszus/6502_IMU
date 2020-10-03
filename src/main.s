; Developed by Kristian Sloth Lauszus, 2020
; The code is released under the MIT License.
;
; https://eater.net/6502
; https://www.masswerk.at/6502/6502_instruction_set.html
; http://6502.org/tutorials/interrupts.html
; https://skilldrick.github.io/easy6502
; http://www.obelisk.me.uk/65C02/reference.html

; RAM: $0000 - $3FFF
;   Stack: $0100 - $01FF
; VIA: $6000 - $600F
; ROM: $8000 - $FFFF

; Variables stored in RAM
; $00 - $02 are used by the atan2 function
divisor         = $03
t1_10ms_counter = $04
spi_reg_addr    = $05
spi_data        = $06 ; This will store up to 6 bytes
spi_data_length = $0C
bit_clear_xor   = $0D
mpu_data_read   = $0E
mpu_acc_x_h     = $0F
mpu_acc_y_h     = $10
mpu_acc_z_h     = $11
print8_num      = $12 ; Will store up to 8 numbers when printing in base 2

; Versatile Interface Adapter (VIA)
VIA_PORTB   = $6000 ; Output Register "B" Input Register "B"
VIA_PORTA   = $6001 ; Output Register "A" / Input Register "A"
VIA_DDRB    = $6002 ; Data Direction Register "B"
VIA_DDRA    = $6003 ; Data Direction Register "A"
VIA_T1CL    = $6004 ; T1 Low-Order Latches / T1 Low-Order Counter
VIA_T1CH    = $6005 ; T1 High-Order Counter
VIA_T1LL    = $6006 ; T1 Low-Order Latches
VIA_T1HL    = $6007 ; T1 High-Order Latches
VIA_T2CL    = $6008 ; T2 Low-Order Latches / T2 Low-Order Counter
VIA_T2CH    = $6009 ; T2 High-Order Counter
VIA_SR      = $600A ; Shift Register
VIA_ACR     = $600B ; Auxiliary Control Register
VIA_PCR     = $600C ; Peripheral Control Register
VIA_IFR     = $600D ; Interrupt Flag Register
VIA_IER     = $600E ; Interrupt Enable Register
VIA_ORA_IRA = $600F ; Same as Reg 1 except no "Handshake"

; Interrupt bits used for the IFR and IER registers
VIA_ISR_EN  = %10000000
VIA_ISR_DIS = %00000000
VIA_ISR_T1  = %01000000
VIA_ISR_T2  = %00100000
VIA_ISR_CB1 = %00010000
VIA_ISR_CB2 = %00001000
VIA_ISR_SR  = %00000100
VIA_ISR_CA1 = %00000010
VIA_ISR_CA2 = %00000001

; Display output pins
LCD_E       = %10000000
LCD_RW      = %01000000
LCD_RS      = %00100000

; Display instructions
LCD_CLEAR_DISPLAY   = %00000001
LCD_RETURN_HOME     = %00000010
LCD_ENTRY_MODE_SET  = %00000100
LCD_ON_OFF_CONTROL  = %00001000
LCD_FUNCTION_SET    = %00100000
LCD_SET_DDRAM       = $80

; Display values
LCD_DDRAM_ROW_0   = $00
LCD_DDRAM_ROW_1   = $40

  ; The ROM starts at adress $8000
  .org $8000

  ; Include all of our other code in the beginning of the ROM
  .include macros.s
  .include math.s
  .include delay.s
  .include print.s
  .include spi.s

;mpu_found_str: .asciiz "IMU Found"
angles_str: .asciiz "Angles:"
assert_str: .asciiz "Assert"

; This is where the application will start after a reset
reset:
  ; Initialize the stack pointer
  ldx #$FF
  txs

  lda #%11111111    ; Set all pins on port B to output
  sta VIA_DDRB
  lda #%11100000    ; Set top 3 pins on port A to output
  sta VIA_DDRA

  lda #LCD_CLEAR_DISPLAY                ; Clear display
  jsr lcd_instruction
  lda #(LCD_FUNCTION_SET | %00011000)   ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #(LCD_ON_OFF_CONTROL | %00000100) ; Display on; cursor off; blink off
  jsr lcd_instruction
  lda #(LCD_ENTRY_MODE_SET | %00000010) ; Increment and shift cursor; don't shift display
  jsr lcd_instruction

  ; PA4 is used as an output for blinking a LED
  SET_BITS VIA_DDRA,%00010000

  cli                 ; Clear interrupt disable bit
  jsr init_10ms_timer ; Initiailize timer to interupt every 10 ms

  ; Intiailize the SPI and MPU
  jsr spi_init
  jsr mpu_init

loop:
  ; You can use this code to poll the IMU if you have not connected the INT pin
  ; Wait until the bit has cleared
  ;lda #MPU_INT_STATUS
  ;jsr spi_read
  ;and #$01
  ;bne loop

  ; Wait for the NMI interrupt
  stz mpu_data_read
  lda #$01
.mpu_int_wait:
  cmp mpu_data_read
  bne .mpu_int_wait

  ldx #0
  lda #(LCD_SET_DDRAM | (LCD_DDRAM_ROW_1 + 1))
.mpu_print_loop:
  jsr lcd_instruction
  clc                 ; Clear the carry-bit before the addition
  adc #5              ; Move the cursor 5 to the right, as the maximum length is 4 fx '-123'
  pha

  ; Print the value
  lda spi_data,x
  jsr print_i8_dec

  ; Clear any left-over characters i.e. old value: '-123', new value: 0
  ; This is faster than clearing the entire display
  lda #' '
  jsr print_char
  jsr print_char
  jsr print_char

  ; Restore the accumulator used for setting the cursor position
  pla

  ; Print every second value i.e. top 8-bits of the accelerometer data
  inx                 ; X++
  inx                 ; X++
  cpx #6
  bne .mpu_print_loop ; x < 6

  ; Calculate the roll and pitch angles using the following formula:
  ;   roll = atan2(Y, Z)
  ;   pitch = atan2(-X, Z)
  ;
  ; Note that X is inverted, so the angle follows the right-hand rule
  ; See: http://www.freescale.com/files/sensors/doc/app_note/AN3461.pdf

  ; Get the atan2 x argument
  ldx #4  ; Get the Z-axis value
  lda spi_data,x
  sta $00
  pha     ; Store the value, as we will be using it for the pitch angle as well

  ; Get the atan2 y argument
  ldx #2  ; Get the Y-axis value
  lda spi_data,x
  sta $01

  ; The quadrant will now be stored in Y
  jsr atan2_quadrant

  ; Prepare the arguments for the atan2 function
  lda $00
  ABS     ; Get the absolute value
  asl     ; Shift the value one to the left, as the sign-bit is not used anyway since we parse the absolute value
          ; This is done, as the atan2 function only works on the top 4-bits
  sta $00

  lda $01
  ABS     ; Get the absolute value
  asl     ; Shift the value one to the left, as the sign-bit is not used anyway since we parse the absolute value
          ; This is done, as the atan2 function only works on the top 4-bits
  sta $01

  ; Calculate the roll angle
  jsr atan2

  tay
  lda #(LCD_SET_DDRAM | LCD_DDRAM_ROW_0)
  jsr lcd_instruction
  PRINT_STR angles_str
  lda #' '  ; Add a space after the string
  jsr print_char
  tya       ; Print the roll angle
  jsr print_i8_dec
  lda #' '  ; Make sure the old characters gets overriden
  jsr print_char
  jsr print_char

  ; Get the atan2 x argument
  pla     ; Simply just use the same value as before
  sta $00

  ; Get the atan2 y argument
  ldx #0  ; Get the X-axis value
  lda spi_data,x
  INV     ; Flip the X-axis, so the angle follows the right hand rule
  sta $01

  ; The quadrant will now be stored in Y
  jsr atan2_quadrant

  ; Prepare the arguments for the atan2 function
  lda $00
  ABS     ; Get the absolute value
  asl     ; Shift the value one to the left, as the sign-bit is not used anyway since we parse the absolute value
          ; This is done, as the atan2 function only works on the top 4-bits
  sta $00

  lda $01
  ABS     ; Get the absolute value
  asl     ; Shift the value one to the left, as the sign-bit is not used anyway since we parse the absolute value
          ; This is done, as the atan2 function only works on the top 4-bits
  sta $01

  ; Calculate the pitch angle
  jsr atan2

  tay
  lda #(LCD_SET_DDRAM | (LCD_DDRAM_ROW_0 + 12))
  jsr lcd_instruction
  tya       ; Print the pitch angle
  jsr print_i8_dec
  lda #' '  ; Make sure the old characters gets overriden
  jsr print_char
  jsr print_char

  jmp loop

mpu_init:
  ; Read "WHO_AM_I" register
  lda #MPU_WHO_AM_I
  jsr spi_read

  ; Make sure the device is found
  cmp #MPU6500_WHO_AM_I_ID
  beq .mpu_found
  cmp #MPU9250_WHO_AM_I_ID
  beq .mpu_found
  cmp #ICM20689_WHO_AM_I_ID
  beq .mpu_found

  ; Assert if the IMU was not found
  jmp assert

.mpu_found:
  ;PRINT_STR mpu_found_str

  ; Reset device, this resets all internal registers to their default values
  lda #MPU_PWR_MGMT_1
  ldx #(1 << 7)
  jsr spi_write

  ; The power on reset time is specified to 100 ms
  ; It seems to be the case with a software reset as well
  jsr delay_100ms

  ; Wait until the bit has cleared
.mpu_reset_wait:
  jsr delay_1ms
  lda #MPU_PWR_MGMT_1
  jsr spi_read
  and #(1 << 7)
  bne .mpu_reset_wait

  ; Disable sleep mode and use PLL as clock reference
  lda #MPU_PWR_MGMT_1
  ldx #(1 << 0)
  jsr spi_write

  ; To prevent switching into I2C mode when using SPI, the I2C interface should be disabled by setting the I2C_IF_DIS configuration bit.
  ; Setting this bit should be performed immediately after waiting for the time specified by the "Start-Up Time for Register Read/Write" in Section 6.3.
  lda #MPU_USER_CTRL
  ldx #(1 << 5 | 1 << 4)  ; I2C Master mode and set I2C_IF_DIS to disable slave mode I2C bus
  jsr spi_write

  ; Set sample frequency to 10 Hz
  ldx #(1000 / 10 - 1)    ; Fs = 1000 / (register + 1) Hz
  stx spi_data + 0

  ; Disable FSYNC and set 184 Hz Gyro filtering, 1 kHz sampling rate
  ldx #$01
  stx spi_data + 1

  ; Set Gyro Full Scale Range to +-250 deg/s
  ldx #(0 << 3)
  stx spi_data + 2

  ; Set Accelerometer Full Scale Range to +-2 g
  ldx #(0 << 3)
  stx spi_data + 3

  ; 218.1 Hz Acc filtering, 1 kHz sampling rate
  ldx #$00
  stx spi_data + 4

  ; Write to all five registers at once
  lda #MPU_SMPLRT_DIV
  ldx #5
  jsr spi_write_data

  ; Setup interrupt on the INT pin

  ; The logic level for INT pin is active low
  ; The INT pin is held high until the interrupt is cleared - useful for checking how long it takes for the processor to service the interrupt
  ; Interrupt status is cleared if any read operation is performed
  ldx #(1 << 7 | 1 << 5 | 1 << 4) ; ACTL = 1, LATCH_INT_EN = 1, INT_ANYRD_2CLEAR = 1
  stx spi_data + 0

  ; Enable Raw Sensor Data Ready interrupt to propagate to interrupt pin
  ldx #(1 << 0)
  stx spi_data + 1

  ; Write to both registers at once
  lda #MPU_INT_PIN_CFG
  ldx #2
  jsr spi_write_data

  rts

nmi_interrupt:
  pha

  ; Read all 3-axis of the accelerometer
  lda #MPU_ACCEL_XOUT_H
  ldx #6
  jsr spi_read_data

  ; Set flag to indicate that the data has been read
  lda #$01
  sta mpu_data_read

  pla
  rti

assert:
  ; Store the registers
  pha
  phx
  phy

  ; Clear display
  lda #LCD_CLEAR_DISPLAY
  jsr lcd_instruction

  PRINT_STR assert_str

  ; Set cursor to bottom left
  lda #(LCD_SET_DDRAM | LCD_DDRAM_ROW_1)
  jsr lcd_instruction

  ; Print the register values
  pla
  jsr print_u8_hex
  lda #' '
  jsr print_char

  plx
  txa
  jsr print_u8_hex
  lda #' '
  jsr print_char

  ply
  tya
  jsr print_u8_hex

  sei   ; Set interrupt disable bit
  SET_BITS VIA_PORTA,%00010000  ; Turn on the LED

  jmp * ; Jump to the current PC i.e. loop forever

irq_interrupt:
  pha

  ; Check if the interrupt was triggered by the VLA by checking the IFR bits
  lda VIA_IFR         ; Read the VLA IFR register
  bpl .isr_end        ; Check if it is a VLA interrupt by checking bit-7
  and VIA_IER         ; Only check bits were the interrupt is enabled
.isr_timer1:
  asl                 ; Shift the accumulator left one bit
  bpl .isr_timer2     ; Check if bit-7 is high
  ;tax
  lda VIA_T1CL        ; Clear the T1 interrupt by reading the timer value
  inc t1_10ms_counter ; ms++
  lda t1_10ms_counter ; A = ms
  cmp #10             ; A == 10
  bne .isr_timer2     ; Z == 0
  stz t1_10ms_counter ; ms = 0
  TOGGLE_BITS VIA_PORTA,%00010000  ; Toggle PA4
  ;txa
.isr_timer2:
;   asl
;   bpl isr_cb1
; isr_cb1:
;   asl
;   bpl isr_cb2
; isr_cb2:
;   asl
;   bpl isr_sr
; isr_sr:
;   asl
;   bpl isr_ca1
; isr_ca1:
;   asl
;   bpl isr_ca2
; isr_ca2:
;   asl
.isr_end:
  pla
  rti

init_10ms_timer:
  ; Reset the variable
  stz t1_10ms_counter

  lda #%01000000    ; Continuous Timer1 interrupt
  sta VIA_ACR
  ; Load 10000 (2710) / 1 Mhz = 10 ms into the counter
  lda #(10000 & $FF)
  sta VIA_T1CL
  lda #(10000 >> 8)
  sta VIA_T1CH
  lda #(VIA_ISR_EN | VIA_ISR_T1)  ; Enable Timer1 interrupt
  sta VIA_IER
  rts

lcd_wait:
  pha
  lda #%00000000  ; Port B is input
  sta VIA_DDRB
.lcdbusy:
  ; Set RW; Clear RS/E bits
  lda VIA_PORTA
  ora #LCD_RW
  and #~(LCD_RS | LCD_E) & $FF
  sta VIA_PORTA

  ora #LCD_E        ; Set E bit to send instruction
  sta VIA_PORTA

  lda VIA_PORTB
  and #%10000000
  bne .lcdbusy

  lda VIA_PORTA
  and #~LCD_E & $FF ; Clear E bits
  sta VIA_PORTA

  lda #%11111111    ; Port B is output
  sta VIA_DDRB
  pla
  rts

lcd_instruction:
  pha
  jsr lcd_wait
  sta VIA_PORTB     ; Output A on the datalines

  ; Clear RS/RW/E bits
  lda VIA_PORTA
  and #~(LCD_RS | LCD_RW | LCD_E) & $FF
  sta VIA_PORTA

  ; Set E bit to send instruction
  ora #LCD_E
  sta VIA_PORTA

  ; Clear RS/RW/E bits
  and #~(LCD_RS | LCD_RW | LCD_E) & $FF
  sta VIA_PORTA
  pla
  rts

print_char:
  pha
  jsr lcd_wait
  sta VIA_PORTB       ; Output A on the datalines

  ; Set RS; Clear RW/E bits
  lda VIA_PORTA
  ora #LCD_RS
  and #~(LCD_RW | LCD_E) & $FF
  sta VIA_PORTA

  ora #LCD_E          ; Set E bit to send instruction
  sta VIA_PORTA
  and #~LCD_E  & $FF  ; Clear E bits
  sta VIA_PORTA
  pla
  rts

  .org $FFFA
  .word nmi_interrupt ; $FFFA, $FFFB - NMI (Non-Maskable Interrupt) vector
  .word reset         ; $FFFC, $FFFD - RES (Reset) vector
  .word irq_interrupt ; $FFFE, $FFFF - IRQ (Interrupt Request) vector
