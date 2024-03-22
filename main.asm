 ;### MACROS & defs (.equ)###

.MACRO LOAD_CONST  
  ldi @0, high(@2)
  ldi @1, low(@2)
.ENDMACRO 

/*** Display ***/
.equ DigitsPort   		  = PORTB    
.equ SegmentsPort		  = PORTD
.equ DisplayRefreshPeriod = 5

; SET_DIGIT diplay digit of a number given in macro argument, example: SET_DIGIT 2
.MACRO SET_DIGIT  
  push R16
  push R20
  
  ldi R20, 0b00000010<<@0
  out DigitsPort, R20
  mov R16, Dig_@0
  rcall DigitTo7segCode
  out SegmentsPort, R16
  LOAD_CONST R17, R16, DisplayRefreshPeriod 
  rcall DealyInMs
  
  pop R20
  pop R16
.ENDMACRO 

; ### GLOBAL VARIABLES ###

.def PulseEdgeCtrL=R0
.def PulseEdgeCtrH=R1

.def Dig_0=R2
.def Dig_1=R3
.def Dig_2=R4
.def Dig_3=R5

; ### INTERRUPT VECTORS ###
.cseg		     ; segment pamiêci kodu programu 

.org	 0      rjmp	_main	 ; skok do programu g³ównego
.org OC1Aaddr	rjmp  _Timer_ISR; TBD
.org 0x000b   rjmp  _ExtInt_ISR; TBD ; skok do procedury obs³ugi przerwania zenetrznego 

; ### INTERRUPT SEERVICE ROUTINES ###

_ExtInt_ISR: 	 ; procedura obs³ugi przerwania zewnetrznego

 ; TBD
    push R20
    in R20, SREG ; Store SREG value (temp must be defined by user)
    cli ; Disable interrupts during timed sequence
    push R24
    push R25
	
    mov R24,PulseEdgeCtrL
    mov R25,PulseEdgeCtrH
    adiw R25:R24, 1
    mov PulseEdgeCtrL, R24
    mov PulseEdgeCtrH, R25
	
    pop R25
    pop R24
    out SREG, R20 ; Restore SREG value (I-Flag)
    pop R20

reti   ; powrót z procedury obs³ugi przerwania (reti zamiast ret)      

_Timer_ISR:
    push R16
    push R17
    push R18
    push R19

    push R20
    in R20, SREG 
    cli ; Disable interrupts during timed sequence
    mov R16, PulseEdgeCtrL
    mov R17, PulseEdgeCtrH
    ldi R18, 2
    clr R19
    rcall _Divide
    mov R16, R18
    mov R17, R19
    rcall _NumberToDigits
    mov Dig_0, R16
    mov Dig_1, R17
    mov Dig_2, R18
    mov Dig_3, R19
    clr PulseEdgeCtrL
    clr PulseEdgeCtrH
    out SREG, R20
    pop R20

	pop R19
    pop R18
    pop R17
    pop R16

  reti

; ### MAIN LOOP ###

_main: 
    ; *** Initialisations ***
    ;--- Ext. ints --- PB0
    ldi R16, (1<<PCIE)					//
    out GIMSK, R16						//w³¹czenie przerwania zewnêtrznego PCIE0

    ldi R16, (1<<PCINT0)				//
    out PCMSK, R16						//aktywowanie przerwania z pinu PCINT0 (PB0)


	;--- Timer1 --- CTC with 256 prescaller
	ldi R16, (1<<CS12) | (1<<WGM12)		//CS12 prescaler 256, CS11 prescaler 8, CS10 prescaler 1, CS12+CS10 prescaler 1024, CS11+CS10 prescaler 64
    out TCCR1B, R16						//preskaler 256 i tryb CTC//

    ldi R16, LOW(31250)					//
    ldi R17, HIGH(31250)			    //
    out OCR1AH, R17						//
    out OCR1AL, R16						//

    ldi R16, (1<<OCIE1A)				//TIMSK Timer/Counter Interrupt Mask Register(tam gdzie ma jedynki te przerwania dzialaja)//Timer/Counter1 Output CompareA Match Interrupt Enable(wlacza ten event)
    out TIMSK, R16		
	
	;---  Display  --- 
    ldi R20, 0x1E
    out DDRB, R20
    ldi R20, 0b01111111
    out DDRD, R20
    sei

