; HCCS Forth Option ROM Disassembly
; ================================
;
; ROM:       8KB option ROM at $6000-$7FFF
; CPU:       HD6303R (Hitachi 6301/6303 family)
; System:    Epson HX-20 portable computer
; Author:    J.W. Brown / HCCS Associates
; Copyright: (C) 1982
; Type:      FIG-Forth implementation
;
; This is a FIG-Forth (Forth Interest Group) implementation for the
; Epson HX-20, provided as a plug-in option ROM. It implements the
; standard FIG-Forth model with extensions for the HX-20's hardware:
; LCD display, printer, graphics, real-time clock, and cassette I/O.
;
; ================================================================
; ARCHITECTURE
; ================================================================
;
; Register Conventions:
;   IP  ($0092)     Instruction Pointer — points to next thread address
;   W   ($0090)     Word pointer — CFA of currently executing word
;   PSP ($0084)     Parameter stack pointer (grows downward in RAM)
;   RP  ($0094)     Return stack pointer (grows downward in RAM)
;   UP  ($0086)     User area pointer
;   S register      Used as return stack pointer (hardware stack)
;   X register      General work register / W during NEXT
;
; Inner Interpreter:
;   PUSHD ($612E)   Push D to parameter stack (PSHB;PSHA), then fall through to NEXT
;   NEXT  ($6130)   Fetch next thread cell via IP, look up CFA, jump to code
;   NEXT_INX ($6132) Mid-NEXT entry (used by DOCOL, ;S: X already loaded)
;   CLIT  ($6152)   Character literal — read 1 byte from thread, push as 16-bit
;   DOCOL ($65F2)   Enter colon definition: push IP to return stack
;   SEMI_S ($659D)  Exit colon definition: pop IP from return stack
;   DOCON ($6628)   Push constant value from PFA
;   DOUSE ($6655)   Push user variable address (UP + offset)
;   DODOES ($6AA1)  DOES> runtime: push PFA, enter defining word's thread
;
; Memory Map:
;   $0060-$007F     Forth workspace (scratch variables)
;   $0080-$0095     Forth virtual registers (IP, W, PSP, UP, RP)
;   $0096-$00FF     Available RAM
;   $0100-$04BF     Parameter stack area (grows down from $04BF)
;   $04C0-$06FF     Return stack + user area + buffers
;   $6000-$7FFF     This option ROM
;
; Dictionary Structure:
;   Each word has: NFA (name field) → LFA (link field) → CFA (code field) → PFA
;   NFA: [count|flags] [name chars, MSB set on last]
;     count bits: 7=always 1, 6=immediate, 5=smudge, 4-0=length
;   LFA: 2-byte pointer to previous word's NFA (0000 = end of chain)
;   CFA: 2-byte pointer to machine code that implements the word
;   PFA: parameter data (machine code, thread, constant value, etc.)
;
; Word Types:
;   PRIMITIVE   CFA → own PFA (machine code follows)
;   COLON       CFA → DOCOL ($65F2), PFA = list of CFA addresses (thread)
;   CONSTANT    CFA → DOCON ($6628), PFA = 16-bit value
;   USER        CFA → DOUSE ($6655), PFA = offset into user area
;   DOES>       CFA → DODOES ($6AA1), PFA = data for creating word
;
; Thread Decompilation:
;   For COLON definitions, comments show the word names referenced
;   by each thread cell, e.g.:
;     FDB  forth_DUP_CFA    ;xxxx: .. ..   ; DUP
;
; ================================================================
; EXTERNAL ROM CALLS (HX-20 Main ROM v1.0)
; ================================================================
;   $0C10  Read keyboard character
;   $D715  Print string (X=addr, B=length)
;   $D735  Print string with newline
;   $E2EF  Sound beep
;   $E3F2  Sound beep (alternate entry)
;   $EB8F  Print character in A
;   $FEDA  Get character (with echo)
;   $FEDD  Get character (no echo)
;   $FEE0  Put character
;   $FF9A  Serial I/O
;
; ================================================================


; f9dasm: M6800/1/2/3/8/9 / H6309 Binary/OS9/FLEX9 Disassembler V1.83
; Loaded binary file ../../Forth_HCCS.rom

;****************************************************
;* Used Labels                                      *
;****************************************************

M0001   EQU     $0001
M0004   EQU     $0004
M0006   EQU     $0006
M0008   EQU     $0008
M0050   EQU     $0050
M0060   EQU     $0060
M0061   EQU     $0061
Z0064   EQU     $0064
M006A   EQU     $006A
forth_IP_hi EQU     $0080
forth_IP_lo EQU     $0081
forth_W_hi EQU     $0082
forth_PSP_hi EQU     $0084
forth_UP_hi EQU     $0086
forth_tmp1 EQU     $0088
forth_char_buf EQU     $008A
forth_char_flag EQU     $008B
forth_W EQU     $0090
forth_IP EQU     $0092
forth_RP EQU     $0094
M0096   EQU     $0096
M0098   EQU     $0098
M009C   EQU     $009C
M009D   EQU     $009D
M00B0   EQU     $00B0
M016D   EQU     $016D
M0203   EQU     $0203
M02A4   EQU     $02A4
M02BB   EQU     $02BB
M04BF   EQU     $04BF
M04C0   EQU     $04C0
M04C2   EQU     $04C2
M04C4   EQU     $04C4
M04E8   EQU     $04E8
M04E9   EQU     $04E9
M0C0F   EQU     $0C0F
rom_read_key EQU     $0C10
M1202   EQU     $1202
M4F4B   EQU     $4F4B
M8448   EQU     $8448
M9A81   EQU     $9A81
ZD310   EQU     $D310
CIRQVEC EQU     $D3EB
rom_print_string EQU     $D715
rom_print_string_nl EQU     $D735
ZD957   EQU     $D957
ZD977   EQU     $D977
ZD9D6   EQU     $D9D6
ZDA07   EQU     $DA07
ZE1FF   EQU     $E1FF
ZE2A5   EQU     $E2A5
rom_beep EQU     $E2EF
ZE34D   EQU     $E34D
rom_beep_2 EQU     $E3F2
rom_print_char EQU     $EB8F
ZFED7   EQU     $FED7
rom_get_char EQU     $FEDA
rom_get_char_noecho EQU     $FEDD
rom_put_char EQU     $FEE0
ZFF4F   EQU     $FF4F
rom_serial_io EQU     $FF9A

;****************************************************
;* Program Code / Data Areas                        *
;****************************************************

        ORG     $6000


; ================================================================
; Option ROM Header
; ================================================================
opt_rom_header FCB     $BA                      ;6000: BA             '.'
        FCC     "A"                      ;6001: 41             'A'
        FCB     $FF,$FF                  ;6002: FF FF          '..'
        FCC     "`"                      ;6004: 60             '`'
        FCB     $0C                      ;6005: 0C             '.'
        FCC     "FORTH"                  ;6006: 46 4F 52 54 48 'FORTH'
        FCB     $00                      ;600B: 00             '.'

; ================================================================
; Entry Points (cold start / warm start)
; ================================================================
forth_cold_entry NOP                              ;600C: 01             '.'
        JMP     Z70E7                    ;600D: 7E 70 E7       '~p.'
forth_warm_entry NOP                              ;6010: 01             '.'
        JMP     Z70B5                    ;6011: 7E 70 B5       '~p.'

; ================================================================
; User Area Initial Values Table
; S0, R0, TIB, WIDTH, WARNING, FENCE, DP, VOC-LINK,
; FIRST, LIMIT, and compilation state defaults
; ================================================================
user_init_table FDB     $6301,$0100              ;6014: 63 01 01 00    'c...'
        FDB     forth_2_STAR_NFA,M0008   ;6018: 7E E9 00 08    '~...'
M601C   FDB     $04B0                    ;601C: 04 B0          '..'
M601E   FDB     $06FE                    ;601E: 06 FE          '..'
M6020   FDB     $05FE,$0500,$001F,$0000  ;6020: 05 FE 05 00 00 1F 00 00 '........'
M6028   FDB     $1000                    ;6028: 10 00          '..'
M602A   FDB     $1000                    ;602A: 10 00          '..'
M602C   FDB     $0D0E,$0040              ;602C: 0D 0E 00 40    '...@'
M6030   FDB     $007F,$0000              ;6030: 00 7F 00 00    '....'

; ================================================================
; Forth System Init / I/O Routines
; Machine code for terminal I/O, key handling, and init
; ================================================================
        EIM     #$F2,$05,S               ;6034: 65 F2 65       'e.e'
        JSR     Z0064                    ;6037: 9D 64          '.d'
        LDAB    #$64                     ;6039: C6 64          '.d'
        LSRA                             ;603B: 44             'D'
Z603C   LDAA    #$0A                     ;603C: 86 0A          '..'
        BSR     Z6048                    ;603E: 8D 08          '..'
        LDAA    #$0D                     ;6040: 86 0D          '..'
        BSR     Z6048                    ;6042: 8D 04          '..'
        RTS                              ;6044: 39             '9'
Z6045   ANDA    M04E9                    ;6045: B4 04 E9       '...'
Z6048   JSR     Z6106                    ;6048: BD 61 06       '.a.'
        RTS                              ;604B: 39             '9'
        FCB     $00                      ;604C: 00             '.'
Z604D   LDAB    M0060                    ;604D: D6 60          '.`'
        CLRA                             ;604F: 4F             'O'
        LDX     #M02A4                   ;6050: CE 02 A4       '...'
        TST     >M0061                   ;6053: 7D 00 61       '}.a'
        BEQ     Z605D                    ;6056: 27 05          ''.'
        JSR     rom_get_char             ;6058: BD FE DA       '...'
        BRA     Z6060                    ;605B: 20 03          ' .'
Z605D   JSR     rom_put_char             ;605D: BD FE E0       '...'
Z6060   STAA    M006A                    ;6060: 97 6A          '.j'
        BNE     Z6081                    ;6062: 26 1D          '&.'
        BCS     Z6081                    ;6064: 25 1B          '%.'
        LDAB    M0060                    ;6066: D6 60          '.`'
        TST     >M0061                   ;6068: 7D 00 61       '}.a'
        BEQ     Z6075                    ;606B: 27 08          ''.'
        LDX     M02BB                    ;606D: FE 02 BB       '...'
        JSR     ZFED7                    ;6070: BD FE D7       '...'
        BRA     Z6078                    ;6073: 20 03          ' .'
Z6075   JSR     rom_get_char_noecho      ;6075: BD FE DD       '...'
Z6078   STAA    M006A                    ;6078: 97 6A          '.j'
        BNE     Z6081                    ;607A: 26 05          '&.'
        BCS     Z6081                    ;607C: 25 03          '%.'
        JMP     NEXT                     ;607E: 7E 61 30       '~a0'
Z6081   LDX     #rom_print_string_nl     ;6081: CE D7 35       '..5'
        LDAB    #$05                     ;6084: C6 05          '..'
        JSR     rom_print_string         ;6086: BD D7 15       '...'
        JMP     Z70AF                    ;6089: 7E 70 AF       '~p.'
        LDX     #forth_IP_hi             ;608C: CE 00 80       '...'
        LDAB    #$08                     ;608F: C6 08          '..'
Z6091   PULA                             ;6091: 32             '2'
        STAA    ,X                       ;6092: A7 00          '..'
        INX                              ;6094: 08             '.'
        DECB                             ;6095: 5A             'Z'
        BNE     Z6091                    ;6096: 26 F9          '&.'
        STS     forth_tmp1               ;6098: 9F 88          '..'
        LDS     forth_UP_hi              ;609A: 9E 86          '..'
        DES                              ;609C: 34             '4'
        LDD     forth_PSP_hi             ;609D: DC 84          '..'
        ADDD    forth_UP_hi              ;609F: D3 86          '..'
        STD     forth_PSP_hi             ;60A1: DD 84          '..'
Z60A3   LDX     forth_W_hi               ;60A3: DE 82          '..'
        DEX                              ;60A5: 09             '.'
        LDAB    #$FF                     ;60A6: C6 FF          '..'
Z60A8   INCB                             ;60A8: 5C             '\'
        INX                              ;60A9: 08             '.'
        CMPB    forth_IP_lo              ;60AA: D1 81          '..'
        BCC     Z60C3                    ;60AC: 24 15          '$.'
        PULA                             ;60AE: 32             '2'
        CMPA    ,X                       ;60AF: A1 00          '..'
        BEQ     Z60A8                    ;60B1: 27 F5          ''.'
        TSX                              ;60B3: 30             '0'
        CPX     forth_PSP_hi             ;60B4: 9C 84          '..'
        BCC     Z60BA                    ;60B6: 24 02          '$.'
        BRA     Z60A3                    ;60B8: 20 E9          ' .'
Z60BA   LDS     forth_tmp1               ;60BA: 9E 88          '..'
        CLRA                             ;60BC: 4F             'O'
        PSHA                             ;60BD: 36             '6'
        PSHA                             ;60BE: 36             '6'
        STX     forth_PSP_hi             ;60BF: DF 84          '..'
        BRA     Z60CC                    ;60C1: 20 09          ' .'
Z60C3   TSX                              ;60C3: 30             '0'
        LDS     forth_tmp1               ;60C4: 9E 88          '..'
        STX     forth_PSP_hi             ;60C6: DF 84          '..'
        LDX     #M0001                   ;60C8: CE 00 01       '...'
        PSHX                             ;60CB: 3C             '<'
Z60CC   LDD     forth_PSP_hi             ;60CC: DC 84          '..'
        SUBD    forth_UP_hi              ;60CE: 93 86          '..'
        JMP     Z7F02                    ;60D0: 7E 7F 02       '~..'
        PSHA                             ;60D3: 36             '6'
        LDAA    #$BD                     ;60D4: 86 BD          '..'
        STX     M9A81                    ;60D6: FF 9A 81       '...'
        FCB     $1F                      ;60D9: 1F             '.'
        BLS     Z60DD                    ;60DA: 23 01          '#.'
Z60DC   RTS                              ;60DC: 39             '9'
Z60DD   CMPA    #$08                     ;60DD: 81 08          '..'
        BEQ     Z60DC                    ;60DF: 27 FB          ''.'
        CMPA    #$0D                     ;60E1: 81 0D          '..'
        BEQ     Z60DC                    ;60E3: 27 F7          ''.'
        JSR     rom_read_key             ;60E5: BD 0C 10       '...'
        BRA     Z60D5                    ;60E8: 20 EB          ' .'
        FCB     $00                      ;60EA: 00             '.'
        NOP                              ;60EB: 01             '.'
        BRA     Z60FC                    ;60EC: 20 0E          ' .'
        FCB     $87                      ;60EE: 87             '.'
        BVC     Z611C                    ;60EF: 28 2B          '(+'
        INCA                             ;60F1: 4C             'L'
        CLRA                             ;60F2: 4F             'O'
        EIM     #$F2,$01,S               ;60F3: 65 F2 61       'e.a'
        FCB     $52                      ;60F6: 52             'R'
        FCB     $02                      ;60F7: 02             '.'
        TIM     #$F8,Z0064               ;60F8: 7B F8 64       '{.d'
        LSRA                             ;60FB: 44             'D'
Z60FC   INX                              ;60FC: 08             '.'
        INC     >forth_IP_lo             ;60FD: 7C 00 81       '|..'
        BNE     Z6105                    ;6100: 26 03          '&.'
        INC     >forth_IP_hi             ;6102: 7C 00 80       '|..'
Z6105   RTS                              ;6105: 39             '9'
Z6106   STAA    forth_char_buf           ;6106: 97 8A          '..'
        JSR     rom_read_key             ;6108: BD 0C 10       '...'
        LDAB    forth_char_flag          ;610B: D6 8B          '..'
        BEQ     Z6114                    ;610D: 27 05          ''.'
        LDAA    forth_char_buf           ;610F: 96 8A          '..'
        JSR     rom_beep                 ;6111: BD E2 EF       '...'
Z6114   RTS                              ;6114: 39             '9'
Z6115   LDAA    M016D                    ;6115: B6 01 6D       '..m'
        CMPA    #$0D                     ;6118: 81 0D          '..'
        BEQ     Z6123                    ;611A: 27 07          ''.'
Z611C   CMPA    #$08                     ;611C: 81 08          '..'
        BEQ     Z6124                    ;611E: 27 04          ''.'
        NOP                              ;6120: 01             '.'
        NOP                              ;6121: 01             '.'
        NOP                              ;6122: 01             '.'
Z6123   CLRA                             ;6123: 4F             'O'
Z6124   RTS                              ;6124: 39             '9'
        FCB     $00                      ;6125: 00             '.'
Z6126   PULA                             ;6126: 32             '2'
        PULB                             ;6127: 33             '3'
Z6128   STD     ,X                       ;6128: ED 00          '..'
        BRA     NEXT                     ;612A: 20 04          ' .'
Z612C   LDD     ,X                       ;612C: EC 00          '..'

; ================================================================
; Inner Interpreter
; NEXT: fetch next thread cell, look up CFA, execute
; PUSHD: push D to parameter stack, then NEXT
; ================================================================
PUSHD   PSHB                             ;612E: 37             '7'
        PSHA                             ;612F: 36             '6'
NEXT    LDX     forth_IP                 ;6130: DE 92          '..'
NEXT_INX INX                              ;6132: 08             '.'
        INX                              ;6133: 08             '.'
        STX     forth_IP                 ;6134: DF 92          '..'
        LDX     ,X                       ;6136: EE 00          '..'
Z6138   STX     forth_W                  ;6138: DF 90          '..'
        LDX     ,X                       ;613A: EE 00          '..'
        JMP     ,X                       ;613C: 6E 00          'n.'
        NOP                              ;613E: 01             '.'
;
; --- CODE: LIT ---
forth_LIT_NFA FCB     $83                      ;613F: 83             '.'
        FCC     "LI"                     ;6140: 4C 49          'LI'
        FCB     $D4                      ;6142: D4             '.'
forth_LIT_LFA FDB     $0000                    ;6143: 00 00          '..'
forth_LIT_CFA FDB     forth_LIT_PFA            ;6145: 61 47          'aG'
forth_LIT_PFA LDX     forth_IP                 ;6147: DE 92          '..'
        INX                              ;6149: 08             '.'
        INX                              ;614A: 08             '.'
        STX     forth_IP                 ;614B: DF 92          '..'
        LDD     ,X                       ;614D: EC 00          '..'
        JMP     PUSHD                    ;614F: 7E 61 2E       '~a.'
CLIT    AIM     #$54,???                 ;6152: 61 54 DE       'aT.'
        SBCA    M0008                    ;6155: 92 08          '..'
        STX     forth_IP                 ;6157: DF 92          '..'
        CLRA                             ;6159: 4F             'O'
        LDAB    $01,X                    ;615A: E6 01          '..'
        JMP     PUSHD                    ;615C: 7E 61 2E       '~a.'
;
; --- CODE: EXECUTE ---
forth_EXECUTE_NFA FCB     $87                      ;615F: 87             '.'
        FCC     "EXECUT"                 ;6160: 45 58 45 43 55 54 'EXECUT'
        FCB     $C5                      ;6166: C5             '.'
forth_EXECUTE_LFA FDB     forth_LIT_NFA            ;6167: 61 3F          'a?'
forth_EXECUTE_CFA FDB     forth_EXECUTE_PFA        ;6169: 61 6B          'ak'
forth_EXECUTE_PFA PULX                             ;616B: 38             '8'
        JMP     Z6138                    ;616C: 7E 61 38       '~a8'
        INS                              ;616F: 31             '1'
        JMP     Z6138                    ;6170: 7E 61 38       '~a8'
;
; --- CODE@6191: BRANCH ---
forth_BRANCH_NFA FCB     $86                      ;6173: 86             '.'
        FCC     "BRANC"                  ;6174: 42 52 41 4E 43 'BRANC'
        FCB     $C8                      ;6179: C8             '.'
forth_BRANCH_LFA FDB     forth_EXECUTE_NFA        ;617A: 61 5F          'a_'
forth_BRANCH_CFA FDB     Z6191                    ;617C: 61 91          'a.'
;
; --- CODE: 0BRANCH ---
forth_0BRANCH_NFA FCB     $87                      ;617E: 87             '.'
        FCC     "0BRANC"                 ;617F: 30 42 52 41 4E 43 '0BRANC'
        FCB     $C8                      ;6185: C8             '.'
forth_0BRANCH_LFA FDB     forth_BRANCH_NFA         ;6186: 61 73          'as'
forth_0BRANCH_CFA FDB     forth_0BRANCH_PFA        ;6188: 61 8A          'a.'
forth_0BRANCH_PFA PULA                             ;618A: 32             '2'
        PULB                             ;618B: 33             '3'
        ABA                              ;618C: 1B             '.'
        BNE     Z619C                    ;618D: 26 0D          '&.'
        BCS     Z619C                    ;618F: 25 0B          '%.'
Z6191   LDX     forth_IP                 ;6191: DE 92          '..'
        LDD     $02,X                    ;6193: EC 02          '..'
        ADDD    forth_IP                 ;6195: D3 92          '..'
        STD     forth_IP                 ;6197: DD 92          '..'
        JMP     NEXT                     ;6199: 7E 61 30       '~a0'
Z619C   LDX     forth_IP                 ;619C: DE 92          '..'
        INX                              ;619E: 08             '.'
        INX                              ;619F: 08             '.'
        STX     forth_IP                 ;61A0: DF 92          '..'
        JMP     NEXT                     ;61A2: 7E 61 30       '~a0'
;
; --- CODE: (LOOP) ---
forth_PARENLOOP_RPAREN_NFA FCB     $86                      ;61A5: 86             '.'
        FCC     "(LOOP"                  ;61A6: 28 4C 4F 4F 50 '(LOOP'
        FCB     $A9                      ;61AB: A9             '.'
forth_PARENLOOP_RPAREN_LFA FDB     forth_0BRANCH_NFA        ;61AC: 61 7E          'a~'
forth_PARENLOOP_RPAREN_CFA FDB     forth_PARENLOOP_RPAREN_PFA ;61AE: 61 B0          'a.'
forth_PARENLOOP_RPAREN_PFA CLRA                             ;61B0: 4F             'O'
        LDAB    #$01                     ;61B1: C6 01          '..'
        BRA     Z61C3                    ;61B3: 20 0E          ' .'
;
; --- CODE: (+LOOP) ---
forth_PAREN_PLUSLOOP_RPAREN_NFA FCB     $87                      ;61B5: 87             '.'
        FCC     "(+LOOP"                 ;61B6: 28 2B 4C 4F 4F 50 '(+LOOP'
        FCB     $A9                      ;61BC: A9             '.'
forth_PAREN_PLUSLOOP_RPAREN_LFA FDB     forth_PARENLOOP_RPAREN_NFA ;61BD: 61 A5          'a.'
forth_PAREN_PLUSLOOP_RPAREN_CFA FDB     forth_PAREN_PLUSLOOP_RPAREN_PFA ;61BF: 61 C1          'a.'
forth_PAREN_PLUSLOOP_RPAREN_PFA PULA                             ;61C1: 32             '2'
        PULB                             ;61C2: 33             '3'
Z61C3   TSTA                             ;61C3: 4D             'M'
        BPL     Z61D8                    ;61C4: 2A 12          '*.'
        BSR     Z61D1                    ;61C6: 8D 09          '..'
        SEC                              ;61C8: 0D             '.'
        SBCB    $05,X                    ;61C9: E2 05          '..'
        SBCA    $04,X                    ;61CB: A2 04          '..'
        BPL     Z6191                    ;61CD: 2A C2          '*.'
        BRA     Z61E0                    ;61CF: 20 0F          ' .'
Z61D1   LDX     forth_RP                 ;61D1: DE 94          '..'
        ADDD    $02,X                    ;61D3: E3 02          '..'
        STD     $02,X                    ;61D5: ED 02          '..'
        RTS                              ;61D7: 39             '9'
Z61D8   BSR     Z61D1                    ;61D8: 8D F7          '..'
        SUBB    $05,X                    ;61DA: E0 05          '..'
        SBCA    $04,X                    ;61DC: A2 04          '..'
        BMI     Z6191                    ;61DE: 2B B1          '+.'
Z61E0   INX                              ;61E0: 08             '.'
        INX                              ;61E1: 08             '.'
        INX                              ;61E2: 08             '.'
        INX                              ;61E3: 08             '.'
        STX     forth_RP                 ;61E4: DF 94          '..'
        BRA     Z619C                    ;61E6: 20 B4          ' .'
;
; --- CODE: (DO) ---
forth_PARENDO_RPAREN_NFA FCB     $84                      ;61E8: 84             '.'
        FCC     "(DO"                    ;61E9: 28 44 4F       '(DO'
        FCB     $A9                      ;61EC: A9             '.'
forth_PARENDO_RPAREN_LFA FDB     forth_PAREN_PLUSLOOP_RPAREN_NFA ;61ED: 61 B5          'a.'
forth_PARENDO_RPAREN_CFA FDB     forth_PARENDO_RPAREN_PFA ;61EF: 61 F1          'a.'
forth_PARENDO_RPAREN_PFA LDX     forth_RP                 ;61F1: DE 94          '..'
        DEX                              ;61F3: 09             '.'
        DEX                              ;61F4: 09             '.'
        DEX                              ;61F5: 09             '.'
        DEX                              ;61F6: 09             '.'
        STX     forth_RP                 ;61F7: DF 94          '..'
        PULA                             ;61F9: 32             '2'
        PULB                             ;61FA: 33             '3'
        STD     $02,X                    ;61FB: ED 02          '..'
        PULA                             ;61FD: 32             '2'
        PULB                             ;61FE: 33             '3'
        STD     $04,X                    ;61FF: ED 04          '..'
        JMP     NEXT                     ;6201: 7E 61 30       '~a0'
;
; --- CODE: I ---
forth_I_NFA FCB     $81,$C9                  ;6204: 81 C9          '..'
forth_I_LFA FDB     forth_PARENDO_RPAREN_NFA ;6206: 61 E8          'a.'
forth_I_CFA FDB     forth_I_PFA              ;6208: 62 0A          'b.'
forth_I_PFA LDX     forth_RP                 ;620A: DE 94          '..'
        INX                              ;620C: 08             '.'
        INX                              ;620D: 08             '.'
        JMP     Z612C                    ;620E: 7E 61 2C       '~a,'
;
; --- CODE: DIGIT ---
forth_DIGIT_NFA FCB     $85                      ;6211: 85             '.'
        FCC     "DIGI"                   ;6212: 44 49 47 49    'DIGI'
        FCB     $D4                      ;6216: D4             '.'
forth_DIGIT_LFA FDB     forth_I_NFA              ;6217: 62 04          'b.'
forth_DIGIT_CFA FDB     forth_DIGIT_PFA          ;6219: 62 1B          'b.'
forth_DIGIT_PFA TSX                              ;621B: 30             '0'
        LDAA    $03,X                    ;621C: A6 03          '..'
        SUBA    #$30                     ;621E: 80 30          '.0'
        BMI     Z623D                    ;6220: 2B 1B          '+.'
        CMPA    #$0A                     ;6222: 81 0A          '..'
        BMI     Z6230                    ;6224: 2B 0A          '+.'
        CMPA    #$11                     ;6226: 81 11          '..'
        BMI     Z623D                    ;6228: 2B 13          '+.'
        CMPA    #$2B                     ;622A: 81 2B          '.+'
        BPL     Z623D                    ;622C: 2A 0F          '*.'
        SUBA    #$07                     ;622E: 80 07          '..'
Z6230   CMPA    $01,X                    ;6230: A1 01          '..'
        BPL     Z623D                    ;6232: 2A 09          '*.'
        LDAB    #$01                     ;6234: C6 01          '..'
        STAA    $03,X                    ;6236: A7 03          '..'
Z6238   STAB    $01,X                    ;6238: E7 01          '..'
        JMP     NEXT                     ;623A: 7E 61 30       '~a0'
Z623D   CLRB                             ;623D: 5F             '_'
        INS                              ;623E: 31             '1'
        INS                              ;623F: 31             '1'
        TSX                              ;6240: 30             '0'
        STAB    ,X                       ;6241: E7 00          '..'
        BRA     Z6238                    ;6243: 20 F3          ' .'
;
; --- CODE: (FIND) ---
forth_PARENFIND_RPAREN_NFA FCB     $86                      ;6245: 86             '.'
        FCC     "(FIND"                  ;6246: 28 46 49 4E 44 '(FIND'
        FCB     $A9                      ;624B: A9             '.'
forth_PARENFIND_RPAREN_LFA FDB     forth_DIGIT_NFA          ;624C: 62 11          'b.'
forth_PARENFIND_RPAREN_CFA FDB     forth_PARENFIND_RPAREN_PFA ;624E: 62 50          'bP'
forth_PARENFIND_RPAREN_PFA NOP                              ;6250: 01             '.'
        NOP                              ;6251: 01             '.'
        LDX     #forth_IP_hi             ;6252: CE 00 80       '...'
        LDAB    #$04                     ;6255: C6 04          '..'
Z6257   PULA                             ;6257: 32             '2'
        STAA    ,X                       ;6258: A7 00          '..'
        INX                              ;625A: 08             '.'
        DECB                             ;625B: 5A             'Z'
        BNE     Z6257                    ;625C: 26 F9          '&.'
        LDX     forth_IP_hi              ;625E: DE 80          '..'
Z6260   LDAB    ,X                       ;6260: E6 00          '..'
        STAB    forth_UP_hi              ;6262: D7 86          '..'
        ANDB    #$3F                     ;6264: C4 3F          '.?'
        INX                              ;6266: 08             '.'
        STX     forth_IP_hi              ;6267: DF 80          '..'
        LDX     forth_W_hi               ;6269: DE 82          '..'
        LDAA    ,X                       ;626B: A6 00          '..'
        INX                              ;626D: 08             '.'
        STX     forth_PSP_hi             ;626E: DF 84          '..'
        CBA                              ;6270: 11             '.'
        BNE     Z6295                    ;6271: 26 22          '&"'
Z6273   LDX     forth_PSP_hi             ;6273: DE 84          '..'
        LDAA    ,X                       ;6275: A6 00          '..'
        INX                              ;6277: 08             '.'
        STX     forth_PSP_hi             ;6278: DF 84          '..'
        LDX     forth_IP_hi              ;627A: DE 80          '..'
        LDAB    ,X                       ;627C: E6 00          '..'
        INX                              ;627E: 08             '.'
        STX     forth_IP_hi              ;627F: DF 80          '..'
        TSTB                             ;6281: 5D             ']'
        BPL     Z6292                    ;6282: 2A 0E          '*.'
        ANDB    #$7F                     ;6284: C4 7F          '..'
        CBA                              ;6286: 11             '.'
        BEQ     Z629E                    ;6287: 27 15          ''.'
Z6289   LDX     ,X                       ;6289: EE 00          '..'
        BNE     Z6260                    ;628B: 26 D3          '&.'
        CLRA                             ;628D: 4F             'O'
        CLRB                             ;628E: 5F             '_'
        JMP     PUSHD                    ;628F: 7E 61 2E       '~a.'
Z6292   CBA                              ;6292: 11             '.'
        BEQ     Z6273                    ;6293: 27 DE          ''.'
Z6295   LDX     forth_IP_hi              ;6295: DE 80          '..'
Z6297   LDAB    ,X                       ;6297: E6 00          '..'
        INX                              ;6299: 08             '.'
        BPL     Z6297                    ;629A: 2A FB          '*.'
        BRA     Z6289                    ;629C: 20 EB          ' .'
Z629E   LDD     forth_IP_hi              ;629E: DC 80          '..'
        ADDD    #M0004                   ;62A0: C3 00 04       '...'
        PSHB                             ;62A3: 37             '7'
        PSHA                             ;62A4: 36             '6'
        LDAA    forth_UP_hi              ;62A5: 96 86          '..'
        PSHA                             ;62A7: 36             '6'
        CLRA                             ;62A8: 4F             'O'
        PSHA                             ;62A9: 36             '6'
        LDAB    #$01                     ;62AA: C6 01          '..'
        JMP     PUSHD                    ;62AC: 7E 61 2E       '~a.'
;
; --- CODE: ENCLOSE ---
forth_ENCLOSE_NFA FCB     $87                      ;62AF: 87             '.'
        FCC     "ENCLOS"                 ;62B0: 45 4E 43 4C 4F 53 'ENCLOS'
        FCB     $C5                      ;62B6: C5             '.'
forth_ENCLOSE_LFA FDB     forth_PARENFIND_RPAREN_NFA ;62B7: 62 45          'bE'
forth_ENCLOSE_CFA FDB     forth_ENCLOSE_PFA        ;62B9: 62 BB          'b.'
forth_ENCLOSE_PFA CLRA                             ;62BB: 4F             'O'
        CLRB                             ;62BC: 5F             '_'
        STD     forth_IP_hi              ;62BD: DD 80          '..'
        INS                              ;62BF: 31             '1'
        PULB                             ;62C0: 33             '3'
        TSX                              ;62C1: 30             '0'
        LDX     ,X                       ;62C2: EE 00          '..'
Z62C4   LDAA    ,X                       ;62C4: A6 00          '..'
        BEQ     Z62EB                    ;62C6: 27 23          ''#'
        CBA                              ;62C8: 11             '.'
        BNE     Z62D0                    ;62C9: 26 05          '&.'
        JSR     Z60FC                    ;62CB: BD 60 FC       '.`.'
        BRA     Z62C4                    ;62CE: 20 F4          ' .'
Z62D0   LDAA    forth_IP_lo              ;62D0: 96 81          '..'
        PSHA                             ;62D2: 36             '6'
        LDAA    forth_IP_hi              ;62D3: 96 80          '..'
        PSHA                             ;62D5: 36             '6'
Z62D6   LDAA    ,X                       ;62D6: A6 00          '..'
        BEQ     Z62F4                    ;62D8: 27 1A          ''.'
        CBA                              ;62DA: 11             '.'
        BEQ     Z62E2                    ;62DB: 27 05          ''.'
        JSR     Z60FC                    ;62DD: BD 60 FC       '.`.'
        BRA     Z62D6                    ;62E0: 20 F4          ' .'
Z62E2   LDD     forth_IP_hi              ;62E2: DC 80          '..'
        PSHB                             ;62E4: 37             '7'
        PSHA                             ;62E5: 36             '6'
        ADDD    #M0001                   ;62E6: C3 00 01       '...'
        BRA     Z62F8                    ;62E9: 20 0D          ' .'
Z62EB   LDD     forth_IP_hi              ;62EB: DC 80          '..'
        PSHB                             ;62ED: 37             '7'
        PSHA                             ;62EE: 36             '6'
        ADDD    #M0001                   ;62EF: C3 00 01       '...'
        BRA     Z62F6                    ;62F2: 20 02          ' .'
Z62F4   LDD     forth_IP_hi              ;62F4: DC 80          '..'
Z62F6   PSHB                             ;62F6: 37             '7'
        PSHA                             ;62F7: 36             '6'
Z62F8   JMP     PUSHD                    ;62F8: 7E 61 2E       '~a.'
;
; --- CODE: EMIT ---
forth_EMIT_NFA FCB     $84                      ;62FB: 84             '.'
        FCC     "EMI"                    ;62FC: 45 4D 49       'EMI'
        FCB     $D4                      ;62FF: D4             '.'
forth_EMIT_LFA FDB     forth_ENCLOSE_NFA        ;6300: 62 AF          'b.'
forth_EMIT_CFA FDB     forth_EMIT_PFA           ;6302: 63 04          'c.'
forth_EMIT_PFA PULA                             ;6304: 32             '2'
        PULA                             ;6305: 32             '2'
        JSR     Z6045                    ;6306: BD 60 45       '.`E'
        LDX     M0096                    ;6309: DE 96          '..'
        INC     $1B,X                    ;630B: 6C 1B          'l.'
        BNE     Z6311                    ;630D: 26 02          '&.'
        INC     $1A,X                    ;630F: 6C 1A          'l.'
Z6311   JMP     NEXT                     ;6311: 7E 61 30       '~a0'
;
; --- CODE: KEY ---
forth_KEY_NFA FCB     $83                      ;6314: 83             '.'
        FCC     "KE"                     ;6315: 4B 45          'KE'
        FCB     $D9                      ;6317: D9             '.'
forth_KEY_LFA FDB     forth_EMIT_NFA           ;6318: 62 FB          'b.'
forth_KEY_CFA FDB     forth_KEY_PFA            ;631A: 63 1C          'c.'
forth_KEY_PFA JSR     Z60D5                    ;631C: BD 60 D5       '.`.'
        PSHA                             ;631F: 36             '6'
        CLRA                             ;6320: 4F             'O'
        PSHA                             ;6321: 36             '6'
        JMP     NEXT                     ;6322: 7E 61 30       '~a0'
;
; --- CODE: ?TERM ---
forth_QUESTIONTERM_NFA FCB     $85                      ;6325: 85             '.'
        FCC     "?TER"                   ;6326: 3F 54 45 52    '?TER'
        FCB     $CD                      ;632A: CD             '.'
forth_QUESTIONTERM_LFA FDB     forth_KEY_NFA            ;632B: 63 14          'c.'
forth_QUESTIONTERM_CFA FDB     forth_QUESTIONTERM_PFA   ;632D: 63 2F          'c/'
forth_QUESTIONTERM_PFA JSR     Z6115                    ;632F: BD 61 15       '.a.'
        CLRB                             ;6332: 5F             '_'
        JMP     PUSHD                    ;6333: 7E 61 2E       '~a.'
;
; --- CODE: CR ---
forth_CR_NFA FCB     $82                      ;6336: 82             '.'
        FCC     "C"                      ;6337: 43             'C'
        FCB     $D2                      ;6338: D2             '.'
forth_CR_LFA FDB     forth_QUESTIONTERM_NFA   ;6339: 63 25          'c%'
forth_CR_CFA FDB     forth_CR_PFA             ;633B: 63 3D          'c='
forth_CR_PFA JSR     Z603C                    ;633D: BD 60 3C       '.`<'
        JMP     NEXT                     ;6340: 7E 61 30       '~a0'
;
; --- CODE: CMOVE ---
forth_CMOVE_NFA FCB     $85                      ;6343: 85             '.'
        FCC     "CMOV"                   ;6344: 43 4D 4F 56    'CMOV'
        FCB     $C5                      ;6348: C5             '.'
forth_CMOVE_LFA FDB     forth_CR_NFA             ;6349: 63 36          'c6'
forth_CMOVE_CFA FDB     forth_CMOVE_PFA          ;634B: 63 4D          'cM'
forth_CMOVE_PFA LDX     #forth_IP_hi             ;634D: CE 00 80       '...'
        LDAB    #$06                     ;6350: C6 06          '..'
Z6352   PULA                             ;6352: 32             '2'
        STAA    ,X                       ;6353: A7 00          '..'
        INX                              ;6355: 08             '.'
        DECB                             ;6356: 5A             'Z'
        BNE     Z6352                    ;6357: 26 F9          '&.'
Z6359   LDAA    forth_IP_hi              ;6359: 96 80          '..'
        LDAB    forth_IP_lo              ;635B: D6 81          '..'
        SUBB    #$01                     ;635D: C0 01          '..'
        SBCA    #$00                     ;635F: 82 00          '..'
        STAA    forth_IP_hi              ;6361: 97 80          '..'
        STAB    forth_IP_lo              ;6363: D7 81          '..'
        BCS     Z6377                    ;6365: 25 10          '%.'
        LDX     forth_PSP_hi             ;6367: DE 84          '..'
        LDAA    ,X                       ;6369: A6 00          '..'
        INX                              ;636B: 08             '.'
        STX     forth_PSP_hi             ;636C: DF 84          '..'
        LDX     forth_W_hi               ;636E: DE 82          '..'
        STAA    ,X                       ;6370: A7 00          '..'
        INX                              ;6372: 08             '.'
        STX     forth_W_hi               ;6373: DF 82          '..'
        BRA     Z6359                    ;6375: 20 E2          ' .'
Z6377   JMP     NEXT                     ;6377: 7E 61 30       '~a0'
;
; --- CODE: U* ---
forth_U_STAR_NFA FCB     $82                      ;637A: 82             '.'
        FCC     "U"                      ;637B: 55             'U'
        FCB     $AA                      ;637C: AA             '.'
forth_U_STAR_LFA FDB     forth_CMOVE_NFA          ;637D: 63 43          'cC'
forth_U_STAR_CFA FDB     forth_U_STAR_PFA         ;637F: 63 81          'c.'
forth_U_STAR_PFA BSR     Z6388                    ;6381: 8D 05          '..'
        INS                              ;6383: 31             '1'
        INS                              ;6384: 31             '1'
        JMP     PUSHD                    ;6385: 7E 61 2E       '~a.'
Z6388   LDAA    #$10                     ;6388: 86 10          '..'
        PSHA                             ;638A: 36             '6'
        CLRA                             ;638B: 4F             'O'
        CLRB                             ;638C: 5F             '_'
        TSX                              ;638D: 30             '0'
Z638E   ROR     $05,X                    ;638E: 66 05          'f.'
        ROR     $06,X                    ;6390: 66 06          'f.'
        DEC     ,X                       ;6392: 6A 00          'j.'
        BMI     Z63A0                    ;6394: 2B 0A          '+.'
        BCC     Z639C                    ;6396: 24 04          '$.'
        ADDB    $04,X                    ;6398: EB 04          '..'
        ADCA    $03,X                    ;639A: A9 03          '..'
Z639C   RORA                             ;639C: 46             'F'
        RORB                             ;639D: 56             'V'
        BRA     Z638E                    ;639E: 20 EE          ' .'
Z63A0   INS                              ;63A0: 31             '1'
        RTS                              ;63A1: 39             '9'
;
; --- CODE: U/ ---
forth_U_SLASH_NFA FCB     $82                      ;63A2: 82             '.'
        FCC     "U"                      ;63A3: 55             'U'
        FCB     $AF                      ;63A4: AF             '.'
forth_U_SLASH_LFA FDB     forth_U_STAR_NFA         ;63A5: 63 7A          'cz'
forth_U_SLASH_CFA FDB     forth_U_SLASH_PFA        ;63A7: 63 A9          'c.'
forth_U_SLASH_PFA LDAA    #$11                     ;63A9: 86 11          '..'
        PSHA                             ;63AB: 36             '6'
        TSX                              ;63AC: 30             '0'
        LDAA    $03,X                    ;63AD: A6 03          '..'
        LDAB    $04,X                    ;63AF: E6 04          '..'
Z63B1   CMPA    $01,X                    ;63B1: A1 01          '..'
        BHI     Z63BE                    ;63B3: 22 09          '".'
        BCS     Z63BB                    ;63B5: 25 04          '%.'
        CMPB    $02,X                    ;63B7: E1 02          '..'
        BCC     Z63BE                    ;63B9: 24 03          '$.'
Z63BB   CLC                              ;63BB: 0C             '.'
        BRA     Z63C3                    ;63BC: 20 05          ' .'
Z63BE   SUBB    $02,X                    ;63BE: E0 02          '..'
        SBCA    $01,X                    ;63C0: A2 01          '..'
        SEC                              ;63C2: 0D             '.'
Z63C3   ROL     $06,X                    ;63C3: 69 06          'i.'
        ROL     $05,X                    ;63C5: 69 05          'i.'
        DEC     ,X                       ;63C7: 6A 00          'j.'
        BEQ     Z63D1                    ;63C9: 27 06          ''.'
        ROLB                             ;63CB: 59             'Y'
        ROLA                             ;63CC: 49             'I'
        BCC     Z63B1                    ;63CD: 24 E2          '$.'
        BRA     Z63BE                    ;63CF: 20 ED          ' .'
Z63D1   INS                              ;63D1: 31             '1'
        INS                              ;63D2: 31             '1'
        INS                              ;63D3: 31             '1'
        INS                              ;63D4: 31             '1'
        INS                              ;63D5: 31             '1'
        JMP     Z654F                    ;63D6: 7E 65 4F       '~eO'
;
; --- CODE: AND ---
forth_AND_NFA FCB     $83                      ;63D9: 83             '.'
        FCC     "AN"                     ;63DA: 41 4E          'AN'
        FCB     $C4                      ;63DC: C4             '.'
forth_AND_LFA FDB     forth_U_SLASH_NFA        ;63DD: 63 A2          'c.'
forth_AND_CFA FDB     forth_AND_PFA            ;63DF: 63 E1          'c.'
forth_AND_PFA PULA                             ;63E1: 32             '2'
        PULB                             ;63E2: 33             '3'
        TSX                              ;63E3: 30             '0'
        ANDB    $01,X                    ;63E4: E4 01          '..'
        ANDA    ,X                       ;63E6: A4 00          '..'
        JMP     Z6128                    ;63E8: 7E 61 28       '~a('
;
; --- CODE: OR ---
forth_OR_NFA FCB     $82                      ;63EB: 82             '.'
        FCC     "O"                      ;63EC: 4F             'O'
        FCB     $D2                      ;63ED: D2             '.'
forth_OR_LFA FDB     forth_AND_NFA            ;63EE: 63 D9          'c.'
forth_OR_CFA FDB     forth_OR_PFA             ;63F0: 63 F2          'c.'
forth_OR_PFA PULA                             ;63F2: 32             '2'
        PULB                             ;63F3: 33             '3'
        TSX                              ;63F4: 30             '0'
        ORAB    $01,X                    ;63F5: EA 01          '..'
        ORAA    ,X                       ;63F7: AA 00          '..'
        JMP     Z6128                    ;63F9: 7E 61 28       '~a('
;
; --- CODE: XOR ---
forth_XOR_NFA FCB     $83                      ;63FC: 83             '.'
        FCC     "XO"                     ;63FD: 58 4F          'XO'
        FCB     $D2                      ;63FF: D2             '.'
forth_XOR_LFA FDB     forth_OR_NFA             ;6400: 63 EB          'c.'
forth_XOR_CFA FDB     forth_XOR_PFA            ;6402: 64 04          'd.'
forth_XOR_PFA PULA                             ;6404: 32             '2'
        PULB                             ;6405: 33             '3'
        TSX                              ;6406: 30             '0'
        EORB    $01,X                    ;6407: E8 01          '..'
        EORA    ,X                       ;6409: A8 00          '..'
        JMP     Z6128                    ;640B: 7E 61 28       '~a('
;
; --- CODE: SP@ ---
forth_SP_FETCH_NFA FCB     $83                      ;640E: 83             '.'
        FCC     "SP"                     ;640F: 53 50          'SP'
        FCB     $C0                      ;6411: C0             '.'
forth_SP_FETCH_LFA FDB     forth_XOR_NFA            ;6412: 63 FC          'c.'
forth_SP_FETCH_CFA FDB     forth_SP_FETCH_PFA       ;6414: 64 16          'd.'
forth_SP_FETCH_PFA TSX                              ;6416: 30             '0'
        STX     forth_IP_hi              ;6417: DF 80          '..'
        LDX     #forth_IP_hi             ;6419: CE 00 80       '...'
        JMP     Z612C                    ;641C: 7E 61 2C       '~a,'
;
; --- CODE: SP! ---
forth_SP_STORE_NFA FCB     $83                      ;641F: 83             '.'
        FCC     "SP"                     ;6420: 53 50          'SP'
        FCB     $A1                      ;6422: A1             '.'
forth_SP_STORE_LFA FDB     forth_SP_FETCH_NFA       ;6423: 64 0E          'd.'
forth_SP_STORE_CFA FDB     forth_SP_STORE_PFA       ;6425: 64 27          'd''
forth_SP_STORE_PFA LDX     M0096                    ;6427: DE 96          '..'
        LDX     $06,X                    ;6429: EE 06          '..'
        TXS                              ;642B: 35             '5'
        JMP     NEXT                     ;642C: 7E 61 30       '~a0'
;
; --- CODE: RP! ---
forth_RP_STORE_NFA FCB     $83                      ;642F: 83             '.'
        FCC     "RP"                     ;6430: 52 50          'RP'
        FCB     $A1                      ;6432: A1             '.'
forth_RP_STORE_LFA FDB     forth_SP_STORE_NFA       ;6433: 64 1F          'd.'
forth_RP_STORE_CFA FDB     forth_RP_STORE_PFA       ;6435: 64 37          'd7'
forth_RP_STORE_PFA LDX     M6020                    ;6437: FE 60 20       '.` '
        STX     forth_RP                 ;643A: DF 94          '..'
        JMP     NEXT                     ;643C: 7E 61 30       '~a0'
;
; --- CODE: ;S ---
forth_SEMIS_NFA FCB     $82                      ;643F: 82             '.'
        FCC     ";"                      ;6440: 3B             ';'
        FCB     $D3                      ;6441: D3             '.'
forth_SEMIS_LFA FDB     forth_RP_STORE_NFA       ;6442: 64 2F          'd/'
forth_SEMIS_CFA FDB     forth_SEMIS_PFA          ;6444: 64 46          'dF'
forth_SEMIS_PFA LDX     forth_RP                 ;6446: DE 94          '..'
        INX                              ;6448: 08             '.'
        INX                              ;6449: 08             '.'
        STX     forth_RP                 ;644A: DF 94          '..'
        LDX     ,X                       ;644C: EE 00          '..'
        JMP     NEXT_INX                 ;644E: 7E 61 32       '~a2'
;
; --- CODE: LEAVE ---
forth_LEAVE_NFA FCB     $85                      ;6451: 85             '.'
        FCC     "LEAV"                   ;6452: 4C 45 41 56    'LEAV'
        FCB     $C5                      ;6456: C5             '.'
forth_LEAVE_LFA FDB     forth_SEMIS_NFA          ;6457: 64 3F          'd?'
forth_LEAVE_CFA FDB     forth_LEAVE_PFA          ;6459: 64 5B          'd['
forth_LEAVE_PFA LDX     forth_RP                 ;645B: DE 94          '..'
        LDD     $02,X                    ;645D: EC 02          '..'
        STD     $04,X                    ;645F: ED 04          '..'
        JMP     NEXT                     ;6461: 7E 61 30       '~a0'
;
; --- CODE: >R ---
forth_GTR_NFA FCB     $82                      ;6464: 82             '.'
        FCC     ">"                      ;6465: 3E             '>'
        FCB     $D2                      ;6466: D2             '.'
forth_GTR_LFA FDB     forth_LEAVE_NFA          ;6467: 64 51          'dQ'
forth_GTR_CFA FDB     forth_GTR_PFA            ;6469: 64 6B          'dk'
forth_GTR_PFA LDX     forth_RP                 ;646B: DE 94          '..'
        DEX                              ;646D: 09             '.'
        DEX                              ;646E: 09             '.'
        STX     forth_RP                 ;646F: DF 94          '..'
        PULA                             ;6471: 32             '2'
        PULB                             ;6472: 33             '3'
        STD     $02,X                    ;6473: ED 02          '..'
        JMP     NEXT                     ;6475: 7E 61 30       '~a0'
;
; --- CODE: R> ---
forth_R_GT_NFA FCB     $82                      ;6478: 82             '.'
        FCC     "R"                      ;6479: 52             'R'
        FCB     $BE                      ;647A: BE             '.'
forth_R_GT_LFA FDB     forth_GTR_NFA            ;647B: 64 64          'dd'
forth_R_GT_CFA FDB     forth_R_GT_PFA           ;647D: 64 7F          'd.'
forth_R_GT_PFA LDX     forth_RP                 ;647F: DE 94          '..'
        LDD     $02,X                    ;6481: EC 02          '..'
        INX                              ;6483: 08             '.'
        INX                              ;6484: 08             '.'
        STX     forth_RP                 ;6485: DF 94          '..'
        JMP     PUSHD                    ;6487: 7E 61 2E       '~a.'
;
; --- CODE: R ---
forth_R_NFA FCB     $81,$D2                  ;648A: 81 D2          '..'
forth_R_LFA FDB     forth_R_GT_NFA           ;648C: 64 78          'dx'
forth_R_CFA FDB     forth_R_PFA              ;648E: 64 90          'd.'
forth_R_PFA LDX     forth_RP                 ;6490: DE 94          '..'
        INX                              ;6492: 08             '.'
        INX                              ;6493: 08             '.'
        JMP     Z612C                    ;6494: 7E 61 2C       '~a,'
;
; --- CODE: 0= ---
forth_0_EQ_NFA FCB     $82                      ;6497: 82             '.'
        FCC     "0"                      ;6498: 30             '0'
        FCB     $BD                      ;6499: BD             '.'
forth_0_EQ_LFA FDB     forth_R_NFA              ;649A: 64 8A          'd.'
forth_0_EQ_CFA FDB     forth_0_EQ_PFA           ;649C: 64 9E          'd.'
forth_0_EQ_PFA TSX                              ;649E: 30             '0'
        CLRA                             ;649F: 4F             'O'
        CLRB                             ;64A0: 5F             '_'
        LDX     ,X                       ;64A1: EE 00          '..'
        BNE     Z64A6                    ;64A3: 26 01          '&.'
        INCB                             ;64A5: 5C             '\'
Z64A6   TSX                              ;64A6: 30             '0'
        JMP     Z6128                    ;64A7: 7E 61 28       '~a('
;
; --- CODE: 0< ---
forth_0_LT_NFA FCB     $82                      ;64AA: 82             '.'
        FCC     "0"                      ;64AB: 30             '0'
        FCB     $BC                      ;64AC: BC             '.'
forth_0_LT_LFA FDB     forth_0_EQ_NFA           ;64AD: 64 97          'd.'
forth_0_LT_CFA FDB     forth_0_LT_PFA           ;64AF: 64 B1          'd.'
forth_0_LT_PFA TSX                              ;64B1: 30             '0'
        LDAA    #$80                     ;64B2: 86 80          '..'
        ANDA    ,X                       ;64B4: A4 00          '..'
        BEQ     Z64BE                    ;64B6: 27 06          ''.'
        CLRA                             ;64B8: 4F             'O'
        LDAB    #$01                     ;64B9: C6 01          '..'
        JMP     Z6128                    ;64BB: 7E 61 28       '~a('
Z64BE   CLRB                             ;64BE: 5F             '_'
        JMP     Z6128                    ;64BF: 7E 61 28       '~a('
;
; --- CODE: + ---
forth_PLUS_NFA FCB     $81,$AB                  ;64C2: 81 AB          '..'
forth_PLUS_LFA FDB     forth_0_LT_NFA           ;64C4: 64 AA          'd.'
forth_PLUS_CFA FDB     forth_PLUS_PFA           ;64C6: 64 C8          'd.'
forth_PLUS_PFA PULA                             ;64C8: 32             '2'
        PULB                             ;64C9: 33             '3'
        TSX                              ;64CA: 30             '0'
        ADDD    ,X                       ;64CB: E3 00          '..'
        JMP     Z6128                    ;64CD: 7E 61 28       '~a('
;
; --- CODE: D+ ---
forth_D_PLUS_NFA FCB     $82                      ;64D0: 82             '.'
        FCC     "D"                      ;64D1: 44             'D'
        FCB     $AB                      ;64D2: AB             '.'
forth_D_PLUS_LFA FDB     forth_PLUS_NFA           ;64D3: 64 C2          'd.'
forth_D_PLUS_CFA FDB     forth_D_PLUS_PFA         ;64D5: 64 D7          'd.'
forth_D_PLUS_PFA TSX                              ;64D7: 30             '0'
        CLC                              ;64D8: 0C             '.'
        LDAB    #$04                     ;64D9: C6 04          '..'
Z64DB   LDAA    $03,X                    ;64DB: A6 03          '..'
        ADCA    $07,X                    ;64DD: A9 07          '..'
        STAA    $07,X                    ;64DF: A7 07          '..'
        DEX                              ;64E1: 09             '.'
        DECB                             ;64E2: 5A             'Z'
        BNE     Z64DB                    ;64E3: 26 F6          '&.'
        INS                              ;64E5: 31             '1'
        INS                              ;64E6: 31             '1'
        INS                              ;64E7: 31             '1'
        INS                              ;64E8: 31             '1'
        JMP     NEXT                     ;64E9: 7E 61 30       '~a0'
;
; --- CODE: MINUS ---
forth_MINUS_NFA FCB     $85                      ;64EC: 85             '.'
        FCC     "MINU"                   ;64ED: 4D 49 4E 55    'MINU'
        FCB     $D3                      ;64F1: D3             '.'
forth_MINUS_LFA FDB     forth_D_PLUS_NFA         ;64F2: 64 D0          'd.'
forth_MINUS_CFA FDB     forth_MINUS_PFA          ;64F4: 64 F6          'd.'
forth_MINUS_PFA TSX                              ;64F6: 30             '0'
        NEG     $01,X                    ;64F7: 60 01          '`.'
        BCS     Z64FF                    ;64F9: 25 04          '%.'
        NEG     ,X                       ;64FB: 60 00          '`.'
        BRA     Z6501                    ;64FD: 20 02          ' .'
Z64FF   COM     ,X                       ;64FF: 63 00          'c.'
Z6501   JMP     NEXT                     ;6501: 7E 61 30       '~a0'
;
; --- CODE: DMINUS ---
forth_DMINUS_NFA FCB     $86                      ;6504: 86             '.'
        FCC     "DMINU"                  ;6505: 44 4D 49 4E 55 'DMINU'
        FCB     $D3                      ;650A: D3             '.'
forth_DMINUS_LFA FDB     forth_MINUS_NFA          ;650B: 64 EC          'd.'
forth_DMINUS_CFA FDB     forth_DMINUS_PFA         ;650D: 65 0F          'e.'
forth_DMINUS_PFA TSX                              ;650F: 30             '0'
        COM     ,X                       ;6510: 63 00          'c.'
        COM     $01,X                    ;6512: 63 01          'c.'
        COM     $02,X                    ;6514: 63 02          'c.'
        NEG     $03,X                    ;6516: 60 03          '`.'
        BNE     Z6524                    ;6518: 26 0A          '&.'
        INC     $02,X                    ;651A: 6C 02          'l.'
        BNE     Z6524                    ;651C: 26 06          '&.'
        INC     $01,X                    ;651E: 6C 01          'l.'
        BNE     Z6524                    ;6520: 26 02          '&.'
        INC     ,X                       ;6522: 6C 00          'l.'
Z6524   JMP     NEXT                     ;6524: 7E 61 30       '~a0'
;
; --- CODE: OVER ---
forth_OVER_NFA FCB     $84                      ;6527: 84             '.'
        FCC     "OVE"                    ;6528: 4F 56 45       'OVE'
        FCB     $D2                      ;652B: D2             '.'
forth_OVER_LFA FDB     forth_DMINUS_NFA         ;652C: 65 04          'e.'
forth_OVER_CFA FDB     forth_OVER_PFA           ;652E: 65 30          'e0'
forth_OVER_PFA TSX                              ;6530: 30             '0'
        LDD     $02,X                    ;6531: EC 02          '..'
        JMP     PUSHD                    ;6533: 7E 61 2E       '~a.'
;
; --- CODE: DROP ---
forth_DROP_NFA FCB     $84                      ;6536: 84             '.'
        FCC     "DRO"                    ;6537: 44 52 4F       'DRO'
        FCB     $D0                      ;653A: D0             '.'
forth_DROP_LFA FDB     forth_OVER_NFA           ;653B: 65 27          'e''
forth_DROP_CFA FDB     forth_DROP_PFA           ;653D: 65 3F          'e?'
forth_DROP_PFA INS                              ;653F: 31             '1'
        INS                              ;6540: 31             '1'
        JMP     NEXT                     ;6541: 7E 61 30       '~a0'
;
; --- CODE: SWAP ---
forth_SWAP_NFA FCB     $84                      ;6544: 84             '.'
        FCC     "SWA"                    ;6545: 53 57 41       'SWA'
        FCB     $D0                      ;6548: D0             '.'
forth_SWAP_LFA FDB     forth_DROP_NFA           ;6549: 65 36          'e6'
forth_SWAP_CFA FDB     forth_SWAP_PFA           ;654B: 65 4D          'eM'
forth_SWAP_PFA PULA                             ;654D: 32             '2'
        PULB                             ;654E: 33             '3'
Z654F   PULX                             ;654F: 38             '8'
        PSHB                             ;6550: 37             '7'
        PSHA                             ;6551: 36             '6'
        PSHX                             ;6552: 3C             '<'
        JMP     NEXT                     ;6553: 7E 61 30       '~a0'
        STX     forth_IP_hi              ;6556: DF 80          '..'
        LDX     #forth_IP_hi             ;6558: CE 00 80       '...'
        JMP     Z612C                    ;655B: 7E 61 2C       '~a,'
;
; --- CODE: DUP ---
forth_DUP_NFA FCB     $83                      ;655E: 83             '.'
        FCC     "DU"                     ;655F: 44 55          'DU'
        FCB     $D0                      ;6561: D0             '.'
forth_DUP_LFA FDB     forth_SWAP_NFA           ;6562: 65 44          'eD'
forth_DUP_CFA FDB     forth_DUP_PFA            ;6564: 65 66          'ef'
forth_DUP_PFA PULA                             ;6566: 32             '2'
        PULB                             ;6567: 33             '3'
        PSHB                             ;6568: 37             '7'
        PSHA                             ;6569: 36             '6'
        JMP     PUSHD                    ;656A: 7E 61 2E       '~a.'
;
; --- CODE: +! ---
forth_PLUS_STORE_NFA FCB     $82                      ;656D: 82             '.'
        FCC     "+"                      ;656E: 2B             '+'
        FCB     $A1                      ;656F: A1             '.'
forth_PLUS_STORE_LFA FDB     forth_DUP_NFA            ;6570: 65 5E          'e^'
forth_PLUS_STORE_CFA FDB     forth_PLUS_STORE_PFA     ;6572: 65 74          'et'
forth_PLUS_STORE_PFA PULX                             ;6574: 38             '8'
        PULA                             ;6575: 32             '2'
        PULB                             ;6576: 33             '3'
        ADDD    ,X                       ;6577: E3 00          '..'
        STD     ,X                       ;6579: ED 00          '..'
        JMP     NEXT                     ;657B: 7E 61 30       '~a0'
        FCB     $00                      ;657E: 00             '.'
        JMP     NEXT                     ;657F: 7E 61 30       '~a0'
;
; --- :: TOGGLE ---
forth_TOGGLE_NFA FCB     $86                      ;6582: 86             '.'
        FCC     "TOGGL"                  ;6583: 54 4F 47 47 4C 'TOGGL'
        FCB     $C5                      ;6588: C5             '.'
forth_TOGGLE_LFA FDB     forth_PLUS_STORE_NFA     ;6589: 65 6D          'em'
forth_TOGGLE_CFA FDB     DOCOL                    ;658B: 65 F2          'e.'
forth_TOGGLE_PFA FDB     forth_OVER_CFA           ;658D: 65 2E          ; OVER
        FDB     forth_C_FETCH_CFA        ;658F: 65 AC          ; C@
        FDB     forth_XOR_CFA            ;6591: 64 02          ; XOR
        FDB     forth_SWAP_CFA           ;6593: 65 4B          ; SWAP
        FDB     forth_C_STORE_CFA        ;6595: 65 CC          ; C!
        FDB     forth_SEMIS_CFA          ;6597: 64 44          ; ;S
;
; --- CODE: @ ---
forth_FETCH_NFA FCB     $81,$C0                  ;6599: 81 C0          '..'
forth_FETCH_LFA FDB     forth_TOGGLE_NFA         ;659B: 65 82          'e.'
forth_FETCH_CFA FDB     forth_FETCH_PFA          ;659D: 65 9F          'e.'
forth_FETCH_PFA PULX                             ;659F: 38             '8'
        JMP     Z612C                    ;65A0: 7E 61 2C       '~a,'
        INS                              ;65A3: 31             '1'
        JMP     Z612C                    ;65A4: 7E 61 2C       '~a,'
;
; --- CODE: C@ ---
forth_C_FETCH_NFA FCB     $82                      ;65A7: 82             '.'
        FCC     "C"                      ;65A8: 43             'C'
        FCB     $C0                      ;65A9: C0             '.'
forth_C_FETCH_LFA FDB     forth_FETCH_NFA          ;65AA: 65 99          'e.'
forth_C_FETCH_CFA FDB     forth_C_FETCH_PFA        ;65AC: 65 AE          'e.'
forth_C_FETCH_PFA PULX                             ;65AE: 38             '8'
        CLRA                             ;65AF: 4F             'O'
        LDAB    ,X                       ;65B0: E6 00          '..'
        JMP     PUSHD                    ;65B2: 7E 61 2E       '~a.'
        INS                              ;65B5: 31             '1'
        JMP     PUSHD                    ;65B6: 7E 61 2E       '~a.'
;
; --- CODE: ! ---
forth_STORE_NFA FCB     $81,$A1                  ;65B9: 81 A1          '..'
forth_STORE_LFA FDB     forth_C_FETCH_NFA        ;65BB: 65 A7          'e.'
forth_STORE_CFA FDB     forth_STORE_PFA          ;65BD: 65 BF          'e.'
forth_STORE_PFA PULX                             ;65BF: 38             '8'
        JMP     Z6126                    ;65C0: 7E 61 26       '~a&'
        INS                              ;65C3: 31             '1'
        JMP     Z6126                    ;65C4: 7E 61 26       '~a&'
;
; --- CODE: C! ---
forth_C_STORE_NFA FCB     $82                      ;65C7: 82             '.'
        FCC     "C"                      ;65C8: 43             'C'
        FCB     $A1                      ;65C9: A1             '.'
forth_C_STORE_LFA FDB     forth_STORE_NFA          ;65CA: 65 B9          'e.'
forth_C_STORE_CFA FDB     forth_C_STORE_PFA        ;65CC: 65 CE          'e.'
forth_C_STORE_PFA PULX                             ;65CE: 38             '8'
        INS                              ;65CF: 31             '1'
        PULB                             ;65D0: 33             '3'
        STAB    ,X                       ;65D1: E7 00          '..'
        JMP     NEXT                     ;65D3: 7E 61 30       '~a0'
        FCB     $00                      ;65D6: 00             '.'
        JMP     NEXT                     ;65D7: 7E 61 30       '~a0'
;
; --- :: : [IMMEDIATE] ---
forth_COLON_NFA FCB     $C1,$BA                  ;65DA: C1 BA          '..'
forth_COLON_LFA FDB     forth_C_STORE_NFA        ;65DC: 65 C7          'e.'
forth_COLON_CFA FDB     DOCOL                    ;65DE: 65 F2          'e.'
forth_COLON_PFA FDB     forth_QUESTIONEXEC_CFA   ;65E0: 69 81          ; ?EXEC
        FDB     forth_STORECSP_CFA       ;65E2: 69 3D          ; !CSP
        FDB     forth_CURRENT_CFA        ;65E4: 67 47          ; CURRENT
        FDB     forth_FETCH_CFA          ;65E6: 65 9D          ; @
        FDB     forth_CONTEXT_CFA        ;65E8: 67 39          ; CONTEXT
        FDB     forth_STORE_CFA          ;65EA: 65 BD          ; !
        FDB     forth_CREATE_CFA         ;65EC: 6E 5E          ; CREATE
        FDB     forth_RBRACKET_CFA       ;65EE: 6A 02          ; ]
        FDB     forth_PAREN_SEMICODE_RPAREN_CFA ;65F0: 6A 51          ; (;CODE)
DOCOL   FDB     $DE94,$0909,$DF94,$DC92  ;65F2: DE 94 09 09 DF 94 DC 92 ; $DE94
        FDB     $ED02,$DE90,$7E61        ;65FA: ED 02 DE 90 7E 61 ; $ED02
        FDB     $32C1                    ;6600: 32 C1          ; $32C1
        FCB     $BB                      ;6602: BB             ; $BB65
forth_SEMI_LFA FDB     forth_COLON_NFA          ;6603: 65 DA          'e.'
forth_SEMI_CFA FDB     DOCOL                    ;6605: 65 F2          'e.'
forth_SEMI_PFA FDB     forth_QUESTIONCSP_CFA    ;6607: 69 A9          ; ?CSP
        FDB     forth_COMPILE_CFA        ;6609: 69 DE          ; COMPILE
        FDB     forth_SEMIS_CFA          ;660B: 64 44          ; ;S
        FDB     forth_SMUDGE_CFA         ;660D: 6A 16          'j.'
        FDB     forth_LBRACKET_CFA       ;660F: 69 F4          'i.'
        FDB     forth_SEMIS_CFA          ;6611: 64 44          'dD'
;
; --- :: CONSTANT ---
forth_CONSTANT_NFA FCB     $88                      ;6613: 88             '.'
        FCC     "CONSTAN"                ;6614: 43 4F 4E 53 54 41 4E ; $434F
        FCB     $D4                      ;661B: D4             '.'
forth_CONSTANT_LFA FDB     forth_SEMI_NFA           ;661C: 66 01          ; $6601
forth_CONSTANT_CFA FDB     DOCOL                    ;661E: 65 F2          ; $65F2
forth_CONSTANT_PFA FDB     forth_CREATE_CFA         ;6620: 6E 5E          ; CREATE
        FDB     forth_SMUDGE_CFA         ;6622: 6A 16          ; SMUDGE
        FDB     forth_COMMA_CFA          ;6624: 67 F8          ; ,
        FDB     forth_PAREN_SEMICODE_RPAREN_CFA ;6626: 6A 51          ; (;CODE)
DOCON   FDB     $DE90,$EC02,$7E61        ;6628: DE 90 EC 02 7E 61 ; $DE90
        FDB     $2E88                    ;662E: 2E 88          ; $2E88
        FCC     "VARIABL"                ;6630: 56 41 52 49 41 42 4C ; $5641
        FCB     $C5                      ;6637: C5             '.'
forth_VARIABLE_LFA FDB     forth_CONSTANT_NFA       ;6638: 66 13          ; $6613
forth_VARIABLE_CFA FDB     DOCOL                    ;663A: 65 F2          ; $65F2
forth_VARIABLE_PFA FDB     forth_CONSTANT_CFA       ;663C: 66 1E          ; CONSTANT
        FDB     forth_PAREN_SEMICODE_RPAREN_CFA ;663E: 6A 51          ; (;CODE)
        FDB     $DC90,$C300,$027E,PUSHD  ;6640: DC 90 C3 00 02 7E 61 2E ; $DC90
;
; --- :: USER ---
forth_USER_NFA FCB     $84                      ;6648: 84             ; $8455
        FCC     "USE"                    ;6649: 55 53 45       'USE'
        FCB     $D2                      ;664C: D2             ; $D266
forth_USER_LFA FDB     forth_VARIABLE_NFA       ;664D: 66 2F          'f/'
forth_USER_CFA FDB     DOCOL                    ;664F: 65 F2          'e.'
forth_USER_PFA FDB     forth_CONSTANT_CFA       ;6651: 66 1E          ; CONSTANT
        FDB     forth_PAREN_SEMICODE_RPAREN_CFA ;6653: 6A 51          ; (;CODE)
DOUSE   FDB     $DE90,$EC02,$D396,$7E61  ;6655: DE 90 EC 02 D3 96 7E 61 ; $DE90
        FDB     $2E81                    ;665D: 2E 81          ; $2E81
        FCB     $B0                      ;665F: B0             ; $B066
forth_0_LFA FDB     forth_USER_NFA           ;6660: 66 48          ; $6648
forth_0_CFA FDB     DOCON                    ;6662: 66 28          ; $6628
forth_0_PFA FDB     $0000                    ;6664: 00 00          ; $0000
;
; --- CONSTANT: 1 ---
forth_1_NFA FCB     $81,$B1                  ;6666: 81 B1          ; $81B1
forth_1_LFA FDB     forth_0_NFA              ;6668: 66 5E          ; $665E
forth_1_CFA FDB     DOCON                    ;666A: 66 28          ; $6628
forth_1_PFA FDB     M0001                    ;666C: 00 01          ; $0001
;
; --- CONSTANT: 2 ---
forth_2_NFA FCB     $81,$B2                  ;666E: 81 B2          ; $81B2
forth_2_LFA FDB     forth_1_NFA              ;6670: 66 66          ; $6666
forth_2_CFA FDB     DOCON                    ;6672: 66 28          ; $6628
forth_2_PFA FDB     $0002                    ;6674: 00 02          ; $0002
;
; --- CONSTANT: 3 ---
forth_3_NFA FCB     $81,$B3                  ;6676: 81 B3          ; $81B3
forth_3_LFA FDB     forth_2_NFA              ;6678: 66 6E          ; $666E
forth_3_CFA FDB     DOCON                    ;667A: 66 28          ; $6628
forth_3_PFA FDB     $0003                    ;667C: 00 03          ; $0003
;
; --- CONSTANT: BL ---
forth_BL_NFA FCB     $82                      ;667E: 82             ; $8242
        FCC     "B"                      ;667F: 42             ; $42CC
        FCB     $CC                      ;6680: CC             ; $CC66
forth_BL_LFA FDB     forth_3_NFA              ;6681: 66 76          ; $6676
forth_BL_CFA FDB     DOCON                    ;6683: 66 28          ; $6628
forth_BL_PFA FDB     $0020                    ;6685: 00 20          ; $0020
;
; --- CONSTANT: FIRST ---
forth_FIRST_NFA FCB     $85                      ;6687: 85             ; $8546
        FCC     "FIRS"                   ;6688: 46 49 52 53    ; $4649
        FCB     $D4                      ;668C: D4             ; $D466
forth_FIRST_LFA FDB     forth_BL_NFA             ;668D: 66 7E          ; $667E
forth_FIRST_CFA FDB     DOCON                    ;668F: 66 28          ; $6628
forth_FIRST_PFA FDB     $0710                    ;6691: 07 10          ; $0710
;
; --- CONSTANT: LIMIT ---
forth_LIMIT_NFA FCB     $85                      ;6693: 85             ; $854C
        FCC     "LIMI"                   ;6694: 4C 49 4D 49    ; $4C49
        FCB     $D4                      ;6698: D4             ; $D466
forth_LIMIT_LFA FDB     forth_FIRST_NFA          ;6699: 66 87          ; $6687
forth_LIMIT_CFA FDB     DOCON                    ;669B: 66 28          ; $6628
forth_LIMIT_PFA FDB     $0B30                    ;669D: 0B 30          ; $0B30
;
; --- :: +ORIGIN ---
forth_PLUSORIGIN_NFA FCB     $87                      ;669F: 87             ; $872B
        FCC     "+ORIGI"                 ;66A0: 2B 4F 52 49 47 49 ; $2B4F
        FCB     $CE                      ;66A6: CE             ; $CE66
forth_PLUSORIGIN_LFA FDB     forth_LIMIT_NFA          ;66A7: 66 93          ; $6693
forth_PLUSORIGIN_CFA FDB     DOCOL                    ;66A9: 65 F2          ; $65F2
forth_PLUSORIGIN_PFA FDB     forth_LIT_CFA            ;66AB: 61 45          ; LIT
        FDB     opt_rom_header           ;66AD: 60 00          ;   [24576 ($6000)]
        FDB     forth_PLUS_CFA           ;66AF: 64 C6          ; +
        FDB     forth_SEMIS_CFA          ;66B1: 64 44          ; ;S
;
; --- USER variable: TIB ---
forth_TIB_NFA FCB     $83                      ;66B3: 83             '.'
        FCC     "TI"                     ;66B4: 54 49          ; $5449
        FCB     $C2                      ;66B6: C2             ; $C266
forth_TIB_LFA FDB     forth_PLUSORIGIN_NFA     ;66B7: 66 9F          'f.'
forth_TIB_CFA FDB     DOUSE                    ;66B9: 66 55          'fU'
forth_TIB_PFA FDB     $000A                    ;66BB: 00 0A          ; user area offset 10 ($000A)
;
; --- USER variable: WIDTH ---
forth_WIDTH_NFA FCB     $85                      ;66BD: 85             '.'
        FCC     "WIDT"                   ;66BE: 57 49 44 54    ; $5749
        FCB     $C8                      ;66C2: C8             ; $C866
forth_WIDTH_LFA FDB     forth_TIB_NFA            ;66C3: 66 B3          'f.'
forth_WIDTH_CFA FDB     DOUSE                    ;66C5: 66 55          'fU'
forth_WIDTH_PFA FDB     $000C                    ;66C7: 00 0C          ; user area offset 12 ($000C)
;
; --- USER variable: WARNING ---
forth_WARNING_NFA FCB     $87                      ;66C9: 87             '.'
        FCC     "WARNIN"                 ;66CA: 57 41 52 4E 49 4E ; $5741
        FCB     $C7                      ;66D0: C7             ; $C766
forth_WARNING_LFA FDB     forth_WIDTH_NFA          ;66D1: 66 BD          'f.'
forth_WARNING_CFA FDB     DOUSE                    ;66D3: 66 55          'fU'
forth_WARNING_PFA FDB     $000E                    ;66D5: 00 0E          ; user area offset 14 ($000E)
;
; --- USER variable: FENCE ---
forth_FENCE_NFA FCB     $85                      ;66D7: 85             '.'
        FCC     "FENC"                   ;66D8: 46 45 4E 43    ; $4645
        FCB     $C5                      ;66DC: C5             ; $C566
forth_FENCE_LFA FDB     forth_WARNING_NFA        ;66DD: 66 C9          'f.'
forth_FENCE_CFA FDB     DOUSE                    ;66DF: 66 55          'fU'
forth_FENCE_PFA FDB     $0010                    ;66E1: 00 10          ; user area offset 16 ($0010)
;
; --- USER variable: DP ---
forth_DP_NFA FCB     $82                      ;66E3: 82             '.'
        FCC     "D"                      ;66E4: 44             ; $44D0
        FCB     $D0                      ;66E5: D0             '.'
forth_DP_LFA FDB     forth_FENCE_NFA          ;66E6: 66 D7          ; $66D7
forth_DP_CFA FDB     DOUSE                    ;66E8: 66 55          ; $6655
forth_DP_PFA FDB     $0012                    ;66EA: 00 12          ; $0012
;
; --- USER variable: VOC-LINK ---
forth_VOC_MINUSLINK_NFA FCB     $88                      ;66EC: 88             ; $8856
        FCC     "VOC-LIN"                ;66ED: 56 4F 43 2D 4C 49 4E 'VOC-LIN'
        FCB     $CB                      ;66F4: CB             ; $CB66
forth_VOC_MINUSLINK_LFA FDB     forth_DP_NFA             ;66F5: 66 E3          'f.'
forth_VOC_MINUSLINK_CFA FDB     DOUSE                    ;66F7: 66 55          'fU'
forth_VOC_MINUSLINK_PFA FDB     $0014                    ;66F9: 00 14          ; user area offset 20 ($0014)
;
; --- USER variable: BLK ---
forth_BLK_NFA FCB     $83                      ;66FB: 83             '.'
        FCC     "BL"                     ;66FC: 42 4C          ; $424C
        FCB     $CB                      ;66FE: CB             ; $CB66
forth_BLK_LFA FDB     forth_VOC_MINUSLINK_NFA  ;66FF: 66 EC          'f.'
forth_BLK_CFA FDB     DOUSE                    ;6701: 66 55          'fU'
forth_BLK_PFA FDB     $0016                    ;6703: 00 16          ; user area offset 22 ($0016)
;
; --- USER variable: IN ---
forth_IN_NFA FCB     $82                      ;6705: 82             '.'
        FCC     "I"                      ;6706: 49             ; $49CE
        FCB     $CE                      ;6707: CE             '.'
forth_IN_LFA FDB     forth_BLK_NFA            ;6708: 66 FB          ; $66FB
forth_IN_CFA FDB     DOUSE                    ;670A: 66 55          ; $6655
forth_IN_PFA FDB     $0018                    ;670C: 00 18          ; $0018
;
; --- USER variable: OUT ---
forth_OUT_NFA FCB     $83                      ;670E: 83             ; $834F
        FCC     "OU"                     ;670F: 4F 55          'OU'
        FCB     $D4                      ;6711: D4             '.'
forth_OUT_LFA FDB     forth_IN_NFA             ;6712: 67 05          ; $6705
forth_OUT_CFA FDB     DOUSE                    ;6714: 66 55          ; $6655
forth_OUT_PFA FDB     $001A                    ;6716: 00 1A          ; $001A
;
; --- USER variable: SCR ---
forth_SCR_NFA FCB     $83                      ;6718: 83             ; $8353
        FCC     "SC"                     ;6719: 53 43          'SC'
        FCB     $D2                      ;671B: D2             '.'
forth_SCR_LFA FDB     forth_OUT_NFA            ;671C: 67 0E          ; $670E
forth_SCR_CFA FDB     DOUSE                    ;671E: 66 55          ; $6655
forth_SCR_PFA FDB     $001C                    ;6720: 00 1C          ; $001C
;
; --- USER variable: OFFSET ---
forth_OFFSET_NFA FCB     $86                      ;6722: 86             ; $864F
        FCC     "OFFSE"                  ;6723: 4F 46 46 53 45 'OFFSE'
        FCB     $D4                      ;6728: D4             ; $D467
forth_OFFSET_LFA FDB     forth_SCR_NFA            ;6729: 67 18          'g.'
forth_OFFSET_CFA FDB     DOUSE                    ;672B: 66 55          'fU'
forth_OFFSET_PFA FDB     $001E                    ;672D: 00 1E          ; user area offset 30 ($001E)
;
; --- USER variable: CONTEXT ---
forth_CONTEXT_NFA FCB     $87                      ;672F: 87             '.'
        FCC     "CONTEX"                 ;6730: 43 4F 4E 54 45 58 ; $434F
        FCB     $D4                      ;6736: D4             ; $D467
forth_CONTEXT_LFA FDB     forth_OFFSET_NFA         ;6737: 67 22          'g"'
forth_CONTEXT_CFA FDB     DOUSE                    ;6739: 66 55          'fU'
forth_CONTEXT_PFA FDB     $0020                    ;673B: 00 20          ; user area offset 32 ($0020)
;
; --- USER variable: CURRENT ---
forth_CURRENT_NFA FCB     $87                      ;673D: 87             '.'
        FCC     "CURREN"                 ;673E: 43 55 52 52 45 4E ; $4355
        FCB     $D4                      ;6744: D4             ; $D467
forth_CURRENT_LFA FDB     forth_CONTEXT_NFA        ;6745: 67 2F          'g/'
forth_CURRENT_CFA FDB     DOUSE                    ;6747: 66 55          'fU'
forth_CURRENT_PFA FDB     $0022                    ;6749: 00 22          ; user area offset 34 ($0022)
;
; --- USER variable: STATE ---
forth_STATE_NFA FCB     $85                      ;674B: 85             '.'
        FCC     "STAT"                   ;674C: 53 54 41 54    ; $5354
        FCB     $C5                      ;6750: C5             ; $C567
forth_STATE_LFA FDB     forth_CURRENT_NFA        ;6751: 67 3D          'g='
forth_STATE_CFA FDB     DOUSE                    ;6753: 66 55          'fU'
forth_STATE_PFA FDB     $0024                    ;6755: 00 24          ; user area offset 36 ($0024)
;
; --- USER variable: BASE ---
forth_BASE_NFA FCB     $84                      ;6757: 84             '.'
        FCC     "BAS"                    ;6758: 42 41 53       ; $4241
        FCB     $C5                      ;675B: C5             '.'
forth_BASE_LFA FDB     forth_STATE_NFA          ;675C: 67 4B          ; $674B
forth_BASE_CFA FDB     DOUSE                    ;675E: 66 55          ; $6655
forth_BASE_PFA FDB     $0026                    ;6760: 00 26          ; $0026
;
; --- USER variable: DPL ---
forth_DPL_NFA FCB     $83                      ;6762: 83             ; $8344
        FCC     "DP"                     ;6763: 44 50          'DP'
        FCB     $CC                      ;6765: CC             '.'
forth_DPL_LFA FDB     forth_BASE_NFA           ;6766: 67 57          ; $6757
forth_DPL_CFA FDB     DOUSE                    ;6768: 66 55          ; $6655
forth_DPL_PFA FDB     $0028                    ;676A: 00 28          ; $0028
;
; --- USER variable: FLD ---
forth_FLD_NFA FCB     $83                      ;676C: 83             ; $8346
        FCC     "FL"                     ;676D: 46 4C          'FL'
        FCB     $C4                      ;676F: C4             '.'
forth_FLD_LFA FDB     forth_DPL_NFA            ;6770: 67 62          ; $6762
forth_FLD_CFA FDB     DOUSE                    ;6772: 66 55          ; $6655
forth_FLD_PFA FDB     $002A                    ;6774: 00 2A          ; $002A
;
; --- USER variable: CSP ---
forth_CSP_NFA FCB     $83                      ;6776: 83             ; $8343
        FCC     "CS"                     ;6777: 43 53          'CS'
        FCB     $D0                      ;6779: D0             '.'
forth_CSP_LFA FDB     forth_FLD_NFA            ;677A: 67 6C          ; $676C
forth_CSP_CFA FDB     DOUSE                    ;677C: 66 55          ; $6655
forth_CSP_PFA FDB     $002C                    ;677E: 00 2C          ; $002C
;
; --- USER variable: R# ---
forth_R_HASH_NFA FCB     $82                      ;6780: 82             ; $8252
        FCC     "R"                      ;6781: 52             'R'
        FCB     $A3                      ;6782: A3             ; $A367
forth_R_HASH_LFA FDB     forth_CSP_NFA            ;6783: 67 76          'gv'
forth_R_HASH_CFA FDB     DOUSE                    ;6785: 66 55          'fU'
forth_R_HASH_PFA FDB     $002E                    ;6787: 00 2E          ; user area offset 46 ($002E)
;
; --- USER variable: HLD ---
forth_HLD_NFA FCB     $83                      ;6789: 83             '.'
        FCC     "HL"                     ;678A: 48 4C          ; $484C
        FCB     $C4                      ;678C: C4             ; $C467
forth_HLD_LFA FDB     forth_R_HASH_NFA         ;678D: 67 80          'g.'
forth_HLD_CFA FDB     DOUSE                    ;678F: 66 55          'fU'
forth_HLD_PFA FDB     $0030                    ;6791: 00 30          ; user area offset 48 ($0030)
;
; --- CONSTANT: C/L ---
forth_C_SLASHL_NFA FCB     $83                      ;6793: 83             '.'
        FCC     "C/"                     ;6794: 43 2F          ; $432F
        FCB     $CC                      ;6796: CC             ; $CC67
forth_C_SLASHL_LFA FDB     forth_HLD_NFA            ;6797: 67 89          'g.'
forth_C_SLASHL_CFA FDB     DOCON                    ;6799: 66 28          'f('
forth_C_SLASHL_PFA FDB     $0040                    ;679B: 00 40          ; = 64 ($0040)
;
; --- CODE: 1+ ---
forth_1_PLUS_NFA FCB     $82                      ;679D: 82             '.'
        FCC     "1"                      ;679E: 31             ; $31AB
        FCB     $AB                      ;679F: AB             '.'
forth_1_PLUS_LFA FDB     forth_C_SLASHL_NFA       ;67A0: 67 93          ; $6793
forth_1_PLUS_CFA FDB     forth_1_PLUS_PFA         ;67A2: 67 A4          ; $67A4
forth_1_PLUS_PFA PULX                             ;67A4: 38             ; $3808
Z67A5   INX                              ;67A5: 08             '.'
        PSHX                             ;67A6: 3C             ; $3C7E
        JMP     NEXT                     ;67A7: 7E 61 30       '~a0'
;
; --- CODE: 2+ ---
forth_2_PLUS_NFA FCB     $82                      ;67AA: 82             ; $8232
        FCC     "2"                      ;67AB: 32             '2'
        FCB     $AB                      ;67AC: AB             ; $AB67
forth_2_PLUS_LFA FDB     forth_1_PLUS_NFA         ;67AD: 67 9D          'g.'
forth_2_PLUS_CFA FDB     forth_2_PLUS_PFA         ;67AF: 67 B1          'g.'
forth_2_PLUS_PFA PULX                             ;67B1: 38             '8'
        INX                              ;67B2: 08             ; $0820
        BRA     Z67A5                    ;67B3: 20 F0          ' .'
        NOP                              ;67B5: 01             '.'
        SUBD    #M8448                   ;67B6: 83 84 48       ; $8384
        FCC     "ER"                     ;67B9: 45 52          'ER'
        FCB     $C5                      ;67BB: C5             '.'
forth_HERE_LFA FDB     forth_2_PLUS_NFA         ;67BC: 67 AA          ; $67AA
forth_HERE_CFA FDB     DOCOL                    ;67BE: 65 F2          ; $65F2
forth_HERE_PFA FDB     forth_DP_CFA             ;67C0: 66 E8          ; DP
        FDB     forth_FETCH_CFA          ;67C2: 65 9D          ; @
        FDB     forth_SEMIS_CFA          ;67C4: 64 44          ; ;S
;
; --- CODE: 2DROP ---
forth_2DROP_NFA FCB     $85                      ;67C6: 85             '.'
        FCC     "2DRO"                   ;67C7: 32 44 52 4F    '2DRO'
        FCB     $D0                      ;67CB: D0             '.'
forth_2DROP_LFA FDB     forth_HERE_NFA           ;67CC: 67 B7          'g.'
forth_2DROP_CFA FDB     forth_2DROP_PFA          ;67CE: 67 D0          'g.'
forth_2DROP_PFA INS                              ;67D0: 31             '1'
        INS                              ;67D1: 31             '1'
        JMP     forth_DROP_PFA           ;67D2: 7E 65 3F       '~e?'
;
; --- :: 2DUP ---
forth_2DUP_NFA FCB     $84                      ;67D5: 84             '.'
        FCC     "2DU"                    ;67D6: 32 44 55       '2DU'
        FCB     $D0                      ;67D9: D0             '.'
forth_2DUP_LFA FDB     forth_2DROP_NFA          ;67DA: 67 C6          'g.'
forth_2DUP_CFA FDB     DOCOL                    ;67DC: 65 F2          'e.'
forth_2DUP_PFA FDB     forth_OVER_CFA           ;67DE: 65 2E          ; OVER
        FDB     forth_OVER_CFA           ;67E0: 65 2E          ; OVER
        FDB     forth_SEMIS_CFA          ;67E2: 64 44          ; ;S
;
; --- :: ALLOT ---
forth_ALLOT_NFA FCB     $85                      ;67E4: 85             '.'
        FCC     "ALLO"                   ;67E5: 41 4C 4C 4F    'ALLO'
        FCB     $D4                      ;67E9: D4             '.'
forth_ALLOT_LFA FDB     forth_2DUP_NFA           ;67EA: 67 D5          'g.'
forth_ALLOT_CFA FDB     DOCOL                    ;67EC: 65 F2          'e.'
forth_ALLOT_PFA FDB     forth_DP_CFA             ;67EE: 66 E8          ; DP
        FDB     forth_PLUS_STORE_CFA     ;67F0: 65 72          ; +!
        FDB     forth_SEMIS_CFA          ;67F2: 64 44          ; ;S
;
; --- :: , ---
forth_COMMA_NFA FCB     $81,$AC                  ;67F4: 81 AC          '..'
forth_COMMA_LFA FDB     forth_ALLOT_NFA          ;67F6: 67 E4          'g.'
forth_COMMA_CFA FDB     DOCOL                    ;67F8: 65 F2          'e.'
forth_COMMA_PFA FDB     forth_HERE_CFA           ;67FA: 67 BE          ; HERE
        FDB     forth_STORE_CFA          ;67FC: 65 BD          ; !
        FDB     forth_2_CFA              ;67FE: 66 72          ; 2
        FDB     forth_ALLOT_CFA          ;6800: 67 EC          ; ALLOT
        FDB     forth_SEMIS_CFA          ;6802: 64 44          ; ;S
;
; --- :: C, ---
forth_C_COMMA_NFA FCB     $82                      ;6804: 82             '.'
        FCC     "C"                      ;6805: 43             'C'
        FCB     $AC                      ;6806: AC             '.'
forth_C_COMMA_LFA FDB     forth_COMMA_NFA          ;6807: 67 F4          'g.'
forth_C_COMMA_CFA FDB     DOCOL                    ;6809: 65 F2          'e.'
forth_C_COMMA_PFA FDB     forth_HERE_CFA           ;680B: 67 BE          ; HERE
        FDB     forth_C_STORE_CFA        ;680D: 65 CC          ; C!
        FDB     forth_1_CFA              ;680F: 66 6A          ; 1
        FDB     forth_ALLOT_CFA          ;6811: 67 EC          ; ALLOT
        FDB     forth_SEMIS_CFA          ;6813: 64 44          ; ;S
;
; --- :: - ---
forth_MINUS_NFA FCB     $81,$AD                  ;6815: 81 AD          '..'
forth_MINUS_LFA FDB     forth_C_COMMA_NFA        ;6817: 68 04          'h.'
forth_MINUS_CFA FDB     DOCOL                    ;6819: 65 F2          'e.'
forth_MINUS_PFA FDB     forth_MINUS_CFA          ;681B: 64 F4          ; MINUS
        FDB     forth_PLUS_CFA           ;681D: 64 C6          ; +
        FDB     forth_SEMIS_CFA          ;681F: 64 44          ; ;S
;
; --- :: = ---
forth_EQ_NFA FCB     $81,$BD                  ;6821: 81 BD          '..'
forth_EQ_LFA FDB     forth_MINUS_NFA          ;6823: 68 15          'h.'
forth_EQ_CFA FDB     DOCOL                    ;6825: 65 F2          'e.'
forth_EQ_PFA FDB     forth_MINUS_CFA          ;6827: 68 19          ; -
        FDB     forth_0_EQ_CFA           ;6829: 64 9C          ; 0=
        FDB     forth_SEMIS_CFA          ;682B: 64 44          ; ;S
;
; --- CODE: < ---
forth_LT_NFA FCB     $81,$BC                  ;682D: 81 BC          '..'
forth_LT_LFA FDB     forth_EQ_NFA             ;682F: 68 21          'h!'
forth_LT_CFA FDB     forth_LT_PFA             ;6831: 68 33          'h3'
forth_LT_PFA PULA                             ;6833: 32             '2'
        PULB                             ;6834: 33             '3'
Z6835   TSX                              ;6835: 30             '0'
        CMPA    ,X                       ;6836: A1 00          '..'
        INS                              ;6838: 31             '1'
        BGT     Z6844                    ;6839: 2E 09          '..'
        BNE     Z6841                    ;683B: 26 04          '&.'
        CMPB    $01,X                    ;683D: E1 01          '..'
        BHI     Z6844                    ;683F: 22 03          '".'
Z6841   CLRB                             ;6841: 5F             '_'
        BRA     Z6846                    ;6842: 20 02          ' .'
Z6844   LDAB    #$01                     ;6844: C6 01          '..'
Z6846   CLRA                             ;6846: 4F             'O'
        INS                              ;6847: 31             '1'
        JMP     PUSHD                    ;6848: 7E 61 2E       '~a.'
;
; --- CODE: > ---
forth_GT_NFA FCB     $81,$BE                  ;684B: 81 BE          '..'
forth_GT_LFA FDB     forth_LT_NFA             ;684D: 68 2D          'h-'
forth_GT_CFA FDB     forth_GT_PFA             ;684F: 68 51          'hQ'
forth_GT_PFA PULX                             ;6851: 38             '8'
        PULA                             ;6852: 32             '2'
        PULB                             ;6853: 33             '3'
        PSHX                             ;6854: 3C             '<'
        BRA     Z6835                    ;6855: 20 DE          ' .'
;
; --- :: ROT ---
forth_ROT_NFA FCB     $83                      ;6857: 83             '.'
        FCC     "RO"                     ;6858: 52 4F          'RO'
        FCB     $D4                      ;685A: D4             '.'
forth_ROT_LFA FDB     forth_GT_NFA             ;685B: 68 4B          'hK'
forth_ROT_CFA FDB     DOCOL                    ;685D: 65 F2          'e.'
forth_ROT_PFA FDB     forth_GTR_CFA            ;685F: 64 69          ; >R
        FDB     forth_SWAP_CFA           ;6861: 65 4B          ; SWAP
        FDB     forth_R_GT_CFA           ;6863: 64 7D          ; R>
        FDB     forth_SWAP_CFA           ;6865: 65 4B          ; SWAP
        FDB     forth_SEMIS_CFA          ;6867: 64 44          ; ;S
;
; --- :: SPACE ---
forth_SPACE_NFA FCB     $85                      ;6869: 85             '.'
        FCC     "SPAC"                   ;686A: 53 50 41 43    'SPAC'
        FCB     $C5                      ;686E: C5             '.'
forth_SPACE_LFA FDB     forth_ROT_NFA            ;686F: 68 57          'hW'
forth_SPACE_CFA FDB     DOCOL                    ;6871: 65 F2          'e.'
forth_SPACE_PFA FDB     forth_BL_CFA             ;6873: 66 83          ; BL
        FDB     forth_EMIT_CFA           ;6875: 63 02          ; EMIT
        FDB     forth_SEMIS_CFA          ;6877: 64 44          ; ;S
;
; --- :: MIN ---
forth_MIN_NFA FCB     $83                      ;6879: 83             '.'
        FCC     "MI"                     ;687A: 4D 49          'MI'
        FCB     $CE                      ;687C: CE             '.'
forth_MIN_LFA FDB     forth_SPACE_NFA          ;687D: 68 69          'hi'
forth_MIN_CFA FDB     DOCOL                    ;687F: 65 F2          'e.'
forth_MIN_PFA FDB     forth_2DUP_CFA           ;6881: 67 DC          ; 2DUP
        FDB     forth_GT_CFA             ;6883: 68 4F          ; >
        FDB     forth_0BRANCH_CFA,M0004  ;6885: 61 88 00 04    ; 0BRANCH
        FDB     forth_SWAP_CFA           ;6889: 65 4B          ; SWAP
        FDB     forth_DROP_CFA           ;688B: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;688D: 64 44          ; ;S
;
; --- :: MAX ---
forth_MAX_NFA FCB     $83                      ;688F: 83             '.'
        FCC     "MA"                     ;6890: 4D 41          'MA'
        FCB     $D8                      ;6892: D8             '.'
forth_MAX_LFA FDB     forth_MIN_NFA            ;6893: 68 79          'hy'
forth_MAX_CFA FDB     DOCOL                    ;6895: 65 F2          'e.'
forth_MAX_PFA FDB     forth_2DUP_CFA           ;6897: 67 DC          ; 2DUP
        FDB     forth_LT_CFA             ;6899: 68 31          ; <
        FDB     forth_0BRANCH_CFA,M0004  ;689B: 61 88 00 04    ; 0BRANCH
        FDB     forth_SWAP_CFA           ;689F: 65 4B          ; SWAP
        FDB     forth_DROP_CFA           ;68A1: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;68A3: 64 44          ; ;S
;
; --- :: -DUP ---
forth_MINUSDUP_NFA FCB     $84                      ;68A5: 84             '.'
        FCC     "-DU"                    ;68A6: 2D 44 55       '-DU'
        FCB     $D0                      ;68A9: D0             '.'
forth_MINUSDUP_LFA FDB     forth_MAX_NFA            ;68AA: 68 8F          'h.'
forth_MINUSDUP_CFA FDB     DOCOL                    ;68AC: 65 F2          'e.'
forth_MINUSDUP_PFA FDB     forth_DUP_CFA            ;68AE: 65 64          ; DUP
        FDB     forth_0BRANCH_CFA,M0004  ;68B0: 61 88 00 04    ; 0BRANCH
        FDB     forth_DUP_CFA            ;68B4: 65 64          ; DUP
        FDB     forth_SEMIS_CFA          ;68B6: 64 44          ; ;S
;
; --- :: TRAVERSE ---
forth_TRAVERSE_NFA FCB     $88                      ;68B8: 88             '.'
        FCC     "TRAVERS"                ;68B9: 54 52 41 56 45 52 53 'TRAVERS'
        FCB     $C5                      ;68C0: C5             '.'
forth_TRAVERSE_LFA FDB     forth_MINUSDUP_NFA       ;68C1: 68 A5          'h.'
forth_TRAVERSE_CFA FDB     DOCOL                    ;68C3: 65 F2          'e.'
forth_TRAVERSE_PFA FDB     forth_SWAP_CFA           ;68C5: 65 4B          ; SWAP
        FDB     forth_OVER_CFA           ;68C7: 65 2E          ; OVER
        FDB     forth_PLUS_CFA,CLIT      ;68C9: 64 C6 61 52    ; +
        FDB     $7F65,$2E65,$AC68,$3161  ;68CD: 7F 65 2E 65 AC 68 31 61 ;   [char $7F]
        FDB     $88FF,$F165,$4B65,$3D64  ;68D5: 88 FF F1 65 4B 65 3D 64 '...eKe=d'
        FDB     $4486                    ;68DD: 44 86          'D.'
        FCC     "LATES"                  ;68DF: 4C 41 54 45 53 'LATES'
        FCB     $D4                      ;68E4: D4             '.'
forth_LATEST_LFA FDB     forth_TRAVERSE_NFA       ;68E5: 68 B8          'h.'
forth_LATEST_CFA FDB     DOCOL                    ;68E7: 65 F2          'e.'
forth_LATEST_PFA FDB     forth_CURRENT_CFA        ;68E9: 67 47          ; CURRENT
        FDB     forth_FETCH_CFA          ;68EB: 65 9D          ; @
        FDB     forth_FETCH_CFA          ;68ED: 65 9D          ; @
        FDB     forth_SEMIS_CFA          ;68EF: 64 44          ; ;S
;
; --- :: LFA ---
forth_LFA_NFA FCB     $83                      ;68F1: 83             '.'
        FCC     "LF"                     ;68F2: 4C 46          'LF'
        FCB     $C1                      ;68F4: C1             '.'
forth_LFA_LFA FDB     forth_LATEST_NFA         ;68F5: 68 DE          'h.'
forth_LFA_CFA FDB     DOCOL                    ;68F7: 65 F2          'e.'
forth_LFA_PFA FDB     CLIT,$0468,$1964         ;68F9: 61 52 04 68 19 64 ; CLIT
        FDB     $4483                    ;68FF: 44 83          'D.'
        FCC     "CF"                     ;6901: 43 46          'CF'
        FCB     $C1                      ;6903: C1             '.'
forth_CFA_LFA FDB     forth_LFA_NFA            ;6904: 68 F1          'h.'
forth_CFA_CFA FDB     DOCOL                    ;6906: 65 F2          'e.'
forth_CFA_PFA FDB     forth_2_CFA              ;6908: 66 72          ; 2
        FDB     forth_MINUS_CFA          ;690A: 68 19          ; -
        FDB     forth_SEMIS_CFA          ;690C: 64 44          ; ;S
;
; --- :: NFA ---
forth_NFA_NFA FCB     $83                      ;690E: 83             '.'
        FCC     "NF"                     ;690F: 4E 46          'NF'
        FCB     $C1                      ;6911: C1             '.'
forth_NFA_LFA FDB     forth_CFA_NFA            ;6912: 69 00          'i.'
forth_NFA_CFA FDB     DOCOL                    ;6914: 65 F2          'e.'
forth_NFA_PFA FDB     CLIT,$0568,$1966,$6A64   ;6916: 61 52 05 68 19 66 6A 64 ; CLIT
        FDB     $F468,$C364              ;691E: F4 68 C3 64    '.h.d'
        FDB     $4483                    ;6922: 44 83          'D.'
        FCC     "PF"                     ;6924: 50 46          'PF'
        FCB     $C1                      ;6926: C1             '.'
forth_PFA_LFA FDB     forth_NFA_NFA            ;6927: 69 0E          'i.'
forth_PFA_CFA FDB     DOCOL                    ;6929: 65 F2          'e.'
forth_PFA_PFA FDB     forth_1_CFA              ;692B: 66 6A          ; 1
        FDB     forth_TRAVERSE_CFA,CLIT  ;692D: 68 C3 61 52    ; TRAVERSE
        FDB     $0564,$C664              ;6931: 05 64 C6 64    ;   [char $05]
        FDB     $4484                    ;6935: 44 84          'D.'
        FCC     "!CS"                    ;6937: 21 43 53       '!CS'
        FCB     $D0                      ;693A: D0             '.'
forth_STORECSP_LFA FDB     forth_PFA_NFA            ;693B: 69 23          'i#'
forth_STORECSP_CFA FDB     DOCOL                    ;693D: 65 F2          'e.'
forth_STORECSP_PFA FDB     forth_SP_FETCH_CFA       ;693F: 64 14          ; SP@
        FDB     forth_CSP_CFA            ;6941: 67 7C          ; CSP
        FDB     forth_STORE_CFA          ;6943: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;6945: 64 44          ; ;S
;
; --- :: ?ERROR ---
forth_QUESTIONERROR_NFA FCB     $86                      ;6947: 86             '.'
        FCC     "?ERRO"                  ;6948: 3F 45 52 52 4F '?ERRO'
        FCB     $D2                      ;694D: D2             '.'
forth_QUESTIONERROR_LFA FDB     forth_STORECSP_NFA       ;694E: 69 36          'i6'
forth_QUESTIONERROR_CFA FDB     DOCOL                    ;6950: 65 F2          'e.'
forth_QUESTIONERROR_PFA FDB     forth_SWAP_CFA           ;6952: 65 4B          ; SWAP
        FDB     forth_0BRANCH_CFA,M0008  ;6954: 61 88 00 08    ; 0BRANCH
        FDB     forth_ERROR_CFA          ;6958: 6D F1          ; ERROR
        FDB     forth_BRANCH_CFA,M0004   ;695A: 61 7C 00 04    ; BRANCH
        FDB     forth_DROP_CFA           ;695E: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;6960: 64 44          ; ;S
;
; --- :: ?COMP ---
forth_QUESTIONCOMP_NFA FCB     $85                      ;6962: 85             '.'
        FCC     "?COM"                   ;6963: 3F 43 4F 4D    '?COM'
        FCB     $D0                      ;6967: D0             '.'
forth_QUESTIONCOMP_LFA FDB     forth_QUESTIONERROR_NFA  ;6968: 69 47          'iG'
forth_QUESTIONCOMP_CFA FDB     DOCOL                    ;696A: 65 F2          'e.'
forth_QUESTIONCOMP_PFA FDB     forth_STATE_CFA          ;696C: 67 53          ; STATE
        FDB     forth_FETCH_CFA          ;696E: 65 9D          ; @
        FDB     forth_0_EQ_CFA,CLIT      ;6970: 64 9C 61 52    ; 0=
        FDB     $1169,$5064              ;6974: 11 69 50 64    ;   [char $11]
        FDB     $4485                    ;6978: 44 85          'D.'
        FCC     "?EXE"                   ;697A: 3F 45 58 45    '?EXE'
        FCB     $C3                      ;697E: C3             '.'
forth_QUESTIONEXEC_LFA FDB     forth_QUESTIONCOMP_NFA   ;697F: 69 62          'ib'
forth_QUESTIONEXEC_CFA FDB     DOCOL                    ;6981: 65 F2          'e.'
forth_QUESTIONEXEC_PFA FDB     forth_STATE_CFA          ;6983: 67 53          ; STATE
        FDB     forth_FETCH_CFA,CLIT     ;6985: 65 9D 61 52    ; @
        FDB     $1269,$5064              ;6989: 12 69 50 64    ;   [char $12]
        FDB     $4486                    ;698D: 44 86          'D.'
        FCC     "?PAIR"                  ;698F: 3F 50 41 49 52 '?PAIR'
        FCB     $D3                      ;6994: D3             '.'
forth_QUESTIONPAIRS_LFA FDB     forth_QUESTIONEXEC_NFA   ;6995: 69 79          'iy'
forth_QUESTIONPAIRS_CFA FDB     DOCOL                    ;6997: 65 F2          'e.'
forth_QUESTIONPAIRS_PFA FDB     forth_MINUS_CFA,CLIT     ;6999: 68 19 61 52    ; -
        FDB     $1369,$5064              ;699D: 13 69 50 64    ;   [char $13]
        FDB     $4484                    ;69A1: 44 84          'D.'
        FCC     "?CS"                    ;69A3: 3F 43 53       '?CS'
        FCB     $D0                      ;69A6: D0             '.'
forth_QUESTIONCSP_LFA FDB     forth_QUESTIONPAIRS_NFA  ;69A7: 69 8E          'i.'
forth_QUESTIONCSP_CFA FDB     DOCOL                    ;69A9: 65 F2          'e.'
forth_QUESTIONCSP_PFA FDB     forth_SP_FETCH_CFA       ;69AB: 64 14          ; SP@
        FDB     forth_CSP_CFA            ;69AD: 67 7C          ; CSP
        FDB     forth_FETCH_CFA          ;69AF: 65 9D          ; @
        FDB     forth_MINUS_CFA,CLIT     ;69B1: 68 19 61 52    ; -
        FDB     $1469,$5064              ;69B5: 14 69 50 64    ;   [char $14]
        FDB     $4488                    ;69B9: 44 88          'D.'
        FCC     "?LOADIN"                ;69BB: 3F 4C 4F 41 44 49 4E '?LOADIN'
        FCB     $C7                      ;69C2: C7             '.'
forth_QUESTIONLOADING_LFA FDB     forth_QUESTIONCSP_NFA    ;69C3: 69 A2          'i.'
forth_QUESTIONLOADING_CFA FDB     DOCOL                    ;69C5: 65 F2          'e.'
forth_QUESTIONLOADING_PFA FDB     forth_BLK_CFA            ;69C7: 67 01          ; BLK
        FDB     forth_FETCH_CFA          ;69C9: 65 9D          ; @
        FDB     forth_0_EQ_CFA,CLIT      ;69CB: 64 9C 61 52    ; 0=
        FDB     $1669,$5064              ;69CF: 16 69 50 64    ;   [char $16]
        FDB     $4487                    ;69D3: 44 87          'D.'
        FCC     "COMPIL"                 ;69D5: 43 4F 4D 50 49 4C 'COMPIL'
        FCB     $C5                      ;69DB: C5             '.'
forth_COMPILE_LFA FDB     forth_QUESTIONLOADING_NFA ;69DC: 69 BA          'i.'
forth_COMPILE_CFA FDB     DOCOL                    ;69DE: 65 F2          'e.'
forth_COMPILE_PFA FDB     forth_QUESTIONCOMP_CFA   ;69E0: 69 6A          ; ?COMP
        FDB     forth_R_GT_CFA           ;69E2: 64 7D          ; R>
        FDB     forth_2_PLUS_CFA         ;69E4: 67 AF          ; 2+
        FDB     forth_DUP_CFA            ;69E6: 65 64          ; DUP
        FDB     forth_GTR_CFA            ;69E8: 64 69          ; >R
        FDB     forth_FETCH_CFA          ;69EA: 65 9D          ; @
        FDB     forth_COMMA_CFA          ;69EC: 67 F8          ; ,
        FDB     forth_SEMIS_CFA          ;69EE: 64 44          ; ;S
;
; --- :: [ [IMMEDIATE] ---
forth_LBRACKET_NFA FCB     $C1,$DB                  ;69F0: C1 DB          '..'
forth_LBRACKET_LFA FDB     forth_COMPILE_NFA        ;69F2: 69 D4          'i.'
forth_LBRACKET_CFA FDB     DOCOL                    ;69F4: 65 F2          'e.'
forth_LBRACKET_PFA FDB     forth_0_CFA              ;69F6: 66 62          ; 0
        FDB     forth_STATE_CFA          ;69F8: 67 53          ; STATE
        FDB     forth_STORE_CFA          ;69FA: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;69FC: 64 44          ; ;S
;
; --- :: ] ---
forth_RBRACKET_NFA FCB     $81,$DD                  ;69FE: 81 DD          '..'
forth_RBRACKET_LFA FDB     forth_LBRACKET_NFA       ;6A00: 69 F0          'i.'
forth_RBRACKET_CFA FDB     DOCOL                    ;6A02: 65 F2          'e.'
forth_RBRACKET_PFA FDB     CLIT,$C067,$5365,$BD64   ;6A04: 61 52 C0 67 53 65 BD 64 ; CLIT
        FDB     $4486                    ;6A0C: 44 86          'D.'
        FCC     "SMUDG"                  ;6A0E: 53 4D 55 44 47 'SMUDG'
        FCB     $C5                      ;6A13: C5             '.'
forth_SMUDGE_LFA FDB     forth_RBRACKET_NFA       ;6A14: 69 FE          'i.'
forth_SMUDGE_CFA FDB     DOCOL                    ;6A16: 65 F2          'e.'
forth_SMUDGE_PFA FDB     forth_LATEST_CFA,CLIT    ;6A18: 68 E7 61 52    ; LATEST
        FDB     $2065,$8B64              ;6A1C: 20 65 8B 64    ;   [char $20]
        FDB     $4483                    ;6A20: 44 83          'D.'
        FCC     "HE"                     ;6A22: 48 45          'HE'
        FCB     $D8                      ;6A24: D8             '.'
forth_HEX_LFA FDB     forth_SMUDGE_NFA         ;6A25: 6A 0D          'j.'
forth_HEX_CFA FDB     DOCOL                    ;6A27: 65 F2          'e.'
forth_HEX_PFA FDB     CLIT,$1067,$5E65,$BD64   ;6A29: 61 52 10 67 5E 65 BD 64 ; CLIT
        FDB     $4487                    ;6A31: 44 87          'D.'
        FCC     "DECIMA"                 ;6A33: 44 45 43 49 4D 41 'DECIMA'
        FCB     $CC                      ;6A39: CC             '.'
forth_DECIMAL_LFA FDB     forth_HEX_NFA            ;6A3A: 6A 21          'j!'
forth_DECIMAL_CFA FDB     DOCOL                    ;6A3C: 65 F2          'e.'
forth_DECIMAL_PFA FDB     CLIT,$0A67,$5E65,$BD64   ;6A3E: 61 52 0A 67 5E 65 BD 64 ; CLIT
        FDB     $4487                    ;6A46: 44 87          'D.'
        FCC     "(;CODE"                 ;6A48: 28 3B 43 4F 44 45 '(;CODE'
        FCB     $A9                      ;6A4E: A9             '.'
forth_PAREN_SEMICODE_RPAREN_LFA FDB     forth_DECIMAL_NFA        ;6A4F: 6A 32          'j2'
forth_PAREN_SEMICODE_RPAREN_CFA FDB     DOCOL                    ;6A51: 65 F2          'e.'
forth_PAREN_SEMICODE_RPAREN_PFA FDB     forth_R_GT_CFA           ;6A53: 64 7D          ; R>
        FDB     forth_2_PLUS_CFA         ;6A55: 67 AF          ; 2+
        FDB     forth_LATEST_CFA         ;6A57: 68 E7          ; LATEST
        FDB     forth_PFA_CFA            ;6A59: 69 29          ; PFA
        FDB     forth_CFA_CFA            ;6A5B: 69 06          ; CFA
        FDB     forth_STORE_CFA          ;6A5D: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;6A5F: 64 44          ; ;S
;
; --- :: ;CODE [IMMEDIATE] ---
forth_SEMICODE_NFA FCB     $C5                      ;6A61: C5             '.'
        FCC     ";COD"                   ;6A62: 3B 43 4F 44    ';COD'
        FCB     $C5                      ;6A66: C5             '.'
forth_SEMICODE_LFA FDB     forth_PAREN_SEMICODE_RPAREN_NFA ;6A67: 6A 47          'jG'
forth_SEMICODE_CFA FDB     DOCOL                    ;6A69: 65 F2          'e.'
forth_SEMICODE_PFA FDB     forth_QUESTIONCSP_CFA    ;6A6B: 69 A9          ; ?CSP
        FDB     forth_COMPILE_CFA        ;6A6D: 69 DE          ; COMPILE
        FDB     forth_PAREN_SEMICODE_RPAREN_CFA ;6A6F: 6A 51          ; (;CODE)
        FDB     forth_SMUDGE_CFA         ;6A71: 6A 16          ; SMUDGE
        FDB     forth_LBRACKET_CFA       ;6A73: 69 F4          ; [
        FDB     forth_QUESTIONSTACK_CFA  ;6A75: 6B 86          ; ?STACK
        FDB     forth_SEMIS_CFA          ;6A77: 64 44          ; ;S
;
; --- :: <BUILDS ---
forth_LTBUILDS_NFA FCB     $87                      ;6A79: 87             '.'
        FCC     "<BUILD"                 ;6A7A: 3C 42 55 49 4C 44 '<BUILD'
        FCB     $D3                      ;6A80: D3             '.'
forth_LTBUILDS_LFA FDB     forth_SEMICODE_NFA       ;6A81: 6A 61          'ja'
forth_LTBUILDS_CFA FDB     DOCOL                    ;6A83: 65 F2          'e.'
forth_LTBUILDS_PFA FDB     forth_0_CFA              ;6A85: 66 62          ; 0
        FDB     forth_CONSTANT_CFA       ;6A87: 66 1E          ; CONSTANT
        FDB     forth_SEMIS_CFA          ;6A89: 64 44          ; ;S
;
; --- :: DOES> ---
forth_DOES_GT_NFA FCB     $85                      ;6A8B: 85             '.'
        FCC     "DOES"                   ;6A8C: 44 4F 45 53    'DOES'
        FCB     $BE                      ;6A90: BE             '.'
forth_DOES_GT_LFA FDB     forth_LTBUILDS_NFA       ;6A91: 6A 79          'jy'
forth_DOES_GT_CFA FDB     DOCOL                    ;6A93: 65 F2          'e.'
forth_DOES_GT_PFA FDB     forth_R_GT_CFA           ;6A95: 64 7D          ; R>
        FDB     forth_2_PLUS_CFA         ;6A97: 67 AF          ; 2+
        FDB     forth_LATEST_CFA         ;6A99: 68 E7          ; LATEST
        FDB     forth_PFA_CFA            ;6A9B: 69 29          ; PFA
        FDB     forth_STORE_CFA          ;6A9D: 65 BD          ; !
        FDB     forth_PAREN_SEMICODE_RPAREN_CFA ;6A9F: 6A 51          ; (;CODE)
DODOES  FDB     $DC92,$DE94,$0909,$DF94  ;6AA1: DC 92 DE 94 09 09 DF 94 ; $DC92
        FDB     $ED02,$DE90,$0808,$DF80  ;6AA9: ED 02 DE 90 08 08 DF 80 ; $ED02
        FDB     $EE00,$DF92,$4FC6,$02D3  ;6AB1: EE 00 DF 92 4F C6 02 D3 ; $EE00
        FDB     $8037,$367E,$6136        ;6AB9: 80 37 36 7E 61 36 ; $8037
;
; --- :: COUNT ---
forth_COUNT_NFA FCB     $85                      ;6ABF: 85             ; $8543
        FCC     "COUN"                   ;6AC0: 43 4F 55 4E    'COUN'
        FCB     $D4                      ;6AC4: D4             '.'
forth_COUNT_LFA FDB     forth_DOES_GT_NFA        ;6AC5: 6A 8B          ; $6A8B
forth_COUNT_CFA FDB     DOCOL                    ;6AC7: 65 F2          ; $65F2
forth_COUNT_PFA FDB     forth_DUP_CFA            ;6AC9: 65 64          ; DUP
        FDB     forth_1_PLUS_CFA         ;6ACB: 67 A2          ; 1+
        FDB     forth_SWAP_CFA           ;6ACD: 65 4B          ; SWAP
        FDB     forth_C_FETCH_CFA        ;6ACF: 65 AC          ; C@
        FDB     forth_SEMIS_CFA          ;6AD1: 64 44          ; ;S
;
; --- :: TYPE ---
forth_TYPE_NFA FCB     $84                      ;6AD3: 84             '.'
        FCC     "TYP"                    ;6AD4: 54 59 50       'TYP'
        FCB     $C5                      ;6AD7: C5             '.'
forth_TYPE_LFA FDB     forth_COUNT_NFA          ;6AD8: 6A BF          'j.'
forth_TYPE_CFA FDB     DOCOL                    ;6ADA: 65 F2          'e.'
forth_TYPE_PFA FDB     forth_MINUSDUP_CFA       ;6ADC: 68 AC          ; -DUP
        FDB     forth_0BRANCH_CFA,$0018  ;6ADE: 61 88 00 18    ; 0BRANCH
        FDB     forth_OVER_CFA           ;6AE2: 65 2E          ; OVER
        FDB     forth_PLUS_CFA           ;6AE4: 64 C6          ; +
        FDB     forth_SWAP_CFA           ;6AE6: 65 4B          ; SWAP
        FDB     forth_PARENDO_RPAREN_CFA ;6AE8: 61 EF          ; (DO)
        FDB     forth_I_CFA              ;6AEA: 62 08          ; I
        FDB     forth_C_FETCH_CFA        ;6AEC: 65 AC          ; C@
        FDB     forth_EMIT_CFA           ;6AEE: 63 02          ; EMIT
        FDB     forth_PARENLOOP_RPAREN_CFA ;6AF0: 61 AE          ; (LOOP)
        FDB     $FFF8,forth_BRANCH_CFA   ;6AF2: FF F8 61 7C    ;   [->$6AEA]
        FDB     M0004,forth_DROP_CFA     ;6AF6: 00 04 65 3D    ;   [->$6AFA]
        FDB     forth_SEMIS_CFA          ;6AFA: 64 44          ; ;S
;
; --- :: -TRAILING ---
forth_MINUSTRAILING_NFA FCB     $89                      ;6AFC: 89             '.'
        FCC     "-TRAILIN"               ;6AFD: 2D 54 52 41 49 4C 49 4E '-TRAILIN'
        FCB     $C7                      ;6B05: C7             '.'
forth_MINUSTRAILING_LFA FDB     forth_TYPE_NFA           ;6B06: 6A D3          'j.'
forth_MINUSTRAILING_CFA FDB     DOCOL                    ;6B08: 65 F2          'e.'
forth_MINUSTRAILING_PFA FDB     forth_DUP_CFA            ;6B0A: 65 64          ; DUP
        FDB     forth_0_CFA              ;6B0C: 66 62          ; 0
        FDB     forth_PARENDO_RPAREN_CFA ;6B0E: 61 EF          ; (DO)
        FDB     forth_2DUP_CFA           ;6B10: 67 DC          ; 2DUP
        FDB     forth_PLUS_CFA           ;6B12: 64 C6          ; +
        FDB     forth_1_CFA              ;6B14: 66 6A          ; 1
        FDB     forth_MINUS_CFA          ;6B16: 68 19          ; -
        FDB     forth_C_FETCH_CFA        ;6B18: 65 AC          ; C@
        FDB     forth_BL_CFA             ;6B1A: 66 83          ; BL
        FDB     forth_MINUS_CFA          ;6B1C: 68 19          ; -
        FDB     forth_0BRANCH_CFA,M0008  ;6B1E: 61 88 00 08    ; 0BRANCH
        FDB     forth_LEAVE_CFA          ;6B22: 64 59          ; LEAVE
        FDB     forth_BRANCH_CFA,M0006   ;6B24: 61 7C 00 06    ; BRANCH
        FDB     forth_1_CFA              ;6B28: 66 6A          ; 1
        FDB     forth_MINUS_CFA          ;6B2A: 68 19          ; -
        FDB     forth_PARENLOOP_RPAREN_CFA ;6B2C: 61 AE          ; (LOOP)
        FDB     $FFE2,forth_SEMIS_CFA    ;6B2E: FF E2 64 44    ;   [->$6B10]
;
; --- :: (.") ---
forth_PAREN_DOT_QUOTE_RPAREN_NFA FCB     $84                      ;6B32: 84             '.'
        FCC     "(."                     ;6B33: 28 2E          '(.'
        FCB     $22,$A9                  ;6B35: 22 A9          '".'
forth_PAREN_DOT_QUOTE_RPAREN_LFA FDB     forth_MINUSTRAILING_NFA  ;6B37: 6A FC          'j.'
forth_PAREN_DOT_QUOTE_RPAREN_CFA FDB     DOCOL                    ;6B39: 65 F2          'e.'
forth_PAREN_DOT_QUOTE_RPAREN_PFA FDB     forth_R_CFA              ;6B3B: 64 8E          ; R
        FDB     forth_2_PLUS_CFA         ;6B3D: 67 AF          ; 2+
        FDB     forth_COUNT_CFA          ;6B3F: 6A C7          ; COUNT
        FDB     forth_DUP_CFA            ;6B41: 65 64          ; DUP
        FDB     forth_1_PLUS_CFA         ;6B43: 67 A2          ; 1+
        FDB     forth_R_GT_CFA           ;6B45: 64 7D          ; R>
        FDB     forth_PLUS_CFA           ;6B47: 64 C6          ; +
        FDB     forth_GTR_CFA            ;6B49: 64 69          ; >R
        FDB     forth_TYPE_CFA           ;6B4B: 6A DA          ; TYPE
        FDB     forth_SEMIS_CFA          ;6B4D: 64 44          ; ;S
;
; --- :: ." [IMMEDIATE] ---
forth_DOT_QUOTE_NFA FCB     $C2                      ;6B4F: C2             '.'
        FCC     "."                      ;6B50: 2E             '.'
        FCB     $A2                      ;6B51: A2             '.'
forth_DOT_QUOTE_LFA FDB     forth_PAREN_DOT_QUOTE_RPAREN_NFA ;6B52: 6B 32          'k2'
forth_DOT_QUOTE_CFA FDB     DOCOL                    ;6B54: 65 F2          'e.'
forth_DOT_QUOTE_PFA FDB     CLIT,$2267,$5365,$9D61   ;6B56: 61 52 22 67 53 65 9D 61 ; CLIT
        FDB     $8800,$1469,$DE6B,$396C  ;6B5E: 88 00 14 69 DE 6B 39 6C '...i.k9l'
        FDB     FCB+$127,$BE65,$AC67     ;6B66: C9 67 BE 65 AC 67 '.g.e.g'
        FDB     $A267,$EC61,$7C00,$0A6C  ;6B6C: A2 67 EC 61 7C 00 0A 6C '.g.a|..l'
        FDB     FCB+$127,$BE6A,$C76A     ;6B74: C9 67 BE 6A C7 6A '.g.j.j'
        FDB     $DA64                    ;6B7A: DA 64          '.d'
        FDB     $4486                    ;6B7C: 44 86          'D.'
        FCC     "?STAC"                  ;6B7E: 3F 53 54 41 43 '?STAC'
        FCB     $CB                      ;6B83: CB             '.'
forth_QUESTIONSTACK_LFA FDB     forth_DOT_QUOTE_NFA      ;6B84: 6B 4F          'kO'
forth_QUESTIONSTACK_CFA FDB     DOCOL                    ;6B86: 65 F2          'e.'
forth_QUESTIONSTACK_PFA FDB     CLIT,$1E66,$A965,$9D66   ;6B88: 61 52 1E 66 A9 65 9D 66 ; CLIT
        FDB     $7268,$1964,$1468,$3166  ;6B90: 72 68 19 64 14 68 31 66 'rh.d.h1f'
        FDB     forth_SEMICODE_CFA       ;6B98: 6A 69          'ji'
        FDB     $5064,$1466,$B965,$9D61  ;6B9A: 50 64 14 66 B9 65 9D 61 'Pd.f.e.a'
        FDB     $5242,forth_PLUS_CFA     ;6BA2: 52 42 64 C6    'RBd.'
        FDB     forth_LT_CFA             ;6BA6: 68 31          ; <
        FDB     forth_0BRANCH_CFA,M0006  ;6BA8: 61 88 00 06    ; 0BRANCH
        FDB     forth_2_CFA              ;6BAC: 66 72          ; 2
        FDB     forth_QUESTIONERROR_CFA  ;6BAE: 69 50          ; ?ERROR
        FDB     forth_SEMIS_CFA          ;6BB0: 64 44          ; ;S
;
; --- :: EXPECT ---
forth_EXPECT_NFA FCB     $86                      ;6BB2: 86             '.'
        FCC     "EXPEC"                  ;6BB3: 45 58 50 45 43 'EXPEC'
        FCB     $D4                      ;6BB8: D4             '.'
forth_EXPECT_LFA FDB     forth_QUESTIONSTACK_NFA  ;6BB9: 6B 7D          'k}'
forth_EXPECT_CFA FDB     DOCOL                    ;6BBB: 65 F2          'e.'
forth_EXPECT_PFA FDB     forth_OVER_CFA           ;6BBD: 65 2E          ; OVER
        FDB     forth_PLUS_CFA           ;6BBF: 64 C6          ; +
        FDB     forth_OVER_CFA           ;6BC1: 65 2E          ; OVER
        FDB     forth_PARENDO_RPAREN_CFA ;6BC3: 61 EF          ; (DO)
        FDB     forth_KEY_CFA            ;6BC5: 63 1A          ; KEY
        FDB     forth_DUP_CFA,CLIT       ;6BC7: 65 64 61 52    ; DUP
        FDB     $1A66,$A965,$9D68,$2561  ;6BCB: 1A 66 A9 65 9D 68 25 61 ;   [char $1A]
        FDB     $8800,$1F65,$3D61,$5208  ;6BD3: 88 00 1F 65 3D 61 52 08 '...e=aR.'
        FDB     forth_OVER_CFA           ;6BDB: 65 2E          ; OVER
        FDB     forth_I_CFA              ;6BDD: 62 08          ; I
        FDB     forth_EQ_CFA             ;6BDF: 68 25          ; =
        FDB     forth_DUP_CFA            ;6BE1: 65 64          ; DUP
        FDB     forth_R_GT_CFA           ;6BE3: 64 7D          ; R>
        FDB     forth_2_CFA              ;6BE5: 66 72          ; 2
        FDB     forth_MINUS_CFA          ;6BE7: 68 19          ; -
        FDB     forth_PLUS_CFA           ;6BE9: 64 C6          ; +
        FDB     forth_GTR_CFA            ;6BEB: 64 69          ; >R
        FDB     forth_MINUS_CFA          ;6BED: 68 19          ; -
        FDB     forth_BRANCH_CFA,$0027   ;6BEF: 61 7C 00 27    'a|.; BRANCH
        FDB     forth_DUP_CFA,CLIT       ;6BF3: 65 64 61 52    ; DUP
        FDB     $0D68,$2561,$8800,$0E64  ;6BF7: 0D 68 25 61 88 00 0E 64 ;   [char $0D]
        FDB     $5965,$3D66,$8366,$6261  ;6BFF: 59 65 3D 66 83 66 62 61 'Ye=f.fba'
        FDB     $7C00,$0465,$6462,$0865  ;6C07: 7C 00 04 65 64 62 08 65 '|..edb.e'
        FDB     $CC66,$6262,$0867,$A265  ;6C0F: CC 66 62 62 08 67 A2 65 '.fbb.g.e'
        FDB     $BD63,$0261,$AEFF,$A965  ;6C17: BD 63 02 61 AE FF A9 65 '.c.a...e'
        FDB     $3D64                    ;6C1F: 3D 64          '=d'
        FDB     $4485                    ;6C21: 44 85          'D.'
        FCC     "QUER"                   ;6C23: 51 55 45 52    'QUER'
        FCB     $D9                      ;6C27: D9             '.'
forth_QUERY_LFA FDB     forth_EXPECT_NFA         ;6C28: 6B B2          'k.'
forth_QUERY_CFA FDB     DOCOL                    ;6C2A: 65 F2          'e.'
forth_QUERY_PFA FDB     forth_TIB_CFA            ;6C2C: 66 B9          ; TIB
        FDB     forth_FETCH_CFA          ;6C2E: 65 9D          ; @
        FDB     forth_C_SLASHL_CFA       ;6C30: 67 99          ; C/L
        FDB     forth_EXPECT_CFA         ;6C32: 6B BB          ; EXPECT
        FDB     forth_0_CFA              ;6C34: 66 62          ; 0
        FDB     forth_IN_CFA             ;6C36: 67 0A          ; IN
        FDB     forth_STORE_CFA          ;6C38: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;6C3A: 64 44          ; ;S
;
; --- :: FILL ---
forth_FILL_NFA FCB     $84                      ;6C3C: 84             '.'
        FCC     "FIL"                    ;6C3D: 46 49 4C       'FIL'
        FCB     $CC                      ;6C40: CC             '.'
forth_FILL_LFA FDB     forth_QUERY_NFA          ;6C41: 6C 22          'l"'
forth_FILL_CFA FDB     DOCOL                    ;6C43: 65 F2          'e.'
forth_FILL_PFA FDB     forth_SWAP_CFA           ;6C45: 65 4B          ; SWAP
        FDB     forth_GTR_CFA            ;6C47: 64 69          ; >R
        FDB     forth_OVER_CFA           ;6C49: 65 2E          ; OVER
        FDB     forth_C_STORE_CFA        ;6C4B: 65 CC          ; C!
        FDB     forth_DUP_CFA            ;6C4D: 65 64          ; DUP
        FDB     forth_1_PLUS_CFA         ;6C4F: 67 A2          ; 1+
        FDB     forth_R_GT_CFA           ;6C51: 64 7D          ; R>
        FDB     forth_1_CFA              ;6C53: 66 6A          ; 1
        FDB     forth_MINUS_CFA          ;6C55: 68 19          ; -
        FDB     forth_CMOVE_CFA          ;6C57: 63 4B          ; CMOVE
        FDB     forth_SEMIS_CFA          ;6C59: 64 44          ; ;S
;
; --- :: ERASE ---
forth_ERASE_NFA FCB     $85                      ;6C5B: 85             '.'
        FCC     "ERAS"                   ;6C5C: 45 52 41 53    'ERAS'
        FCB     $C5                      ;6C60: C5             '.'
forth_ERASE_LFA FDB     forth_FILL_NFA           ;6C61: 6C 3C          'l<'
forth_ERASE_CFA FDB     DOCOL                    ;6C63: 65 F2          'e.'
forth_ERASE_PFA FDB     forth_0_CFA              ;6C65: 66 62          ; 0
        FDB     forth_FILL_CFA           ;6C67: 6C 43          ; FILL
        FDB     forth_SEMIS_CFA          ;6C69: 64 44          ; ;S
;
; --- :: BLANKS ---
forth_BLANKS_NFA FCB     $86                      ;6C6B: 86             '.'
        FCC     "BLANK"                  ;6C6C: 42 4C 41 4E 4B 'BLANK'
        FCB     $D3                      ;6C71: D3             '.'
forth_BLANKS_LFA FDB     forth_ERASE_NFA          ;6C72: 6C 5B          'l['
forth_BLANKS_CFA FDB     DOCOL                    ;6C74: 65 F2          'e.'
forth_BLANKS_PFA FDB     forth_BL_CFA             ;6C76: 66 83          ; BL
        FDB     forth_FILL_CFA           ;6C78: 6C 43          ; FILL
        FDB     forth_SEMIS_CFA          ;6C7A: 64 44          ; ;S
;
; --- :: HOLD ---
forth_HOLD_NFA FCB     $84                      ;6C7C: 84             '.'
        FCC     "HOL"                    ;6C7D: 48 4F 4C       'HOL'
        FCB     $C4                      ;6C80: C4             '.'
forth_HOLD_LFA FDB     forth_BLANKS_NFA         ;6C81: 6C 6B          'lk'
forth_HOLD_CFA FDB     DOCOL                    ;6C83: 65 F2          'e.'
forth_HOLD_PFA FDB     forth_LIT_CFA,$FFFF      ;6C85: 61 45 FF FF    ; LIT
        FDB     forth_HLD_CFA            ;6C89: 67 8F          ; HLD
        FDB     forth_PLUS_STORE_CFA     ;6C8B: 65 72          ; +!
        FDB     forth_HLD_CFA            ;6C8D: 67 8F          ; HLD
        FDB     forth_FETCH_CFA          ;6C8F: 65 9D          ; @
        FDB     forth_C_STORE_CFA        ;6C91: 65 CC          ; C!
        FDB     forth_SEMIS_CFA          ;6C93: 64 44          ; ;S
;
; --- :: PAD ---
forth_PAD_NFA FCB     $83                      ;6C95: 83             '.'
        FCC     "PA"                     ;6C96: 50 41          'PA'
        FCB     $C4                      ;6C98: C4             '.'
forth_PAD_LFA FDB     forth_HOLD_NFA           ;6C99: 6C 7C          'l|'
forth_PAD_CFA FDB     DOCOL                    ;6C9B: 65 F2          'e.'
forth_PAD_PFA FDB     forth_HERE_CFA,CLIT      ;6C9D: 67 BE 61 52    ; HERE
        FDB     $4464,$C664              ;6CA1: 44 64 C6 64    ;   [char $44]
        FDB     $44C1                    ;6CA5: 44 C1          'D.'
        FCB     $80                      ;6CA7: 80             '.'
forth_NULL_LFA FDB     forth_PAD_NFA            ;6CA8: 6C 95          'l.'
forth_NULL_CFA FDB     DOCOL                    ;6CAA: 65 F2          'e.'
forth_NULL_PFA FDB     forth_BLK_CFA            ;6CAC: 67 01          ; BLK
        FDB     forth_FETCH_CFA          ;6CAE: 65 9D          ; @
        FDB     forth_0BRANCH_CFA,$000A  ;6CB0: 61 88 00 0A    ; 0BRANCH
        FDB     forth_0_CFA              ;6CB4: 66 62          ; 0
        FDB     forth_IN_CFA             ;6CB6: 67 0A          ; IN
        FDB     forth_STORE_CFA          ;6CB8: 65 BD          ; !
        FDB     forth_QUESTIONEXEC_CFA   ;6CBA: 69 81          ; ?EXEC
        FDB     forth_R_GT_CFA           ;6CBC: 64 7D          ; R>
        FDB     forth_DROP_CFA           ;6CBE: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;6CC0: 64 44          ; ;S
;
; --- :: WORD ---
forth_WORD_NFA FCB     $84                      ;6CC2: 84             '.'
        FCC     "WOR"                    ;6CC3: 57 4F 52       'WOR'
        FCB     $C4                      ;6CC6: C4             '.'
forth_WORD_LFA FDB     forth_NULL_NFA           ;6CC7: 6C A6          'l.'
forth_WORD_CFA FDB     DOCOL                    ;6CC9: 65 F2          'e.'
forth_WORD_PFA FDB     forth_BLK_CFA            ;6CCB: 67 01          ; BLK
        FDB     forth_FETCH_CFA          ;6CCD: 65 9D          ; @
        FDB     forth_0BRANCH_CFA,M0008  ;6CCF: 61 88 00 08    ; 0BRANCH
        FDB     forth_FIRST_CFA          ;6CD3: 66 8F          ; FIRST
        FDB     forth_BRANCH_CFA,M0006   ;6CD5: 61 7C 00 06    ; BRANCH
        FDB     forth_TIB_CFA            ;6CD9: 66 B9          ; TIB
        FDB     forth_FETCH_CFA          ;6CDB: 65 9D          ; @
        FDB     forth_IN_CFA,$6034       ;6CDD: 67 0A 60 34    ; IN
        FDB     forth_SWAP_CFA           ;6CE1: 65 4B          ; SWAP
        FDB     forth_ENCLOSE_CFA        ;6CE3: 62 B9          ; ENCLOSE
        FDB     forth_HERE_CFA           ;6CE5: 67 BE          ; HERE
        FDB     forth_LIT_CFA,$0022      ;6CE7: 61 45 00 22    ; LIT
        FDB     forth_BLANKS_CFA         ;6CEB: 6C 74          ; BLANKS
        FDB     forth_IN_CFA             ;6CED: 67 0A          ; IN
        FDB     forth_PLUS_STORE_CFA     ;6CEF: 65 72          ; +!
        FDB     forth_OVER_CFA           ;6CF1: 65 2E          ; OVER
        FDB     forth_MINUS_CFA          ;6CF3: 68 19          ; -
        FDB     forth_GTR_CFA            ;6CF5: 64 69          ; >R
        FDB     forth_R_CFA              ;6CF7: 64 8E          ; R
        FDB     forth_HERE_CFA           ;6CF9: 67 BE          ; HERE
        FDB     forth_C_STORE_CFA        ;6CFB: 65 CC          ; C!
        FDB     forth_PLUS_CFA           ;6CFD: 64 C6          ; +
        FDB     forth_HERE_CFA           ;6CFF: 67 BE          ; HERE
        FDB     forth_1_PLUS_CFA         ;6D01: 67 A2          ; 1+
        FDB     forth_R_GT_CFA           ;6D03: 64 7D          ; R>
        FDB     forth_CMOVE_CFA          ;6D05: 63 4B          ; CMOVE
        FDB     forth_SEMIS_CFA          ;6D07: 64 44          ; ;S
;
; --- :: (NUMBER) ---
forth_PARENNUMBER_RPAREN_NFA FCB     $88                      ;6D09: 88             '.'
        FCC     "(NUMBER"                ;6D0A: 28 4E 55 4D 42 45 52 '(NUMBER'
        FCB     $A9                      ;6D11: A9             '.'
forth_PARENNUMBER_RPAREN_LFA FDB     forth_WORD_NFA           ;6D12: 6C C2          'l.'
forth_PARENNUMBER_RPAREN_CFA FDB     DOCOL                    ;6D14: 65 F2          'e.'
forth_PARENNUMBER_RPAREN_PFA FDB     forth_1_PLUS_CFA         ;6D16: 67 A2          ; 1+
        FDB     forth_DUP_CFA            ;6D18: 65 64          ; DUP
        FDB     forth_GTR_CFA            ;6D1A: 64 69          ; >R
        FDB     forth_C_FETCH_CFA        ;6D1C: 65 AC          ; C@
        FDB     forth_BASE_CFA           ;6D1E: 67 5E          ; BASE
        FDB     forth_FETCH_CFA          ;6D20: 65 9D          ; @
        FDB     forth_DIGIT_CFA          ;6D22: 62 19          ; DIGIT
        FDB     forth_0BRANCH_CFA,$002C  ;6D24: 61 88 00 2C    ; 0BRANCH
        FDB     forth_SWAP_CFA           ;6D28: 65 4B          ; SWAP
        FDB     forth_BASE_CFA           ;6D2A: 67 5E          ; BASE
        FDB     forth_FETCH_CFA          ;6D2C: 65 9D          ; @
        FDB     forth_U_STAR_CFA         ;6D2E: 63 7F          ; U*
        FDB     forth_DROP_CFA           ;6D30: 65 3D          ; DROP
        FDB     forth_ROT_CFA            ;6D32: 68 5D          ; ROT
        FDB     forth_BASE_CFA           ;6D34: 67 5E          ; BASE
        FDB     forth_FETCH_CFA          ;6D36: 65 9D          ; @
        FDB     forth_U_STAR_CFA         ;6D38: 63 7F          ; U*
        FDB     forth_D_PLUS_CFA         ;6D3A: 64 D5          ; D+
        FDB     forth_DPL_CFA            ;6D3C: 67 68          ; DPL
        FDB     forth_FETCH_CFA          ;6D3E: 65 9D          ; @
        FDB     forth_1_PLUS_CFA         ;6D40: 67 A2          ; 1+
        FDB     forth_0BRANCH_CFA,M0008  ;6D42: 61 88 00 08    ; 0BRANCH
        FDB     forth_1_CFA              ;6D46: 66 6A          ; 1
        FDB     forth_DPL_CFA            ;6D48: 67 68          ; DPL
        FDB     forth_PLUS_STORE_CFA     ;6D4A: 65 72          ; +!
        FDB     forth_R_GT_CFA           ;6D4C: 64 7D          ; R>
        FDB     forth_BRANCH_CFA,$FFC6   ;6D4E: 61 7C FF C6    ; BRANCH
        FDB     forth_R_GT_CFA           ;6D52: 64 7D          ; R>
        FDB     forth_SEMIS_CFA          ;6D54: 64 44          ; ;S
;
; --- :: NUMBER ---
forth_NUMBER_NFA FCB     $86                      ;6D56: 86             '.'
        FCC     "NUMBE"                  ;6D57: 4E 55 4D 42 45 'NUMBE'
        FCB     $D2                      ;6D5C: D2             '.'
forth_NUMBER_LFA FDB     forth_PARENNUMBER_RPAREN_NFA ;6D5D: 6D 09          'm.'
forth_NUMBER_CFA FDB     DOCOL                    ;6D5F: 65 F2          'e.'
forth_NUMBER_PFA FDB     forth_0_CFA,forth_0_CFA  ;6D61: 66 62 66 62    ; 0
        FDB     forth_ROT_CFA            ;6D65: 68 5D          ; ROT
        FDB     forth_DUP_CFA            ;6D67: 65 64          ; DUP
        FDB     forth_1_PLUS_CFA         ;6D69: 67 A2          ; 1+
        FDB     forth_C_FETCH_CFA        ;6D6B: 65 AC          ; C@
        FDB     forth_LIT_CFA,$002D      ;6D6D: 61 45 00 2D    ; LIT
        FDB     forth_EQ_CFA             ;6D71: 68 25          ; =
        FDB     forth_DUP_CFA            ;6D73: 65 64          ; DUP
        FDB     forth_GTR_CFA            ;6D75: 64 69          ; >R
        FDB     forth_PLUS_CFA           ;6D77: 64 C6          ; +
        FDB     forth_LIT_CFA,$FFFF      ;6D79: 61 45 FF FF    ; LIT
        FDB     forth_DPL_CFA            ;6D7D: 67 68          ; DPL
        FDB     forth_STORE_CFA          ;6D7F: 65 BD          ; !
        FDB     forth_PARENNUMBER_RPAREN_CFA ;6D81: 6D 14          ; (NUMBER)
        FDB     forth_DUP_CFA            ;6D83: 65 64          ; DUP
        FDB     forth_C_FETCH_CFA        ;6D85: 65 AC          ; C@
        FDB     forth_BL_CFA             ;6D87: 66 83          ; BL
        FDB     forth_MINUS_CFA          ;6D89: 68 19          ; -
        FDB     forth_0BRANCH_CFA,$0016  ;6D8B: 61 88 00 16    ; 0BRANCH
        FDB     forth_DUP_CFA            ;6D8F: 65 64          ; DUP
        FDB     forth_C_FETCH_CFA        ;6D91: 65 AC          ; C@
        FDB     forth_LIT_CFA,$002E      ;6D93: 61 45 00 2E    ; LIT
        FDB     forth_MINUS_CFA          ;6D97: 68 19          ; -
        FDB     forth_0_CFA              ;6D99: 66 62          ; 0
        FDB     forth_QUESTIONERROR_CFA  ;6D9B: 69 50          ; ?ERROR
        FDB     forth_0_CFA              ;6D9D: 66 62          ; 0
        FDB     forth_BRANCH_CFA,$FFDC   ;6D9F: 61 7C FF DC    ; BRANCH
        FDB     forth_DROP_CFA           ;6DA3: 65 3D          ; DROP
        FDB     forth_R_GT_CFA           ;6DA5: 64 7D          ; R>
        FDB     forth_0BRANCH_CFA,M0004  ;6DA7: 61 88 00 04    ; 0BRANCH
        FDB     forth_DMINUS_CFA         ;6DAB: 65 0D          ; DMINUS
        FDB     forth_SEMIS_CFA          ;6DAD: 64 44          ; ;S
;
; --- :: -FIND ---
forth_MINUSFIND_NFA FCB     $85                      ;6DAF: 85             '.'
        FCC     "-FIN"                   ;6DB0: 2D 46 49 4E    '-FIN'
        FCB     $C4                      ;6DB4: C4             '.'
forth_MINUSFIND_LFA FDB     forth_NUMBER_NFA         ;6DB5: 6D 56          'mV'
forth_MINUSFIND_CFA FDB     DOCOL                    ;6DB7: 65 F2          'e.'
forth_MINUSFIND_PFA FDB     forth_BL_CFA             ;6DB9: 66 83          ; BL
        FDB     forth_WORD_CFA           ;6DBB: 6C C9          ; WORD
        FDB     forth_HERE_CFA           ;6DBD: 67 BE          ; HERE
        FDB     forth_CONTEXT_CFA        ;6DBF: 67 39          ; CONTEXT
        FDB     forth_FETCH_CFA          ;6DC1: 65 9D          ; @
        FDB     forth_FETCH_CFA          ;6DC3: 65 9D          ; @
        FDB     forth_PARENFIND_RPAREN_CFA ;6DC5: 62 4E          ; (FIND)
        FDB     forth_DUP_CFA            ;6DC7: 65 64          ; DUP
        FDB     forth_0_EQ_CFA           ;6DC9: 64 9C          ; 0=
        FDB     forth_0BRANCH_CFA,$000A  ;6DCB: 61 88 00 0A    ; 0BRANCH
        FDB     forth_DROP_CFA           ;6DCF: 65 3D          ; DROP
        FDB     forth_HERE_CFA           ;6DD1: 67 BE          ; HERE
        FDB     forth_LATEST_CFA         ;6DD3: 68 E7          ; LATEST
        FDB     forth_PARENFIND_RPAREN_CFA ;6DD5: 62 4E          ; (FIND)
        FDB     forth_SEMIS_CFA          ;6DD7: 64 44          ; ;S
;
; --- :: (ABORT) ---
forth_PARENABORT_RPAREN_NFA FCB     $87                      ;6DD9: 87             '.'
        FCC     "(ABORT"                 ;6DDA: 28 41 42 4F 52 54 '(ABORT'
        FCB     $A9                      ;6DE0: A9             '.'
forth_PARENABORT_RPAREN_LFA FDB     forth_MINUSFIND_NFA      ;6DE1: 6D AF          'm.'
forth_PARENABORT_RPAREN_CFA FDB     DOCOL                    ;6DE3: 65 F2          'e.'
forth_PARENABORT_RPAREN_PFA FDB     forth_ABORT_CFA          ;6DE5: 70 24          ; ABORT
        FDB     forth_SEMIS_CFA          ;6DE7: 64 44          ; ;S
;
; --- :: ERROR ---
forth_ERROR_NFA FCB     $85                      ;6DE9: 85             '.'
        FCC     "ERRO"                   ;6DEA: 45 52 52 4F    'ERRO'
        FCB     $D2                      ;6DEE: D2             '.'
forth_ERROR_LFA FDB     $0C00                    ;6DEF: 0C 00          '..'
forth_ERROR_CFA FDB     DOCOL                    ;6DF1: 65 F2          'e.'
forth_ERROR_PFA FDB     forth_WARNING_CFA        ;6DF3: 66 D3          ; WARNING
        FDB     forth_FETCH_CFA          ;6DF5: 65 9D          ; @
        FDB     forth_0_LT_CFA           ;6DF7: 64 AF          ; 0<
        FDB     forth_0BRANCH_CFA,M0004  ;6DF9: 61 88 00 04    ; 0BRANCH
        FDB     $0C0A,forth_HERE_CFA     ;6DFD: 0C 0A 67 BE    ; $0C0A
        FDB     forth_COUNT_CFA          ;6E01: 6A C7          ; COUNT
        FDB     forth_TYPE_CFA           ;6E03: 6A DA          ; TYPE
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;6E05: 6B 39          ; (.")
        FDB     $0320,$3F20,CLIT,$1260   ;6E07: 03 20 3F 20 61 52 12 60 ;   [" ? "]
        FDB     $F374,$5264,$2567,$CE67  ;6E0F: F3 74 52 64 25 67 CE 67 '.tRd%g.g'
        FDB     $0A65,$9D67,$0165,$9D6F  ;6E17: 0A 65 9D 67 01 65 9D 6F '.e.g.e.o'
        FDB     $F664                    ;6E1F: F6 64          '.d'
        FDB     $4483                    ;6E21: 44 83          'D.'
        FCC     "ID"                     ;6E23: 49 44          'ID'
        FCB     $AE                      ;6E25: AE             '.'
forth_ID_DOT_LFA FDB     forth_ERROR_NFA          ;6E26: 6D E9          'm.'
forth_ID_DOT_CFA FDB     DOCOL                    ;6E28: 65 F2          'e.'
forth_ID_DOT_PFA FDB     forth_PAD_CFA            ;6E2A: 6C 9B          ; PAD
        FDB     forth_LIT_CFA,$0020      ;6E2C: 61 45 00 20    ; LIT
        FDB     forth_LIT_CFA,$005F      ;6E30: 61 45 00 5F    ; LIT
        FDB     forth_FILL_CFA           ;6E34: 6C 43          ; FILL
        FDB     forth_DUP_CFA            ;6E36: 65 64          ; DUP
        FDB     forth_PFA_CFA            ;6E38: 69 29          ; PFA
        FDB     forth_LFA_CFA            ;6E3A: 68 F7          ; LFA
        FDB     forth_OVER_CFA           ;6E3C: 65 2E          ; OVER
        FDB     forth_MINUS_CFA          ;6E3E: 68 19          ; -
        FDB     forth_PAD_CFA            ;6E40: 6C 9B          ; PAD
        FDB     forth_SWAP_CFA           ;6E42: 65 4B          ; SWAP
        FDB     forth_CMOVE_CFA          ;6E44: 63 4B          ; CMOVE
        FDB     forth_PAD_CFA            ;6E46: 6C 9B          ; PAD
        FDB     forth_COUNT_CFA,CLIT     ;6E48: 6A C7 61 52    ; COUNT
        FDB     $1F63,$DF6A,$DA68,$7164  ;6E4C: 1F 63 DF 6A DA 68 71 64 ;   [char $1F]
        FDB     $4486                    ;6E54: 44 86          'D.'
        FCC     "CREAT"                  ;6E56: 43 52 45 41 54 'CREAT'
        FCB     $C5                      ;6E5B: C5             '.'
forth_CREATE_LFA FDB     forth_ID_DOT_NFA         ;6E5C: 6E 22          'n"'
forth_CREATE_CFA FDB     DOCOL                    ;6E5E: 65 F2          'e.'
forth_CREATE_PFA FDB     forth_MINUSFIND_CFA      ;6E60: 6D B7          ; -FIND
        FDB     forth_0BRANCH_CFA,$0010  ;6E62: 61 88 00 10    ; 0BRANCH
        FDB     forth_DROP_CFA           ;6E66: 65 3D          ; DROP
        FDB     forth_NFA_CFA            ;6E68: 69 14          ; NFA
        FDB     forth_ID_DOT_CFA         ;6E6A: 6E 28          ; ID.
        FDB     forth_LIT_CFA,M0004      ;6E6C: 61 45 00 04    ; LIT
        FDB     forth_MESSAGE_CFA        ;6E70: 74 52          ; MESSAGE
        FDB     forth_SPACE_CFA          ;6E72: 68 71          ; SPACE
        FDB     forth_HERE_CFA           ;6E74: 67 BE          ; HERE
        FDB     forth_DUP_CFA            ;6E76: 65 64          ; DUP
        FDB     forth_C_FETCH_CFA        ;6E78: 65 AC          ; C@
        FDB     forth_WIDTH_CFA          ;6E7A: 66 C5          ; WIDTH
        FDB     forth_FETCH_CFA          ;6E7C: 65 9D          ; @
        FDB     forth_MIN_CFA            ;6E7E: 68 7F          ; MIN
        FDB     forth_1_PLUS_CFA         ;6E80: 67 A2          ; 1+
        FDB     forth_ALLOT_CFA          ;6E82: 67 EC          ; ALLOT
        FDB     forth_DUP_CFA,CLIT       ;6E84: 65 64 61 52    ; DUP
        FDB     $A065,$8B67,$BE66,$6A68  ;6E88: A0 65 8B 67 BE 66 6A 68 ;   [char $A0]
        FDB     $1961,$5280              ;6E90: 19 61 52 80    '.aR.'
        FDB     forth_TOGGLE_CFA         ;6E94: 65 8B          ; TOGGLE
        FDB     forth_LATEST_CFA         ;6E96: 68 E7          ; LATEST
        FDB     forth_COMMA_CFA          ;6E98: 67 F8          ; ,
        FDB     forth_CURRENT_CFA        ;6E9A: 67 47          ; CURRENT
        FDB     forth_FETCH_CFA          ;6E9C: 65 9D          ; @
        FDB     forth_STORE_CFA          ;6E9E: 65 BD          ; !
        FDB     forth_HERE_CFA           ;6EA0: 67 BE          ; HERE
        FDB     forth_2_PLUS_CFA         ;6EA2: 67 AF          ; 2+
        FDB     forth_COMMA_CFA          ;6EA4: 67 F8          ; ,
        FDB     forth_SEMIS_CFA          ;6EA6: 64 44          ; ;S
;
; --- :: [COMPILE] [IMMEDIATE] ---
forth_LBRACKETCOMPILE_RBRACKET_NFA FCB     $C9                      ;6EA8: C9             '.'
        FCC     "[COMPILE"               ;6EA9: 5B 43 4F 4D 50 49 4C 45 '[COMPILE'
        FCB     $DD                      ;6EB1: DD             '.'
forth_LBRACKETCOMPILE_RBRACKET_LFA FDB     forth_CREATE_NFA         ;6EB2: 6E 55          'nU'
forth_LBRACKETCOMPILE_RBRACKET_CFA FDB     DOCOL                    ;6EB4: 65 F2          'e.'
forth_LBRACKETCOMPILE_RBRACKET_PFA FDB     forth_MINUSFIND_CFA      ;6EB6: 6D B7          ; -FIND
        FDB     forth_0_EQ_CFA           ;6EB8: 64 9C          ; 0=
        FDB     forth_0_CFA              ;6EBA: 66 62          ; 0
        FDB     forth_QUESTIONERROR_CFA  ;6EBC: 69 50          ; ?ERROR
        FDB     forth_DROP_CFA           ;6EBE: 65 3D          ; DROP
        FDB     forth_CFA_CFA            ;6EC0: 69 06          ; CFA
        FDB     forth_COMMA_CFA          ;6EC2: 67 F8          ; ,
        FDB     forth_SEMIS_CFA          ;6EC4: 64 44          ; ;S
;
; --- :: LITERAL [IMMEDIATE] ---
forth_LITERAL_NFA FCB     $C7                      ;6EC6: C7             '.'
        FCC     "LITERA"                 ;6EC7: 4C 49 54 45 52 41 'LITERA'
        FCB     $CC                      ;6ECD: CC             '.'
forth_LITERAL_LFA FDB     forth_LBRACKETCOMPILE_RBRACKET_NFA ;6ECE: 6E A8          'n.'
forth_LITERAL_CFA FDB     DOCOL                    ;6ED0: 65 F2          'e.'
forth_LITERAL_PFA FDB     forth_STATE_CFA          ;6ED2: 67 53          ; STATE
        FDB     forth_FETCH_CFA          ;6ED4: 65 9D          ; @
        FDB     forth_0BRANCH_CFA,M0008  ;6ED6: 61 88 00 08    ; 0BRANCH
        FDB     forth_COMPILE_CFA        ;6EDA: 69 DE          ; COMPILE
        FDB     forth_LIT_CFA            ;6EDC: 61 45          ; LIT
        FDB     forth_COMMA_CFA          ;6EDE: 67 F8          ;   [26616 ($67F8)]
        FDB     forth_SEMIS_CFA          ;6EE0: 64 44          ; ;S
;
; --- :: DLITERAL [IMMEDIATE] ---
forth_DLITERAL_NFA FCB     $C8                      ;6EE2: C8             '.'
        FCC     "DLITERA"                ;6EE3: 44 4C 49 54 45 52 41 'DLITERA'
        FCB     $CC                      ;6EEA: CC             '.'
forth_DLITERAL_LFA FDB     forth_LITERAL_NFA        ;6EEB: 6E C6          'n.'
forth_DLITERAL_CFA FDB     DOCOL                    ;6EED: 65 F2          'e.'
forth_DLITERAL_PFA FDB     forth_STATE_CFA          ;6EEF: 67 53          ; STATE
        FDB     forth_FETCH_CFA          ;6EF1: 65 9D          ; @
        FDB     forth_0BRANCH_CFA,M0008  ;6EF3: 61 88 00 08    ; 0BRANCH
        FDB     forth_SWAP_CFA           ;6EF7: 65 4B          ; SWAP
        FDB     forth_LITERAL_CFA        ;6EF9: 6E D0          ; LITERAL
        FDB     forth_LITERAL_CFA        ;6EFB: 6E D0          ; LITERAL
        FDB     forth_SEMIS_CFA          ;6EFD: 64 44          ; ;S
;
; --- :: INTERPRET ---
forth_INTERPRET_NFA FCB     $89                      ;6EFF: 89             '.'
        FCC     "INTERPRE"               ;6F00: 49 4E 54 45 52 50 52 45 'INTERPRE'
        FCB     $D4                      ;6F08: D4             '.'
forth_INTERPRET_LFA FDB     forth_DLITERAL_NFA       ;6F09: 6E E2          'n.'
forth_INTERPRET_CFA FDB     DOCOL                    ;6F0B: 65 F2          'e.'
forth_INTERPRET_PFA FDB     forth_MINUSFIND_CFA      ;6F0D: 6D B7          ; -FIND
        FDB     forth_0BRANCH_CFA,$001E  ;6F0F: 61 88 00 1E    ; 0BRANCH
        FDB     forth_STATE_CFA          ;6F13: 67 53          ; STATE
        FDB     forth_FETCH_CFA          ;6F15: 65 9D          ; @
        FDB     forth_LT_CFA             ;6F17: 68 31          ; <
        FDB     forth_0BRANCH_CFA,$000A  ;6F19: 61 88 00 0A    ; 0BRANCH
        FDB     forth_CFA_CFA            ;6F1D: 69 06          ; CFA
        FDB     forth_COMMA_CFA          ;6F1F: 67 F8          ; ,
        FDB     forth_BRANCH_CFA,M0006   ;6F21: 61 7C 00 06    ; BRANCH
        FDB     forth_CFA_CFA            ;6F25: 69 06          ; CFA
        FDB     forth_EXECUTE_CFA        ;6F27: 61 69          ; EXECUTE
        FDB     forth_QUESTIONSTACK_CFA  ;6F29: 6B 86          ; ?STACK
        FDB     forth_BRANCH_CFA,$001C   ;6F2B: 61 7C 00 1C    ; BRANCH
        FDB     forth_HERE_CFA           ;6F2F: 67 BE          ; HERE
        FDB     forth_NUMBER_CFA         ;6F31: 6D 5F          ; NUMBER
        FDB     forth_DPL_CFA            ;6F33: 67 68          ; DPL
        FDB     forth_FETCH_CFA          ;6F35: 65 9D          ; @
        FDB     forth_1_PLUS_CFA         ;6F37: 67 A2          ; 1+
        FDB     forth_0BRANCH_CFA,M0008  ;6F39: 61 88 00 08    ; 0BRANCH
        FDB     forth_DLITERAL_CFA       ;6F3D: 6E ED          ; DLITERAL
        FDB     forth_BRANCH_CFA,M0006   ;6F3F: 61 7C 00 06    ; BRANCH
        FDB     forth_DROP_CFA           ;6F43: 65 3D          ; DROP
        FDB     forth_LITERAL_CFA        ;6F45: 6E D0          ; LITERAL
        FDB     forth_QUESTIONSTACK_CFA  ;6F47: 6B 86          ; ?STACK
        FDB     forth_BRANCH_CFA,$FFC2   ;6F49: 61 7C FF C2    ; BRANCH
;
; --- :: IMMEDIATE ---
forth_IMMEDIATE_NFA FCB     $89                      ;6F4D: 89             ; $8949
        FCC     "IMMEDIAT"               ;6F4E: 49 4D 4D 45 44 49 41 54 'IMMEDIAT'
        FCB     $C5                      ;6F56: C5             '.'
forth_IMMEDIATE_LFA FDB     forth_INTERPRET_NFA      ;6F57: 6E FF          ; $6EFF
forth_IMMEDIATE_CFA FDB     DOCOL                    ;6F59: 65 F2          ; $65F2
forth_IMMEDIATE_PFA FDB     forth_LATEST_CFA,CLIT    ;6F5B: 68 E7 61 52    ; LATEST
        FDB     $4065,$8B64              ;6F5F: 40 65 8B 64    ;   [char $40]
        FDB     $448A                    ;6F63: 44 8A          'D.'
        FCC     "VOCABULAR"              ;6F65: 56 4F 43 41 42 55 4C 41 52 'VOCABULAR'
        FCB     $D9                      ;6F6E: D9             '.'
forth_VOCABULARY_LFA FDB     forth_IMMEDIATE_NFA      ;6F6F: 6F 4D          'oM'
forth_VOCABULARY_CFA FDB     DOCOL                    ;6F71: 65 F2          'e.'
forth_VOCABULARY_PFA FDB     forth_LTBUILDS_CFA       ;6F73: 6A 83          ; <BUILDS
        FDB     forth_LIT_CFA,$81A0      ;6F75: 61 45 81 A0    ; LIT
        FDB     forth_COMMA_CFA          ;6F79: 67 F8          ; ,
        FDB     forth_CURRENT_CFA        ;6F7B: 67 47          ; CURRENT
        FDB     forth_FETCH_CFA          ;6F7D: 65 9D          ; @
        FDB     forth_CFA_CFA            ;6F7F: 69 06          ; CFA
        FDB     forth_COMMA_CFA          ;6F81: 67 F8          ; ,
        FDB     forth_HERE_CFA           ;6F83: 67 BE          ; HERE
        FDB     forth_VOC_MINUSLINK_CFA  ;6F85: 66 F7          ; VOC-LINK
        FDB     forth_FETCH_CFA          ;6F87: 65 9D          ; @
        FDB     forth_COMMA_CFA          ;6F89: 67 F8          ; ,
        FDB     forth_VOC_MINUSLINK_CFA  ;6F8B: 66 F7          ; VOC-LINK
        FDB     forth_STORE_CFA          ;6F8D: 65 BD          ; !
        FDB     forth_DOES_GT_CFA        ;6F8F: 6A 93          ; DOES>
        FDB     forth_2_PLUS_CFA         ;6F91: 67 AF          ; 2+
        FDB     forth_CONTEXT_CFA        ;6F93: 67 39          ; CONTEXT
        FDB     forth_STORE_CFA          ;6F95: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;6F97: 64 44          ; ;S
;
; --- DOES> word: FORTH [IMMEDIATE] ---
forth_FORTH_NFA FCB     $C5                      ;6F99: C5             '.'
        FCC     "FORT"                   ;6F9A: 46 4F 52 54    'FORT'
        FCB     $C8                      ;6F9E: C8             '.'
forth_FORTH_LFA FDB     forth_VOCABULARY_NFA     ;6F9F: 6F 64          'od'
forth_FORTH_CFA FDB     DODOES                   ;6FA1: 6A A1          'j.'
forth_FORTH_PFA FDB     $6F91,$81A0              ;6FA3: 6F 91 81 A0    'o...'
        FDB     forth_2_STAR_NFA,$0000   ;6FA7: 7E E9 00 00    '~...'
copyright_string FCB     '(,'C,'),' ,'1,'9,'8,'2  ;6FAB: 28 43 29 20 31 39 38 32 '(C) 1982'
        FCB     ' ,'J,'.,'W,'.,'B,'r,'o  ;6FB3: 20 4A 2E 57 2E 42 72 6F ' J.W.Bro'
        FCB     'w,'n,' ,'T,'o,' ,'S,'a  ;6FBB: 77 6E 20 54 6F 20 53 61 'wn To Sa'
        FCB     'r,'a,'h,$0a,$0d         ;6FC3: 72 61 68 0A 0D 'rah..'
;
; --- :: DEFINITIONS ---
forth_DEFINITIONS_NFA FCB     $8B                      ;6FC8: 8B             '.'
        FCC     "DEFINITION"             ;6FC9: 44 45 46 49 4E 49 54 49 4F 4E 'DEFINITION'
        FCB     $D3                      ;6FD3: D3             '.'
forth_DEFINITIONS_LFA FDB     $0D00                    ;6FD4: 0D 00          '..'
forth_DEFINITIONS_CFA FDB     DOCOL                    ;6FD6: 65 F2          'e.'
forth_DEFINITIONS_PFA FDB     forth_CONTEXT_CFA        ;6FD8: 67 39          ; CONTEXT
        FDB     forth_FETCH_CFA          ;6FDA: 65 9D          ; @
        FDB     forth_CURRENT_CFA        ;6FDC: 67 47          ; CURRENT
        FDB     forth_STORE_CFA          ;6FDE: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;6FE0: 64 44          ; ;S
;
; --- :: ( [IMMEDIATE] ---
forth_PAREN_NFA FCB     $C1,$A8                  ;6FE2: C1 A8          '..'
forth_PAREN_LFA FDB     forth_DEFINITIONS_NFA    ;6FE4: 6F C8          'o.'
forth_PAREN_CFA FDB     DOCOL                    ;6FE6: 65 F2          'e.'
forth_PAREN_PFA FDB     CLIT,$296C,FCB+$124      ;6FE8: 61 52 29 6C C9 64 ; CLIT
        FDB     $4484                    ;6FEE: 44 84          'D.'
        FCC     "QUI"                    ;6FF0: 51 55 49       'QUI'
        FCB     $D4                      ;6FF3: D4             '.'
forth_QUIT_LFA FDB     forth_PAREN_NFA          ;6FF4: 6F E2          'o.'
forth_QUIT_CFA FDB     DOCOL                    ;6FF6: 65 F2          'e.'
forth_QUIT_PFA FDB     forth_0_CFA              ;6FF8: 66 62          ; 0
        FDB     forth_BLK_CFA            ;6FFA: 67 01          ; BLK
        FDB     forth_STORE_CFA          ;6FFC: 65 BD          ; !
        FDB     forth_LBRACKET_CFA       ;6FFE: 69 F4          ; [
        FDB     forth_RP_STORE_CFA       ;7000: 64 35          ; RP!
        FDB     forth_CR_CFA             ;7002: 63 3B          ; CR
        FDB     forth_QUERY_CFA          ;7004: 6C 2A          ; QUERY
        FDB     forth_INTERPRET_CFA      ;7006: 6F 0B          ; INTERPRET
        FDB     forth_STATE_CFA          ;7008: 67 53          ; STATE
        FDB     forth_FETCH_CFA          ;700A: 65 9D          ; @
        FDB     forth_0_EQ_CFA           ;700C: 64 9C          ; 0=
        FDB     forth_0BRANCH_CFA,M0008  ;700E: 61 88 00 08    ; 0BRANCH
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;7012: 6B 39          ; (.")
        FDB     $0320,M4F4B              ;7014: 03 20 4F 4B    ;   [" OK"]
        FDB     forth_BRANCH_CFA,$FFE6   ;7018: 61 7C FF E6    ; BRANCH
;
; --- :: ABORT ---
forth_ABORT_NFA FCB     $85                      ;701C: 85             ; $8541
        FCC     "ABOR"                   ;701D: 41 42 4F 52    'ABOR'
        FCB     $D4                      ;7021: D4             '.'
forth_ABORT_LFA FDB     forth_QUIT_NFA           ;7022: 6F EF          ; $6FEF
forth_ABORT_CFA FDB     DOCOL                    ;7024: 65 F2          ; $65F2
forth_ABORT_PFA FDB     forth_SP_STORE_CFA       ;7026: 64 25          ; SP!
        FDB     forth_DECIMAL_CFA        ;7028: 6A 3C          ; DECIMAL
        FDB     forth_QUESTIONSTACK_CFA  ;702A: 6B 86          ; ?STACK
        FDB     forth_CR_CFA             ;702C: 63 3B          ; CR
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;702E: 6B 39          ; (.")
        FDB     $1045,$5053,$4F4E,$2D46  ;7030: 10 45 50 53 4F 4E 2D 46 ;   ["EPSON-FORTH V1.0"]
        FDB     $4F52,$5448,$2056,$312E  ;7038: 4F 52 54 48 20 56 31 2E 'ORTH V1.'
        FDB     $300D,$086F,$D66F        ;7040: 30 0D 08 6F D6 6F '0..o.o'
        FDB     $F665                    ;7046: F6 65          '.e'
        FDB     $F263,$3B6B,$391B,$436F  ;7048: F2 63 3B 6B 39 1B 43 6F '.c;k9.Co'
        FDB     $7079,$7269              ;7050: 70 79 72 69    'pyri'
        FDB     forth_DPL_CFA,$7420      ;7054: 67 68 74 20    'ght '
        FDB     $3139,$3832,$0A0D,$4A2E  ;7058: 31 39 38 32 0A 0D 4A 2E '1982..J.'
        FDB     $572E,$4272,$6F77,$6E20  ;7060: 57 2E 42 72 6F 77 6E 20 'W.Brown '
        FDB     $2070,$2464              ;7068: 20 70 24 64    ' p$d'
        FDB     $448E                    ;706C: 44 8E          'D.'
        SEC                              ;706E: 0D             '.'
        CBA                              ;706F: 11             '.'
        LDX     #copyright_string        ;7070: CE 6F AB       '.o.'
Z7073   DEX                              ;7073: 09             '.'
        LDAA    ,X                       ;7074: A6 00          '..'
        PSHA                             ;7076: 36             '6'
        CPX     #forth_FORTH_NFA         ;7077: 8C 6F 99       '.o.'
        BNE     Z7073                    ;707A: 26 F7          '&.'
        LDS     #M0C0F                   ;707C: 8E 0C 0F       '...'
        JMP     Z708E                    ;707F: 7E 70 8E       '~p.'
;
; --- CODE: COLD ---
forth_COLD_NFA FCB     $84                      ;7082: 84             '.'
        FCC     "COL"                    ;7083: 43 4F 4C       'COL'
        FCB     $C4                      ;7086: C4             '.'
forth_COLD_LFA FDB     forth_ABORT_NFA          ;7087: 70 1C          'p.'
forth_COLD_CFA FDB     forth_COLD_PFA           ;7089: 70 8B          'p.'
forth_COLD_PFA JMP     cold_init_code           ;708B: 7E 70 6D       '~pm'
Z708E   LDX     #forth_ERROR_NFA         ;708E: CE 6D E9       '.m.'
Z7091   DEX                              ;7091: 09             '.'
        LDAA    ,X                       ;7092: A6 00          '..'
        PSHA                             ;7094: 36             '6'
        CPX     #forth_PARENABORT_RPAREN_NFA ;7095: 8C 6D D9       '.m.'
        BNE     Z7091                    ;7098: 26 F7          '&.'
        JMP     Z7ECA                    ;709A: 7E 7E CA       '~~.'
        LDX     M602C                    ;709D: FE 60 2C       '.`,'
        STX     M04C4                    ;70A0: FF 04 C4       '...'
        LDX     M602A                    ;70A3: FE 60 2A       '.`*'
        STX     M04C2                    ;70A6: FF 04 C2       '...'
        LDX     M6028                    ;70A9: FE 60 28       '.`('
        STX     M04C0                    ;70AC: FF 04 C0       '...'
Z70AF   LDX     M6030                    ;70AF: FE 60 30       '.`0'
        STX     M04E8                    ;70B2: FF 04 E8       '...'
Z70B5   LDS     #M04BF                   ;70B5: 8E 04 BF       '...'
        LDX     #M6028                   ;70B8: CE 60 28       '.`('
Z70BB   DEX                              ;70BB: 09             '.'
        LDAA    ,X                       ;70BC: A6 00          '..'
        PSHA                             ;70BE: 36             '6'
        CPX     #M601E                   ;70BF: 8C 60 1E       '.`.'
        BNE     Z70BB                    ;70C2: 26 F7          '&.'
        LDS     M601E                    ;70C4: BE 60 1E       '.`.'
        LDX     M601C                    ;70C7: FE 60 1C       '.`.'
        STX     M0096                    ;70CA: DF 96          '..'
        LDX     M0098                    ;70CC: DE 98          '..'
        CPX     #M4F4B                   ;70CE: 8C 4F 4B       '.OK'
        BEQ     Z70DB                    ;70D1: 27 08          ''.'
        LDX     #M7047                   ;70D3: CE 70 47       '.pG'
Z70D6   STX     forth_IP                 ;70D6: DF 92          '..'
        JMP     forth_RP_STORE_PFA       ;70D8: 7E 64 37       '~d7'
Z70DB   LDX     #forth_ABORT_CFA         ;70DB: CE 70 24       '.p$'
        BRA     Z70D6                    ;70DE: 20 F6          ' .'
M70E0   FCB     $00                      ;70E0: 00             '.'
        NOP                              ;70E1: 01             '.'
        ASRB                             ;70E2: 57             'W'
        AIM     #$72,$0D,S               ;70E3: 61 72 6D       'arm'
        SWI                              ;70E6: 3F             '?'
Z70E7   LDAA    #$0C                     ;70E7: 86 0C          '..'
        JSR     ZFF4F                    ;70E9: BD FF 4F       '..O'
        LDX     #M70E0                   ;70EC: CE 70 E0       '.p.'
        LDAB    #$05                     ;70EF: C6 05          '..'
        JSR     rom_print_string         ;70F1: BD D7 15       '...'
        LDAA    #$16                     ;70F4: 86 16          '..'
        JSR     ZFF4F                    ;70F6: BD FF 4F       '..O'
        STX     M0098                    ;70F9: DF 98          '..'
        JSR     rom_serial_io            ;70FB: BD FF 9A       '...'
        RORA                             ;70FE: 46             'F'
        BCS     Z7104                    ;70FF: 25 03          '%.'
        JMP     forth_COLD_PFA           ;7101: 7E 70 8B       '~p.'
Z7104   JMP     Z70B5                    ;7104: 7E 70 B5       '~p.'
        FCB     $00                      ;7107: 00             '.'
        FCB     $00                      ;7108: 00             '.'
;
; --- :: S->D ---
forth_S_MINUS_GTD_NFA FCB     $84                      ;7109: 84             '.'
        FCC     "S->"                    ;710A: 53 2D 3E       'S->'
        FCB     $C4                      ;710D: C4             '.'
forth_S_MINUS_GTD_LFA FDB     forth_COLD_NFA           ;710E: 70 82          'p.'
forth_S_MINUS_GTD_CFA FDB     DOCOL                    ;7110: 65 F2          'e.'
forth_S_MINUS_GTD_PFA FDB     forth_DUP_CFA            ;7112: 65 64          ; DUP
        FDB     forth_0_LT_CFA           ;7114: 64 AF          ; 0<
        FDB     forth_MINUS_CFA          ;7116: 64 F4          ; MINUS
        FDB     forth_SEMIS_CFA          ;7118: 64 44          ; ;S
;
; --- :: D+- ---
forth_D_PLUS_MINUS_NFA FCB     $83                      ;711A: 83             '.'
        FCC     "D+"                     ;711B: 44 2B          'D+'
        FCB     $AD                      ;711D: AD             '.'
forth_D_PLUS_MINUS_LFA FDB     forth_S_MINUS_GTD_NFA    ;711E: 71 09          'q.'
forth_D_PLUS_MINUS_CFA FDB     DOCOL                    ;7120: 65 F2          'e.'
forth_D_PLUS_MINUS_PFA FDB     forth_0_LT_CFA           ;7122: 64 AF          ; 0<
        FDB     forth_0BRANCH_CFA,M0004  ;7124: 61 88 00 04    ; 0BRANCH
        FDB     forth_DMINUS_CFA         ;7128: 65 0D          ; DMINUS
        FDB     forth_SEMIS_CFA          ;712A: 64 44          ; ;S
;
; --- :: +- ---
forth_PLUS_MINUS_NFA FCB     $82                      ;712C: 82             '.'
        FCC     "+"                      ;712D: 2B             '+'
        FCB     $AD                      ;712E: AD             '.'
forth_PLUS_MINUS_LFA FDB     forth_D_PLUS_MINUS_NFA   ;712F: 71 1A          'q.'
forth_PLUS_MINUS_CFA FDB     DOCOL                    ;7131: 65 F2          'e.'
forth_PLUS_MINUS_PFA FDB     forth_0_LT_CFA           ;7133: 64 AF          ; 0<
        FDB     forth_0BRANCH_CFA,M0004  ;7135: 61 88 00 04    ; 0BRANCH
        FDB     forth_MINUS_CFA          ;7139: 64 F4          ; MINUS
        FDB     forth_SEMIS_CFA          ;713B: 64 44          ; ;S
;
; --- :: ABS ---
forth_ABS_NFA FCB     $83                      ;713D: 83             '.'
        FCC     "AB"                     ;713E: 41 42          'AB'
        FCB     $D3                      ;7140: D3             '.'
forth_ABS_LFA FDB     forth_PLUS_MINUS_NFA     ;7141: 71 2C          'q,'
forth_ABS_CFA FDB     DOCOL                    ;7143: 65 F2          'e.'
forth_ABS_PFA FDB     forth_DUP_CFA            ;7145: 65 64          ; DUP
        FDB     forth_PLUS_MINUS_CFA     ;7147: 71 31          ; +-
        FDB     forth_SEMIS_CFA          ;7149: 64 44          ; ;S
;
; --- :: DABS ---
forth_DABS_NFA FCB     $84                      ;714B: 84             '.'
        FCC     "DAB"                    ;714C: 44 41 42       'DAB'
        FCB     $D3                      ;714F: D3             '.'
forth_DABS_LFA FDB     forth_ABS_NFA            ;7150: 71 3D          'q='
forth_DABS_CFA FDB     DOCOL                    ;7152: 65 F2          'e.'
forth_DABS_PFA FDB     forth_DUP_CFA            ;7154: 65 64          ; DUP
        FDB     forth_D_PLUS_MINUS_CFA   ;7156: 71 20          ; D+-
        FDB     forth_SEMIS_CFA          ;7158: 64 44          ; ;S
;
; --- :: M* ---
forth_M_STAR_NFA FCB     $82                      ;715A: 82             '.'
        FCC     "M"                      ;715B: 4D             'M'
        FCB     $AA                      ;715C: AA             '.'
forth_M_STAR_LFA FDB     forth_DABS_NFA           ;715D: 71 4B          'qK'
forth_M_STAR_CFA FDB     DOCOL                    ;715F: 65 F2          'e.'
forth_M_STAR_PFA FDB     forth_2DUP_CFA           ;7161: 67 DC          ; 2DUP
        FDB     forth_XOR_CFA            ;7163: 64 02          ; XOR
        FDB     forth_GTR_CFA            ;7165: 64 69          ; >R
        FDB     forth_ABS_CFA            ;7167: 71 43          ; ABS
        FDB     forth_SWAP_CFA           ;7169: 65 4B          ; SWAP
        FDB     forth_ABS_CFA            ;716B: 71 43          ; ABS
        FDB     forth_U_STAR_CFA         ;716D: 63 7F          ; U*
        FDB     forth_R_GT_CFA           ;716F: 64 7D          ; R>
        FDB     forth_D_PLUS_MINUS_CFA   ;7171: 71 20          ; D+-
        FDB     forth_SEMIS_CFA          ;7173: 64 44          ; ;S
;
; --- :: M/ ---
forth_M_SLASH_NFA FCB     $82                      ;7175: 82             '.'
        FCC     "M"                      ;7176: 4D             'M'
        FCB     $AF                      ;7177: AF             '.'
forth_M_SLASH_LFA FDB     forth_M_STAR_NFA         ;7178: 71 5A          'qZ'
forth_M_SLASH_CFA FDB     DOCOL                    ;717A: 65 F2          'e.'
forth_M_SLASH_PFA FDB     forth_OVER_CFA           ;717C: 65 2E          ; OVER
        FDB     forth_GTR_CFA            ;717E: 64 69          ; >R
        FDB     forth_GTR_CFA            ;7180: 64 69          ; >R
        FDB     forth_DABS_CFA           ;7182: 71 52          ; DABS
        FDB     forth_R_CFA              ;7184: 64 8E          ; R
        FDB     forth_ABS_CFA            ;7186: 71 43          ; ABS
        FDB     forth_U_SLASH_CFA        ;7188: 63 A7          ; U/
        FDB     forth_R_GT_CFA           ;718A: 64 7D          ; R>
        FDB     forth_R_CFA              ;718C: 64 8E          ; R
        FDB     forth_XOR_CFA            ;718E: 64 02          ; XOR
        FDB     forth_PLUS_MINUS_CFA     ;7190: 71 31          ; +-
        FDB     forth_SWAP_CFA           ;7192: 65 4B          ; SWAP
        FDB     forth_R_GT_CFA           ;7194: 64 7D          ; R>
        FDB     forth_PLUS_MINUS_CFA     ;7196: 71 31          ; +-
        FDB     forth_SWAP_CFA           ;7198: 65 4B          ; SWAP
        FDB     forth_SEMIS_CFA          ;719A: 64 44          ; ;S
;
; --- CODE: * ---
forth_STAR_NFA FCB     $81,$AA                  ;719C: 81 AA          '..'
forth_STAR_LFA FDB     forth_M_SLASH_NFA        ;719E: 71 75          'qu'
forth_STAR_CFA FDB     forth_STAR_PFA           ;71A0: 71 A2          'q.'
forth_STAR_PFA JSR     Z6388                    ;71A2: BD 63 88       '.c.'
        INS                              ;71A5: 31             '1'
        INS                              ;71A6: 31             '1'
        JMP     NEXT                     ;71A7: 7E 61 30       '~a0'
;
; --- :: /MOD ---
forth_SLASHMOD_NFA FCB     $84                      ;71AA: 84             '.'
        FCC     "/MO"                    ;71AB: 2F 4D 4F       '/MO'
        FCB     $C4                      ;71AE: C4             '.'
forth_SLASHMOD_LFA FDB     forth_STAR_NFA           ;71AF: 71 9C          'q.'
forth_SLASHMOD_CFA FDB     DOCOL                    ;71B1: 65 F2          'e.'
forth_SLASHMOD_PFA FDB     forth_GTR_CFA            ;71B3: 64 69          ; >R
        FDB     forth_S_MINUS_GTD_CFA    ;71B5: 71 10          ; S->D
        FDB     forth_R_GT_CFA           ;71B7: 64 7D          ; R>
        FDB     forth_M_SLASH_CFA        ;71B9: 71 7A          ; M/
        FDB     forth_SEMIS_CFA          ;71BB: 64 44          ; ;S
;
; --- :: / ---
forth_SLASH_NFA FCB     $81,$AF                  ;71BD: 81 AF          '..'
forth_SLASH_LFA FDB     forth_SLASHMOD_NFA       ;71BF: 71 AA          'q.'
forth_SLASH_CFA FDB     DOCOL                    ;71C1: 65 F2          'e.'
forth_SLASH_PFA FDB     forth_SLASHMOD_CFA       ;71C3: 71 B1          ; /MOD
        FDB     forth_SWAP_CFA           ;71C5: 65 4B          ; SWAP
        FDB     forth_DROP_CFA           ;71C7: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;71C9: 64 44          ; ;S
;
; --- :: */MOD ---
forth_STAR_SLASHMOD_NFA FCB     $85                      ;71CB: 85             '.'
        FCC     "*/MO"                   ;71CC: 2A 2F 4D 4F    '*/MO'
        FCB     $C4                      ;71D0: C4             '.'
forth_STAR_SLASHMOD_LFA FDB     forth_SLASH_NFA          ;71D1: 71 BD          'q.'
forth_STAR_SLASHMOD_CFA FDB     DOCOL                    ;71D3: 65 F2          'e.'
forth_STAR_SLASHMOD_PFA FDB     forth_GTR_CFA            ;71D5: 64 69          ; >R
        FDB     forth_U_STAR_CFA         ;71D7: 63 7F          ; U*
        FDB     forth_R_GT_CFA           ;71D9: 64 7D          ; R>
        FDB     forth_U_SLASH_CFA        ;71DB: 63 A7          ; U/
        FDB     forth_SEMIS_CFA          ;71DD: 64 44          ; ;S
;
; --- :: */ ---
forth_STAR_SLASH_NFA FCB     $82                      ;71DF: 82             '.'
        FCC     "*"                      ;71E0: 2A             '*'
        FCB     $AF                      ;71E1: AF             '.'
forth_STAR_SLASH_LFA FDB     forth_STAR_SLASHMOD_NFA  ;71E2: 71 CB          'q.'
forth_STAR_SLASH_CFA FDB     DOCOL                    ;71E4: 65 F2          'e.'
forth_STAR_SLASH_PFA FDB     forth_STAR_SLASHMOD_CFA  ;71E6: 71 D3          ; */MOD
        FDB     forth_SWAP_CFA           ;71E8: 65 4B          ; SWAP
        FDB     forth_DROP_CFA           ;71EA: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;71EC: 64 44          ; ;S
;
; --- :: M/MOD ---
forth_M_SLASHMOD_NFA FCB     $85                      ;71EE: 85             '.'
        FCC     "M/MO"                   ;71EF: 4D 2F 4D 4F    'M/MO'
        FCB     $C4                      ;71F3: C4             '.'
forth_M_SLASHMOD_LFA FDB     forth_STAR_SLASH_NFA     ;71F4: 71 DF          'q.'
forth_M_SLASHMOD_CFA FDB     DOCOL                    ;71F6: 65 F2          'e.'
forth_M_SLASHMOD_PFA FDB     forth_GTR_CFA            ;71F8: 64 69          ; >R
        FDB     forth_0_CFA,forth_R_CFA  ;71FA: 66 62 64 8E    ; 0
        FDB     forth_U_SLASH_CFA        ;71FE: 63 A7          ; U/
        FDB     forth_R_GT_CFA           ;7200: 64 7D          ; R>
        FDB     forth_SWAP_CFA           ;7202: 65 4B          ; SWAP
        FDB     forth_GTR_CFA            ;7204: 64 69          ; >R
        FDB     forth_U_SLASH_CFA        ;7206: 63 A7          ; U/
        FDB     forth_R_GT_CFA           ;7208: 64 7D          ; R>
        FDB     forth_SEMIS_CFA          ;720A: 64 44          ; ;S
;
; --- :: .LINE ---
forth_DOTLINE_NFA FCB     $85                      ;720C: 85             '.'
        FCC     ".LIN"                   ;720D: 2E 4C 49 4E    '.LIN'
        FCB     $C5                      ;7211: C5             '.'
forth_DOTLINE_LFA FDB     forth_M_SLASHMOD_NFA     ;7212: 71 EE          'q.'
forth_DOTLINE_CFA FDB     DOCOL                    ;7214: 65 F2          'e.'
forth_DOTLINE_PFA FDB     forth_C_SLASHL_CFA       ;7216: 67 99          ; C/L
        FDB     forth_STAR_CFA           ;7218: 71 A0          ; *
        FDB     forth_FIRST_CFA          ;721A: 66 8F          ; FIRST
        FDB     forth_PLUS_CFA           ;721C: 64 C6          ; +
        FDB     forth_C_SLASHL_CFA       ;721E: 67 99          ; C/L
        FDB     forth_MINUSTRAILING_CFA  ;7220: 6B 08          ; -TRAILING
        FDB     forth_TYPE_CFA           ;7222: 6A DA          ; TYPE
        FDB     forth_SEMIS_CFA          ;7224: 64 44          ; ;S
;
; --- :: ' [IMMEDIATE] ---
forth_TICK_NFA FCB     $C1,$A7                  ;7226: C1 A7          '..'
forth_TICK_LFA FDB     forth_DOTLINE_NFA        ;7228: 72 0C          'r.'
forth_TICK_CFA FDB     DOCOL                    ;722A: 65 F2          'e.'
forth_TICK_PFA FDB     forth_MINUSFIND_CFA      ;722C: 6D B7          ; -FIND
        FDB     forth_0_EQ_CFA           ;722E: 64 9C          ; 0=
        FDB     forth_0_CFA              ;7230: 66 62          ; 0
        FDB     forth_QUESTIONERROR_CFA  ;7232: 69 50          ; ?ERROR
        FDB     forth_DROP_CFA           ;7234: 65 3D          ; DROP
        FDB     forth_LITERAL_CFA        ;7236: 6E D0          ; LITERAL
        FDB     forth_SEMIS_CFA          ;7238: 64 44          ; ;S
;
; --- :: BACK ---
forth_BACK_NFA FCB     $84                      ;723A: 84             '.'
        FCC     "BAC"                    ;723B: 42 41 43       'BAC'
        FCB     $CB                      ;723E: CB             '.'
forth_BACK_LFA FDB     forth_TICK_NFA           ;723F: 72 26          'r&'
forth_BACK_CFA FDB     DOCOL                    ;7241: 65 F2          'e.'
forth_BACK_PFA FDB     forth_HERE_CFA           ;7243: 67 BE          ; HERE
        FDB     forth_MINUS_CFA          ;7245: 68 19          ; -
        FDB     forth_COMMA_CFA          ;7247: 67 F8          ; ,
        FDB     forth_SEMIS_CFA          ;7249: 64 44          ; ;S
;
; --- :: BEGIN [IMMEDIATE] ---
forth_BEGIN_NFA FCB     $C5                      ;724B: C5             '.'
        FCC     "BEGI"                   ;724C: 42 45 47 49    'BEGI'
        FCB     $CE                      ;7250: CE             '.'
forth_BEGIN_LFA FDB     forth_BACK_NFA           ;7251: 72 3A          'r:'
forth_BEGIN_CFA FDB     DOCOL                    ;7253: 65 F2          'e.'
forth_BEGIN_PFA FDB     forth_QUESTIONCOMP_CFA   ;7255: 69 6A          ; ?COMP
        FDB     forth_HERE_CFA           ;7257: 67 BE          ; HERE
        FDB     forth_1_CFA              ;7259: 66 6A          ; 1
        FDB     forth_SEMIS_CFA          ;725B: 64 44          ; ;S
;
; --- :: THEN [IMMEDIATE] ---
forth_THEN_NFA FCB     $C4                      ;725D: C4             '.'
        FCC     "THE"                    ;725E: 54 48 45       'THE'
        FCB     $CE                      ;7261: CE             '.'
forth_THEN_LFA FDB     forth_BEGIN_NFA          ;7262: 72 4B          'rK'
forth_THEN_CFA FDB     DOCOL                    ;7264: 65 F2          'e.'
forth_THEN_PFA FDB     forth_QUESTIONCOMP_CFA   ;7266: 69 6A          ; ?COMP
        FDB     forth_2_CFA              ;7268: 66 72          ; 2
        FDB     forth_QUESTIONPAIRS_CFA  ;726A: 69 97          ; ?PAIRS
        FDB     forth_HERE_CFA           ;726C: 67 BE          ; HERE
        FDB     forth_OVER_CFA           ;726E: 65 2E          ; OVER
        FDB     forth_MINUS_CFA          ;7270: 68 19          ; -
        FDB     forth_SWAP_CFA           ;7272: 65 4B          ; SWAP
        FDB     forth_STORE_CFA          ;7274: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;7276: 64 44          ; ;S
;
; --- :: DO [IMMEDIATE] ---
forth_DO_NFA FCB     $C2                      ;7278: C2             '.'
        FCC     "D"                      ;7279: 44             'D'
        FCB     $CF                      ;727A: CF             '.'
forth_DO_LFA FDB     forth_THEN_NFA           ;727B: 72 5D          'r]'
forth_DO_CFA FDB     DOCOL                    ;727D: 65 F2          'e.'
forth_DO_PFA FDB     forth_COMPILE_CFA        ;727F: 69 DE          ; COMPILE
        FDB     forth_PARENDO_RPAREN_CFA ;7281: 61 EF          ; (DO)
        FDB     forth_HERE_CFA           ;7283: 67 BE          ; HERE
        FDB     forth_3_CFA              ;7285: 66 7A          ; 3
        FDB     forth_SEMIS_CFA          ;7287: 64 44          ; ;S
;
; --- :: LOOP [IMMEDIATE] ---
forth_LOOP_NFA FCB     $C4                      ;7289: C4             '.'
        FCC     "LOO"                    ;728A: 4C 4F 4F       'LOO'
        FCB     $D0                      ;728D: D0             '.'
forth_LOOP_LFA FDB     forth_DO_NFA             ;728E: 72 78          'rx'
forth_LOOP_CFA FDB     DOCOL                    ;7290: 65 F2          'e.'
forth_LOOP_PFA FDB     forth_3_CFA              ;7292: 66 7A          ; 3
        FDB     forth_QUESTIONPAIRS_CFA  ;7294: 69 97          ; ?PAIRS
        FDB     forth_COMPILE_CFA        ;7296: 69 DE          ; COMPILE
        FDB     forth_PARENLOOP_RPAREN_CFA ;7298: 61 AE          ; (LOOP)
        FDB     forth_BACK_CFA           ;729A: 72 41          ;   [->$E4DB]
        FDB     forth_SEMIS_CFA          ;729C: 64 44          ; ;S
;
; --- :: +LOOP [IMMEDIATE] ---
forth_PLUSLOOP_NFA FCB     $C5                      ;729E: C5             '.'
        FCC     "+LOO"                   ;729F: 2B 4C 4F 4F    '+LOO'
        FCB     $D0                      ;72A3: D0             '.'
forth_PLUSLOOP_LFA FDB     forth_LOOP_NFA           ;72A4: 72 89          'r.'
forth_PLUSLOOP_CFA FDB     DOCOL                    ;72A6: 65 F2          'e.'
forth_PLUSLOOP_PFA FDB     forth_3_CFA              ;72A8: 66 7A          ; 3
        FDB     forth_QUESTIONPAIRS_CFA  ;72AA: 69 97          ; ?PAIRS
        FDB     forth_COMPILE_CFA        ;72AC: 69 DE          ; COMPILE
        FDB     forth_PAREN_PLUSLOOP_RPAREN_CFA ;72AE: 61 BF          ; (+LOOP)
        FDB     forth_BACK_CFA           ;72B0: 72 41          ;   [->$E4F1]
        FDB     forth_SEMIS_CFA          ;72B2: 64 44          ; ;S
;
; --- :: UNTIL [IMMEDIATE] ---
forth_UNTIL_NFA FCB     $C5                      ;72B4: C5             '.'
        FCC     "UNTI"                   ;72B5: 55 4E 54 49    'UNTI'
        FCB     $CC                      ;72B9: CC             '.'
forth_UNTIL_LFA FDB     forth_PLUSLOOP_NFA       ;72BA: 72 9E          'r.'
forth_UNTIL_CFA FDB     DOCOL                    ;72BC: 65 F2          'e.'
forth_UNTIL_PFA FDB     forth_1_CFA              ;72BE: 66 6A          ; 1
        FDB     forth_QUESTIONPAIRS_CFA  ;72C0: 69 97          ; ?PAIRS
        FDB     forth_COMPILE_CFA        ;72C2: 69 DE          ; COMPILE
        FDB     forth_0BRANCH_CFA        ;72C4: 61 88          ; 0BRANCH
        FDB     forth_BACK_CFA           ;72C6: 72 41          ;   [->$E507]
        FDB     forth_SEMIS_CFA          ;72C8: 64 44          ; ;S
;
; --- :: END [IMMEDIATE] ---
forth_END_NFA FCB     $C3                      ;72CA: C3             '.'
        FCC     "EN"                     ;72CB: 45 4E          'EN'
        FCB     $C4                      ;72CD: C4             '.'
forth_END_LFA FDB     forth_UNTIL_NFA          ;72CE: 72 B4          'r.'
forth_END_CFA FDB     DOCOL                    ;72D0: 65 F2          'e.'
forth_END_PFA FDB     forth_UNTIL_CFA          ;72D2: 72 BC          ; UNTIL
        FDB     forth_SEMIS_CFA          ;72D4: 64 44          ; ;S
;
; --- :: AGAIN [IMMEDIATE] ---
forth_AGAIN_NFA FCB     $C5                      ;72D6: C5             '.'
        FCC     "AGAI"                   ;72D7: 41 47 41 49    'AGAI'
        FCB     $CE                      ;72DB: CE             '.'
forth_AGAIN_LFA FDB     forth_END_NFA            ;72DC: 72 CA          'r.'
forth_AGAIN_CFA FDB     DOCOL                    ;72DE: 65 F2          'e.'
forth_AGAIN_PFA FDB     forth_1_CFA              ;72E0: 66 6A          ; 1
        FDB     forth_QUESTIONPAIRS_CFA  ;72E2: 69 97          ; ?PAIRS
        FDB     forth_COMPILE_CFA        ;72E4: 69 DE          ; COMPILE
        FDB     forth_BRANCH_CFA         ;72E6: 61 7C          ; BRANCH
        FDB     forth_BACK_CFA           ;72E8: 72 41          ;   [->$E529]
        FDB     forth_SEMIS_CFA          ;72EA: 64 44          ; ;S
;
; --- :: REPEAT [IMMEDIATE] ---
forth_REPEAT_NFA FCB     $C6                      ;72EC: C6             '.'
        FCC     "REPEA"                  ;72ED: 52 45 50 45 41 'REPEA'
        FCB     $D4                      ;72F2: D4             '.'
forth_REPEAT_LFA FDB     forth_AGAIN_NFA          ;72F3: 72 D6          'r.'
forth_REPEAT_CFA FDB     DOCOL                    ;72F5: 65 F2          'e.'
forth_REPEAT_PFA FDB     forth_GTR_CFA            ;72F7: 64 69          ; >R
        FDB     forth_GTR_CFA            ;72F9: 64 69          ; >R
        FDB     forth_AGAIN_CFA          ;72FB: 72 DE          ; AGAIN
        FDB     forth_R_GT_CFA           ;72FD: 64 7D          ; R>
        FDB     forth_R_GT_CFA           ;72FF: 64 7D          ; R>
        FDB     forth_2_CFA              ;7301: 66 72          ; 2
        FDB     forth_MINUS_CFA          ;7303: 68 19          ; -
        FDB     forth_THEN_CFA           ;7305: 72 64          ; THEN
        FDB     forth_SEMIS_CFA          ;7307: 64 44          ; ;S
;
; --- :: IF [IMMEDIATE] ---
forth_IF_NFA FCB     $C2                      ;7309: C2             '.'
        FCC     "I"                      ;730A: 49             'I'
        FCB     $C6                      ;730B: C6             '.'
forth_IF_LFA FDB     forth_REPEAT_NFA         ;730C: 72 EC          'r.'
forth_IF_CFA FDB     DOCOL                    ;730E: 65 F2          'e.'
forth_IF_PFA FDB     forth_COMPILE_CFA        ;7310: 69 DE          ; COMPILE
        FDB     forth_0BRANCH_CFA        ;7312: 61 88          ; 0BRANCH
        FDB     forth_HERE_CFA           ;7314: 67 BE          ;   [->$DAD2]
        FDB     forth_0_CFA              ;7316: 66 62          ; 0
        FDB     forth_COMMA_CFA          ;7318: 67 F8          ; ,
        FDB     forth_2_CFA              ;731A: 66 72          ; 2
        FDB     forth_SEMIS_CFA          ;731C: 64 44          ; ;S
;
; --- :: ELSE [IMMEDIATE] ---
forth_ELSE_NFA FCB     $C4                      ;731E: C4             '.'
        FCC     "ELS"                    ;731F: 45 4C 53       'ELS'
        FCB     $C5                      ;7322: C5             '.'
forth_ELSE_LFA FDB     forth_IF_NFA             ;7323: 73 09          's.'
forth_ELSE_CFA FDB     DOCOL                    ;7325: 65 F2          'e.'
forth_ELSE_PFA FDB     forth_2_CFA              ;7327: 66 72          ; 2
        FDB     forth_QUESTIONPAIRS_CFA  ;7329: 69 97          ; ?PAIRS
        FDB     forth_COMPILE_CFA        ;732B: 69 DE          ; COMPILE
        FDB     forth_BRANCH_CFA         ;732D: 61 7C          ; BRANCH
        FDB     forth_HERE_CFA           ;732F: 67 BE          ;   [->$DAED]
        FDB     forth_0_CFA              ;7331: 66 62          ; 0
        FDB     forth_COMMA_CFA          ;7333: 67 F8          ; ,
        FDB     forth_SWAP_CFA           ;7335: 65 4B          ; SWAP
        FDB     forth_2_CFA              ;7337: 66 72          ; 2
        FDB     forth_THEN_CFA           ;7339: 72 64          ; THEN
        FDB     forth_2_CFA              ;733B: 66 72          ; 2
        FDB     forth_SEMIS_CFA          ;733D: 64 44          ; ;S
;
; --- :: WHILE [IMMEDIATE] ---
forth_WHILE_NFA FCB     $C5                      ;733F: C5             '.'
        FCC     "WHIL"                   ;7340: 57 48 49 4C    'WHIL'
        FCB     $C5                      ;7344: C5             '.'
forth_WHILE_LFA FDB     forth_ELSE_NFA           ;7345: 73 1E          's.'
forth_WHILE_CFA FDB     DOCOL                    ;7347: 65 F2          'e.'
forth_WHILE_PFA FDB     forth_IF_CFA             ;7349: 73 0E          ; IF
        FDB     forth_2_PLUS_CFA         ;734B: 67 AF          ; 2+
        FDB     forth_SEMIS_CFA          ;734D: 64 44          ; ;S
;
; --- :: SPACES ---
forth_SPACES_NFA FCB     $86                      ;734F: 86             '.'
        FCC     "SPACE"                  ;7350: 53 50 41 43 45 'SPACE'
        FCB     $D3                      ;7355: D3             '.'
forth_SPACES_LFA FDB     forth_WHILE_NFA          ;7356: 73 3F          's?'
forth_SPACES_CFA FDB     DOCOL                    ;7358: 65 F2          'e.'
forth_SPACES_PFA FDB     forth_0_CFA              ;735A: 66 62          ; 0
        FDB     forth_MAX_CFA            ;735C: 68 95          ; MAX
        FDB     forth_MINUSDUP_CFA       ;735E: 68 AC          ; -DUP
        FDB     forth_0BRANCH_CFA,$000C  ;7360: 61 88 00 0C    ; 0BRANCH
        FDB     forth_0_CFA              ;7364: 66 62          ; 0
        FDB     forth_PARENDO_RPAREN_CFA ;7366: 61 EF          ; (DO)
        FDB     forth_SPACE_CFA          ;7368: 68 71          ; SPACE
        FDB     forth_PARENLOOP_RPAREN_CFA ;736A: 61 AE          ; (LOOP)
        FDB     $FFFC,forth_SEMIS_CFA    ;736C: FF FC 64 44    ;   [->$7368]
;
; --- :: <# ---
forth_LT_HASH_NFA FCB     $82                      ;7370: 82             '.'
        FCC     "<"                      ;7371: 3C             '<'
        FCB     $A3                      ;7372: A3             '.'
forth_LT_HASH_LFA FDB     forth_SPACES_NFA         ;7373: 73 4F          'sO'
forth_LT_HASH_CFA FDB     DOCOL                    ;7375: 65 F2          'e.'
forth_LT_HASH_PFA FDB     forth_PAD_CFA            ;7377: 6C 9B          ; PAD
        FDB     forth_HLD_CFA            ;7379: 67 8F          ; HLD
        FDB     forth_STORE_CFA          ;737B: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;737D: 64 44          ; ;S
;
; --- :: #> ---
forth_HASH_GT_NFA FCB     $82                      ;737F: 82             '.'
        FCC     "#"                      ;7380: 23             '#'
        FCB     $BE                      ;7381: BE             '.'
forth_HASH_GT_LFA FDB     forth_LT_HASH_NFA        ;7382: 73 70          'sp'
forth_HASH_GT_CFA FDB     DOCOL                    ;7384: 65 F2          'e.'
forth_HASH_GT_PFA FDB     forth_2DROP_CFA          ;7386: 67 CE          ; 2DROP
        FDB     forth_HLD_CFA            ;7388: 67 8F          ; HLD
        FDB     forth_FETCH_CFA          ;738A: 65 9D          ; @
        FDB     forth_PAD_CFA            ;738C: 6C 9B          ; PAD
        FDB     forth_OVER_CFA           ;738E: 65 2E          ; OVER
        FDB     forth_MINUS_CFA          ;7390: 68 19          ; -
        FDB     forth_SEMIS_CFA          ;7392: 64 44          ; ;S
;
; --- :: SIGN ---
forth_SIGN_NFA FCB     $84                      ;7394: 84             '.'
        FCC     "SIG"                    ;7395: 53 49 47       'SIG'
        FCB     $CE                      ;7398: CE             '.'
forth_SIGN_LFA FDB     forth_HASH_GT_NFA        ;7399: 73 7F          's.'
forth_SIGN_CFA FDB     DOCOL                    ;739B: 65 F2          'e.'
forth_SIGN_PFA FDB     forth_ROT_CFA            ;739D: 68 5D          ; ROT
        FDB     forth_0_LT_CFA           ;739F: 64 AF          ; 0<
        FDB     forth_0BRANCH_CFA,M0008  ;73A1: 61 88 00 08    ; 0BRANCH
        FDB     forth_LIT_CFA,$002D      ;73A5: 61 45 00 2D    ; LIT
        FDB     forth_HOLD_CFA           ;73A9: 6C 83          ; HOLD
        FDB     forth_SEMIS_CFA          ;73AB: 64 44          ; ;S
;
; --- :: # ---
forth_HASH_NFA FCB     $81,$A3                  ;73AD: 81 A3          '..'
forth_HASH_LFA FDB     forth_SIGN_NFA           ;73AF: 73 94          's.'
forth_HASH_CFA FDB     DOCOL                    ;73B1: 65 F2          'e.'
forth_HASH_PFA FDB     forth_BASE_CFA           ;73B3: 67 5E          ; BASE
        FDB     forth_FETCH_CFA          ;73B5: 65 9D          ; @
        FDB     forth_M_SLASHMOD_CFA     ;73B7: 71 F6          ; M/MOD
        FDB     forth_ROT_CFA            ;73B9: 68 5D          ; ROT
        FDB     forth_LIT_CFA,$0009      ;73BB: 61 45 00 09    ; LIT
        FDB     forth_OVER_CFA           ;73BF: 65 2E          ; OVER
        FDB     forth_LT_CFA             ;73C1: 68 31          ; <
        FDB     forth_0BRANCH_CFA,M0008  ;73C3: 61 88 00 08    ; 0BRANCH
        FDB     forth_LIT_CFA,$0007      ;73C7: 61 45 00 07    ; LIT
        FDB     forth_PLUS_CFA           ;73CB: 64 C6          ; +
        FDB     forth_LIT_CFA,$0030      ;73CD: 61 45 00 30    ; LIT
        FDB     forth_PLUS_CFA           ;73D1: 64 C6          ; +
        FDB     forth_HOLD_CFA           ;73D3: 6C 83          ; HOLD
        FDB     forth_SEMIS_CFA          ;73D5: 64 44          ; ;S
;
; --- :: #S ---
forth_HASHS_NFA FCB     $82                      ;73D7: 82             '.'
        FCC     "#"                      ;73D8: 23             '#'
        FCB     $D3                      ;73D9: D3             '.'
forth_HASHS_LFA FDB     forth_HASH_NFA           ;73DA: 73 AD          's.'
forth_HASHS_CFA FDB     DOCOL                    ;73DC: 65 F2          'e.'
forth_HASHS_PFA FDB     forth_HASH_CFA           ;73DE: 73 B1          ; #
        FDB     forth_2DUP_CFA           ;73E0: 67 DC          ; 2DUP
        FDB     forth_OR_CFA             ;73E2: 63 F0          ; OR
        FDB     forth_0_EQ_CFA           ;73E4: 64 9C          ; 0=
        FDB     forth_0BRANCH_CFA,$FFF6  ;73E6: 61 88 FF F6    ; 0BRANCH
        FDB     forth_SEMIS_CFA          ;73EA: 64 44          ; ;S
;
; --- :: D.R ---
forth_D_DOTR_NFA FCB     $83                      ;73EC: 83             '.'
        FCC     "D."                     ;73ED: 44 2E          'D.'
        FCB     $D2                      ;73EF: D2             '.'
forth_D_DOTR_LFA FDB     forth_HASHS_NFA          ;73F0: 73 D7          's.'
forth_D_DOTR_CFA FDB     DOCOL                    ;73F2: 65 F2          'e.'
forth_D_DOTR_PFA FDB     forth_GTR_CFA            ;73F4: 64 69          ; >R
        FDB     forth_SWAP_CFA           ;73F6: 65 4B          ; SWAP
        FDB     forth_OVER_CFA           ;73F8: 65 2E          ; OVER
        FDB     forth_DABS_CFA           ;73FA: 71 52          ; DABS
        FDB     forth_LT_HASH_CFA        ;73FC: 73 75          ; <#
        FDB     forth_HASHS_CFA          ;73FE: 73 DC          ; #S
        FDB     forth_SIGN_CFA           ;7400: 73 9B          ; SIGN
        FDB     forth_HASH_GT_CFA        ;7402: 73 84          ; #>
        FDB     forth_R_GT_CFA           ;7404: 64 7D          ; R>
        FDB     forth_OVER_CFA           ;7406: 65 2E          ; OVER
        FDB     forth_MINUS_CFA          ;7408: 68 19          ; -
        FDB     forth_SPACES_CFA         ;740A: 73 58          ; SPACES
        FDB     forth_TYPE_CFA           ;740C: 6A DA          ; TYPE
        FDB     forth_SEMIS_CFA          ;740E: 64 44          ; ;S
;
; --- :: D. ---
forth_D_DOT_NFA FCB     $82                      ;7410: 82             '.'
        FCC     "D"                      ;7411: 44             'D'
        FCB     $AE                      ;7412: AE             '.'
forth_D_DOT_LFA FDB     forth_D_DOTR_NFA         ;7413: 73 EC          's.'
forth_D_DOT_CFA FDB     DOCOL                    ;7415: 65 F2          'e.'
forth_D_DOT_PFA FDB     forth_0_CFA              ;7417: 66 62          ; 0
        FDB     forth_D_DOTR_CFA         ;7419: 73 F2          ; D.R
        FDB     forth_SPACE_CFA          ;741B: 68 71          ; SPACE
        FDB     forth_SEMIS_CFA          ;741D: 64 44          ; ;S
;
; --- :: .R ---
forth_DOTR_NFA FCB     $82                      ;741F: 82             '.'
        FCC     "."                      ;7420: 2E             '.'
        FCB     $D2                      ;7421: D2             '.'
forth_DOTR_LFA FDB     forth_D_DOT_NFA          ;7422: 74 10          't.'
forth_DOTR_CFA FDB     DOCOL                    ;7424: 65 F2          'e.'
forth_DOTR_PFA FDB     forth_GTR_CFA            ;7426: 64 69          ; >R
        FDB     forth_S_MINUS_GTD_CFA    ;7428: 71 10          ; S->D
        FDB     forth_R_GT_CFA           ;742A: 64 7D          ; R>
        FDB     forth_D_DOTR_CFA         ;742C: 73 F2          ; D.R
        FDB     forth_SEMIS_CFA          ;742E: 64 44          ; ;S
;
; --- :: . ---
forth_DOT_NFA FCB     $81,$AE                  ;7430: 81 AE          '..'
forth_DOT_LFA FDB     forth_DOTR_NFA           ;7432: 74 1F          't.'
forth_DOT_CFA FDB     DOCOL                    ;7434: 65 F2          'e.'
forth_DOT_PFA FDB     forth_S_MINUS_GTD_CFA    ;7436: 71 10          ; S->D
        FDB     forth_D_DOT_CFA          ;7438: 74 15          ; D.
        FDB     forth_SEMIS_CFA          ;743A: 64 44          ; ;S
;
; --- :: ? ---
forth_QUESTION_NFA FCB     $81,$BF                  ;743C: 81 BF          '..'
forth_QUESTION_LFA FDB     forth_DOT_NFA            ;743E: 74 30          't0'
forth_QUESTION_CFA FDB     DOCOL                    ;7440: 65 F2          'e.'
forth_QUESTION_PFA FDB     forth_FETCH_CFA          ;7442: 65 9D          ; @
        FDB     forth_DOT_CFA            ;7444: 74 34          ; .
        FDB     forth_SEMIS_CFA          ;7446: 64 44          ; ;S
;
; --- :: MESSAGE ---
forth_MESSAGE_NFA FCB     $87                      ;7448: 87             '.'
        FCC     "MESSAG"                 ;7449: 4D 45 53 53 41 47 'MESSAG'
        FCB     $C5                      ;744F: C5             '.'
forth_MESSAGE_LFA FDB     forth_QUESTION_NFA       ;7450: 74 3C          't<'
forth_MESSAGE_CFA FDB     DOCOL                    ;7452: 65 F2          'e.'
forth_MESSAGE_PFA FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;7454: 6B 39          ; (.")
        FDB     $064D,$5347,$2023,$2074  ;7456: 06 4D 53 47 20 23 20 74 ;   ["MSG # "]
        FDB     $3464                    ;745E: 34 64          '4d'
        FDB     $4486                    ;7460: 44 86          'D.'
        FCC     "FORGE"                  ;7462: 46 4F 52 47 45 'FORGE'
        FCB     $D4                      ;7467: D4             '.'
forth_FORGET_LFA FDB     forth_MESSAGE_NFA        ;7468: 74 48          'tH'
forth_FORGET_CFA FDB     DOCOL                    ;746A: 65 F2          'e.'
forth_FORGET_PFA FDB     forth_CURRENT_CFA        ;746C: 67 47          ; CURRENT
        FDB     forth_FETCH_CFA          ;746E: 65 9D          ; @
        FDB     forth_CONTEXT_CFA        ;7470: 67 39          ; CONTEXT
        FDB     forth_FETCH_CFA          ;7472: 65 9D          ; @
        FDB     forth_MINUS_CFA          ;7474: 68 19          ; -
        FDB     forth_LIT_CFA,$0018      ;7476: 61 45 00 18    ; LIT
        FDB     forth_QUESTIONERROR_CFA  ;747A: 69 50          ; ?ERROR
        FDB     forth_TICK_CFA           ;747C: 72 2A          ; '
        FDB     forth_DUP_CFA            ;747E: 65 64          ; DUP
        FDB     forth_FENCE_CFA          ;7480: 66 DF          ; FENCE
        FDB     forth_FETCH_CFA          ;7482: 65 9D          ; @
        FDB     forth_LT_CFA             ;7484: 68 31          ; <
        FDB     forth_LIT_CFA,$0015      ;7486: 61 45 00 15    ; LIT
        FDB     forth_QUESTIONERROR_CFA  ;748A: 69 50          ; ?ERROR
        FDB     forth_DUP_CFA            ;748C: 65 64          ; DUP
        FDB     forth_NFA_CFA            ;748E: 69 14          ; NFA
        FDB     forth_DP_CFA             ;7490: 66 E8          ; DP
        FDB     forth_STORE_CFA          ;7492: 65 BD          ; !
        FDB     forth_LFA_CFA            ;7494: 68 F7          ; LFA
        FDB     forth_FETCH_CFA          ;7496: 65 9D          ; @
        FDB     forth_CURRENT_CFA        ;7498: 67 47          ; CURRENT
        FDB     forth_FETCH_CFA          ;749A: 65 9D          ; @
        FDB     forth_STORE_CFA          ;749C: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;749E: 64 44          ; ;S
;
; --- CODE: MON ---
forth_MON_NFA FCB     $83                      ;74A0: 83             '.'
        FCC     "MO"                     ;74A1: 4D 4F          'MO'
        FCB     $CE                      ;74A3: CE             '.'
forth_MON_LFA FDB     forth_FORGET_NFA         ;74A4: 74 61          'ta'
forth_MON_CFA FDB     forth_MON_PFA            ;74A6: 74 A8          't.'
forth_MON_PFA JSR     ZD310                    ;74A8: BD D3 10       '...'
        JMP     NEXT                     ;74AB: 7E 61 30       '~a0'
;
; --- :: CLS ---
forth_CLS_NFA FCB     $83                      ;74AE: 83             '.'
        FCC     "CL"                     ;74AF: 43 4C          'CL'
        FCB     $D3                      ;74B1: D3             '.'
forth_CLS_LFA FDB     forth_MON_NFA            ;74B2: 74 A0          't.'
forth_CLS_CFA FDB     DOCOL                    ;74B4: 65 F2          'e.'
forth_CLS_PFA FDB     forth_LIT_CFA,$000C      ;74B6: 61 45 00 0C    ; LIT
        FDB     forth_EMIT_CFA           ;74BA: 63 02          ; EMIT
        FDB     forth_SEMIS_CFA          ;74BC: 64 44          ; ;S
;
; --- :: PICK ---
forth_PICK_NFA FCB     $84                      ;74BE: 84             '.'
        FCC     "PIC"                    ;74BF: 50 49 43       'PIC'
        FCB     $CB                      ;74C2: CB             '.'
forth_PICK_LFA FDB     forth_CLS_NFA            ;74C3: 74 AE          't.'
forth_PICK_CFA FDB     DOCOL                    ;74C5: 65 F2          'e.'
forth_PICK_PFA FDB     forth_DUP_CFA            ;74C7: 65 64          ; DUP
        FDB     forth_1_CFA              ;74C9: 66 6A          ; 1
        FDB     forth_LT_CFA             ;74CB: 68 31          ; <
        FDB     forth_LIT_CFA,$0005      ;74CD: 61 45 00 05    ; LIT
        FDB     forth_QUESTIONERROR_CFA  ;74D1: 69 50          ; ?ERROR
        FDB     forth_DUP_CFA            ;74D3: 65 64          ; DUP
        FDB     forth_PLUS_CFA           ;74D5: 64 C6          ; +
        FDB     forth_SP_FETCH_CFA       ;74D7: 64 14          ; SP@
        FDB     forth_PLUS_CFA           ;74D9: 64 C6          ; +
        FDB     forth_FETCH_CFA          ;74DB: 65 9D          ; @
        FDB     forth_SEMIS_CFA          ;74DD: 64 44          ; ;S
;
; --- :: <CMOVE ---
forth_LTCMOVE_NFA FCB     $86                      ;74DF: 86             '.'
        FCC     "<CMOV"                  ;74E0: 3C 43 4D 4F 56 '<CMOV'
        FCB     $C5                      ;74E5: C5             '.'
forth_LTCMOVE_LFA FDB     forth_PICK_NFA           ;74E6: 74 BE          't.'
forth_LTCMOVE_CFA FDB     DOCOL                    ;74E8: 65 F2          'e.'
forth_LTCMOVE_PFA FDB     forth_1_CFA              ;74EA: 66 6A          ; 1
        FDB     forth_MINUS_CFA          ;74EC: 68 19          ; -
        FDB     forth_LIT_CFA,$FFFF      ;74EE: 61 45 FF FF    ; LIT
        FDB     forth_SWAP_CFA           ;74F2: 65 4B          ; SWAP
        FDB     forth_PARENDO_RPAREN_CFA ;74F4: 61 EF          ; (DO)
        FDB     forth_OVER_CFA           ;74F6: 65 2E          ; OVER
        FDB     forth_I_CFA              ;74F8: 62 08          ; I
        FDB     forth_PLUS_CFA           ;74FA: 64 C6          ; +
        FDB     forth_C_FETCH_CFA        ;74FC: 65 AC          ; C@
        FDB     forth_OVER_CFA           ;74FE: 65 2E          ; OVER
        FDB     forth_I_CFA              ;7500: 62 08          ; I
        FDB     forth_PLUS_CFA           ;7502: 64 C6          ; +
        FDB     forth_C_STORE_CFA        ;7504: 65 CC          ; C!
        FDB     forth_LIT_CFA,$FFFF      ;7506: 61 45 FF FF    ; LIT
        FDB     forth_PAREN_PLUSLOOP_RPAREN_CFA ;750A: 61 BF          ; (+LOOP)
        FDB     $FFEA,forth_2DROP_CFA    ;750C: FF EA 67 CE    ;   [->$74F6]
        FDB     forth_SEMIS_CFA          ;7510: 64 44          ; ;S
;
; --- :: ROLL ---
forth_ROLL_NFA FCB     $84                      ;7512: 84             '.'
        FCC     "ROL"                    ;7513: 52 4F 4C       'ROL'
        FCB     $CC                      ;7516: CC             '.'
forth_ROLL_LFA FDB     forth_LTCMOVE_NFA        ;7517: 74 DF          't.'
forth_ROLL_CFA FDB     DOCOL                    ;7519: 65 F2          'e.'
forth_ROLL_PFA FDB     forth_DUP_CFA            ;751B: 65 64          ; DUP
        FDB     forth_DUP_CFA            ;751D: 65 64          ; DUP
        FDB     forth_PLUS_CFA           ;751F: 64 C6          ; +
        FDB     forth_GTR_CFA            ;7521: 64 69          ; >R
        FDB     forth_PICK_CFA           ;7523: 74 C5          ; PICK
        FDB     forth_SP_FETCH_CFA       ;7525: 64 14          ; SP@
        FDB     forth_DUP_CFA            ;7527: 65 64          ; DUP
        FDB     forth_2_PLUS_CFA         ;7529: 67 AF          ; 2+
        FDB     forth_R_GT_CFA           ;752B: 64 7D          ; R>
        FDB     forth_LTCMOVE_CFA        ;752D: 74 E8          ; <CMOVE
        FDB     forth_DROP_CFA           ;752F: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;7531: 64 44          ; ;S
;
; --- :: SEED ---
forth_SEED_NFA FCB     $84                      ;7533: 84             '.'
        FCC     "SEE"                    ;7534: 53 45 45       'SEE'
        FCB     $C4                      ;7537: C4             '.'
forth_SEED_LFA FDB     forth_ROLL_NFA           ;7538: 75 12          'u.'
forth_SEED_CFA FDB     DOCOL                    ;753A: 65 F2          'e.'
forth_SEED_PFA FDB     forth_LIT_CFA,$009A      ;753C: 61 45 00 9A    ; LIT
        FDB     forth_SEMIS_CFA          ;7540: 64 44          ; ;S
;
; --- :: (RND) ---
forth_PARENRND_RPAREN_NFA FCB     $85                      ;7542: 85             '.'
        FCC     "(RND"                   ;7543: 28 52 4E 44    '(RND'
        FCB     $A9                      ;7547: A9             '.'
forth_PARENRND_RPAREN_LFA FDB     forth_SEED_NFA           ;7548: 75 33          'u3'
forth_PARENRND_RPAREN_CFA FDB     DOCOL                    ;754A: 65 F2          'e.'
forth_PARENRND_RPAREN_PFA FDB     forth_SEED_CFA           ;754C: 75 3A          ; SEED
        FDB     forth_FETCH_CFA          ;754E: 65 9D          ; @
        FDB     forth_LIT_CFA,$0103      ;7550: 61 45 01 03    ; LIT
        FDB     forth_STAR_CFA           ;7554: 71 A0          ; *
        FDB     forth_3_CFA              ;7556: 66 7A          ; 3
        FDB     forth_PLUS_CFA           ;7558: 64 C6          ; +
        FDB     forth_LIT_CFA,$7FFF      ;755A: 61 45 7F FF    ; LIT
        FDB     forth_AND_CFA            ;755E: 63 DF          ; AND
        FDB     forth_DUP_CFA            ;7560: 65 64          ; DUP
        FDB     forth_SEED_CFA           ;7562: 75 3A          ; SEED
        FDB     forth_STORE_CFA          ;7564: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;7566: 64 44          ; ;S
;
; --- :: RND ---
forth_RND_NFA FCB     $83                      ;7568: 83             '.'
        FCC     "RN"                     ;7569: 52 4E          'RN'
        FCB     $C4                      ;756B: C4             '.'
forth_RND_LFA FDB     forth_PARENRND_RPAREN_NFA ;756C: 75 42          'uB'
forth_RND_CFA FDB     DOCOL                    ;756E: 65 F2          'e.'
forth_RND_PFA FDB     forth_PARENRND_RPAREN_CFA ;7570: 75 4A          ; (RND)
        FDB     forth_LIT_CFA,$7FFF      ;7572: 61 45 7F FF    ; LIT
        FDB     forth_STAR_SLASH_CFA     ;7576: 71 E4          ; */
        FDB     forth_SEMIS_CFA          ;7578: 64 44          ; ;S
;
; --- :: TEXT ---
forth_TEXT_NFA FCB     $84                      ;757A: 84             '.'
        FCC     "TEX"                    ;757B: 54 45 58       'TEX'
        FCB     $D4                      ;757E: D4             '.'
forth_TEXT_LFA FDB     forth_RND_NFA            ;757F: 75 68          'uh'
forth_TEXT_CFA FDB     DOCOL                    ;7581: 65 F2          'e.'
forth_TEXT_PFA FDB     forth_HERE_CFA           ;7583: 67 BE          ; HERE
        FDB     forth_C_SLASHL_CFA       ;7585: 67 99          ; C/L
        FDB     forth_1_PLUS_CFA         ;7587: 67 A2          ; 1+
        FDB     forth_BLANKS_CFA         ;7589: 6C 74          ; BLANKS
        FDB     forth_WORD_CFA           ;758B: 6C C9          ; WORD
        FDB     forth_HERE_CFA           ;758D: 67 BE          ; HERE
        FDB     forth_PAD_CFA            ;758F: 6C 9B          ; PAD
        FDB     forth_C_SLASHL_CFA       ;7591: 67 99          ; C/L
        FDB     forth_1_PLUS_CFA         ;7593: 67 A2          ; 1+
        FDB     forth_CMOVE_CFA          ;7595: 63 4B          ; CMOVE
        FDB     forth_SEMIS_CFA          ;7597: 64 44          ; ;S
;
; --- :: LINE ---
forth_LINE_NFA FCB     $84                      ;7599: 84             '.'
        FCC     "LIN"                    ;759A: 4C 49 4E       'LIN'
        FCB     $C5                      ;759D: C5             '.'
forth_LINE_LFA FDB     forth_TEXT_NFA           ;759E: 75 7A          'uz'
forth_LINE_CFA FDB     DOCOL                    ;75A0: 65 F2          'e.'
forth_LINE_PFA FDB     forth_DUP_CFA            ;75A2: 65 64          ; DUP
        FDB     forth_LIT_CFA,$FFF0      ;75A4: 61 45 FF F0    ; LIT
        FDB     forth_AND_CFA            ;75A8: 63 DF          ; AND
        FDB     forth_LIT_CFA,$0017      ;75AA: 61 45 00 17    ; LIT
        FDB     forth_QUESTIONERROR_CFA  ;75AE: 69 50          ; ?ERROR
        FDB     forth_C_SLASHL_CFA       ;75B0: 67 99          ; C/L
        FDB     forth_STAR_CFA           ;75B2: 71 A0          ; *
        FDB     forth_FIRST_CFA          ;75B4: 66 8F          ; FIRST
        FDB     forth_PLUS_CFA           ;75B6: 64 C6          ; +
        FDB     forth_SEMIS_CFA          ;75B8: 64 44          ; ;S
;
; --- :: EMPTY-BUFFERS ---
forth_EMPTY_MINUSBUFFERS_NFA FCB     $8D                      ;75BA: 8D             '.'
        FCC     "EMPTY-BUFFER"           ;75BB: 45 4D 50 54 59 2D 42 55 46 46 45 52 'EMPTY-BUFFER'
        FCB     $D3                      ;75C7: D3             '.'
forth_EMPTY_MINUSBUFFERS_LFA FDB     forth_LINE_NFA           ;75C8: 75 99          'u.'
forth_EMPTY_MINUSBUFFERS_CFA FDB     DOCOL                    ;75CA: 65 F2          'e.'
forth_EMPTY_MINUSBUFFERS_PFA FDB     forth_LIMIT_CFA          ;75CC: 66 9B          ; LIMIT
        FDB     forth_LIT_CFA,$0020      ;75CE: 61 45 00 20    ; LIT
        FDB     forth_MINUS_CFA          ;75D2: 68 19          ; -
        FDB     forth_FIRST_CFA          ;75D4: 66 8F          ; FIRST
        FDB     forth_2DUP_CFA           ;75D6: 67 DC          ; 2DUP
        FDB     forth_MINUS_CFA          ;75D8: 68 19          ; -
        FDB     forth_BLANKS_CFA         ;75DA: 6C 74          ; BLANKS
        FDB     forth_LIT_CFA,$0020      ;75DC: 61 45 00 20    ; LIT
        FDB     forth_ERASE_CFA          ;75E0: 6C 63          ; ERASE
        FDB     forth_SEMIS_CFA          ;75E2: 64 44          ; ;S
;
; --- :: ENTER ---
forth_ENTER_NFA FCB     $85                      ;75E4: 85             '.'
        FCC     "ENTE"                   ;75E5: 45 4E 54 45    'ENTE'
        FCB     $D2                      ;75E9: D2             '.'
forth_ENTER_LFA FDB     forth_EMPTY_MINUSBUFFERS_NFA ;75EA: 75 BA          'u.'
forth_ENTER_CFA FDB     DOCOL                    ;75EC: 65 F2          'e.'
forth_ENTER_PFA FDB     forth_IN_CFA             ;75EE: 67 0A          ; IN
        FDB     forth_FETCH_CFA          ;75F0: 65 9D          ; @
        FDB     forth_GTR_CFA            ;75F2: 64 69          ; >R
        FDB     forth_1_CFA              ;75F4: 66 6A          ; 1
        FDB     forth_BLK_CFA            ;75F6: 67 01          ; BLK
        FDB     forth_STORE_CFA          ;75F8: 65 BD          ; !
        FDB     forth_0_CFA              ;75FA: 66 62          ; 0
        FDB     forth_IN_CFA             ;75FC: 67 0A          ; IN
        FDB     forth_STORE_CFA          ;75FE: 65 BD          ; !
        FDB     forth_INTERPRET_CFA      ;7600: 6F 0B          ; INTERPRET
        FDB     forth_R_GT_CFA           ;7602: 64 7D          ; R>
        FDB     forth_IN_CFA             ;7604: 67 0A          ; IN
        FDB     forth_STORE_CFA          ;7606: 65 BD          ; !
        FDB     forth_0_CFA              ;7608: 66 62          ; 0
        FDB     forth_BLK_CFA            ;760A: 67 01          ; BLK
        FDB     forth_STORE_CFA          ;760C: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;760E: 64 44          ; ;S
;
; --- :: CONV ---
forth_CONV_NFA FCB     $84                      ;7610: 84             '.'
        FCC     "CON"                    ;7611: 43 4F 4E       'CON'
        FCB     $D6                      ;7614: D6             '.'
forth_CONV_LFA FDB     forth_ENTER_NFA          ;7615: 75 E4          'u.'
forth_CONV_CFA FDB     DOCOL                    ;7617: 65 F2          'e.'
forth_CONV_PFA FDB     forth_S_MINUS_GTD_CFA    ;7619: 71 10          ; S->D
        FDB     forth_LT_HASH_CFA        ;761B: 73 75          ; <#
        FDB     forth_HASH_CFA           ;761D: 73 B1          ; #
        FDB     forth_HASH_CFA           ;761F: 73 B1          ; #
        FDB     forth_HASH_CFA           ;7621: 73 B1          ; #
        FDB     forth_HASH_GT_CFA        ;7623: 73 84          ; #>
        FDB     forth_SEMIS_CFA          ;7625: 64 44          ; ;S
;
; --- CODE: XFILE ---
forth_XFILE_NFA FCB     $85                      ;7627: 85             '.'
        FCC     "XFIL"                   ;7628: 58 46 49 4C    'XFIL'
        FCB     $C5                      ;762C: C5             '.'
forth_XFILE_LFA FDB     forth_CONV_NFA           ;762D: 76 10          'v.'
forth_XFILE_CFA FDB     forth_XFILE_PFA          ;762F: 76 31          'v1'
forth_XFILE_PFA JMP     Z604D                    ;7631: 7E 60 4D       '~`M'
;
; --- :: FILE ---
forth_FILE_NFA FCB     $84                      ;7634: 84             '.'
        FCC     "FIL"                    ;7635: 46 49 4C       'FIL'
        FCB     $C5                      ;7638: C5             '.'
forth_FILE_LFA FDB     forth_XFILE_NFA          ;7639: 76 27          'v''
forth_FILE_CFA FDB     DOCOL                    ;763B: 65 F2          'e.'
forth_FILE_PFA FDB     forth_CLS_CFA            ;763D: 74 B4          ; CLS
        FDB     forth_BASE_CFA           ;763F: 67 5E          ; BASE
        FDB     forth_FETCH_CFA          ;7641: 65 9D          ; @
        FDB     forth_DECIMAL_CFA        ;7643: 6A 3C          ; DECIMAL
        FDB     forth_SCR_CFA            ;7645: 67 1E          ; SCR
        FDB     forth_FETCH_CFA          ;7647: 65 9D          ; @
        FDB     forth_DUP_CFA            ;7649: 65 64          ; DUP
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;764B: 6B 39          ; (.")
        FDB     $013E,forth_DOT_CFA      ;764D: 01 3E 74 34    ;   [">"]
        FDB     forth_CONV_CFA           ;7651: 76 17          ; CONV
        FDB     forth_LIT_CFA,$02AC      ;7653: 61 45 02 AC    ; LIT
        FDB     forth_SWAP_CFA           ;7657: 65 4B          ; SWAP
        FDB     forth_CMOVE_CFA          ;7659: 63 4B          ; CMOVE
        FDB     forth_LIT_CFA,$6006      ;765B: 61 45 60 06    ; LIT
        FDB     forth_LIT_CFA,$02A7      ;765F: 61 45 02 A7    ; LIT
        FDB     forth_LIT_CFA,$0005      ;7663: 61 45 00 05    ; LIT
        FDB     forth_CMOVE_CFA          ;7667: 63 4B          ; CMOVE
        FDB     forth_LIT_CFA,$4249      ;7669: 61 45 42 49    ; LIT
        FDB     forth_LIT_CFA,$02AF      ;766D: 61 45 02 AF    ; LIT
        FDB     forth_STORE_CFA          ;7671: 65 BD          ; !
        FDB     forth_LIT_CFA,$004E      ;7673: 61 45 00 4E    ; LIT
        FDB     forth_LIT_CFA,$02B1      ;7677: 61 45 02 B1    ; LIT
        FDB     forth_C_STORE_CFA        ;767B: 65 CC          ; C!
        FDB     forth_LIT_CFA,$0710      ;767D: 61 45 07 10    ; LIT
        FDB     forth_LIT_CFA,$02B7      ;7681: 61 45 02 B7    ; LIT
        FDB     forth_STORE_CFA          ;7685: 65 BD          ; !
        FDB     forth_LIT_CFA,$0B0F      ;7687: 61 45 0B 0F    ; LIT
        FDB     forth_LIT_CFA,$02B9      ;768B: 61 45 02 B9    ; LIT
        FDB     forth_STORE_CFA          ;768F: 65 BD          ; !
        FDB     forth_0_CFA              ;7691: 66 62          ; 0
        FDB     forth_LIT_CFA,M02BB      ;7693: 61 45 02 BB    ; LIT
        FDB     forth_STORE_CFA          ;7697: 65 BD          ; !
        FDB     forth_LIT_CFA,NEXT       ;7699: 61 45 61 30    ; LIT
        FDB     forth_LIT_CFA,$02BD      ;769D: 61 45 02 BD    ; LIT
        FDB     forth_STORE_CFA          ;76A1: 65 BD          ; !
        FDB     forth_LIT_CFA,$0378      ;76A3: 61 45 03 78    ; LIT
        FDB     forth_LIT_CFA,$02A5      ;76A7: 61 45 02 A5    ; LIT
        FDB     forth_STORE_CFA          ;76AB: 65 BD          ; !
        FDB     forth_LIT_CFA,$0052      ;76AD: 61 45 00 52    ; LIT
        FDB     forth_LIT_CFA,$0062      ;76B1: 61 45 00 62    ; LIT
        FDB     forth_C_STORE_CFA        ;76B5: 65 CC          ; C!
        FDB     forth_BASE_CFA           ;76B7: 67 5E          ; BASE
        FDB     forth_STORE_CFA          ;76B9: 65 BD          ; !
        FDB     forth_DUP_CFA            ;76BB: 65 64          ; DUP
        FDB     forth_LIT_CFA,M0061      ;76BD: 61 45 00 61    ; LIT
        FDB     forth_C_STORE_CFA        ;76C1: 65 CC          ; C!
        FDB     forth_0BRANCH_CFA,$0012  ;76C3: 61 88 00 12    ; 0BRANCH
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;76C7: 6B 39          ; (.")
        FDB     $0953,$6561,$7263        ;76C9: 09 53 65 61 72 63 ;   ["Searching"]
        FDB     forth_SPACE_NFA,$6E67    ;76CF: 68 69 6E 67    'hing'
        FDB     forth_BRANCH_CFA,$000B   ;76D3: 61 7C 00 0B    ; BRANCH
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;76D7: 6B 39          ; (.")
        FDB     $0653,$6176,$696E        ;76D9: 06 53 61 76 69 6E ;   ["Saving"]
        FDB     forth_CSP_NFA,$2F64      ;76DF: 67 76 2F 64    'gv/d'
        FDB     $4400                    ;76E3: 44 00          'D.'
        FDB     forth_PSP_hi             ;76E5: 00 84          '..'
        FCC     "CAS"                    ;76E7: 43 41 53       'CAS'
        FCB     $D3                      ;76EA: D3             '.'
forth_CASS_LFA FDB     forth_FILE_NFA           ;76EB: 76 34          'v4'
forth_CASS_CFA FDB     DOCOL                    ;76ED: 65 F2          'e.'
forth_CASS_PFA FDB     forth_LIT_CFA,$0043      ;76EF: 61 45 00 43    ; LIT
        FDB     forth_LIT_CFA,M0060      ;76F3: 61 45 00 60    ; LIT
        FDB     forth_C_STORE_CFA        ;76F7: 65 CC          ; C!
        FDB     forth_SEMIS_CFA          ;76F9: 64 44          ; ;S
;
; --- :: SAVE ---
forth_SAVE_NFA FCB     $84                      ;76FB: 84             '.'
        FCC     "SAV"                    ;76FC: 53 41 56       'SAV'
        FCB     $C5                      ;76FF: C5             '.'
forth_SAVE_LFA FDB     forth_CASS_NFA           ;7700: 76 E6          'v.'
forth_SAVE_CFA FDB     DOCOL                    ;7702: 65 F2          'e.'
forth_SAVE_PFA FDB     forth_SCR_CFA            ;7704: 67 1E          ; SCR
        FDB     forth_FETCH_CFA          ;7706: 65 9D          ; @
        FDB     forth_DUP_CFA            ;7708: 65 64          ; DUP
        FDB     forth_LIT_CFA,$03E7      ;770A: 61 45 03 E7    ; LIT
        FDB     forth_GT_CFA             ;770E: 68 4F          ; >
        FDB     forth_SWAP_CFA           ;7710: 65 4B          ; SWAP
        FDB     forth_0_CFA              ;7712: 66 62          ; 0
        FDB     forth_LT_CFA             ;7714: 68 31          ; <
        FDB     forth_OR_CFA             ;7716: 63 F0          ; OR
        FDB     forth_LIT_CFA,M0006      ;7718: 61 45 00 06    ; LIT
        FDB     forth_QUESTIONERROR_CFA  ;771C: 69 50          ; ?ERROR
        FDB     forth_CR_CFA             ;771E: 63 3B          ; CR
        FDB     forth_0_CFA              ;7720: 66 62          ; 0
        FDB     forth_FILE_CFA           ;7722: 76 3B          ; FILE
        FDB     forth_CLS_CFA            ;7724: 74 B4          ; CLS
        FDB     forth_SCR_CFA            ;7726: 67 1E          ; SCR
        FDB     forth_FETCH_CFA          ;7728: 65 9D          ; @
        FDB     forth_DOT_CFA            ;772A: 74 34          ; .
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;772C: 6B 39          ; (.")
        FDB     $0553,$6176              ;772E: 05 53 61 76    ;   ["Saved"]
        FDB     forth_DUP_CFA            ;7732: 65 64          'ed'
        FDB     forth_SEMIS_CFA          ;7734: 64 44          ; ;S
;
; --- :: LIST ---
forth_LIST_NFA FCB     $84                      ;7736: 84             '.'
        FCC     "LIS"                    ;7737: 4C 49 53       'LIS'
        FCB     $D4                      ;773A: D4             '.'
forth_LIST_LFA FDB     forth_SAVE_NFA           ;773B: 76 FB          'v.'
forth_LIST_CFA FDB     DOCOL                    ;773D: 65 F2          'e.'
forth_LIST_PFA FDB     forth_CR_CFA             ;773F: 63 3B          ; CR
        FDB     forth_DUP_CFA            ;7741: 65 64          ; DUP
        FDB     forth_SCR_CFA            ;7743: 67 1E          ; SCR
        FDB     forth_FETCH_CFA          ;7745: 65 9D          ; @
        FDB     forth_MINUS_CFA          ;7747: 68 19          ; -
        FDB     forth_0BRANCH_CFA,$000C  ;7749: 61 88 00 0C    ; 0BRANCH
        FDB     forth_DUP_CFA            ;774D: 65 64          ; DUP
        FDB     forth_SCR_CFA            ;774F: 67 1E          ; SCR
        FDB     forth_STORE_CFA          ;7751: 65 BD          ; !
        FDB     forth_1_CFA              ;7753: 66 6A          ; 1
        FDB     forth_FILE_CFA           ;7755: 76 3B          ; FILE
        FDB     forth_CLS_CFA            ;7757: 74 B4          ; CLS
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;7759: 6B 39          ; (.")
        FDB     $0653,$6372,$2023,$2074  ;775B: 06 53 63 72 20 23 20 74 ;   ["Scr # "]
        FDB     $3461,$4500,$1066,$6261  ;7763: 34 61 45 00 10 66 62 61 '4aE..fba'
        FDB     $EF63,$3B62,$0866,$7274  ;776B: EF 63 3B 62 08 66 72 74 '.c;b.frt'
        FDB     $2468,$7162,$0872,$1461  ;7773: 24 68 71 62 08 72 14 61 '$hqb.r.a'
        FDB     $AEFF,$F063,$3B64        ;777B: AE FF F0 63 3B 64 '...c;d'
        FDB     $4484                    ;7781: 44 84          'D.'
        FCC     "LOA"                    ;7783: 4C 4F 41       'LOA'
        FCB     $C4                      ;7786: C4             '.'
forth_LOAD_LFA FDB     forth_LIST_NFA           ;7787: 77 36          'w6'
forth_LOAD_CFA FDB     DOCOL                    ;7789: 65 F2          'e.'
forth_LOAD_PFA FDB     forth_SCR_CFA            ;778B: 67 1E          ; SCR
        FDB     forth_STORE_CFA          ;778D: 65 BD          ; !
        FDB     forth_CR_CFA             ;778F: 63 3B          ; CR
        FDB     forth_FIRST_CFA          ;7791: 66 8F          ; FIRST
        FDB     forth_LIMIT_CFA          ;7793: 66 9B          ; LIMIT
        FDB     forth_OVER_CFA           ;7795: 65 2E          ; OVER
        FDB     forth_MINUS_CFA          ;7797: 68 19          ; -
        FDB     forth_ERASE_CFA          ;7799: 6C 63          ; ERASE
        FDB     forth_1_CFA              ;779B: 66 6A          ; 1
        FDB     forth_FILE_CFA           ;779D: 76 3B          ; FILE
        FDB     forth_ENTER_CFA          ;779F: 75 EC          ; ENTER
        FDB     forth_SEMIS_CFA          ;77A1: 64 44          ; ;S
;
; --- :: --> ---
forth_MINUS_MINUS_GT_NFA FCB     $83                      ;77A3: 83             '.'
        FCC     "--"                     ;77A4: 2D 2D          '--'
        FCB     $BE                      ;77A6: BE             '.'
forth_MINUS_MINUS_GT_LFA FDB     forth_LOAD_NFA           ;77A7: 77 82          'w.'
forth_MINUS_MINUS_GT_CFA FDB     DOCOL                    ;77A9: 65 F2          'e.'
forth_MINUS_MINUS_GT_PFA FDB     forth_QUESTIONLOADING_CFA ;77AB: 69 C5          ; ?LOADING
        FDB     forth_0_CFA              ;77AD: 66 62          ; 0
        FDB     forth_IN_CFA             ;77AF: 67 0A          ; IN
        FDB     forth_STORE_CFA          ;77B1: 65 BD          ; !
        FDB     forth_1_CFA              ;77B3: 66 6A          ; 1
        FDB     forth_SCR_CFA            ;77B5: 67 1E          ; SCR
        FDB     forth_PLUS_STORE_CFA     ;77B7: 65 72          ; +!
        FDB     forth_1_CFA              ;77B9: 66 6A          ; 1
        FDB     forth_FILE_CFA           ;77BB: 76 3B          ; FILE
        FDB     forth_SEMIS_CFA          ;77BD: 64 44          ; ;S
;
; --- :: ANOTHER ---
forth_ANOTHER_NFA FCB     $87                      ;77BF: 87             '.'
        FCC     "ANOTHE"                 ;77C0: 41 4E 4F 54 48 45 'ANOTHE'
        FCB     $D2                      ;77C6: D2             '.'
forth_ANOTHER_LFA FDB     forth_MINUS_MINUS_GT_NFA ;77C7: 77 A3          'w.'
forth_ANOTHER_CFA FDB     DOCOL                    ;77C9: 65 F2          'e.'
forth_ANOTHER_PFA FDB     forth_EMPTY_MINUSBUFFERS_CFA ;77CB: 75 CA          ; EMPTY-BUFFERS
        FDB     forth_1_CFA              ;77CD: 66 6A          ; 1
        FDB     forth_SCR_CFA            ;77CF: 67 1E          ; SCR
        FDB     forth_PLUS_STORE_CFA     ;77D1: 65 72          ; +!
        FDB     forth_SCR_CFA            ;77D3: 67 1E          ; SCR
        FDB     forth_FETCH_CFA          ;77D5: 65 9D          ; @
        FDB     forth_LIST_CFA           ;77D7: 77 3D          ; LIST
        FDB     forth_SEMIS_CFA          ;77D9: 64 44          ; ;S
;
; --- :: PROGRAM ---
forth_PROGRAM_NFA FCB     $87                      ;77DB: 87             '.'
        FCC     "PROGRA"                 ;77DC: 50 52 4F 47 52 41 'PROGRA'
        FCB     $CD                      ;77E2: CD             '.'
forth_PROGRAM_LFA FDB     forth_ANOTHER_NFA        ;77E3: 77 BF          'w.'
forth_PROGRAM_CFA FDB     DOCOL                    ;77E5: 65 F2          'e.'
forth_PROGRAM_PFA FDB     forth_CR_CFA             ;77E7: 63 3B          ; CR
        FDB     forth_DECIMAL_CFA        ;77E9: 6A 3C          ; DECIMAL
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;77EB: 6B 39          ; (.")
        FDB     $1146,$6972,$7374,$2053  ;77ED: 11 46 69 72 73 74 20 53 ;   ["First Scr. no. ? "]
        FDB     $6372,$2E20,$6E6F,$2E20  ;77F5: 63 72 2E 20 6E 6F 2E 20 'cr. no. '
        FDB     $3F20,forth_QUERY_CFA    ;77FD: 3F 20 6C 2A    '? l*'
        FDB     forth_INTERPRET_CFA      ;7801: 6F 0B          ; INTERPRET
        FDB     forth_SPACE_CFA          ;7803: 68 71          ; SPACE
        FDB     forth_1_CFA              ;7805: 66 6A          ; 1
        FDB     forth_MINUS_CFA          ;7807: 68 19          ; -
        FDB     forth_SCR_CFA            ;7809: 67 1E          ; SCR
        FDB     forth_STORE_CFA          ;780B: 65 BD          ; !
        FDB     forth_ANOTHER_CFA        ;780D: 77 C9          ; ANOTHER
        FDB     forth_SEMIS_CFA          ;780F: 64 44          ; ;S
;
; --- :: MORE ---
forth_MORE_NFA FCB     $84                      ;7811: 84             '.'
        FCC     "MOR"                    ;7812: 4D 4F 52       'MOR'
        FCB     $C5                      ;7815: C5             '.'
forth_MORE_LFA FDB     forth_PROGRAM_NFA        ;7816: 77 DB          'w.'
forth_MORE_CFA FDB     DOCOL                    ;7818: 65 F2          'e.'
forth_MORE_PFA FDB     forth_SAVE_CFA           ;781A: 77 02          ; SAVE
        FDB     forth_ANOTHER_CFA        ;781C: 77 C9          ; ANOTHER
        FDB     forth_SEMIS_CFA          ;781E: 64 44          ; ;S
;
; --- :: WHERE ---
forth_WHERE_NFA FCB     $85                      ;7820: 85             '.'
        FCC     "WHER"                   ;7821: 57 48 45 52    'WHER'
        FCB     $C5                      ;7825: C5             '.'
forth_WHERE_LFA FDB     forth_MORE_NFA           ;7826: 78 11          'x.'
forth_WHERE_CFA FDB     DOCOL                    ;7828: 65 F2          'e.'
forth_WHERE_PFA FDB     forth_SWAP_CFA           ;782A: 65 4B          ; SWAP
        FDB     forth_C_SLASHL_CFA       ;782C: 67 99          ; C/L
        FDB     forth_SLASH_CFA          ;782E: 71 C1          ; /
        FDB     forth_DUP_CFA            ;7830: 65 64          ; DUP
        FDB     forth_DECIMAL_CFA        ;7832: 6A 3C          ; DECIMAL
        FDB     forth_SCR_CFA            ;7834: 67 1E          ; SCR
        FDB     forth_FETCH_CFA          ;7836: 65 9D          ; @
        FDB     forth_CR_CFA             ;7838: 63 3B          ; CR
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;783A: 6B 39          ; (.")
        FDB     $0353,$6372              ;783C: 03 53 63 72    ;   ["Scr"]
        FDB     forth_DOT_CFA            ;7840: 74 34          ; .
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;7842: 6B 39          ; (.")
        FDB     $044C,$696E              ;7844: 04 4C 69 6E    ;   ["Line"]
        FDB     forth_PLUS_STORE_PFA     ;7848: 65 74          'et'
        FDB     $3463,$3B65,$6472,$1463  ;784A: 34 63 3B 65 64 72 14 63 '4c;edr.c'
        FDB     $3B6F,$F664              ;7852: 3B 6F F6 64    ';o.d'
        FDB     $4487                    ;7856: 44 87          'D.'
        FCC     "#LOCAT"                 ;7858: 23 4C 4F 43 41 54 '#LOCAT'
        FCB     $C5                      ;785E: C5             '.'
forth_HASHLOCATE_LFA FDB     forth_WHERE_NFA          ;785F: 78 20          'x '
forth_HASHLOCATE_CFA FDB     DOCOL                    ;7861: 65 F2          'e.'
forth_HASHLOCATE_PFA FDB     forth_R_HASH_CFA         ;7863: 67 85          ; R#
        FDB     forth_FETCH_CFA          ;7865: 65 9D          ; @
        FDB     forth_C_SLASHL_CFA       ;7867: 67 99          ; C/L
        FDB     forth_SLASHMOD_CFA       ;7869: 71 B1          ; /MOD
        FDB     forth_SEMIS_CFA          ;786B: 64 44          ; ;S
;
; --- :: #LEAD ---
forth_HASHLEAD_NFA FCB     $85                      ;786D: 85             '.'
        FCC     "#LEA"                   ;786E: 23 4C 45 41    '#LEA'
        FCB     $C4                      ;7872: C4             '.'
forth_HASHLEAD_LFA FDB     forth_HASHLOCATE_NFA     ;7873: 78 57          'xW'
forth_HASHLEAD_CFA FDB     DOCOL                    ;7875: 65 F2          'e.'
forth_HASHLEAD_PFA FDB     forth_HASHLOCATE_CFA     ;7877: 78 61          ; #LOCATE
        FDB     forth_LINE_CFA           ;7879: 75 A0          ; LINE
        FDB     forth_SWAP_CFA           ;787B: 65 4B          ; SWAP
        FDB     forth_SEMIS_CFA          ;787D: 64 44          ; ;S
;
; --- :: #LAG ---
forth_HASHLAG_NFA FCB     $84                      ;787F: 84             '.'
        FCC     "#LA"                    ;7880: 23 4C 41       '#LA'
        FCB     $C7                      ;7883: C7             '.'
forth_HASHLAG_LFA FDB     forth_HASHLEAD_NFA       ;7884: 78 6D          'xm'
forth_HASHLAG_CFA FDB     DOCOL                    ;7886: 65 F2          'e.'
forth_HASHLAG_PFA FDB     forth_HASHLEAD_CFA       ;7888: 78 75          ; #LEAD
        FDB     forth_DUP_CFA            ;788A: 65 64          ; DUP
        FDB     forth_GTR_CFA            ;788C: 64 69          ; >R
        FDB     forth_PLUS_CFA           ;788E: 64 C6          ; +
        FDB     forth_C_SLASHL_CFA       ;7890: 67 99          ; C/L
        FDB     forth_R_GT_CFA           ;7892: 64 7D          ; R>
        FDB     forth_MINUS_CFA          ;7894: 68 19          ; -
        FDB     forth_SEMIS_CFA          ;7896: 64 44          ; ;S
;
; --- :: -MOVE ---
forth_MINUSMOVE_NFA FCB     $85                      ;7898: 85             '.'
        FCC     "-MOV"                   ;7899: 2D 4D 4F 56    '-MOV'
        FCB     $C5                      ;789D: C5             '.'
forth_MINUSMOVE_LFA FDB     forth_HASHLAG_NFA        ;789E: 78 7F          'x.'
forth_MINUSMOVE_CFA FDB     DOCOL                    ;78A0: 65 F2          'e.'
forth_MINUSMOVE_PFA FDB     forth_LINE_CFA           ;78A2: 75 A0          ; LINE
        FDB     forth_C_SLASHL_CFA       ;78A4: 67 99          ; C/L
        FDB     forth_CMOVE_CFA          ;78A6: 63 4B          ; CMOVE
        FDB     forth_SEMIS_CFA          ;78A8: 64 44          ; ;S
;
; --- :: H ---
forth_H_NFA FCB     $81,$C8                  ;78AA: 81 C8          '..'
forth_H_LFA FDB     forth_MINUSMOVE_NFA      ;78AC: 78 98          'x.'
forth_H_CFA FDB     DOCOL                    ;78AE: 65 F2          'e.'
forth_H_PFA FDB     forth_LINE_CFA           ;78B0: 75 A0          ; LINE
        FDB     forth_PAD_CFA            ;78B2: 6C 9B          ; PAD
        FDB     forth_1_PLUS_CFA         ;78B4: 67 A2          ; 1+
        FDB     forth_C_SLASHL_CFA       ;78B6: 67 99          ; C/L
        FDB     forth_DUP_CFA            ;78B8: 65 64          ; DUP
        FDB     forth_PAD_CFA            ;78BA: 6C 9B          ; PAD
        FDB     forth_C_STORE_CFA        ;78BC: 65 CC          ; C!
        FDB     forth_CMOVE_CFA          ;78BE: 63 4B          ; CMOVE
        FDB     forth_SEMIS_CFA          ;78C0: 64 44          ; ;S
;
; --- :: E ---
forth_E_NFA FCB     $81,$C5                  ;78C2: 81 C5          '..'
forth_E_LFA FDB     forth_H_NFA              ;78C4: 78 AA          'x.'
forth_E_CFA FDB     DOCOL                    ;78C6: 65 F2          'e.'
forth_E_PFA FDB     forth_LINE_CFA           ;78C8: 75 A0          ; LINE
        FDB     forth_C_SLASHL_CFA       ;78CA: 67 99          ; C/L
        FDB     forth_BLANKS_CFA         ;78CC: 6C 74          ; BLANKS
        FDB     forth_SEMIS_CFA          ;78CE: 64 44          ; ;S
;
; --- :: S ---
forth_S_NFA FCB     $81,$D3                  ;78D0: 81 D3          '..'
forth_S_LFA FDB     forth_E_NFA              ;78D2: 78 C2          'x.'
forth_S_CFA FDB     DOCOL                    ;78D4: 65 F2          'e.'
forth_S_PFA FDB     forth_DUP_CFA            ;78D6: 65 64          ; DUP
        FDB     forth_1_CFA              ;78D8: 66 6A          ; 1
        FDB     forth_MINUS_CFA          ;78DA: 68 19          ; -
        FDB     forth_LIT_CFA,$000E      ;78DC: 61 45 00 0E    ; LIT
        FDB     forth_PARENDO_RPAREN_CFA ;78E0: 61 EF          ; (DO)
        FDB     forth_I_CFA              ;78E2: 62 08          ; I
        FDB     forth_LINE_CFA           ;78E4: 75 A0          ; LINE
        FDB     forth_I_CFA              ;78E6: 62 08          ; I
        FDB     forth_1_PLUS_CFA         ;78E8: 67 A2          ; 1+
        FDB     forth_MINUSMOVE_CFA      ;78EA: 78 A0          ; -MOVE
        FDB     forth_LIT_CFA,$FFFF      ;78EC: 61 45 FF FF    ; LIT
        FDB     forth_PAREN_PLUSLOOP_RPAREN_CFA ;78F0: 61 BF          ; (+LOOP)
        FDB     $FFF0,forth_E_CFA        ;78F2: FF F0 78 C6    ;   [->$78E2]
        FDB     forth_SEMIS_CFA          ;78F6: 64 44          ; ;S
;
; --- :: D ---
forth_D_NFA FCB     $81,$C4                  ;78F8: 81 C4          '..'
forth_D_LFA FDB     forth_S_NFA              ;78FA: 78 D0          'x.'
forth_D_CFA FDB     DOCOL                    ;78FC: 65 F2          'e.'
forth_D_PFA FDB     $7EF6,forth_LIT_CFA      ;78FE: 7E F6 61 45    ; $7EF6
        FDB     $000F,forth_DUP_CFA      ;7902: 00 0F 65 64    ;   [15 ($000F)]
        FDB     forth_ROT_CFA            ;7906: 68 5D          ; ROT
        FDB     forth_PARENDO_RPAREN_CFA ;7908: 61 EF          ; (DO)
        FDB     forth_I_CFA              ;790A: 62 08          ; I
        FDB     forth_1_PLUS_CFA         ;790C: 67 A2          ; 1+
        FDB     forth_LINE_CFA           ;790E: 75 A0          ; LINE
        FDB     forth_I_CFA              ;7910: 62 08          ; I
        FDB     forth_MINUSMOVE_CFA      ;7912: 78 A0          ; -MOVE
        FDB     forth_PARENLOOP_RPAREN_CFA ;7914: 61 AE          ; (LOOP)
        FDB     $FFF4,forth_E_CFA        ;7916: FF F4 78 C6    ;   [->$790A]
        FDB     forth_SEMIS_CFA          ;791A: 64 44          ; ;S
;
; --- :: HALT ---
forth_HALT_NFA FCB     $84                      ;791C: 84             '.'
        FCC     "HAL"                    ;791D: 48 41 4C       'HAL'
        FCB     $D4                      ;7920: D4             '.'
forth_HALT_LFA FDB     forth_D_NFA              ;7921: 78 F8          'x.'
forth_HALT_CFA FDB     DOCOL                    ;7923: 65 F2          'e.'
forth_HALT_PFA FDB     forth_LIT_CFA,$008F      ;7925: 61 45 00 8F    ; LIT
        FDB     forth_C_FETCH_CFA        ;7929: 65 AC          ; C@
        FDB     forth_0BRANCH_CFA,$0014  ;792B: 61 88 00 14    ; 0BRANCH
        FDB     forth_PAREN_DOT_QUOTE_RPAREN_CFA ;792F: 6B 39          ; (.")
        FDB     $0B50,$7265              ;7931: 0B 50 72 65    ;   ["Press space"]
        FDB     forth_LT_HASH_LFA,$2073  ;7935: 73 73 20 73    'ss s'
        FDB     $7061,$6365              ;7939: 70 61 63 65    'pace'
        FDB     forth_KEY_CFA            ;793D: 63 1A          ; KEY
        FDB     forth_DROP_CFA           ;793F: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;7941: 64 44          ; ;S
;
; --- :: M ---
forth_M_NFA FCB     $81,$CD                  ;7943: 81 CD          '..'
forth_M_LFA FDB     forth_HALT_NFA           ;7945: 79 1C          'y.'
forth_M_CFA FDB     DOCOL                    ;7947: 65 F2          'e.'
forth_M_PFA FDB     forth_R_HASH_CFA         ;7949: 67 85          ; R#
        FDB     forth_PLUS_STORE_CFA     ;794B: 65 72          ; +!
        FDB     forth_CR_CFA             ;794D: 63 3B          ; CR
        FDB     forth_SPACE_CFA          ;794F: 68 71          ; SPACE
        FDB     forth_HASHLEAD_CFA       ;7951: 78 75          ; #LEAD
        FDB     forth_TYPE_CFA           ;7953: 6A DA          ; TYPE
        FDB     forth_LIT_CFA,$0023      ;7955: 61 45 00 23    ; LIT
        FDB     forth_EMIT_CFA           ;7959: 63 02          ; EMIT
        FDB     forth_HASHLAG_CFA        ;795B: 78 86          ; #LAG
        FDB     forth_TYPE_CFA           ;795D: 6A DA          ; TYPE
        FDB     forth_HASHLOCATE_CFA     ;795F: 78 61          ; #LOCATE
        FDB     forth_DOT_CFA            ;7961: 74 34          ; .
        FDB     forth_DROP_CFA           ;7963: 65 3D          ; DROP
        FDB     forth_HALT_CFA           ;7965: 79 23          ; HALT
        FDB     forth_SEMIS_CFA          ;7967: 64 44          ; ;S
;
; --- :: TOP ---
forth_TOP_NFA FCB     $83                      ;7969: 83             '.'
        FCC     "TO"                     ;796A: 54 4F          'TO'
        FCB     $D0                      ;796C: D0             '.'
forth_TOP_LFA FDB     forth_M_NFA              ;796D: 79 43          'yC'
forth_TOP_CFA FDB     DOCOL                    ;796F: 65 F2          'e.'
forth_TOP_PFA FDB     forth_0_CFA              ;7971: 66 62          ; 0
        FDB     forth_R_HASH_CFA         ;7973: 67 85          ; R#
        FDB     forth_STORE_CFA          ;7975: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;7977: 64 44          ; ;S
;
; --- :: T ---
forth_T_NFA FCB     $81,$D4                  ;7979: 81 D4          '..'
forth_T_LFA FDB     forth_TOP_NFA            ;797B: 79 69          'yi'
forth_T_CFA FDB     DOCOL                    ;797D: 65 F2          'e.'
forth_T_PFA FDB     forth_DUP_CFA            ;797F: 65 64          ; DUP
        FDB     forth_C_SLASHL_CFA       ;7981: 67 99          ; C/L
        FDB     forth_STAR_CFA           ;7983: 71 A0          ; *
        FDB     forth_R_HASH_CFA         ;7985: 67 85          ; R#
        FDB     forth_STORE_CFA          ;7987: 65 BD          ; !
        FDB     forth_H_CFA,forth_0_CFA  ;7989: 78 AE 66 62    ; H
        FDB     forth_M_CFA              ;798D: 79 47          ; M
        FDB     forth_SEMIS_CFA          ;798F: 64 44          ; ;S
;
; --- :: L ---
forth_L_NFA FCB     $81,$CC                  ;7991: 81 CC          '..'
forth_L_LFA FDB     forth_T_NFA              ;7993: 79 79          'yy'
forth_L_CFA FDB     DOCOL                    ;7995: 65 F2          'e.'
forth_L_PFA FDB     forth_SCR_CFA            ;7997: 67 1E          ; SCR
        FDB     forth_FETCH_CFA          ;7999: 65 9D          ; @
        FDB     forth_LIST_CFA           ;799B: 77 3D          ; LIST
        FDB     forth_0_CFA,forth_M_CFA  ;799D: 66 62 79 47    ; 0
        FDB     forth_SEMIS_CFA          ;79A1: 64 44          ; ;S
;
; --- :: RPAD ---
forth_RPAD_NFA FCB     $84                      ;79A3: 84             '.'
        FCC     "RPA"                    ;79A4: 52 50 41       'RPA'
        FCB     $C4                      ;79A7: C4             '.'
forth_RPAD_LFA FDB     forth_L_NFA              ;79A8: 79 91          'y.'
forth_RPAD_CFA FDB     DOCOL                    ;79AA: 65 F2          'e.'
forth_RPAD_PFA FDB     forth_PAD_CFA            ;79AC: 6C 9B          ; PAD
        FDB     forth_1_PLUS_CFA         ;79AE: 67 A2          ; 1+
        FDB     forth_SWAP_CFA           ;79B0: 65 4B          ; SWAP
        FDB     forth_MINUSMOVE_CFA      ;79B2: 78 A0          ; -MOVE
        FDB     forth_SEMIS_CFA          ;79B4: 64 44          ; ;S
;
; --- :: P ---
forth_P_NFA FCB     $81,$D0                  ;79B6: 81 D0          '..'
forth_P_LFA FDB     forth_RPAD_NFA           ;79B8: 79 A3          'y.'
forth_P_CFA FDB     DOCOL                    ;79BA: 65 F2          'e.'
forth_P_PFA FDB     forth_1_CFA              ;79BC: 66 6A          ; 1
        FDB     forth_TEXT_CFA           ;79BE: 75 81          ; TEXT
        FDB     forth_RPAD_CFA           ;79C0: 79 AA          ; RPAD
        FDB     forth_SEMIS_CFA          ;79C2: 64 44          ; ;S
;
; --- :: IPAD ---
forth_IPAD_NFA FCB     $84                      ;79C4: 84             '.'
        FCC     "IPA"                    ;79C5: 49 50 41       'IPA'
        FCB     $C4                      ;79C8: C4             '.'
forth_IPAD_LFA FDB     forth_P_NFA              ;79C9: 79 B6          'y.'
forth_IPAD_CFA FDB     DOCOL                    ;79CB: 65 F2          'e.'
forth_IPAD_PFA FDB     forth_DUP_CFA            ;79CD: 65 64          ; DUP
        FDB     forth_S_CFA              ;79CF: 78 D4          ; S
        FDB     forth_RPAD_CFA           ;79D1: 79 AA          ; RPAD
        FDB     forth_SEMIS_CFA          ;79D3: 64 44          ; ;S
;
; --- :: D/L ---
forth_D_SLASHL_NFA FCB     $83                      ;79D5: 83             '.'
        FCC     "D/"                     ;79D6: 44 2F          'D/'
        FCB     $CC                      ;79D8: CC             '.'
forth_D_SLASHL_LFA FDB     forth_IPAD_NFA           ;79D9: 79 C4          'y.'
forth_D_SLASHL_CFA FDB     DOCOL                    ;79DB: 65 F2          'e.'
forth_D_SLASHL_PFA FDB     forth_LIT_CFA,$0010      ;79DD: 61 45 00 10    ; LIT
        FDB     forth_SWAP_CFA           ;79E1: 65 4B          ; SWAP
        FDB     forth_PARENDO_RPAREN_CFA ;79E3: 61 EF          ; (DO)
        FDB     forth_CLS_CFA            ;79E5: 74 B4          ; CLS
        FDB     forth_I_CFA              ;79E7: 62 08          ; I
        FDB     forth_DOT_CFA            ;79E9: 74 34          ; .
        FDB     forth_I_CFA              ;79EB: 62 08          ; I
        FDB     forth_LINE_CFA           ;79ED: 75 A0          ; LINE
        FDB     forth_C_SLASHL_CFA       ;79EF: 67 99          ; C/L
        FDB     forth_TYPE_CFA           ;79F1: 6A DA          ; TYPE
        FDB     forth_KEY_CFA            ;79F3: 63 1A          ; KEY
        FDB     forth_LIT_CFA,$004E      ;79F5: 61 45 00 4E    ; LIT
        FDB     forth_EQ_CFA             ;79F9: 68 25          ; =
        FDB     forth_0_EQ_CFA           ;79FB: 64 9C          ; 0=
        FDB     forth_0BRANCH_CFA,M0004  ;79FD: 61 88 00 04    ; 0BRANCH
        FDB     forth_LEAVE_CFA          ;7A01: 64 59          ; LEAVE
        FDB     forth_PARENLOOP_RPAREN_CFA ;7A03: 61 AE          ; (LOOP)
        FDB     $FFE0,forth_SEMIS_CFA    ;7A05: FF E0 64 44    ;   [->$79E5]
;
; --- CODE@7EFE: MATCH ---
forth_MATCH_NFA FCB     $85                      ;7A09: 85             '.'
        FCC     "MATC"                   ;7A0A: 4D 41 54 43    'MATC'
        FCB     $C8                      ;7A0E: C8             '.'
forth_MATCH_LFA FDB     forth_D_SLASHL_NFA       ;7A0F: 79 D5          'y.'
forth_MATCH_CFA FDB     $7EFE                    ;7A11: 7E FE          '~.'
;
; --- :: 1LINE ---
forth_1LINE_NFA FCB     $85                      ;7A13: 85             '.'
        FCC     "1LIN"                   ;7A14: 31 4C 49 4E    '1LIN'
        FCB     $C5                      ;7A18: C5             '.'
forth_1LINE_LFA FDB     forth_MATCH_NFA          ;7A19: 7A 09          'z.'
forth_1LINE_CFA FDB     DOCOL                    ;7A1B: 65 F2          'e.'
forth_1LINE_PFA FDB     forth_HASHLAG_CFA        ;7A1D: 78 86          ; #LAG
        FDB     forth_PAD_CFA            ;7A1F: 6C 9B          ; PAD
        FDB     forth_COUNT_CFA          ;7A21: 6A C7          ; COUNT
        FDB     forth_MATCH_CFA          ;7A23: 7A 11          ; MATCH
        FDB     forth_R_HASH_CFA         ;7A25: 67 85          ; R#
        FDB     forth_PLUS_STORE_CFA     ;7A27: 65 72          ; +!
        FDB     forth_SEMIS_CFA          ;7A29: 64 44          ; ;S
;
; --- :: FIND ---
forth_FIND_NFA FCB     $84                      ;7A2B: 84             '.'
        FCC     "FIN"                    ;7A2C: 46 49 4E       'FIN'
        FCB     $C4                      ;7A2F: C4             '.'
forth_FIND_LFA FDB     forth_1LINE_NFA          ;7A30: 7A 13          'z.'
forth_FIND_CFA FDB     DOCOL                    ;7A32: 65 F2          'e.'
forth_FIND_PFA FDB     forth_LIT_CFA,$03FF      ;7A34: 61 45 03 FF    ; LIT
        FDB     forth_R_HASH_CFA         ;7A38: 67 85          ; R#
        FDB     forth_FETCH_CFA          ;7A3A: 65 9D          ; @
        FDB     forth_LT_CFA             ;7A3C: 68 31          ; <
        FDB     forth_0BRANCH_CFA,$0012  ;7A3E: 61 88 00 12    ; 0BRANCH
        FDB     forth_TOP_CFA            ;7A42: 79 6F          ; TOP
        FDB     forth_PAD_CFA            ;7A44: 6C 9B          ; PAD
        FDB     forth_HERE_CFA           ;7A46: 67 BE          ; HERE
        FDB     forth_C_SLASHL_CFA       ;7A48: 67 99          ; C/L
        FDB     forth_1_PLUS_CFA         ;7A4A: 67 A2          ; 1+
        FDB     forth_CMOVE_CFA          ;7A4C: 63 4B          ; CMOVE
        FDB     forth_0_CFA              ;7A4E: 66 62          ; 0
        FDB     forth_ERROR_CFA          ;7A50: 6D F1          ; ERROR
        FDB     forth_1LINE_CFA          ;7A52: 7A 1B          ; 1LINE
        FDB     forth_0BRANCH_CFA,$FFDE  ;7A54: 61 88 FF DE    ; 0BRANCH
        FDB     forth_SEMIS_CFA          ;7A58: 64 44          ; ;S
;
; --- :: N ---
forth_N_NFA FCB     $81,$CE                  ;7A5A: 81 CE          '..'
forth_N_LFA FDB     forth_FIND_NFA           ;7A5C: 7A 2B          'z+'
forth_N_CFA FDB     DOCOL                    ;7A5E: 65 F2          'e.'
forth_N_PFA FDB     forth_FIND_CFA           ;7A60: 7A 32          ; FIND
        FDB     forth_0_CFA,forth_M_CFA  ;7A62: 66 62 79 47    ; 0
        FDB     forth_SEMIS_CFA          ;7A66: 64 44          ; ;S
;
; --- :: F ---
forth_F_NFA FCB     $81,$C6                  ;7A68: 81 C6          '..'
forth_F_LFA FDB     forth_N_NFA              ;7A6A: 7A 5A          'zZ'
forth_F_CFA FDB     DOCOL                    ;7A6C: 65 F2          'e.'
forth_F_PFA FDB     forth_1_CFA              ;7A6E: 66 6A          ; 1
        FDB     forth_TEXT_CFA           ;7A70: 75 81          ; TEXT
        FDB     forth_N_CFA              ;7A72: 7A 5E          ; N
        FDB     forth_SEMIS_CFA          ;7A74: 64 44          ; ;S
;
; --- :: B ---
forth_B_NFA FCB     $81,$C2                  ;7A76: 81 C2          '..'
forth_B_LFA FDB     forth_F_NFA              ;7A78: 7A 68          'zh'
forth_B_CFA FDB     DOCOL                    ;7A7A: 65 F2          'e.'
forth_B_PFA FDB     forth_PAD_CFA            ;7A7C: 6C 9B          ; PAD
        FDB     forth_C_FETCH_CFA        ;7A7E: 65 AC          ; C@
        FDB     forth_MINUS_CFA          ;7A80: 64 F4          ; MINUS
        FDB     forth_M_CFA              ;7A82: 79 47          ; M
        FDB     forth_SEMIS_CFA          ;7A84: 64 44          ; ;S
;
; --- :: DELETE ---
forth_DELETE_NFA FCB     $86                      ;7A86: 86             '.'
        FCC     "DELET"                  ;7A87: 44 45 4C 45 54 'DELET'
        FCB     $C5                      ;7A8C: C5             '.'
forth_DELETE_LFA FDB     forth_B_NFA              ;7A8D: 7A 76          'zv'
forth_DELETE_CFA FDB     DOCOL                    ;7A8F: 65 F2          'e.'
forth_DELETE_PFA FDB     forth_GTR_CFA            ;7A91: 64 69          ; >R
        FDB     forth_HASHLAG_CFA        ;7A93: 78 86          ; #LAG
        FDB     forth_PLUS_CFA           ;7A95: 64 C6          ; +
        FDB     forth_R_CFA              ;7A97: 64 8E          ; R
        FDB     forth_MINUS_CFA          ;7A99: 68 19          ; -
        FDB     forth_HASHLAG_CFA        ;7A9B: 78 86          ; #LAG
        FDB     forth_R_CFA              ;7A9D: 64 8E          ; R
        FDB     forth_MINUS_CFA          ;7A9F: 64 F4          ; MINUS
        FDB     forth_R_HASH_CFA         ;7AA1: 67 85          ; R#
        FDB     forth_PLUS_STORE_CFA     ;7AA3: 65 72          ; +!
        FDB     forth_HASHLEAD_CFA       ;7AA5: 78 75          ; #LEAD
        FDB     forth_PLUS_CFA           ;7AA7: 64 C6          ; +
        FDB     forth_SWAP_CFA           ;7AA9: 65 4B          ; SWAP
        FDB     forth_CMOVE_CFA          ;7AAB: 63 4B          ; CMOVE
        FDB     forth_R_GT_CFA           ;7AAD: 64 7D          ; R>
        FDB     forth_BLANKS_CFA         ;7AAF: 6C 74          ; BLANKS
        FDB     forth_SEMIS_CFA          ;7AB1: 64 44          ; ;S
;
; --- :: X ---
forth_X_NFA FCB     $81,$D8                  ;7AB3: 81 D8          '..'
forth_X_LFA FDB     forth_DELETE_NFA         ;7AB5: 7A 86          'z.'
forth_X_CFA FDB     DOCOL                    ;7AB7: 65 F2          'e.'
forth_X_PFA FDB     forth_1_CFA              ;7AB9: 66 6A          ; 1
        FDB     forth_TEXT_CFA           ;7ABB: 75 81          ; TEXT
        FDB     forth_FIND_CFA           ;7ABD: 7A 32          ; FIND
        FDB     forth_PAD_CFA            ;7ABF: 6C 9B          ; PAD
        FDB     forth_C_FETCH_CFA        ;7AC1: 65 AC          ; C@
        FDB     forth_DELETE_CFA         ;7AC3: 7A 8F          ; DELETE
        FDB     forth_0_CFA,forth_M_CFA  ;7AC5: 66 62 79 47    ; 0
        FDB     forth_SEMIS_CFA          ;7AC9: 64 44          ; ;S
;
; --- :: TILL ---
forth_TILL_NFA FCB     $84                      ;7ACB: 84             '.'
        FCC     "TIL"                    ;7ACC: 54 49 4C       'TIL'
        FCB     $CC                      ;7ACF: CC             '.'
forth_TILL_LFA FDB     forth_X_NFA              ;7AD0: 7A B3          'z.'
forth_TILL_CFA FDB     DOCOL                    ;7AD2: 65 F2          'e.'
forth_TILL_PFA FDB     forth_HASHLEAD_CFA       ;7AD4: 78 75          ; #LEAD
        FDB     forth_PLUS_CFA           ;7AD6: 64 C6          ; +
        FDB     forth_1_CFA              ;7AD8: 66 6A          ; 1
        FDB     forth_TEXT_CFA           ;7ADA: 75 81          ; TEXT
        FDB     forth_1LINE_CFA          ;7ADC: 7A 1B          ; 1LINE
        FDB     forth_0_EQ_CFA           ;7ADE: 64 9C          ; 0=
        FDB     forth_0_CFA              ;7AE0: 66 62          ; 0
        FDB     forth_QUESTIONERROR_CFA  ;7AE2: 69 50          ; ?ERROR
        FDB     forth_HASHLEAD_CFA       ;7AE4: 78 75          ; #LEAD
        FDB     forth_PLUS_CFA           ;7AE6: 64 C6          ; +
        FDB     forth_SWAP_CFA           ;7AE8: 65 4B          ; SWAP
        FDB     forth_MINUS_CFA          ;7AEA: 68 19          ; -
        FDB     forth_DELETE_CFA         ;7AEC: 7A 8F          ; DELETE
        FDB     forth_0_CFA,forth_M_CFA  ;7AEE: 66 62 79 47    ; 0
        FDB     forth_SEMIS_CFA          ;7AF2: 64 44          ; ;S
;
; --- :: C ---
forth_C_NFA FCB     $81,$C3                  ;7AF4: 81 C3          '..'
forth_C_LFA FDB     forth_TILL_NFA           ;7AF6: 7A CB          'z.'
forth_C_CFA FDB     DOCOL                    ;7AF8: 65 F2          'e.'
forth_C_PFA FDB     forth_1_CFA              ;7AFA: 66 6A          ; 1
        FDB     forth_TEXT_CFA           ;7AFC: 75 81          ; TEXT
        FDB     forth_PAD_CFA            ;7AFE: 6C 9B          ; PAD
        FDB     forth_COUNT_CFA          ;7B00: 6A C7          ; COUNT
        FDB     forth_HASHLAG_CFA        ;7B02: 78 86          ; #LAG
        FDB     forth_ROT_CFA            ;7B04: 68 5D          ; ROT
        FDB     forth_OVER_CFA           ;7B06: 65 2E          ; OVER
        FDB     forth_MIN_CFA            ;7B08: 68 7F          ; MIN
        FDB     forth_GTR_CFA            ;7B0A: 64 69          ; >R
        FDB     forth_R_CFA              ;7B0C: 64 8E          ; R
        FDB     forth_R_HASH_CFA         ;7B0E: 67 85          ; R#
        FDB     forth_PLUS_STORE_CFA     ;7B10: 65 72          ; +!
        FDB     forth_R_CFA              ;7B12: 64 8E          ; R
        FDB     forth_MINUS_CFA          ;7B14: 68 19          ; -
        FDB     forth_GTR_CFA            ;7B16: 64 69          ; >R
        FDB     forth_DUP_CFA            ;7B18: 65 64          ; DUP
        FDB     forth_HERE_CFA           ;7B1A: 67 BE          ; HERE
        FDB     forth_R_CFA              ;7B1C: 64 8E          ; R
        FDB     forth_CMOVE_CFA          ;7B1E: 63 4B          ; CMOVE
        FDB     forth_HERE_CFA           ;7B20: 67 BE          ; HERE
        FDB     forth_HASHLEAD_CFA       ;7B22: 78 75          ; #LEAD
        FDB     forth_PLUS_CFA           ;7B24: 64 C6          ; +
        FDB     forth_R_GT_CFA           ;7B26: 64 7D          ; R>
        FDB     forth_CMOVE_CFA          ;7B28: 63 4B          ; CMOVE
        FDB     forth_R_GT_CFA           ;7B2A: 64 7D          ; R>
        FDB     forth_CMOVE_CFA          ;7B2C: 63 4B          ; CMOVE
        FDB     forth_0_CFA,forth_M_CFA  ;7B2E: 66 62 79 47    ; 0
        FDB     forth_SEMIS_CFA          ;7B32: 64 44          ; ;S
;
; --- :: VLIST ---
forth_VLIST_NFA FCB     $85                      ;7B34: 85             '.'
        FCC     "VLIS"                   ;7B35: 56 4C 49 53    'VLIS'
        FCB     $D4                      ;7B39: D4             '.'
forth_VLIST_LFA FDB     forth_C_NFA              ;7B3A: 7A F4          'z.'
forth_VLIST_CFA FDB     DOCOL                    ;7B3C: 65 F2          'e.'
forth_VLIST_PFA FDB     forth_LIT_CFA            ;7B3E: 61 45          ; LIT
        FDB     forth_IP_hi              ;7B40: 00 80          ;   [128 ($0080)]
        FDB     forth_OUT_CFA            ;7B42: 67 14          ; OUT
        FDB     forth_STORE_CFA          ;7B44: 65 BD          ; !
        FDB     forth_CONTEXT_CFA        ;7B46: 67 39          ; CONTEXT
        FDB     forth_FETCH_CFA          ;7B48: 65 9D          ; @
        FDB     forth_FETCH_CFA          ;7B4A: 65 9D          ; @
        FDB     forth_OUT_CFA            ;7B4C: 67 14          ; OUT
        FDB     forth_FETCH_CFA          ;7B4E: 65 9D          ; @
        FDB     forth_C_SLASHL_CFA       ;7B50: 67 99          ; C/L
        FDB     forth_GT_CFA             ;7B52: 68 4F          ; >
        FDB     forth_0BRANCH_CFA,$000A  ;7B54: 61 88 00 0A    ; 0BRANCH
        FDB     forth_CR_CFA             ;7B58: 63 3B          ; CR
        FDB     forth_0_CFA              ;7B5A: 66 62          ; 0
        FDB     forth_OUT_CFA            ;7B5C: 67 14          ; OUT
        FDB     forth_STORE_CFA          ;7B5E: 65 BD          ; !
        FDB     forth_DUP_CFA            ;7B60: 65 64          ; DUP
        FDB     forth_ID_DOT_CFA         ;7B62: 6E 28          ; ID.
        FDB     forth_SPACE_CFA          ;7B64: 68 71          ; SPACE
        FDB     forth_SPACE_CFA          ;7B66: 68 71          ; SPACE
        FDB     forth_PFA_CFA            ;7B68: 69 29          ; PFA
        FDB     forth_LFA_CFA            ;7B6A: 68 F7          ; LFA
        FDB     forth_FETCH_CFA          ;7B6C: 65 9D          ; @
        FDB     forth_DUP_CFA            ;7B6E: 65 64          ; DUP
        FDB     forth_0_EQ_CFA           ;7B70: 64 9C          ; 0=
        FDB     forth_QUESTIONTERM_CFA   ;7B72: 63 2D          ; ?TERM
        FDB     forth_OR_CFA             ;7B74: 63 F0          ; OR
        FDB     forth_0BRANCH_CFA,$FFD4  ;7B76: 61 88 FF D4    ; 0BRANCH
        FDB     forth_DROP_CFA           ;7B7A: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;7B7C: 64 44          ; ;S
;
; --- :: U. ---
forth_U_DOT_NFA FCB     $82                      ;7B7E: 82             '.'
        FCC     "U"                      ;7B7F: 55             'U'
        FCB     $AE                      ;7B80: AE             '.'
forth_U_DOT_LFA FDB     forth_VLIST_NFA          ;7B81: 7B 34          '{4'
forth_U_DOT_CFA FDB     DOCOL                    ;7B83: 65 F2          'e.'
forth_U_DOT_PFA FDB     forth_0_CFA              ;7B85: 66 62          ; 0
        FDB     forth_D_DOT_CFA          ;7B87: 74 15          ; D.
        FDB     forth_SEMIS_CFA          ;7B89: 64 44          ; ;S
;
; --- :: U< ---
forth_U_LT_NFA FCB     $82                      ;7B8B: 82             '.'
        FCC     "U"                      ;7B8C: 55             'U'
        FCB     $BC                      ;7B8D: BC             '.'
forth_U_LT_LFA FDB     forth_U_DOT_NFA          ;7B8E: 7B 7E          '{~'
forth_U_LT_CFA FDB     DOCOL                    ;7B90: 65 F2          'e.'
forth_U_LT_PFA FDB     forth_2DUP_CFA           ;7B92: 67 DC          ; 2DUP
        FDB     forth_XOR_CFA            ;7B94: 64 02          ; XOR
        FDB     forth_0_LT_CFA           ;7B96: 64 AF          ; 0<
        FDB     forth_0BRANCH_CFA,$000C  ;7B98: 61 88 00 0C    ; 0BRANCH
        FDB     forth_DROP_CFA           ;7B9C: 65 3D          ; DROP
        FDB     forth_0_LT_CFA           ;7B9E: 64 AF          ; 0<
        FDB     forth_0_EQ_CFA           ;7BA0: 64 9C          ; 0=
        FDB     forth_BRANCH_CFA,M0006   ;7BA2: 61 7C 00 06    ; BRANCH
        FDB     forth_MINUS_CFA          ;7BA6: 68 19          ; -
        FDB     forth_0_LT_CFA           ;7BA8: 64 AF          ; 0<
        FDB     forth_SEMIS_CFA          ;7BAA: 64 44          ; ;S
;
; --- CODE: 2! ---
forth_2_STORE_NFA FCB     $82                      ;7BAC: 82             '.'
        FCC     "2"                      ;7BAD: 32             '2'
        FCB     $A1                      ;7BAE: A1             '.'
forth_2_STORE_LFA FDB     forth_U_LT_NFA           ;7BAF: 7B 8B          '{.'
forth_2_STORE_CFA FDB     forth_2_STORE_PFA        ;7BB1: 7B B3          '{.'
forth_2_STORE_PFA TSX                              ;7BB3: 30             '0'
        LDX     ,X                       ;7BB4: EE 00          '..'
        INS                              ;7BB6: 31             '1'
        INS                              ;7BB7: 31             '1'
        PULA                             ;7BB8: 32             '2'
        PULB                             ;7BB9: 33             '3'
        STD     ,X                       ;7BBA: ED 00          '..'
        INX                              ;7BBC: 08             '.'
        INX                              ;7BBD: 08             '.'
        JMP     Z6126                    ;7BBE: 7E 61 26       '~a&'
;
; --- CODE: 2@ ---
forth_2_FETCH_NFA FCB     $82                      ;7BC1: 82             '.'
        FCC     "2"                      ;7BC2: 32             '2'
        FCB     $C0                      ;7BC3: C0             '.'
forth_2_FETCH_LFA FDB     forth_2_STORE_NFA        ;7BC4: 7B AC          '{.'
forth_2_FETCH_CFA FDB     forth_2_FETCH_PFA        ;7BC6: 7B C8          '{.'
forth_2_FETCH_PFA TSX                              ;7BC8: 30             '0'
        LDX     ,X                       ;7BC9: EE 00          '..'
        INS                              ;7BCB: 31             '1'
        INS                              ;7BCC: 31             '1'
        LDD     $02,X                    ;7BCD: EC 02          '..'
        PSHB                             ;7BCF: 37             '7'
        PSHA                             ;7BD0: 36             '6'
        JMP     Z612C                    ;7BD1: 7E 61 2C       '~a,'
;
; --- CODE: RP@ ---
forth_RP_FETCH_NFA FCB     $83                      ;7BD4: 83             '.'
        FCC     "RP"                     ;7BD5: 52 50          'RP'
        FCB     $C0                      ;7BD7: C0             '.'
forth_RP_FETCH_LFA FDB     forth_2_FETCH_NFA        ;7BD8: 7B C1          '{.'
forth_RP_FETCH_CFA FDB     forth_RP_FETCH_PFA       ;7BDA: 7B DC          '{.'
forth_RP_FETCH_PFA LDD     forth_RP                 ;7BDC: DC 94          '..'
        JMP     PUSHD                    ;7BDE: 7E 61 2E       '~a.'
;
; --- CODE: J ---
forth_J_NFA FCB     $81,$CA                  ;7BE1: 81 CA          '..'
forth_J_LFA FDB     forth_RP_FETCH_NFA       ;7BE3: 7B D4          '{.'
forth_J_CFA FDB     forth_J_PFA              ;7BE5: 7B E7          '{.'
forth_J_PFA LDD     forth_RP                 ;7BE7: DC 94          '..'
        ADDD    #M0006                   ;7BE9: C3 00 06       '...'
        PSHB                             ;7BEC: 37             '7'
        PSHA                             ;7BED: 36             '6'
        JMP     forth_FETCH_PFA          ;7BEE: 7E 65 9F       '~e.'
;
; --- CODE: BEEP ---
forth_BEEP_NFA FCB     $84                      ;7BF1: 84             '.'
        FCC     "BEE"                    ;7BF2: 42 45 45       'BEE'
        FCB     $D0                      ;7BF5: D0             '.'
forth_BEEP_LFA FDB     forth_J_NFA              ;7BF6: 7B E1          '{.'
forth_BEEP_CFA FDB     forth_BEEP_PFA           ;7BF8: 7B FA          '{.'
forth_BEEP_PFA PULB                             ;7BFA: 33             '3'
        PULB                             ;7BFB: 33             '3'
        PULA                             ;7BFC: 32             '2'
        PULA                             ;7BFD: 32             '2'
        JSR     rom_beep_2               ;7BFE: BD E3 F2       '...'
        JMP     NEXT                     ;7C01: 7E 61 30       '~a0'
;
; --- CODE: COPY ---
forth_COPY_NFA FCB     $84                      ;7C04: 84             '.'
        FCC     "COP"                    ;7C05: 43 4F 50       'COP'
        FCB     $D9                      ;7C08: D9             '.'
forth_COPY_LFA FDB     forth_BEEP_NFA           ;7C09: 7B F1          '{.'
forth_COPY_CFA FDB     forth_COPY_PFA           ;7C0B: 7C 0D          '|.'
forth_COPY_PFA JSR     ZE34D                    ;7C0D: BD E3 4D       '..M'
        JMP     NEXT                     ;7C10: 7E 61 30       '~a0'
;
; --- :: PRINT ---
forth_PRINT_NFA FCB     $85                      ;7C13: 85             '.'
        FCC     "PRIN"                   ;7C14: 50 52 49 4E    'PRIN'
        FCB     $D4                      ;7C18: D4             '.'
forth_PRINT_LFA FDB     forth_COPY_NFA           ;7C19: 7C 04          '|.'
forth_PRINT_CFA FDB     DOCOL                    ;7C1B: 65 F2          'e.'
forth_PRINT_PFA FDB     forth_LIT_CFA            ;7C1D: 61 45          ; LIT
        FDB     forth_char_flag          ;7C1F: 00 8B          ;   [139 ($008B)]
        FDB     forth_C_STORE_CFA        ;7C21: 65 CC          ; C!
        FDB     forth_SEMIS_CFA          ;7C23: 64 44          ; ;S
;
; --- CODE: FEED ---
forth_FEED_NFA FCB     $84                      ;7C25: 84             '.'
        FCC     "FEE"                    ;7C26: 46 45 45       'FEE'
        FCB     $C4                      ;7C29: C4             '.'
forth_FEED_LFA FDB     forth_PRINT_NFA          ;7C2A: 7C 13          '|.'
forth_FEED_CFA FDB     forth_FEED_PFA           ;7C2C: 7C 2E          '|.'
forth_FEED_PFA PULB                             ;7C2E: 33             '3'
        PULA                             ;7C2F: 32             '2'
        JSR     ZE2A5                    ;7C30: BD E2 A5       '...'
        JMP     NEXT                     ;7C33: 7E 61 30       '~a0'
;
; --- CODE: PSET ---
forth_PSET_NFA FCB     $84                      ;7C36: 84             '.'
        FCC     "PSE"                    ;7C37: 50 53 45       'PSE'
        FCB     $D4                      ;7C3A: D4             '.'
forth_PSET_LFA FDB     forth_FEED_NFA           ;7C3B: 7C 25          '|%'
forth_PSET_CFA FDB     forth_PSET_PFA           ;7C3D: 7C 3F          '|?'
forth_PSET_PFA LDX     #M009C                   ;7C3F: CE 00 9C       '...'
        STX     M0050                    ;7C42: DF 50          '.P'
        PULA                             ;7C44: 32             '2'
        PULB                             ;7C45: 33             '3'
        STD     $03,X                    ;7C46: ED 03          '..'
        PULA                             ;7C48: 32             '2'
        PULB                             ;7C49: 33             '3'
        STD     $01,X                    ;7C4A: ED 01          '..'
        PULA                             ;7C4C: 32             '2'
        PULB                             ;7C4D: 33             '3'
        STAB    $05,X                    ;7C4E: E7 05          '..'
        JSR     ZD957                    ;7C50: BD D9 57       '..W'
        JMP     NEXT                     ;7C53: 7E 61 30       '~a0'
;
; --- CODE: PGET ---
forth_PGET_NFA FCB     $84                      ;7C56: 84             '.'
        FCC     "PGE"                    ;7C57: 50 47 45       'PGE'
        FCB     $D4                      ;7C5A: D4             '.'
forth_PGET_LFA FDB     forth_PSET_NFA           ;7C5B: 7C 36          '|6'
forth_PGET_CFA FDB     forth_PGET_PFA           ;7C5D: 7C 5F          '|_'
forth_PGET_PFA LDX     #M009C                   ;7C5F: CE 00 9C       '...'
        STX     M0050                    ;7C62: DF 50          '.P'
        PULA                             ;7C64: 32             '2'
        PULB                             ;7C65: 33             '3'
        STD     $03,X                    ;7C66: ED 03          '..'
        PULA                             ;7C68: 32             '2'
        PULB                             ;7C69: 33             '3'
        STD     $01,X                    ;7C6A: ED 01          '..'
        JSR     ZD977                    ;7C6C: BD D9 77       '..w'
        CLRA                             ;7C6F: 4F             'O'
        LDAB    M009D                    ;7C70: D6 9D          '..'
        JMP     PUSHD                    ;7C72: 7E 61 2E       '~a.'
;
; --- CODE: PLOT ---
forth_PLOT_NFA FCB     $84                      ;7C75: 84             '.'
        FCC     "PLO"                    ;7C76: 50 4C 4F       'PLO'
        FCB     $D4                      ;7C79: D4             '.'
forth_PLOT_LFA FDB     forth_PGET_NFA           ;7C7A: 7C 56          '|V'
forth_PLOT_CFA FDB     forth_PLOT_PFA           ;7C7C: 7C 7E          '|~'
forth_PLOT_PFA LDX     #M009C                   ;7C7E: CE 00 9C       '...'
        STX     M0050                    ;7C81: DF 50          '.P'
        PULA                             ;7C83: 32             '2'
        PULB                             ;7C84: 33             '3'
        STD     $03,X                    ;7C85: ED 03          '..'
        PULA                             ;7C87: 32             '2'
        PULB                             ;7C88: 33             '3'
        STD     $01,X                    ;7C89: ED 01          '..'
        PULA                             ;7C8B: 32             '2'
        PULB                             ;7C8C: 33             '3'
        STAB    $09,X                    ;7C8D: E7 09          '..'
        JSR     ZD9D6                    ;7C8F: BD D9 D6       '...'
        JMP     NEXT                     ;7C92: 7E 61 30       '~a0'
;
; --- CODE: DRAW ---
forth_DRAW_NFA FCB     $84                      ;7C95: 84             '.'
        FCC     "DRA"                    ;7C96: 44 52 41       'DRA'
        FCB     $D7                      ;7C99: D7             '.'
forth_DRAW_LFA FDB     forth_PLOT_NFA           ;7C9A: 7C 75          '|u'
forth_DRAW_CFA FDB     forth_DRAW_PFA           ;7C9C: 7C 9E          '|.'
forth_DRAW_PFA LDX     #M009C                   ;7C9E: CE 00 9C       '...'
        STX     M0050                    ;7CA1: DF 50          '.P'
        PULA                             ;7CA3: 32             '2'
        PULB                             ;7CA4: 33             '3'
        STD     $07,X                    ;7CA5: ED 07          '..'
        PULA                             ;7CA7: 32             '2'
        PULB                             ;7CA8: 33             '3'
        STD     $05,X                    ;7CA9: ED 05          '..'
        PULA                             ;7CAB: 32             '2'
        PULB                             ;7CAC: 33             '3'
        STD     $03,X                    ;7CAD: ED 03          '..'
        PULA                             ;7CAF: 32             '2'
        PULB                             ;7CB0: 33             '3'
        STD     $01,X                    ;7CB1: ED 01          '..'
        PULA                             ;7CB3: 32             '2'
        PULB                             ;7CB4: 33             '3'
        STAB    $09,X                    ;7CB5: E7 09          '..'
        JSR     ZDA07                    ;7CB7: BD DA 07       '...'
        JMP     NEXT                     ;7CBA: 7E 61 30       '~a0'
;
; --- USER variable: MASK ---
forth_MASK_NFA FCB     $84                      ;7CBD: 84             '.'
        FCC     "MAS"                    ;7CBE: 4D 41 53       'MAS'
        FCB     $CB                      ;7CC1: CB             '.'
forth_MASK_LFA FDB     forth_DRAW_NFA           ;7CC2: 7C 95          '|.'
forth_MASK_CFA FDB     DOUSE                    ;7CC4: 66 55          'fU'
forth_MASK_PFA FDB     $0038                    ;7CC6: 00 38          ; user area offset 56 ($0038)
;
; --- :: TRAM ---
forth_TRAM_NFA FCB     $84                      ;7CC8: 84             '.'
        FCC     "TRA"                    ;7CC9: 54 52 41       'TRA'
        FCB     $CD                      ;7CCC: CD             '.'
forth_TRAM_LFA FDB     forth_MASK_NFA           ;7CCD: 7C BD          '|.'
forth_TRAM_CFA FDB     DOCOL                    ;7CCF: 65 F2          'e.'
forth_TRAM_PFA FDB     forth_LIT_CFA,$007E      ;7CD1: 61 45 00 7E    ; LIT
        FDB     forth_LIT_CFA            ;7CD5: 61 45          ; LIT
        FDB     forth_IP_hi              ;7CD7: 00 80          ;   [128 ($0080)]
        FDB     forth_TOGGLE_CFA         ;7CD9: 65 8B          ; TOGGLE
        FDB     forth_SEMIS_CFA          ;7CDB: 64 44          ; ;S
;
; --- CODE: (CLK) ---
forth_PARENCLK_RPAREN_NFA FCB     $85                      ;7CDD: 85             '.'
        FCC     "(CLK"                   ;7CDE: 28 43 4C 4B    '(CLK'
        FCB     $A9                      ;7CE2: A9             '.'
forth_PARENCLK_RPAREN_LFA FDB     forth_TRAM_NFA           ;7CE3: 7C C8          '|.'
forth_PARENCLK_RPAREN_CFA FDB     forth_PARENCLK_RPAREN_PFA ;7CE5: 7C E7          '|.'
forth_PARENCLK_RPAREN_PFA SEI                              ;7CE7: 0F             '.'
        LDX     #M00B0                   ;7CE8: CE 00 B0       '...'
        JSR     ZE1FF                    ;7CEB: BD E1 FF       '...'
        JMP     NEXT                     ;7CEE: 7E 61 30       '~a0'
;
; --- :: TIME@ ---
forth_TIME_FETCH_NFA FCB     $85                      ;7CF1: 85             '.'
        FCC     "TIME"                   ;7CF2: 54 49 4D 45    'TIME'
        FCB     $C0                      ;7CF6: C0             '.'
forth_TIME_FETCH_LFA FDB     forth_PARENCLK_RPAREN_NFA ;7CF7: 7C DD          '|.'
forth_TIME_FETCH_CFA FDB     DOCOL                    ;7CF9: 65 F2          'e.'
forth_TIME_FETCH_PFA FDB     forth_TRAM_CFA           ;7CFB: 7C CF          ; TRAM
        FDB     forth_PARENCLK_RPAREN_CFA ;7CFD: 7C E5          ; (CLK)
        FDB     forth_TRAM_CFA           ;7CFF: 7C CF          ; TRAM
        FDB     forth_SEMIS_CFA          ;7D01: 64 44          ; ;S
;
; --- :: HRS ---
forth_HRS_NFA FCB     $83                      ;7D03: 83             '.'
        FCC     "HR"                     ;7D04: 48 52          'HR'
        FCB     $D3                      ;7D06: D3             '.'
forth_HRS_LFA FDB     forth_TIME_FETCH_NFA     ;7D07: 7C F1          '|.'
forth_HRS_CFA FDB     DOCOL                    ;7D09: 65 F2          'e.'
forth_HRS_PFA FDB     forth_LIT_CFA,$00B3      ;7D0B: 61 45 00 B3    ; LIT
        FDB     forth_C_FETCH_CFA        ;7D0F: 65 AC          ; C@
        FDB     forth_SEMIS_CFA          ;7D11: 64 44          ; ;S
;
; --- :: MINS ---
forth_MINS_NFA FCB     $84                      ;7D13: 84             '.'
        FCC     "MIN"                    ;7D14: 4D 49 4E       'MIN'
        FCB     $D3                      ;7D17: D3             '.'
forth_MINS_LFA FDB     forth_HRS_NFA            ;7D18: 7D 03          '}.'
forth_MINS_CFA FDB     DOCOL                    ;7D1A: 65 F2          'e.'
forth_MINS_PFA FDB     forth_LIT_CFA,$00B4      ;7D1C: 61 45 00 B4    ; LIT
        FDB     forth_C_FETCH_CFA        ;7D20: 65 AC          ; C@
        FDB     forth_SEMIS_CFA          ;7D22: 64 44          ; ;S
;
; --- :: SECS ---
forth_SECS_NFA FCB     $84                      ;7D24: 84             '.'
        FCC     "SEC"                    ;7D25: 53 45 43       'SEC'
        FCB     $D3                      ;7D28: D3             '.'
forth_SECS_LFA FDB     forth_MINS_NFA           ;7D29: 7D 13          '}.'
forth_SECS_CFA FDB     DOCOL                    ;7D2B: 65 F2          'e.'
forth_SECS_PFA FDB     forth_LIT_CFA,$00B5      ;7D2D: 61 45 00 B5    ; LIT
        FDB     forth_C_FETCH_CFA        ;7D31: 65 AC          ; C@
        FDB     forth_SEMIS_CFA          ;7D33: 64 44          ; ;S
;
; --- :: TIME ---
forth_TIME_NFA FCB     $84                      ;7D35: 84             '.'
        FCC     "TIM"                    ;7D36: 54 49 4D       'TIM'
        FCB     $C5                      ;7D39: C5             '.'
forth_TIME_LFA FDB     forth_SECS_NFA           ;7D3A: 7D 24          '}$'
forth_TIME_CFA FDB     DOCOL                    ;7D3C: 65 F2          'e.'
forth_TIME_PFA FDB     forth_TIME_FETCH_CFA     ;7D3E: 7C F9          ; TIME@
        FDB     forth_BASE_CFA           ;7D40: 67 5E          ; BASE
        FDB     forth_FETCH_CFA          ;7D42: 65 9D          ; @
        FDB     forth_HEX_CFA            ;7D44: 6A 27          'j; HEX
        FDB     forth_HRS_CFA            ;7D46: 7D 09          ; HRS
        FDB     forth_DOT_CFA            ;7D48: 74 34          ; .
        FDB     forth_LIT_CFA,$003A      ;7D4A: 61 45 00 3A    ; LIT
        FDB     forth_EMIT_CFA           ;7D4E: 63 02          ; EMIT
        FDB     forth_MINS_CFA           ;7D50: 7D 1A          ; MINS
        FDB     forth_DOT_CFA            ;7D52: 74 34          ; .
        FDB     forth_LIT_CFA,$003A      ;7D54: 61 45 00 3A    ; LIT
        FDB     forth_EMIT_CFA           ;7D58: 63 02          ; EMIT
        FDB     forth_SECS_CFA           ;7D5A: 7D 2B          ; SECS
        FDB     forth_DOT_CFA            ;7D5C: 74 34          ; .
        FDB     forth_BASE_CFA           ;7D5E: 67 5E          ; BASE
        FDB     forth_STORE_CFA          ;7D60: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;7D62: 64 44          ; ;S
;
; --- :: DAY ---
forth_DAY_NFA FCB     $83                      ;7D64: 83             '.'
        FCC     "DA"                     ;7D65: 44 41          'DA'
        FCB     $D9                      ;7D67: D9             '.'
forth_DAY_LFA FDB     forth_TIME_NFA           ;7D68: 7D 35          '}5'
forth_DAY_CFA FDB     DOCOL                    ;7D6A: 65 F2          'e.'
forth_DAY_PFA FDB     forth_LIT_CFA,$00B1      ;7D6C: 61 45 00 B1    ; LIT
        FDB     forth_C_FETCH_CFA        ;7D70: 65 AC          ; C@
        FDB     forth_SEMIS_CFA          ;7D72: 64 44          ; ;S
;
; --- :: MTH ---
forth_MTH_NFA FCB     $83                      ;7D74: 83             '.'
        FCC     "MT"                     ;7D75: 4D 54          'MT'
        FCB     $C8                      ;7D77: C8             '.'
forth_MTH_LFA FDB     forth_DAY_NFA            ;7D78: 7D 64          '}d'
forth_MTH_CFA FDB     DOCOL                    ;7D7A: 65 F2          'e.'
forth_MTH_PFA FDB     forth_LIT_CFA,M00B0      ;7D7C: 61 45 00 B0    ; LIT
        FDB     forth_C_FETCH_CFA        ;7D80: 65 AC          ; C@
        FDB     forth_SEMIS_CFA          ;7D82: 64 44          ; ;S
;
; --- :: YR ---
forth_YR_NFA FCB     $82                      ;7D84: 82             '.'
        FCC     "Y"                      ;7D85: 59             'Y'
        FCB     $D2                      ;7D86: D2             '.'
forth_YR_LFA FDB     forth_MTH_NFA            ;7D87: 7D 74          '}t'
forth_YR_CFA FDB     DOCOL                    ;7D89: 65 F2          'e.'
forth_YR_PFA FDB     forth_LIT_CFA,$00B2      ;7D8B: 61 45 00 B2    ; LIT
        FDB     forth_C_FETCH_CFA        ;7D8F: 65 AC          ; C@
        FDB     forth_SEMIS_CFA          ;7D91: 64 44          ; ;S
;
; --- :: DATE ---
forth_DATE_NFA FCB     $84                      ;7D93: 84             '.'
        FCC     "DAT"                    ;7D94: 44 41 54       'DAT'
        FCB     $C5                      ;7D97: C5             '.'
forth_DATE_LFA FDB     forth_YR_NFA             ;7D98: 7D 84          '}.'
forth_DATE_CFA FDB     DOCOL                    ;7D9A: 65 F2          'e.'
forth_DATE_PFA FDB     forth_TIME_FETCH_CFA     ;7D9C: 7C F9          ; TIME@
        FDB     forth_BASE_CFA           ;7D9E: 67 5E          ; BASE
        FDB     forth_FETCH_CFA          ;7DA0: 65 9D          ; @
        FDB     forth_HEX_CFA            ;7DA2: 6A 27          'j; HEX
        FDB     forth_DAY_CFA            ;7DA4: 7D 6A          ; DAY
        FDB     forth_DOT_CFA            ;7DA6: 74 34          ; .
        FDB     forth_LIT_CFA,$002E      ;7DA8: 61 45 00 2E    ; LIT
        FDB     forth_EMIT_CFA           ;7DAC: 63 02          ; EMIT
        FDB     forth_MTH_CFA            ;7DAE: 7D 7A          ; MTH
        FDB     forth_DOT_CFA            ;7DB0: 74 34          ; .
        FDB     forth_LIT_CFA,$002E      ;7DB2: 61 45 00 2E    ; LIT
        FDB     forth_EMIT_CFA           ;7DB6: 63 02          ; EMIT
        FDB     forth_YR_CFA             ;7DB8: 7D 89          ; YR
        FDB     forth_DOT_CFA            ;7DBA: 74 34          ; .
        FDB     forth_BASE_CFA           ;7DBC: 67 5E          ; BASE
        FDB     forth_STORE_CFA          ;7DBE: 65 BD          ; !
        FDB     forth_SEMIS_CFA          ;7DC0: 64 44          ; ;S
;
; --- CONSTANT: UDP ---
forth_UDP_NFA FCB     $83                      ;7DC2: 83             '.'
        FCC     "UD"                     ;7DC3: 55 44          'UD'
        FCB     $D0                      ;7DC5: D0             '.'
forth_UDP_LFA FDB     forth_DATE_NFA           ;7DC6: 7D 93          '}.'
forth_UDP_CFA FDB     DOCON                    ;7DC8: 66 28          'f('
forth_UDP_PFA FDB     $011E                    ;7DCA: 01 1E          ; = 286 ($011E)
;
; --- :: DCHAR ---
forth_DCHAR_NFA FCB     $85                      ;7DCC: 85             '.'
        FCC     "DCHA"                   ;7DCD: 44 43 48 41    'DCHA'
        FCB     $D2                      ;7DD1: D2             '.'
forth_DCHAR_LFA FDB     forth_UDP_NFA            ;7DD2: 7D C2          '}.'
forth_DCHAR_CFA FDB     DOCOL                    ;7DD4: 65 F2          'e.'
forth_DCHAR_PFA FDB     forth_LIT_CFA,$0007      ;7DD6: 61 45 00 07    ; LIT
        FDB     forth_ROLL_CFA           ;7DDA: 75 19          ; ROLL
        FDB     forth_LIT_CFA,$00E0      ;7DDC: 61 45 00 E0    ; LIT
        FDB     forth_MINUS_CFA          ;7DE0: 68 19          ; -
        FDB     forth_DUP_CFA            ;7DE2: 65 64          ; DUP
        FDB     forth_0_LT_CFA           ;7DE4: 64 AF          ; 0<
        FDB     forth_LIT_CFA,$0005      ;7DE6: 61 45 00 05    ; LIT
        FDB     forth_QUESTIONERROR_CFA  ;7DEA: 69 50          ; ?ERROR
        FDB     forth_LIT_CFA,M0006      ;7DEC: 61 45 00 06    ; LIT
        FDB     forth_STAR_CFA           ;7DF0: 71 A0          ; *
        FDB     forth_UDP_CFA            ;7DF2: 7D C8          ; UDP
        FDB     forth_FETCH_CFA          ;7DF4: 65 9D          ; @
        FDB     forth_PLUS_CFA           ;7DF6: 64 C6          ; +
        FDB     forth_1_CFA              ;7DF8: 66 6A          ; 1
        FDB     forth_MINUS_CFA          ;7DFA: 68 19          ; -
        FDB     forth_DUP_CFA            ;7DFC: 65 64          ; DUP
        FDB     forth_LIT_CFA,M0006      ;7DFE: 61 45 00 06    ; LIT
        FDB     forth_PLUS_CFA           ;7E02: 64 C6          ; +
        FDB     forth_PARENDO_RPAREN_CFA ;7E04: 61 EF          ; (DO)
        FDB     forth_I_CFA              ;7E06: 62 08          ; I
        FDB     forth_C_STORE_CFA        ;7E08: 65 CC          ; C!
        FDB     forth_LIT_CFA,$FFFF      ;7E0A: 61 45 FF FF    ; LIT
        FDB     forth_PAREN_PLUSLOOP_RPAREN_CFA ;7E0E: 61 BF          ; (+LOOP)
        FDB     $FFF6,forth_SEMIS_CFA    ;7E10: FF F6 64 44    ;   [->$7E06]
;
; --- :: LAST ---
forth_LAST_NFA FCB     $84                      ;7E14: 84             '.'
        FCC     "LAS"                    ;7E15: 4C 41 53       'LAS'
        FCB     $D4                      ;7E18: D4             '.'
forth_LAST_LFA FDB     forth_DCHAR_NFA          ;7E19: 7D CC          '}.'
forth_LAST_CFA FDB     DOCOL                    ;7E1B: 65 F2          'e.'
forth_LAST_PFA FDB     forth_LATEST_CFA         ;7E1D: 68 E7          ; LATEST
        FDB     forth_ID_DOT_CFA         ;7E1F: 6E 28          ; ID.
        FDB     forth_SEMIS_CFA          ;7E21: 64 44          ; ;S
;
; --- :: HOME ---
forth_HOME_NFA FCB     $84                      ;7E23: 84             '.'
        FCC     "HOM"                    ;7E24: 48 4F 4D       'HOM'
        FCB     $C5                      ;7E27: C5             '.'
forth_HOME_LFA FDB     forth_LAST_NFA           ;7E28: 7E 14          '~.'
forth_HOME_CFA FDB     DOCOL                    ;7E2A: 65 F2          'e.'
forth_HOME_PFA FDB     forth_LIT_CFA,$000B      ;7E2C: 61 45 00 0B    ; LIT
        FDB     forth_EMIT_CFA           ;7E30: 63 02          ; EMIT
        FDB     forth_SEMIS_CFA          ;7E32: 64 44          ; ;S
;
; --- :: MTC ---
forth_MTC_NFA FCB     $83                      ;7E34: 83             '.'
        FCC     "MT"                     ;7E35: 4D 54          'MT'
        FCB     $C3                      ;7E37: C3             '.'
forth_MTC_LFA FDB     forth_HOME_NFA           ;7E38: 7E 23          '~#'
forth_MTC_CFA FDB     DOCOL                    ;7E3A: 65 F2          'e.'
forth_MTC_PFA FDB     forth_HOME_CFA           ;7E3C: 7E 2A          ; HOME
        FDB     forth_MINUSDUP_CFA       ;7E3E: 68 AC          ; -DUP
        FDB     forth_0BRANCH_CFA,$0010  ;7E40: 61 88 00 10    ; 0BRANCH
        FDB     forth_0_CFA              ;7E44: 66 62          ; 0
        FDB     forth_PARENDO_RPAREN_CFA ;7E46: 61 EF          ; (DO)
        FDB     forth_LIT_CFA,$001F      ;7E48: 61 45 00 1F    ; LIT
        FDB     forth_EMIT_CFA           ;7E4C: 63 02          ; EMIT
        FDB     forth_PARENLOOP_RPAREN_CFA ;7E4E: 61 AE          ; (LOOP)
        FDB     $FFF8                    ;7E50: FF F8          ;   [->$7E48]
        FDB     forth_MINUSDUP_CFA       ;7E52: 68 AC          ; -DUP
        FDB     forth_0BRANCH_CFA,$0010  ;7E54: 61 88 00 10    ; 0BRANCH
        FDB     forth_0_CFA              ;7E58: 66 62          ; 0
        FDB     forth_PARENDO_RPAREN_CFA ;7E5A: 61 EF          ; (DO)
        FDB     forth_LIT_CFA,$001C      ;7E5C: 61 45 00 1C    ; LIT
        FDB     forth_EMIT_CFA           ;7E60: 63 02          ; EMIT
        FDB     forth_PARENLOOP_RPAREN_CFA ;7E62: 61 AE          ; (LOOP)
        FDB     $FFF8,forth_SEMIS_CFA    ;7E64: FF F8 64 44    ;   [->$7E5C]
;
; --- :: MCASS ---
forth_MCASS_NFA FCB     $85                      ;7E68: 85             '.'
        FCC     "MCAS"                   ;7E69: 4D 43 41 53    'MCAS'
        FCB     $D3                      ;7E6D: D3             '.'
forth_MCASS_LFA FDB     forth_MTC_NFA            ;7E6E: 7E 34          '~4'
forth_MCASS_CFA FDB     DOCOL                    ;7E70: 65 F2          'e.'
forth_MCASS_PFA FDB     forth_LIT_CFA,$004D      ;7E72: 61 45 00 4D    ; LIT
        FDB     forth_LIT_CFA,M0060      ;7E76: 61 45 00 60    ; LIT
        FDB     forth_C_STORE_CFA        ;7E7A: 65 CC          ; C!
        FDB     forth_SEMIS_CFA          ;7E7C: 64 44          ; ;S
;
; --- CODE: TAPCNT ---
forth_TAPCNT_NFA FCB     $86                      ;7E7E: 86             '.'
        FCC     "TAPCN"                  ;7E7F: 54 41 50 43 4E 'TAPCN'
        FCB     $D4                      ;7E84: D4             '.'
forth_TAPCNT_LFA FDB     forth_MCASS_NFA          ;7E85: 7E 68          '~h'
forth_TAPCNT_CFA FDB     forth_TAPCNT_PFA         ;7E87: 7E 89          '~.'
forth_TAPCNT_PFA PULA                             ;7E89: 32             '2'
        PULA                             ;7E8A: 32             '2'
        TSTA                             ;7E8B: 4D             'M'
        BEQ     Z7E95                    ;7E8C: 27 07          ''.'
        PULX                             ;7E8E: 38             '8'
        STX     M0203                    ;7E8F: FF 02 03       '...'
Z7E92   JMP     NEXT                     ;7E92: 7E 61 30       '~a0'
Z7E95   LDX     M0203                    ;7E95: FE 02 03       '...'
        BMI     Z7E9D                    ;7E98: 2B 03          '+.'
        PSHX                             ;7E9A: 3C             '<'
        BRA     Z7E92                    ;7E9B: 20 F5          ' .'
Z7E9D   LDD     #M1202                   ;7E9D: CC 12 02       '...'
        JSR     rom_beep_2               ;7EA0: BD E3 F2       '...'
        BRA     Z7E92                    ;7EA3: 20 ED          ' .'
;
; --- CODE: SEEK ---
forth_SEEK_NFA FCB     $84                      ;7EA5: 84             '.'
        FCC     "SEE"                    ;7EA6: 53 45 45       'SEE'
        FCB     $CB                      ;7EA9: CB             '.'
forth_SEEK_LFA FDB     forth_TAPCNT_NFA         ;7EAA: 7E 7E          '~~'
forth_SEEK_CFA FDB     forth_SEEK_PFA           ;7EAC: 7E AE          '~.'
forth_SEEK_PFA PULX                             ;7EAE: 38             '8'
        JSR     rom_print_char           ;7EAF: BD EB 8F       '...'
        JMP     NEXT                     ;7EB2: 7E 61 30       '~a0'
;
; --- :: WIND ---
forth_WIND_NFA FCB     $84                      ;7EB5: 84             '.'
        FCC     "WIN"                    ;7EB6: 57 49 4E       'WIN'
        FCB     $C4                      ;7EB9: C4             '.'
forth_WIND_LFA FDB     forth_SEEK_NFA           ;7EBA: 7E A5          '~.'
forth_WIND_CFA FDB     DOCOL                    ;7EBC: 65 F2          'e.'
forth_WIND_PFA FDB     forth_LIT_CFA,M0203      ;7EBE: 61 45 02 03    ; LIT
        FDB     forth_FETCH_CFA          ;7EC2: 65 9D          ; @
        FDB     forth_PLUS_CFA           ;7EC4: 64 C6          ; +
        FDB     forth_SEEK_CFA           ;7EC6: 7E AC          ; SEEK
        FDB     forth_SEMIS_CFA          ;7EC8: 64 44          ; ;S
Z7ECA   FDB     $867E,$CEDF,$F1B7        ;7ECA: 86 7E CE DF F1 B7 '.~....'
        FDB     rom_read_key,$FF0C       ;7ED0: 0C 10 FF 0C    '....'
        FDB     $118E,M04BF              ;7ED4: 11 8E 04 BF    '....'
        FDB     forth_MCASS_CFA          ;7ED8: 7E 70          '~p'
        FDB     $9D83                    ;7EDA: 9D 83          '..'
        FCC     "MO"                     ;7EDC: 4D 4F          'MO'
        FCB     $C4                      ;7EDE: C4             '.'
forth_MOD_LFA FDB     forth_WIND_NFA           ;7EDF: 7E B5          '~.'
forth_MOD_CFA FDB     DOCOL                    ;7EE1: 65 F2          'e.'
forth_MOD_PFA FDB     forth_SLASHMOD_CFA       ;7EE3: 71 B1          ; /MOD
        FDB     forth_DROP_CFA           ;7EE5: 65 3D          ; DROP
        FDB     forth_SEMIS_CFA          ;7EE7: 64 44          ; ;S
;
; --- :: 2* ---
forth_2_STAR_NFA FCB     $82                      ;7EE9: 82             '.'
        FCC     "2"                      ;7EEA: 32             '2'
        FCB     $AA                      ;7EEB: AA             '.'
forth_2_STAR_LFA FDB     forth_MOD_NFA            ;7EEC: 7E DB          '~.'
forth_2_STAR_CFA FDB     DOCOL                    ;7EEE: 65 F2          'e.'
forth_2_STAR_PFA FDB     forth_DUP_CFA            ;7EF0: 65 64          ; DUP
        FDB     forth_PLUS_CFA           ;7EF2: 64 C6          ; +
        FDB     forth_SEMIS_CFA,DOCOL    ;7EF4: 64 44 65 F2    ; ;S
        FDB     forth_DUP_CFA            ;7EF8: 65 64          'ed'
        FDB     forth_H_CFA              ;7EFA: 78 AE          'x.'
        FDB     forth_SEMIS_CFA,$0F7E    ;7EFC: 64 44 0F 7E    'dD.~'
        FDB     $608C                    ;7F00: 60 8C          '`.'
Z7F02   FDB     $0E7E,PUSHD,$32D4,$B84C  ;7F02: 0E 7E 61 2E 32 D4 B8 4C '.~a.2..L'
        FDB     $186E,$8239,$4813,$E890  ;7F0A: 18 6E 82 39 48 13 E8 90 '.n.9H...'
        FDB     $0E6C,$C01D,$CA6C,$6E3E  ;7F12: 0E 6C C0 1D CA 6C 6E 3E '.l...ln>'
        FDB     $06E6,$BECC,$BEDF,$2B1F  ;7F1A: 06 E6 BE CC BE DF 2B 1F '......+.'
        FDB     $8EB5,$096B,$52C0,$5AC1  ;7F22: 8E B5 09 6B 52 C0 5A C1 '...kR.Z.'
        FDB     $2EDF,$E38D,$9C51,$0578  ;7F2A: 2E DF E3 8D 9C 51 05 78 '.....Q.x'
        FDB     $361F,$B309,$3A4A,$4E3C  ;7F32: 36 1F B3 09 3A 4A 4E 3C '6...:JN<'
        FDB     $181C,$7439,$4C67,$CFD2  ;7F3A: 18 1C 74 39 4C 67 CF D2 '..t9Lg..'
        FDB     $4D91,$2231,$86E6,$03FE  ;7F42: 4D 91 22 31 86 E6 03 FE 'M."1....'
        FDB     $103C,$368D,$5F3C,$0F6B  ;7F4A: 10 3C 36 8D 5F 3C 0F 6B '.<6._<.k'
        FDB     $CDF8,$A4B9,$D31F,$3A9F  ;7F52: CD F8 A4 B9 D3 1F 3A 9F '......:.'
        FDB     $EB47,$36A7,$8814,$E8DA  ;7F5A: EB 47 36 A7 88 14 E8 DA '.G6.....'
        FDB     $1DBB,$2E4A,$95FC,$9257  ;7F62: 1D BB 2E 4A 95 FC 92 57 '...J...W'
        FDB     forth_PARENNUMBER_RPAREN_NFA ;7F6A: 6D 09          'm.'
        FDB     forth_DMINUS_CFA,$3AF0   ;7F6C: 65 0D 3A F0    'e.:.'
        FDB     $4A39,$3922,$8360,$8797  ;7F70: 4A 39 39 22 83 60 87 97 'J99".`..'
        FDB     $E736,$4CCB,$0FEE,$7456  ;7F78: E7 36 4C CB 0F EE 74 56 '.6L...tV'
        FDB     $E5AB,$7E62,$A346,$83BF  ;7F80: E5 AB 7E 62 A3 46 83 BF '..~b.F..'
        FDB     $CF04,$01CB,$0A20,$227B  ;7F88: CF 04 01 CB 0A 20 22 7B '..... "{'
        FDB     $340C,$EF37,$47E3,$86D2  ;7F90: 34 0C EF 37 47 E3 86 D2 '4..7G...'
        FDB     $88E1,$9F0B,$F283,$DD9F  ;7F98: 88 E1 9F 0B F2 83 DD 9F '........'
        FDB     $6D28,$315E,$C769,$159F  ;7FA0: 6D 28 31 5E C7 69 15 9F 'm(1^.i..'
        FDB     $2884,$039B,$42F6,$CF48  ;7FA8: 28 84 03 9B 42 F6 CF 48 '(...B..H'
        FDB     $1AFC,$E6CA,M0C0F,$A741  ;7FB0: 1A FC E6 CA 0C 0F A7 41 '.......A'
        FDB     $8A54,$EA07,$6465,$226A  ;7FB8: 8A 54 EA 07 64 65 22 6A '.T..de"j'
        FDB     $8504,$530F,$3156,$5837  ;7FC0: 85 04 53 0F 31 56 58 37 '..S.1VX7'
        FDB     $EE0A,$EBF9,$447A,$9D2C  ;7FC8: EE 0A EB F9 44 7A 9D 2C '....Dz.,'
        FDB     $9AAA,$F1A0,$463F,$CB21  ;7FD0: 9A AA F1 A0 46 3F CB 21 '....F?.!'
        FDB     CIRQVEC,$1890,$6041      ;7FD8: D3 EB 18 90 60 41 '....`A'
        FDB     $6BCB,$8547,$F149,$117D  ;7FDE: 6B CB 85 47 F1 49 11 7D 'k..G.I.}'
        FDB     $C9BC,$C9C3,$502B,$9425  ;7FE6: C9 BC C9 C3 50 2B 94 25 '....P+.%'
        FDB     $8BDA,$5A8A,$B5F3,$4488  ;7FEE: 8B DA 5A 8A B5 F3 44 88 '..Z...D.'
        FDB     $EEEF,$17C1,$81A6,$2A39  ;7FF6: EE EF 17 C1 81 A6 2A 39 '......*9'
        FDB     $DCC3                    ;7FFE: DC C3          '..'

        END
