Config_IOs	;config BT1 RA4, BT2 RA5, P1 RC2 (AN6), P2 RB4 (AN10) and LED1-3 RC5 RC3 RA2
	movlb	.2		;Bank2
	clrf	LATA
	clrf	LATB
	clrf	LATC
	movlb	.3		;Bank3
	movlw	b'00000000'
	movwf	ANSELA		;digital IO
	movlw	b'00010000'
	movwf	ANSELB		;digital IO, except RB4
	movlw	b'00000100'
	movwf	ANSELC		;digital IO, except RC2
	movlb	.1		;Bank1
	movlw	b'11111011'
	movwf	TRISA
	movlw	b'00111111'
	movwf	TRISB
	movlw	b'00010101'
	movwf	TRISC
	return


	
	
	
	
	