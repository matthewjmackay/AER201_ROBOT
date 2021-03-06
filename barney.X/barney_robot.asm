; ============================================================================
; AER201 LED Testing Machine
; Programmer: Matthew MacKay
; ============================================================================
    ERRORLEVEL  -207, -205

#include <p18f4620.inc>
		list P=18F4620, F=INHX32, C=160, N=80, ST=OFF, MM=OFF, R=DEC

; ============================================================================
;Configuration Bits
; ============================================================================
		CONFIG OSC=HS, FCMEN=OFF, IESO=OFF
		CONFIG PWRT = OFF, BOREN = SBORDIS, BORV = 3
		CONFIG WDT = OFF, WDTPS = 32768
		CONFIG MCLRE = ON, LPT1OSC = OFF, PBADEN = OFF, CCP2MX = PORTC
		CONFIG STVREN = ON, LVP = OFF, XINST = OFF
		CONFIG DEBUG = OFF
		CONFIG CP0 = OFF, CP1 = OFF, CP2 = OFF, CP3 = OFF
		CONFIG CPB = OFF, CPD = OFF
		CONFIG WRT0 = OFF, WRT1 = OFF, WRT2 = OFF, WRT3 = OFF
		CONFIG WRTB = OFF, WRTC = OFF, WRTD = OFF
		CONFIG EBTR0 = OFF, EBTR1 = OFF, EBTR2 = OFF, EBTR3 = OFF
		CONFIG EBTRB = OFF

; ============================================================================
; Constant Definitions
; ===========================================================================
#define     first_line  B'10000000'
#define     second_line B'11000000'
#define     LCD_RS      PORTD, 2
#define     LCD_E       PORTD, 3
#define     MOTOR_CCW   PORTD, 0
#define     MOTOR_CW    PORTD, 1
#define     SR_CINHIBIT PORTE, 0
#define     SR_LOAD     PORTC, 7
#define     SR_CLOCK    PORTE, 1
#define     SR_L1       PORTC, 0
#define     SR_L2       PORTC, 1
#define     SR_L3       PORTC, 2
#define     SR_P        PORTC, 5

#define     key_1       d'0'
#define     key_2       d'1'
#define     key_3       d'2'
#define     key_A       d'3'
#define     key_4       d'4'
#define     key_5       d'5'
#define     key_6       d'6'
#define     key_B       d'7'
#define     key_7       d'8'
#define     key_8       d'9'
#define     key_9       d'10'
#define     key_C       d'11'
#define     key_star    d'12'
#define     key_0       d'13'
#define     key_pound   d'14'
#define     key_D       d'15'

#define     log_A       d'0'
#define     log_B       d'20'
#define     log_C       d'40'
#define     log_D       d'60'

#define     seconds     0x0
#define     minutes     0x1
#define     hours       0x2
#define     day         0x3
#define     date        0x4
#define     month       0x5
#define     year        0x6
#define     rtc_con     0x7
; ============================================================================
; General Purpose Registers (using Access Bank)
; ============================================================================
    cblock          0x20
        ; LCD/Delay registers
        temp_var1
        delay1
        delay2
        delay3
        temp_var3
        ; Sensor registers
        test_light
        LED_count
        light_result
        ; Light result registers
        current_light
        lights_present
        light1
        light2
        light3
        light4
        light5
        light6
        light7
        light8
        light9
        ; Log variables
        curr_log_addr
        new_log_addr
        loop_count
        log_light1
        log_light2
        temp_light
        log_to_show

        ; Keypad registers
        keypad_data
        keypad_result
        keypad_test

        ; E-stop registers
        e_stop_poll
        display_flag
        display_light
        curr_display_1u
        curr_display_1h
        curr_display_1l
        curr_display_2u
        curr_display_2h
        curr_display_2l

        ; RTC registers
        rtc_min
        rtc_sec
        rtc_hr
        rtc_day
        rtc_date
        rtc_mon
        rtc_yr

        tens_digit
        ones_digit
        temp_var2

        ; Computing time difference registers
        start_time_sec
        start_time_min
        end_time_sec
        end_time_min
        temp_var4
        temp_var5
        second_diff
        min_diff
    endc



; ============================================================================
; Macros
; ============================================================================
; ----------------------------------------------------------------------------
; General macros
; ----------------------------------------------------------------------------
; movlf:    Move a literal value to the file register specified
movlf       macro   literal, register
            movlw   literal
            movwf   register
            endm

; beq:      goes to label if register value == literal
; Note: I was having trouble with branch statement, changed it to use goto.
; Decided to just decrement then increment back to see if it was zero
; to make use of existing instruction set for skipping next instruction if
; file register is zero.
beq         macro   literal, register, label
            movlw   literal
            subwf   register, W
            decf    WREG, W
            infsnz  WREG
            goto    label
            endm
; ----------------------------------------------------------------------------
conv_dig    macro   register
            movf    register, W
            addlw   0x30
            endm

;conv_bcd    macro   bcd_rep, total_rep
;            movf    bcd_rep, W
;            andlw   0x0F
;            movwf   ones
;            swapf   bcd_rep, W
;            andlw   0x0F
;            movwf   tens_nibble
;            mullf   d'10', tens_nibble, tens
;            addff   ones, tens, total_rep
;            endm
;
;
;mullf       macro   literal, register, result
;            movf    register, W
;            mullw   literal
;            movwf   result
;            endm
;
;addff       macro   reg1, reg2, result
;            movff   reg1, result
;            movf    reg2, W
;            addwf   result, f
;            endm



; ----------------------------------------------------------------------------
; EEPROM macros
; ----------------------------------------------------------------------------
eeprom_read macro   address_high, address, register
            movlw   address_high
            movwf   EEADRH          ; Upper bits of Data Memory Address to read
            movf   address, W
            movwf   EEADR           ; Lower bits of Data Memory Address to read
            bcf     EECON1, EEPGD   ; Point to DATA memory
            bcf     EECON1, CFGS    ; Access EEPROM
            bsf     EECON1, RD      ; EEPROM Read
            movff   EEDATA, register       ; W = EEDATA
            endm

eeprom_write macro address_high, address, ee_data
            movlf   address_high, EEADRH; Upper bits of Data Memory Address to write
            movlf   address, EEADR    ; Lower bits of Data Memory Address to write
            movff   ee_data, EEDATA ; Data Memory Value to write
            btfsc   EECON1, WR
            bra     $-2
            bcf     EECON1, EEPGD    ; Point to DATA memory
            bcf     EECON1, CFGS    ; Access EEPROM
            bsf     EECON1, WREN    ; Enable writes
            bcf     INTCON, GIE     ; Disable Interrupts
            bcf     PIR2, EEIF
            movlw   0x55 ;
            movwf   EECON2   ; Write 55h
            movlw   0xAA
            movwf   EECON2            ; Write 0AAh
            bsf     EECON1, WR      ; Set WR bit to begin write
            btfsc   EECON1, WR
            bra     $-2
            bsf     INTCON, GIE     ; Enable Interrupts
            ; User code execution
            bcf     EECON1, WREN    ; Disable writes on write complete (EEIF set)
            endm