MainLoop:   ; presents Digit0-3 variables on a Display
			SET_DIGIT 0
			SET_DIGIT 1
			SET_DIGIT 2
			SET_DIGIT 3

			RJMP MainLoop

; ### SUBROUTINES ###

;*** NumberToDigits ***
;converts number to coresponding digits
;input/otput: R16-17/R16-19
;internals: X_R,Y_R,Q_R,R_R - see _Divider

; internals
.def Dig0=R22 ; Digits temps
.def Dig1=R23 ; 
.def Dig2=R24 ; 
.def Dig3=R25 ; 

_NumberToDigits:
	push Dig0
	push Dig1
	push Dig2
	push Dig3
	; thousands 
    ; TBD
    ldi R19, HIGH(1000)
    ldi R18, LOW(1000)
    rcall _Divide
    mov Dig0, R18
	; hundreads 
    ; TBD     
    ldi R19, HIGH(100)
    ldi R18, LOW(100)
    rcall _Divide
    mov Dig1, R18
	; tens 
    ; TBD    
    ldi R19, HIGH(10)
    ldi R18, LOW(10)
    rcall _Divide
    mov Dig2, R18
	; ones 
    ; TBD
    mov Dig3, R16 

	; otput result

	mov R16,Dig0
	mov R17,Dig1
	mov R18,Dig2
	mov R19,Dig3

	pop Dig3
	pop Dig2
	pop Dig1
	pop Dig0

	ret

;*** Divide ***
; divide 16-bit nr by 16-bit nr; X/Y -> Qotient,Reminder
; Input/Output: R16-19, Internal R24-25

; inputs
.def XL=R16 ; divident  
.def XH=R17 

.def YL=R18 ; divider
.def YH=R19 

; outputs

.def RL=R16 ; reminder 
.def RH=R17 

.def QL=R18 ; quotient
.def QH=R19 

; internal
.def QCtrL=R24
.def QCtrH=R25

_Divide:push R24 ;save internal variables on stack
        push R25
		
        ; TBD
        clr QCtrH						
        clr QCtrL

RepeatSub:	cp XL, YL				
			cpc XH, YH				

			brmi EndDiv				

			sub XL, YL				
			sbc XH, YH				
			adiw QCtrH:QCtrL, 1		
			rjmp RepeatSub			

EndDiv:		mov QL, QCtrL			
			mov QH, QCtrH			

			mov RL, XL				
			mov RH, XH				

		pop R25 ; pop internal variables from stack
		pop R24

		ret

; *** DigitTo7segCode ***
; In/Out - R16

Table: .db 0x3f,0x06,0x5B,0x4F,0x66,0x6d,0x7D,0x07,0xff,0x6f

DigitTo7segCode:

push R30
push R31

    ; TBD
ldi R30, low(Table<<1)
ldi R31, high(Table<<1)
add R30, R16
lpm R16, Z

pop R31
pop R30

ret

; *** DelayInMs ***
; In: R16,R17
DealyInMs:  
            push R24
			push R25

            ; TBD
mov R24, R16
mov R25, R17
Delay:
rcall OneMsLoop
sbiw R25:R24, 1
brne Delay
pop R25
pop R24

			ret

; *** OneMsLoop ***
OneMsLoop:	
			push R24
			push R25 
			
			LOAD_CONST R25,R24,2000                    

L1:			SBIW R25:R24,1 
			BRNE L1

			pop R25
			pop R24

			ret



