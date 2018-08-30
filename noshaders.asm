
; "No shaders" for RCA Studio II
; - 256 bytes intro by Frog for CC'2018
;
; use asmx to assemble
;
; http://enlight.ru/roi
; frog@enlight.ru
;


        .include "1802.inc"
LINES	equ		8	; number of raster lines to scroll
BYTES_PER_LINE equ	8	; bytes per one line

VADDR_STARS	equ	$09FF-24*BYTES_PER_LINE
VADDR_SKY	equ	$09FF-16*BYTES_PER_LINE
VADDR_CITY	equ	$09FF-6*BYTES_PER_LINE	; addr of the most right (bottom) byte to scroll from
VADDR_ROAD	equ	$09FF-3*BYTES_PER_LINE
VADDR_BORDER	equ	$09FF-0*BYTES_PER_LINE	; addr of the most right (bottom) byte to scroll from
; 9ff - end of VRAM
        .org 0400h
	.db	4,2



	sex 15		; X = RF

; draw test pattern
;       ldi 9h          ; const -> D      RF = $09FF
;	phi 15		; D -> R6.1
;	ldi 255		; const -> D
;	plo 15		; D -> R9.0
;loop:	stxd		; D -> M(Rx), Rx--
;	glo 15		; Rn -> D
;	bnz loop


; -------- draw stars -----------

; from
	ldi	03	; const -> D
	plo     r4      ; D -> Rn.0
	phi     r4      ; D -> Rn.0
; to
	ldi	<VADDR_STARS	; const -> D        
	plo     r15      ; D -> Rn.0
	ldi	>VADDR_STARS	; const -> D        
	phi     r15      ; D -> Rn.1

loop:	
	ldn	r4	; M[Rn] -> D
	ani	%00000010	; D and const -> D
	bdf	skip	; jump if carry
	ldi	0	; const -> D
skip:	
	stxd		; D -> M(Rx), Rx--
	
	glo	r4	; Rn -> D
;	adci	39	; D + const -> D   47  71             55 27
	adi	47	; D + const -> D   47  71             55 27
	plo	r4	; Rn -> D

	glo 	r15		; Rn -> D
	bnz 	loop


; draw static road borders
	ldi	<VADDR_BORDER	; const -> D        
	plo     r15      ; D -> Rn.0
;	ldi	>VADDR_BORDER	; const -> D        
;	phi     r15      ; D -> Rn.1

nextbyteA:
	ldi	$ff	; const -> D        
        stxd		; D -> M(Rx), Rx--
        
	glo	r15	; Rn -> D
	xri	<VADDR_BORDER - 8	; compare (D == const) -> D         
	bnz	nextbyteA

	glo	r15	; Rn -> D
	smi 	32	; D - const -> D     gap 4 lines
	plo     r15      ; D -> Rn.0

nextbyteB:
	ldi	$ff	; const -> D        
        stxd		; D -> M(Rx), Rx--
        
	glo	r15	; Rn -> D
	xri	<VADDR_BORDER - 6*BYTES_PER_LINE	; compare (D == const) -> D         
	bnz	nextbyteB


; data to scroll
	ldi	$04	; everything in cartridge have hi bytes $04 (cart ROM space $0400-07FF)
	phi     r4      ; D -> Rn.1
	phi     r5      ; D -> Rn.1
	phi     r14      ; D -> Rn.1
	phi     r13      ; D -> Rn.1


	ldi	<citydata	; const -> D        $17
	plo     r4      ; D -> Rn.0

;	ldi	>citydata	; const -> D        $09
;	phi     r4      ; D -> Rn.1

	ldi	<skydata	; const -> D        $17
	plo     r5      ; D -> Rn.0
;	ldi	>skydata	; const -> D        $09
;	phi     r5      ; D -> Rn.1

; scroll subroutine
	ldi	<scroll	; const -> D       
	plo     r14      ; D -> Rn.0
;	ldi	>scroll	; const -> D       
;	phi     r14      ; D -> Rn.1

; commands (list of sky and city data addresses)
	ldi	<commands	; const -> D       
	plo     r13      ; D -> Rn.0
;	ldi	>commands	; const -> D       
;	phi     r13      ; D -> Rn.1

	sex	r6	; set Rx

	ldi	0
	plo	r15	; D -> Rn.0
	phi	r15	; D -> Rn.1


; r3 - main PC
; r4 - bitmap data pointer for the city
; r5 - bitmap data pointer for the sky
; r6 - VRAM pointer
; r7 - byte counter, local (-)
; r10 - line counter, local 
; r12 - temp storage for scrollable byte, local
; r13 - commands
; r15 - global frame counter
; r14 - PC for scroll subroutine call


; WARNING! BIOS INT HANDLER CHANGES: R0,R1,R2,R8,R9,r11(RB)
; (X,P,D restored)

nextscroll:

delay: 	bn1     delay    ; wait for EFX in video chip      

; ------ SCROLL CITY -------------------------------------------

        glo	r15	; Rn -> D
	shr
	bdf	skipScrollCity	

	ldi	<VADDR_CITY	; const -> D        
	plo     r6      ; D -> Rn.0
;	ldi	>VADDR_CITY	; const -> D        
;	phi     r6      ; D -> Rn.1



; check for end of commands and loop if it done	
        glo	r13	; Rn -> D
	xri	<endofcommands
	bnz	notRESTART	; check if command execution not yet finished (1 - marker of its` end)
; restart commands
	ldi	<commands	; const -> D       
	plo     r13      ; D -> Rn.0
;	ldi	>commands	; const -> D       
;	phi     r13      ; D -> Rn.1


notRESTART:

; get byte for new vertical column

	lda	r4	; M[Rn] -> D, Rn++
	plo	r12	; D -> Rn.0 (save new byte in Rn.0)

; check for end of command
	xri	1
	bnz	notEOC	; check if command execution not yet finished (1 - marker of its` end)