eeprom_wr_reg   macro   address_high, address_reg, ee_data
            movlf   address_high, EEADRH; Upper bits of Data Memory Address to write
            movff   address_reg, EEADR    ; Lower bits of Data Memory Address to write
            movff   ee_data, EEDATA ; Data Memory Value to write
            btfsc   EECON1, WR
            bra     $-2
            bcf     EECON1, EEPGD    ; Point to DATA memory
            bcf     EECON1, CFGS    ; Access EEPROM
            bsf     EECON1, WREN    ; Enable writes
            bcf     INTCON, GIE     ; Disable Interrupts
            bcf     PIR2, EEIF
            movlw   0x55 ;
            movwf   EECON2   ; Write 55h
            movlw   0xAA
            movwf   EECON2            ; Write 0AAh
            bsf     EECON1, WR      ; Set WR bit to begin write
            btfsc   EECON1, WR
            bra     $-2
            bsf     INTCON, GIE     ; Enable Interrupts
            ; User code execution
            bcf     EECON1, WREN    ; Disable writes on write complete (EEIF set)
            endm

; shift_logs- shift contents at location log1 into location log2
shift_logs  macro   log1, log2
            movlf   log1, curr_log_addr
            movlf   log2, new_log_addr
            call    ShiftLogs
            endm

; ----------------------------------------------------------------------------
; E-stop macros
; ----------------------------------------------------------------------------
; store_disp1- stores current first line table into register
store_disp1     macro   table
                movlf   upper table, curr_display_1u
                movlf   high table, curr_display_1h
                movlf   low table, curr_display_1l
                endm
; ----------------------------------------------------------------------------
; store_disp2- stores current second line table into register
store_disp2     macro   table
                movlf   upper table, curr_display_2u
                movlf   high table, curr_display_2h
                movlf   low table, curr_display_2l
                endm
; ----------------------------------------------------------------------------
; redisp- takes tables stored and redisplays them on LCD
redisp          macro
                ; set LCD to write on first line
                movlw   first_line
                writelcdinst
                ; write stored first line back onto LCD
                movf    curr_display_1u, W
                movwf   TBLPTRU
                movf    curr_display_1h, W
                movwf   TBLPTRH
                movf    curr_display_1l, W
                movwf   TBLPTRL
                call    WriteLCDChar
                ;set LCD to write on second line
                movlw   second_line
                writelcdinst
                ; write stored second line back onto LCD
                movf    curr_display_2u, W
                movwf   TBLPTRU
                movf    curr_display_2h, W
                movwf   TBLPTRH
                movf    curr_display_2l, W
                movwf   TBLPTRL
                call    WriteLCDChar
                endm
; ----------------------------------------------------------------------------
; redisp_light- redisplays interrupted light display back onto LCD
redisp_light    macro   light
                movff   light, current_light
                ; set LCD to write on first line
                movlw   first_line
                writelcdinst
                ; write stored light message and the light's results
                movf    curr_display_1u, W
                movwf   TBLPTRU
                movf    curr_display_1h, W
                movwf   TBLPTRH
                movf    curr_display_1l, W
                movwf   TBLPTRL
                call    WriteLCDChar
                call    WriteLCDLightResults
                ; set LCD to write on second line
                movlw   second_line
                writelcdinst
                ; write whichever menu needs to be written back on LCD
                movf    curr_display_2u, W
                movwf   TBLPTRU
                movf    curr_display_2h, W
                movwf   TBLPTRH
                movf    curr_display_2l, W
                movwf   TBLPTRL
                call    WriteLCDChar
                endm
; ----------------------------------------------------------------------------
; Keypad macros
; ----------------------------------------------------------------------------
; testkey: Checks if key has been pressed
testkey     macro   literal
            movlf   literal, keypad_test
            call    CheckButton
            endm
; ----------------------------------------------------------------------------
; keygoto:  Checks if key has been pressed, branches to label if so
keygoto     macro   literal, label
            movlf   literal, keypad_test
            call    CheckButton
            beq     d'1', keypad_result, label
            endm
; ----------------------------------------------------------------------------
; LCD macros
; ----------------------------------------------------------------------------
; lcddisplay:   Displays the inputted table on the LCD display on given line
lcddisplay  macro   Table, Line
            ; If Line = 10000000, use Line 1; if Line = 11000000, use Line 2
            movlw   Line
            writelcdinst
            ; move full address of table into Table Pointer
            movlw   upper Table
            movwf   TBLPTRU
            movlw   high Table
            movwf   TBLPTRH
            movlw   low Table
            movwf   TBLPTRL
            ; write character data to LCD
            call    WriteLCDChar
            endm
; ----------------------------------------------------------------------------
; writelcdinst: Sets LCD for instruction mode, then writes given instruction
; to display
writelcdinst    macro
            bcf     LCD_RS
            call    WriteLCD
            endm
; ----------------------------------------------------------------------------
; writelcddata: Sets LCD for data mode, then writes given data to display.
writelcddata    macro
            bsf     LCD_RS
            call    WriteLCD
            endm
; ----------------------------------------------------------------------------
; displight: Displays given light's tested results on LCD display
displight       macro   register, table
            ; move light's results to current_light to be displayed
            movff   register, current_light
            ; set LCD for line 1
            movlw   b'10000000'
            writelcdinst
            ; move full address of table into Table Pointer
            movlw   upper table
            movwf   TBLPTRU
            movlw   high table
            movwf   TBLPTRH
            movlw   low table
            movwf   TBLPTRL
            ; write character data to LCD
            call    WriteLCDChar
            call    WriteLCDLightResults
            endm

; ----------------------------------------------------------------------------
; rtcdisp: Writes inputted rtc register to lcd display
rtc_disp    macro   rtc_data
            rtc_convert rtc_data
            movff       tens_digit, WREG
            call        WriteLCDCharData
            movff       ones_digit, WREG
            call        WriteLCDCharData
            endm
; ----------------------------------------------------------------------------
; Sensor Arrays macros
; ----------------------------------------------------------------------------
; storeSR: Stores results from shift register into given light variable
storeSR         macro   register
            movff   PORTC, test_light
            movf    test_light, w
            andlw   b'00100111'     ; mask all bits but SR output
            movwf   test_light       ; store processed output for later use
            btfss   test_light, 5    ; if no light present...
            call    NoLightPresent   ;...call subroutine to take care of this
            btfsc   test_light, 5    ; if a light is present...
            call    LightPresent     ; ...call subroutine to take care of this
            movff   light_result, register
            endm
; ----------------------------------------------------------------------------
; I2C macros - code inspired by sample code provided
; ----------------------------------------------------------------------------
; i2c_start- tells I2C to begin transaction
i2c_start       macro
        bsf     SSPCON2, SEN
        call    CheckI2C
        endm
; ----------------------------------------------------------------------------
; i2c_stop- tells I2C that transaction has stopped
i2c_stop        macro
        bsf     SSPCON2, PEN
        call    CheckI2C
        endm
; ----------------------------------------------------------------------------
; i2c_write- writes current value of WREG into I2C buffer
i2c_write       macro
        movwf   SSPBUF
        call    CheckI2C
        endm
; ----------------------------------------------------------------------------
; rd_i2c_buf_ack- read I2C buffer, send acknowledge- keep reading
rd_i2c_buf_ack  macro   rtc_reg
        bsf     SSPCON2, RCEN
        call    CheckI2C
        i2c_common_ack
        movff   SSPBUF, rtc_reg
        endm
