;Pomocí P1 plynule nastavujte barvu RGB LED (R-G-B-R) a pomocí P2 její jas
;Zaklad pro psani vlastnich programu
    list	p=16F1508
    #include    "p16f1508.inc"
    
    #define R       0x21    ; Red component (output)
    #define G       0x22    ; Green component (output)
    #define B       0x23    ; Blue component (output)
    #define F       0x24    ; Fraction of a sector
    #define P       0x25    ; Decreasing intensity
    #define Q       0x26    ; Increasing intensity
    #define T       0x27    ; Trailing intensity

    
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
	R1
	G1
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

	movlw .6 ; sestkrát pricist W k X
	movwf LoopCount
AddLoop
	addwf X, F
	btfsc STATUS, C ; Check for overflow
	incf OverflowCount, F ; Increment overflow counter if overflow occurs
	decfsz LoopCount, F ; Decrement loop counter, skip if zero
	goto AddLoop ; Repeat loop if loop counter is not zero
	
	movf OverflowCount, W
	andlw b'00000001' ; Take only the least significant bit
	movwf HRange

	movf X, W
	btfsc HRange, 0
	sublw 0xFF ; If HRange is 1, then X = 255 - X
	movwf X

	movf prevP1, W ; V = prevP2
	movf X, W ; Result is stored in PRODH:PRODL

	; Calculate (R1, G1, B1) based on H range
	movf HRange, W
	addlw .6 ; Add 6 to W
	movwf LoopCount

	; Calculate (R, G, B) by adding m to (R1, G1, B1)
	btfsc   STATUS,Z
	movf prevP1, W ; V = prevP2
	subwf R1, W
	movwf PWM1DCH ; Store into PWM1DCH
	
	btfsc   STATUS,Z
	subwf G1, W
	movwf PWM2DCH ; Store into PWM2DCH
	
	btfsc   STATUS,Z
	subwf B1, W
	movwf PWM3DCH ; Store into PWM3DCH
	
Delay100			;zpozdeni 100 ms
        movlw   .100

	
   #include	"Config_IOs.inc"
		
	END