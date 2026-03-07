; ******************************************************+
;
; HCCS Forth ROM for the Epson HX-20
;
; ******************************************************+
; Size of binary:             8192 bytes
; Type of EPROM:              27C64
; Original ROM image CRC-32:  1319F181
;
; Systen:                     Epson HX-20
; CPU:                        Hitachi 6301
: RAM, ROM:                   16 KB, this ROM at $6000-$7FFF
;
; Assemble with
;    a09 -OH01 -l forth.asm
; to generate a binary identical image and a listing file.
;
; See below how to adapt to different HX-20 system ROM versions.
;
; This file has been created by Martin Hepperle, 2022.
;
; The code was first disassembled with DASMX Version 1.4
; and then reworked with the help of a symbol file and finally
; manually refined to make the assembler code position independent.
;
; As an example how to extend the ROM into the unused space at its end,
; I addeded new Forth words to the FORTH dictionary.
;
; I also saved a few bytes by replacing add, subtract or store operations
; using (A) and (B) registers by equivalent opcodes using the (D) register.
; The original source already made use of this capability of the 6301,
; but a few places with original 6800 code were still let.
;
; I have commented about 64 unused bytes out, and replaced short jmp 
; instructions by bra opcodes and moved a subroutine.
; This means that the modified ROM will not be binary identical 
; to the original ROM.
;
; However, if you define the following below, you will obtain 
; a binary identical copy of the original ROM:
; ROM_CD          EQU JAPAN | V10
; ROM_EF          EQU JAPAN | V10
; INCLUDE_FLUFF   EQU  1
; MH_EXTENSIONS   EQU  0
; INCLUDE_TRAILER EQU  1
;
; Note to self:
;   The 6103 stack is of the POSTDECREMENTING type:
;   A push first copies the value from the source to the
;   stack and then DECREMENTS (SP).
;   A pull PREINCREMENTS (SP) and then copies the value 
;   on the stack to the destination.
;   In case of 16-bit quantities, the low byte is pushed 
;   first, followed by the high byte.
;   
;   Thus a sequence
;          HHLL       low ...... high 
;   ldx  #$0301       $?? $?? SP  $?? 
;   pshx              SP  $03 $01 $??    TOS has the high byte
;   pula              $?? SP  $01 $??
;   pulb              $?? $?? SP  $??
;   would leave the high byte $03 in (A) and the 
;   low byte $01 in (B).
;
; ******************************************************+
EUROPE EQU 100
JAPAN  EQU 200
V10    EQU 1
V11    EQU 2

; --- select one set
; European, e.g. German HX-20 with Basic V1.0
ROM_CD EQU EUROPE | V10
ROM_EF EQU EUROPE | V10
; ---
; European, e.g. German HX-20 with Basic V1.1
;ROM_CD EQU EUROPE | V11
;ROM_EF EQU EUROPE | V11
; ---
; Japanese and US or UK HX-20 with Basic V1.0
;ROM_CD EQU JAPAN | V10
;ROM_EF EQU JAPAN | V10
; ---
; Japanese and US or UK HX-20 with Basic V1.1
;ROM_CD EQU JAPAN | V11
;ROM_EF EQU JAPAN | V11

; if MH_EXTENSIONS == 1 then extension words are added
;                       to Forth dictionary
MH_EXTENSIONS   EQU  1

; if INCLUDE_TRAILER == 0 then the trailer is filled with $00
;                         otherwise the original trailer bytes
;                         are included
INCLUDE_TRAILER EQU  0

; if INCLUDE_FLUFF == 1 then unused data and code are assembled 
;                       as per original ROM
; This only makes sense, when MH_EXTENSIONS = 0 and 
;                             ROM_.. versions are JAPAN | V10
INCLUDE_FLUFF  	EQU  0

; ===================================
;
; unofficial ROM entries (BASIC ROMs)
;
; ===================================
; ------------------------------
; ROM C000-DFFF
; ------------------------------
	if (ROM_CD & V10) == V10
;		FCB "C000-DFFF V1.0"
ROM_D310     EQU   $D310   ; Basic: MON
ROM_D715     EQU   $D715 
ROM_D735     EQU   $D735   ; "Error"
ROM_D957     EQU   $D957   ; Basic: PSET
ROM_D977     EQU   $D977   ; Basic: PGET
ROM_D9D6     EQU   $D9D6   ; Basic: PLOT 
ROM_DA07     EQU   $DA07 
	else
;		FCB "C000-DFFF V1.1"
; ROM C000-DFFF
ROM_D310     EQU   $D31C   ; Basic: MON - not working
ROM_D715     EQU   $D724
ROM_D735     EQU   $D744   ; "Error"
ROM_D957     EQU   $D967   ; Basic: PSET
ROM_D977     EQU   $D987   ; Basic: PGET
ROM_D9D6     EQU   $D9E6   ; Basic: PLOT
ROM_DA07     EQU   $DA17
	endif

; ------------------------------
; ROM E000-FFFF
; ------------------------------
	if (ROM_EF & EUROPE) == EUROPE
	if (ROM_EF & V10) == V10
;		FCB "E000-FFFF EUROPE_V1.0"
ROM_E1FF     EQU   $E1FF
ROM_E2A5     EQU   $E291          ; printer paper feed by value in (D)
ROM_E2EF     EQU   $E2DB          ; output char in A to printer
ROM_E34D     EQU   $E339
ROM_E3F2     EQU   $E3DE
ROM_E900     EQU   $E900
ROM_EB8F     EQU   $EB6E
	else
;		FCB "E000-FFFF EUROPE_V1.1"
ROM_E1FF     EQU   $E1E0
ROM_E2A5     EQU   $E276          ; printer paper feed by value in (D)
ROM_E2EF     EQU   $E2C0          ; output char in A to printer
ROM_E34D     EQU   $E31E
ROM_E3F2     EQU   $E3C6
ROM_E900     EQU   $E900
ROM_EB8F     EQU   $EB57
	endif
	else
	if (ROM_EF & V10) == V10
;		FCB "EF JAPAN_V1.0"
ROM_E1FF     EQU   $E1FF
ROM_E2A5     EQU   $E2A5          ; printer paper feed by value in (D)
ROM_E2EF     EQU   $E2EF          ; output char in A to printer
ROM_E34D     EQU   $E34D
ROM_E3F2     EQU   $E3F2
ROM_E900     EQU   $E900
ROM_EB8F     EQU   $EB8F
	else
;		FCB "EF JAPAN_V1.1"
ROM_E1FF     EQU   $E1E0
ROM_E2A5     EQU   $E2BA          ; printer paper feed by value in (D)
ROM_E2EF     EQU   $E2D4          ; output char in A to printer
ROM_E34D     EQU   $E332
ROM_E3F2     EQU   $E3DA
ROM_E900     EQU   $E900
ROM_EB8F     EQU   $EB6F
	endif
	endif
; ------------------------------

; published system jump tables in ROM 1
SYS_BILOAD   EQU   $FED7	; binary read file opened by OPNLOD -> jmp BILOAD
SYS_OPNLOD   EQU   $FEDA	; open file for binary read         -> jmp OPNOAD
SYS_BIDUMP   EQU   $FEDD	; binary write to file opened by OPNDMP jmp BIDUMP
SYS_OPNDMP   EQU   $FEE0	; open file for binary write         -> jmp OPNDMP
SYS_DSPSCR   EQU   $FF4F	; display character in (A) on screen -> jmp $DFF1
				                                     -> jmp SCRCHR
				                                     -> jmp D7EF
SYS_KEYIN    EQU   $FF9A	; read key from key stack to (A) (B) -> jmp KEYIN

SYS_RSPOWER  EQU   $FF85 	; RS232 serial power on/off
SYS_RSPUT    EQU   $FF76 	; RS232 serial output
SYS_RSGET    EQU   $FF79 	; RS232 serial input
SYS_RSCLOSE  EQU   $FF7F        ; RS232 close buffered receive
SYS_RSOPEN   EQU   $FF82        ; RS232 open buffered receiver
SYS_RSMODE   EQU   $FF88	; RS232 mode (incorrectly given as FF8A in tech manual)

SYS_CASBUF   EQU   $0378        ; 260 bytes cassette buffer [378-47B]
SYS_RSCOUNT  EQU   $01C2        ; byte count in receive buffer

SYS_OUT_CHR  EQU   $0C10        ; jmp DFF1: output one character to virtual screen and LCD
XDFF1        EQU   $DFF1	; into jump table, fits V1.0 and V1.1

; RAM usage

; computational stack SP starts at $06FE
; it grows downwards
; return stack SP starts at $05FE
; it grows downwards
; dictionary starts at
; it grows upwards
;
; some RAM addresses used in the code
X0050    EQU   $0050     ; $009C for PSET, PGET, PLOT, DRAW work area
X0060    EQU   $0060     ; device name 'M' or 'C'
X0061    EQU   $0061     ; 1=load or 0=save flag
X006A    EQU   $006A     ; I/O error flag

X0080    EQU   $0080     ; used as temporary variables
X0081    EQU   $0081     ; byte
X0082    EQU   $0082     ; word
X0084    EQU   $0084     ; word
X0086    EQU   $0086     ; word
X0088    EQU   $0088     ; word
X008A    EQU   $008A     ; intermediate buffer for character to output
PRNFLAG  EQU   $008B     ; printer LCD=1, printer=2, RS232C=4
PTR_W    EQU   $0090     ; ???? W variables pointer
PTR_IP   EQU   $0092     ; IP instruction pointer
PTR_RP   EQU   $0094     ; RP return stack pointer
PTR_SP   EQU   $0096     ; SP data stack pointer
X0098    EQU   $0098     ; may at one time be $4F4B 'OK'

X009D    EQU   $009D     ; in Basic work area filled in by PGET
;
; $B0...$B5: date/time buffer with 2 digit BCD numbers: 
; $B0 = month                           filled by (CLK)
; $B1 = day
; $B2 = year
; $B3 = hour
; $B4 = minutes
; $B5 = seconds
;
MEMEND  EQU    $0B30     ; LIMIT
;
FNTGPN   EQU   $011E     ; user defined character address
KEYCODE  EQU   $016D     ; input key code (1 byte, 2 bytes for PF keys)
;
TAPE_CNT EQU   $0203     ; microcassette tape count
;
X04C0    EQU   $04C0     ; FENCE,    ever used?
X04C2    EQU   $04C2     ; DP0,      ever used?
X04C4    EQU   $04C4     ; VOC-LINK, ever used?
;
X04E8    EQU   $04E8     ; 16-bit value with ZERO AND MASK $007F
X04E9    EQU   (X04E8+1) ; low byte = MASK $7F 
;
;	avoid line breaks due to long comment lines
	setli 160
;
; NFA_... bits:
; $80 = precedence bits 100.....
; $C0 = precedence bits 110..... immediate
; $20 = precedence bits 001..... smudge
; STATE =   0 : executing
; STATE = $C0 : compiling
;
; This ROM starts at address $6000
;
	org	$6000

; ******************************************************+
; ROM Header
; ******************************************************+
ID_1:
	FCB	':' | $80        ; Program appears in Menu
ID_2:
	FCB	"A"              ; 'A'pplication, uses absolute addresses
LINK_NEXT_ROM:
	FDB	$FFFF            ; no additional programs in this ROM
ENTRY_POINT:
	FDB	INIT_ROUTINE     ; the entry point
MENU_NAME:
	FCB	"FORTH",$00      ; shown in the menu
; ******************************************************+

; ******************************************************+
INIT_ROUTINE:
	nop                      ; word aligned 
	jmp	RESTART          ;
	nop                      ; word aligned
	jmp	DOWARM           ;
; --------------------------------
	fdb	$6301	         ; cpu type, not really used
	fdb     $0100            ; revision, not really used 
; --------------------------------
;       address of topmost word in Forth vocabulary
; never used????
	if MH_EXTENSIONS == 1
	FDB	NFA_TWODIV          ; link to latest top word
	else
	FDB	NFA_TWOMUL          ; link to top word "2*"
	endif
DATA_BS:
	fdb     $0008            ; backspace character, used in EXPECT
; --------------------------------
ADDR_USER:
	fdb	$04B0            ; start of USER variables area
ADDR_SP0:
	fdb	$06FE            ; initial SP = S0, grows down to $05FF
ADDR_RP0:
	fdb	$05FE            ; initial RP = R0, grows down to $0540
	fdb	$0500            ; address of TIB
	fdb	$001F            ; max. name field WIDTH (31 characters)
	fdb	$0000            ; initial WARNING
ADDR_FENCE:
	fdb	$1000            ; initial FENCE
ADDR_DP0:
	fdb	$1000            ; cold start DP
ADDR_VL0:
	fdb	$0D0E            ; cold start VOC-LINK
	fdb	$0040            ; never used ????
CHAR_MASK:
	fdb	$007F            ; MASK
; --------------------------------
LFA_GET_ADD:                     ; internal word: "@ +"
	fdb	$0000            ; unlinked
CFA_GET_ADD:
	fdb	DOCOL
	fdb	CFA_GET
	fdb	CFA_PLUS
	fdb	CFA_SEMIS
; --------------------------------
OUT_CRLF:
	if MH_EXTENSIONS
	; swap to more common CR/LF sequence
	ldaa	#$0D                 ; carriage return
	bsr	OUT_ONECHAR
	ldaa	#$0A                 ; line feed
	bsr	OUT_ONECHAR
	else
	ldaa	#$0A                 ; line feed
	bsr	OUT_ONECHAR
	ldaa	#$0D                 ; carriage return
	bsr	OUT_ONECHAR
	endif
	rts

	; if output from EMIT, then mask bit 7 off
OUT_7BITCHAR:                        ; entry from EMIT
	anda	X04E9                ; $7F mask bit 7 off

OUT_ONECHAR:
	jsr	OUT_CHR
	rts
;
	if INCLUDE_FLUFF == 1
	; 1 excess byte
	FCB	$00
	endif

; ----- XFILE dump I/O
L604D:
	ldab	X0060	             ; (B) = device name 'C' or 'M'
	clra
	ldx	#$02A4               ; address of i/o packet
	tst	X0061	             ; 1=load or 0=save
	beq	L605D
	jsr	SYS_OPNLOD
	bra	L6060
;
L605D:
	jsr	SYS_OPNDMP           ; dump
L6060:
	staa	X006A                ; error flag
	bne	ERR_MSIO
	bcs	ERR_MSIO

	ldab	X0060	             ; (B) = device name 'C' or 'M'
	tst	X0061	             ; 1=load or 0=save
	beq	DUMP_BIN             ; dump

	ldx	$02BB                ; destination offset ($0000)
	jsr	SYS_BILOAD           ; load
	bra	MSIO_DONE
;
DUMP_BIN:
	jsr	SYS_BIDUMP
MSIO_DONE:
	staa	X006A
	bne	ERR_MSIO             ; error
	bcs	ERR_MSIO             ; error
	jmp	NEXT
; 
ERR_MSIO:
	ldx	#ROM_D735          ; address of 'Error' in system ROM
	ldab	#$05               ; string length
	jsr	ROM_D715           ; display 'Error' string
	jmp	L70AF              ; do a warm start
; ----- XFILE

; arrives here from CFA_SEI
L608C:
	ldx	#$0080
	ldab	#$08
L6091:
	pula
	staa	$00,x
	inx
	decb
	bne	L6091
	sts	X0088
	lds	X0086
	des
	ldd	X0084
	addd	X0086
	std	X0084
L60A3:
	ldx	X0082
	dex
	ldab	#$FF
L60A8:
	incb
	inx
	cmpb	X0081
	bcc	L60C3
	pula
	cmpa	$00,x
	beq	L60A8
	tsx
	cpx	X0084
	bcc	L60BA
	bra	L60A3
;
L60BA:
	lds	X0088
	clra
	psha
	psha
	stx	X0084
	bra	L60CC
;
L60C3:
	tsx
	lds	X0088
	stx	X0084
	ldx	#$0001
	pshx
L60CC:
	ldd	X0084
	subd	X0086
	jmp	CFA_CLI

	if INCLUDE_FLUFF == 1
	; 2 excess bytes
	FCB	$36                ; unused bytes ????
	FCB	$86                ; unused bytes ????
	endif

READ_KEYS:
	jsr	SYS_KEYIN          ; get a key to (A)(B)

	if MH_EXTENSIONS == 1
	cmpa	#$FE               ; 2-byte sequence?
	; (A) $FE to high byte, (B) PF key to low byte
	beq	NEXT_PSH_D
	endif

	cmpa	#$1F               ; below space character?
	bls	TEST_CHAR
L60DC:
	rts
;
TEST_CHAR:
	cmpa	#$08               ; DEL key? -> return
	beq	L60DC
	cmpa	#$0D               ; ENTER key? -> return
	beq	L60DC
	jsr	SYS_OUT_CHR        ; output character to LCD via jmp DFF1 which will rts here
	bra	READ_KEYS              ; get next key

; --------------------------------
	if INCLUDE_FLUFF == 1
	; 9 excess bytes
	FCB	$00
	nop
	bra	L60FC
;NFA_PPLUSLOOPFRAGMENT:             ; ???? never used
	FCB	$80|7
;PPLUSLOOPFRAGMENT:
	FCB	"(+LO"
	endif
; --------------------------------
CFA_ERR_BEEP:
	FDB	DOCOL              ; used by ERROR
	FDB	CFA_LIT_BYTE
	FCB	$02                ; duration for BEEP
	FDB	CFA_BEEP
	FDB	CFA_SEMIS
; --------------------------------
L60FC:
	inx
	inc	X0081              ; low byte
	bne	L6105              ; not zero: no overflow: skip
	inc	X0080              ; else: increment high byte
L6105:
	rts
; --------------------------------
OUT_CHR:
	if MH_EXTENSIONS == 1
	; ----- new handler for PRINT flag
	; bits 2,1,0 = RS232C,PRN,LCD
	ldab	PRNFLAG
	beq	OUT_3              ; if zero: no output at all
OUT_0:
	asrb	                   ; shift bit 0 to C
	bcs	OUT_LCD

OUT_1:
	asrb	                   ; shift bit 1 to C
	bcs	OUT_PRN

OUT_2:
	asrb	                   ; shift bit 2 to C
	bcs	OUT_RS232

OUT_3:                             
	rts	                   ; done

; --- output routines
OUT_LCD:
;	ldaa	X008A              ; restore character
	psha	                   ; save chaacter
	pshb	                   ; save shifted bits
	jsr	SYS_OUT_CHR        ; output character to virtual screen and LCD
	pulb	                   ; restore shifted bits
	pula	                   ; restore
	bra	OUT_1

OUT_PRN:
;	ldaa	X008A              ; restore character
	psha	                   ; save character
	pshb	                   ; save shifted bits
	jsr	ROM_E2EF           ; output character to printer
	pulb	                   ; restore shifted bits
	pula	                   ; restore
	bra	OUT_2

OUT_RS232:
;	ldaa	X008A              ; restore character
	jsr	SYS_RSPUT         ; else: output character to RS232C
;	bra	OUT_3              ; done, return
	rts	; saves 1 byte

	; ----- end of new handler

	else

	; ----- original handler for PRINT flag
	staa	X008A              ; save 7-bit character to output
	jsr	SYS_OUT_CHR        ; output character to LCD
	ldab	PRNFLAG
	beq	L6114              ; if zero: skip
	ldaa	X008A              ; restore character
	jsr	ROM_E2EF           ; output character to printer
L6114:                             
	rts

	; ----- end of original handler
	endif

; --------------------------------
CR_OR_DEL:
	ldaa	KEYCODE            ; get 1-byte key code to (A)
	cmpa	#$0D               ; CR pressed
	beq	L6123              ; clear (A) and return

	cmpa	#$08               ; DEL key pressed
	beq	L6124              ; leave code in (A)

	if INCLUDE_FLUFF == 1
	; 3 excess bytes
	nop
	nop
	nop
	endif

L6123:
	clra
L6124:
	rts
; --------------------------------
	if INCLUDE_FLUFF == 1
	; 1 excess byte
	FCB	$00             ; ???? unused byte ????
	endif
;
L6126:
	pula
	pulb
L6128:
	std	$00,x
	bra	NEXT
;
NEXT_PSH_REF_X:                 ; return contents of *(X)
	ldd	$00,x
NEXT_PSH_D:                     ; push (D) to stack, used by machine language words
	pshb                    ; low byte       (D) = (A)(B)
	psha                    ; high byte
NEXT:                           ; used by machine language words
	ldx	PTR_IP
NEXT_IPINX:                     ; (X) has been preset to IP
	inx			; increment IP to next word
	inx
	stx	PTR_IP          ; store new IP
L6136:
	ldx	$00,x           ; get next word from IP chain
L6138:
	stx	PTR_W           ; save word
	ldx	$00,x           ; get address
	jmp	$00,x           ; and ... jump
;
	if INCLUDE_FLUFF == 1
	; 1 excess byte
	nop                     ; ???? unused byte ????
	endif
; --------------------------------
; first word in dictionary
; --------------------------------
NFA_LIT:
	FCB	$80|3
LIT:
	FCB	"LI",('T'|$80)
LFA_LIT:
	FDB	$0000           ; unlinked, first word in chain
CFA_LIT_WORD:                   ; get next word from execution stack
	FDB     *+2
	ldx	PTR_IP          ; instruction pointer
	inx
	inx                     ; increment to next word
	stx	PTR_IP
	ldd	$00,x           ; load 16-bit from *(X) word to (D)
	if INCLUDE_FLUFF == 1
	; 3 bytes 
	jmp	NEXT_PSH_D
	else
	; 1 excess byte less
	bra	NEXT_PSH_D
	endif
; same for literal byte
CFA_LIT_BYTE:                   ; get next byte from execution stack
	FDB     *+2
	ldx	PTR_IP          ; execution pointer
	inx                     ; increment to next byte
	stx	PTR_IP
	clra                    ; high byte = 0
	ldab	$01,x           ; one byte 
	if INCLUDE_FLUFF == 1
	jmp	NEXT_PSH_D
	else
	; 1 excess byte less
	bra	NEXT_PSH_D
	endif
; --------------------------------
NFA_EXECUTE:
	FCB	$80|7
EXECUTE:
	FCB	"EXECUT",('E'|$80)
LFA_EXECUTE:
	FDB	NFA_LIT
CFA_EXECUTE:
	FDB     *+2
;
	pulx
	if INCLUDE_FLUFF == 1
	jmp	L6138
	else
	; 1 excess byte less
	bra	L6138
	endif

	if INCLUDE_FLUFF == 1
	; 4 excess bytes
	ins                        ; ???? unused byte
	jmp	L6138              ; ???? unused byte
	endif
; --------------------------------
NFA_BRANCH:
	FCB	$80|6
BRANCH:
	FCB	"BRANC",('H'|$80)
LFA_BRANCH:
	FDB	NFA_EXECUTE
CFA_BRANCH:
	FDB	DOBRANCH
; --------------------------------
NFA_ZEROBRANCH:
	FCB	$80|7
ZEROBRANCH:
	FCB	"0BRANC",('H'|$80)
LFA_ZEROBRANCH:
	FDB	NFA_BRANCH
CFA_ZEROBRANCH:
	FDB     *+2
	pula
	pulb
	aba
	bne	L619C
	bcs	L619C
DOBRANCH:
	ldx	PTR_IP
	ldd	$02,x
	addd	PTR_IP
	std	PTR_IP

	if INCLUDE_FLUFF == 1
	; 3 bytes
	jmp	NEXT
	else
	; 1 excess byte less
	bra	NEXT
	endif
;
L619C:
	ldx	PTR_IP
	inx
	inx
	stx	PTR_IP
	if INCLUDE_FLUFF == 1
	; 3 bytes
	jmp	NEXT
	else
	; 1 excess byte less
	bra	NEXT
	endif
; --------------------------------
NFA_PARLOOP:
	FCB	$80|6
PARLOOP:
	FCB	"(LOOP",(')'|$80)
LFA_PARLOOP:
	FDB	NFA_ZEROBRANCH
CFA_PARLOOP:
	FDB	*+2
	clra
	ldab	#$01
	bra	L61C3
; --------------------------------
NFA_PARPLOOP:
	FCB	$80|7
PARPLOOP:
	FCB	"(+LOOP",(')'|$80)
LFA_PARPLOOP:
	FDB	NFA_PARLOOP
CFA_PARPLOOP:
	FDB	*+2
	pula
	pulb
L61C3:
	tsta
	bpl	L61D8
	bsr	L61D1
	sec
	sbcb	$05,x
	sbca	$04,x
	bpl	DOBRANCH
	bra	L61E0
;
L61D1:
	ldx	PTR_RP
	addd	$02,x
	std	$02,x
	rts
;
L61D8:
	bsr	L61D1
	if MH_EXTENSIONS == 1
; hey, we have a 6301 and could use SUBD, saving 2 bytes
	subd	$04,x
	else
; original code
	subb	$05,x
	sbca	$04,x
	endif
;
	bmi	DOBRANCH
L61E0:
	inx
	inx                       ; +2
	inx
	inx                       ; +4
	stx	PTR_RP
	bra	L619C
; --------------------------------
NFA_PARDO:
	FCB	$80|4
PARDO:
	FCB	"(DO",(')'|$80)
LFA_PARDO:
	FDB	NFA_PARPLOOP
CFA_PARDO:
	FDB	*+2
	ldx	PTR_RP
	dex
	dex                     ; -2
	dex
	dex                     ; -4
	stx	PTR_RP
	pula
	pulb
	std	$02,x
	pula
	pulb
	std	$04,x
	jmp	NEXT
; --------------------------------
NFA_I:
	FCB	$80|1
I:
	FCB	$C9
LFA_I:
	FDB	NFA_PARDO
CFA_I:
	FDB	*+2
	ldx	PTR_RP
	inx
	inx                     ; get address of I: RP+2
	jmp	NEXT_PSH_REF_X  ; return contents of J = *(X)
; --------------------------------
NFA_DIGIT:
	FCB	$80|5
DIGIT:
	FCB	"DIGI",('T'|$80)
LFA_DIGIT:
	FDB	NFA_I
CFA_DIGIT:
	FDB	*+2
	tsx
	ldaa	$03,x
	suba	#$30
	bmi	L623D
	cmpa	#$0A
	bmi	L6230
	cmpa	#$11
	bmi	L623D
	cmpa	#$2B
	bpl	L623D
	suba	#$07
L6230:
	cmpa	$01,x
	bpl	L623D
	ldab	#$01
	staa	$03,x
L6238:
	stab	$01,x
	jmp	NEXT