; ----------------------------------------------------------------------------
; rd_i2c_buf_nack- read I2C buffer, send not acknowledge- done reading
rd_i2c_buf_nack macro   rtc_reg
        bsf     SSPCON2, RCEN
        call    CheckI2C
        i2c_common_nack
        movff   SSPBUF, rtc_reg
        endm
; ----------------------------------------------------------------------------
; i2c_common_ack - send acknowledge to slave device
i2c_common_ack  macro
        bcf     SSPCON2,ACKDT
        bsf     SSPCON2,ACKEN
        call    CheckI2C
        endm
; ----------------------------------------------------------------------------
; i2c_common_nack - send not acknowledge to slave device
i2c_common_nack	macro
        bsf      SSPCON2,ACKDT
        bsf      SSPCON2,ACKEN
        call     CheckI2C
        endm
; ----------------------------------------------------------------------------
; RTC macros
; ----------------------------------------------------------------------------
; rtc_wr - writes data given to register at address in RTC
rtc_wr   macro   address, rtc_data
        i2c_start
        movlw       0xD0            ; RTC address
        i2c_write
        movlw       address         ; set register address on I2C
        i2c_write
        movlw       rtc_data        ; write data to RTC register
        i2c_write
        i2c_stop
        endm
; ----------------------------------------------------------------------------
; rtc_convert- takes BCD coded data and outputs an ASCII ones and tens digit
; these are stored in registers tens_digit and ones_digit
rtc_convert macro   rtc_data
        swapf       rtc_data, W
        andlw       B'00001111'     ; masks all but MSBs of rtc_data
        addlw       0x30            ; required to convert to ASCII
        movwf       tens_digit      ; store in tens_digit
        movf        rtc_data, W
        andlw       B'00001111'     ; masks all but LSBs of rtc_data
        addlw       0x30            ; required to convert to ASCII
        movwf       ones_digit      ; store in ones_digit
        endm
; ============================================================================
; Vectors
; ============================================================================
        org         0x00        ; Reset vector
        goto        Main

        org         0x08        ; High priority interrupt vector - only used for E-stop
        goto        EmergencyStop

        org         0x18        ; low priority interrupt vector
        retfie
; ============================================================================
; Tables
; ============================================================================
BlankLine               db      "  ", 0

WelcomeMsg              db      "Welcome User!", 0
WelcomeMsg2             db      "Press any button", 0
MenuMsg1                db      "Main Menu", 0
MenuMsg2                db      "1:Begin, 2:Logs", 0
OpMsg                   db      "Working...", 0
OpComplete              db      "Test complete", 0
LogMsg1                 db      "View which log?", 0
LogMsg2                 db      "1: Main Menu", 0

OpResults               db      "Results:", 0
TimeTakenMsg            db      "Time taken:", 0

LightsPresentMsg        db      "Lights present:", 0

Light1Msg               db      "Light 1: ", 0
Light2Msg               db      "Light 2: ", 0
Light3Msg               db      "Light 3: ", 0
Light4Msg               db      "Light 4: ", 0
Light5Msg               db      "Light 5: ", 0
Light6Msg               db      "Light 6: ", 0
Light7Msg               db      "Light 7: ", 0
Light8Msg               db      "Light 8: ", 0
Light9Msg               db      "Light 9: ", 0

LogMsgA                 db      "Log A:", 0
LogMsgB                 db      "Log B:", 0
LogMsgC                 db      "Log C:", 0
LogMsgD                 db      "Log D:", 0

working_3               db      "3 LEDs", 0
working_2               db      "2 LEDs", 0
working_1               db      "1 LED", 0
working_0               db      "0 LEDs", 0
not_present             db      "N/A", 0

ResultsMenu             db      "1:Menu, 2:Next", 0

AllResultsShown         db      "All lights shown", 0
ResultsDone1            db      "1:Main Menu", 0
ResultsDone2            db      "2:Show again", 0

LogResultsMenu          db      "1:Logs, 2:Next",0
LogResultsDone1         db      "1:Log Menu", 0

EStopFlash1             db      "Emergency stop", 0
EStopFlash2             db      "Activated!", 0
EStopActive1            db      "Deactivate stop", 0
EStopActive2            db      "when ready.", 0
EStopResume1            db      "Resuming...", 0

DateMsg                 db      "Date: ", 0
TimeMsg                 db      "Time: ", 0



; ============================================================================
; Main program
; ============================================================================

Main
; ----------------------------------------------------------------------------
; Configure- Sets up machine for use.
; ----------------------------------------------------------------------------
Configure
        ; set all ports to output
        clrf        TRISA
        clrf        TRISB
        clrf        TRISC
        clrf        TRISD
        clrf        TRISE
        ; clear all ports
        clrf        PORTA
        clrf        PORTB
        clrf        PORTC
        clrf        PORTD
        clrf        PORTE
        ; configure PORTA for input from shift register
        ; SR input-<3:0>
        movlw       b'00000000'
        movwf       TRISA
        movlw       07h
        movwf       ADCON1
        ; configure PORTB for keypad, emergency stop
        movlw       b'11110011'
        movwf       TRISB
        ; configure PORTC for motor signals, RTC, output to shift register
        ; SR output-<7:5>, RTC-<4:3>, Motor signals-<1:0>
        movlw       b'00111111'
        movwf       TRISC
        bsf         SR_LOAD
        bsf         SR_CINHIBIT
        call        Delay1s
        
        call        Delay1s
        ; configure interrupts
        clrf        INTCON
        bcf         RCON, IPEN              ; disable interrupt priority
        bsf         INTCON, GIE             ; enable interrupts
        bsf         INTCON, INT0IE          ; RB0 is interrupt
        bcf         INTCON2, INTEDG0        ; falling edge trigger

        call        ConfigureLCD            ; Configures LCD, sets parameters as needed
        call        ConfigureI2C            ; Configures I2C for RTC
        call        InitializeRTC           ; Only called when clock needs to be reconfigured
       
; ----------------------------------------------------------------------------
; Welcome - Initially shown on start up until user presses a button.  Displays
; date and time.
; ----------------------------------------------------------------------------
WelcomeScreen
        call        ClearLCD
        store_disp1 WelcomeMsg
        store_disp2 WelcomeMsg2
        call        RTCDisplayTimeDate       ; display date and time
        call        Delay1s
        call        Delay1s
        call        ClearLCD
        ;display first and secondlines of welcome message
        lcddisplay  WelcomeMsg, first_line
        lcddisplay  WelcomeMsg2, second_line
WelcomeLoop
        call        CheckAnyButton
        beq         d'1', keypad_result, Menu   ; if key has not been pressed
        bra         WelcomeLoop                 ; continue looping
; ----------------------------------------------------------------------------
; Main Menu- From here user can begin an operation or access previous operation
; logs.
; ----------------------------------------------------------------------------
Menu
        movlf       '0', display_flag
        call        ClearLCD                    ;Clears LCD Screen
        ; Display menu message
        lcddisplay  MenuMsg1, first_line
        store_disp1 MenuMsg1
        lcddisplay  MenuMsg2, second_line
        store_disp2 MenuMsg2
MenuLoop
        ; Wait until user has pressed 1 to begin or 2 for logs.
        keygoto     key_1, BeginOperation
        keygoto     key_2, LogMenu
        bra         MenuLoop
