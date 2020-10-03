; Developed by Kristian Sloth Lauszus, 2020
; The code is released under the MIT License.
;
; This implement bitbang SPI mode = 0 with MSB first
; The 6502 is only running at 1 MHz and all registers in the MPU6500 works up to 1 MHz,
; so we should never be able to write and read faster than the IMU can handle
SPI_CLK       = %00000001
SPI_MOSI      = %00000010
SPI_MISO      = %00000100
SPI_CS        = %00001000

; Flag used to indicate if it is a SPI read transfer
MPU_SPI_READ_FLAG = $80

; MPU registers
MPU_SMPLRT_DIV      = $19 ; Sample Rate Divider register
MPU_CONFIG          = $1A ; Configuration
MPU_GYRO_CONFIG     = $1B ; Gyroscope Configuration
MPU_ACCEL_CONFIG    = $1C ; Accelerometer Configuration
MPU_ACCEL_CONFIG_2  = $1D ; Accelerometer Configuration 2
MPU_INT_PIN_CFG     = $37 ; INT Pin / Bypass Enable Configuration register
MPU_INT_ENABLE      = $38 ; Interrupt Enable
MPU_INT_STATUS      = $3A ; Interrupt Status

; Start of Accelerometer Measurements registers
MPU_ACCEL_XOUT_H    = $3B
MPU_ACCEL_XOUT_L    = $3C
MPU_ACCEL_YOUT_H    = $3D
MPU_ACCEL_YOUT_L    = $3E
MPU_ACCEL_ZOUT_H    = $3F
MPU_ACCEL_ZOUT_L    = $40

; Gyroscope Measurements registers
MPU_GYRO_XOUT_H     = $43
MPU_GYRO_XOUT_L     = $44
MPU_GYRO_YOUT_H     = $45
MPU_GYRO_YOUT_L     = $46
MPU_GYRO_ZOUT_H     = $47
MPU_GYRO_ZOUT_L     = $48

MPU_USER_CTRL       = $6A ; User Control register
MPU_PWR_MGMT_1      = $6B ; Power Management 1 register
MPU_WHO_AM_I        = $75 ; Who Am I register

; MPU identification values.
; These are the values returned by MPU_WHO_AM_I register to indicate the type of sensor.
MPU6500_WHO_AM_I_ID   = $70
MPU9250_WHO_AM_I_ID   = $71
ICM20689_WHO_AM_I_ID  = $98

  .macro SPI_CLK_HIGH
    SET_BITS VIA_PORTA,SPI_CLK
  .endm

  .macro SPI_CLK_LOW
    CLEAR_BITS VIA_PORTA,SPI_CLK
  .endm

  .macro SPI_MOSI_HIGH
    SET_BITS VIA_PORTA,SPI_MOSI
  .endm

  .macro SPI_MOSI_LOW
    CLEAR_BITS VIA_PORTA,SPI_MOSI
  .endm

  .macro SPI_CS_HIGH
    SET_BITS VIA_PORTA,SPI_CS
  .endm

  .macro SPI_CS_LOW
    CLEAR_BITS VIA_PORTA,SPI_CS
  .endm

  .macro SPI_WRITE,DATA
      ldy #7             ; Y = 7
    \@.loop:
      SPI_CLK_LOW       ; Set the clock low
      asl \DATA         ; Shift A on bit to the left and store the bit in the carry bit
      bcs \@.high       ; Check carry bit
      SPI_MOSI_LOW      ; The MSB was low
      jmp \@.clk
    \@.high:
      SPI_MOSI_HIGH     ; The MSB was high
    \@.clk:
      SPI_CLK_HIGH      ; Set the clock high when the MOSI has been set
      dey               ; Y--
      bpl \@.loop       ; Check if Y is still positive
      SPI_CLK_LOW
  .endm

  .macro SPI_READ,DATA
      ldy #7            ; Y = 7
      SPI_MOSI_LOW      ; Send dummy bytes
    \@.loop:
      SPI_CLK_HIGH
      lda VIA_PORTA     ; Read the port
      and #SPI_MISO
      bne \@.high       ; Bit is set
      clc               ; Clear carry flag
      jmp \@.shift
    \@.high:
      sec               ; Set the carry bit
    \@.shift:
      rol \DATA         ; C <- [76543210] <- C
      SPI_CLK_LOW
      dey               ; Y--
      bpl \@.loop       ; Check if Y is still positive
  .endm

spi_init:
  ; Set the pins to their initial state
  SPI_CLK_LOW
  SPI_MOSI_LOW
  SPI_CS_HIGH
  lda VIA_DDRA                        ; A = DDRA
  ora #(SPI_CLK | SPI_MOSI | SPI_CS)  ; Set CLK, MOSI and CS as outputs
  and #~SPI_MISO                      ; Set MISO as a input
  sta VIA_DDRA                        ; DDRA = A
  rts

spi_read:
  ora #MPU_SPI_READ_FLAG ; Set bit-7 high to indicate a read operation
  sta spi_reg_addr
  SPI_CS_LOW
  SPI_WRITE spi_reg_addr
  SPI_READ spi_data
  SPI_CS_HIGH
  lda spi_data          ; Put the data in the accumulator as well
  rts

spi_write:
  sta spi_reg_addr
  stx spi_data
  SPI_CS_LOW
  SPI_WRITE spi_reg_addr
  SPI_WRITE spi_data
  SPI_CS_HIGH
  rts

spi_read_data:
  ora #MPU_SPI_READ_FLAG ; Set bit-7 high to indicate a read operation
  sta spi_reg_addr
  stx spi_data_length
  SPI_CS_LOW
  SPI_WRITE spi_reg_addr

  ldx #0
.loop
  SPI_READ spi_reg_addr  ; Re-use the register address to store the data
  lda spi_reg_addr
  sta spi_data,x
  inx       ; X++
  cpx spi_data_length
  bne .loop ; X < length

  SPI_CS_HIGH
  rts

spi_write_data:
  sta spi_reg_addr
  stx spi_data_length
  SPI_CS_LOW
  SPI_WRITE spi_reg_addr

  ldx #0
.loop
  lda spi_data,x
  sta spi_reg_addr        ; Re-use the register address to store the data
  SPI_WRITE spi_reg_addr
  inx       ; X++
  cpx spi_data_length
  bne .loop ; X < length

  SPI_CS_HIGH
  rts
