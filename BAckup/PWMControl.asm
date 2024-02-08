;Pomocí P1 plynule nastavujte barvu RGB LED (R-G-B-R) a pomocí P2 její jas
    list	p=16F1508
    #include    "p16f1508.inc"
    #define LED2    PORTC,3
    #define LED1    PORTC,5
    #define LED3    PORTA,3
    

    
    __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

    __CONFIG _CONFIG2, _WRT_OFF & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON


;VARIABLE DEFINITIONS
;COMMON RAM 0x70 to 0x7F
    CBLOCK	0x70
	tmp
	prevP1	
	prevP2	
	cnt1
	cnt2
	X
	
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
	bsf	PWM2CON,PWM2EN	;spustit PWM2
	
	;neprime adresovani v Bance 0
	movlb	.0
	movlw   0x06       ; Adresa PWM1DH = 0x0612
	movwf   FSR0H      
	movlw   0x12
	movwf   FSR0L      ; Control PWM1DCH ;ovlada vykon a svit
	
			
Loop	
	;Reset to 0
	
	;Color
	call	ReadP1
	movf	prevP1,W
	call	ColorLoop
	
	;Brightness
	call    ReadP2
	movf	prevP2,W
	call	PWMControl
	

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

ColorLoop
	movlb   .12

	;LED1 (Red) (255, 0 , 0)
	sublw   0xFF    ; Subtract the ADC value from 255
	movwf   PWM1DCH ;Nyni mame hodnotu v PWM1 invertovanou na 255 (max)

	; Depending on the color state, adjust the corresponding LED
	movf    prevP1, W
	sublw   0x01
	btfss   STATUS, Z
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
	
Delay_100			;zpozdeni 50 ms
        movlw   .50
Delay_ms
        movwf	cnt2		
OutLp	movlw	.249		
	movwf	cnt1		
	nop			
	decfsz	cnt1,F
        goto	$-2		
	decfsz	cnt2,F
	goto	OutLp
	return	
	
   #include	"Config_IOs.inc"
		
	END