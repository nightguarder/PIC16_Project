; Display.INC
; Podprogramy obsluhy displeje

;*******************************************************
; Signaly obsluhy displeje na EduKitBeta
; SPI rozhrani k posuvnym registrum budicim LED segmenty
#define nCS	PORTC,6	    ; signal chip-select obvodu 4094
#define SDO	PORTC,7	    ; signal data obvodu 4094
#define SCK	PORTB,6	    ; hodinovy signal obvodu 4094
;*******************************************************

; Registry nadefinovat v .asm, jmena a poradi nutno dodrzet: num7S, disp(L/M/R)

;***********************************************************
; Konfigurace SPI pro komunikaci se 7seg
Config_SPI
	movlb	.4		;Bank4
	clrf	SSP1STAT
	movlw	b'00110000'	;high idle state, Fosc/4, SPI ON
	movwf	SSP1CON1
	
	clrw
	movlb	.0		;Bank0
	bcf	nCS		;!CS -> low
	movlb	.4		;Bank4
	movwf	SSP1BUF
	btfss	SSP1STAT,0	;ceka do vyprazdneni bufferu
	goto	$-1
	movf	SSP1BUF,W	;prazdne cteni HLAVNE NEZAPISOVAT ZPATKY DO F!
	clrw
	movwf	SSP1BUF
	btfss	SSP1STAT,0	;ceka do vyprazdneni bufferu
	goto	$-1
	movf	SSP1BUF,W	;prazdne cteni HLAVNE NEZAPISOVAT ZPATKY DO F!
	clrw
	movwf	SSP1BUF
	btfss	SSP1STAT,0	;ceka do vyprazdneni bufferu
	goto	$-1
	movf	SSP1BUF,W	;prazdne cteni HLAVNE NEZAPISOVAT ZPATKY DO F!
	clrw
	movlb	.0
	bsf	nCS		;!CS -> high
	
	return	

	
;***********************************************************************
; Prevod binarniho cisla (16 bitu hval:lval) na BCD (4 digity hbcd:lbcd)
Bin2Bcd
	clrf	dispR
	clrf	dispM
	clrf	dispL
	
	lslf	num7S,F		;nejvyssi bit
	rlf	dispR,F
	
	lslf	num7S,F		;2. nejvyssi bit
	rlf	dispR,F
	
	lslf	num7S,F		;3. nejvyssi
	rlf	dispR,F
	
	movlw	.5		;zbylych 5 bitu v loopu
	movwf	dispM		;slouzi jako pocitadlo
	
ShLoop	movf	dispR,W		;test spodniho nibble
	addlw	0x03		
	btfsc	WREG,3		;je po pricteni 3 vetsi/roven 8 (puvodne >= 5)
	movwf	dispR		;ano prepsat prictenym
	movf	dispR,W		;test horniho nibble
	addlw	0x30
	btfsc	WREG,7		;je po pricteni 3 vetsi/roven 8 (puvodne >= 5)
	movwf	dispR		;ano prepsat prictenym
	
	lslf	num7S,F		;postupne posuny pres C
	rlf	dispR,F
	rlf	dispL,F
	
	decfsz	dispM,F		;odecist pocet posunuti
	goto	ShLoop
	
	movf	dispR,W		;rozdelit nibbles do dvou bytu
	movwf	dispM
	swapf	dispM,F
	movlw	0x0F
	andwf	dispR,F		;pro jistotu vymaskovat nepouzite nibbles
	andwf	dispM,F
	
	return	
	
	
;***********************************************************
; Tabulka prevodu 4-bitoveho kodu (hexa) na 7-segmentovy kod
; Desetinna tecka se dodatecne koduje do 0. bitu (napr. inkrementaci)
Byte2Seg
	andlw   0x0F            ; omezeni na 4 nizsi bity (hexa kod)
	brw			; pricte w k citaci instrukci
	retlw   b'11111100'     ; zobrazi 0
	retlw   b'01100000'     ; zobrazi 1
	retlw   b'11011010'     ; zobrazi 2
	retlw   b'11110010'     ; zobrazi 3
	retlw   b'01100110'     ; zobrazi 4
	retlw   b'10110110'     ; zobrazi 5
	retlw   b'10111110'     ; zobrazi 6
	retlw   b'11100000'     ; zobrazi 7
	retlw   b'11111110'     ; zobrazi 8
	retlw   b'11110110'     ; zobrazi 9
	retlw   b'11101110'	; zobrazi 'A'
	retlw   b'00111110'	; zobrazi 'b'
	retlw   b'10011100'	; zobrazi 'C'
	retlw   b'01111010'	; zobrazi 'd'
	retlw   b'10011110'	; zobrazi 'E'
	retlw   b'10001110'	; zobrazi 'F'

	
	
;*******************************************************************************
; Seriovy prenos W do leveho displeje, aktualne zobrazene se posunou doprava
SendByte7S
	movlb	.0		;Bank0
	bcf	nCS		;!CS -> low
	movlb	.4		;Bank4
	movwf	SSP1BUF
	btfss	SSP1STAT,0	;ceka do vyprazdneni bufferu
	goto	$-1
	movf	SSP1BUF,W	;prazdne cteni HLAVNE NEZAPISOVAT ZPATKY DO F!
	clrw
	movlb	.0
	bsf	nCS		;!CS -> high
	return	

