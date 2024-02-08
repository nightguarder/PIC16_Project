;ManualLED backup.asm
;Pomocí P1 plynule nastavujte barvu RGB LED (R-G-B-R) a pomocí P2 její jas
;Zaklad pro psani vlastnich programu
    list	p=16F1508
    #include    "p16f1508.inc"

#define P1	PORTC,2
#define P2	PORTB,4

    
    __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

    __CONFIG _CONFIG2, _WRT_OFF & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON


;VARIABLE DEFINITIONS
;COMMON RAM 0x70 to 0x7F
    CBLOCK	0x70
	prevP1	
	prevP2
	OverflowCount
	LoopCount
	R
	X
	NearestMultipleOf60
	PRODL
	
    ENDC
    
;**********************************************************************
	ORG     0x00
  	goto    Start
	
	ORG     0x04
	nop			;pripraveno pro obsluhu preruseni
  	retfie
	
Start	
	movlb	.1		;Bank1
	movlw	b'01101000'	;4MHz Medium
	movwf	OSCCON		;nastaveni hodin

	call	Config_IOs	;vola nastaveni pinu
	
	
	;config AD Prevodniku
	movlb .1
	movlw	b'00101000'	;P2 = AN10
	movwf	ADCON0
	movlw	b'01110000'	;leftAlig, FRC, VDD
	movwf	ADCON1
	clrf	ADCON2		;single conv.
	bsf	ADCON0,ADON	;zapnout ADC
	
	;config TMR2
	movlb	.0		;Banka0 s TMR2
	clrf	T2CON		;1:1 pre, 1:1 post prescalor
	clrf	TMR2		;vynulovat citac na 0 postscalor
	movlw	0xFF		;(4000000/4)/256 = 3906.25 Hz	pro oko neviditelne
	movwf	PR2		;nastavit na max. hodnotu
	bsf	T2CON,TMR2ON	;po nastaveni vseho zapnout TMR2
	
	;config PWM3! ne PWM1
	movlb	.12		;PWM moduly v Bance 12
	clrf	PWM3DCH
	clrf	PWM3DCL
	bsf	PWM3CON,PWM3OE	;povolit vystup signalu na pin (Output enable)
	bsf	PWM3CON,PWM3EN	;spustit PWM3
	;config PWM1
	clrf	PWM1DCH
	clrf	PWM1DCL
	bsf	PWM1CON,PWM1OE	;povolit vystup signalu na pin (Output enable)
	bsf	PWM1CON,PWM1EN	;spustit PWM1
	;config PWM2
	clrf	PWM2DCH
	clrf	PWM2DCL
	bsf	PWM2CON,PWM2OE	;povolit vystup signalu na pin (Output enable)
	bsf	PWM2CON,PWM2EN	;spustit PWM1
	
	;neprime adresovani
	movlw   0x06       ; Adresa PWM3DH = 0x0612
	movwf   FSR0H      
	movlw   0x18
	movwf   FSR0L      ; Control PWM3DCH ;ovlada vykon a svit
	movlb	.0		;Banka0 s PORT
			
Loop	
	;Read P1 and P2
	call	ReadP1
	call    ReadP2
	;Brightness
	movf	prevP2,W
	call	PWMControl
	;Color
	movf	prevP1,W
	call	HSVtoRGB
	goto    Loop

ReadP1
	;start ADC prevodniku
	movlb	.1		;Banka1 s ADC
	movlw	b'00011001'	;P1 = AN6
	movwf	ADCON0		;nastav cteni z P1
	bsf     ADCON0,GO       ;start A/D prevodu
        btfsc   ADCON0,GO 	;A/D prevod skoncen?
        goto    $-1             ;pokud ne, navrat o radek vyse
	
	movf    ADRESH,W
	movwf	prevP1
	;vysledek AD prevodniku uloz do P1
	return
ReadP2
	movlb	.1		;Banka1 s ADC
	movlw    b'00101001'    ;P2 = AN10
	movwf	ADCON0
	bsf     ADCON0,GO       ;start A/D prevodu
        btfsc   ADCON0,GO 	;A/D prevod skoncen?
        goto    $-1             ;pokud ne, navrat o radek vyse
	
	movf    ADRESH,W
	movwf	prevP2
	return
	