; ----------------------------------------------------------------------------
; Begin Operation- Manages all motors and sensors needed to test LCD.
; Stores needed light data in logs, calculates time needed for operation.
; ----------------------------------------------------------------------------
BeginOperation
        ; get Start time of operation
        call        ReadFromRTC
        movff       rtc_sec, start_time_sec
        movff       rtc_min, start_time_min
        ; Display "working..." message
        call        ClearLCD
        lcddisplay  OpMsg, first_line
        store_disp1 OpMsg
        store_disp2 BlankLine
        ; Operate the motor, read and store the sensor input
        call        OperateMotorForwards
        call        Delay500ms
        call        ReadSensorInput
        call        Delay500ms
        call        OperateMotorBackwards
        call        Delay500ms
        call        StoreLogs
        ; Display "Operation complete."
        call        ClearLCD                    
        lcddisplay  OpComplete, first_line
        store_disp1 OpComplete
        store_disp2 BlankLine
        ;get end time
        call        ReadFromRTC
        movff       rtc_sec, end_time_sec
        movff       rtc_min, end_time_min
        call        Delay1s                 ; allow user time to read message
        goto        DisplayOperation
; ----------------------------------------------------------------------------
; Display Operation - Tells user results are about to be shown.  Then displays
; each individual light's results.
; ----------------------------------------------------------------------------
DisplayOperation
        call        ClearLCD                    ; clear the LCD
        lcddisplay  OpResults, first_line       ; displays "Results:"
        store_disp1 OpResults
        store_disp2 BlankLine
        call        Delay1s
        call        Delay1s
        goto        DisplayLightsPresent
; ----------------------------------------------------------------------------
DisplayLightsPresent
        call        ClearLCD
        movlf       d'0', lights_present
        call        GetLightsPresent    
        lcddisplay  LightsPresentMsg, first_line
        ;movlf       d'9', lights_present
        ;movlf       d'0', lights_present
        conv_dig    lights_present
        call        WriteLCDCharData
        call        Delay1s
        call        Delay1s
; ----------------------------------------------------------------------------
DisplayTimeTaken
        call        ClearLCD
        call        GetTimeTaken
        lcddisplay  TimeTakenMsg, first_line
        movlw       second_line
        writelcdinst
        rtc_disp    min_diff
        movlw       0x3A                ; ":"
        call        WriteLCDCharData
        rtc_disp    second_diff
        call        Delay1s
        call        Delay1s
; ----------------------------------------------------------------------------
DisplayLight1
        movlf       b'11111111', display_flag   ; currently displaying lights
        call        ClearLCD
        displight   light1, Light1Msg           ; display results from light 1
        movff       light1, display_light
        store_disp1 Light1Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight1Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight2
        bra         DisplayLight1Loop
; ----------------------------------------------------------------------------
DisplayLight2
        call        ClearLCD
        displight   light2, Light2Msg           ; display results from light 2
        movff       light2, display_light
        store_disp1  Light2Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight2Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight3
        bra         DisplayLight2Loop
; ----------------------------------------------------------------------------
DisplayLight3
        call        ClearLCD
        displight   light3, Light3Msg           ; display results from light 3
        movff       light3, display_light
        store_disp1 Light3Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight3Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight4
        bra         DisplayLight3Loop
; ----------------------------------------------------------------------------
DisplayLight4
        call        ClearLCD
        displight   light4, Light4Msg           ; display results from light 4
        movff       light4, display_light
        store_disp1 Light4Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight4Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight5
        bra         DisplayLight4Loop
; ----------------------------------------------------------------------------
DisplayLight5
        call        ClearLCD
        displight   light5, Light5Msg           ; display results from light 5
        movff       light5, display_light
        store_disp1 Light5Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight5Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight6
        bra         DisplayLight5Loop
; ----------------------------------------------------------------------------
DisplayLight6
        call        ClearLCD
        displight   light6, Light6Msg           ; display results from light 6
        movff       light6, display_light
        store_disp1 Light6Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight6Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight7
        bra         DisplayLight6Loop
; ----------------------------------------------------------------------------
DisplayLight7
        call        ClearLCD
        displight   light7, Light7Msg           ; display results from light 7
        movff       light7, display_light
        store_disp1 Light7Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight7Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight8
        bra         DisplayLight7Loop
; ----------------------------------------------------------------------------
DisplayLight8
        call        ClearLCD
        displight   light8, Light8Msg           ; display results from light 8
        movff       light8, display_light
        store_disp1 Light8Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight8Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight9
        bra         DisplayLight8Loop
; ----------------------------------------------------------------------------
DisplayLight9
        call        ClearLCD
        displight   light9, Light9Msg           ; display results from light 9
        movff       light9, display_light
        store_disp1 Light9Msg
        lcddisplay  ResultsMenu, second_line
        store_disp2 ResultsMenu
DisplayLight9Loop
        ; user presses 1- go to main menu, 2- go to next light
        keygoto     key_1, Menu
        keygoto     key_2, EndDisplay
        bra         DisplayLight9Loop

; ----------------------------------------------------------------------------
EndDisplay
        ; Prompt user whether they want to display results again or go back
        ; to the main menu.
        movlf       b'00000000', display_flag   ; no longer displaying lights
        call        ClearLCD
        ; display "All lights shown"
        lcddisplay  AllResultsShown, first_line
        store_disp1 AllResultsShown
        store_disp2 BlankLine
        call        Delay1s
        call        Delay1s
        call        ClearLCD
        ; "Display "1: Main Menu, 2: Show again"
        lcddisplay  ResultsDone1, first_line
        store_disp1 ResultsDone1
        lcddisplay  ResultsDone2, second_line
        store_disp2 ResultsDone2
EndDisplayLoop
        ; user presses 1- go to main menu, 2- display results again
        keygoto     key_1, Menu
        keygoto     key_2, DisplayLight1
        bra         EndDisplayLoop


; ----------------------------------------------------------------------------
; Logs- TODO: will eventually contain code showing user results of previous
; operations.
; ----------------------------------------------------------------------------
LogMenu
        movlf       d'0', display_flag
        call        ClearLCD
        lcddisplay  LogMsg1, first_line
        store_disp1 LogMsg1
        lcddisplay  LogMsg2, second_line
        store_disp2 LogMsg2
LogLoop
        keygoto     key_1, Menu
        keygoto     key_A, ChooseLogA
        keygoto     key_B, ChooseLogB
        keygoto     key_C, ChooseLogC
        keygoto     key_D, ChooseLogD
        bra         LogLoop
; ----------------------------------------------------------------------------
ChooseLogA
        call        ClearLCD
        movlf       '0', log_to_show
        lcddisplay  LogMsgA, first_line
        store_disp1 LogMsgA
        store_disp2 BlankLine
        call        Delay1s
        call        Delay1s
        bra         DisplayLogTime
ChooseLogB
        call        ClearLCD
        movlf       d'20', log_to_show
        lcddisplay  LogMsgB, first_line
        store_disp1 LogMsgB
        store_disp2 BlankLine
        call        Delay1s
        call        Delay1s
        bra         DisplayLogTime
ChooseLogC
        call        ClearLCD
        movlf       d'40', log_to_show
        lcddisplay  LogMsgC, first_line
        store_disp1 LogMsgC
        store_disp2 BlankLine
        call        Delay1s
        call        Delay1s
        bra         DisplayLogTime
ChooseLogD
        call        ClearLCD
        movlf       d'60', log_to_show
        lcddisplay  LogMsgD, first_line
        store_disp1 LogMsgD
        store_disp2 BlankLine
        call        Delay1s
        call        Delay1s
        bra         DisplayLogTime