;
L623D:
	clrb
	ins
	ins
	tsx
	stab	$00,x
	bra	L6238
; --------------------------------
NFA_PARFIND:
	FCB	$80|6
PARFIND:
	FCB	"(FIND",(')'|$80)
LFA_PARFIND:
	FDB	NFA_DIGIT
CFA_PARFIND:
	FDB	*+2
	if INCLUDE_FLUFF == 1
	; excess 2 bytes
	nop
	nop
	endif
        ; copy 4 bytes from stack to $0080...$0083
        ; $0080-81: nfa start address for search
	; $0082-83: text buffer with length byte and name string
	ldx	#$0080
	ldab	#$04
CPY_PARS:
	pula
	staa	$00,x          ; -> $0080,1,2,3
	inx
	decb                   ; 3,2,1,0
	bne	CPY_PARS

	ldx	X0080          ; NFA
L6260:
	ldab	$00,x          ; get *NFA = length | $80
	stab	X0086          ; save *NFA
	andb	#$3F           ; length
	inx                    ; to name string of word
	stx	X0080          ; address of first character
	ldx	X0082          ; text to find
	ldaa	$00,x          ; length byte
	inx
	stx	X0084          ; $0084-85: pFind: name to find
	cba
	bne	FIND_SKIP      ; lengths do not match
FIND_MORE:
	ldx	X0084
	ldaa	$00,x          ; (A) = *pFind
	inx
	stx	X0084          ; pFind++
	ldx	X0080          
	ldab	$00,x          ; (B) = *pSearch
	inx
	stx	X0080          ; pSearch++
	tstb                   ; MSB of *pSearch clear? (last character | $80)
	bpl	FIND_TEST      ; branch if N clear
	; last character
	andb	#$7F           ; clear bit 7
	cba                    ; equal?
	beq	FIND_DONE      ; branch if yes: all characters matched
L6289:
	ldx	$00,x
	bne	L6260
	clra
	clrb                   ; return false
	jmp	NEXT_PSH_D
;
FIND_TEST:
	cba
	beq	FIND_MORE      ; characters match

FIND_SKIP:                     ; to next dictionary entry
	ldx	X0080
L6297:
	ldab	$00,x
	inx
	bpl	L6297
	bra	L6289
;
FIND_DONE:
	ldd	X0080                  ; has LFA
	addd	#$0004                 ; to PFA
	pshb
	psha                           ; return PFA

	ldaa	X0086                  ; get NFA length byte
	psha                           ;
	clra
	psha                           ; high 0

	; (A) is still 0
	ldab	#$01                   ; true

	jmp	NEXT_PSH_D
; --------------------------------
NFA_ENCLOSE:
	FCB	$80|7
ENCLOSE:
	FCB	"ENCLOS",('E'|$80)
LFA_ENCLOSE:
	FDB	NFA_PARFIND
CFA_ENCLOSE:
	FDB	*+2
	clra
	clrb
	std	X0080              ; save
	ins
	pulb
	tsx
	ldx	$00,x
L62C4:
	ldaa	$00,x
	beq	L62EB
	cba
	bne	L62D0
	jsr	L60FC              ; increment (X) and word at [$80-$81]
	bra	L62C4
;
L62D0:
	ldaa	X0081
	psha
	ldaa	X0080
	psha                       ; push word at [$80-$81]
L62D6:
	ldaa	$00,x
	beq	L62F4              ; 0: no increment
	cba
	beq	L62E2
	jsr	L60FC              ; increment (X) and word at [$80-$81]
	bra	L62D6
;
L62E2:
	ldd	X0080
	pshb
	psha                       ; push word at [$80-$81]
	addd	#$0001             ; + 1
	bra	L62F8              ; (D) has word + 1
;
L62EB:
	ldd	X0080
	pshb
	psha                       ; push word at [$80-$81]
	addd	#$0001             ; + 1
	bra	L62F6              ; (D) has word + 1
;
L62F4:
	ldd	X0080              ; (D) has word at [$80-$81]
L62F6:
	pshb
	psha                       ; push word at [$80-$81] or word + 1
L62F8:
	jmp	NEXT_PSH_D
; --------------------------------
NFA_EMIT:
	FCB	$80|4
EMIT:
	FCB	"EMI",('T'|$80)
LFA_EMIT:
	FDB	NFA_ENCLOSE
CFA_EMIT:
	FDB	*+2
	pula
	pula                          ; use byte value only
	jsr	OUT_7BITCHAR          ; mask bit 7 off and finally jsr ROM_E2EF
	ldx	PTR_SP                ;
	inc	$1B,x                 ; increment cursor position low byte
	bne	EMIT1                 ; overflow, if low byte became 0
	inc	$1A,x                 ; increment high byte
EMIT1:
	jmp	NEXT
; --------------------------------
NFA_KEY:
	FCB	$80|3
KEY:
	FCB	"KE",('Y'|$80)
LFA_KEY:
	FDB	NFA_EMIT
CFA_KEY:
	FDB	*+2
	jsr	READ_KEYS
	psha              ; key to low byte
	clra              ; zero high byte 
	psha
	jmp	NEXT
; --------------------------------
NFA_QUESTTERM:
	FCB	$80|5
QUESTTERM:
	FCB	"?TER",('M'|$80)
LFA_QUESTTERM:
	FDB	NFA_KEY
CFA_QUESTTERM:
	FDB	*+2
	jsr	CR_OR_DEL          ; returns 8 when DEL has been pressed, else 0
	clrb
	jmp	NEXT_PSH_D
; --------------------------------
NFA_CR:
	FCB	$80|2
CR:
	FCB	"C",('R'|$80)
LFA_CR:
	FDB	NFA_QUESTTERM
CFA_CR:
	FDB	*+2
	jsr	OUT_CRLF
	jmp	NEXT
; --------------------------------
NFA_CMOVE:
	FCB	$80|5
CMOVE:
	FCB	"CMOV",('E'|$80)
LFA_CMOVE:
	FDB	NFA_CR
CFA_CMOVE:
	FDB	*+2
	ldx	#$0080
	ldab	#$06
CMOVE1:
	pula
	staa	$00,x
	inx
	decb
	bne	CMOVE1
CMOVE2:
	ldaa	X0080
	ldab	X0081
	if MH_EXTENSIONS == 1
; hey, we have a 6301 and could use SUBD, saving 1 byte, ...
	subd	#$0001
; ... and STD, saving 2 more bytes
	std	X0080
	else
; original code
	subb	#$01
	sbca	#$00
	staa	X0080
	stab	X0081
	endif
;
	bcs	CMOVE3
	ldx	X0084
	ldaa	$00,x
	inx
	stx	X0084
	ldx	X0082
	staa	$00,x
	inx
	stx	X0082
	bra	CMOVE2
CMOVE3:
	jmp	NEXT
; --------------------------------
NFA_UMUL:
	FCB	$80|2
UMUL:
	FCB	"U",('*'|$80)
LFA_UMUL:
	FDB	NFA_CMOVE
CFA_UMUL:
	FDB	*+2
	bsr	L6388
	ins
	ins
	jmp	NEXT_PSH_D
;
L6388:
	ldaa	#$10
	psha
	clra
	clrb
	tsx
L638E:
	ror	$05,x
	ror	$06,x
	dec	$00,x
	bmi	L63A0
	bcc	L639C
	if MH_EXTENSIONS == 1
; hey, we have a 6301 and could use this, using 2 bytes only
	addd	$03,x
	else
; original code
	addb	$04,x          ; no carry
	adca	$03,x          ; with carry
	endif
L639C:
	rora
	rorb
	bra	L638E
;
L63A0:
	ins
	rts
; --------------------------------
NFA_UDIV:
	FCB	$80|2
UDIV:
	FCB	"U",('/'|$80)
LFA_UDIV:
	FDB	NFA_UMUL
CFA_UDIV:
	FDB	*+2
	ldaa	#$11
	psha
	tsx
	ldaa	$03,x
	ldab	$04,x
L63B1:
	cmpa	$01,x
	bhi	L63BE
	bcs	L63BB
	cmpb	$02,x
	bcc	L63BE
L63BB:
	clc
	bra	L63C3
;
L63BE:
	if MH_EXTENSIONS == 1
; hey, we have a 6301 and could use this:
	subd	$01,x
	else
; original code
	subb	$02,x
	sbca	$01,x
	endif
;
	sec
L63C3:
	rol	$06,x
	rol	$05,x
	dec	$00,x
	beq	L63D1
	rolb
	rola
	bcc	L63B1
	bra	L63BE
;
L63D1:
	ins
	ins
	ins
	ins
	ins
	jmp	L654F
; --------------------------------
NFA_AND:
	FCB	$80|3
AND:
	FCB	"AN",('D'|$80)
LFA_AND:
	FDB	NFA_UDIV
CFA_AND:
	FDB	*+2
	pula	; high byte
	pulb	; low byte
	tsx
	andb	$01,x
	anda	$00,x
	jmp	L6128
; --------------------------------
NFA_OR:
	FCB	$80|2
OR:
	FCB	"O",('R'|$80)
LFA_OR:
	FDB	NFA_AND
CFA_OR:
	FDB	*+2
	pula
	pulb
	tsx
	orab	$01,x
	oraa	$00,x
	jmp	L6128
; --------------------------------
NFA_XOR:
	FCB	$80|3
XOR:
	FCB	"XO",('R'|$80)
LFA_XOR:
	FDB	NFA_OR
CFA_XOR:
	FDB	*+2
	pula
	pulb
	tsx
	eorb	$01,x
	eora	$00,x
	jmp	L6128
; --------------------------------
NFA_SPGET:
	FCB	$80|3
SPGET:
	FCB	"SP",('@'|$80)
LFA_SPGET:
	FDB	NFA_XOR
CFA_SPGET:
	FDB	*+2
	tsx                   ; (SP) to (X)
	stx	X0080         ; save (SP) in $80-$81
	ldx	#$0080        ; load address
	jmp	NEXT_PSH_REF_X  ; return contents of *(X) == (SP)
; --------------------------------
NFA_SPSTOR:
	FCB	$80|3
SPSTOR:
	FCB	"SP",('!'|$80)
LFA_SPSTOR:
	FDB	NFA_SPGET
CFA_SPSTOR:
	FDB	*+2
	ldx	PTR_SP        ; get current (SP)
	ldx	$06,x         ; get word: *(SP+6)  (3 reserved variables)
	txs                   ; set SP to this value
	jmp	NEXT
; --------------------------------
NFA_RPSTOR:
	FCB	$80|3
RPSTOR:
	FCB	"RP",('!'|$80)
LFA_RPSTOR:
	FDB	NFA_SPSTOR
CFA_RPSTOR:
	FDB	*+2
L6437:
	ldx	ADDR_RP0                ; initial RP $05FE
	stx	PTR_RP                ; initialize return stack pointer
	jmp	NEXT
; --------------------------------
NFA_SEMIS:
	FCB	$80|2
SEMIS:
	FCB	";",('S'|$80)
LFA_SEMIS:
	FDB	NFA_RPSTOR
CFA_SEMIS:
	FDB	*+2
	ldx	PTR_RP                ; get return stack pointer RP
	inx
	inx                           ; back to previous level
	stx	PTR_RP                ; store updated RP
	ldx	$00,x                 ; get return address to (X) and then to IP
	jmp	NEXT_IPINX            ; moves (X) to IP
; --------------------------------
NFA_LEAVE:
	FCB	$80|5
LEAVE:
	FCB	"LEAV",('E'|$80)
LFA_LEAVE:
	FDB	NFA_SEMIS
CFA_LEAVE:
	FDB	*+2
	ldx	PTR_RP               ; get return stack pointer RP
	ldd	$02,x                ; get last word from return stack
	std	$04,x                ; store as 3rd word
	jmp	NEXT
; --------------------------------
NFA_TOR:
	FCB	$80|2
TOR:
	FCB	">",('R'|$80)
LFA_TOR:
	FDB	NFA_LEAVE
CFA_TOR:
	FDB	*+2
	ldx	PTR_RP       ; get return stack pointer RP
	dex
	dex
	stx	PTR_RP       ; store decremented RP, points to empty space
	pula
	pulb                 ; get word
	std	$02,x        ; push word above current RP
	jmp	NEXT
; --------------------------------
NFA_FROMR:
	FCB	$80|2
FROMR:
	FCB	"R",('>'|$80)
LFA_FROMR:
	FDB	NFA_TOR
CFA_FROMR:
	FDB	*+2
	ldx	PTR_RP
	ldd	$02,x          ; get word off RP stack
	inx
	inx
	stx	PTR_RP         ; back one level
	jmp	NEXT_PSH_D     ; push to calculation stack
; --------------------------------
NFA_R:
	FCB	$80|1
R:
	FCB	('R'|$80)
LFA_R:
	FDB	NFA_FROMR
CFA_R:
	FDB	*+2
	ldx	PTR_RP           ; get current (free) RP
	inx
	inx                      ; back to previous (occupied) slot
	jmp	NEXT_PSH_REF_X   ; return contents of J = *(X)
; --------------------------------
NFA_ZEROEQ:
	FCB	$80|2
ZEROEQ:
	FCB	"0",('='|$80)
LFA_ZEROEQ:
	FDB	NFA_R
CFA_ZEROEQ:
	FDB	*+2
	tsx                      ; get address of word on stack
	clra
	clrb                     ; zero
	ldx	$00,x            ; load word and (re)set Z bit
	bne	L64A6            ; Zero bit not set: leave 0 
	incb                     ; make 1
L64A6:
	tsx                      ; replace word by 0 or 1
	jmp	L6128
; --------------------------------
NFA_ZEROLT:
	FCB	$80|2
ZEROLT:
	FCB	"0",('<'|$80)
LFA_ZEROLT:
	FDB	NFA_ZEROEQ
CFA_ZEROLT:
	FDB	*+2
	tsx
	ldaa	#$80
	anda	$00,x
	beq	L64BE
	clra
	ldab	#$01
	jmp	L6128
;
L64BE:
	clrb
	jmp	L6128
; --------------------------------
NFA_PLUS:
	FCB	$80|1
PLUS:
	FCB	('+'|$80)
LFA_PLUS:
	FDB	NFA_ZEROLT
CFA_PLUS:
	FDB	*+2
	pula
	pulb
	tsx
	addd	$00,x
	jmp	L6128
; --------------------------------
NFA_DPLUS:
	FCB	$80|2
DPLUS:
	FCB	"D",('+'|$80)
LFA_DPLUS:
	FDB	NFA_PLUS
CFA_DPLUS:
	FDB	*+2
	tsx
	clc
	ldab	#$04
L64DB:
	ldaa	$03,x
	adca	$07,x
	staa	$07,x
	dex
	decb
	bne	L64DB
	ins
	ins
	ins
	ins
	jmp	NEXT
; --------------------------------
NFA_NEGATE:
	FCB	$80|5
NEGATE:
	FCB	"MINU",('S'|$80)
LFA_NEGATE:
	FDB	NFA_DPLUS
CFA_NEGATE:
	FDB	*+2
	tsx		; get address of word
	neg	$01,x	; invert low byte
	bcs	NEGATE_1	
	neg	$00,x	; invert high byte
	bra	NEGATE_2
NEGATE_1:
	com	$00,x	; complement high byte
NEGATE_2:
	jmp	NEXT
; --------------------------------
NFA_DNEGATE:
	FCB	$80|6
DNEGATE:
	FCB	"DMINU",('S'|$80)
LFA_DNEGATE:
	FDB	NFA_NEGATE
CFA_DNEGATE:
	FDB	*+2
	tsx
	com	$00,x
	com	$01,x
	com	$02,x
	neg	$03,x
	bne	L6524
	inc	$02,x
	bne	L6524
	inc	$01,x
	bne	L6524
	inc	$00,x
L6524:
	jmp	NEXT
; --------------------------------
NFA_OVER:
	FCB	$80|4
OVER:
	FCB	"OVE",('R'|$80)
LFA_OVER:
	FDB	NFA_DNEGATE
CFA_OVER:
	FDB	*+2
	tsx
	ldd	$02,x
	jmp	NEXT_PSH_D
; --------------------------------
NFA_DROP:
	FCB	$80|4
DROP:
	FCB	"DRO",('P'|$80)
LFA_DROP:
	FDB	NFA_OVER
CFA_DROP:
	FDB	*+2
DROP_RET:
	ins
	ins
	jmp	NEXT
; --------------------------------
NFA_SWAP:
	FCB	$80|4
SWAP:
	FCB	"SWA",('P'|$80)
LFA_SWAP:
	FDB	NFA_DROP
CFA_SWAP:
	FDB	*+2
	pula                  ; low byte is on top
	pulb                  ; first word to (B)(A)
L654F:
	pulx                  ; second word to (X)
	pshb                  ; first word to stack
	psha                  ; low byte last
	pshx                  ; second word to top of stack 
	jmp	NEXT
;                             ; duplicated from SP@
	if INCLUDE_FLUFF == 1
	; 7 excess bytes
	stx	X0080         ; unused code ????
	ldx	#$0080        ; unused code ????
	jmp	NEXT_PSH_REF_X  ; unused code ????
	endif
; --------------------------------
NFA_DUP:
	FCB	$80|3
DUP:
	FCB	"DU",('P'|$80)
LFA_DUP:
	FDB	NFA_SWAP
CFA_DUP:
	FDB	*+2
	pula                  ; low byte is on top
	pulb                  ; first word to (B)(A)
	pshb                  ; restore stack
	psha                  ; copy of top word in (B)(A)
	jmp	NEXT_PSH_D    ; push this copy and NEXT
; --------------------------------
NFA_PLUSSTORE:
	FCB	$80|2
PLUSSTORE:
	FCB	"+",('!'|$80)
LFA_PLUSSTORE:
	FDB	NFA_DUP
CFA_PLUSSTORE:
	FDB	*+2
	pulx
	pula
	pulb
	addd	$00,x
	std	$00,x
	jmp	NEXT
;
	if INCLUDE_FLUFF == 1
	; 1 excess byte
	FCB	$00
	; 3 excess byte
	jmp	NEXT
	endif
; --------------------------------
NFA_TOGGLE:
	FCB	$80|6
TOGGLE:
	FCB	"TOGGL",('E'|$80)
LFA_TOGGLE:
	FDB	NFA_PLUSSTORE
CFA_TOGGLE:
	FDB	DOCOL
	FDB	CFA_OVER
	FDB	CFA_CGET
	FDB	CFA_XOR
	FDB	CFA_SWAP
	FDB	CFA_CSTOR
	FDB	CFA_SEMIS
; --------------------------------
NFA_GET:
	FCB	$80|1
GET:
	FCB	('@'|$80)
LFA_GET:
	FDB	NFA_TOGGLE
CFA_GET:
	FDB	*+2
;
L659F:
	pulx
	jmp	NEXT_PSH_REF_X   ; return contents of *(X)
;
	if INCLUDE_FLUFF == 1
	; 4 excess bytes
	ins                       ; unused code ????
	jmp	NEXT_PSH_REF_X    ; unused code ????
	endif
; --------------------------------
NFA_CGET:
	FCB	$80|2
CGET:
	FCB	"C",('@'|$80)
LFA_CGET:
	FDB	NFA_GET
CFA_CGET:
	FDB	*+2
	pulx
	clra
	ldab	$00,x
	jmp	NEXT_PSH_D
;
	if INCLUDE_FLUFF == 1
	; 4 excess bytes
	ins                            ; unused bytes ????
	jmp	NEXT_PSH_D             ; never used ????
	endif
; --------------------------------
NFA_EXCLAM:
	FCB	$80|1
EXCLAM:
	FCB	$A1
LFA_EXCLAM:
	FDB	NFA_CGET
CFA_EXCLAM:
	FDB	*+2
	pulx
	jmp	L6126

	if INCLUDE_FLUFF == 1
	; 4 excess bytes
	ins
	jmp	L6126
	endif
; --------------------------------
NFA_CSTOR:
	FCB	$80|2
CSTOR:
	FCB	"C",('!'|$80)
LFA_CSTOR:
	FDB	NFA_EXCLAM
CFA_CSTOR:
	FDB	*+2
	pulx
	ins
	pulb
	stab	$00,x
	jmp	NEXT

	if INCLUDE_FLUFF == 1
	; 4 excess bytes
	FCB	$00
	jmp	NEXT
	endif
; --------------------------------
NFA_COLON:
	FCB	$80|$40|1
COLON:
	FCB	(':'|$80)
LFA_COLON:
	FDB	NFA_CSTOR
CFA_COLON:
	FDB	DOCOL
	FDB	CFA_QUESTEXEC
	FDB	CFA_EXCSP
	FDB	CFA_CURRENT
	FDB	CFA_GET               ; current CONTEXT
	FDB	CFA_CONTEXT
	FDB	CFA_EXCLAM            ; set CONTEXT = CURRENT
	FDB	CFA_CREATE
	FDB	CFA_RBRACK
	FDB	CFA_PARSCODE
DOCOL:                                ; code for ":"
	ldx	PTR_RP
	dex
	dex
	stx	PTR_RP                ; store next
	ldd	PTR_IP
	std	$02,x
	ldx	PTR_W
	jmp	NEXT_IPINX            ; moves (X) to IP
; --------------------------------
NFA_SEMI:
	FCB	$80|$40|1
SEMI:
	FCB	(';'|$80)
LFA_SEMI:
	FDB	NFA_COLON
CFA_SEMI:
	FDB	DOCOL
	FDB	CFA_QUESTCSP
	FDB	CFA_COMPILE
	FDB	CFA_SEMIS           ;  ;S
	FDB	CFA_SMUDGE
	FDB	CFA_LBRACK
	FDB	CFA_SEMIS
; --------------------------------
NFA_CONSTANT:
	FCB	$80|8
CONSTANT:
	FCB	"CONSTAN",('T'|$80)
LFA_CONSTANT:
	FDB	NFA_SEMI
CFA_CONSTANT:
	FDB	DOCOL
	FDB	CFA_CREATE
	FDB	CFA_SMUDGE
	FDB	CFA_COMMA
	FDB	CFA_PARSCODE
COD_CONSTANT:                  ; code for CONSTANT
	ldx	PTR_W          ; get address of constant from next word
	ldd	$02,x          ; load constant from word following IP to D
	jmp	NEXT_PSH_D
; --------------------------------
NFA_VARIABLE:
	FCB	$80|8
VARIABLE:
	FCB	"VARIABL",('E'|$80)
LFA_VARIABLE:
	FDB	NFA_CONSTANT
CFA_VARIABLE:
	FDB	DOCOL
	FDB	CFA_CONSTANT
	FDB	CFA_PARSCODE     ; machine code follows
COD_VARIABLE:                    ; code for VARIABLE
	ldd	PTR_W            ; get address of variable from next word
	addd	#$0002           ; (D) has address of variable value
	jmp	NEXT_PSH_D       ; return address and NEXT
; --------------------------------
NFA_USER:
	FCB	$80|4
USER:
	FCB	"USE",('R'|$80)
LFA_USER:
	FDB	NFA_VARIABLE
CFA_USER:
	FDB	DOCOL
	FDB	CFA_CONSTANT    ; index# was following call to CFA_USER
	FDB	CFA_PARSCODE    ; machine code following
COD_USER:                       ; code for USER
	ldx	PTR_W           ; address of CONSTANT
	ldd	$02,x           ; get offset following CONSTANT
	addd	PTR_SP          ; add index at SP 
	jmp	NEXT_PSH_D
; --------------------------------
NFA_ZERO:
	FCB	$80|1
ZERO:
	FCB	('0'|$80)
LFA_ZERO:
	FDB	NFA_USER
CFA_ZERO:
	FDB	COD_CONSTANT
	FDB	$0000
;       end of word
; --------------------------------
NFA_ONE:
	FCB	$80|1
ONE:
	FCB	('1'|$80)
LFA_ONE:
	FDB	NFA_ZERO
CFA_ONE:
	FDB	COD_CONSTANT
	FDB	$0001
;       end of word
; --------------------------------
NFA_TWO:
	FCB	$80|1
TWO:
	FCB	('2'|$80)
LFA_TWO:
	FDB	NFA_ONE
CFA_TWO:
	FDB	COD_CONSTANT
	FDB	$0002
;       end of word
; --------------------------------
NFA_THREE:
	FCB	$80|1
THREE:
	FCB	('3'|$80)
LFA_THREE:
	FDB	NFA_TWO
CFA_THREE:
	FDB	COD_CONSTANT
	FDB	$0003
;       end of word
; --------------------------------
NFA_BL:
	FCB	$80|2
BL:
	FCB	"B",('L'|$80)
LFA_BL:
	FDB	NFA_THREE
CFA_BL:
	FDB	COD_CONSTANT
	FDB	$0020               ; blank character
;       end of word
; --------------------------------
NFA_FIRST:
	FCB	$80|5
FIRST:
	FCB	"FIRS",('T'|$80)       ; start address of screen buffer
LFA_FIRST:
	FDB	NFA_BL
CFA_FIRST:
	FDB	COD_CONSTANT           ; 1024 byte screen buffer starts at $0710 
	FDB	MEMEND-1056            ; lower limit $0710 = MEMEND - 1024 - 32
;       end of word
; --------------------------------
NFA_LIMIT:
	FCB	$80|5
LIMIT:
	FCB	"LIMI",('T'|$80)
LFA_LIMIT:
	FDB	NFA_FIRST
CFA_LIMIT:
	FDB	COD_CONSTANT
	FDB	MEMEND            ; upper limit MEMEND = 2864 bytes
;       end of word
; --------------------------------
NFA_PLUSORIGIN:
	FCB	$80|7
PLUSORIGIN:
	FCB	"+ORIGI",('N'|$80)
LFA_PLUSORIGIN:
	FDB	NFA_LIMIT
CFA_PLUSORIGIN:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	ID_1                          ; $6000
	FDB	CFA_PLUS
	FDB	CFA_SEMIS
; --------------------------------
NFA_TIB:
	FCB	$80|3
TIB:
	FCB	"TI",('B'|$80)
LFA_TIB:
	FDB	NFA_PLUSORIGIN
CFA_TIB:
	FDB	COD_USER                      ; return address of
	FDB	$000A                         ; terminal input buffer
; --------------------------------
NFA_WIDTH:
	FCB	$80|5
WIDTH:
	FCB	"WIDT",('H'|$80)
LFA_WIDTH:
	FDB	NFA_TIB
CFA_WIDTH:
	FDB	COD_USER
	FDB	$000C
; --------------------------------
NFA_WARNING:
	FCB	$80|7