PWMControl
	;banka 12 s PWM
	movlb	.12
	incf	FSR0L, F ; Increment FSR0L
	movwf	PWM3DCH ; Write to PWM3DCH
	
	;opakuj pro ostatni PWM
	incf	FSR0L,F
	movwf	PWM2DCH
	
	incf	FSR0L,F
	movwf	PWM1DCH
	return
	
MultiplesOf60 ; Lookup table for multiples of 60
    dw 0, 60, 120, 180, 240, 300
Scaling ; Lookup table for scaling to the range of 0 to 255
    dw 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, 72, 76, 80, 84, 88, 92, 96, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144, 148, 152, 156, 160, 164, 168, 172, 176, 180, 184, 188, 192, 196, 200, 204, 208, 212, 216, 220, 224, 228, 232, 236, 240, 244, 248, 252
	
;HSV to RGB conversion
HSVtoRGB
	;S=1,C=V, m=0, 
	;prevP1 = h
	movlb   .12
	;clear Register and overflow
	clrf	R
	clrf	OverflowCount
	
	;Nastaveni LoopCount
	movlw	.4 ;Vetsi presnost
	movwf    LoopCount
	
	; Calculate the nearest multiple of 60 to prevP1
    movf    prevP1,W
    call    MultiplesOf60 ; Get the nearest multiple of 60 from the lookup table
    movwf   NearestMultipleOf60

    ; Calculate the absolute difference between prevP1 and the nearest multiple of 60
    movf    prevP1,W
    subwf   NearestMultipleOf60,W
    btfsc   STATUS,C
    goto    $+3
    comf    WREG,0 ; If prevP1 < NearestMultipleOf60, take the 2's complement of WREG
    movwf   X

    ; Scale X to the range of 0 to 255
    movf    X,W
    call    Scaling ; Get the scaled value from the lookup table
    movwf   X

AddLoop
    ; Adjust the color intensity based on the overflow count
    movf    prevP1,W
    addwf   X,F
    btfsc   STATUS,C
    incf    OverflowCount,F
    decfsz  LoopCount,F
    goto    AddLoop

    ; If OverflowCount is even, subtract X from 255
    btfsc   OverflowCount,0
    goto    $+3
    movlw   0xFF
    subwf   X,W
    movwf   X

    ; Pass the value of X to the PWM modules based on OverflowCount
    movlb   .12
    movf    OverflowCount,W
    andlw   0x03
    addlw   -0
    btfsc   STATUS,Z
    goto    ColorRed
    addlw   -1
    btfsc   STATUS,Z
    goto    ColorYellow
    addlw   -1
    btfsc   STATUS,Z
    goto    ColorGreen
    addlw   -1
    btfsc   STATUS,Z
    
    goto    ColorBlue
    addlw   -1
    btfsc   STATUS,Z
    
    goto    ColorMagenta
    addlw   -1
    btfsc   STATUS,Z
    
    goto    ColorRed
    
ColorRed
    ; Set the value for the red color
    movf X, W
    addwf PWM1DCH, F ; Gradually increase red
    ;decfsz PWM2DCH, F ; Gradually decrease green
    ;decfsz PWM3DCH, F ; Gradually decrease blue
    clrf    PWM2DCH
    clrf    PWM3DCH
    return
    
ColorYellow
    movf X, W
    addwf PWM1DCH, F ; Gradually increase red
    addwf PWM2DCH, F ; Gradually increase green
    clrf PWM3DCH ; Gradually decrease blue
    return
   
ColorGreen
    clrf PWM1DCH ; Gradually decrease red
    movf X, W
    addwf PWM2DCH, F ; Gradually increase green
    addwf PWM3DCH, F ; Gradually increase blue
    return

ColorBlue
    ; Set the value for the blue color
    movf X, W
    
    clrf PWM1DCH ; Gradually decrease red
    clrf PWM2DCH ; Gradually decrease green
    addwf PWM3DCH, F ; Gradually increase blue
    return
    
ColorMagenta
    movf X, W
    addwf PWM1DCH, F ; Gradually increase red
    clrf PWM2DCH ; Gradually decrease green
    addwf PWM3DCH, F ; Gradually increase blue
    return
EndSetColor
    clrf    PWM1DCH
    clrf    PWM2DCH
    clrf    PWM3DCH
    nop
    return
    
Delay100			;zpozdeni 100 ms
        movlw   .100

	
   #include	"Config_IOs.inc"
		
	END