; if end of command	

	lda	r13	; M[Rn] -> D, Rn++	get next command to D
	plo	r4	; D -> Rn.0 

notEOC:

	sep	r14	; call subroutine "scroll" ------->

skipScrollCity:


; ------ SCROLL SKY -------------------------------------------


        glo	r15	; Rn -> D
	ani	%00000011	; slow scroll (4th)
	bnz	skipScrollSky	


	ldi	<VADDR_SKY	; const -> D        
	plo     r6      ; D -> Rn.0
;	ldi	>VADDR_SKY	; const -> D        
;	phi     r6      ; D -> Rn.1


; check for end 
        glo	r5	; Rn -> D
	xri	<endofclouds
	bnz	notRESTARTclouds	; check if command execution not yet finished (1 - marker of its` end)

	ldi	<skydata	; const -> D        
	plo     r5      ; D -> Rn.0
;	ldi	>skydata	; const -> D        
;	phi     r5      ; D -> Rn.1

notRESTARTclouds:


; get byte for new vertical column

	lda	r5	; M[Rn] -> D, Rn++
	plo	r12	; D -> Rn.0 (save new byte in Rn.0)

	SEP	r14	; call subroutine "scroll" ------->


skipScrollSky:


; ------ SCROLL ROAD (only 1px height dashed line) -----------------------------------------

; scroll 1 line one pixel left 

; reset vram addr -> R6 

	ldi	<VADDR_ROAD	; const -> D        
	plo     r6      ; D -> Rn.0
	ldi	>VADDR_ROAD	; const -> D        
	phi     r6      ; D -> Rn.1
; reset  line counter
	ldi	BYTES_PER_LINE*1	; const -> D        
	plo     r7      ; D -> R6.0

; scroll N lines one pixel left

	glo	r15	; Rn -> D
	shr
	shr
	shr

nextbyte2:

	ldx		; M[Rx] -> D
	shlc		; D = D << 1 (carry -> DF)

        stxd		; D -> M(Rx), Rx--
        
        dec	r7	; Rn--
        glo	r7	; Rn -> D
	bnz	nextbyte2

	inc	r15


; ------------------- make two beeps --------
; (via setting system sound counter)

        glo	r15	; Rn -> D
	ani	%11111000	; D + const -> D
	bnz	skipBeep1

	ldi     $8cd & $ff	; const -> D
	plo     r7	; D -> Rn.0
	ldi     10	; const -> D
	str     r7	; D -> M[Rn]
skipBeep1:

        glo	r15	; Rn -> D
	adi	240	; D + const -> D
	ani	%11111000
	bnz	skipBeep2

	ldi     $8cd & $ff	; const -> D            
	plo     r7	; D -> Rn.0
	ldi     15	; const -> D
	str     r7	; D -> M[Rn]
skipBeep2:


	br	nextscroll     ; do forever


; ============= SCROLL CITY/SKY SUBROUTINE =====================
; input: r12

scrollret:
	sep	r3	; return from subroutine
scroll:
	

; set lines counter
	ldi	LINES	; const -> D        
	plo     r10     ; D -> Rn.0


nextline:

; set bytes counter
	ldi	BYTES_PER_LINE	; const -> D        
	plo     r7      ; D -> Rn.0

; set carry to scroll

	glo	r12	; Rn -> D
	shr		; get one bit to set carry
	plo     r12     ; D -> Rn.0 (save shifted byte)

nextbyte:
	ldx		; Rx -> D
	shlc		; D = D << 1 (carry -> DF)
        stxd		; D -> M(Rx), Rx--
        
        dec	r7	; Rn--
        glo	r7	; Rn -> D
	bnz	nextbyte	

        dec	r10	; Rn--
        glo	r10	; Rn -> D
	bnz	nextline	; one line (8 bytes) scrolled, let's scroll next

	br	scrollret

; ======================= DATA ===========================
commands:
	.db	house5
	.db	house2
	.db	house1
	.db	house3
	.db	house2
	.db	house4
	.db	house1
	.db	house3
endofcommands:

skydata:
	.db	%00000000
	.db	%00000000
	.db	%00000000
cloud1:
	.db	%01010000
	.db	%11111000
	.db	%01110000
	.db	%11111000
	.db	%01110000
	.db	%11111000
	.db	%01010000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000

cloud2:	
	.db	%00000010
	.db	%00000111
	.db	%00000010
	.db	%00000111
	.db	%00000010
	.db	%00000000
	.db	%00000000
	.db	%00000000
endofclouds:	

citydata:
house1:
	.db	%00000000
	.db	%11111111
	.db	%10101010
	.db	%11111111
	.db	%10101010
	.db	%11111111
	.db	%00000000
	.db	1
house2:
	.db	%00000000
	.db	%00011111
	.db	%01110101
	.db	%01011111
	.db	%01110101
	.db	%00011111
	.db	%00000000
	.db	1
house3:
	.db	%00000000
	.db	%00001111
	.db	%00001010
	.db	%00001111
	.db	%00001010
	.db	%00001111
	.db	%00000000
	.db	1
house4:
	.db	%00000000
	.db	%00000110
	.db	%00001011
	.db	%00000110
	.db	%00000000
	.db	1
house5:
	.db	%00100000
	.db	%00111111
	.db	%01101010
	.db	%00111111
	.db	%00100000
	.db	1
	
        .end

