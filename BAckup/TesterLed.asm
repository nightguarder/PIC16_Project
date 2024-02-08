;Zaklad pro psani vlastnich programu
    list	p=16F1508
    #include    "p16f1508.inc"

#define	BT1	PORTA,4
#define P1	PORTC,2
#define P2	PORTB,4
#define	LED3	PORTA,3
    
    __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

    __CONFIG _CONFIG2, _WRT_OFF & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON


;VARIABLE DEFINITIONS
;COMMON RAM 0x70 to 0x7F
    CBLOCK	0x70
	tmp	;promene v common RAM
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
	movlb	.0		;Bank0
	
	
	;ADCON config
	bsf ADCON1, ADON ; Turn on ADC
	movlw 0x00 ; Select AN0 (P1) as input
	movwf ADCON0 ; Write to ADCON0
	
	;config P1 a P2
	movlb .1 
	movlw b'00000100'
	movwf TRISC	    ; Nacti (P1)
	movlw b'00010000'
	movwf TRISB	    ; Nacti (P2)
	
	;config LED
	movlw   b'11110111'
	movwf   TRISA

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
	clrf	PWM3DCL		;clear PWM3 duty cycle
	bsf	PWM3CON,PWM3OE	;povolit vystup signalu na pin (Output enable)
	bsf	PWM3CON,PWM3EN	;spustit PWM3
	
	;neprime adresovani
	movlw   0x06       ; Adresa PWM3DH = 0x0612
	movwf   FSR0H      
	movlw   0x18
	movwf   FSR0L      ; Control PWM3DCH
	
	

MainLoop
	;Value from P1
	movlw   .12
	movwf   ADCON0
	bsf     ADCON0,GO
	btfsc   ADCON0,GO
	goto    $-1
	movf    ADRESH,W
	movwf   PWM3DCH

	; Value from P2
	movlw   .12
	movwf   ADCON0
	bsf     ADCON0,GO
	btfsc   ADCON0,GO
	goto    $-1
	movf    ADRESH,W
	movwf   PWM3DCL

    goto MainLoop
    


	
	
    #include	"Config_IOs.inc"	;zde "#include" funguje tak, ze proste jen vlozi svuj obsah tam kam ho napisete
		
	END



