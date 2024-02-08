;ManualLED backup.asm
;Pomocí P1 plynule nastavujte barvu RGB LED (R-G-B-R) a pomocí P2 její jas
;Zaklad pro psani vlastnich programu
    list	p=16F1508
    #include    "p16f1508.inc"

#define LED1 PWM1DCH
#define LED2 PWM2DCH
#define LED3 PWM3DCH

    
    __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

    __CONFIG _CONFIG2, _WRT_OFF & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON


;VARIABLE DEFINITIONS
;COMMON RAM 0x70 to 0x7F
    CBLOCK	0x70
	temp
	temp2
	range
	color
	prevP1_H	
	prevP1_L
	prevP2_H
	prevP2_L
	red
	green
	blue
	
	
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
			
Loop	;Hlavni smycka 
	;Read P1 and P2
	;Barva = Potenciometer 1
	;Jas = Potenciometer 2 
	call    ReadP2
	call	setBrightness
	
	;Color Potenciometer 1
	call	ReadP1	;PRecte Potenciometr 1 a vysledek ulozi do prevP1_H a prevP1_L
	;call	MapToRGB
	call	SetRGB	;Nastav barvu dle rozsahu Potenciometru
	goto    Loop

ReadP1
	;start ADC prevodniku
	
	movlb	.1		;Banka1 s ADC
	movlw	b'00011001'	;P1 = AN6
	movwf	ADCON0		;nastav cteni z P1
	bsf     ADCON0,GO       ;start A/D prevodu
        btfsc   ADCON0,GO 	;A/D prevod skoncen?
        goto    $-1             ;pokud ne, navrat o radek vyse
	
	;10-bit binary result via successive approximation and stores the conversion result into the
	;ADC result registers (ADRESH:ADRESL register pair).
	movf    ADRESH,W
	movwf	prevP1_H ;uloz horních 8 bit? do prevP1_H
	
	movf	ADRESL,W
	movwf	prevP1_L ;uloz spodní 2 bity do prevP1_L
	
	return
ReadP2
	movlb	.1		;Banka1 s ADC
	movlw    b'00101001'    ;P2 = AN10
	movwf	ADCON0
	bsf     ADCON0,GO       ;start A/D prevodu
        btfsc   ADCON0,GO 	;A/D prevod skoncen?
        goto    $-1             ;pokud ne, navrat o radek vyse
	
	movf    ADRESH,W
	movwf	prevP2_H
	movf    ADRESH,W
	movwf	prevP2_L
	return

MapToRGB
	; 10bitovou hodnotu na 8bitovou (0-255) pro jednoduchost
	movf    prevP1_H,W
	movwf   temp
	swapf   temp,F
	andlw   0x03
	movwf   prevP1_L
	movf    temp,W
	andlw   0xFC
	movwf   prevP1_H
	;8bitovou hodnotu je v prevP1_H a prevP1_L
	
	return
	
SetRGB
	movlb	.12 ;Banka 12 ss PWM
	movf	prevP1_H,W
	movwf	temp
	
	; Rozd?lení hodnoty z potenciometru na ctyri casti(256/4)
	movlw	.85
	movwf	range
	;Pokud zvý?íme hodnotu range na 85, rozsahy pro jednotlivé sekce se zm?ní.
   
	; Na zaklade rozsahu Potenciometer 1 zvol barvu
	movf	prevP1_H,W
	
	subwf	range,W
	btfsc	STATUS,C
	goto	Section1
	
	;Green range
	movf	prevP1_H,W
	subwf	range,W
	btfsc	STATUS,C
	goto	Section2
	
	
Section1
	movf	temp,W
	subwf	range,W
	
	movwf	red
	movwf	PWM1DCH
	subwf	range,W
	movwf	green
	movwf	PWM2DCH
	
	;Blue vypnutu
	clrf	blue
	clrf	PWM3DCH
	return

Section2
	movf	temp,W
	subwf	range,W
	
	sublw	.84
	movwf	temp2 ; Ulo?ení do?asné hodnoty

	; Lineární zvý?ení hodnoty blue
	movlw	.84
	subwf	temp2,W
	movwf	blue
	movwf	PWM3DCH
	
	; Lineární sní?ení hodnoty green
	movf	temp,W
	sublw	.64
	movwf	temp
	movlw	.120
	subwf	temp,W
	movwf	green
	movwf	PWM2DCH
	
	;Red vypnutu
	clrf	red
	clrf	PWM1DCH
	
	
	return
	
Section3
	;Lineární sní?ení hodnoty green
	movf	temp,W
	sublw	.64
	movwf	temp
	movlw	.120
	subwf	temp,W
	movwf	blue
	movwf	PWM3DCH
	
	; Lineární zvý?ení hodnoty red
	movlw	.84
	subwf	temp,W
	movwf	red
	movwf	PWM1DCH
	
	;Green
	clrf	green
	clrf	PWM2DCH
	return

setBrightness
	movlb	.12
	
	
	
	return
	
   #include	"Config_IOs.inc"
		
	END