WARNING:
	FCB	"WARNIN",('G'|$80)
LFA_WARNING:
	FDB	NFA_WIDTH
CFA_WARNING:
	FDB	COD_USER
	FDB	$000E
; --------------------------------
NFA_FENCE:
	FCB	$80|5
FENCE:
	FCB	"FENC",('E'|$80)
LFA_FENCE:
	FDB	NFA_WARNING
CFA_FENCE:
	FDB	COD_USER
	FDB	$0010
; --------------------------------
NFA_DP:
	FCB	$80|2
DP:
	FCB	"D",('P'|$80)
LFA_DP:
	FDB	NFA_FENCE
CFA_DP:
	FDB	COD_USER
	FDB	$0012
; --------------------------------
NFA_VOC_LINK:
	FCB	$80|8
VOC_LINK:
	FCB	"VOC-LIN",('K'|$80)
LFA_VOC_LINK:
	FDB	NFA_DP
CFA_VOC_LINK:
	FDB	COD_USER              ; points to previous VOCABULARY in chain
	FDB	$0014
; --------------------------------
NFA_BLK:
	FCB	$80|3
BLK:
	FCB	"BL",('K'|$80)
LFA_BLK:
	FDB	NFA_VOC_LINK
CFA_BLK:
	FDB	COD_USER
	FDB	$0016
; --------------------------------
NFA_IN:
	FCB	$80|2
IN:
	FCB	"I",('N'|$80)
LFA_IN:
	FDB	NFA_BLK
CFA_IN:
	FDB	COD_USER
	FDB	$0018
; --------------------------------
NFA_OUT:
	FCB	$80|3
OUT:
	FCB	"OU",('T'|$80)
LFA_OUT:
	FDB	NFA_IN
CFA_OUT:
	FDB	COD_USER               ; user variable:
	FDB	$001A                  ; characters in current line for EMIT
; --------------------------------
NFA_SCR:
	FCB	$80|3
SCR:
	FCB	"SC",('R'|$80)
LFA_SCR:
	FDB	NFA_OUT
CFA_SCR:
	FDB	COD_USER
	FDB	$001C
; --------------------------------
NFA_OFFSET:
	FCB	$80|6
OFFSET:
	FCB	"OFFSE",('T'|$80)
LFA_OFFSET:
	FDB	NFA_SCR
CFA_OFFSET:
	FDB	COD_USER
	FDB	$001E
; --------------------------------
NFA_CONTEXT:
	FCB	$80|7
CONTEXT:
	FCB	"CONTEX",('T'|$80)
LFA_CONTEXT:
	FDB	NFA_OFFSET
CFA_CONTEXT:
	FDB	COD_USER
	FDB	$0020
; --------------------------------
NFA_CURRENT:
	FCB	$80|7
CURRENT:
	FCB	"CURREN",('T'|$80)
LFA_CURRENT:
	FDB	NFA_CONTEXT
CFA_CURRENT:
	FDB	COD_USER
	FDB	$0022
; --------------------------------
NFA_STATE:
	FCB	$80|5
STATE:
	FCB	"STAT",('E'|$80)
LFA_STATE:
	FDB	NFA_CURRENT
CFA_STATE:
	FDB	COD_USER
	FDB	$0024
; --------------------------------
NFA_BASE:
	FCB	$80|4
BASE:
	FCB	"BAS",('E'|$80)
LFA_BASE:
	FDB	NFA_STATE
CFA_BASE:
	FDB	COD_USER
	FDB	$0026
; --------------------------------
NFA_DPL:
	FCB	$80|3
DPL:
	FCB	"DP",('L'|$80)
LFA_DPL:
	FDB	NFA_BASE
CFA_DPL:
	FDB	COD_USER
	FDB	$0028
; --------------------------------
NFA_FLD:
	FCB	$80|3
FLD:
	FCB	"FL",('D'|$80)
LFA_FLD:
	FDB	NFA_DPL
CFA_FLD:
	FDB	COD_USER
	FDB	$002A
; --------------------------------
NFA_CSP:
	FCB     $80|3
CSP:
	FCB	"CS",('P'|$80)
LFA_CSP:
	FDB	NFA_FLD
CFA_CSP:
	FDB	COD_USER
	FDB	$002C
; --------------------------------
NFA_RNUM:
	FCB	$80|2
RNUM:
	FCB	"R",('#'|$80)
LFA_RNUM:
	FDB	NFA_CSP
CFA_RNUM:
	FDB	COD_USER
	FDB	$002E
; --------------------------------
NFA_HLD:
	FCB	$80|3
HLD:
	FCB	"HL",('D'|$80)
LFA_HLD:
	FDB	NFA_RNUM
CFA_HLD:
	FDB	COD_USER
	FDB	$0030
; --------------------------------
NFA_CPERLINE:
	FCB	$80|3
CPERLINE:
	FCB	"C/",('L'|$80)
LFA_CPERLINE:
	FDB	NFA_HLD
CFA_CPERLINE:
	FDB	COD_CONSTANT
	FDB	$0040
;       end of word
; --------------------------------
NFA_ONEPLUS:
	FCB	$80|2
ONEPLUS:
	FCB	"1",('+'|$80)
LFA_ONEPLUS:
	FDB	NFA_CPERLINE
CFA_ONEPLUS:
	FDB	*+2
	pulx	                ; get cell
ONEPLUS_RET:
	inx	                ; increment
	pshx
	jmp	NEXT
; --------------------------------
NFA_TWOPLUS:
	FCB	$80|2
TWOPLUS:
	FCB	"2",('+'|$80)
LFA_TWOPLUS:
	FDB	NFA_ONEPLUS
CFA_TWOPLUS:
	FDB	*+2
	pulx
	inx
	bra	ONEPLUS_RET

	if INCLUDE_FLUFF == 1
	; excess 2 bytes
	nop                         ; ???? unused code ????
	FCB	$80|3               ; ???? unused code ????
	endif
; --------------------------------
NFA_HERE:
	FCB	$80|4
HERE:
	FCB	"HER",('E'|$80)
LFA_HERE:
	FDB	NFA_TWOPLUS
CFA_HERE:
	FDB	DOCOL
	FDB	CFA_DP
	FDB	CFA_GET
	FDB	CFA_SEMIS
; --------------------------------
NFA_TWODROP:
	FCB	$80|5
TWODROP:
	FCB	"2DRO",('P'|$80)
LFA_TWODROP:
	FDB	NFA_HERE
CFA_TWODROP:
	FDB	*+2
	ins
	ins
	jmp	DROP_RET
; --------------------------------
NFA_TWODUP:
	FCB	$80|4
TWODUP:
	FCB	"2DU",('P'|$80)
LFA_TWODUP:
	FDB	NFA_TWODROP
CFA_TWODUP:
	FDB	DOCOL
	FDB	CFA_OVER
	FDB	CFA_OVER
	FDB	CFA_SEMIS
; --------------------------------
NFA_ALLOT:
	FCB	$80|5
ALLOT:
	FCB	"ALLO",('T'|$80)
LFA_ALLOT:
	FDB	NFA_TWODUP
CFA_ALLOT:
	FDB	DOCOL
	FDB	CFA_DP
	FDB	CFA_PLUSSTORE
	FDB	CFA_SEMIS
; --------------------------------
NFA_COMMA:
	FCB	$80|1
COMMA:
	FCB	(','|$80)
LFA_COMMA:
	FDB	NFA_ALLOT
CFA_COMMA:
	FDB	DOCOL
	FDB	CFA_HERE
	FDB	CFA_EXCLAM
	FDB	CFA_TWO
	FDB	CFA_ALLOT
	FDB	CFA_SEMIS
; --------------------------------
NFA_CCOMMA:
	FCB	$80|2
CCOMMA:
	FCB	"C",(','|$80)
LFA_CCOMMA:
	FDB	NFA_COMMA
CFA_CCOMMA:
	FDB	DOCOL
	FDB	CFA_HERE
	FDB	CFA_CSTOR
	FDB	CFA_ONE
	FDB	CFA_ALLOT
	FDB	CFA_SEMIS
; --------------------------------
NFA_SUBTRACT:
	FCB	$80|1
SUBTRACT:
	FCB	('-'|$80)
LFA_SUBTRACT:
	FDB	NFA_CCOMMA
CFA_SUBTRACT:
	FDB	DOCOL
	FDB	CFA_NEGATE
	FDB	CFA_PLUS
	FDB	CFA_SEMIS
; --------------------------------
NFA_EQUAL:
	FCB	$80|1
EQUAL:
	FCB	('='|$80)
LFA_EQUAL:
	FDB	NFA_SUBTRACT
CFA_EQUAL:
	FDB	DOCOL
	FDB	CFA_SUBTRACT
	FDB	CFA_ZEROEQ
	FDB	CFA_SEMIS
; --------------------------------
NFA_LT:
	FCB	$80|1
LT:
	FCB	('<'|$80)
LFA_LT:
	FDB	NFA_EQUAL
CFA_LT:
	FDB	*+2
	pula
	pulb
L6835:
	tsx
	cmpa	$00,x
	ins
	bgt	L6844
	bne	L6841
	cmpb	$01,x
	bhi	L6844
L6841:
	clrb
	bra	L6846
;
L6844:
	ldab	#$01
L6846:
	clra
	ins
	jmp	NEXT_PSH_D
; --------------------------------
NFA_GT:
	FCB	$80|1
GT:
	FCB	('>'|$80)
LFA_GT:
	FDB	NFA_LT
CFA_GT:
	FDB	*+2
	pulx
	pula
	pulb
	pshx
	bra	L6835
; --------------------------------
NFA_ROT:
	FCB	$80|3
ROT:
	FCB	"RO",('T'|$80)
LFA_ROT:
	FDB	NFA_GT
CFA_ROT:
	FDB	DOCOL
	FDB	CFA_TOR
	FDB	CFA_SWAP
	FDB	CFA_FROMR
	FDB	CFA_SWAP
	FDB	CFA_SEMIS
; --------------------------------
NFA_SPACE:
	FCB	$80|5
SPACE:
	FCB	"SPAC",('E'|$80)
LFA_SPACE:
	FDB	NFA_ROT
CFA_SPACE:
	FDB	DOCOL
	FDB	CFA_BL
	FDB	CFA_EMIT
	FDB	CFA_SEMIS
; --------------------------------
NFA_MIN:
	FCB	$80|3
MIN:
	FCB	"MI",('N'|$80)
LFA_MIN:
	FDB	NFA_SPACE
CFA_MIN:
	FDB	DOCOL
	FDB	CFA_TWODUP
	FDB	CFA_GT
	FDB	CFA_ZEROBRANCH
	FDB	MIN1-*
	FDB	CFA_SWAP
MIN1:	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_MAX:
	FCB	$80|3
MAX:
	FCB	"MA",$D8
LFA_MAX:
	FDB	NFA_MIN
CFA_MAX:
	FDB	DOCOL
	FDB	CFA_TWODUP
	FDB	CFA_LT
	FDB	CFA_ZEROBRANCH
	FDB	MAX1-*
	FDB	CFA_SWAP
MAX1:	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_MINUSDUP:
	FCB	$80|4
MINUSDUP:
	FCB	"-DU",('P'|$80)
LFA_MINUSDUP:
	FDB	NFA_MAX
CFA_MINUSDUP:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_ZEROBRANCH
	FDB	MINDUP-*
	FDB	CFA_DUP
MINDUP:	FDB	CFA_SEMIS
; --------------------------------
NFA_TRAVERSE:
	FCB	$80|8
TRAVERSE:
	FCB	"TRAVERS",('E'|$80)
LFA_TRAVERSE:
	FDB	NFA_MINUSDUP
CFA_TRAVERSE:
	FDB	DOCOL
	FDB	CFA_SWAP
TRAVERSE1:
	FDB	CFA_OVER
	FDB	CFA_PLUS
	FDB	CFA_LIT_BYTE
	FCB	$7F
	FDB	CFA_OVER
	FDB	CFA_CGET
	FDB	CFA_LT
	FDB	CFA_ZEROBRANCH
	FDB	TRAVERSE1-*
	FDB	CFA_SWAP
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_LATEST:
	FCB	$80|6
LATEST:
	FCB	"LATES",('T'|$80)
LFA_LATEST:
	FDB	NFA_TRAVERSE
CFA_LATEST:
	FDB	DOCOL
	FDB	CFA_CURRENT
	FDB	CFA_GET
	FDB	CFA_GET
	FDB	CFA_SEMIS
; --------------------------------
NFA_LFA:
	FCB	$80|3
LFA:
	FCB	"LF",('A'|$80)
LFA_LFA:
	FDB	NFA_LATEST
CFA_LFA:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
	FCB	$04
	FDB	CFA_SUBTRACT
	FDB	CFA_SEMIS
; --------------------------------
NFA_CFA:
	FCB	$80|3
CFA:
	FCB	"CF",('A'|$80)
LFA_CFA:
	FDB	NFA_LFA
CFA_CFA:
	FDB	DOCOL                ; PFA-2
	FDB	CFA_TWO              ; PFA
	FDB	CFA_SUBTRACT
	FDB	CFA_SEMIS
; --------------------------------
NFA_NFA:
	FCB	$80|3
NFA:
	FCB	"NF",('A'|$80)
LFA_NFA:
	FDB	NFA_CFA
CFA_NFA:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
	FCB	$05
	FDB	CFA_SUBTRACT       ; to last character of name
	FDB	CFA_ONE
	FDB	CFA_NEGATE         ; -1 direction backwards
	FDB	CFA_TRAVERSE       ; to length byte of name field
	FDB	CFA_SEMIS
; --------------------------------
NFA_PFA:
	FCB	$80|3
PFA:
	FCB	"PF",('A'|$80)
LFA_PFA:
	FDB	NFA_NFA
CFA_PFA:
	FDB	DOCOL
PFA_PFA:
	FDB	CFA_ONE          ; +1 directon forward
	FDB	CFA_TRAVERSE     ; to last character of name
	FDB	CFA_LIT_BYTE
	FCB	$05
	FDB	CFA_PLUS         ; to PFA_PFA
	FDB	CFA_SEMIS
; --------------------------------
NFA_EXCSP:
	FCB	$80|4
EXCSP:
	FCB	"!CS",('P'|$80)
LFA_EXCSP:
	FDB	NFA_PFA
CFA_EXCSP:
	FDB	DOCOL
	FDB	CFA_SPGET
	FDB	CFA_CSP
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUESTERROR:
	FCB	$80|6
QUESTERROR:
	FCB	"?ERRO",('R'|$80)
LFA_QUESTERROR:
	FDB	NFA_EXCSP
CFA_QUESTERROR:                  ; error code on stack
	FDB	DOCOL
	FDB	CFA_SWAP
	FDB	CFA_ZEROBRANCH
	FDB	QERROR1-*        ; if ZERO: do not show message
	FDB	CFA_ERROR        ; output error msg#
	FDB	CFA_BRANCH
	FDB	QERROR2-*        ; jump to SEMIS
QERROR1:
	FDB	CFA_DROP
QERROR2:
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUESTCOMP:
	FCB	$80|5
QUESTCOMP:
	FCB	"?COM",('P'|$80)
LFA_QUESTCOMP:
	FDB	NFA_QUESTERROR
CFA_QUESTCOMP:
	FDB	DOCOL
	FDB	CFA_STATE
	FDB	CFA_GET
	FDB	CFA_ZEROEQ
	FDB	CFA_LIT_BYTE
	FCB     $11                ; error #17: "Compilation Only"
	FDB	CFA_QUESTERROR
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUESTEXEC:
	FCB	$80|5
QUESTEXEC:
	FCB	"?EXE",('C'|$80)
LFA_QUESTEXEC:
	FDB	NFA_QUESTCOMP
CFA_QUESTEXEC:
	FDB	DOCOL
	FDB	CFA_STATE
	FDB	CFA_GET
	FDB	CFA_LIT_BYTE
	FCB	$12                  ; error #18: "Execution Only"
	FDB	CFA_QUESTERROR
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUESTPAIRS:
	FCB	$80|6
QUESTPAIRS:
	FCB	"?PAIR",('S'|$80)
LFA_QUESTPAIRS:
	FDB	NFA_QUESTEXEC
CFA_QUESTPAIRS:
	FDB	DOCOL
	FDB	CFA_SUBTRACT
	FDB	CFA_LIT_BYTE
	FCB	$13                  ; error #19: "Conditionals not Paired"
	FDB	CFA_QUESTERROR
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUESTCSP:
	FCB	$80|4
QUESTCSP:
	FCB	"?CS",('P'|$80)
LFA_QUESTCSP:
	FDB	NFA_QUESTPAIRS
CFA_QUESTCSP:
	FDB	DOCOL
	FDB	CFA_SPGET
	FDB	CFA_CSP
	FDB	CFA_GET
	FDB	CFA_SUBTRACT
	FDB	CFA_LIT_BYTE
	FCB	$14                 ; error #20: "Definition not Finished"
	FDB	CFA_QUESTERROR
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUESTLOADING:
	FCB	$80|8
QUESTLOADING:
	FCB	"?LOADIN",('G'|$80)
LFA_QUESTLOADING:
	FDB	NFA_QUESTCSP
CFA_QUESTLOADING:
	FDB	DOCOL
	FDB	CFA_BLK
	FDB	CFA_GET           ; get block count
	FDB	CFA_ZEROEQ
	FDB	CFA_LIT_BYTE
	FCB	$16               ; error #22: "Use Only When LOADing"
	FDB	CFA_QUESTERROR
	FDB	CFA_SEMIS
; --------------------------------
NFA_COMPILE:
	FCB	$80|7
COMPILE:
	FCB	"COMPIL",('E'|$80)
LFA_COMPILE:
	FDB	NFA_QUESTLOADING
CFA_COMPILE:
	FDB	DOCOL
	FDB	CFA_QUESTCOMP
	FDB	CFA_FROMR
	FDB	CFA_TWOPLUS
	FDB	CFA_DUP
	FDB	CFA_TOR
	FDB	CFA_GET
	FDB	CFA_COMMA
	FDB	CFA_SEMIS
; --------------------------------
NFA_LBRACK:
	FCB	$80|$40|1
LBRACK:
	FCB	('['|$80)
LFA_LBRACK:
	FDB	NFA_COMPILE
CFA_LBRACK:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_STATE
	FDB	CFA_EXCLAM       ; store 0 in STATE = executing
	FDB	CFA_SEMIS
; --------------------------------
NFA_RBRACK:
	FCB	$80|1
RBRACK:
	FCB	(']'|$80)
LFA_RBRACK:
	FDB	NFA_LBRACK
CFA_RBRACK:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
	FCB	$80|$40
	FDB	CFA_STATE
	FDB	CFA_EXCLAM       ; store $C0 in STATE = compiling
	FDB	CFA_SEMIS
; --------------------------------
NFA_SMUDGE:
	FCB	$80|6
SMUDGE:
	FCB	"SMUDG",('E'|$80)
LFA_SMUDGE:
	FDB	NFA_RBRACK
CFA_SMUDGE:
	FDB	DOCOL
	FDB	CFA_LATEST
	FDB	CFA_LIT_BYTE         ;   v smudge bit
	FCB	$20                  ; 0010.0000
	FDB	CFA_TOGGLE
	FDB	CFA_SEMIS
; --------------------------------
NFA_HEX:
	FCB	$80|3
HEX:
	FCB	"HE",$D8
LFA_HEX:
	FDB	NFA_SMUDGE
CFA_HEX:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
	FCB	$10
	FDB	CFA_BASE
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_DECIMAL:
	FCB	$80|7
DECIMAL:
	FCB	"DECIMA",('L'|$80)
LFA_DECIMAL:
	FDB	NFA_HEX
CFA_DECIMAL:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
	FCB	$0A
	FDB	CFA_BASE
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_PARSCODE:
	FCB	$80|7
PARSCODE:
	FCB	"(;CODE",(')'|$80)
LFA_PARSCODE:
	FDB	NFA_DECIMAL
CFA_PARSCODE:
	FDB	DOCOL
	FDB	CFA_FROMR
	FDB	CFA_TWOPLUS
	FDB	CFA_LATEST
	FDB	CFA_PFA
	FDB	CFA_CFA
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_SEMICODE:
	FCB	$80|$40|5
SEMICODE:
	FCB	";COD",('E'|$80)
LFA_SEMICODE:
	FDB	NFA_PARSCODE
