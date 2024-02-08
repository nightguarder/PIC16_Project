;Desitkovy citac (0 az 255)
    list	p=16F1508
    #include    "p16f1508.inc"

   
    __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

    __CONFIG _CONFIG2, _WRT_OFF & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON

;VARIABLE DEFINITIONS
;COMMON RAM 0x70 to 0x7F
    CBLOCK	0x70
	cnt1
        cnt2
        cnt3
        sec             	;citac 1 sekundy
	
	num7S			;cislo pro zobrazeni, dalsi 3B budou displeje!
	dispL			;levy 7seg
	dispM			;prostredni 7seg
	dispR			;pravy 7seg
    ENDC
    
;**********************************************************************
	ORG     0x00
  	goto    Start
	
	ORG     0x04
	nop
  	retfie
	
	
Start	movlb	.1		;Bank1
	movlw	b'01101000'	;4MHz Medium
	movwf	OSCCON		;nastaveni hodin

	call	Config_IOs
	call	Config_SPI
	
	movlb	.0
	
	
Main	clrf	sec		;vynulovani registru sec
	
Loop	movf    sec,W
	movwf	num7S		;zapsani cisla pro zobrazeni
        call    Bin2Bcd		;z num7S udela BCD cisla v dispL-dispM-dispR
	
	movf	dispL,W
        call    Byte2Seg	;4bit. cislo ve W zmeni na segment pro zobrazeni
	movwf	dispL
	
	movf	dispM,W
        call    Byte2Seg	;4bit. cislo ve W zmeni na segment pro zobrazeni
	movwf	dispM
	
	movf	dispR,W
        call    Byte2Seg	;4bit. cislo ve W zmeni na segment pro zobrazeni
	movwf	dispR	
        call    SendByte7S	;odesle W vzdy do leveho displeje (posun ostat.)
	movf	dispM,W
	call    SendByte7S	;odesle W vzdy do leveho displeje (posun ostat.)
	movf	dispL,W
	call    SendByte7S	;odesle W vzdy do leveho displeje (posun ostat.)
	
	
        movlw   .10		;zpozdeni 10*100=1000 ms
	movwf   cnt3
	call	Delay100
        decfsz  cnt3,F
	goto	$-2
	
        incf    sec,F
        goto    Loop
	
	
	
	
Delay100			;zpozdeni 100 ms
        movlw   .100
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
    
    #include	"Display.inc"
		
	END

		
		
		