; ----------------------------------------------------------------------------
DisplayLogTime
        bra         LoadResults
; ----------------------------------------------------------------------------
LoadResults
        eeprom_read '0', log_to_show, light1
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light2
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light3
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light4
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light5
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light6
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light7
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light8
        call        Delay5ms
        incf        log_to_show
        eeprom_read '0', log_to_show, light9
        call        Delay5ms
        bra         DisplayLogLight1
; ----------------------------------------------------------------------------
DisplayLogLight1
        bsf         display_flag, 0
        call        ClearLCD
        displight   light1, Light1Msg
        movff       light1, display_light
        store_disp1 Light1Msg
        lcddisplay  LogResultsMenu, second_line
        store_disp2 LogResultsMenu
DisplayLogLight1Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight2
        bra         DisplayLogLight1Loop
; ----------------------------------------------------------------------------
DisplayLogLight2
        call        ClearLCD
        displight   light2, Light2Msg
        movff       light2, display_light
        store_disp1 Light2Msg
        lcddisplay  LogResultsMenu, second_line
        store_disp2 LogResultsMenu
DisplayLogLight2Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight3
        bra         DisplayLogLight2Loop
; ----------------------------------------------------------------------------
DisplayLogLight3
        call        ClearLCD
        displight   light3, Light3Msg
        movff       light3, display_light
        store_disp1 Light3Msg
        lcddisplay  LogResultsMenu, second_line
        store_disp2 LogResultsMenu
DisplayLogLight3Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight4
        bra         DisplayLogLight3Loop
; ----------------------------------------------------------------------------
DisplayLogLight4
        call        ClearLCD
        displight   light4, Light4Msg
        movff       light4, display_light
        store_disp1 Light4Msg
        lcddisplay  LogResultsMenu, second_line
        store_disp2 LogResultsMenu
DisplayLogLight4Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight5
        bra         DisplayLogLight4Loop
; ----------------------------------------------------------------------------
DisplayLogLight5
        call        ClearLCD
        displight   light5, Light5Msg
        movff       light5, display_light
        store_disp1 Light5Msg
        lcddisplay  LogResultsMenu, second_line
        store_disp2 LogResultsMenu
DisplayLogLight5Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight6
        bra         DisplayLogLight5Loop
; ----------------------------------------------------------------------------
DisplayLogLight6
        call        ClearLCD
        displight   light6, Light6Msg
        movff       light6, display_light
        store_disp1 Light6Msg
        lcddisplay  LogResultsMenu, second_line
        store_disp2 LogResultsMenu
DisplayLogLight6Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight7
        bra         DisplayLogLight6Loop
; ----------------------------------------------------------------------------
DisplayLogLight7
        call        ClearLCD
        displight   light7, Light7Msg
        movff       light7, display_light
        store_disp1 Light7Msg
        lcddisplay  LogResultsMenu, second_line
        store_disp2 LogResultsMenu
DisplayLogLight7Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight8
        bra         DisplayLogLight7Loop
; ----------------------------------------------------------------------------
DisplayLogLight8
        call        ClearLCD
        displight   light8, Light8Msg
        lcddisplay  LogResultsMenu, second_line
DisplayLogLight8Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight9
        bra         DisplayLogLight8Loop
; ----------------------------------------------------------------------------
DisplayLogLight9
        call        ClearLCD
        displight   light9, Light9Msg
        lcddisplay  LogResultsMenu, second_line
DisplayLogLight9Loop
        keygoto     key_1, LogMenu
        keygoto     key_2, EndLogResults
        bra         DisplayLogLight9Loop
; ----------------------------------------------------------------------------
EndLogResults
        bcf         display_flag, 0
        call        ClearLCD
        lcddisplay  AllResultsShown, first_line
        call        Delay1s
        call        Delay1s
        call        ClearLCD
        lcddisplay  LogResultsDone1, first_line
        lcddisplay  ResultsDone2, second_line
EndLogResultsLoop
        keygoto     key_1, LogMenu
        keygoto     key_2, DisplayLogLight1
        bra         EndLogResultsLoop

; ============================================================================
; Emergency Stop Routine
; ============================================================================
; ----------------------------------------------------------------------------
; EmergencyStop: Loops until I2C has successfully been read/written from/to
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
EmergencyStop
        bcf         INTCON, INT0IF      ; clear flag used for E Stop
        call        ClearLCD
        ; Display emergency stop message
        lcddisplay  EStopFlash1, first_line
        lcddisplay  EStopFlash2, second_line
        call        Delay1s
        call        Delay1s
        call        ClearLCD
        ; Display "deactivate when ready"
        lcddisplay  EStopActive1, first_line
        lcddisplay  EStopActive2, second_line
        ; poll PORTB until RB0 is high once more, i.e. e-stop deactivated
        call        PollEStop
        retfie
; ----------------------------------------------------------------------------
; PollEStop: Loops until E-stop deactivated, redisplays message that was
; being displayed when E-stop activated
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
PollEStop
        bcf         INTCON, GIE         ; disable interrupts
PollEStopLoop
        movff       PORTB, e_stop_poll
        btfsc       e_stop_poll, 0      ; keep looping while signal is low
        goto        EndPollEStopLoop    ; otherwise stop polling
        bra         PollEStopLoop
EndPollEStopLoop
        bsf         INTCON, GIE         ; reenable interrupts
        ;display "Resuming..."
        call        ClearLCD
        lcddisplay  EStopResume1, first_line
        call        Delay1s
        call        ClearLCD
        ; check if we are displaying a light or a general message
        btfsc       display_flag, 0
        goto        ReDisplayLight
        goto        ReDisplayGeneral
ReDisplayGeneral
        redisp                      ; not displaying light, simply redisplay
        goto        EndPollEStop
ReDisplayLight
        redisp_light display_light  ; displaying light, redisplay current light
        goto        EndPollEStop
        gotoEndPollEStop
EndPollEStop
        return

; ============================================================================
; Subroutines
; ============================================================================
; ----------------------------------------------------------------------------
; Log Subroutines
; ----------------------------------------------------------------------------
StoreLogs
;        shift_logs      log_C, log_D
;        shift_logs      log_B, log_C
        ;shift_logs      d'0', d'20' ; shift contents of log A to log B
        ;movlf           '0', curr_log_addr
        ;movlf           d'20', new_log_addr
        
        ;shift_logs      d'20', d'40'; shift log B to log C

;        movlf           d'20', curr_log_addr
;        movlf           d'40', new_log_addr
;        call            ShiftLogs

        ;try to shift one element at a time from Log B to Log C
        movlf           d'20', curr_log_addr
        movlf           d'40', new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
;        movlf           d'19', loop_count
;ShiftLogBToCLoop
;        incf            curr_log_addr
;        incf            new_log_addr
;        eeprom_read     '0', curr_log_addr, temp_light
;        call            Delay5ms
;        eeprom_wr_reg    '0', new_log_addr, temp_light
;        call            Delay5ms
;        dcfsnz          loop_count
;        goto            EndShiftLogs
;        bra             ShiftLogsLoop

        shift_logs      '0', d'20' ; shift log A to log B
        ;call            ShiftLogs
        ; debugging


        ; store most recent results in log A
        movlf           '0', curr_log_addr
        eeprom_wr_reg   '0', curr_log_addr, light1
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg   '0', curr_log_addr, light2
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg    '0', curr_log_addr, light3
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg    '0', curr_log_addr, light4
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg    '0', curr_log_addr, light5
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg    '0', curr_log_addr, light6
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg    '0', curr_log_addr, light7
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg    '0', curr_log_addr, light8
        incf            curr_log_addr
        call            Delay5ms
        eeprom_wr_reg    '0', curr_log_addr, light9
        incf            curr_log_addr
        call            Delay5ms
        return