CFA_SEMICODE:
	FDB	DOCOL
	FDB	CFA_QUESTCSP     ; ?CSP
	FDB	CFA_COMPILE      ; COMPILE  compile mode
	FDB	CFA_PARSCODE     ; (;CODE)  these words are compiled
	FDB	CFA_SMUDGE       ; SMUDGE   therefore no code follows CFA_PARSCODE
	FDB	CFA_LBRACK       ; [
	FDB	CFA_QUESTSTACK   ; ?STACK
	FDB	CFA_SEMIS
; --------------------------------
NFA_LTBUILDS:
	FCB	$80|7
LTBUILDS:
	FCB	"<BUILD",('S'|$80)
LFA_LTBUILDS:
	FDB	NFA_SEMICODE
CFA_LTBUILDS:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_CONSTANT
	FDB	CFA_SEMIS
; --------------------------------
NFA_DOESGT:
	FCB	$80|5
DOESGT:
	FCB	"DOES",('>'|$80)
LFA_DOESGT:
	FDB	NFA_LTBUILDS
CFA_DOESGT:
	FDB	DOCOL
	FDB	CFA_FROMR
	FDB	CFA_TWOPLUS
	FDB	CFA_LATEST
	FDB	CFA_PFA
	FDB	CFA_EXCLAM
	FDB	CFA_PARSCODE
COD_DOESGT:                       ; code for DOES>
	ldd	PTR_IP
	ldx	PTR_RP
	dex
	dex
	stx	PTR_RP
	std	$02,x
	ldx	PTR_W
	inx
	inx                       ; UP+2
	stx	X0080             ; save
	ldx	$00,x
	stx	PTR_IP
	clra
	ldab	#$02
	addd	X0080             ; and add
	pshb
	psha
	jmp	L6136
; --------------------------------
NFA_COUNT:
	FCB	$80|5
COUNT:
	FCB	"COUN",('T'|$80)
LFA_COUNT:
	FDB	NFA_DOESGT
CFA_COUNT:
	FDB	DOCOL
	FDB	CFA_DUP         ; length byte in first char
	FDB	CFA_ONEPLUS     ; addr addr+1
	FDB	CFA_SWAP        ; addr+1 addr
	FDB	CFA_CGET        ; addr+1 length
	FDB	CFA_SEMIS
; --------------------------------
NFA_TYPE:
	FCB	$80|4
TYPE:
	FCB	"TYP",('E'|$80)
LFA_TYPE:
	FDB	NFA_COUNT
CFA_TYPE:
	FDB	DOCOL
	FDB	CFA_MINUSDUP
	FDB	CFA_ZEROBRANCH
	FDB	TYPE2-*
	FDB	CFA_OVER
	FDB	CFA_PLUS
	FDB	CFA_SWAP
	FDB	CFA_PARDO
TYPE1:	FDB	CFA_I
	FDB	CFA_CGET
	FDB	CFA_EMIT
	FDB	CFA_PARLOOP
	FDB	TYPE1-*
	FDB	CFA_BRANCH
	FDB	TYPE3-*
TYPE2:	FDB	CFA_DROP
TYPE3:	FDB	CFA_SEMIS
; --------------------------------
NFA_MINUSTRAILING:
	FCB	$80|9
MINUSTRAILING:
	FCB	"-TRAILIN",('G'|$80)
LFA_MINUSTRAILING:
	FDB	NFA_TYPE
CFA_MINUSTRAILING:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_ZERO
	FDB	CFA_PARDO
MTRAIL1:
	FDB	CFA_TWODUP
	FDB	CFA_PLUS
	FDB	CFA_ONE
	FDB	CFA_SUBTRACT
	FDB	CFA_CGET
	FDB	CFA_BL
	FDB	CFA_SUBTRACT
	FDB	CFA_ZEROBRANCH
	FDB	MTRAIL2-*
	FDB	CFA_LEAVE
	FDB	CFA_BRANCH
	FDB	MTRAIL3-*
MTRAIL2:
	FDB	CFA_ONE
	FDB	CFA_SUBTRACT
MTRAIL3:
	FDB	CFA_PARLOOP
	FDB	MTRAIL1-*
	FDB	CFA_SEMIS
; --------------------------------
NFA_PARDOTQP:
	FCB	$80|4
PARDOTQP:
	FCB	"(.",$22,$A9
LFA_PARDOTQP:
	FDB	NFA_MINUSTRAILING
CFA_PARDOTQP:
	FDB	DOCOL
	FDB	CFA_R
	FDB	CFA_TWOPLUS
	FDB	CFA_COUNT
	FDB	CFA_DUP
	FDB	CFA_ONEPLUS
	FDB	CFA_FROMR
	FDB	CFA_PLUS
	FDB	CFA_TOR
	FDB	CFA_TYPE
	FDB	CFA_SEMIS
; --------------------------------
NFA_DOTQUOTE:
	FCB	$80|$40|2
DOTQUOTE:
	FCB	".",('"'|$80)          ; " to satisfy syntax highlighter
LFA_DOTQUOTE:
	FDB	NFA_PARDOTQP
CFA_DOTQUOTE:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
	FCB	$22           ; double quote character
	FDB	CFA_STATE
	FDB	CFA_GET
	FDB	CFA_ZEROBRANCH
	FDB	DOTQUOTE1-*   ; skip to executing branch
	FDB	CFA_COMPILE   ; compiling
	FDB	CFA_PARDOTQP  ; (.)
	FDB	CFA_WORD      ; read from input up to double quote
	FDB	CFA_HERE      ; 
	FDB	CFA_CGET      ; length byte
	FDB	CFA_ONEPLUS   ; account for length byte
	FDB	CFA_ALLOT     ; include string in word
	FDB	CFA_BRANCH
	FDB	DOTQUOTE2-*
DOTQUOTE1:
	FDB	CFA_WORD      ; executing: read up to double quote 
	FDB	CFA_HERE      ; get address of string with length byte
	FDB	CFA_COUNT     ; convert to address, length words
	FDB	CFA_TYPE      ; type it
DOTQUOTE2:
	FDB	CFA_SEMIS     ; done
; --------------------------------
NFA_QUESTSTACK:
	FCB	$80|6
QUESTSTACK:
	FCB	"?STAC",('K'|$80)
LFA_QUESTSTACK:
	FDB	NFA_DOTQUOTE
CFA_QUESTSTACK:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
;	FCB	$1E                       ; stack limit, relative address
	FCB	ADDR_SP0-ID_1             ; get cell ADDR_SP0 == initial SP 
	FDB	CFA_PLUSORIGIN            ; absolute address: $6000+$1E -> ADDR_SP0
;	the above sequence from CFA_LIT_BYTE on could be replaced by
;	FDB	CFA_LIT_WORD
;	FDB	ADDR_SP0                  ; push value *(ADDR_SP0)
;	saving 1 byte and +ORIGIN operation
	FDB	CFA_GET                   ; get initial RP, SP must be above that limit

	FDB	CFA_TWO
	FDB	CFA_SUBTRACT              ; $06FC limit-2
	FDB	CFA_SPGET                 
	FDB	CFA_LT                    ; SP < $06FC ?
	FDB	CFA_ONE                   ; error #1: "Stack empty"
	FDB	CFA_QUESTERROR

	FDB	CFA_SPGET
	FDB	CFA_TIB
	FDB	CFA_GET
	FDB	CFA_LIT_BYTE
	FCB	$42
	FDB	CFA_PLUS             ; TIB + $42 = TIB + 66 < SP ?
	FDB	CFA_LT
	FDB	CFA_ZEROBRANCH
	FDB	QSTACK1-*            ; skip
	FDB	CFA_TWO              ; error #2: "Dictionary full"
	FDB	CFA_QUESTERROR
QSTACK1:
	FDB	CFA_SEMIS
; --------------------------------
NFA_EXPECT:
	FCB	$80|6
EXPECT:
	FCB	"EXPEC",('T'|$80)
LFA_EXPECT:
	FDB	NFA_QUESTSTACK
CFA_EXPECT:
	FDB	DOCOL
	FDB	CFA_OVER                ; (address)
	FDB	CFA_PLUS                ; (address address+n)
	FDB	CFA_OVER                ; (address address+n address)
	FDB	CFA_PARDO               ; loop over n buffer elements
EXPECT1:                                ;
	FDB	CFA_KEY
	FDB	CFA_DUP
	FDB	CFA_LIT_BYTE
	FCB	DATA_BS-ID_1        ; DATA_BS: relative address
	FDB	CFA_PLUSORIGIN      ; DATA_BS: $6000 + $1A -> $0008
; the above sequence from CFA_LIT_BYTE on could be replaced by
;	FDB	CFA_LIT_WORD
;	FDB	DATA_BS
;	saving 1 byte and +ORIGIN operation
	FDB	CFA_GET
	FDB	CFA_EQUAL           ; key == Backspace ?
	FDB	CFA_ZEROBRANCH
	FDB	EXPECT2-*           ; no
	FDB	CFA_DROP
	FDB	CFA_LIT_BYTE
	FCB	$08                 ; BS, here hard coded ????
	FDB	CFA_OVER
	FDB	CFA_I               ; address
	FDB	CFA_EQUAL           ; end reached
	FDB	CFA_DUP
	FDB	CFA_FROMR
	FDB	CFA_TWO
	FDB	CFA_SUBTRACT
	FDB	CFA_PLUS
	FDB	CFA_TOR
	FDB	CFA_SUBTRACT
	FDB	CFA_BRANCH
	FDB	EXPECT5-*
EXPECT2:
	FDB	CFA_DUP
	FDB	CFA_LIT_BYTE
	FCB	$0D                        ; CR
	FDB	CFA_EQUAL
	FDB	CFA_ZEROBRANCH
	FDB	EXPECT3-*                  ; end of input
	FDB	CFA_LEAVE
	FDB	CFA_DROP                   ; 
	FDB	CFA_BL                     ; replace by blank
	FDB	CFA_ZERO
	FDB	CFA_BRANCH
	FDB	EXPECT4-*                  ; skip
EXPECT3:
	FDB	CFA_DUP
EXPECT4:
	FDB	CFA_I
	FDB	CFA_CSTOR                   ; store key
	FDB	CFA_ZERO
	FDB	CFA_I
	FDB	CFA_ONEPLUS
	FDB	CFA_EXCLAM                  ; append null byte
EXPECT5:
	FDB	CFA_EMIT
	FDB	CFA_PARLOOP     ; loop to next buffer element
	FDB	EXPECT1-*
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUERY:
	FCB	$80|5
QUERY:
	FCB	"QUER",('Y'|$80)
LFA_QUERY:
	FDB	NFA_EXPECT
CFA_QUERY:
        FDB	DOCOL
        FDB	CFA_TIB
        FDB	CFA_GET       ; address of TIB
        FDB	CFA_CPERLINE  ; read up to C/L (64) characters to TIB
        FDB	CFA_EXPECT
        FDB	CFA_ZERO      ; reset TIB index IN to 0
        FDB	CFA_IN
        FDB	CFA_EXCLAM
        FDB	CFA_SEMIS
; --------------------------------
NFA_FILL:
	FCB	$80|4
FILL:
	FCB	"FIL",('L'|$80)
LFA_FILL:
	FDB	NFA_QUERY
CFA_FILL:
	FDB	DOCOL
	FDB	CFA_SWAP
	FDB	CFA_TOR
	FDB	CFA_OVER
	FDB	CFA_CSTOR
	FDB	CFA_DUP
	FDB	CFA_ONEPLUS
	FDB	CFA_FROMR
	FDB	CFA_ONE
	FDB	CFA_SUBTRACT
	FDB	CFA_CMOVE
	FDB	CFA_SEMIS
; --------------------------------
NFA_ERASE:
	FCB	$85
ERASE:
	FCB	"ERAS",('E'|$80)
LFA_ERaSE:
	FDB	NFA_FILL
CFA_ERASE:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_FILL
	FDB	CFA_SEMIS
; --------------------------------
NFA_BLANKS:
	FCB	$80|6
BLANKS:
	FCB	"BLANK",('S'|$80)
LFA_BLANKS:
	FDB	NFA_ERASE
CFA_BLANKS:
	FDB	DOCOL        ; (addr u)
	FDB	CFA_BL       ; (addr u b)
	FDB	CFA_FILL     ; (addr u b)
	FDB	CFA_SEMIS
; --------------------------------
NFA_HOLD:
	FCB	$80|4
HOLD:
	FCB	"HOL",('D'|$80)
LFA_HOLD:
	FDB	NFA_BLANKS
CFA_HOLD:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$FFFF
	FDB	CFA_HLD
	FDB	CFA_PLUSSTORE
	FDB	CFA_HLD
	FDB	CFA_GET
	FDB	CFA_CSTOR
	FDB	CFA_SEMIS
; --------------------------------
NFA_PAD:
	FCB	$80|3
PAD:
	FCB	"PA",('D'|$80)
LFA_PAD:
	FDB	NFA_HOLD
CFA_PAD:
	FDB	DOCOL
	FDB	CFA_HERE
	FDB	CFA_LIT_BYTE
	FCB	$44                       ;
	FDB	CFA_PLUS                  ; HERE + 68
	FDB	CFA_SEMIS
; --------------------------------
NFA_DIVZER:
	FCB	$80|$40|1
DIVZER:
	FCB	$80                       ; '\0'
LFA_DIVZER:
	FDB	NFA_PAD
CFA_DIVZER:
	FDB	DOCOL
	FDB	CFA_BLK
	FDB	CFA_GET                   ; get block count
	FDB	CFA_ZEROBRANCH
	FDB	DIVZ1-*
	FDB	CFA_ZERO
	FDB	CFA_IN
	FDB	CFA_EXCLAM                ; set IN to zero
	FDB	CFA_QUESTEXEC
DIVZ1:	FDB	CFA_FROMR
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_WORD:
	FCB	$80|4
WORD:
	FCB	"WOR",('D'|$80)
LFA_WORD:
	FDB	NFA_DIVZER
CFA_WORD:
	FDB	DOCOL
	FDB	CFA_BLK
	FDB	CFA_GET                   ; get block count
	FDB	CFA_ZEROBRANCH            ; if BLK=0: input from terminal
	FDB	WORD2-*                   ; skip to TIB

	FDB	CFA_FIRST                 ; get address of block
	FDB	CFA_BRANCH
	FDB	WORD3-*                   ; skip to IN

WORD2:	FDB	CFA_TIB                   ; get address of terminal
	FDB	CFA_GET                   ;            input buffer

WORD3:	FDB	CFA_IN                    ; address of current input pointer
	FDB	CFA_GET_ADD               ; add IN to TIB
	FDB	CFA_SWAP                  ; (TIB IN) 
	FDB	CFA_ENCLOSE

	FDB	CFA_HERE                  ; prepare empty input
	FDB	CFA_LIT_WORD
	FDB	$0022
	FDB	CFA_BLANKS                ; put 34 blanks at HERE

	FDB	CFA_IN
	FDB	CFA_PLUSSTORE             ; increment

	FDB	CFA_OVER
	FDB	CFA_SUBTRACT
	FDB	CFA_TOR                   ; save count
	FDB	CFA_R
	FDB	CFA_HERE                  ;
	FDB	CFA_CSTOR                 ; store count at HERE
	FDB	CFA_PLUS
	FDB	CFA_HERE
	FDB	CFA_ONEPLUS               ; destination address: HERE+1
	FDB	CFA_FROMR                 ; restore count
	FDB	CFA_CMOVE                 ; copy count characters
	FDB	CFA_SEMIS
; --------------------------------
NFA_PARNUMBER:
	FCB	$80|8
PARNUMBER:
	FCB	"(NUMBER",(')'|$80)
LFA_PARNUMBER:
	FDB	NFA_WORD
CFA_PARNUMBER:
	FDB	DOCOL
PARNU1:	FDB	CFA_ONEPLUS
	FDB	CFA_DUP
	FDB	CFA_TOR
	FDB	CFA_CGET
	FDB	CFA_BASE
	FDB	CFA_GET
	FDB	CFA_DIGIT
	FDB	CFA_ZEROBRANCH
	FDB	PARNU3-*
	FDB	CFA_SWAP
	FDB	CFA_BASE
	FDB	CFA_GET
	FDB	CFA_UMUL
	FDB	CFA_DROP
	FDB	CFA_ROT
	FDB	CFA_BASE
	FDB	CFA_GET
	FDB	CFA_UMUL
	FDB	CFA_DPLUS
	FDB	CFA_DPL
	FDB	CFA_GET
	FDB	CFA_ONEPLUS
	FDB	CFA_ZEROBRANCH
	FDB	PARNU2-*
	FDB	CFA_ONE
	FDB	CFA_DPL
	FDB	CFA_PLUSSTORE
PARNU2:	FDB	CFA_FROMR
	FDB	CFA_BRANCH
	FDB	PARNU1-*
PARNU3:	FDB	CFA_FROMR
	FDB	CFA_SEMIS
; --------------------------------
NFA_NUMBER:
	FCB	$80|6
NUMBER:
	FCB	"NUMBE",('R'|$80)
LFA_NUMBER:
	FDB	NFA_PARNUMBER
CFA_NUMBER:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_ZERO
	FDB	CFA_ROT
	FDB	CFA_DUP
	FDB	CFA_ONEPLUS
	FDB	CFA_CGET
	FDB	CFA_LIT_WORD
	FDB	$002D
	FDB	CFA_EQUAL
	FDB	CFA_DUP
	FDB	CFA_TOR
	FDB	CFA_PLUS
	FDB	CFA_LIT_WORD
	FDB	$FFFF
NUMBER1:
	FDB	CFA_DPL
	FDB	CFA_EXCLAM
	FDB	CFA_PARNUMBER
	FDB	CFA_DUP
	FDB	CFA_CGET
	FDB	CFA_BL
	FDB	CFA_SUBTRACT
	FDB	CFA_ZEROBRANCH
	FDB	NUMBER2-*
	FDB	CFA_DUP
	FDB	CFA_CGET
	FDB	CFA_LIT_WORD
	FDB	$002E
	FDB	CFA_SUBTRACT
	FDB	CFA_ZERO
	FDB	CFA_QUESTERROR                ; error #0: reserved
	FDB	CFA_ZERO
	FDB	CFA_BRANCH
	FDB	NUMBER1-*
NUMBER2:
	FDB	CFA_DROP
	FDB	CFA_FROMR
	FDB	CFA_ZEROBRANCH
	FDB	NUMBER3-*
	FDB	CFA_DNEGATE
NUMBER3:
	FDB	CFA_SEMIS
; --------------------------------
NFA_MINUSFIND:
	FCB	$80|5
MINUSFIND:
	FCB	"-FIN",('D'|$80)
LFA_MINUSFIND:
	FDB	NFA_NUMBER
CFA_MINUSFIND:
	FDB	DOCOL
	FDB	CFA_BL                ; ' '
	FDB	CFA_WORD              ; read a word until ' '
	FDB	CFA_HERE
	FDB	CFA_CONTEXT
	FDB	CFA_GET
	FDB	CFA_GET               ; address of first word in list
	FDB	CFA_PARFIND

	FDB	CFA_DUP
	FDB	CFA_ZEROEQ
	FDB	CFA_ZEROBRANCH
	FDB	MINFI1-*

	FDB	CFA_DROP
	FDB	CFA_HERE
	FDB	CFA_LATEST
	FDB	CFA_PARFIND            ; (FIND)
MINFI1:	FDB	CFA_SEMIS
; --------------------------------
NFA_PARABORT:
	FCB	$80|7
PARABORT:
	FCB	"(ABORT",(')'|$80)
LFA_PARABORT:
	FDB	NFA_MINUSFIND
CFA_PARABORT:
	FDB	DOCOL
	FDB	CFA_ABORT
	FDB	CFA_SEMIS
; --------------------------------
NFA_ERROR:
	FCB	$80|5
ERROR:
	FCB	"ERRO",('R'|$80)
LFA_ERROR:
	FDB	$0C00               ; linked to copy of NFA_PARABORT in RAM
CFA_ERROR:
	FDB	DOCOL
	FDB	CFA_WARNING
	FDB	CFA_GET
	FDB	CFA_ZEROLT          ; WARNING < 0 ?
	FDB	CFA_ZEROBRANCH
	FDB	ERROR1-*            ; skip next word
	FDB	$0C0A               ; points to CFA_PARABORT in RAM
ERROR1:
	FDB	CFA_HERE
	FDB	CFA_COUNT
	FDB	CFA_TYPE
	FDB	CFA_PARDOTQP
LEN_ERROR:
	FCB	$03
MSG_ERROR:
	FCB	" ? "
	FDB	CFA_LIT_BYTE
	FCB	$12
	FDB	CFA_ERR_BEEP
	FDB	CFA_MESSAGE
	FDB	CFA_SPSTOR
	FDB	CFA_TWODROP
	FDB	CFA_IN
	FDB	CFA_GET
	FDB	CFA_BLK
	FDB	CFA_GET                   ; get block count
	FDB	CFA_QUIT
	if INCLUDE_FLUFF == 1
	; 2 bytes less
	FDB	CFA_SEMIS        ; this is never reached due to QUIT
	endif
; --------------------------------
NFA_IDDOT:
	FCB	$80|3
IDDOT:
	FCB	"ID",('.'|$80)
LFA_IDDOT:
	FDB	NFA_ERROR
CFA_IDDOT:
	FDB	DOCOL
	FDB	CFA_PAD
	FDB	CFA_LIT_WORD
	FDB	$0020
	FDB	CFA_LIT_WORD
	FDB	$005F
	FDB	CFA_FILL
	FDB	CFA_DUP
	FDB	CFA_PFA
	FDB	CFA_LFA
	FDB	CFA_OVER
	FDB	CFA_SUBTRACT
	FDB	CFA_PAD
	FDB	CFA_SWAP
	FDB	CFA_CMOVE
	FDB	CFA_PAD
	FDB	CFA_COUNT
	FDB	CFA_LIT_BYTE
	FCB	$1F
	FDB	CFA_AND
	FDB	CFA_TYPE
	FDB	CFA_SPACE
	FDB	CFA_SEMIS
; --------------------------------
NFA_CREATE:
	FCB	$80|6
CREATE:
	FCB	"CREAT",('E'|$80)
LFA_CREATE:
	FDB	NFA_IDDOT
CFA_CREATE:
	FDB	DOCOL
	FDB	CFA_MINUSFIND
	FDB	CFA_ZEROBRANCH
	FDB	CREAT1-*

	FDB	CFA_DROP
	FDB	CFA_NFA
	FDB	CFA_IDDOT
	FDB	CFA_LIT_WORD
	FDB	$0004
	FDB	CFA_MESSAGE
	FDB	CFA_SPACE

CREAT1:	FDB	CFA_HERE
	FDB	CFA_DUP
	FDB	CFA_CGET
	FDB	CFA_WIDTH
	FDB	CFA_GET
	FDB	CFA_MIN
	FDB	CFA_ONEPLUS
	FDB	CFA_ALLOT
	FDB	CFA_DUP
	FDB	CFA_LIT_BYTE
	FCB	$A0
	FDB	CFA_TOGGLE
	FDB	CFA_HERE
	FDB	CFA_ONE
	FDB	CFA_SUBTRACT
	FDB	CFA_LIT_BYTE
	FCB	$80
	FDB	CFA_TOGGLE
	FDB	CFA_LATEST
	FDB	CFA_COMMA
	FDB	CFA_CURRENT
	FDB	CFA_GET
	FDB	CFA_EXCLAM
	FDB	CFA_HERE
	FDB	CFA_TWOPLUS
	FDB	CFA_COMMA
	FDB	CFA_SEMIS
; --------------------------------
NFA_BRACKCOMPILE:
	FCB	$80|$40|9
BRACKCOMPILE:
	FCB	"[COMPILE",(']'|$80)
LFA_BRACKCOMPILE:
	FDB	NFA_CREATE
CFA_BRACKCOMPILE:
	FDB	DOCOL
	FDB	CFA_MINUSFIND
	FDB	CFA_ZEROEQ
	FDB	CFA_ZERO
	FDB	CFA_QUESTERROR
	FDB	CFA_DROP
	FDB	CFA_CFA
	FDB	CFA_COMMA
	FDB	CFA_SEMIS
; --------------------------------
NFA_LITERAL:
	FCB	$80|$40|7   
LITERAL:
	FCB	"LITERA",('L'|$80)
LFA_LITERAl:
	FDB	NFA_BRACKCOMPILE
CFA_LITERAL:
	FDB	DOCOL
	FDB	CFA_STATE
	FDB	CFA_GET
	FDB	CFA_ZEROBRANCH
	FDB	LIT1-*
	FDB	CFA_COMPILE   ; compiling
	FDB	CFA_LIT_WORD
	FDB	CFA_COMMA
LIT1:	FDB	CFA_SEMIS     ; done
; --------------------------------
NFA_DLITERAL:
	FCB	$80|$40|8
DLITERAL:
	FCB	"DLITERA",('L'|$80)
LFA_DLITERAL:
	FDB	NFA_LITERAL
CFA_DLITERAL:
	FDB	DOCOL
	FDB	CFA_STATE
	FDB	CFA_GET
	FDB	CFA_ZEROBRANCH
	FDB	DLIT1-*
	FDB	CFA_SWAP
	FDB	CFA_LITERAL
	FDB	CFA_LITERAL
DLIT1:	FDB	CFA_SEMIS
; --------------------------------
NFA_INTERPRET:
	FCB	$80|9
INTERPRET:
	FCB	"INTERPRE",('T'|$80)
LFA_INTERPRET:
	FDB	NFA_DLITERAL
CFA_INTERPRET:
	FDB	DOCOL
INTER1:	FDB	CFA_MINUSFIND         ; read a word
	FDB	CFA_ZEROBRANCH
	FDB	INTER4-*              ; test for number

	FDB	CFA_STATE
	FDB	CFA_GET
	FDB	CFA_LT
	FDB	CFA_ZEROBRANCH
	FDB	INTER2-*                 ; executing

	FDB	CFA_CFA                  ; compiling
	FDB	CFA_COMMA
	FDB	CFA_BRANCH
	FDB	INTER3-*

INTER2:	FDB	CFA_CFA
	FDB	CFA_EXECUTE

INTER3:	FDB	CFA_QUESTSTACK
	FDB	CFA_BRANCH
	FDB	INTER7-*

INTER4:	FDB	CFA_HERE              ; a number?
	FDB	CFA_NUMBER
	FDB	CFA_DPL
	FDB	CFA_GET
	FDB	CFA_ONEPLUS
	FDB	CFA_ZEROBRANCH
	FDB	INTER5-*

	FDB	CFA_DLITERAL
	FDB	CFA_BRANCH
	FDB	INTER6-*

INTER5:	FDB	CFA_DROP
	FDB	CFA_LITERAL
INTER6:	FDB	CFA_QUESTSTACK
INTER7:	FDB	CFA_BRANCH
	FDB	INTER1-*              ; loop back 
;       no SEMIS needed
; --------------------------------
NFA_IMMEDIATE:
	FCB	$80|9
IMMEDIATE:
	FCB	"IMMEDIAT",('E'|$80)
LFA_IMMEDIATE:
	FDB	NFA_INTERPRET
CFA_IMMEDIATE:
	FDB	DOCOL
	FDB	CFA_LATEST
	FDB	CFA_LIT_BYTE
	FCB	$40
	FDB	CFA_TOGGLE
	FDB	CFA_SEMIS
; --------------------------------
NFA_VOCABULARY:
	FCB	$80|$0A
VOCABULARY:
	FCB	"VOCABULAR",('Y'|$80)
LFA_VOCABULARY:
	FDB	NFA_IMMEDIATE
;
; Vocabulary e.g. "FORTH"
; NFA    $C5 .  #FORTH
; LFA    $6F43  NFA_IMMEDIATE (previous word)
;        $6A80  COD_DOESGT    (DOES>)
;        $6F70  CFA_DOVOC     (2+ CONTEXT ! )
; CFA    $81A0  dummy NFA         copy CONTEXT to VOC-LINK below
; LFA +1 $7FBE  NFA_TWODIV    [ASCII]
;     *2 $0000  VOC-LINK when this vocabulary was created
;
; VOC-LINK gets updated and now points to the stored previous VOC-LINK
; at CFA+2
;
CFA_VOCABULARY:
	FDB	DOCOL

	FDB	CFA_LTBUILDS        ; <BUILDS
	FDB	CFA_LIT_WORD,$81A0  ; length=(1|$80), name=(' '|$80)
	FDB	CFA_COMMA           ; store dummy name
	FDB	CFA_CURRENT,CFA_GET,CFA_CFA     ; get CFA of CURRENT
	FDB	CFA_COMMA           ; CFA: link to CFA of top word
	FDB	CFA_HERE            ; save for updating VOC-LINK
	FDB	CFA_VOC_LINK,CFA_GET
	FDB	CFA_COMMA           ; LFA: link to previous Vocabulary
	FDB	CFA_VOC_LINK
	FDB	CFA_EXCLAM          ; store saved HERE as new VOC-LINK

	FDB	CFA_DOESGT          ; DOES>
CFA_DOVOC:                          ; entry from FORTH
	FDB	CFA_TWOPLUS         ; VOC-LINK -> to previous Vocabulary
	FDB	CFA_CONTEXT         ;                  in chain
	FDB	CFA_EXCLAM          ; store in CONTEXT
	FDB	CFA_SEMIS
; --------------------------------
NFA_FORTH:
	FCB	$80|$40|5
FORTH:
	FCB	"FORT",('H'|$80)
LFA_FORTH:
	FDB	NFA_VOCABULARY
CFA_FORTH:
	FDB	COD_DOESGT          ; DOES>
	FDB	CFA_DOVOC           ; activate VOCABULARY with the following name 
	FDB	$81A0               ; dummy name field: length=(1|$80), name=(' '|$80)with name ' '
	if MH_EXTENSIONS == 1
	FDB	NFA_TWODIV          ; link to latest top word
	else
	FDB	NFA_TWOMUL          ; link to top word "2*"
	endif
	FDB	$0000               ; CFA dummy, will be copied, leave as is
; --------------------------------
DEDICATION:                         ; serves as a mark for copying
	; we'll keep these memories...
	FCB	"(C) 1982 J.W.Brown To Sarah" ; we leave this as is
	if INCLUDE_FLUFF == 1
	; 2 excess bytes
	FCB	$0A,$0D             
	endif
; --------------------------------
NFA_DEFINITIONS:
	FCB	$80|$0B
DEFINITIONS:
	FCB	"DEFINITION",('S'|$80)
LFA_DEFINITIONS:
	FDB	$0D00               ; ???? where  is this pointing to ????
CFA_DEFINITIONS:                    ; in fig Forth this points to NFA_VOCABULARY
	FDB	DOCOL
	FDB	CFA_CONTEXT         ; address of variable
	FDB	CFA_GET             ; content: address of start of chain
	FDB	CFA_CURRENT
	FDB	CFA_EXCLAM          ; CURRENT = CONTEXT
	FDB	CFA_SEMIS
; --------------------------------
NFA_OPAREN:
	FCB	$80|$40|1
OPAREN:
	FCB	('('|$80)
LFA_OPAREN:
	FDB	NFA_DEFINITIONS
CFA_OPAREN:
	FDB	DOCOL
	FDB	CFA_LIT_BYTE
	FCB	$29
	FDB	CFA_WORD
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUIT:
	FCB	$80|4
QUIT:
	FCB	"QUI",('T'|$80)
LFA_QUIT:
	FDB	NFA_OPAREN
CFA_QUIT:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_BLK
	FDB	CFA_EXCLAM     ; set BLK to zero
	FDB	CFA_LBRACK     ; [
QUIT1:                         ; the never ending outer interpreter
	FDB	CFA_RPSTOR
	FDB	CFA_CR
	FDB	CFA_QUERY       ; get line of input
	FDB	CFA_INTERPRET   ; and interpret

	FDB	CFA_STATE
	FDB	CFA_GET          ; STATE 1=compiling 0=executing
	FDB	CFA_ZEROEQ      ; 
	FDB	CFA_ZEROBRANCH  ; STATE not 0:
	FDB	QUIT2-*         ; compiling: skip to CFA_BRANCH
		                ; could be optimized by 
		                ; directly branching to FDB QUIT1-*
	FDB	CFA_PARDOTQP    ; executing: show prompt " OK"
LEN_QUIT:
	FCB	$03             ; 1 length byte
MSG_QUIT:
	FCB	" OK"           ; 3 bytes to fit word granularity
QUIT2:
	FDB	CFA_BRANCH
	FDB	QUIT1-*         ; next line of input, never leave
; --------------------------------
NFA_ABORT:
	FCB	$80|5
ABORT:
	FCB	"ABOR",('T'|$80)
LFA_ABORT:
	FDB	NFA_QUIT
CFA_ABORT:
	FDB	DOCOL
	FDB	CFA_SPSTOR
	FDB	CFA_DECIMAL
	FDB	CFA_QUESTSTACK
	FDB	CFA_CR
	FDB	CFA_PARDOTQP              ; (.")  " to satisfy syntax highlighter
LEN_NAME:
	FCB	$10
NAME:
	if MH_EXTENSIONS == 1
	FCB	"EPSON-FORTH V1.X"
	else
	FCB	"EPSON-FORTH V1.0"
	endif

	FDB	$0D08                  ; 
	FDB	CFA_DEFINITIONS
	FDB	CFA_QUIT               ; infinite interpreter loop
;       ... rest is not reached due to QUIT

; warm and cold start copy data
; 04B6  ADDR_SP0   $06FE    initial computational stack pointer SP = S0
; 04B8             $05FE    initial return stack pointer RP = R0
; USER variables
; 04BA             $0500    start of TIB
; 04BC             $001F    WIDTH
; 04BE             $0000    WARNING
; 04C0  ADDR_FENCE $1000    FENCE 
; 04C2  ADDR_DP0   $1000    DP
; 04C4  ADDR_VL0   $0D0E    initial VOC-LINK
; 04C6             $0000    BLK
; 04C8             $000F    IN
; 04CA             $058B    OUT
; 04CC             $0000    SCR
; 04CE             $0000    OFFSET
; 04D0             $0D0E    initial CONTEXT
; 04D2             $0D0E    initial CURRENT
; 04D4             $0000    STATE
; 04D6             $0010    BASE
; 04D8             $FFFF    DPL
; 04DA             $0000    FLD
; 04DC             $06FE    CSP
; 04DE             $0000    R#
; 04E0             $        HLD
; 04E2             $        
; 04E4             $        
; 04E6             $        
; 04E8  CHAR_MASK     $007F    MASK : 7 bit mask for emit      

;
; At initialization, "FORTH" and (ABORT) as well as some additional
; data get copied to $0C00...$0D12
;
; Address      NFA_PARABORT:
; 0C00 87         FCB     $80|7
;              PARABORT:
; 0C01 2841424F5254A9 FCB "(ABORT",(')'|$80)
;              LFA_PARABORT:
; 0C08 6DAF       FDB     NFA_MINUSFIND
;              CFA_PARABORT:
; 0C0A 65F2       FDB     DOCOL
; 0C0C 7024       FDB     CFA_ABORT
; 0C0E 6444       FDB     CFA_SEMIS
; 0C10 $7E $DFF1  == jmp $DFF1 output one character 
; ...
;              NFA_FORTH:
; 0CFE C5         FCB     $80|$40|5
;              FORTH:
; 0D00 464F5254C8 FCB     "FORT",('H'|$80)
;              LFA_FORTH:
; 0D05 6F8B       FDB     NFA_VOCABULARY
;              CFA_FORTH:
; 0D07 6AC8       FDB     COD_DOESGT
; 0D09 6FB8       FDB     CFA_DOVOC    ; jump into VOCABULARY and NEXT
; 0D0B 81A0       FDB     $81A0        ; NFA dummy name field ' '
; 0D0D 7F10       FDB     NFA_TWOMUL   ; LFA latest word in dictionary
; 0D09 0000       FDB     $0000        ; CFA ????
;
; ---
; if not OK: interpreter shows copyright notice
CFA_ABORT3:
	FDB	DOCOL
	FDB	CFA_CR
	FDB	CFA_PARDOTQP
LEN_COPYRITE:
	FCB	$1B        ; 27 characters
MSG_COPYRITE:
	FCB	"Copyright 1982",$0A,$0D,"J.W.Brown  "
;
	FDB	CFA_ABORT
	FDB	CFA_SEMIS

; copy block from trailing $0000 to NFA_FORTH
CPY_FORTH:                         ; copy FORTH word (18 bytes) to $0CFE...$0D10
	lds	#$0D11             ; load (SP) with $0D11
	ldx	#DEDICATION        ; load (X) with source address + 1
CPY_FORTH_1:
	dex                        ; src--
	ldaa	$00,x              ; get byte
	psha                       ; push to destination and decrement SP 
	cpx	#NFA_FORTH         ; NFA_FORTH reached?
	bne	CPY_FORTH_1        ; no, copy previous byte
	lds	#$0C0F             ; load (SP) with $0C0F
	jmp	CPY_PARABORT
; --------------------------------
NFA_COLD:
	FCB	$80|4
COLD:
	FCB	"COL",('D'|$80)
LFA_COLD:
	FDB	NFA_ABORT
CFA_COLD:
	FDB	DOCOLD         ; machine code word
DOCOLD:
	if INCLUDE_FLUFF == 1
	; 3 bytes
	jmp	CPY_FORTH      ; copy FORTH and (ABORT) words to RAM
	else
	; 1 excess byte less
	bra	CPY_FORTH      ; copy FORTH and (ABORT) words to RAM
	endif
;
CPY_PARABORT:   ; copy PARABORT word (16 bytes) to (SP) $0C01...$0C0F
	ldx	#NFA_ERROR     ; load (X) with source address + 1
CPY_PABORT_2:
	dex                    ; src--
	ldaa	$00,x          ; get byte
	psha                   ; store at (SP) and decrement (SP)
	cpx	#NFA_PARABORT  ; start of block reached?
	bne	CPY_PABORT_2   ; next

	if INCLUDE_FLUFF == 1
	jmp	CPY_DSPVEC     ; copy character output vector
	else
	; avoid long jump to CPY_DSPVEC and insert code here
	ldaa	#$7E           ; this is the jmp opcode
	ldx	#XDFF1         ; routine DFF1: display one character on screen
	staa	SYS_OUT_CHR    ; copy jmp instruction ...
	stx	SYS_OUT_CHR+1  ; and 16-bit function address

	lds	#$04BF         ; load (SP) with $04BF for copy operation
	endif

CPY_NEXT_4:                 ; copy individual words on cold start
	ldx	ADDR_VL0    ; $0D0E
	stx	X04C4       ; VOC-LINK
	ldx	ADDR_DP0    ; $1000
	stx	X04C2       ; DP
	ldx	ADDR_FENCE  ; $1000
	stx	X04C0       ; FENCE
L70AF:
	ldx	CHAR_MASK   ; $007F  
	stx	X04E8       ; low byte at X04E9 used as MASK in EMIT

DOWARM:                     ; copy 10 bytes from [ADDR_SP0...ADDR_FENCE-1]
	lds	#$04BF      ; load (SP) with destination address of last byte
	ldx	#ADDR_FENCE ; src+1
CPY_SP03:
	dex                 ; src--
	ldaa	$00,x       ; get byte
	psha                ; store byte
	cpx	#ADDR_SP0
	bne	CPY_SP03    ; loop
;
	if MH_EXTENSIONS == 1
	; additional initialization output to LCD only
	ldaa	#$01           ; 0: none, 1: LCD, 2: PRN, 4: RS232C
	staa	PRNFLAG        ; default output: LCD only
	endif
;
	lds	ADDR_SP0      ; load (SP)
	ldx	ADDR_USER     ; data stack pointer
	stx	PTR_SP        ;
	ldx	X0098         ; get a word
	cpx	#(('O'<<8)|'K')   ; if (X) == #$4F4B == 'OK'
	beq	STATE_OK

	ldx	#CFA_ABORT3 ; start address if not OK
L70D6:
	stx	PTR_IP      ; start here
	jmp	L6437
;
STATE_OK:
	ldx	#CFA_ABORT  ; start address if OK
	bra	L70D6
;
MSG_WARM:
	FDB	$0001
	FCB	"Warm?"
;
RESTART:
	ldaa	#$0C
	jsr	SYS_DSPSCR   ; $0C: clear LCD
	ldx	#MSG_WARM    ; string address
	ldab	#$05         ; string length
	jsr	ROM_D715     ; display WARM string
	ldaa	#$16
	jsr	SYS_DSPSCR   ; $16: make cursor visible
	stx	X0098        ; store 2 characters "OK" or not from Basic?
	jsr	SYS_KEYIN    ; wait for key 'Y'=01011001, 'y'=01111001
	rora                 ;              'N'=01001110, 'n'=01101110
	bcs	RESTART_WARM ; if 'Y'/'y' (or other char A,C,E,G... with bit 0 set)

	; 3 bytes
	jmp	DOCOLD

RESTART_WARM:
	if INCLUDE_FLUFF == 1
	; 3 bytes
	jmp	DOWARM
	else
	; 1 excess byte less
	bra	DOWARM
	endif
;
	if INCLUDE_FLUFF == 1
	; 2 excess bytes
	FDB	$0000        ; ???? unused bytes
	endif
; --------------------------------
NFA_STOD:
	FCB	$80|4
STOD:
	FCB	"S->",('D'|$80)
LFA_STOD:
	FDB	NFA_COLD
CFA_STOD:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_ZEROLT
	FDB	CFA_NEGATE
	FDB	CFA_SEMIS
; --------------------------------
NFA_DPLUSMINUS:
	FCB	$80|3
DPLUSMINUS:
	FCB	"D+",('-'|$80)
LFA_DPLUSMINUS:
	FDB	NFA_STOD
CFA_DPLUSMINUS:
	FDB	DOCOL
	FDB	CFA_ZEROLT
	FDB	CFA_ZEROBRANCH
	FDB	DPLUSM1-*
	FDB	CFA_DNEGATE
DPLUSM1:
	FDB	CFA_SEMIS
; --------------------------------
NFA_PLUSMINUS:
	FCB	$80|2
PLUSMINUS:
	FCB	"+",('-'|$80)
LFA_PLUSMINUS:
	FDB	NFA_DPLUSMINUS
CFA_PLUSMINUS:
	FDB	DOCOL
	FDB	CFA_ZEROLT
	FDB	CFA_ZEROBRANCH
	FDB	PLUSM1-*
	FDB	CFA_NEGATE
PLUSM1:	FDB	CFA_SEMIS
; --------------------------------
NFA_ABS:
	FCB	$80|3
ABS:
	FCB	"AB",('S'|$80)
LFA_abs:
	FDB	NFA_PLUSMINUS
CFA_ABS:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_PLUSMINUS
	FDB	CFA_SEMIS
; --------------------------------
NFA_DABS:
	FCB	$80|4
DABS:
	FCB	"DAB",('S'|$80)
LFA_DABS:
	FDB	NFA_ABS
CFA_DABS:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_DPLUSMINUS
	FDB	CFA_SEMIS
; --------------------------------
NFA_MMUL:
	FCB	$80|2
MMUL:
	FCB	"M",('*'|$80)
LFA_MMUL:
	FDB	NFA_DABS
CFA_MMUL:
	FDB	DOCOL
	FDB	CFA_TWODUP
	FDB	CFA_XOR
	FDB	CFA_TOR
	FDB	CFA_ABS
	FDB	CFA_SWAP
	FDB	CFA_ABS
	FDB	CFA_UMUL
	FDB	CFA_FROMR
	FDB	CFA_DPLUSMINUS
	FDB	CFA_SEMIS
; --------------------------------
NFA_MDIV:
	FCB	$80|2
MDIV:
	FCB	"M",('/'|$80)
LFA_MDIV:
	FDB	NFA_MMUL
CFA_MDIV:
	FDB	DOCOL
	FDB	CFA_OVER
	FDB	CFA_TOR
	FDB	CFA_TOR
	FDB	CFA_DABS
	FDB	CFA_R
	FDB	CFA_ABS
	FDB	CFA_UDIV
	FDB	CFA_FROMR
	FDB	CFA_R
	FDB	CFA_XOR
	FDB	CFA_PLUSMINUS
	FDB	CFA_SWAP
	FDB	CFA_FROMR
	FDB	CFA_PLUSMINUS
	FDB	CFA_SWAP
	FDB	CFA_SEMIS
; --------------------------------
NFA_MULTIPLY:
	FCB	$80|1
MULTIPLY:
	FCB	('*'|$80)
LFA_MULTIPLY:
	FDB	NFA_MDIV
CFA_MULTIPLY:
	FDB	*+2
	jsr	L6388
	ins
	ins
	jmp	NEXT
; --------------------------------
NFA_DIVMOD:
	FCB	$80|4
DIVMOD:
	FCB	"/MO",('D'|$80)
LFA_DIVMOD:
	FDB	NFA_MULTIPLY
CFA_DIVMOD:
	FDB	DOCOL
	FDB	CFA_TOR
	FDB	CFA_STOD
	FDB	CFA_FROMR
	FDB	CFA_MDIV
	FDB	CFA_SEMIS
; --------------------------------
NFA_DIV:
	FCB	$80|1
DIV:
	FCB	('/'|$80)
LFA_DIV:
	FDB	NFA_DIVMOD
CFA_DIV:
	FDB	DOCOL
	FDB	CFA_DIVMOD
	FDB	CFA_SWAP
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_MULDIVMOD:
	FCB	$80|5
MULDIVMOD:
	FCB	"*/MO",('D'|$80)
LFA_MULDIVMOD:
	FDB	NFA_DIV
CFA_MULDIVMOD:
	FDB	DOCOL
	FDB	CFA_TOR
	FDB	CFA_UMUL
	FDB	CFA_FROMR
	FDB	CFA_UDIV
	FDB	CFA_SEMIS
; --------------------------------
NFA_MULDIV:
	FCB	$80|2
MULDIV:
	FCB	"*",('/'|$80)
LFA_MULDIV:
	FDB	NFA_MULDIVMOD
CFA_MULDIV:
	FDB	DOCOL
	FDB	CFA_MULDIVMOD
	FDB	CFA_SWAP
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_MDIVMOD:
	FCB	$80|5
MDIVMOD:
	FCB	"M/MO",('D'|$80)
LFA_MDIVMOD:
	FDB	NFA_MULDIV
CFA_MDIVMOD:
	FDB	DOCOL
	FDB	CFA_TOR
	FDB	CFA_ZERO
	FDB	CFA_R
	FDB	CFA_UDIV
	FDB	CFA_FROMR
	FDB	CFA_SWAP
	FDB	CFA_TOR
	FDB	CFA_UDIV
	FDB	CFA_FROMR
	FDB	CFA_SEMIS
; --------------------------------
NFA_DOTLINE:
	FCB	$80|5
DOTLINE:
	FCB	".LIN",('E'|$80)
LFA_DOTLINE:
	FDB	NFA_MDIVMOD
CFA_DOTLINE:
	FDB	DOCOL                 ; (n ---)
	FDB	CFA_CPERLINE          ; 64
	FDB	CFA_MULTIPLY          ; n*64
	FDB	CFA_FIRST             ; start of block buffer
	FDB	CFA_PLUS              ; addr = (FIRST + n*64)
	FDB	CFA_CPERLINE          ; addr 64
	FDB	CFA_MINUSTRAILING     ; trim
	FDB	CFA_TYPE              
	FDB	CFA_SEMIS
; --------------------------------
NFA_PRIME:
	FCB	$80|$40|1
PRIME:
	FCB	$A7        ; (' | $80)
LFA_PRIME:
	FDB	NFA_DOTLINE
CFA_PRIME:
	FDB	DOCOL
	FDB	CFA_MINUSFIND              ; -FIND -> (cfa b true)
	FDB	CFA_ZEROEQ
	FDB	CFA_ZERO
	FDB	CFA_QUESTERROR
	FDB	CFA_DROP                  ; leaves cfa
	FDB	CFA_LITERAL
	FDB	CFA_SEMIS
; --------------------------------
NFA_BACK:
	FCB	$80|4
BACK:
	FCB	"BAC",('K'|$80)
LFA_BACK:
	FDB	NFA_PRIME
CFA_BACK:
	FDB	DOCOL
	FDB	CFA_HERE
	FDB	CFA_SUBTRACT
	FDB	CFA_COMMA
	FDB	CFA_SEMIS
; --------------------------------
NFA_BEGIN:
	FCB	$80|$40|5
BEGIN:
	FCB	"BEGI",('N'|$80)
LFA_BEGIN:
	FDB	NFA_BACK
CFA_BEGIN:
	FDB	DOCOL
	FDB	CFA_QUESTCOMP
	FDB	CFA_HERE
	FDB	CFA_ONE
	FDB	CFA_SEMIS
; --------------------------------
NFA_THEN:
	FCB	$80|$40|4
THEN:
	FCB	"THE",('N'|$80)
LFA_THEN:
	FDB	NFA_BEGIN
CFA_THEN:
	FDB	DOCOL
	FDB	CFA_QUESTCOMP
	FDB	CFA_TWO
	FDB	CFA_QUESTPAIRS
	FDB	CFA_HERE
	FDB	CFA_OVER
	FDB	CFA_SUBTRACT
	FDB	CFA_SWAP
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_DO:
	FCB	$80|$40|2
DO:
	FCB	"D",('O'|$80)
LFA_DO:
	FDB	NFA_THEN
CFA_DO:
	FDB	DOCOL
	FDB	CFA_COMPILE
	FDB	CFA_PARDO
	FDB	CFA_HERE
	FDB	CFA_THREE
	FDB	CFA_SEMIS
; --------------------------------
NFA_LOOP:
	FCB	$80|$40|4
LOOP:
	FCB	"LOO",('P'|$80)
LFA_LOOP:
	FDB	NFA_DO
CFA_LOOP:
	FDB	DOCOL
	FDB	CFA_THREE
	FDB	CFA_QUESTPAIRS
	FDB	CFA_COMPILE
	FDB	CFA_PARLOOP
	FDB	CFA_BACK
	FDB	CFA_SEMIS
; --------------------------------
NFA_PLUSLOOP:
	FCB	$80|$40|5
PLUSLOOP:
	FCB	"+LOO",('P'|$80)
LFA_PLUSLOOP:
	FDB	NFA_LOOP
CFA_PLUSLOOP:
	FDB	DOCOL
	FDB	CFA_THREE
	FDB	CFA_QUESTPAIRS
	FDB	CFA_COMPILE
	FDB	CFA_PARPLOOP
	FDB	CFA_BACK
	FDB	CFA_SEMIS
; --------------------------------
NFA_UNTIL:
	FCB	$80|$40|5
UNTIL:
	FCB	"UNTI",('L'|$80)
LFA_UNTIL:
	FDB	NFA_PLUSLOOP
CFA_UNTIL:
	FDB	DOCOL
	FDB	CFA_ONE
	FDB	CFA_QUESTPAIRS
	FDB	CFA_COMPILE
	FDB	CFA_ZEROBRANCH
	FDB	CFA_BACK
	FDB	CFA_SEMIS
; --------------------------------
NFA_END:
	FCB	$C3
END:
	FCB	"EN",('D'|$80)
LFA_END:
	FDB	NFA_UNTIL
CFA_END:
	FDB	DOCOL
	FDB	CFA_UNTIL
	FDB	CFA_SEMIS
; --------------------------------
NFA_AGAIN:
	FCB	$80|$40|5
AGAIN:
	FCB	"AGAI",('N'|$80)
LFA_AGAIN:
	FDB	NFA_END
CFA_AGAIN:
	FDB	DOCOL
	FDB	CFA_ONE
	FDB	CFA_QUESTPAIRS
	FDB	CFA_COMPILE
	FDB	CFA_BRANCH
	FDB	CFA_BACK
	FDB	CFA_SEMIS
; --------------------------------
NFA_REPEAT:
	FCB	$C6
REPEAT:
	FCB	"REPEA",('T'|$80)
LFA_REPEAT:
	FDB	NFA_AGAIN
CFA_REPEAT:
	FDB	DOCOL
	FDB	CFA_TOR
	FDB	CFA_TOR
	FDB	CFA_AGAIN
	FDB	CFA_FROMR
	FDB	CFA_FROMR
	FDB	CFA_TWO
	FDB	CFA_SUBTRACT
	FDB	CFA_THEN
	FDB	CFA_SEMIS
; --------------------------------
NFA_IF:
	FCB	$80|$40|2     ; immediate
IF:
	FCB	"I",('F'|$80)
LFA_IF:
	FDB	NFA_REPEAT
CFA_IF:
	FDB	DOCOL
	FDB	CFA_COMPILE
	FDB	CFA_ZEROBRANCH
	FDB	CFA_HERE
	FDB	CFA_ZERO
	FDB	CFA_COMMA
	FDB	CFA_TWO
	FDB	CFA_SEMIS
; --------------------------------
NFA_ELSE:
	FCB	$80|$40|4
ELSE:
	FCB	"ELS",('E'|$80)
LFA_ELSE:
	FDB	NFA_IF
CFA_ELSE:
	FDB	DOCOL
	FDB	CFA_TWO
	FDB	CFA_QUESTPAIRS
	FDB	CFA_COMPILE
	FDB	CFA_BRANCH
	FDB	CFA_HERE
	FDB	CFA_ZERO
	FDB	CFA_COMMA
	FDB	CFA_SWAP
	FDB	CFA_TWO
	FDB	CFA_THEN
	FDB	CFA_TWO
	FDB	CFA_SEMIS
; --------------------------------
NFA_WHILE:
	FCB	$80|$40|5
WHILE:
	FCB	"WHIL",('E'|$80)
LFA_WHILE:
	FDB	NFA_ELSE
CFA_WHILE:
	FDB	DOCOL
	FDB	CFA_IF
	FDB	CFA_TWOPLUS
	FDB	CFA_SEMIS
; --------------------------------
NFA_SPACES:
	FCB	$80|6
SPACES:
	FCB	"SPACE",('S'|$80)
LFA_SPACES:
	FDB	NFA_WHILE
CFA_SPACES:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_MAX
	FDB	CFA_MINUSDUP
	FDB	CFA_ZEROBRANCH
	FDB	SPACES2-*
	FDB	CFA_ZERO
	FDB	CFA_PARDO
SPACES1:
	FDB	CFA_SPACE
	FDB	CFA_PARLOOP
	FDB	SPACES1-*
SPACES2:
	FDB	CFA_SEMIS
; --------------------------------
NFA_LTNUM:
	FCB	$80|2
LTNUM:
	FCB	"<",('#'|$80)
LFA_LTNUM:
	FDB	NFA_SPACES
CFA_LTNUM:
	FDB	DOCOL
	FDB	CFA_PAD
	FDB	CFA_HLD
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_NUMGT:
	FCB	$80|2
NUMGT:
	FCB	$23, $BE
LFA_NUMGT:
	FDB	NFA_LTNUM
CFA_NUMGT:
	FDB	DOCOL
	FDB	CFA_TWODROP
	FDB	CFA_HLD
	FDB	CFA_GET
	FDB	CFA_PAD
	FDB	CFA_OVER
	FDB	CFA_SUBTRACT
	FDB	CFA_SEMIS
; --------------------------------
NFA_SIGN:
	FCB	$80|4
SIGN:
	FCB	"SIG",('N'|$80)
LFA_SIGN:
	FDB	NFA_NUMGT
CFA_SIGN:
	FDB	DOCOL
	FDB	CFA_ROT
	FDB	CFA_ZEROLT
	FDB	CFA_ZEROBRANCH
	FDB	SIGN1-*
	FDB	CFA_LIT_WORD
	FDB	$002D
	FDB	CFA_HOLD
SIGN1:	FDB	CFA_SEMIS
; --------------------------------
NFA_NUMB:
	FCB	$80|1
NUMB:
	FCB	('#'|$80)
LFA_NUMB:
	FDB	NFA_SIGN
CFA_NUMB:                          ; convert one digit, leave remainder(nd)
	FDB	DOCOL
	FDB	CFA_BASE
	FDB	CFA_GET
	FDB	CFA_MDIVMOD        ; n/base(single), remainder(nd)
	FDB	CFA_ROT            ; get n/base
	FDB	CFA_LIT_WORD
	FDB	$0009
	FDB	CFA_OVER           ; get copy of n/base
	FDB	CFA_LT             ; 9 < n?
	FDB	CFA_ZEROBRANCH
	FDB	NUMB1-*            ; n < 10: skip to CFA_LIT_WORD $30
	FDB	CFA_LIT_WORD       ; arrive here if n > 9
	FDB	$0007
	FDB	CFA_PLUS           ; + 7:  10 -> 17
NUMB1:	FDB	CFA_LIT_WORD           
	FDB	$0030             
	FDB	CFA_PLUS           ; + 48: 0 -> '0', 17 -> 'A' 
	FDB	CFA_HOLD
	FDB	CFA_SEMIS
; --------------------------------
NFA_NUMS:
	FCB	$80|2
NUMS:
	FCB	"#",('S'|$80)
LFA_NUMS:
	FDB	NFA_NUMB
CFA_NUMS:                            ; convert nd to PAD, leaves 0d
	FDB	DOCOL
NUMS1:	FDB	CFA_NUMB             ; convert one digit, leave remainder
	FDB	CFA_TWODUP           ; test remainder double words == 0
	FDB	CFA_OR
	FDB	CFA_ZEROEQ           ; remainder == 0 -> true = 1
	FDB	CFA_ZEROBRANCH       ; no,
	FDB	NUMS1-*              ; back do next digit
	FDB	CFA_SEMIS
; --------------------------------
NFA_DDOTR:
	FCB	$80|3
DDOTR:
	FCB	"D.",('R'|$80)
LFA_DDOTR:
	FDB	NFA_NUMS
CFA_DDOTR:
	FDB	DOCOL               ; (nd width ---)
	FDB	CFA_TOR
	FDB	CFA_SWAP
	FDB	CFA_OVER
	FDB	CFA_DABS
	FDB	CFA_LTNUM
	FDB	CFA_NUMS
	FDB	CFA_SIGN
	FDB	CFA_NUMGT
	FDB	CFA_FROMR
	FDB	CFA_OVER
	FDB	CFA_SUBTRACT
	FDB	CFA_SPACES
	FDB	CFA_TYPE
	FDB	CFA_SEMIS
; --------------------------------
NFA_DDOT:
	FCB	$80|2
DDOT:
	FCB	"D",('.'|$80)
LFA_DDOT:
	FDB	NFA_DDOTR
CFA_DDOT:
	FDB	DOCOL
	FDB	CFA_ZERO             ; field width
	FDB	CFA_DDOTR            ; (nd width ---)
	FDB	CFA_SPACE
	FDB	CFA_SEMIS
; --------------------------------
NFA_DOTR:
	FCB	$80|2
DOTR:
	FCB	".",('R'|$80)
LFA_DOTR:
	FDB	NFA_DDOT
CFA_DOTR:
	FDB	DOCOL
	FDB	CFA_TOR
	FDB	CFA_STOD
	FDB	CFA_FROMR
	FDB	CFA_DDOTR
	FDB	CFA_SEMIS
; --------------------------------
NFA_DOT:
	FCB	$80|1
DOT:
	FCB	('.'|$80)
LFA_DOT:
	FDB	NFA_DOTR
CFA_DOT:
	FDB	DOCOL
	FDB	CFA_STOD
	FDB	CFA_DDOT
	FDB	CFA_SEMIS
; --------------------------------
NFA_QUEST:
	FCB	$80|1
QUEST:
	FCB	$BF
LFA_QUEST:
	FDB	NFA_DOT
CFA_QUEST:
	FDB	DOCOL
	FDB	CFA_GET
	FDB	CFA_DOT
	FDB	CFA_SEMIS
; --------------------------------
NFA_MESSAGE:
	FCB	$80|7
MESSAGE:
	FCB	"MESSAG",('E'|$80)
LFA_MESSAGE:
	FDB	NFA_QUEST
CFA_MESSAGE:
	FDB	DOCOL
	FDB	CFA_PARDOTQP
LEN_MESSAGE:
	FCB	$06
MSG_MESSAGE:
	FCB	"MSG # "
;
	FDB	CFA_DOT
	FDB	CFA_SEMIS
; --------------------------------
NFA_FORGET:
	FCB	$80|6
FORGET:
	FCB	"FORGE",('T'|$80)
LFA_FORGET:
	FDB	NFA_MESSAGE
CFA_FORGET:
	FDB	DOCOL

	FDB	CFA_CURRENT
	FDB	CFA_GET
	FDB	CFA_CONTEXT
	FDB	CFA_GET
	FDB	CFA_SUBTRACT         ; 0 if CONTEXT == CURRENT
	FDB	CFA_LIT_WORD
	FDB	$0018
	FDB	CFA_QUESTERROR       ; error #24: "Not in CURRENT Vocabulary"

	FDB	CFA_PRIME            ; ' next word
	FDB	CFA_DUP
	FDB	CFA_FENCE
	FDB	CFA_GET
	FDB	CFA_LT               ; 0 if FENCE > '
	FDB	CFA_LIT_WORD
	FDB	$0015                ; error #21: "In Protected Dictionary"
	FDB	CFA_QUESTERROR

	FDB	CFA_DUP
	FDB	CFA_NFA
	FDB	CFA_DP
	FDB	CFA_EXCLAM

	FDB	CFA_LFA
	FDB	CFA_GET
	FDB	CFA_CURRENT
	FDB	CFA_GET
	FDB	CFA_EXCLAM

	FDB	CFA_SEMIS
; --------------------------------
NFA_MON:
	FCB	$80|3
MON:
	FCB	"MO",('N'|$80)
LFA_MON:
	FDB	NFA_FORGET
CFA_MON:
	FDB	*+2
	if (MH_EXTENSIONS == 1) 
	if (ROM_CD & V11) == V11	
	; 12 bytes for V1.1 ROM
	ldx	#NEXT     ; return address
	stx	$02C1     ; return address: NEXT
	stx	$02BF     ; program counter: NEXT
	jmp	$FF10     ; jump into MONITOR
;	jmp	$DFF7     ; V 1.0 jumps voa FF10 -> jmp DFF7 -> jmp D310
;                         ; V 1.1 jumps via FF10 -> jmp DFF7 -> jmp D77E
	else
	jsr	ROM_D310  ; version dependent
	jmp	NEXT      ; is this required?
	endif
	else
	; 6 bytes
	jsr	ROM_D310  ; version dependent, sets return address
	jmp	NEXT      ; is this required?
	endif
; --------------------------------
NFA_CLS:
	FCB	$83
CLS:
	FCB	"CL",('S'|$80)
LFA_CLS:
	FDB	NFA_MON
CFA_CLS:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$000C               ; clear-screen character
	FDB	CFA_EMIT
	FDB	CFA_SEMIS
; --------------------------------
NFA_PICK:
	FCB	$80|4
PICK:
	FCB	"PIC",('K'|$80)
LFA_PICK:
	FDB	NFA_CLS
CFA_PICK:
	FDB	DOCOL
	FDB	CFA_DUP              ; n n
	FDB	CFA_ONE              ; level must be 1 or higher
	FDB	CFA_LT
	FDB	CFA_LIT_WORD
	FDB	$0005                ; error #5: "Parameter Outside Valid Range"
	FDB	CFA_QUESTERROR
	FDB	CFA_DUP
	FDB	CFA_PLUS              ; n*2
	FDB	CFA_SPGET
	FDB	CFA_PLUS              ; SP + n*2
	FDB	CFA_GET
	FDB	CFA_SEMIS
; --------------------------------
NFA_LTCMOVE:
	FCB	$80|6
LTCMOVE:
	FCB	"<CMOV",('E'|$80)
LFA_LTCMOVE:
	FDB	NFA_PICK
CFA_LTCMOVE:
	FDB	DOCOL
	FDB	CFA_ONE
	FDB	CFA_SUBTRACT
	FDB	CFA_LIT_WORD
	FDB	$FFFF
	FDB	CFA_SWAP
	FDB	CFA_PARDO
LTCMOV1:
	FDB	CFA_OVER
	FDB	CFA_I
	FDB	CFA_PLUS
	FDB	CFA_CGET
	FDB	CFA_OVER
	FDB	CFA_I
	FDB	CFA_PLUS
	FDB	CFA_CSTOR
	FDB	CFA_LIT_WORD
	FDB	$FFFF
	FDB	CFA_PARPLOOP
	FDB	LTCMOV1-*
	FDB	CFA_TWODROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_ROLL:
	FCB	$80|4
ROLL:
	FCB	"ROL",('L'|$80)
LFA_ROLL:
	FDB	NFA_LTCMOVE
CFA_ROLL:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_DUP
	FDB	CFA_PLUS
	FDB	CFA_TOR
	FDB	CFA_PICK
	FDB	CFA_SPGET
	FDB	CFA_DUP
	FDB	CFA_TWOPLUS
	FDB	CFA_FROMR
	FDB	CFA_LTCMOVE
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_SEED:
	FCB	$80|4
SEED:
	FCB	"SEE",('D'|$80)
LFA_SEED:
	FDB	NFA_ROLL
CFA_SEED:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$009A
	FDB	CFA_SEMIS
; --------------------------------
NFA_PARRND:
	FCB	$80|5
PARRND:
	FCB	"(RND",(')'|$80)
LFA_PARRND:
	FDB	NFA_SEED
CFA_PARRND:
	FDB	DOCOL
	FDB	CFA_SEED
	FDB	CFA_GET
	FDB	CFA_LIT_WORD
	FDB	$0103
	FDB	CFA_MULTIPLY
	FDB	CFA_THREE
	FDB	CFA_PLUS
	FDB	CFA_LIT_WORD
	FDB	$7FFF
	FDB	CFA_AND
	FDB	CFA_DUP
	FDB	CFA_SEED
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_RND:
	FCB	$80|3
RND:
	FCB	"RN",('D'|$80)
LFA_RND:
	FDB	NFA_PARRND
CFA_RND:
	FDB	DOCOL                      ; n
	FDB	CFA_PARRND                 ; n seed
	FDB	CFA_LIT_WORD
	FDB	$7FFF                      ; n seed $7FFF
	FDB	CFA_MULDIV                 ; n * seed / $7FFF
	FDB	CFA_SEMIS
; --------------------------------
NFA_TEXT:
	FCB	$80|4
TEXT:
	FCB	"TEX",('T'|$80)
LFA_TEXT:
	FDB	NFA_RND
CFA_TEXT:
	FDB	DOCOL                  ; on entry: terminator, e.g. blank on stack
	FDB	CFA_HERE               ; make empty line at HERE
	FDB	CFA_CPERLINE           ; C/L (64) characters / line
	FDB	CFA_ONEPLUS            ; C/L+1
	FDB	CFA_BLANKS             ; C/L+1 blanks at HERE
	FDB	CFA_WORD               ; read one word from input to HERE, uses terminator
	FDB	CFA_HERE               ; source
	FDB	CFA_PAD                ; destination
	FDB	CFA_CPERLINE
	FDB	CFA_ONEPLUS            ; C/L+1
	FDB	CFA_CMOVE              ; copy to PAD
	FDB	CFA_SEMIS
; --------------------------------
NFA_LINE:
	FCB	$80|4
LINE:
	FCB	"LIN",('E'|$80)
LFA_LINE:
	FDB	NFA_TEXT
CFA_LINE:                      ; return start address of line
	FDB	DOCOL          ; (line --- addr)
	FDB	CFA_DUP        ; (line line)
	FDB	CFA_LIT_WORD
	FDB	$FFF0          ; must be in 0...15
	FDB	CFA_AND
	FDB	CFA_LIT_WORD
	FDB	$0017          ; error #23: "Off Current Editing Screen"
	FDB	CFA_QUESTERROR
	FDB	CFA_CPERLINE   ; o.k.: less than 16
	FDB	CFA_MULTIPLY   ; line*C/L
	FDB	CFA_FIRST      ; address of block buffer
	FDB	CFA_PLUS       ; FIRST + line*C/L
	FDB	CFA_SEMIS
; --------------------------------
NFA_EMPTY_BUFFERS:
	FCB	$80|$0D
EMPTY_BUFFERS:
	FCB	"EMPTY-BUFFER",('S'|$80)
LFA_EMPTY_BUFFERS:
	FDB	NFA_LINE
CFA_EMPTY_BUFFERS:
	FDB	DOCOL
	FDB	CFA_LIMIT
	FDB	CFA_LIT_WORD
	FDB	$0020
	FDB	CFA_SUBTRACT              ; LIMIT-32
	FDB	CFA_FIRST                 ; FIRST (start address)
	FDB	CFA_TWODUP
	FDB	CFA_SUBTRACT              ; LIMIT-32 FIRST (LIMIT-32-FIRST)
	FDB	CFA_BLANKS
	FDB	CFA_LIT_WORD
	FDB	$0020                     ; 32 
	FDB	CFA_ERASE
	FDB	CFA_SEMIS
; --------------------------------
NFA_ENTER:
	FCB	$80|5
ENTER:
	FCB	"ENTE",('R'|$80)
LFA_ENTER:
	FDB	NFA_EMPTY_BUFFERS
CFA_ENTER:
	FDB	DOCOL
	FDB	CFA_IN
	FDB	CFA_GET
	FDB	CFA_TOR              ; save current IN pointer
	FDB	CFA_ONE
	FDB	CFA_BLK
	FDB	CFA_EXCLAM           ; set BLK to one
	FDB	CFA_ZERO
	FDB	CFA_IN
	FDB	CFA_EXCLAM           ; set IN to zero
	FDB	CFA_INTERPRET
	FDB	CFA_FROMR
	FDB	CFA_IN
	FDB	CFA_EXCLAM           ; restore IN pointer
	FDB	CFA_ZERO
	FDB	CFA_BLK
	FDB	CFA_EXCLAM           ; set BLK to zero
	FDB	CFA_SEMIS
; --------------------------------
NFA_CONV:
	FCB	$80|4
CONV:
	FCB	"CON",('V'|$80)
LFA_CONV:
	FDB	NFA_ENTER
CFA_CONV:
	FDB	DOCOL
	FDB	CFA_STOD         ; S->D
	FDB	CFA_LTNUM        ; <#
	FDB	CFA_NUMB         ; #
	FDB	CFA_NUMB         ; #
	FDB	CFA_NUMB         ; #
	FDB	CFA_NUMGT        ; #>
	FDB	CFA_SEMIS
; --------------------------------
NFA_XFILE:
	FCB	$80|5
XFILE:
	FCB	"XFIL",('E'|$80)
LFA_XFILE:
	FDB	NFA_CONV
CFA_XFILE:
	FDB	*+2
	jmp	L604D
; --------------------------------
NFA_FILE:
	FCB	$80|4
FILE:
	FCB	"FIL",('E'|$80)
LFA_FILE:
	FDB	NFA_XFILE
CFA_FILE:                          ; 1=read, 0=write
	FDB	DOCOL
	FDB	CFA_CLS

	FDB	CFA_BASE           ; save current BASE
	FDB	CFA_GET
	FDB	CFA_DECIMAL        ; and change --- why ????

	FDB	CFA_SCR
	FDB	CFA_GET
	FDB	CFA_DUP           ; save for CONV below

	FDB	CFA_PARDOTQP
LEN_PROMPT:
	FCB	$01
MSG_PROMPT:
	FCB	">"              
	FDB	CFA_DOT           ; >SCR#

        ; Build the I/O block
	; Note that this is in the Monitor data area
	; 02A4: 00            start/stop 00 = stop between blocks
	; 02A5: top of buffer $0378 == SYS_CASBUF
	; 02A7: file name     "FORTH###"
	; 02AF: file type     "BIN?????"
	; 02B7: start addr    $0710   screen buffer starts here
	; 02B9: end addr      $0B0F   ==  1024 bytes = 64*16
	; 02BB: offset        $0000   none
	; 02BD: entry point   NEXT    == $6139
        ;       followed by 128 byte block buffer?

	FDB	CFA_CONV                                ; SCR to 3-digit string
	FDB	CFA_LIT_WORD,$02AC
	FDB	CFA_SWAP
	FDB	CFA_CMOVE                               ; 02AC: ###

	FDB	CFA_LIT_WORD,MENU_NAME                  ; copy 'FORTH'
	FDB	CFA_LIT_WORD,$02A7,CFA_LIT_WORD,$0005,CFA_CMOVE
                                                        ; 02A7: 'FORTH'
                                                        ; 02AC: ###
	FDB	CFA_LIT_WORD,$4249,CFA_LIT_WORD,$02AF,CFA_EXCLAM
                                                        ; 02AF: 'BI'
	FDB	CFA_LIT_WORD,$004E,CFA_LIT_WORD,$02B1,CFA_CSTOR
                                                        ; 02B1: 'N'
                                                        ; 02B2: .....
	FDB	CFA_LIT_WORD,$0710,CFA_LIT_WORD,$02B7,CFA_EXCLAM
                                                        ; 02B7: 0710
	FDB	CFA_LIT_WORD,$0B0F,CFA_LIT_WORD,$02B9,CFA_EXCLAM
                                                        ; 02B9: 0B0F
	FDB	CFA_ZERO,     CFA_LIT_WORD,$02BB,CFA_EXCLAM
                                                        ; 02BB: 0000
	FDB	CFA_LIT_WORD,NEXT, CFA_LIT_WORD,$02BD,CFA_EXCLAM
                                                        ; 02BD: 6130
	; insert in front of block
	FDB	CFA_LIT_WORD,SYS_CASBUF,CFA_LIT_WORD,$02A5,CFA_EXCLAM
                                                        ; 02A5: 0378 == SYS_CASBUF
	FDB	CFA_LIT_WORD,$0052,CFA_LIT_WORD,$0062,CFA_CSTOR
                                                        ; 0062: 'R'

	; restore BASE
	FDB	CFA_BASE
	FDB	CFA_EXCLAM

	; save read/write flag at 0061
	FDB	CFA_DUP,CFA_LIT_WORD,X0061,CFA_CSTOR

	FDB	CFA_ZEROBRANCH
	FDB	SAVEFILE-*
	; -----
LOADFILE:
	FDB	CFA_PARDOTQP
LEN_SEARCH:
	FCB	$09
MSG_SEARCH:
	FCB	"Searching"
	FDB	CFA_BRANCH
	FDB	LOADSAVE-*
	; -----
SAVEFILE:
	FDB	CFA_PARDOTQP
LEN_SAVE:
	FCB	$06
MSG_SAVE:
	FCB	"Saving"
	; -----
LOADSAVE:
	FDB	CFA_XFILE            ; read or write
	FDB	CFA_SEMIS
; --------------------------------
	if INCLUDE_FLUFF == 1
	; excess 2 bytes
	FDB	$0000                ; ???? unused
	endif
; --------------------------------
NFA_CASS:
	FCB	$80|4
CASS:
	FCB	"CAS",('S'|$80)
LFA_CASS:
	FDB	NFA_FILE
CFA_CASS:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	'C'                  ; 'C'assette
	FDB	CFA_LIT_WORD
	FDB	X0060
	FDB	CFA_CSTOR
	FDB	CFA_SEMIS
; --------------------------------
NFA_SAVE:
	FCB	$80|4
SAVE:
	FCB	"SAV",('E'|$80)
LFA_SAVE:
	FDB	NFA_CASS
CFA_SAVE:
	FDB	DOCOL
	FDB	CFA_SCR
	FDB	CFA_GET
	FDB	CFA_DUP           ; (screen# screen#)
	FDB	CFA_LIT_WORD
	FDB	$03E7             ; screen# must be <= 999
	FDB	CFA_GT
	FDB	CFA_SWAP
	FDB	CFA_ZERO          ; screen# must be >= 0
	FDB	CFA_LT
	FDB	CFA_OR            ; combine error flags
	FDB	CFA_LIT_WORD
	FDB	$0006             ; error #6: "Screen Number Out of Range"
	FDB	CFA_QUESTERROR
	FDB	CFA_CR
	FDB	CFA_ZERO          ; 0=save
	FDB	CFA_FILE          ; 0 FILE saves SCR
	FDB	CFA_CLS
	FDB	CFA_SCR
	FDB	CFA_GET
	FDB	CFA_DOT           ; print screen#
	FDB	CFA_PARDOTQP
LEN_SAVED:
	FCB	$05
MSG_SAVED:
	FCB	"Saved"
;
	FDB	CFA_SEMIS
; --------------------------------
NFA_LIST:
	FCB	$80|4
LIST:
	FCB	"LIS",('T'|$80)
LFA_LIST:
	FDB	NFA_SAVE
CFA_LIST:
	FDB	DOCOL
	FDB	CFA_CR
	FDB	CFA_DUP
	FDB	CFA_SCR
	FDB	CFA_GET
	FDB	CFA_SUBTRACT
	FDB	CFA_ZEROBRANCH
	FDB	LIST1-*            ; already loaded
	;
	FDB	CFA_DUP
	FDB	CFA_SCR
	FDB	CFA_EXCLAM         ; update SCR
	FDB	CFA_ONE            ; 1=read
	FDB	CFA_FILE           ; 1 FILE loads SCR
LIST1:	FDB	CFA_CLS
	FDB	CFA_PARDOTQP       ;
LEN_SCREEN:
	FCB	$06
MSG_SCREEN:
	FCB	"Scr # "
	FDB	CFA_DOT
	FDB	CFA_LIT_WORD
	FDB	$0010
	FDB	CFA_ZERO
	FDB	CFA_PARDO         ; over 16 lines
LIST2:	FDB	CFA_CR
	FDB	CFA_I             ; output I in a field
	FDB	CFA_TWO           ; 2 characters wide
	FDB	CFA_DOTR
	FDB	CFA_SPACE         ; output a space
	FDB	CFA_I
	FDB	CFA_DOTLINE       ; output line I
	FDB	CFA_PARLOOP
	FDB	LIST2-*           ; loop
	FDB	CFA_CR
	FDB	CFA_SEMIS
; --------------------------------
NFA_LOAD:
	FCB	$80|4
LOAD:
	FCB	"LOA",('D'|$80)
LFA_LOAD:
	FDB	NFA_LIST
CFA_LOAD:
	FDB	DOCOL
	FDB	CFA_SCR
	FDB	CFA_EXCLAM       ; store n in SCR
	FDB	CFA_CR
	FDB	CFA_FIRST        ; FIRST
	FDB	CFA_LIMIT        ; 
	FDB	CFA_OVER 
	FDB	CFA_SUBTRACT     ; FIRST (LIMIT-FIRST)
	FDB	CFA_ERASE        ; 
	FDB	CFA_ONE          ; 1=read
	FDB	CFA_FILE         ; 1 FILE loads SCR
	FDB	CFA_ENTER        ; and interpret the screen
	FDB	CFA_SEMIS
; --------------------------------
NFA_CONTI:
	FCB	$80|3
CONTI:
	FCB	"--",('>'|$80)
LFA_CONTI:
	FDB	NFA_LOAD
CFA_CONTI:
	FDB	DOCOL
	FDB	CFA_QUESTLOADING
	FDB	CFA_ZERO
	FDB	CFA_IN
	FDB	CFA_EXCLAM
	FDB	CFA_ONE
	FDB	CFA_SCR
	FDB	CFA_PLUSSTORE          ; increment
	FDB	CFA_ONE                ; 1=read
	FDB	CFA_FILE               ; 1 FILE loads SCR
	FDB	CFA_SEMIS
; --------------------------------
NFA_ANOTHER:
	FCB	$80|7
ANOTHER:
	FCB	"ANOTHE",('R'|$80)
LFA_ANOTHER:
	FDB	NFA_CONTI
CFA_ANOTHER:
	FDB	DOCOL
	FDB	CFA_EMPTY_BUFFERS
	FDB	CFA_ONE
	FDB	CFA_SCR
	FDB	CFA_PLUSSTORE
	FDB	CFA_SCR
	FDB	CFA_GET
	FDB	CFA_LIST
	FDB	CFA_SEMIS
; --------------------------------
NFA_PROGRAM:
	FCB	$80|7
PROGRAM:
	FCB	"PROGRA",('M'|$80)
LFA_PROGRAM:
	FDB	NFA_ANOTHER
CFA_PROGRAM:
	FDB	DOCOL
	FDB	CFA_CR
	FDB	CFA_DECIMAL
	FDB	CFA_PARDOTQP
LEN_FIRST:
	FCB	$11
MSG_FIRST:
	FCB	"First Scr. no. ? "
;
	FDB	CFA_QUERY               ; read line of input
	FDB	CFA_INTERPRET           ; execute it, leaves number n
	FDB	CFA_SPACE               ; output one space character
	FDB	CFA_ONE
	FDB	CFA_SUBTRACT            ; n-1
	FDB	CFA_SCR
	FDB	CFA_EXCLAM              ; SCR = n-1
	FDB	CFA_ANOTHER             ; next empty screen: n
	FDB	CFA_SEMIS
; --------------------------------
NFA_MORE:
	FCB	$80|4
MORE:
	FCB	"MOR",('E'|$80)
LFA_MORE:
	FDB	NFA_PROGRAM
CFA_MORE:
	FDB	DOCOL
	FDB	CFA_SAVE
	FDB	CFA_ANOTHER
	FDB	CFA_SEMIS
; --------------------------------
NFA_WHERE:
	FCB	$80|5
WHERE:
	FCB	"WHER",('E'|$80)
LFA_WHERE:
	FDB	NFA_MORE
CFA_WHERE:
	FDB	DOCOL
	FDB	CFA_SWAP
	FDB	CFA_CPERLINE
	FDB	CFA_DIV
	FDB	CFA_DUP
	FDB	CFA_DECIMAL
	FDB	CFA_SCR
	FDB	CFA_GET
	FDB	CFA_CR
	FDB	CFA_PARDOTQP
LEN_SCR:
	FCB	$03
MSG_SCR:
	FCB	"Scr"
;
	FDB	CFA_DOT
	FDB	CFA_PARDOTQP
LEN_LINE:
	FCB	$04
MSG_LINE:
	FCB	"Line"
;
	FDB	CFA_DOT
	FDB	CFA_CR
	FDB	CFA_DUP
	FDB	CFA_DOTLINE
	FDB	CFA_CR
	FDB	CFA_QUIT
	if INCLUDE_FLUFF == 1
	; 2 bytes less
	FDB	CFA_SEMIS          ; this is never reached due to QUIT
	endif
; --------------------------------
NFA_NUMLOCATE:
	FCB	$80|7
NUMLOCATE:
	FCB	"#LOCAT",('E'|$80)          ; (--- column row)
LFA_NUMLOCATE:
	FDB	NFA_WHERE
CFA_NUMLOCATE:
	FDB	DOCOL
	FDB	CFA_RNUM           ; get cursor position
	FDB	CFA_GET            ; (linear position)
	FDB	CFA_CPERLINE       ; division R# / (C/L) and remainder
	FDB	CFA_DIVMOD         ; (column row)
	FDB	CFA_SEMIS
; --------------------------------
NFA_NUMLEAD:
	FCB	$80|5
NUMLEAD:
	FCB	"#LEA",('D'|$80)   ; (addr length)
LFA_NUMLEAD:
	FDB	NFA_NUMLOCATE
CFA_NUMLEAD:
	FDB	DOCOL
	FDB	CFA_NUMLOCATE      ; (column row)
	FDB	CFA_LINE           ; (column addr) get line start addr
	FDB	CFA_SWAP           ; (addr column)
	FDB	CFA_SEMIS
; --------------------------------
NFA_NUMLAG:
	FCB	$80|4
NUMLAG:
	FCB	"#LA",('G'|$80)    ; (addr length)
LFA_NUMLAG:
	FDB	NFA_NUMLEAD
CFA_NUMLAG:
	FDB	DOCOL
	FDB	CFA_NUMLEAD        ; (addr column) line start and cursor column
	FDB	CFA_DUP
	FDB	CFA_TOR            ; save
	FDB	CFA_PLUS           ; addr+column
	FDB	CFA_CPERLINE
	FDB	CFA_FROMR
	FDB	CFA_SUBTRACT       ; C/L - column
	FDB	CFA_SEMIS          ; (addr n) address of cursor, remaining characters
; --------------------------------
NFA_MMOVE:
	FCB	$80|5
MMOVE:
	FCB	"-MOV",('E'|$80)     ; copy screen line n to given addres
LFA_MMOVE:
	FDB	NFA_NUMLAG
CFA_MMOVE:
	FDB	DOCOL
	FDB	CFA_LINE             ; get address of line n
	FDB	CFA_CPERLINE         ; count
	FDB	CFA_CMOVE            ; addr line count CMOVE
	FDB	CFA_SEMIS
; --------------------------------
NFA_H:
	FCB	$80|1
H:
	FCB	('H'|$80)
LFA_H:
	FDB	NFA_MMOVE
CFA_H:
	FDB	DOCOL                  ; (n ---)
	FDB	CFA_LINE               ; addr
	FDB	CFA_PAD                ; addr PAD
	FDB	CFA_ONEPLUS            ; addr PAD+1
	FDB	CFA_CPERLINE           ; addr PAD+1 64
	FDB	CFA_DUP                ; addr PAD+1 64  64
	FDB	CFA_PAD                ; addr PAD+1 64  64 PAD
	FDB	CFA_CSTOR              ; store 64 into length byte
	FDB	CFA_CMOVE              ; addr PAD+1 64 
	FDB	CFA_SEMIS              ; copy 64 bytes from line to PAD
; --------------------------------
NFA_E:
	FCB	$81
E:
	FCB	('E'|$80)
LFA_E:
	FDB	NFA_H
CFA_E:
	FDB	DOCOL
	FDB	CFA_LINE
	FDB	CFA_CPERLINE
	FDB	CFA_BLANKS
	FDB	CFA_SEMIS
; --------------------------------
NFA_S:
	FCB	$80|1
S:
	FCB	('S'|$80)
LFA_S:
	FDB	NFA_E
CFA_S:
	FDB	DOCOL
	FDB	CFA_DUP           ; for final erase at end
	FDB	CFA_ONE
	FDB	CFA_SUBTRACT
	FDB	CFA_LIT_WORD           ; n-1
	FDB	$000E             ; start at line 14
	FDB	CFA_PARDO         ; (DO)
S1:
	FDB	CFA_I
	FDB	CFA_LINE          ; get address of line i
	FDB	CFA_I
	FDB	CFA_ONEPLUS       ; i+1
	FDB	CFA_MMOVE         ; copy from i to i+1
	FDB	CFA_LIT_WORD
	FDB	$FFFF             ; -1
	FDB	CFA_PARPLOOP      ; (+LOOP)
	FDB	S1-*              ; back to (DO)
	FDB	CFA_E             ; clear line n
	FDB	CFA_SEMIS
; --------------------------------
NFA_D:
	FCB	$80|1
D:
	FCB	('D'|$80)
LFA_D:
	FDB	NFA_S
CFA_D:
	FDB	DOCOL
	if MH_EXTENSIONS == 1
	; 2 bytes less by inlining this internal word
	FDB	CFA_DUP            ; copy line
	FDB	CFA_H              ; to PAD
	else
	FDB	CFA_EDITOOL
	endif
	FDB	CFA_LIT_WORD
	FDB	$000F
	FDB	CFA_DUP
	FDB	CFA_ROT
	FDB	CFA_PARDO
D1:
	FDB	CFA_I
	FDB	CFA_ONEPLUS
	FDB	CFA_LINE
	FDB	CFA_I
	FDB	CFA_MMOVE
	FDB	CFA_PARLOOP
	FDB	D1-*
	FDB	CFA_E
	FDB	CFA_SEMIS
; --------------------------------
NFA_HALT:
	FCB	$80|4
HALT:
	FCB	"HAL",('T'|$80)
LFA_HALT:
	FDB	NFA_D
CFA_HALT:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$008F
	FDB	CFA_CGET             ; get flag from addr $8F == 143d
	FDB	CFA_ZEROBRANCH
	FDB	HALT2-*              ; if ==0 then skip to CFA_SEMIS
	FDB	CFA_PARDOTQP
LEN_PRESS:
	FCB	$0B
MSG_PRESS:
	FCB	"Press space"
;
	FDB	CFA_KEY            
	FDB	CFA_DROP           ; accept any key
HALT2:	FDB	CFA_SEMIS
; --------------------------------
NFA_M:
	FCB	$80|1
M:
	FCB	('M'|$80)
LFA_M:
	FDB	NFA_HALT
CFA_M:
	FDB	DOCOL              ; (n)
	FDB	CFA_RNUM           ; get cursor position
	FDB	CFA_PLUSSTORE      ; increment cursor position by n
	FDB	CFA_CR             ; $0D
	FDB	CFA_SPACE          ; $20
	FDB	CFA_NUMLEAD        ; (addr column) line start and cursor column
	FDB	CFA_TYPE           ; display leader part
	FDB	CFA_LIT_WORD
	FDB	$0023              ; $23 = '#'
	FDB	CFA_EMIT           ; show cursor symbol
	FDB	CFA_NUMLAG         ; get trailer start addr and length
	FDB	CFA_TYPE           ; (addr n)
	FDB	CFA_NUMLOCATE      ; (column row) get cursor position
	FDB	CFA_DOT            ; print row number
	FDB	CFA_DROP           ; forget column number
	FDB	CFA_HALT           ; pause (or not)
	FDB	CFA_SEMIS
; --------------------------------
NFA_TOP:
	FCB	$80|3
TOP:
	FCB	"TO",('P'|$80)
LFA_TOP:
	FDB	NFA_M
CFA_TOP:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_RNUM
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_T:
	FCB	$80|1
T:
	FCB	('T'|$80)
LFA_T:
	FDB	NFA_TOP
CFA_T:
	FDB	DOCOL
	FDB	CFA_DUP                ; n n
	FDB	CFA_CPERLINE           ; n n 64
	FDB	CFA_MULTIPLY           ; n n*64
	FDB	CFA_RNUM               ; store start position
	FDB	CFA_EXCLAM             ; n
	FDB	CFA_H                  ; copy line n to PAD
	FDB	CFA_ZERO               ; 0
	FDB	CFA_M                  ; Move cursor by 0
	FDB	CFA_SEMIS
; --------------------------------
NFA_L:
	FCB	$80|1
L:
	FCB	('L'|$80)
LFA_L:
	FDB	NFA_T
CFA_L:
	FDB	DOCOL
	FDB	CFA_SCR
	FDB	CFA_GET
	FDB	CFA_LIST
	FDB	CFA_ZERO
	FDB	CFA_M
	FDB	CFA_SEMIS
; --------------------------------
NFA_RPAD:
	FCB	$80|4
RPAD:
	FCB	"RPA",('D'|$80)
LFA_RPAD:
	FDB	NFA_L
CFA_RPAD:
	FDB	DOCOL
	FDB	CFA_PAD
	FDB	CFA_ONEPLUS
	FDB	CFA_SWAP
	FDB	CFA_MMOVE
	FDB	CFA_SEMIS
; --------------------------------
NFA_P:
	FCB	$80|1
P:
	FCB	('P'|$80)
LFA_P:
	FDB	NFA_RPAD
CFA_P:
	FDB	DOCOL
	FDB	CFA_ONE
	FDB	CFA_TEXT
	FDB	CFA_RPAD
	FDB	CFA_SEMIS
; --------------------------------
NFA_IPAD:
	FCB	$80|4
IPAD:
	FCB	"IPA",('D'|$80)
LFA_IPAD:
	FDB	NFA_P
CFA_IPAD:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_S
	FDB	CFA_RPAD
	FDB	CFA_SEMIS
; --------------------------------
NFA_D_L:
	FCB	$80|3
D_L:
	FCB	"D/",('L'|$80)
LFA_D_L:
	FDB	NFA_IPAD
CFA_D_L:                                 ; display screen line by line
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$0010                   ; loop 0...15
	FDB	CFA_SWAP
	FDB	CFA_PARDO               ; (DO)
D_L1:	FDB	CFA_CLS
	FDB	CFA_I
	FDB	CFA_DOT                 ; line number
	FDB	CFA_I
	FDB	CFA_LINE                ; get line
	FDB	CFA_CPERLINE            
	FDB	CFA_TYPE
	FDB	CFA_KEY
	FDB	CFA_LIT_WORD
	FDB	$004E                   ; 'N'ext
	FDB	CFA_EQUAL               ; 'N':1 else: 0
	FDB	CFA_ZEROEQ              ; 'N':0 else: 1 
	FDB	CFA_ZEROBRANCH          ; 
	FDB	D_L2-*                  ; 'N': skip over LEAVE
	FDB	CFA_LEAVE
D_L2:	FDB	CFA_PARLOOP             ; (LOOP)
	FDB	D_L1-*
	FDB	CFA_SEMIS
; --------------------------------
NFA_MATCH:
	FCB	$80|5
MATCH:
	FCB	"MATC",('H'|$80)
LFA_MATCH:
	FDB	NFA_D_L
CFA_MATCH:
	FDB	CFA_SEI
; --------------------------------
NFA_ONELINE:
	FCB	$80|5
ONELINE:
	FCB	"1LIN",('E'|$80)
LFA_ONELINE:
	FDB	NFA_MATCH
CFA_ONELINE:
	FDB	DOCOL           ; : (addr1 ---)
	FDB	CFA_NUMLAG      ; #LAG  addr1 n1
	FDB	CFA_PAD         ; PAD   addr1 n1 addr2
	FDB	CFA_COUNT       ; COUNT addr1 n1 addr3 n2
	FDB	CFA_MATCH       ; MATCH f offset
	FDB	CFA_RNUM        ; R#    addr of R#
	FDB	CFA_PLUSSTORE   ; +!    R# = R#+offset
	FDB	CFA_SEMIS       ; leave f
; --------------------------------
NFA_FIND:
	FCB	$80|4
FIND:
	FCB	"FIN",('D'|$80)
LFA_FIND:
	FDB	NFA_ONELINE
CFA_FIND:
	FDB	DOCOL

FIND1:	FDB	CFA_LIT_WORD
	FDB	$03FF             ; 1023
	FDB	CFA_RNUM          ; R#
	FDB	CFA_GET           ; get cursor position in screen
	FDB	CFA_LT            ; *(R#) < 1023 ?
	FDB	CFA_ZEROBRANCH    ; skip if 0: *(R#) >= 1024
	FDB	FIND2-*
	FDB	CFA_TOP           ; move cursor to start of screen
	FDB	CFA_PAD          
	FDB	CFA_HERE
	FDB	CFA_CPERLINE
	FDB	CFA_ONEPLUS       ; 1 + C/L
	FDB	CFA_CMOVE         ; copy line from PAD to HERE
	FDB	CFA_ZERO          ; 
	FDB	CFA_ERROR         ; 0 ERROR
FIND2:	FDB	CFA_ONELINE       ; leaves 1 if found, otherwise 0
	FDB	CFA_ZEROBRANCH
	FDB	FIND1-*           ; search again
	FDB	CFA_SEMIS
; --------------------------------
NFA_N:
	FCB	$80|1
N:
	FCB	('N'|$80)
LFA_N:
	FDB	NFA_FIND
CFA_N:
	FDB	DOCOL
	FDB	CFA_FIND
	FDB	CFA_ZERO
	FDB	CFA_M
	FDB	CFA_SEMIS
; --------------------------------
NFA_F:
	FCB	$80|1
F:
	FCB	('F'|$80)
LFA_F:
	FDB	NFA_N
CFA_F:
	FDB	DOCOL
	FDB	CFA_ONE               ; 1
	FDB	CFA_TEXT              ; cccc
	FDB	CFA_N                 ; find next occurance
	FDB	CFA_SEMIS
; --------------------------------
NFA_B:
	FCB	$80|1
B:
	FCB	('B'|$80)
LFA_B:
	FDB	NFA_F
CFA_B:
	FDB	DOCOL
	FDB	CFA_PAD
	FDB	CFA_CGET
	FDB	CFA_NEGATE
	FDB	CFA_M
	FDB	CFA_SEMIS
; --------------------------------
NFA_DELETE:
	FCB	$80|6
DELETE:
	FCB	"DELET",('E'|$80)
LFA_DELETE:
	FDB	NFA_B
CFA_DELETE:
	FDB	DOCOL
	FDB	CFA_TOR
	FDB	CFA_NUMLAG
	FDB	CFA_PLUS
	FDB	CFA_R
	FDB	CFA_SUBTRACT
	FDB	CFA_NUMLAG
	FDB	CFA_R
	FDB	CFA_NEGATE
	FDB	CFA_RNUM
	FDB	CFA_PLUSSTORE
	FDB	CFA_NUMLEAD           ; (addr column) line start, cursor column
	FDB	CFA_PLUS
	FDB	CFA_SWAP
	FDB	CFA_CMOVE
	FDB	CFA_FROMR
	FDB	CFA_BLANKS
	FDB	CFA_SEMIS
; --------------------------------
NFA_X:
	FCB	$80|1
X:
	FCB	('X'|$80)
LFA_X:
	FDB	NFA_DELETE
CFA_X:
	FDB	DOCOL
	FDB	CFA_ONE
	FDB	CFA_TEXT
	FDB	CFA_FIND
	FDB	CFA_PAD
	FDB	CFA_CGET
	FDB	CFA_DELETE
	FDB	CFA_ZERO
	FDB	CFA_M
	FDB	CFA_SEMIS
; --------------------------------
NFA_TILL:
	FCB	$80|4
TILL:
	FCB	"TIL",('L'|$80)
LFA_TILL:
	FDB	NFA_X
CFA_TILL:
	FDB	DOCOL
	FDB	CFA_NUMLEAD    ; (addr column) line start, cursor column
	FDB	CFA_PLUS
	FDB	CFA_ONE
	FDB	CFA_TEXT
	FDB	CFA_ONELINE    ; leaves flag 1 or 0
	FDB	CFA_ZEROEQ
	FDB	CFA_ZERO
	FDB	CFA_QUESTERROR
	FDB	CFA_NUMLEAD    ; (addr n)
	FDB	CFA_PLUS
	FDB	CFA_SWAP
	FDB	CFA_SUBTRACT
	FDB	CFA_DELETE
	FDB	CFA_ZERO
	FDB	CFA_M
	FDB	CFA_SEMIS
; --------------------------------
NFA_C:
	FCB	$80|1
C:
	FCB	('C'|$80)
LFA_C:
	FDB	NFA_TILL
CFA_C:
	FDB	DOCOL
	FDB	CFA_ONE
	FDB	CFA_TEXT
	FDB	CFA_PAD
	FDB	CFA_COUNT
	FDB	CFA_NUMLAG
	FDB	CFA_ROT
	FDB	CFA_OVER
	FDB	CFA_MIN
	FDB	CFA_TOR
	FDB	CFA_R
	FDB	CFA_RNUM
	FDB	CFA_PLUSSTORE
	FDB	CFA_R
	FDB	CFA_SUBTRACT
	FDB	CFA_TOR
	FDB	CFA_DUP
	FDB	CFA_HERE
	FDB	CFA_R
	FDB	CFA_CMOVE
	FDB	CFA_HERE
	FDB	CFA_NUMLEAD    ; (addr n)
	FDB	CFA_PLUS
	FDB	CFA_FROMR
	FDB	CFA_CMOVE
	FDB	CFA_FROMR
	FDB	CFA_CMOVE
	FDB	CFA_ZERO
	FDB	CFA_M
	FDB	CFA_SEMIS
; --------------------------------
NFA_VLIST:
	FCB	$80|5
VLIST:
	FCB	"VLIS",('T'|$80)
LFA_VLIST:
	FDB	NFA_C
CFA_VLIST:
	FDB	DOCOL
	FDB	CFA_LIT_WORD

	FDB	$80                  ; 128 to OUT
	FDB	CFA_OUT                ; set character count
	FDB	CFA_EXCLAM             ; force EOL

	FDB	CFA_CONTEXT             ; address of variable CONTEXT
	FDB	CFA_GET                 ; address of first word in chain
	FDB	CFA_GET                 ; 

VLIST1:	FDB	CFA_OUT                 ; are we at EOL?
	FDB	CFA_GET                  ;
	FDB	CFA_CPERLINE            ; C/L
	FDB	CFA_GT                  ;
	FDB	CFA_ZEROBRANCH          ; if not at EOL:
	FDB	VLIST2-*                ;   skip to DUP

	FDB	CFA_CR                  ; new line
	FDB	CFA_ZERO                ; 0 OUT !
	FDB	CFA_OUT                 ;
	FDB	CFA_EXCLAM              ; prepare new line

VLIST2:	FDB	CFA_DUP
	FDB	CFA_IDDOT
	FDB	CFA_SPACE
	FDB	CFA_SPACE
	FDB	CFA_PFA
	FDB	CFA_LFA
	FDB	CFA_GET
	FDB	CFA_DUP
	FDB	CFA_ZEROEQ          ; LFA == 0?
	FDB	CFA_QUESTTERM
	FDB	CFA_OR
	FDB	CFA_ZEROBRANCH
	FDB	VLIST1-*            ; -22 words
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_UDOT:
	FCB	$80|2
UDOT:
	FCB	"U",('.'|$80)
LFA_UDOT:
	FDB	NFA_VLIST
CFA_UDOT:
	FDB	DOCOL
	FDB	CFA_ZERO
	FDB	CFA_DDOT
	FDB	CFA_SEMIS
; --------------------------------
NFA_ULT:
	FCB	$80|2
ULT:
	FCB	"U",('<'|$80)
LFA_ULT:
	FDB	NFA_UDOT
CFA_ULT:
	FDB	DOCOL
	FDB	CFA_TWODUP
	FDB	CFA_XOR
	FDB	CFA_ZEROLT
	FDB	CFA_ZEROBRANCH
	FDB	ULT1-*
	FDB	CFA_DROP
	FDB	CFA_ZEROLT
	FDB	CFA_ZEROEQ
	FDB	CFA_BRANCH
	FDB	ULT2-*
ULT1:	FDB	CFA_SUBTRACT
	FDB	CFA_ZEROLT
ULT2:	FDB	CFA_SEMIS
; --------------------------------
NFA_TWOSTOR:
	FCB	$80|2
TWOSTOR:
	FCB	"2",('!'|$80)
LFA_TWOSTOR:
	FDB	NFA_ULT
CFA_TWOSTOR:
	FDB	*+2
	tsx
	ldx	$00,x
	ins
	ins
	pula
	pulb
	std	$00,x
	inx
	inx
	jmp	L6126
; --------------------------------
NFA_TWOGET:
	FCB	$80|2
TWOGET:
	FCB	"2",('@'|$80)
LFA_TWOGET:
	FDB	NFA_TWOSTOR
CFA_TWOGET:
	FDB	*+2
	tsx
	ldx	$00,x             ; first cell
	ins
	ins
	ldd	$02,x             ; second cell
	pshb
	psha                      ; return first cell
	jmp	NEXT_PSH_REF_X    ; return contents of *(X)
; --------------------------------
NFA_RPGET:
	FCB	$80|3
RPGET:
	FCB	"RP",('@'|$80)
LFA_RPGET:
	FDB	NFA_TWOGET
CFA_RPGET:
	FDB	*+2
	ldd	PTR_RP                 ; return RP
	jmp	NEXT_PSH_D
; --------------------------------
NFA_J:
	FCB	$80|1
J:
	FCB	$CA
LFA_J:
	FDB	NFA_RPGET
CFA_J:
	FDB	*+2
	ldd	PTR_RP
	addd	#$0006    ; get address of J: RP+6
	pshb
	psha
	jmp	L659F
; --------------------------------
NFA_BEEP:
	FCB	$80|4
BEEP:
	FCB	"BEE",('P'|$80)
LFA_BEEP:
	FDB	NFA_J
CFA_BEEP:
	FDB	*+2
	pulb                 ; forget high byte
	pulb                 ; drop duration to (B)
	pula                 ; forget high byte
	pula                 ; drop frequency to (A)
	jsr	ROM_E3F2     ; takes two 8-bit parameters in (A) (B)
	jmp	NEXT 
; --------------------------------
NFA_COPY:
	FCB	$80|4
COPY:
	FCB	"COP",('Y'|$80)
LFA_COPY:
	FDB	NFA_BEEP
CFA_COPY:
	FDB	*+2
	jsr	ROM_E34D     ; 
	jmp	NEXT         ; 
; --------------------------------
NFA_PRINT:
	FCB	$80|5
PRINT:
	FCB	"PRIN",('T'|$80)
LFA_PRINT:
	FDB	NFA_COPY
CFA_PRINT:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	PRNFLAG          ; address of printer flag
	FDB	CFA_CSTOR
	FDB	CFA_SEMIS
; --------------------------------
NFA_FEED:
	FCB	$80|4
FEED:
	FCB	"FEE",('D'|$80)
LFA_FEED:
	FDB	NFA_PRINT
CFA_FEED:
	FDB	*+2
	pulb
	pula
	jsr	ROM_E2A5           ; printer paper feed by value in (D)
	jmp	NEXT
; --------------------------------
NFA_PSET:
	FCB	$80|4
PSET:
	FCB	"PSE",('T'|$80)
LFA_PSET:
	FDB	NFA_FEED
CFA_PSET:
	FDB	*+2
	ldx	#$009C     ; buffer address
	stx	X0050
	pula
	pulb               ; drop Y
	std	$03,x      ; 03-04: Y
	pula
	pulb               ; drop X
	std	$01,x      ; 01-02: X
	pula
	pulb               ; drop Flag
	stab	$05,x      ; 05-06: 1=set/0=clear
	jsr	ROM_D957   ; Basic: PSET
	jmp	NEXT
; data structure for ROM_D957
; $0050 = $009C buffer address
; $009C	= ? XX YY F
;         0 12 34 5
; --------------------------------
NFA_PGET:
	FCB	$80|4
PGET:
	FCB	"PGE",('T'|$80)
LFA_PGET:
	FDB	NFA_PSET
CFA_PGET:
	FDB	*+2
	ldx	#$009C
	stx	X0050
	pula
	pulb
	std	$03,x      ; 03-04: Y
	pula
	pulb
	std	$01,x      ; 01-02: X
	jsr	ROM_D977   ; Basic: PGET
	clra
	ldab	X009D      ; obviously set by PGET to 0 or 1
	jmp	NEXT_PSH_D
; data structure for ROM_D977
; $0050 = $009C buffer address
; $009C	= ? XX YY
;         0 12 34
; return:
; $009C = ? F
; --------------------------------
NFA_PLOT:
	FCB	$80|4
PLOT:
	FCB	"PLO",('T'|$80)
LFA_PLOT:
	FDB	NFA_PGET
CFA_PLOT:
	FDB	*+2
	ldx	#$009C
	stx	X0050
	pula
	pulb
	std	$03,x      ; 03-04: Y
	pula
	pulb
	std	$01,x      ; 01-02: X
	pula
	pulb
	stab	$09,x      ; 09-0A: 
	jsr	ROM_D9D6
	jmp	NEXT
; data structure for ROM_D9D6
; $0050 = $009C buffer address
; $009C	= ? XX YY .    FF
;         0 12 34 56 78 9A
; --------------------------------
NFA_DRAW:
	FCB	$80|4
DRAW:
	FCB	"DRA",('W'|$80)
LFA_DRAW:
	FDB	NFA_PLOT
CFA_DRAW:
	FDB	*+2
	ldx	#$009C
	stx	X0050
	pula
	pulb
	std	$07,x      ; 07-08: Y2
	pula
	pulb
	std	$05,x      ; 05-06: X2
	pula
	pulb
	std	$03,x      ; 03-04: Y1
	pula
	pulb
	std	$01,x      ; 01-02: X1
	pula
	pulb
	stab	$09,x      ; 09-0A: 1=set/0=clear
	jsr	ROM_DA07
	jmp	NEXT
; data structure for ROM_DA07
; $0050 = $009C buffer address
; $009C	= ? X1 Y1 X2 Y2 F
;         0 12 34 56 78 9
; --------------------------------
NFA_MASK:
	FCB	$80|4
MASK:
	FCB	"MAS",('K'|$80)
LFA_MASK:
	FDB	NFA_DRAW
CFA_MASK:
	FDB	COD_USER
	FDB	$0038         ; offset into USER variable area
; --------------------------------
NFA_TRAM:
	FCB	$80|4
TRAM:
	FCB	"TRA",('M'|$80)
LFA_TRAM:
	FDB	NFA_MASK
CFA_TRAM:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$007E
	FDB	CFA_LIT_WORD
	FDB	$80
	FDB	CFA_TOGGLE
	FDB	CFA_SEMIS
; --------------------------------
NFA_PARCLK:
	FCB	$80|5
PARCLK:
	FCB	"(CLK",(')'|$80)
LFA_PARCLK:
	FDB	NFA_TRAM
CFA_PARCLK:
	FDB	*+2
	sei
	ldx	#$00B0          ; address for date/time buffer: B0-B1 = month, B2-B3 = year, B4 = minutes, B5 = seconds
	jsr	ROM_E1FF	; get 6 bytes date/time to B0...B5
	jmp	NEXT
	; date/time buffer with 2 digit BCD numbers: 
	; $B0 = month  $B1 = day      $B2 = year
	; $B3 = hour   $B4 = minutes  $B5 = seconds
; --------------------------------
NFA_TIMEGET:
	FCB	$80|5
TIMEGET:
	FCB	"TIME",('@'|$80)
LFA_TIMEGET:
	FDB	NFA_PARCLK
CFA_TIMEGET:
	FDB	DOCOL
	FDB	CFA_TRAM              ; toggle RAM access
	FDB	CFA_PARCLK            ; (CLK) fills time/date buffer $B0...$B5 
	FDB	CFA_TRAM              ; toggle RAM access
	FDB	CFA_SEMIS
; --------------------------------
NFA_HRS:
	FCB	$80|3
HRS:
	FCB	"HR",('S'|$80)
LFA_HRS:
	FDB	NFA_TIMEGET
CFA_HRS:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$00B3                       ; B3 = hours
	FDB	CFA_CGET
	FDB	CFA_SEMIS
; --------------------------------
NFA_MINS:
	FCB	$80|4
MINS:
	FCB	"MIN",('S'|$80)
LFA_MINS:
	FDB	NFA_HRS
CFA_MINS:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$00B4                        ; B4 = minutes
	FDB	CFA_CGET
	FDB	CFA_SEMIS
; --------------------------------
NFA_SECS:
	FCB	$80|4
SECS:
	FCB	"SEC",('S'|$80)
LFA_SECS:
	FDB	NFA_MINS
CFA_SECS:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$00B5                       ; B5 = seconds
	FDB	CFA_CGET
	FDB	CFA_SEMIS
; --------------------------------
NFA_TIME:
	FCB	$80|4
TIME:
	FCB	"TIM",('E'|$80)
LFA_TIME:
	FDB	NFA_SECS
CFA_TIME:
	FDB	DOCOL
	FDB	CFA_TIMEGET
	FDB	CFA_BASE
	FDB	CFA_GET
	FDB	CFA_HEX
	FDB	CFA_HRS
	FDB	CFA_DOT
	FDB	CFA_LIT_WORD
	FDB	$003A               ; ':'
	FDB	CFA_EMIT
	FDB	CFA_MINS
	FDB	CFA_DOT
	FDB	CFA_LIT_WORD
	FDB	$003A               ; ':'
	FDB	CFA_EMIT
	FDB	CFA_SECS
	FDB	CFA_DOT
	FDB	CFA_BASE
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_DAY:
	FCB	$80|3
DAY:
	FCB	"DA",('Y'|$80)
LFA_DAY:
	FDB	NFA_TIME
CFA_DAY:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$00B1                       ; B1 = day
	FDB	CFA_CGET
	FDB	CFA_SEMIS
; --------------------------------
NFA_MTH:
	FCB	$80|3
MTH:
	FCB	"MT",('H'|$80)
LFA_MTH:
	FDB	NFA_DAY
CFA_MTH:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$00B0                       ; B0 = month in basic work area?
	FDB	CFA_CGET
	FDB	CFA_SEMIS
; --------------------------------
NFA_YR:
	FCB	$80|2
YR:
	FCB	"Y",('R'|$80)
LFA_YR:
	FDB	NFA_MTH
CFA_YR:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$00B2                       ; B2 = year
	FDB	CFA_CGET
	FDB	CFA_SEMIS
; --------------------------------
NFA_DATE:
	FCB	$80|4
DATE:
	FCB	"DAT",('E'|$80)
LFA_DATE:
	FDB	NFA_YR
CFA_DATE:
	FDB	DOCOL
	FDB	CFA_TIMEGET
	FDB	CFA_BASE
	FDB	CFA_GET
	FDB	CFA_HEX
	FDB	CFA_DAY
	FDB	CFA_DOT
	FDB	CFA_LIT_WORD
	FDB	$002E               ; '.'
	FDB	CFA_EMIT
	FDB	CFA_MTH
	FDB	CFA_DOT
	FDB	CFA_LIT_WORD
	FDB	$002E               ; '.'
	FDB	CFA_EMIT
	FDB	CFA_YR
	FDB	CFA_DOT
	FDB	CFA_BASE
	FDB	CFA_EXCLAM
	FDB	CFA_SEMIS
; --------------------------------
NFA_UDP:
	FCB	$80|3
UDP:
	FCB	"UD",('P'|$80)
LFA_UDP:
	FDB	NFA_DATE
CFA_UDP:
	FDB	COD_CONSTANT
	FDB	FNTGPN              ; user defined character
;       end of word
; --------------------------------
NFA_DCHAR:
	FCB	$80|5
DCHAR:
	FCB	"DCHA",('R'|$80)
LFA_DCHAR:
	FDB	NFA_UDP
CFA_DCHAR:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$0007
	FDB	CFA_ROLL
	FDB	CFA_LIT_WORD
	FDB	$00E0               ; 14
	FDB	CFA_SUBTRACT
	FDB	CFA_DUP
	FDB	CFA_ZEROLT          ;
	FDB	CFA_LIT_WORD
	FDB	$0005
	FDB	CFA_QUESTERROR      ; error #5: "Parameter Outside Valid Range"

	FDB	CFA_LIT_WORD
	FDB	$0006
	FDB	CFA_MULTIPLY   ; CHAR# * 6
	FDB	CFA_UDP
	FDB	CFA_GET         ; get address 
	FDB	CFA_PLUS       ; UDP address + 6 * CHAR#
	FDB	CFA_ONE        ;
	FDB	CFA_SUBTRACT   ; - 1 because of 1-based I
	FDB	CFA_DUP        ; start address - 1
	FDB	CFA_LIT_WORD
	FDB	$0006
	FDB	CFA_PLUS       ; end address I = 6 5 4 3 2 1
	FDB	CFA_PARDO
DCHAR1:                        ; copy 6 bytes bottom to top?
	FDB	CFA_I
	FDB	CFA_CSTOR
	FDB	CFA_LIT_WORD
	FDB	$FFFF
	FDB	CFA_PARPLOOP    ; -1 +LOOP
	FDB	DCHAR1-*
	FDB	CFA_SEMIS
; --------------------------------
NFA_LAST:
	FCB	$80|4
LAST:
	FCB	"LAS",('T'|$80)
LFA_LAST:
	FDB	NFA_DCHAR
CFA_LAST:
	FDB	DOCOL
	FDB	CFA_LATEST
	FDB	CFA_IDDOT
	FDB	CFA_SEMIS
; --------------------------------
NFA_HOME:
	FCB	$80|4
HOME:
	FCB	"HOM",('E'|$80)
LFA_HOME:
	FDB	NFA_LAST
CFA_HOME:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	$000B               ; HOME	 CURSOR
	FDB	CFA_EMIT
	FDB	CFA_SEMIS
; --------------------------------
NFA_MTC:
	FCB	$80|3
MTC:
	FCB	"MT",('C'|$80)
LFA_MTC:
	FDB	NFA_HOME
CFA_MTC:
	FDB	DOCOL                  ; (col row ---)
	FDB	CFA_HOME
	FDB	CFA_MINUSDUP           ; col row row or, if row==0, col row
	FDB	CFA_ZEROBRANCH
	FDB	MTC2-*

	FDB	CFA_ZERO               ; col row 0
	FDB	CFA_PARDO              ; move to row
MTC1:	FDB	CFA_LIT_WORD
	FDB	$001F                  ; cursor down
	FDB	CFA_EMIT
	FDB	CFA_PARLOOP
	FDB	MTC1-*

MTC2:	FDB	CFA_MINUSDUP           ; col col or if col==0, col
	FDB	CFA_ZEROBRANCH
	FDB	$0010

	FDB	CFA_ZERO
	FDB	CFA_PARDO              ; move to column
MTC3:	FDB	CFA_LIT_WORD
	FDB	$001C                  ; cursor right
	FDB	CFA_EMIT
	FDB	CFA_PARLOOP
	FDB	MTC3-*
	FDB	CFA_SEMIS
; --------------------------------
NFA_MCASS:
	FCB	$80|5
MCASS:
	FCB	"MCAS",('S'|$80)
LFA_MCASS:
	FDB	NFA_MTC
CFA_MCASS:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	'M'                    ; 'M'icro cassette
	FDB	CFA_LIT_WORD
	FDB	X0060
	FDB	CFA_CSTOR
	FDB	CFA_SEMIS
; --------------------------------
NFA_TAPCNT:
	FCB	$80|6
TAPCNT:
	FCB	"TAPCN",('T'|$80)
LFA_TAPCNT:
	FDB	NFA_MCASS
CFA_TAPCNT:
	FDB	*+2
	pula
	pula
	tsta
	beq	TAPCNT_STORE        ; if zero: retrieve tape counter
	pulx
	stx	TAPE_CNT            ; store
TAPCNT_DONE:
	jmp	NEXT
;
TAPCNT_STORE:
	ldx	TAPE_CNT            ; retrieve
	bmi	TAPCNT_NEGATIVE               
	pshx                        ; leave tape count
	bra	TAPCNT_DONE
;
TAPCNT_NEGATIVE:
	ldd	#$1202              ; ???? 
	jsr	ROM_E3F2
	bra	TAPCNT_DONE
; --------------------------------
NFA_SEEK:
	FCB	$80|4
SEEK:
	FCB	"SEE",('K'|$80)
LFA_SEEK:
	FDB	NFA_TAPCNT
CFA_SEEK:
	FDB	*+2
	pulx
	jsr	ROM_EB8F
	jmp	NEXT
; --------------------------------
NFA_WIND:
	FCB	$80|4
WIND:
	FCB	"WIN",('D'|$80)
LFA_WIND:
	FDB	NFA_SEEK
CFA_WIND:
	FDB	DOCOL
	FDB	CFA_LIT_WORD
	FDB	TAPE_CNT
	FDB	CFA_GET
	FDB	CFA_PLUS
	FDB	CFA_SEEK
	FDB	CFA_SEMIS
;
	if INCLUDE_FLUFF == 1
CPY_DSPVEC:
	ldaa	#$7E           ; this is the jmp opcode
	ldx	#XDFF1         ; routine DFF1: display one character on screen
	staa	SYS_OUT_CHR    ; copy jmp instruction ...
	stx	SYS_OUT_CHR+1  ; and function address

	lds	#$04BF         ; load (SP) with $04BF for copy operation
	jmp	CPY_NEXT_4
	endif
; --------------------------------
NFA_MOD:
	FCB	$80|3
MOD:
	FCB	"MO",('D'|$80)
LFA_MOD:
	FDB	NFA_WIND
CFA_MOD:
	FDB	DOCOL
	FDB	CFA_DIVMOD
	FDB	CFA_DROP
	FDB	CFA_SEMIS
; --------------------------------
NFA_TWOMUL:
	FCB	$80|2
TWOMUL:
	FCB	"2",('*'|$80)
LFA_TWOMUL:
	FDB	NFA_MOD
CFA_TWOMUL:
	FDB	DOCOL
	FDB	CFA_DUP
	FDB	CFA_PLUS           ; n + n = 2*n
	FDB	CFA_SEMIS
; --------------------------------
	if MH_EXTENSIONS == 0
CFA_EDITOOL:	                   ; used only once
	FDB	DOCOL
	FDB	CFA_DUP            ; copy line
	FDB	CFA_H              ; to PAD
	FDB	CFA_SEMIS
; --------------------------------
	endif
CFA_SEI:
	sei                        ; set interrupt mask
	jmp	L608C
; --------------------------------
CFA_CLI:
	cli                        ; clear interrupt mask
	jmp	NEXT_PSH_D         ; push (B)(A) and NEXT
; --------------------------------
	if MH_EXTENSIONS == 1
; Prepend new words to the head of the dictionary.
;
; SHIFT
; (n1 b --- n2) Leave n1 binary shifted by b bits. 
;               b can be in +/-[0...15].
;
; Machine language implementation takes $25 = 37d bytes
;
NFA_SHIFT:
	FCB	$80|5              ; $80 | length of name
SHIFT:
	FCB	"SHIF",('T'|$80)   ; 5 characters long
LFA_SHIFT:
	FDB	NFA_TWOMUL
CFA_SHIFT:
	FDB	*+2                ; machine code word
	; drop shift count into (A)(B)
	pula                       ; high byte
	pulb                       ; low byte
	; we ignore the high byte (shift count < 16)
	tstb                       ; set Z(ero) and N(egative)

	; case 1: shift count is zero
	beq	SHIFT_DONE	   ; Z is set: -> no shift, leave 2nd word on stack

;       we do it on the stack
	tsx                        ; get address of word (SP) to (X)
	; if shift count is negative then LSHIFT else RSHIFT
	bmi	LSHIFT	           ; low byte is negative -> left shift

	; case 2: shift count is positive
RSHIFT:
	lsr	$00,x              ; shift high byte -> carry
	ror 	$01,x              ; carry -> shift low byte
	decb                       ; decrement (A)
	bne	RSHIFT             ; loop until (A)=0
	bra	SHIFT_DONE         ; jmp NEXT would save 4 machine cycles
		                   ; but take 1 additional byte - whoa!

	; case 3: shift count is negative
LSHIFT:
	asl 	$01,x              ; carry <- shift low byte
	rol	$00,x              ; shift high byte <- carry
	incb                       ; increment (A)
	bne	LSHIFT             ; loop until (A)=0

SHIFT_DONE:
	jmp	NEXT               ; done, rsult is still on the stack
; --------------------------------
;
; BCDBIN
; (n1 --- n2) Convert the two-digit BCD number n1 to binary n2. 
;
NFA_BCDBIN:
	FCB	$80|6              ; $80 | length of name
BCDBIN:
	FCB	"BCDBI",('N'|$80)  ; 6 characters long
LFA_BCDBIN:
	FDB	NFA_SHIFT
CFA_BCDBIN:
	FDB	*+2                ; machine code word

	; drop BCD number $00HL into (A)(B)
	pula                       ; high byte (unused)
	pulb                       ; low byte
	pshb                       ; save for the low nibble

	andb   #$F0                ; mask H nibble

	; 10*H/16 = 5*H/8 = 4*H/8 + 1*H/8 = H/2 + H/8
	lsrb                       ; H/2
	tba                        ; save H/2 in (A)
	lsrb                       ; H/4
	lsrb                       ; H/8
	aba                        ; (A) = H/2 + H/8 == high nibble in binary

	pulb                       ; get L nibble
	andb   #$0F                ; mask lower nibble
	aba                        ; and add it to high nibble in (A)

;---
	tab	                   ; (A) to (B)
	clra	                   ; clear (A)
	jmp	NEXT_PSH_D         ; push D and then NEXT
; --------------------------------
; SECONDS
; (--- ud) Return the current time in seconds since midnight. 
;
NFA_SECONDS:
	FCB	$80|7              ; $80 | length of name
SECONDS:
	FCB	"SECOND",('S'|$80)  ; 7 characters long
LFA_SECONDS:
	FDB	NFA_BCDBIN
CFA_SECONDS:
	FDB	DOCOL
	FDB	CFA_TIMEGET
	FDB	CFA_HRS
	FDB	CFA_BCDBIN         ; BCD to DECIMAL
	FDB	CFA_LIT_WORD
	FDB	3600               ; seconds per hour
	FDB	CFA_UMUL           ; leaves unsigned double

	FDB	CFA_MINS
	FDB	CFA_BCDBIN         ; BCD to DECIMAL
	FDB	CFA_LIT_WORD
	FDB	60                 ; seconds per minute
	FDB	CFA_UMUL           ; leaves unsigned double
	FDB	CFA_DPLUS          

	FDB	CFA_SECS
	FDB	CFA_BCDBIN         ; BCD to DECIMAL
	FDB	CFA_STOD           ; expand to double
	FDB	CFA_DPLUS          ; leaves double

	FDB	CFA_SEMIS
; --------------------------------
; (c ---) RSPUT
; Output one character to the RS-232C interface
NFA_RSPUT:
	FCB	$80|5              ; $80 | length of name
RSPUT:
	FCB	"RSPU",('T'|$80)   ; 5 characters long
LFA_RSPUT:
	FDB	NFA_SECONDS
CFA_RSPUT:
	FDB	*+2                ; machine code word
	; drop character to (A)
	pula                       ; high byte (unused)
	pula                       ; character
	jsr	SYS_RSPUT
	jmp	NEXT               ; done
; --------------------------------
; (c ---) RSGET
; Read one character from the RS-232C interface
NFA_RSGET:
	FCB	$80|5              ; $80 | length of name
RSGET:
	FCB	"RSGE",('T'|$80)   ; 5 characters long
LFA_RSGET:
	FDB	NFA_RSPUT
CFA_RSGET:
	FDB	*+2                ; machine code word

	clrb	                   ; clear low byte for false
	ldx	SYS_RSCOUNT        ; get 16-bit count from address
	beq	NO_CHAR            ; if (A) is empty, then return false

	jsr	SYS_RSGET          ; get byte to (A)
; initial solution
;	tab	                   ; copy to low byte (B)
;	clra	                   ; clear high byte
;	pshb	                   ; low byte goes first
;	psha	                   ; high byte next
;	ldab	#$01               ; set flag=true
; 2 bytes shorter:
	clrb	                   ; (B) = 0
	psha	                   ; low byte first
	pshb	                   ; high byte
	incb	                   ; set flag = true
NO_CHAR:
	clra	                   ; clear high byte
	jmp	NEXT_PSH_D         ; return flag 0/1
; --------------------------------
; (f ---) RSPWR
; Switch the RS-232C interface ON (f=1) or OFF (f=0)
; if ON: set 4800 baud, 8 data bits, no parity and no handshake
NFA_RSPOWER:
	FCB	$80|5              ; $80 | length of name
RSPOWER:
	FCB	"RSPW",('R'|$80)   ; 5 characters long
LFA_RSPOWER:
	FDB	NFA_RSGET
CFA_RSPOWER:
	FDB	*+2                ; machine code word

	; 1) set the mode, even if we close the port, saves bytes

	; Basic: COM0:(68N1D)      4800,8,N,1
	ldd	#$B568             ; (A)(B)
	;   A = $B5 = 10.1101.01   ; 1 stop bit, no parity 
	;   B = $68 = 0110.1000    ; 8 bits, 4800 baud 

	; Not implemented to conserve ROM space:
	; Algorithm for determining baud rate number:
	; shift the baud rate left until the C bit is set
	; decimal = binary word       - baud rate #
	;     110 = 00000000.01101110 - 0
	;     150 = 00000000.10010110 - 1
	;     300 = 00000001.00101100 - 2
	;     600 = 00000010.01011000 - 3
	;    1200 = 00000100.10110000 - 4
	;    2400 = 00001001.01100000 - 5
	;    4800 = 00010010.11000000 - 6 <<<
	;    9600 = 00100101.10000000 - 7
	;
	; ldd	#baud
	; ldx	#$00A0	; initial count nibble = $A
	: do:
	; dex
	; asl	b	; low
	; lsl	a	; high
	; bcc	do	; loop
	; x-hi now has count 0...7
	; stx	XM	; hi-lo
	; lda	#$B5
	; ldb	XM+1	; e.g. $60 for 4800 baud
	; orab	#$08	; bit width
	;

	jsr	SYS_RSMODE         ; (A),(B),(X) retained

	; 2) close the port in any case to save bytes
	jsr	SYS_RSCLOSE        ; (B) (X) retained

	; finally drop FLAG to (A)
	pula	                   ; high byte (unused)
	pula	                   ; low byte is 0 or 1

	jsr	SYS_RSPOWER        ; (B) (X) retained, Z<-(A)
	beq	RS232_DON          ; (Z)=f=0 : power off ?

	; 3) we just powered on, open with buffer
	ldd	#255               ; 255 bytes (could be 260)
	ldx	#SYS_CASBUF        ; $0378 == $FFDC @
;	alternative: use MONITOR data area $02D8-$0357
;	ldd	#128               ; 128 bytes
;	ldx	#$2D8              ; $02D8
	jsr	SYS_RSOPEN         ; 

RS232_DON:
	jmp	NEXT               ; done
; --------------------------------
; (---) ASCII
; Leave the ASCII code for the following character. 
; Used outside of a definition in the form ASCII c.
; ASCII A leaves 65.
;
NFA_ASCII:
	FCB	$80|5              ; cannot be used in definitions, see [ASCII]
ASCII:
	FCB	"ASCI",('I'|$80)
LFA_ASCII:
	FDB	NFA_RSPOWER
CFA_ASCII:
	FDB	DOCOL
	FDB	CFA_BL                ; ' '  terminator
	FDB	CFA_WORD              ; WORD read a word until ' ' to HERE
	FDB	CFA_HERE              ; HERE get address
	FDB	CFA_ONEPLUS           ; 1+   skip length byte
	FDB	CFA_CGET              ; C@   get character code to stack
	FDB	CFA_SEMIS
; --------------------------------
NFA_BRACKETASCII:
; (---) [ASCII]
; Compile the ASCII code for the following character. 
; Used inside a definition in the form [ASCII] c.
; [ASCII] A compiles 65 into the current dictionary position.
;
	FCB	$80|$40|7             ; immediate, can be used in definitions
BRACKETASCII:
	FCB	"[ASCII",(']'|$80)
LFA_BRACKETASCII:
	FDB	NFA_ASCII
CFA_BRACKETASCII:
	FDB	DOCOL
	FDB	CFA_ASCII             ; immediately get ASCII code to stack
	FDB	CFA_LITERAL           ; and compile LITERAL_WORD followed by ASCII code
	FDB	CFA_SEMIS
; --------------------------------
; (--- n)
; Return the depth of the computational stack in cells.
;
NFA_DEPTH:
	FCB	$80|5                 ; (--- n)
DEPTH:
	FCB	"DEPT",('H'|$80)
LFA_DEPTH:
	FDB	NFA_BRACKETASCII
CFA_DEPTH:
	FDB	*+2
	ldd	ADDR_SP0      ; get initial SP0
	
	tsx                   ; transfer (SP) to (X)
	stx	X0080         ; save (SP) temporarily in $80-$81
;	subb    X0081         ; low byte -> carry
;	sbca	X0080         ; high byte with carry
;	hey, we have a 6301 and dont need to do two operations with carry!
	subd	X0080         ; $06FE - (SP) -> (D)
		              ; divide by two for result in cells
	lsra                  ; 0 -> high byte -> Carry
	rorb	              ; Carry -> low byte
	jmp	NEXT_PSH_D    ; return contents of (D)
; --------------------------------
NFA_TWODIV:
	FCB	$80|2
TWODIV:
	FCB	"2",('/'|$80)
LFA_TWODIV:
	FDB	NFA_DEPTH
CFA_TWODIV:
	FDB	*+2
	tsx	                ; SP to X
	clc
	ldaa	0,x             ; get high byte
	bpl	DIVSHIFT        ; positive number: just shift with carry clear
	inc	1,x             ; negative number: increment low byte
	bne	NOINC           ; low byte is not zero
	inc	0,x             ; else: carry: increment high byte
NOINC:                          
	beq	DIVSHIFT        ; high byte became zero
	sec	                ; set carry
DIVSHIFT:                           
	ror	0,x             ; carry -> high byte >> 1 -> carry
	ror	1,x             ; carry -> low byte  >> 1
	jmp	NEXT

; --------------------------------

	endif

TRAILER:
	if INCLUDE_TRAILER == 1

	; ???? unused bytes ????
	FCB	$32
	FCB	$D4
	FCB	$B8
	FCB	$4C
	FCB	$18
	FCB	$6E
	FCB	$82
	FCB	$39
	FCB	$48
	FCB	$13
	FCB	$E8
	FCB	$90
	FCB	$0E
	FCB	$6C
	FCB	$C0
	FCB	$1D
	FCB	$CA
	FCB	$6C
	FCB	$6E
	FCB	$3E
	FCB	$06
	FCB	$E6
	FCB	$BE
	FCB	$CC
	FCB	$BE
	FCB	$DF
	FCB	$2B
	FCB	$1F
	FCB	$8E
	FCB	$B5
	FCB	$09
	FCB	$6B
	FCB	$52
	FCB	$C0
	FCB	$5A
	FCB	$C1
	FCB	$2E
	FCB	$DF
	FCB	$E3
	FCB	$8D
	FCB	$9C
	FCB	$51
	FCB	$05
	FCB	$78
	FCB	$36
	FCB	$1F
	FCB	$B3
	FCB	$09
	FCB	$3A
	FCB	$4A
	FCB	$4E
	FCB	$3C
	FCB	$18
	FCB	$1C
	FCB	$74
	FCB	$39
	FCB	$4C
	FCB	$67
	FCB	$CF
	FCB	$D2
	FCB	$4D
	FCB	$91
	FCB	$22
	FCB	$31
	FCB	$86
	FCB	$E6
	FCB	$03
	FCB	$FE
	FCB	$10
	FCB	$3C
	FCB	$36
	FCB	$8D
	FCB	$5F
	FCB	$3C
	FCB	$0F
	FCB	$6B
	FCB	$CD
	FCB	$F8
	FCB	$A4
	FCB	$B9
	FCB	$D3
	FCB	$1F
	FCB	$3A
	FCB	$9F
	FCB	$EB
	FCB	$47
	FCB	$36
	FCB	$A7
	FCB	$88
	FCB	$14
	FCB	$E8
	FCB	$DA
	FCB	$1D
	FCB	$BB
	FCB	$2E
	FCB	$4A
	FCB	$95
	FCB	$FC
	FCB	$92
	FCB	$57
	FCB	$6D
	FCB	$09
	FCB	$65
	FCB	$0D
	FCB	$3A
	FCB	$F0
	FCB	$4A
	FCB	$39
	FCB	$39
	FCB	$22
	FCB	$83
	FCB	$60
	FCB	$87
	FCB	$97
	FCB	$E7
	FCB	$36
	FCB	$4C
	FCB	$CB
	FCB	$0F
	FCB	$EE
	FCB	$74
	FCB	$56
	FCB	$E5
	FCB	$AB
	FCB	$7E
	FCB	$62
	FCB	$A3
	FCB	$46
	FCB	$83
	FCB	$BF
	FCB	$CF
	FCB	$04
	FCB	$01
	FCB	$CB
	FCB	$0A
	FCB	$20
	FCB	$22
	FCB	$7B
	FCB	$34
	FCB	$0C
	FCB	$EF
	FCB	$37
	FCB	$47
	FCB	$E3
	FCB	$86
	FCB	$D2
	FCB	$88
	FCB	$E1
	FCB	$9F
	FCB	$0B
	FCB	$F2
	FCB	$83
	FCB	$DD
	FCB	$9F
	FCB	$6D
	FCB	$28
	FCB	$31
	FCB	$5E
	FCB	$C7
	FCB	$69
	FCB	$15
	FCB	$9F
	FCB	$28
	FCB	$84
	FCB	$03
	FCB	$9B
	FCB	$42
	FCB	$F6
	FCB	$CF
	FCB	$48
	FCB	$1A
	FCB	$FC
	FCB	$E6
	FCB	$CA
	FCB	$0C
	FCB	$0F
	FCB	$A7
	FCB	$41
	FCB	$8A
	FCB	$54
	FCB	$EA
	FCB	$07
	FCB	$64
	FCB	$65
	FCB	$22
	FCB	$6A
	FCB	$85
	FCB	$04
	FCB	$53
	FCB	$0F
	FCB	$31
	FCB	$56
	FCB	$58
	FCB	$37
	FCB	$EE
	FCB	$0A
	FCB	$EB
	FCB	$F9
	FCB	$44
	FCB	$7A
	FCB	$9D
	FCB	$2C
	FCB	$9A
	FCB	$AA
	FCB	$F1
	FCB	$A0
	FCB	$46
	FCB	$3F
	FCB	$CB
	FCB	$21
	FCB	$D3
	FCB	$EB
	FCB	$18
	FCB	$90
	FCB	$60
	FCB	$41
	FCB	$6B
	FCB	$CB
	FCB	$85
	FCB	$47
	FCB	$F1
	FCB	$49
	FCB	$11
	FCB	$7D
	FCB	$C9
	FCB	$BC
	FCB	$C9
	FCB	$C3
	FCB	$50
	FCB	$2B
	FCB	$94
	FCB	$25
	FCB	$8B
	FCB	$DA
	FCB	$5A
	FCB	$8A
	FCB	$B5
	FCB	$F3
	FCB	$44
	FCB	$88
	FCB	$EE
	FCB	$EF
	FCB	$17
	FCB	$C1
	FCB	$81
	FCB	$A6
	FCB	$2A
	FCB	$39
	FCB	$DC
	FCB	$C3

	else

	org $8000-24
	if (ROM_CD & V10) == V10
	FCB	"C10/"
	else
	FCB	"C11/"
	endif

	org $8000-20
	if (ROM_EF & EUROPE) == EUROPE
	if (ROM_EF & V10) == V10
	FCB	"E10E/"
	else
	FCB	"E11E/"
	endif
	else
	if (ROM_EF & V10) == V10
	FCB	"E10J/"
	else
	FCB	"E11J/"
	endif
	endif
	if MH_EXTENSIONS == 1
	org $8000-15
	FCB	"2022-M.Hepperle"
	else
	org $7FFF
	FCB	$00
	endif

	endif

; ******************************************************+
; ********************* End Of File *********************
; ******************************************************+