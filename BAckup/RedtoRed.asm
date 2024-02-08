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
	prevP1_L	
	prevP2_L
	temp
	OverflowCount
	LoopCount
	R
	Result
	ResultHigh
	X
	NearestMultipleOf60
	
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
	
	movf    ADRESH,W    ;uloz hornich 8 bits do P1
	movwf	prevP1
	movf	ADRESL,W    ;uloz spodni 2 bits do P1
	movwf	prevP1_L
	
	return
ReadP2
	movlb	.1		;Banka1 s ADC
	movlw    b'00101001'    ;P2 = AN10
	movwf	ADCON0
	bsf     ADCON0,GO       ;start A/D prevodu
        btfsc   ADCON0,GO 	;A/D prevod skoncen?
        goto    $-1             ;pokud ne, navrat o radek vyse
	
	movf    ADRESH,W    ;uloz hornich 8 bits do P1
	movwf	prevP2
	movf	ADRESL,W    ;uloz spodni 2 bits do P1
	movwf	prevP2_L
	
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
	

HSVtoRGB
	;S=1,C=V, m=0, 
	;prevP1 = h
	movlb   .12
	;clear Register and overflow
	clrw
	clrf	OverflowCount
	
	;Nastaveni LoopCount
	movlw	.6 ;Vetsi presnost
	movwf    LoopCount
	
AddLoop
    ; Adjust the color intensity based on the overflow count
    movf    prevP1,W
    addwf   X,F	    ;Add Scaled X to F
    btfsc   STATUS,C
    incf    OverflowCount,F
    decfsz  LoopCount,F
    goto    AddLoop

    

    ; Pass the value of X to the PWM modules based on OverflowCount
    movlb   .12
    movf    OverflowCount,W
    andlw   0x06
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
    addlw   -1
    
    goto    ColorRed2
    
ColorRed
    ; Set the value for the red color
    movf    prevP1,W
    movwf   temp
    movlw d'84' ; Horní limit pro ?ervenou barvu
    subwf temp, W ; Od?ítání hodnoty potenciometru od limitu
    addwf PWM1DCH, F ; Gradually increase red
    ;decfsz PWM2DCH, F ; Gradually decrease green
    ;decfsz PWM3DCH, F ; Gradually decrease blue
    clrf PWM2DCH 
    clrf    PWM3DCH
    return
    
ColorYellow
    movf prevP1,W
    addwf PWM1DCH, F 
    addwf PWM2DCH, F 
    clrf PWM3DCH 
    return
   
ColorGreen
    movf prevP1,W
    movwf   temp
    clrf PWM1DCH
    clrf PWM1DCL
    addwf    PWM2DCH,F
    clrf    PWM3DCH
    return

ColorBlue
    ; Set the value for the blue color
    movf prevP1,W
    
    
    clrf PWM1DCH 
    clrf PWM1DCL
    
    subwf PWM2DCH 
    addwf PWM3DCH, F
    return
    
ColorMagenta
    movf    prevP1,W
    clrf    PWM1DCH
    clrf PWM2DCH    ;LED2
    addwf PWM3DCH ; LED3
    return
    
Delay100			;zpozdeni 100 ms
        movlw   .100

	
   #include	"Config_IOs.inc"
		
	END