ShiftLogs
        ; debugging
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms

        movlf           d'19', loop_count
ShiftLogsLoop
        incf            curr_log_addr
        incf            new_log_addr
        eeprom_read     '0', curr_log_addr, temp_light
        call            Delay5ms
        eeprom_wr_reg    '0', new_log_addr, temp_light
        call            Delay5ms
        dcfsnz          loop_count
        goto            EndShiftLogs
        bra             ShiftLogsLoop

EndShiftLogs
        return

; ----------------------------------------------------------------------------
; I2C Subroutines
; ----------------------------------------------------------------------------
; CheckI2C: Loops until I2C has successfully been read/written from/to
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
CheckI2C
        btfss       PIR1, SSPIF   ; set whenever complete byte transferred
        goto        CheckI2C
        goto        EndCheckI2C
EndCheckI2C
        bcf         PIR1, SSPIF
        return
; ----------------------------------------------------------------------------
; ConfigureI2C: Configures I2C/RTC for use
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ConfigureI2C
        ;enable MSSPmode set to I2c master mode - SSPCON1
        ; disable slew control rate control
        ; store 24 in sspadd
        movlf       b'00101000', SSPCON1     ; enable MSSP master mode, enable serial port
        movlf       b'10000000', SSPSTAT     ; disable slew control, write mode
        movlf       d'24', SSPADD           ; 100 kHz baud rate
        rtc_wr      rtc_con, 0x90
        return


; ----------------------------------------------------------------------------
; InitializeRTC: Sets date, time, year, etc on RTC- only to be used on initial 
; use
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
InitializeRTC
        rtc_wr      seconds, d'0'       ; seconds
        rtc_wr      minutes, d'0'       ; minutes
        rtc_wr      hours, d'9'         ; hours
        rtc_wr      day, d'1'           ; days
        rtc_wr      date, b'00100010'   ; date
        rtc_wr      month, d'2'         ; month
        rtc_wr      year, b'00010100'   ; year
        return

; ----------------------------------------------------------------------------
; ReadFromRTC: Reads time, date, year, etc of current values on RTC
; INPUT: None
; OUTPUT: rtc_min, rtc_sec, rtc_hr, rtc_day, rtc_date, rtc_mon, rtc_yr
; ----------------------------------------------------------------------------
ReadFromRTC
        ; write that we want to start at seconds register
        i2c_start
        movlw       0xD0                ; slave address: write
        i2c_write
        movlw       0x00                ; seconds register
        i2c_write
        i2c_stop
        ; configure RTC clock for reading data
        i2c_start
        movlw       0xD1                ; slave address: read
        i2c_write
        ; repeatedly read values from i2c buffer, write into appropriate rtc
        ; register
        rd_i2c_buf_ack  rtc_sec
        rd_i2c_buf_ack  rtc_min
        rd_i2c_buf_ack  rtc_hr
        rd_i2c_buf_ack  rtc_day
        rd_i2c_buf_ack  rtc_date
        rd_i2c_buf_ack  rtc_mon
        rd_i2c_buf_nack rtc_yr
        i2c_stop
        return
; ----------------------------------------------------------------------------
; RTCDisplayTimeDate: Displays date and time on two lines of LCD display
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
RTCDisplayTimeDate
        call        ReadFromRTC         ; get current value of date, time
        lcddisplay  DateMsg, first_line ; write "Date: " to first line
        ; display date in "mm/dd/yy" format
        rtc_disp    rtc_mon
        movlw       0x2F                ; "/"
        call        WriteLCDCharData
        rtc_disp    rtc_date
        movlw       0x2F                ; "/"
        call        WriteLCDCharData
        rtc_disp    rtc_yr
        ; display time in "hh:mm: format
        lcddisplay  TimeMsg, second_line ; write "Time: " to second line
        rtc_disp    rtc_hr
        movlw       0x3A                ; ":"
        call        WriteLCDCharData
        rtc_disp    rtc_min
        return

; ----------------------------------------------------------------------------
; ComputeTimeDifference: Computes how long an operation took by computing
; difference between start and end times, stores BCD results in second_diff and
; minute_diff
; INPUT: start_time_sec, start_time_min, end_time_sec, end_time_min
; OUTPUT: second_diff, min_diff
; ----------------------------------------------------------------------------
GetTimeTaken
FirstDigitSeconds
        ; first digit of second
        movf    end_time_sec, W
        andlw   0x0F                         ; mask upper MSBs
        movwf   temp_var4
        movf    start_time_sec, W
        andlw   0x0F                         ; mask upper MSBs of starting time
        movwf   temp_var5
        ; ending first digit (seconds) - starting first digit (seconds)
        movf    temp_var5, W
        subwf   temp_var4, w                 
        bnn     FirstDigitSecondsNotNegative ; no other processing needed
                                             ; if this is not negative
                                       
        ; if negative, then add 10 to it
        addlw   d'10'
        andlw   0x0F                    ; mask to have lower bit only
        movwf   second_diff
        ; add 1 to starting second digit (seconds), same thing as subtracting 1 
        ; from ending second digit (seconds)
        swapf   start_time_sec, W       ; swap to lower nibble and store in W
        andlw   0x0F                    ; mask it
        incf    WREG                    ; add one
        swapf   WREG                    ; swap back to upper nibble
        movwf   start_time_sec          ; move it back to old data
        bra     SecondDigitSeconds

FirstDigitSecondsNotNegative
        andlw   0x0F                    ; mask MSBs
        movwf   second_diff             ; no other processing needed

SecondDigitSeconds
        ; get second digit of ending time (seconds)
        swapf   end_time_sec, w
        andlw   0x0F                    
        movwf   temp_var4
        ; get second digit of starting time (seconds)
        swapf   start_time_sec, w
        andlw   0x0F            
        movwf   temp_var5
        ; ending second digit(seconds) - starting second digit (seconds)
        movff   temp_var5, WREG
        subwf   temp_var4, w            
        bnn     SecondDigitSecondsNotNegative   ; no other processing needed
                                                ; if this is not negative
        ; if negative, then add 6 to - result of carrying from minutes
        addlw   d'6'
        swapf   WREG
        andlw   0xF0                    ; this is second digit so mask lower bits
        addwf   second_diff, 1          ; add to store into the second difference
        ;and add 1 to the low digit of minute of the OLD one
        ; before adding it, need to check if it's 9. If it is, then will need
        ; to add one to HighMinute 
        sublw   d'9'
        bnz     AddOneToFirstDigitMinutes
AddOneToSecondDigitMinutes
            movlw   0xF0                ; make the lower bit 0 (bcoz 9+1=10)
            andwf   start_time_min, 1
            movlw   0x10
            addwf   start_time_min, 1   ; add 1 to the high nibble
            goto     FirstDigitMinutes

AddOneToFirstDigitMinutes
            ; simply add 1 to the RTC_Minute_Old
            incf     start_time_min, 1
            goto     FirstDigitMinutes

