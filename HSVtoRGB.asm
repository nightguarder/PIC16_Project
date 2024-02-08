;Pomocí P1 plynule nastavujte barvu RGB LED (R-G-B-R) a pomocí P2 její jas
;Zaklad pro psani vlastnich programu
    list	p=16F1508
    #include    "p16f1508.inc"
    

    
    __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

    __CONFIG _CONFIG2, _WRT_OFF & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON


;VARIABLE DEFINITIONS
;COMMON RAM 0x70 to 0x7F
    CBLOCK	0x70
	prevP1	
	prevP2	
	H
	X
	HRange
	LoopCount
	OverflowCount
	Counter
	R1
	G1
	A
	B1
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
	
	;config P1
	movlb	.1		;Banka1 s ADC
	movlw	b'00011000'	;P1 = AN6
	movwf	ADCON0
	movlw	b'01110000'	;leftAlig, FRC, VDD
	movwf	ADCON1
	clrf	ADCON2		;single conv.
	bsf	ADCON0,ADON	;zapnout ADC
	
	;config	P2
	movlb .1
	movlw	b'00101000' ;P2 = AN10
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
	
        goto    Loop	;main loop

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
	;return?
	
HSVtoRGB
	movlb   .12
	movf prevP1, W ; Nacíst prevP1 do W
	movwf H ; Ulozit do H

	clrf OverflowCount ; Vynulovat pocítadlo pretecení
	clrf X ; Vynulovat X
	clrf	Counter

	movlw .6 ; sestkrát pricist W k X
	movwf LoopCount
	
AddLoop
	
	; Assume S=1, C=V, m=0
    ; prevP1 = H (0-360), prevP2 = V (0-255)

    ; Convert H from 0-360 to 0-6
    movf    prevP1,W
    ;divlw   60
    movlw .6
    movwf   H
    
    ; Calculate X = C * (1 - |(H mod 2) - 1|)
    movf    H,W
    andlw   .1
    sublw   .1
    btfsc   STATUS,C
    comf    WREG,0
    movwf   A
    movf    prevP2,W
    movwf   B1
    call    Multiply
    movf    B1,W
    movwf   X
Multiply
    clrf    B1       ; clear B1 (B1 will hold the high byte of the result)
    movlw   .8       ; repeat the loop 8 times
    movwf   Counter
MultiplyLoop
    btfsc   A,0     ; if the least significant bit of A is 1...
    addwf   B1,F     ; ...then add A to B1
    bcf	STATUS,C
    rlf     A,F     ; shift A left (multiply by 2), moving bit 0 to the Carry
    rlf     B1,F     ; rotate B1 left (multiply by 2), moving the Carry to bit 0
    decfsz  Counter ; decrement the counter and skip the next instruction if it's 0
    goto    MultiplyLoop
    return

    
    ; Calculate RGB values based on H
    movf    H,W
    addlw   -0
    btfsc   STATUS,Z
    goto    Case0
    addlw   -1
    btfsc   STATUS,Z
    goto    Case1
    addlw   -1
    btfsc   STATUS,Z
    goto    Case2
    addlw   -1
    btfsc   STATUS,Z
    goto    Case3
    addlw   -1
    btfsc   STATUS,Z
    goto    Case4
    addlw   -1
    btfsc   STATUS,Z
    goto    Case5
    
Case0
    ; R=C, G=X, B=0
    movf    prevP1,W
    movwf   PWM1DCH ; R
    movf    X,W
    movwf   PWM2DCH ; G
    clrf    PWM3DCH ; B
    return

Case1
    ; R=X, G=C, B=0
    movf    X,W
    movwf   PWM1DCH ; R
    movf    prevP2,W
    movwf   PWM2DCH ; G
    clrf    PWM3DCH ; B
    return

Case2
    ; R=0, G=C, B=X
    clrf    PWM1DCH ; R
    movf    prevP2,W
    movwf   PWM2DCH ; G
    movf    X,W
    movwf   PWM3DCH ; B
    return

Case3
    ; R=0, G=X, B=C
    clrf    PWM1DCH ; R
    movf    X,W
    movwf   PWM2DCH ; G
    movf    prevP2,W
    movwf   PWM3DCH ; B
    return

Case4
    ; R=X, G=0, B=C
    movf    X,W
    movwf   PWM1DCH ; R
    clrf    PWM2DCH ; G
    movf    prevP2,W
    movwf   PWM3DCH ; B
    return

Case5
    ; R=C, G=0, B=X
    movf    prevP2,W
    movwf   PWM1DCH ; R
    clrf    PWM2DCH ; G
    movf    X,W
    movwf   PWM3DCH ; B
    return    
	return
	
Delay100			;zpozdeni 100 ms
        movlw   .100

	
   #include	"Config_IOs.inc"
		
	END