SecondDigitSecondsNotNegative
                andlw   0x0F
                swapf   WREG
                addwf   second_diff

FirstDigitMinutes
        ; lower digit of minute
        movff   end_time_min, WREG
        andlw   0x0F                    ; read lower nibble only
        movwf   temp_var4
        movff   start_time_min, WREG
        andlw   0x0F
        movwf   temp_var5
       
        movff   temp_var5, WREG
        subwf   temp_var4, 0    
        bnn     FirstDigitMinutesNotNegative        
                                       
        
        addlw   d'10'
        andlw   0x0F                    
        movwf   min_diff
        
        swapf   start_time_min, 0       
        andlw   0x0F                    
        incf    WREG                    
        swapf   WREG                    
        movwf   start_time_min         
        bra     SecondDigitMinutes

FirstDigitMinutesNotNegative
                andlw   0x0F
                movwf   min_diff

SecondDigitMinutes
        ; high digit of minute
        swapf   end_time_min, w
        andlw   0x0F                    
        movwf   temp_var4
        swapf   start_time_min, w
        andlw   0x0F
        movwf   temp_var5
       
        movff   temp_var5, WREG
        subwf   temp_var4, 0   
        bnn     SecondDigitMinutesNotNegative     
                                       
   
        addlw   d'6'
        swapf   WREG
        andlw   0xF0                   
        addwf   min_diff, 1      
        
        bra     EndGetTimeTaken

SecondDigitMinutesNotNegative
                andlw   0x0F
                swapf   WREG
                addwf   min_diff

EndGetTimeTaken
        return






; ----------------------------------------------------------------------------
; Motor Subroutines
; ----------------------------------------------------------------------------
; OperateMotorForwards: Operates motor forward by setting pin connecting to
; "counterclockwise" circuit
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
OperateMotorForwards
        bsf         MOTOR_CCW       ; send high signal to CCW circuit
        call        MotorDelay      ; delay so motor can turn
        return
; ----------------------------------------------------------------------------
; OperateMotorBackwards: Operates motor backwards by setting pin connecting to
; "clockwise" circuit
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
OperateMotorBackwards
        bcf         MOTOR_CCW       ; clear previous counterclockwise signal
        bsf         MOTOR_CW        ; send high signal to CW circuit
        call        MotorDelay      ; delay so motor can turn
        bcf         MOTOR_CW        ; clear signal to CW circuit
        return

; ----------------------------------------------------------------------------
; Sensor Subroutines
; ----------------------------------------------------------------------------
; ReadSensorInput: Read in data from sensors, stored in shift registers
; INPUT: None
; OUTPUT: light1, light2, light3, light4, light5, light6, light7, light8, light9
; ----------------------------------------------------------------------------
ReadSensorInput
        bsf         SR_CINHIBIT ; enable clock inhibit
        call        Delay1s     ; for demonstration purposes
        ;pulse load signal
        bcf         SR_LOAD
        call        Delay5ms
        call        Delay5ms
        call        Delay1s     ; for demonstrative purposes
        call        Delay5ms
        bsf         SR_LOAD
        bcf         SR_CINHIBIT ; disable clock inhibit
        ; send posedges until all lights read
        call        Delay1s     ; for demonstrative purposes
        call        ClockSRs
        storeSR     light1
        call        ClockSRs
        storeSR     light2
        call        ClockSRs
        storeSR     light3
        call        ClockSRs
        storeSR     light4
        call        ClockSRs
        storeSR     light5
        call        ClockSRs
        storeSR     light6
        call        ClockSRs
        storeSR     light7
        call        ClockSRs
        storeSR     light8
        call        ClockSRs
        storeSR     light9
        bsf         SR_CINHIBIT ; enable clock inhibit
        return
; ----------------------------------------------------------------------------
; ClockSRs: Send a posedge to the shift registers' clock signals
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ClockSRs
        bsf         SR_CLOCK
        call        Delay5ms
        call        Delay5ms
        call        Delay1s     ; for demonstrative purposes
        bcf         SR_CLOCK
        call        Delay44us
        call        Delay1s     ; for demonstrative purposes
        return
; ----------------------------------------------------------------------------
; NoLightPresent: No light is present, return the binary output coded for
; no LED
; INPUT: None
; OUTPUT: light_result
; ----------------------------------------------------------------------------
NoLightPresent
        movlf       b'10000000', light_result
        return
; ----------------------------------------------------------------------------
; LightPresent: Light is present, return number of functional LEDs
; INPUT: test_light
; OUTPUT: light_result
; ----------------------------------------------------------------------------
LightPresent
        movlf       b'0', LED_count         ; reset number of functional LEDs detected
        ; add 1 to LED_count for each LED sensed
        btfsc       test_light, 0
        call        AddLEDCount
        btfsc       test_light, 1
        call        AddLEDCount
        btfsc       test_light, 2
        call        AddLEDCount

        movff       LED_count, light_result   ; move number of lights counted to light_result
        return

; ----------------------------------------------------------------------------
; AddLEDCount: Functional LED has been detected, increment count
; INPUT: None
; OUTPUT: LED_count
; ----------------------------------------------------------------------------
AddLEDCount
        ; increment LED_count
        movf        LED_count, W
        addlw       b'1'
        movwf       LED_count
        return

; ----------------------------------------------------------------------------
; GetLightsPresent: Count number of flashlights present
; INPUT: None
; OUTPUT: lights_present
; ----------------------------------------------------------------------------
GetLightsPresent
        btfss       light1, 7
        call        AddLightCount
        btfss       light2, 7
        call        AddLightCount
        btfss       light3, 7
        call        AddLightCount
        btfss       light4, 7
        call        AddLightCount
        btfss       light5, 7
        call        AddLightCount
        btfss       light6, 7
        call        AddLightCount
        btfss       light7, 7
        call        AddLightCount
        btfss       light8, 7
        call        AddLightCount
        btfss       light9, 7
        call        AddLightCount
        return
; ----------------------------------------------------------------------------
; GetLightsPresent: Flashlight detected, add one to lights_present
; INPUT: None
; OUTPUT: lights_present
; ----------------------------------------------------------------------------
AddLightCount
        movf        lights_present, W
        addlw       b'1'
        movwf       lights_present
        return

; ----------------------------------------------------------------------------
; LCD Subroutines
; ----------------------------------------------------------------------------
; ConfigureLCD: Configures the LCD for use
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ConfigureLCD
        ;wait for LCD to warm up
        call        Delay5ms
        call        Delay5ms
        call        Delay5ms
        ; set for 8 bit
        movlw       B'00110011'
        writelcdinst
        ; set for 8 bit again then 4 bit
        movlw       B'00110010'
        writelcdinst
        ; 4 bits, 2 lines, 5x7 dot
        movlw       B'00101000'
        writelcdinst
        ; display on/off
        movlw       B'00001100'
        writelcdinst
        ; Entry mode
        movlw       B'00000110'
        writelcdinst
        ; clear ram
        call        ClearLCD
        return
; ----------------------------------------------------------------------------
; WriteLCD: Writes data/instructions to the LCD
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCD
        movwf       temp_var1       ; store W into a temporary register
        call        MovMSB
        call        ClockLCD
        swapf       temp_var1, w    ; swap nibbles
        call        MovMSB
        call        ClockLCD
        call        Delay5ms
        return
; ----------------------------------------------------------------------------
; WriteLCDChar: Displays the characters in the table pointer on LCD
; INPUT: TBLPTR
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCDChar
        tblrd*                      ; copy byte pointed to by TBLPTR into TABLAT
        movf        TABLAT, W       ; move contents of TABLAT into W
CharReadLoop
        writelcddata                ; write the contents of W into the LCD
        tblrd+*                     ; read next byte into TABLAT
        movf        TABLAT, W       ; move contents of TABLAT into W
        bnz         CharReadLoop    ; all bytes have been read once 0 is reached
        return
; ----------------------------------------------------------------------------
; ClockLCD: Pulses enable bit to transmit information to LCD
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ClockLCD
        bsf         LCD_E
        nop
        call        Delay5ms
        call        Delay5ms
        bcf         LCD_E
        call        Delay44us
        return
; ----------------------------------------------------------------------------
; MovMSB: Move the MSB of W to PORTD without disturbing LSB
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
MovMSB
        andlw       0xF0
        iorwf       PORTD, f
        iorlw       0x0F
        andwf       PORTD, f
        return
; ----------------------------------------------------------------------------
; WriteLCDCharData: Writes bare bones data in W register to LCD display
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCDCharData
        bsf         LCD_RS      ; prepare LCD for write
        movwf       temp_var3   ; save W register for future use
        call        MovMSB      ; move MSBs into PORTD
        ; pulse LCD enable bit
        bsf         LCD_E
        call        Delay44us
        bcf         LCD_E
        ; swap nibbles, move MSBs into PORTD
        swapf       temp_var3, 0
        call        MovMSB
        ;pulse LCD enable bit
        bsf         LCD_E
        call        Delay44us
        bcf         LCD_E
        call        Delay44us
        return
; ----------------------------------------------------------------------------
; ClearLCD: Clear both lines of LCD
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ClearLCD
        movlw       B'11000000'
        writelcdinst
        movlw       B'00000001'
        writelcdinst
        movlw       B'10000000'
        writelcdinst
        movlw       B'00000001'
        writelcdinst
        return

; ----------------------------------------------------------------------------
; WriteLCDLightResults: Writes results of light test onto display
; INPUT: current_light
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCDLightResults
        ; branches to different part of code depending on if light is present
        ; and how many LEDs are working
        beq         b'0', current_light, ZeroWorking
        beq         b'1', current_light, OneWorking
        beq         b'10', current_light, TwoWorking
        beq         b'11', current_light, ThreeWorking
        beq         b'10000000', current_light, NotPresent
ZeroWorking
       ; move full address of table into Table Pointer
        movlw   upper working_0
        movwf   TBLPTRU
        movlw   high working_0
        movwf   TBLPTRH
        movlw   low working_0
        movwf   TBLPTRL
        ; write character data to LCD
        call    WriteLCDChar
        goto    EndWriteLCDLightResults
NotPresent
       ; move full address of table into Table Pointer
        movlw   upper not_present
        movwf   TBLPTRU
        movlw   high not_present
        movwf   TBLPTRH
        movlw   low not_present
        movwf   TBLPTRL
        ; write character data to LCD
        call    WriteLCDChar
        goto    EndWriteLCDLightResults
OneWorking
       ; move full address of table into Table Pointer
        movlw   upper working_1
        movwf   TBLPTRU
        movlw   high working_1
        movwf   TBLPTRH
        movlw   low working_1
        movwf   TBLPTRL
        ; write character data to LCD
        call    WriteLCDChar
        goto    EndWriteLCDLightResults
TwoWorking
       ; move full address of table into Table Pointer
        movlw   upper working_2
        movwf   TBLPTRU
        movlw   high working_2
        movwf   TBLPTRH
        movlw   low working_2
        movwf   TBLPTRL
        ; write character data to LCD
        call    WriteLCDChar
        goto    EndWriteLCDLightResults
ThreeWorking
       ; move full address of table into Table Pointer
        movlw   upper working_3
        movwf   TBLPTRU
        movlw   high working_3
        movwf   TBLPTRH
        movlw   low working_3
        movwf   TBLPTRL
        ; write character data to LCD
        call    WriteLCDChar
        goto    EndWriteLCDLightResults
EndWriteLCDLightResults
        return
; ----------------------------------------------------------------------------
; Keypad Subroutines
; ----------------------------------------------------------------------------
; CheckAnyButton: Checks if any keypad button has been pressed
; INPUT: None
; OUTPUT: keypad_result (1 if button has been pressed, 0 otherwise)
; ----------------------------------------------------------------------------
CheckAnyButton
        movff       PORTB, keypad_data
        btfsc       keypad_data, 1
        goto        AnyPressed ; a key has been pressed
        movlf       B'0', keypad_result
        goto        EndCheckAnyButton
AnyPressed
        movlf       B'1', keypad_result
EndCheckAnyButton
        return

; ----------------------------------------------------------------------------
; CheckButton: Checks for keypad button, returns button info
; INPUT: keypad_test
; OUTPUT: keypad_result (sets bit 7 if no press)
; ----------------------------------------------------------------------------
CheckButton
        movff       PORTB, keypad_data
        btfss       keypad_data, 1      ;test if any data is input
        goto        NoButtonPressed
        swapf       keypad_data, W
        andlw       B'00001111'
        subwf       keypad_test, w
        bnz         NoButtonPressed
        movlf        d'1', keypad_result
        bra          EndCheckButton
NoButtonPressed
        movlf       d'0', keypad_result
        goto        EndCheckButton
EndCheckButton
        return
; ----------------------------------------------------------------------------
; Delay Subroutines
; ----------------------------------------------------------------------------
; Delay44us: Delays program for 44us (110 cycles)
; ----------------------------------------------------------------------------
Delay44us
        movlf       0x23, delay1
Delay44usLoop
        decfsz      delay1, f
        bra         Delay44usLoop
        return
; ----------------------------------------------------------------------------
; Delay5ms: Delays program for 5ms
; ----------------------------------------------------------------------------
Delay5ms
        movlf       0xC2, delay1
        movlf       0x0A, delay2
Delay5msLoop
        decfsz      delay1, f
        bra         d2
        decfsz      delay2, f
d2      bra         Delay5msLoop
        return
; ----------------------------------------------------------------------------
; Delay500ms: Delays program for 500ms
; ----------------------------------------------------------------------------
Delay500ms
        movlf       d'100', delay3
Delay500msLoop
        dcfsnz      delay3, f
        goto        EndDelay500ms
        call        Delay5ms
        bra         Delay500msLoop
EndDelay500ms
        return
; ----------------------------------------------------------------------------
; Delay1s: Delays program for 1s
; ----------------------------------------------------------------------------
Delay1s
        movlf       d'200', delay3
Delay1sLoop
        dcfsnz      delay3, f
        goto        EndDelay1s
        call        Delay5ms
        bra         Delay1sLoop
EndDelay1s
        return
; ----------------------------------------------------------------------------
; MotorDelay: TODO: Delays program for 10s for motor to turn, determined through
; experimentation
; ----------------------------------------------------------------------------
MotorDelay
        call        Delay1s
        call        Delay1s
        call        Delay1s
        ;call        Delay1s
        ;call        Delay1s
        ;call        Delay1s
        ;call        Delay1s
        ;call        Delay1s
        ;call        Delay1s
        ;call        Delay1s
EndDelayMotor
        return


    end