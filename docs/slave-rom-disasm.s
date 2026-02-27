; f9dasm: M6800/1/2/3/8/9 / H6309 Binary/OS9/FLEX9 Disassembler V1.83
; Loaded binary file public/roms/secondary.bin

;****************************************************
;* Used Labels                                      *
;****************************************************

DDR1    EQU     $0000
DDR2    EQU     $0001
PORT1   EQU     $0002
PORT2   EQU     $0003
DDR3    EQU     $0004
DDR4    EQU     $0005
PORT3   EQU     $0006
PORT4   EQU     $0007
TCSR    EQU     $0008
FRC_H   EQU     $0009
OCR_H   EQU     $000B
ICR_H   EQU     $000D
P3CSR   EQU     $000F
RMCR    EQU     $0010
TRCSR   EQU     $0011
RDR     EQU     $0012
TDR     EQU     $0013
M0019   EQU     $0019
M001E   EQU     $001E
M0028   EQU     $0028
M002D   EQU     $002D
M0033   EQU     $0033
M0040   EQU     $0040
M004A   EQU     $004A
M0054   EQU     $0054
frc_ref EQU     $0080
cas0_mode EQU     $0081
fsk_byte EQU     $0082
bit_counter EQU     $0083
param1_hi EQU     $0084
param1_lo EQU     $0085
ctrl_state EQU     $0086
cas1_mode EQU     $0087
sci_vec_ram EQU     $0088
return_addr EQU     $0089
ring_write_ptr EQU     $008B
ring_read_ptr EQU     $008D
ring_count EQU     $008F
cmd_byte EQU     $0090
queued_cmd EQU     $0091
cmd_state EQU     $0092
crc_poly_hi EQU     $0093
crc_poly_lo EQU     $0094
crc_hi  EQU     $0095
crc_lo  EQU     $0096
icr_period_hi EQU     $0097
icr_config_hi EQU     $0099
icr_config_lo EQU     $009A
key_status EQU     $009B
access_key EQU     $009C
cas1_short_hi EQU     $009D
cas1_long_hi EQU     $009F
cas1_long_lo EQU     $00A0
fsk_thresh_hi EQU     $00A1
fsk_param3_hi EQU     $00A3
fsk_flags EQU     $00A5
cas0_1bit_ph2_hi EQU     $00A6
cas0_1bit_ph1_hi EQU     $00A8
cas0_0bit_hi EQU     $00AA
cas0_icr_adj_hi EQU     $00AC
leader_count EQU     $00AE
tape_pos_hi EQU     $00B0
tape_pos_lo EQU     $00B1
cas_status EQU     $00B4
cas1_leader_ct EQU     $00B5
cas1_trailer_ct EQU     $00B6
load_byte_ct EQU     $00B7
save_byte_ct_hi EQU     $00B8
icr_prev_hi EQU     $00BA
p46_state EQU     $00BE
save_mode_7b EQU     $00BF
M00E5   EQU     $00E5
M00FF   EQU     $00FF
M0100   EQU     $0100
M017A   EQU     $017A
M0200   EQU     $0200
M0258   EQU     $0258
M0266   EQU     $0266
M0271   EQU     $0271
M0640   EQU     $0640
M0A00   EQU     $0A00
M0AFF   EQU     $0AFF
M0FFA   EQU     $0FFA
M1179   EQU     $1179
M2710   EQU     $2710
M45FE   EQU     $45FE
M48FF   EQU     $48FF
M8CA0   EQU     $8CA0

;****************************************************
;* Program Code / Data Areas                        *
;****************************************************

        ORG     $F000

slave_reset: SEI                              ;F000: 0F             '.'     disable interrupts during init
        LDAA    #$21                     ;F001: 86 21          '.!'    P30=1 (motor off), P35=1
        STAA    PORT3                    ;F003: 97 06          '..'    write initial port 3
ZF005:  LDS     #M00FF                   ;F005: 8E 00 FF       '...'   stack at top of internal RAM
        JSR     ram_init                 ;F008: BD F1 55       '..U'   init RAM variables from table
        CLRB                             ;F00B: 5F             '_'     B=0 (cold boot flag)
ZF00C:  LDAA    #$FB                     ;F00C: 86 FB          '..'    P3DDR=FB: P32 is only input
        STAA    DDR3                     ;F00E: 97 04          '..'
        OIM     #$21,PORT3               ;F010: 72 21 06       'r!.'   P30=1, P35=1 (motor off)
        AIM     #$E7,PORT3               ;F013: 71 E7 06       'q..'   P33=0, P34=0
        LDAA    #$10                     ;F016: 86 10          '..'    P14=1 (output)
        STAA    PORT1                    ;F018: 97 02          '..'    Port 1 DDR: bits 0-5 output
        LDAA    #$3F                     ;F01A: 86 3F          '.?'
        STAA    DDR1                     ;F01C: 97 00          '..'
        LDAA    #$00                     ;F01E: 86 00          '..'    Port 4 all 0
        STAA    PORT4                    ;F020: 97 07          '..'
        LDAA    #$3E                     ;F022: 86 3E          '.>'    DDR4=3E: bits 1-5 output
        STAA    DDR4                     ;F024: 97 05          '..'
        LDAA    #$12                     ;F026: 86 12          '..'    Port 2=12: P21=1, P24=1
        STAA    PORT2                    ;F028: 97 03          '..'    DDR2=12: P21, P24 output
        LDAA    #$12                     ;F02A: 86 12          '..'
        STAA    DDR2                     ;F02C: 97 01          '..'
        LDAA    #$04                     ;F02E: 86 04          '..'    RMCR: baud rate select
        STAA    RMCR                     ;F030: 97 10          '..'    TCSR: OLVL=1
        LDAA    #$01                     ;F032: 86 01          '..'    TRCSR=1A: TE+RE (SCI on)
        STAA    TCSR                     ;F034: 97 08          '..'
        LDAA    #$1A                     ;F036: 86 1A          '..'
        STAA    TRCSR                    ;F038: 97 11          '..'
        TSTB                             ;F03A: 5D             ']'     test cold boot flag
        BNE     main_loop                ;F03B: 26 03          '&.'    nonzero: skip cold init
        JSR     cold_init                ;F03D: BD F4 B6       '...'   cold boot initialization
main_loop: CLRB                             ;F040: 5F             '_'     B=0 (clear error)
        AIM     #$EF,PORT3               ;F041: 71 EF 06       'q..'   P34=0 (slave flag clear)
        LDX     #main_loop               ;F044: CE F0 40       '..@'   save main_loop addr for recovery
        STX     return_addr              ;F047: DF 89          '..'
        LDAA    #$01                     ;F049: 86 01          '..'    TCSR: OLVL=1
        STAA    TCSR                     ;F04B: 97 08          '..'
        LDAA    #$1A                     ;F04D: 86 1A          '..'    TRCSR=1A: TE+RE
        STAA    TRCSR                    ;F04F: 97 11          '..'
        LDS     #M00FF                   ;F051: 8E 00 FF       '...'   reset stack
ZF054:  SEI                              ;F054: 0F             '.'     SEI
        TSTB                             ;F055: 5D             ']'     test B
        BNE     cmd_dispatch_done        ;F056: 26 33          '&3'    B!=0: skip SLP
        SLP                              ;F058: 1A             '.'     sleep until interrupt
cmd_dispatch: LDAA    TRCSR                    ;F059: 96 11          '..'    read TRCSR
        BPL     ZF054                    ;F05B: 2A F7          '*.'    RDRF not set: loop
        BITA    #$40                     ;F05D: 85 40          '.@'    test ORFE (overrun/framing)
        BNE     sci_error_exit           ;F05F: 26 3C          '&<'    error: sci_error_exit
        LDAA    RDR                      ;F061: 96 12          '..'    read command byte from RDR
ZF063:  CLR     >cmd_state               ;F063: 7F 00 92       '...'   clear command state
        STAA    cmd_byte                 ;F066: 97 90          '..'    save command byte
        TAB                              ;F068: 16             '.'     copy to B
        CMPA    #$90                     ;F069: 81 90          '..'    command >= 90?
        BCC     cmd_unknown              ;F06B: 24 29          '$)'    yes: unknown command
        ANDB    #$F0                     ;F06D: C4 F0          '..'    upper nibble mask
        LSRB                             ;F06F: 54             'T'     shift right 3x = nibble
        LSRB                             ;F070: 54             'T'
        LSRB                             ;F071: 54             'T'
        LDX     #grp_table               ;F072: CE F0 AA       '...'   group table base
        ABX                              ;F075: 3A             ':'     index into table
        TAB                              ;F076: 16             '.'     B = original command
        ANDB    #$0F                     ;F077: C4 0F          '..'    lower nibble
        LDX     ,X                       ;F079: EE 00          '..'    load sub-table pointer
        CMPB    ,X                       ;F07B: E1 00          '..'    compare with max valid
        BGT     cmd_unknown              ;F07D: 2E 17          '..'    too large: error
        ASLB                             ;F07F: 58             'X'     lower_nibble 
        ABX                              ;F080: 3A             ':'     index into sub-table
        CLC                              ;F081: 0C             '.'     clear carry (success default)
        LDX     $01,X                    ;F082: EE 01          '..'    load handler address
        JSR     ,X                       ;F084: AD 00          '..'    JSR to handler
        BCC     cmd_dispatch_done        ;F086: 24 03          '$.'    C=0: done
ZF088:  JSR     cmd_error_report         ;F088: BD F4 A2       '...'   C=1: error report
cmd_dispatch_done: CLRB                             ;F08B: 5F             '_'     clear B
        LDAA    cmd_state                ;F08C: 96 92          '..'    check command state
        CMPA    #$02                     ;F08E: 81 02          '..'    state 2 = queued command
        BNE     ZF054                    ;F090: 26 C2          '&.'    not 2: back to dispatch
        LDAA    queued_cmd               ;F092: 96 91          '..'    load queued command
        BRA     ZF063                    ;F094: 20 CD          ' .'    process queued command
cmd_unknown: LDAA    #$0F                     ;F096: 86 0F          '..'    unknown cmd: send 0F error
        JSR     sci_send_byte            ;F098: BD F1 4B       '..K'
        BRA     ZF088                    ;F09B: 20 EB          ' .'
sci_error_exit: SEI                              ;F09D: 0F             '.'     SEI
        LDAA    #$02                     ;F09E: 86 02          '..'    send 02 error code
        JSR     sci_send_byte            ;F0A0: BD F1 4B       '..K'
        LDD     TRCSR                    ;F0A3: DC 11          '..'    read+clear TRCSR+RDR
        LDAB    #$01                     ;F0A5: C6 01          '..'    B=1 (warm boot flag)
        JMP     ZF00C                    ;F0A7: 7E F0 0C       '~..'   restart from DDR3 init
grp_table: FDB     grp0_subtable            ;F0AA: F0 E9          '..'
        FDB     grp1_subtable            ;F0AC: F2 2E          '..'
        FDB     grp2_subtable            ;F0AE: F5 E2          '..'
        FDB     grp3_subtable            ;F0B0: F4 72          '.r'
        FDB     grp4_subtable            ;F0B2: F8 C9          '..'
        FDB     grp5_subtable            ;F0B4: F9 EB          '..'
        FDB     grp6_subtable            ;F0B6: FA 18          '..'
        FDB     grp7_subtable            ;F0B8: FA 39          '.9'
        FDB     grp8_subtable            ;F0BA: F1 E9          '..'
ram_init_table: FCC     "~"                      ;F0BC: 7E             '~'
        FCB     $F0                      ;F0BD: F0             '.'
        FCC     "@"                      ;F0BE: 40             '@'
        FCB     $00,$B5,$00,$B5,$00,$00  ;F0BF: 00 B5 00 B5 00 00 '......'
        FCB     $00,$00,$84,$08,$00,$00  ;F0C5: 00 00 84 08 00 00 '......'
        FCB     $08,$00,$07,$05,$00,$00  ;F0CB: 08 00 07 05 00 00 '......'
        FCB     $01                      ;F0D1: 01             '.'
        FCC     "9"                      ;F0D2: 39             '9'
        FCB     $00,$9C,$01,$D0,$00      ;F0D3: 00 9C 01 D0 00 '.....'
        FCC     "}"                      ;F0D8: 7D             '}'
        FCB     $00,$01                  ;F0D9: 00 01          '..'
        FCC     "9"                      ;F0DB: 39             '9'
        FCB     $01                      ;F0DC: 01             '.'
        FCC     "9"                      ;F0DD: 39             '9'
        FCB     $00,$9C,$01,$D0,$00      ;F0DE: 00 9C 01 D0 00 '.....'
        FCC     "}"                      ;F0E3: 7D             '}'
        FCB     $00,$00,$00,$00          ;F0E4: 00 00 00 00    '....'
MF0E8:  FCB     $00                      ;F0E8: 00             '.'
grp0_subtable: FCB     $0D                      ;F0E9: 0D             '.'
        FDB     send_ack,cmd_02_handler  ;F0EA: F1 48 F1 53    '.H.S'
        FDB     cmd_03_handler           ;F0EE: F1 6B          '.k'
        FDB     cmd_04_handler           ;F0F0: F1 70          '.p'
        FDB     cmd_05_handler           ;F0F2: F1 78          '.x'
        FDB     cmd_06_read_mem          ;F0F4: F1 7E          '.~'
        FDB     cmd_07_write_mem         ;F0F6: F1 92          '..'
        FDB     cmd_08_or_mem            ;F0F8: F1 98          '..'
        FDB     cmd_09_and_mem           ;F0FA: F1 A0          '..'
        FDB     cmd_0A_p35_low           ;F0FC: F1 BC          '..'
        FDB     cmd_0B_p35_high          ;F0FE: F1 C1          '..'
        FDB     cmd_0C_jump              ;F100: F1 C7          '..'
        FDB     sci_error_exit           ;F102: F0 9D          '..'
        FDB     cmd_0E_set_port3         ;F104: F1 D5          '..'
sci_transact_1: TAB                              ;F106: 16             '.'     send ACK first, then do transact_2
        BSR     send_ack                 ;F107: 8D 3F          '.?'
        TBA                              ;F109: 17             '.'
sci_transact_2: TAB                              ;F10A: 16             '.'     B = ACK value (from A)
ZF10B:  LDAA    TRCSR                    ;F10B: 96 11          '..'    wait RDRF
        BPL     ZF10B                    ;F10D: 2A FC          '*.'
        BITA    #$40                     ;F10F: 85 40          '.@'    check ORFE
        BNE     ZF126                    ;F111: 26 13          '&.'    error: sci_error_exit
        LDAA    RDR                      ;F113: 96 12          '..'    A = byte1 from RDR
ZF115:  TIM     #$20,TRCSR               ;F115: 7B 20 11       '{ .'   wait TDRE
        BEQ     ZF115                    ;F118: 27 FB          ''.'    not ready: loop
        STAB    TDR                      ;F11A: D7 13          '..'    send ACK #1
ZF11C:  TST     >TRCSR                   ;F11C: 7D 00 11       '}..'   check RDRF again
        BPL     ZF11C                    ;F11F: 2A FB          '*.'
        TIM     #$40,TRCSR               ;F121: 7B 40 11       '{@.'   check ORFE on 2nd byte
ZF124:  BEQ     ZF129                    ;F124: 27 03          ''.'    error: sci_error_exit
ZF126:  JMP     sci_error_exit           ;F126: 7E F0 9D       '~..'
ZF129:  STAB    TDR                      ;F129: D7 13          '..'    send ACK #2
        LDAB    RDR                      ;F12B: D6 12          '..'    B = byte2 from RDR
        RTS                              ;F12D: 39             '9'     return: A=byte1, B=byte2
sci_recv_byte: TST     >TRCSR                   ;F12E: 7D 00 11       '}..'   recv: wait RDRF, send A as ACK, return RDR
        BPL     sci_recv_byte            ;F131: 2A FB          '*.'
        TIM     #$40,TRCSR               ;F133: 7B 40 11       '{@.'
        BNE     ZF124                    ;F136: 26 EC          '&.'
        STAA    TDR                      ;F138: 97 13          '..'
        LDAA    RDR                      ;F13A: 96 12          '..'
        RTS                              ;F13C: 39             '9'
sci_recv_raw: LDAA    TRCSR                    ;F13D: 96 11          '..'    recv_raw: wait RDRF, return RDR (no ACK send)
        BPL     sci_recv_raw             ;F13F: 2A FC          '*.'
        BITA    #$40                     ;F141: 85 40          '.@'
        BNE     ZF124                    ;F143: 26 DF          '&.'
        LDAA    RDR                      ;F145: 96 12          '..'
        RTS                              ;F147: 39             '9'
send_ack: LDAA    #$01                     ;F148: 86 01          '..'    ACK = 01
ZF14A:  CLC                              ;F14A: 0C             '.'     CLC (no error)
sci_send_byte: TIM     #$20,TRCSR               ;F14B: 7B 20 11       '{ .'   wait TDRE
        BEQ     sci_send_byte            ;F14E: 27 FB          ''.'
        STAA    TDR                      ;F150: 97 13          '..'    send byte
        RTS                              ;F152: 39             '9'
cmd_02_handler: BSR     send_ack                 ;F153: 8D F3          '..'    cmd 0x02: ACK + reinit RAM
ram_init: LDD     #M002D                   ;F155: CC 00 2D       '..-'   init 2D RAM bytes from F0E8 table
        LDX     #MF0E8                   ;F158: CE F0 E8       '...'
ZF15B:  LDAA    ,X                       ;F15B: A6 00          '..'
        DEX                              ;F15D: 09             '.'
        PSHX                             ;F15E: 3C             '<'
        PSHA                             ;F15F: 36             '6'
        CLRA                             ;F160: 4F             'O'
        XGDX                             ;F161: 18             '.'
        PULA                             ;F162: 32             '2'
        STAA    $87,X                    ;F163: A7 87          '..'
        XGDX                             ;F165: 18             '.'
        PULX                             ;F166: 38             '8'
        DECB                             ;F167: 5A             'Z'
        BNE     ZF15B                    ;F168: 26 F1          '&.'
        RTS                              ;F16A: 39             '9'
cmd_03_handler: BSR     send_ack                 ;F16B: 8D DB          '..'    cmd 0x03: ACK + full reset (stack + ram_init)
        JMP     ZF005                    ;F16D: 7E F0 05       '~..'
cmd_04_handler: BSR     send_ack                 ;F170: 8D D6          '..'    cmd 0x04: ACK + set access_key=01
        LDAA    #$01                     ;F172: 86 01          '..'
        BSR     sci_recv_byte            ;F174: 8D B8          '..'
        BRA     ZF17B                    ;F176: 20 03          ' .'
cmd_05_handler: BSR     send_ack                 ;F178: 8D CE          '..'    cmd 0x05: ACK + clear access_key
        CLRA                             ;F17A: 4F             'O'
ZF17B:  STAA    access_key               ;F17B: 97 9C          '..'
        RTS                              ;F17D: 39             '9'
cmd_06_read_mem: LDAA    access_key               ;F17E: 96 9C          '..'    cmd 0x06: read [addr] if key=AA
        CMPA    #$AA                     ;F180: 81 AA          '..'
        BNE     cmd_error_0f             ;F182: 26 5F          '&_'
        BSR     send_ack                 ;F184: 8D C2          '..'
        BSR     sci_recv_byte            ;F186: 8D A6          '..'
        PSHA                             ;F188: 36             '6'
        BSR     sci_recv_raw             ;F189: 8D B2          '..'
        TAB                              ;F18B: 16             '.'
        PULA                             ;F18C: 32             '2'
        XGDX                             ;F18D: 18             '.'
        LDAA    ,X                       ;F18E: A6 00          '..'
        BRA     ZF14A                    ;F190: 20 B8          ' .'
cmd_07_write_mem: BSR     cmd_helper_check_aa      ;F192: 8D 15          '..'    cmd 0x07: write A to [addr] if key=AA
        BCS     cmd_error_0f             ;F194: 25 4D          '%M'
        BRA     ZF1A6                    ;F196: 20 0E          ' .'
cmd_08_or_mem: BSR     cmd_helper_check_aa      ;F198: 8D 0F          '..'    cmd 0x08: OR A into [addr] if key=AA
        BCS     cmd_error_0f             ;F19A: 25 47          '%G'
        ORAA    ,X                       ;F19C: AA 00          '..'
        BRA     ZF1A6                    ;F19E: 20 06          ' .'
cmd_09_and_mem: BSR     cmd_helper_check_aa      ;F1A0: 8D 07          '..'    cmd 0x09: AND A into [addr] if key=AA
        BCS     cmd_error_0f             ;F1A2: 25 3F          '%?'
        ANDA    ,X                       ;F1A4: A4 00          '..'
ZF1A6:  STAA    ,X                       ;F1A6: A7 00          '..'
        RTS                              ;F1A8: 39             '9'
cmd_helper_check_aa: LDAA    access_key               ;F1A9: 96 9C          '..'    check access_key==AA; if so, recv addr+data
        CMPA    #$AA                     ;F1AB: 81 AA          '..'
        SEC                              ;F1AD: 0D             '.'
        BNE     ZF1BB                    ;F1AE: 26 0B          '&.'
        LDAA    #$01                     ;F1B0: 86 01          '..'
        JSR     sci_transact_1           ;F1B2: BD F1 06       '...'
        XGDX                             ;F1B5: 18             '.'
        LDAA    #$01                     ;F1B6: 86 01          '..'
        JSR     sci_recv_byte            ;F1B8: BD F1 2E       '...'
ZF1BB:  RTS                              ;F1BB: 39             '9'
cmd_0A_p35_low: AIM     #$DF,PORT3               ;F1BC: 71 DF 06       'q..'   cmd 0x0A: P35=low (AIM &DF on PORT3)
        BRA     ZF1C4                    ;F1BF: 20 03          ' .'
cmd_0B_p35_high: OIM     #$20,PORT3               ;F1C1: 72 20 06       'r .'   cmd 0x0B: P35=high (OIM $20 on PORT3)
ZF1C4:  JMP     send_ack                 ;F1C4: 7E F1 48       '~.H'
cmd_0C_jump: LDAA    access_key               ;F1C7: 96 9C          '..'    cmd 0x0C: jump to addr (if key=AA)
        CMPA    #$AA                     ;F1C9: 81 AA          '..'
        BNE     cmd_error_0f             ;F1CB: 26 16          '&.'
        LDAA    #$01                     ;F1CD: 86 01          '..'
        JSR     sci_transact_1           ;F1CF: BD F1 06       '...'
        XGDX                             ;F1D2: 18             '.'
        JMP     ,X                       ;F1D3: 6E 00          'n.'
cmd_0E_set_port3: JSR     send_ack                 ;F1D5: BD F1 48       '..H'   cmd 0x0E: set PORT3=E1 (if key=AA)
        JSR     sci_recv_raw             ;F1D8: BD F1 3D       '..='
        CMPA    #$AA                     ;F1DB: 81 AA          '..'
        BNE     cmd_error_0f             ;F1DD: 26 04          '&.'
        LDAA    #$E1                     ;F1DF: 86 E1          '..'
        STAA    PORT3                    ;F1E1: 97 06          '..'
cmd_error_0f: LDAA    #$0F                     ;F1E3: 86 0F          '..'
        SEC                              ;F1E5: 0D             '.'
        JMP     sci_send_byte            ;F1E6: 7E F1 4B       '~.K'
grp8_subtable: FCB     $01                      ;F1E9: 01             '.'
        FDB     cmd_80_read_port         ;F1EA: F2 13          '..'
        FDB     cmd_81_write_port        ;F1EC: F1 EE          '..'
cmd_81_write_port: JSR     cmd_helper_check_aa      ;F1EE: BD F1 A9       '...'   cmd 0x81: write masked bits to port
        BCS     cmd_error_jmp            ;F1F1: 25 1D          '%.'
        STX     frc_ref                  ;F1F3: DF 80          '..'
        STAA    fsk_byte                 ;F1F5: 97 82          '..'
ZF1F7:  LDX     frc_ref                  ;F1F7: DE 80          '..'    loop: read port, mask, write to target
        CLRA                             ;F1F9: 4F             'O'
        TIM     #$01,PORT4               ;F1FA: 7B 01 07       '{..'
        BEQ     ZF200                    ;F1FD: 27 01          ''.'
        DECA                             ;F1FF: 4A             'J'
ZF200:  ANDA    fsk_byte                 ;F200: 94 82          '..'
        LDAB    fsk_byte                 ;F202: D6 82          '..'
        COMB                             ;F204: 53             'S'
        ANDB    ,X                       ;F205: E4 00          '..'
        ABA                              ;F207: 1B             '.'
        STAA    ,X                       ;F208: A7 00          '..'
        LDAA    TRCSR                    ;F20A: 96 11          '..'    check RDRF: new cmd ends loop
        BPL     ZF1F7                    ;F20C: 2A E9          '*.'
        CLRA                             ;F20E: 4F             'O'
        RTS                              ;F20F: 39             '9'
cmd_error_jmp: JMP     cmd_error_0f             ;F210: 7E F1 E3       '~..'
cmd_80_read_port: JSR     cmd_helper_check_aa      ;F213: BD F1 A9       '...'   cmd 0x80: read port bit, output to P34
        BCS     cmd_error_jmp            ;F216: 25 F8          '%.'
        STAA    bit_counter              ;F218: 97 83          '..'
ZF21A:  LDAA    ,X                       ;F21A: A6 00          '..'    loop: test bit, set/clear P34 accordingly
        ANDA    bit_counter              ;F21C: 94 83          '..'
        BEQ     ZF225                    ;F21E: 27 05          ''.'
        OIM     #$10,PORT3               ;F220: 72 10 06       'r..'
        BRA     ZF228                    ;F223: 20 03          ' .'
ZF225:  AIM     #$EF,PORT3               ;F225: 71 EF 06       'q..'
ZF228:  LDAA    TRCSR                    ;F228: 96 11          '..'    check RDRF: new cmd ends loop
        BPL     ZF21A                    ;F22A: 2A EE          '*.'
        CLRA                             ;F22C: 4F             'O'
        RTS                              ;F22D: 39             '9'
grp1_subtable: FCB     $02                      ;F22E: 02             '.'
        FDB     cmd_10_print_data        ;F22F: F2 60          '.`'
        FDB     cmd_10_print_data        ;F231: F2 60          '.`'
        FDB     cmd_12_timed_pulse       ;F233: F2 35          '.5'
cmd_12_timed_pulse: JSR     send_ack                 ;F235: BD F1 48       '..H'   cmd 0x12: timed pulse train on PORT1
        BSR     check_b4_p44             ;F238: 8D 1D          '..'
        LDX     #PORT1                   ;F23A: CE 00 02       '...'
        CLRA                             ;F23D: 4F             'O'
        STAA    PORT1                    ;F23E: 97 02          '..'
ZF240:  LDAA    TCSR                     ;F240: 96 08          '..'    arm OCR with period=$8CA0
        LDD     FRC_H                    ;F242: DC 09          '..'
        ADDD    #M8CA0                   ;F244: C3 8C A0       '...'
        STD     OCR_H                    ;F247: DD 0B          '..'
ZF249:  TIM     #$40,TCSR                ;F249: 7B 40 08       '{@.'
        BEQ     ZF249                    ;F24C: 27 FB          ''.'
        DEX                              ;F24E: 09             '.'
        BNE     ZF240                    ;F24F: 26 EF          '&.'
        LDAA    #$10                     ;F251: 86 10          '..'
        STAA    PORT1                    ;F253: 97 02          '..'
        CLC                              ;F255: 0C             '.'
        RTS                              ;F256: 39             '9'
check_b4_p44: TST     >cas_status              ;F257: 7D 00 B4       '}..'
        BPL     ZF25F                    ;F25A: 2A 03          '*.'
        AIM     #$FB,PORT4               ;F25C: 71 FB 07       'q..'
ZF25F:  RTS                              ;F25F: 39             '9'
cmd_10_print_data: CLR     >ctrl_state              ;F260: 7F 00 86       '...'   cmd 0x10: serial print data output
        BSR     check_b4_p44             ;F263: 8D F2          '..'
ZF265:  TAB                              ;F265: 16             '.'     parse sub-command nibbles
        ANDB    #$0F                     ;F266: C4 0F          '..'
        ANDA    #$F0                     ;F268: 84 F0          '..'
        CMPA    #$10                     ;F26A: 81 10          '..'
        CLC                              ;F26C: 0C             '.'
        BNE     ZF2DA                    ;F26D: 26 6B          '&k'
        CMPB    #$02                     ;F26F: C1 02          '..'
        BPL     ZF2D4                    ;F271: 2A 61          '*a'
        LDAA    #$01                     ;F273: 86 01          '..'    sub-cmd 0x10: print mode, ACK, init buf
        STAA    TDR                      ;F275: 97 13          '..'
        LDAA    #$01                     ;F277: 86 01          '..'
        STAA    cmd_state                ;F279: 97 92          '..'
        JSR     ring_buf_init            ;F27B: BD F3 F2       '...'
        TSTB                             ;F27E: 5D             ']'
        BNE     ZF2B5                    ;F27F: 26 34          '&4'
        OIM     #$FF,ctrl_state          ;F281: 72 FF 86       'r..'
ZF284:  LDAA    cmd_state                ;F284: 96 92          '..'
        CMPA    #$02                     ;F286: 81 02          '..'
        BPL     ZF2D9                    ;F288: 2A 4F          '*O'
        JSR     cmd_state_handler        ;F28A: BD F3 FD       '...'
        LDAA    ring_count               ;F28D: 96 8F          '..'
        CMPA    #$18                     ;F28F: 81 18          '..'
        BMI     ZF284                    ;F291: 2B F1          '+.'
        BSR     port1_edge_init          ;F293: 8D 5F          '._'    init Port 1 edge timing for FSK
        BMI     ZF2D9                    ;F295: 2B 42          '+B'
        BSR     cmd_helper_reset_modes   ;F297: 8D 6C          '.l'
        BMI     ZF2D9                    ;F299: 2B 3E          '+>'
ZF29B:  JSR     printer_output_data      ;F29B: BD F3 87       '...'
        BMI     ZF2D9                    ;F29E: 2B 39          '+9'
        LDAA    ring_count               ;F2A0: 96 8F          '..'
        CMPA    #$18                     ;F2A2: 81 18          '..'
        BPL     ZF29B                    ;F2A4: 2A F5          '*.'
ZF2A6:  LDAA    cmd_state                ;F2A6: 96 92          '..'
        CLC                              ;F2A8: 0C             '.'
        BEQ     ZF2DA                    ;F2A9: 27 2F          ''/'
        CMPA    #$02                     ;F2AB: 81 02          '..'
        BNE     ZF2D4                    ;F2AD: 26 25          '&%'
        LDAA    queued_cmd               ;F2AF: 96 91          '..'
        STAA    cmd_byte                 ;F2B1: 97 90          '..'
        BRA     ZF265                    ;F2B3: 20 B0          ' .'
ZF2B5:  BSR     port1_edge_init          ;F2B5: 8D 3D          '.='
        BMI     ZF2D9                    ;F2B7: 2B 20          '+ '
ZF2B9:  JSR     ring_buf_read            ;F2B9: BD F4 55       '..U'
        BCS     ZF2A6                    ;F2BC: 25 E8          '%.'
        ADDA    ctrl_state               ;F2BE: 9B 86          '..'
        CLR     >ctrl_state              ;F2C0: 7F 00 86       '...'
        TAB                              ;F2C3: 16             '.'
        BEQ     ZF2B9                    ;F2C4: 27 F3          ''.'
ZF2C6:  BSR     cmd_helper_reset_modes   ;F2C6: 8D 3D          '.='
        BMI     ZF2D9                    ;F2C8: 2B 0F          '+.'
        TIM     #$40,TRCSR               ;F2CA: 7B 40 11       '{@.'
        BNE     ZF2F1                    ;F2CD: 26 22          '&"'
        DECB                             ;F2CF: 5A             'Z'
        BNE     ZF2C6                    ;F2D0: 26 F4          '&.'
        BRA     ZF2B9                    ;F2D2: 20 E5          ' .'
ZF2D4:  LDAA    #$1F                     ;F2D4: 86 1F          '..'
        JSR     sci_send_byte            ;F2D6: BD F1 4B       '..K'
ZF2D9:  SEC                              ;F2D9: 0D             '.'
ZF2DA:  LDAA    #$10                     ;F2DA: 86 10          '..'
        STAA    PORT1                    ;F2DC: 97 02          '..'
        OIM     #$02,PORT4               ;F2DE: 72 02 07       'r..'
        LDD     FRC_H                    ;F2E1: DC 09          '..'
        TIM     #$FF,TCSR                ;F2E3: 7B FF 08       '{..'
        STD     OCR_H                    ;F2E6: DD 0B          '..'
ZF2E8:  TIM     #$40,TCSR                ;F2E8: 7B 40 08       '{@.'
        BEQ     ZF2E8                    ;F2EB: 27 FB          ''.'
        AIM     #$FD,PORT4               ;F2ED: 71 FD 07       'q..'
        RTS                              ;F2F0: 39             '9'
ZF2F1:  JMP     sci_error_exit           ;F2F1: 7E F0 9D       '~..'
port1_edge_init: CLRA                             ;F2F4: 4F             'O'     init Port1 for edge-based data output
        STAA    frc_ref                  ;F2F5: 97 80          '..'
        STAA    PORT1                    ;F2F7: 97 02          '..'
        LDAB    #$5F                     ;F2F9: C6 5F          '._'
        STAB    cas0_mode                ;F2FB: D7 81          '..'
ZF2FD:  JSR     cmd_state_handler        ;F2FD: BD F3 FD       '...'
        BSR     ZF30C                    ;F300: 8D 0A          '..'
        BEQ     ZF2FD                    ;F302: 27 F9          ''.'
        RTS                              ;F304: 39             '9'
cmd_helper_reset_modes: PSHB                             ;F305: 37             '7'     reset cas0_mode=0, cas1_mode=1
        CLRB                             ;F306: 5F             '_'
        STAB    cas0_mode                ;F307: D7 81          '..'
        INCB                             ;F309: 5C             '\'
        BRA     ZF30E                    ;F30A: 20 02          ' .'
ZF30C:  PSHB                             ;F30C: 37             '7'
ZF30D:  CLRB                             ;F30D: 5F             '_'
ZF30E:  STAB    cas1_mode                ;F30E: D7 87          '..'
        LDAA    #$07                     ;F310: 86 07          '..'
        STAA    fsk_byte                 ;F312: 97 82          '..'
ZF314:  TIM     #$40,TCSR                ;F314: 7B 40 08       '{@.'
        BEQ     ZF323                    ;F317: 27 0A          ''.'
        OIM     #$00,OCR_H               ;F319: 72 00 0B       'r..'
        LDAA    #$80                     ;F31C: 86 80          '..'
        DEC     >fsk_byte                ;F31E: 7A 00 82       'z..'
        BEQ     ZF384                    ;F321: 27 61          ''a'
ZF323:  LDAA    PORT1                    ;F323: 96 02          '..'
        CMPA    PORT1                    ;F325: 91 02          '..'
        BNE     ZF323                    ;F327: 26 FA          '&.'
        TAB                              ;F329: 16             '.'
        TST     >cas1_mode               ;F32A: 7D 00 87       '}..'
        BEQ     ZF344                    ;F32D: 27 15          ''.'
        BMI     ZF35E                    ;F32F: 2B 2D          '+-'
        BITA    #$40                     ;F331: 85 40          '.@'
        BNE     ZF344                    ;F333: 26 0F          '&.'
        LDAB    #$05                     ;F335: C6 05          '..'
ZF337:  DECB                             ;F337: 5A             'Z'
        BNE     ZF337                    ;F338: 26 FD          '&.'
        LDAB    PORT1                    ;F33A: D6 02          '..'
        BITB    #$40                     ;F33C: C5 40          '.@'
        BNE     ZF343                    ;F33E: 26 03          '&.'
        OIM     #$FF,cas1_mode           ;F340: 72 FF 87       'r..'
ZF343:  TBA                              ;F343: 17             '.'
ZF344:  EORA    frc_ref                  ;F344: 98 80          '..'
        STAB    frc_ref                  ;F346: D7 80          '..'
        TSTA                             ;F348: 4D             'M'
        BPL     ZF314                    ;F349: 2A C9          '*.'
        LDAA    TCSR                     ;F34B: 96 08          '..'
        LDD     FRC_H                    ;F34D: DC 09          '..'
        STD     OCR_H                    ;F34F: DD 0B          '..'
        LDAB    cas1_mode                ;F351: D6 87          '..'
        BEQ     ZF37A                    ;F353: 27 25          ''%'
        DEC     >cas0_mode               ;F355: 7A 00 81       'z..'
        BNE     ZF314                    ;F358: 26 BA          '&.'
        LDAA    #$80                     ;F35A: 86 80          '..'
        PULB                             ;F35C: 33             '3'
        RTS                              ;F35D: 39             '9'
ZF35E:  BITA    #$40                     ;F35E: 85 40          '.@'
        BEQ     ZF344                    ;F360: 27 E2          ''.'
        LDAB    #$05                     ;F362: C6 05          '..'
ZF364:  DECB                             ;F364: 5A             'Z'
        BNE     ZF364                    ;F365: 26 FD          '&.'
        LDAB    PORT1                    ;F367: D6 02          '..'
        BITB    #$40                     ;F369: C5 40          '.@'
        BEQ     ZF343                    ;F36B: 27 D6          ''.'
        LDAA    #$01                     ;F36D: 86 01          '..'
        STAA    cas0_mode                ;F36F: 97 81          '..'
        LDD     FRC_H                    ;F371: DC 09          '..'
        SUBD    OCR_H                    ;F373: 93 0B          '..'
        SUBD    #cas1_long_lo            ;F375: 83 00 A0       '...'
        BCC     ZF30D                    ;F378: 24 93          '$.'
ZF37A:  CLRA                             ;F37A: 4F             'O'
        DEC     >cas0_mode               ;F37B: 7A 00 81       'z..'
        BNE     ZF384                    ;F37E: 26 04          '&.'
        OIM     #$FC,cas0_mode           ;F380: 72 FC 81       'r..'
        INCA                             ;F383: 4C             'L'
ZF384:  TSTA                             ;F384: 4D             'M'
        PULB                             ;F385: 33             '3'
        RTS                              ;F386: 39             '9'
printer_output_data: LDAA    ring_count               ;F387: 96 8F          '..'    output buffered data to Port 1 serially
        CMPA    #$18                     ;F389: 81 18          '..'
        BMI     ZF3EB                    ;F38B: 2B 5E          '+^'
        LDX     ring_read_ptr            ;F38D: DE 8D          '..'
        LDAA    #$06                     ;F38F: 86 06          '..'
        STAA    bit_counter              ;F391: 97 83          '..'
ZF393:  LDAA    #$06                     ;F393: 86 06          '..'    6 columns of display data
        STAA    param1_lo                ;F395: 97 85          '..'
ZF397:  LSR     ,X                       ;F397: 64 00          'd.'    shift 4 rows of 6-byte blocks LSR
        ROLB                             ;F399: 59             'Y'
        LSR     $06,X                    ;F39A: 64 06          'd.'
        ROLB                             ;F39C: 59             'Y'
        LSR     $0C,X                    ;F39D: 64 0C          'd.'
        ROLB                             ;F39F: 59             'Y'
        LSR     $12,X                    ;F3A0: 64 12          'd.'
        ROLB                             ;F3A2: 59             'Y'
        LDAA    #$08                     ;F3A3: 86 08          '..'
        STAA    param1_hi                ;F3A5: 97 84          '..'
ZF3A7:  JSR     ZF30C                    ;F3A7: BD F3 0C       '...'   wait for edge, output bit to PORT1
        BMI     ZF3EA                    ;F3AA: 2B 3E          '+>'
        TBA                              ;F3AC: 17             '.'
        ANDA    param1_hi                ;F3AD: 94 84          '..'
        STAA    PORT1                    ;F3AF: 97 02          '..'
        BSR     cmd_state_handler        ;F3B1: 8D 4A          '.J'
        LSR     >param1_hi               ;F3B3: 74 00 84       't..'
        BNE     ZF3A7                    ;F3B6: 26 EF          '&.'
        DEC     >param1_lo               ;F3B8: 7A 00 85       'z..'
        BNE     ZF397                    ;F3BB: 26 DA          '&.'
        INX                              ;F3BD: 08             '.'
        DEC     >bit_counter             ;F3BE: 7A 00 83       'z..'
        BNE     ZF393                    ;F3C1: 26 D0          '&.'
        LDAA    ring_count               ;F3C3: 96 8F          '..'
        SUBA    #$18                     ;F3C5: 80 18          '..'
        STAA    ring_count               ;F3C7: 97 8F          '..'
        LDX     ring_read_ptr            ;F3C9: DE 8D          '..'
        LDAB    #$18                     ;F3CB: C6 18          '..'
        ABX                              ;F3CD: 3A             ':'
        CPX     #M00E5                   ;F3CE: 8C 00 E5       '...'
        BMI     ZF3D6                    ;F3D1: 2B 03          '+.'
        LDX     #cas1_leader_ct          ;F3D3: CE 00 B5       '...'
ZF3D6:  STX     ring_read_ptr            ;F3D6: DF 8D          '..'
        JSR     ZF30C                    ;F3D8: BD F3 0C       '...'
        BMI     ZF3EA                    ;F3DB: 2B 0D          '+.'
        CLRA                             ;F3DD: 4F             'O'
        STAA    PORT1                    ;F3DE: 97 02          '..'
ZF3E0:  BSR     cmd_state_handler        ;F3E0: 8D 1B          '..'
        JSR     ZF30C                    ;F3E2: BD F3 0C       '...'
        BMI     ZF3EA                    ;F3E5: 2B 03          '+.'
        BEQ     ZF3E0                    ;F3E7: 27 F7          ''.'
        CLRA                             ;F3E9: 4F             'O'
ZF3EA:  RTS                              ;F3EA: 39             '9'
ZF3EB:  LDAA    #$10                     ;F3EB: 86 10          '..'
        STAA    PORT1                    ;F3ED: 97 02          '..'
        LDAA    #$E0                     ;F3EF: 86 E0          '..'
        RTS                              ;F3F1: 39             '9'
ring_buf_init: LDX     #cas1_leader_ct          ;F3F2: CE 00 B5       '...'   init ring buffer ptrs at $B5
        STX     ring_write_ptr           ;F3F5: DF 8B          '..'
        STX     ring_read_ptr            ;F3F7: DF 8D          '..'
        CLRA                             ;F3F9: 4F             'O'
        STAA    ring_count               ;F3FA: 97 8F          '..'
        RTS                              ;F3FC: 39             '9'
cmd_state_handler: LDAA    cmd_state                ;F3FD: 96 92          '..'    handle cmd_state: queue or process next byte
        BEQ     ZF433                    ;F3FF: 27 32          ''2'
        CMPA    #$02                     ;F401: 81 02          '..'
        BEQ     ZF431                    ;F403: 27 2C          '','
        LDAA    #$2F                     ;F405: 86 2F          './'
        CMPA    ring_count               ;F407: 91 8F          '..'
        BMI     ZF431                    ;F409: 2B 26          '+&'
        LDAA    TRCSR                    ;F40B: 96 11          '..'
        BPL     ZF431                    ;F40D: 2A 22          '*"'
        BITA    #$40                     ;F40F: 85 40          '.@'
        BNE     ZF452                    ;F411: 26 3F          '&?'
        LDAA    #$01                     ;F413: 86 01          '..'
        STAA    TDR                      ;F415: 97 13          '..'
        LDAA    RDR                      ;F417: 96 12          '..'
        PSHX                             ;F419: 3C             '<'
        LDX     ring_write_ptr           ;F41A: DE 8B          '..'
        STAA    ,X                       ;F41C: A7 00          '..'
        INX                              ;F41E: 08             '.'
        INC     >ring_count              ;F41F: 7C 00 8F       '|..'
        CPX     #M00E5                   ;F422: 8C 00 E5       '...'
        BNE     ZF42A                    ;F425: 26 03          '&.'
        LDX     #cas1_leader_ct          ;F427: CE 00 B5       '...'
ZF42A:  STX     ring_write_ptr           ;F42A: DF 8B          '..'
        PULX                             ;F42C: 38             '8'
        CLRA                             ;F42D: 4F             'O'
        STAA    cmd_state                ;F42E: 97 92          '..'
        RTS                              ;F430: 39             '9'
ZF431:  SEC                              ;F431: 0D             '.'
        RTS                              ;F432: 39             '9'
ZF433:  LDAA    TRCSR                    ;F433: 96 11          '..'
        BPL     ZF431                    ;F435: 2A FA          '*.'
        BITA    #$40                     ;F437: 85 40          '.@'
        BNE     ZF452                    ;F439: 26 17          '&.'
        LDAA    RDR                      ;F43B: 96 12          '..'
        CMPA    cmd_byte                 ;F43D: 91 90          '..'
        BNE     ZF44A                    ;F43F: 26 09          '&.'
        LDAA    #$01                     ;F441: 86 01          '..'
        STAA    TDR                      ;F443: 97 13          '..'
        INC     >cmd_state               ;F445: 7C 00 92       '|..'
        CLRA                             ;F448: 4F             'O'
        RTS                              ;F449: 39             '9'
ZF44A:  STAA    queued_cmd               ;F44A: 97 91          '..'
        LDAA    #$02                     ;F44C: 86 02          '..'
        STAA    cmd_state                ;F44E: 97 92          '..'
        CLRA                             ;F450: 4F             'O'
        RTS                              ;F451: 39             '9'
ZF452:  JMP     sci_error_exit           ;F452: 7E F0 9D       '~..'
ring_buf_read: PSHB                             ;F455: 37             '7'     read one byte from ring buffer
        LDAB    ring_count               ;F456: D6 8F          '..'
        SEC                              ;F458: 0D             '.'
        BEQ     ZF470                    ;F459: 27 15          ''.'
        PSHX                             ;F45B: 3C             '<'
        LDX     ring_read_ptr            ;F45C: DE 8D          '..'
        LDAA    ,X                       ;F45E: A6 00          '..'
        DECB                             ;F460: 5A             'Z'
        STAB    ring_count               ;F461: D7 8F          '..'
        INX                              ;F463: 08             '.'
        CPX     #M00E5                   ;F464: 8C 00 E5       '...'
        BNE     ZF46C                    ;F467: 26 03          '&.'
        LDX     #cas1_leader_ct          ;F469: CE 00 B5       '...'
ZF46C:  STX     ring_read_ptr            ;F46C: DF 8D          '..'
        PULX                             ;F46E: 38             '8'
        CLC                              ;F46F: 0C             '.'
ZF470:  PULB                             ;F470: 33             '3'
        RTS                              ;F471: 39             '9'
grp3_subtable: FCB     $05                      ;F472: 05             '.'
        FDB     grp3_cmd_30,grp3_cmd_31  ;F473: F4 BE F4 7F    '....'
        FDB     grp3_cmd_32,grp3_cmd_33  ;F477: F4 8C F4 97    '....'
        FDB     grp3_cmd_34,grp3_cmd_35  ;F47B: F5 A0 F5 C1    '....'
grp3_cmd_31: LDAA    #$31                     ;F47F: 86 31          '.1'    cmd 0x31: set printer params (4-byte transact)
        JSR     sci_transact_1           ;F481: BD F1 06       '...'
        XGDX                             ;F484: 18             '.'
        LDAA    #$31                     ;F485: 86 31          '.1'
        JSR     sci_transact_2           ;F487: BD F1 0A       '...'
        BRA     printer_timed_send       ;F48A: 20 48          ' H'
grp3_cmd_32: JSR     send_ack                 ;F48C: BD F1 48       '..H'   cmd 0x32: print error report
        LDX     print_err_ptr            ;F48F: FE F5 3A       '..:'
        LDD     #M0040                   ;F492: CC 00 40       '..@'
        BRA     printer_timed_send       ;F495: 20 3D          ' ='
grp3_cmd_33: JSR     send_ack                 ;F497: BD F1 48       '..H'   cmd 0x33: print init string
        LDX     print_init_ptr           ;F49A: FE F5 56       '..V'
ZF49D:  LDD     #M0A00                   ;F49D: CC 0A 00       '...'
        BRA     printer_timed_send       ;F4A0: 20 32          ' 2'
cmd_error_report: LDX     print_err_ptr            ;F4A2: FE F5 3A       '..:'   error report: lookup table + timed send
        BRA     ZF49D                    ;F4A5: 20 F6          ' .'
ZF4A7:  LDX     print_timeout_ptr        ;F4A7: FE F5 48       '..H'
        BRA     ZF49D                    ;F4AA: 20 F1          ' .'
ZF4AC:  LDX     print_serial_ptr         ;F4AC: FE F5 64       '..d'
        BRA     ZF49D                    ;F4AF: 20 EC          ' .'
        LDX     print_err2_ptr           ;F4B1: FE F5 3E       '..>'
        BRA     ZF49D                    ;F4B4: 20 E7          ' .'
cold_init: LDX     print_init_ptr           ;F4B6: FE F5 56       '..V'   cold init: print init string at baud=256
        LDD     #M0100                   ;F4B9: CC 01 00       '...'
        BRA     printer_timed_send       ;F4BC: 20 16          ' .'
grp3_cmd_30: LDAA    #$32                     ;F4BE: 86 32          '.2'    cmd 0x30: set baud rate (table lookup)
        JSR     sci_transact_1           ;F4C0: BD F1 06       '...'
        PSHB                             ;F4C3: 37             '7'
        TAB                              ;F4C4: 16             '.'
        CMPB    #$39                     ;F4C5: C1 39          '.9'
        BCS     ZF4CA                    ;F4C7: 25 01          '%.'
        CLRB                             ;F4C9: 5F             '_'
ZF4CA:  CLRA                             ;F4CA: 4F             'O'
        ASLD                             ;F4CB: 05             '.'
        ADDD    #printer_config_table    ;F4CC: C3 F5 2E       '...'
        XGDX                             ;F4CF: 18             '.'
        LDX     ,X                       ;F4D0: EE 00          '..'
        CLRB                             ;F4D2: 5F             '_'
        PULA                             ;F4D3: 32             '2'
printer_timed_send: STD     frc_ref                  ;F4D4: DD 80          '..'    timed character send loop
        BEQ     ZF50C                    ;F4D6: 27 34          ''4'
        XGDX                             ;F4D8: 18             '.'
        STD     ctrl_state               ;F4D9: DD 86          '..'
        SUBD    #M0040                   ;F4DB: 83 00 40       '..@'
        BCS     ZF511                    ;F4DE: 25 31          '%1'
        CLR     >fsk_byte                ;F4E0: 7F 00 82       '...'
        LDAA    TCSR                     ;F4E3: 96 08          '..'
        LDD     FRC_H                    ;F4E5: DC 09          '..'
        STD     OCR_H                    ;F4E7: DD 0B          '..'
        BRA     ZF4F0                    ;F4E9: 20 05          ' .'
ZF4EB:  TIM     #$40,TCSR                ;F4EB: 7B 40 08       '{@.'
        BEQ     ZF4EB                    ;F4EE: 27 FB          ''.'
ZF4F0:  EIM     #$20,PORT1               ;F4F0: 75 20 02       'u .'
        TIM     #$40,TRCSR               ;F4F3: 7B 40 11       '{@.'
        BNE     ZF52B                    ;F4F6: 26 33          '&3'
        LDD     OCR_H                    ;F4F8: DC 0B          '..'
        ADDD    ctrl_state               ;F4FA: D3 86          '..'
        STD     OCR_H                    ;F4FC: DD 0B          '..'
        LDD     cas0_mode                ;F4FE: DC 81          '..'
        SUBD    ctrl_state               ;F500: 93 86          '..'
        STD     cas0_mode                ;F502: DD 81          '..'
        LDAA    frc_ref                  ;F504: 96 80          '..'
        SBCA    #$00                     ;F506: 82 00          '..'
        STAA    frc_ref                  ;F508: 97 80          '..'
        BCC     ZF4EB                    ;F50A: 24 DF          '$.'
ZF50C:  AIM     #$DF,PORT1               ;F50C: 71 DF 02       'q..'
        CLC                              ;F50F: 0C             '.'
        RTS                              ;F510: 39             '9'
ZF511:  LDAA    TCSR                     ;F511: 96 08          '..'
        LDD     FRC_H                    ;F513: DC 09          '..'
ZF515:  ADDD    #M0100                   ;F515: C3 01 00       '...'
        STD     OCR_H                    ;F518: DD 0B          '..'
ZF51A:  TIM     #$40,TRCSR               ;F51A: 7B 40 11       '{@.'
        BNE     ZF52B                    ;F51D: 26 0C          '&.'
        TIM     #$40,TCSR                ;F51F: 7B 40 08       '{@.'
        BEQ     ZF51A                    ;F522: 27 F6          ''.'
        LDD     OCR_H                    ;F524: DC 0B          '..'
        DEX                              ;F526: 09             '.'
        BNE     ZF515                    ;F527: 26 EC          '&.'
        CLC                              ;F529: 0C             '.'
        RTS                              ;F52A: 39             '9'
ZF52B:  JMP     sci_error_exit           ;F52B: 7E F0 9D       '~..'
printer_config_table: FCB     $00,$00,$04,$97,$04,$16  ;F52E: 00 00 04 97 04 16 '......'
        FCB     $03,$A4,$03              ;F534: 03 A4 03       '...'
        FCC     "p"                      ;F537: 70             'p'
        FCB     $03,$10                  ;F538: 03 10          '..'
print_err_ptr: FCB     $02,$BA,$02              ;F53A: 02 BA 02       '...'
        FCC     "n"                      ;F53D: 6E             'n'
print_err2_ptr: FCB     $02                      ;F53E: 02             '.'
        FCC     "K"                      ;F53F: 4B             'K'
        FCB     $02,$0B,$01,$D2,$01,$B8  ;F540: 02 0B 01 D2 01 B8 '......'
        FCB     $01,$88                  ;F546: 01 88          '..'
print_timeout_ptr: FCB     $01                      ;F548: 01             '.'
        FCC     "]"                      ;F549: 5D             ']'
        FCB     $01                      ;F54A: 01             '.'
        FCC     "7"                      ;F54B: 37             '7'
        FCB     $01,$26,$01,$06,$00,$E9  ;F54C: 01 26 01 06 00 E9 '.&....'
        FCB     $00,$DC,$00,$C4          ;F552: 00 DC 00 C4    '....'
print_init_ptr: FCB     $00,$AF,$00,$9C,$00,$93  ;F556: 00 AF 00 9C 00 93 '......'
        FCB     $00,$83,$00              ;F55C: 00 83 00       '...'
        FCC     "t"                      ;F55F: 74             't'
        FCB     $00                      ;F560: 00             '.'
        FCC     "n"                      ;F561: 6E             'n'
        FCB     $00                      ;F562: 00             '.'
        FCC     "b"                      ;F563: 62             'b'
print_serial_ptr: FCB     $00                      ;F564: 00             '.'
        FCC     "W"                      ;F565: 57             'W'
        FCB     $00                      ;F566: 00             '.'
        FCC     "N"                      ;F567: 4E             'N'
        FCB     $04                      ;F568: 04             '.'
        FCC     "V"                      ;F569: 56             'V'
        FCB     $03,$DC,$03              ;F56A: 03 DC 03       '...'
        FCC     "p"                      ;F56D: 70             'p'
        FCB     $03                      ;F56E: 03             '.'
        FCC     ">"                      ;F56F: 3E             '>'
        FCB     $02,$E4,$02,$93,$02      ;F570: 02 E4 02 93 02 '.....'
        FCC     "K"                      ;F575: 4B             'K'
        FCB     $02                      ;F576: 02             '.'
        FCC     "+"                      ;F577: 2B             '+'
        FCB     $01,$EE,$01,$B8,$01,$9F  ;F578: 01 EE 01 B8 01 9F '......'
        FCB     $01                      ;F57E: 01             '.'
        FCC     "r"                      ;F57F: 72             'r'
        FCB     $01                      ;F580: 01             '.'
        FCC     "J"                      ;F581: 4A             'J'
        FCB     $01,$26,$01,$16,$00,$F7  ;F582: 01 26 01 16 00 F7 '.&....'
        FCB     $00,$DC,$00,$D0,$00,$B9  ;F588: 00 DC 00 D0 00 B9 '......'
        FCB     $00,$A5,$00,$93,$00,$8B  ;F58E: 00 A5 00 93 00 8B '......'
        FCB     $00                      ;F594: 00             '.'
        FCC     "|"                      ;F595: 7C             '|'
        FCB     $00                      ;F596: 00             '.'
        FCC     "n"                      ;F597: 6E             'n'
        FCB     $00                      ;F598: 00             '.'
        FCC     "h"                      ;F599: 68             'h'
        FCB     $00                      ;F59A: 00             '.'
        FCC     "]"                      ;F59B: 5D             ']'
        FCB     $00                      ;F59C: 00             '.'
        FCC     "R"                      ;F59D: 52             'R'
        FCB     $00                      ;F59E: 00             '.'
        FCC     "I"                      ;F59F: 49             'I'
grp3_cmd_34: LDX     #cas_status              ;F5A0: CE 00 B4       '...'   cmd 0x34: receive 48 config bytes from master
        LDAB    #$30                     ;F5A3: C6 30          '.0'
        JSR     send_ack                 ;F5A5: BD F1 48       '..H'
ZF5A8:  INX                              ;F5A8: 08             '.'
        JSR     sci_recv_raw             ;F5A9: BD F1 3D       '..='
        STAA    ,X                       ;F5AC: A7 00          '..'
        DECB                             ;F5AE: 5A             'Z'
        BEQ     ZF5BB                    ;F5AF: 27 0A          ''.'
        LDAA    #$21                     ;F5B1: 86 21          '.!'
        JSR     sci_send_byte            ;F5B3: BD F1 4B       '..K'
        LDAA    ,X                       ;F5B6: A6 00          '..'
        BPL     ZF5A8                    ;F5B8: 2A EE          '*.'
        RTS                              ;F5BA: 39             '9'
ZF5BB:  LDAA    #$2F                     ;F5BB: 86 2F          './'
        SEC                              ;F5BD: 0D             '.'
        JMP     sci_send_byte            ;F5BE: 7E F1 4B       '~.K'
grp3_cmd_35: LDX     #cas1_leader_ct          ;F5C1: CE 00 B5       '...'   cmd 0x35: send config table to printer
        JSR     send_ack                 ;F5C4: BD F1 48       '..H'
ZF5C7:  LDAB    ,X                       ;F5C7: E6 00          '..'
        BMI     ZF5E1                    ;F5C9: 2B 16          '+.'
        PSHX                             ;F5CB: 3C             '<'
        CLRA                             ;F5CC: 4F             'O'
        ASLD                             ;F5CD: 05             '.'
        ADDD    #printer_config_table    ;F5CE: C3 F5 2E       '...'
        LDX     $01,X                    ;F5D1: EE 01          '..'
        XGDX                             ;F5D3: 18             '.'
        CLRB                             ;F5D4: 5F             '_'
        LSRD                             ;F5D5: 04             '.'
        LSRD                             ;F5D6: 04             '.'
        LDX     ,X                       ;F5D7: EE 00          '..'
        JSR     printer_timed_send       ;F5D9: BD F4 D4       '...'
        PULX                             ;F5DC: 38             '8'
        INX                              ;F5DD: 08             '.'
        INX                              ;F5DE: 08             '.'
        BRA     ZF5C7                    ;F5DF: 20 E6          ' .'
ZF5E1:  RTS                              ;F5E1: 39             '9'
grp2_subtable: FCB     $0B                      ;F5E2: 0B             '.'
        FDB     cmd_20_status            ;F5E3: F5 FB          '..'
        FDB     fsk_timing_init          ;F5E5: F6 24          '.$'
        FDB     cas1_setup,cas1_cleanup  ;F5E7: F6 13 F6 1A    '....'
        FDB     cas1_save_all            ;F5EB: F6 43          '.C'
        FDB     cas1_save_hdr            ;F5ED: F6 37          '.7'
        FDB     cas1_load_hdr            ;F5EF: F7 6A          '.j'
        FDB     cas1_load_end            ;F5F1: F7 66          '.f'
        FDB     cas1_load_all            ;F5F3: F7 72          '.r'
        FDB     cas1_load_skip_crc       ;F5F5: F7 6E          '.n'
        FDB     cas1_save_crc            ;F5F7: F6 3F          '.?'
        FDB     cmd_2B_set_flags         ;F5F9: F6 00          '..'
cmd_20_status: LDAA    #$21                     ;F5FB: 86 21          '.!'    cmd 0x20: send status byte $21
        JMP     sci_send_byte            ;F5FD: 7E F1 4B       '~.K'
cmd_2B_set_flags: JSR     send_ack                 ;F600: BD F1 48       '..H'   cmd 0x2B: set FSK flags from master byte
        LDAA    #$21                     ;F603: 86 21          '.!'
        JSR     sci_recv_byte            ;F605: BD F1 2E       '...'
        TAB                              ;F608: 16             '.'
        ANDA    #$0A                     ;F609: 84 0A          '..'
        ANDB    #$05                     ;F60B: C4 05          '..'
        ASLB                             ;F60D: 58             'X'
        ASLB                             ;F60E: 58             'X'
        ABA                              ;F60F: 1B             '.'
        STAA    fsk_flags                ;F610: 97 A5          '..'
        RTS                              ;F612: 39             '9'
cas1_setup: JSR     send_ack                 ;F613: BD F1 48       '..H'   cas1 setup: ACK + P30=low(motor),P33=low
        AIM     #$E6,PORT3               ;F616: 71 E6 06       'q..'   P30=0(motor on),P33=0,P34=0
        RTS                              ;F619: 39             '9'
cas1_cleanup: JSR     send_ack                 ;F61A: BD F1 48       '..H'   cas1 cleanup: ACK + motor off
cas1_motor_off: AIM     #$E7,PORT3               ;F61D: 71 E7 06       'q..'   motor off: P33=0,P34=0 then P30=1
        OIM     #$01,PORT3               ;F620: 72 01 06       'r..'
        RTS                              ;F623: 39             '9'
fsk_timing_init: JSR     send_ack                 ;F624: BD F1 48       '..H'   cmd 0x21: receive FSK timing params
        LDAA    #$21                     ;F627: 86 21          '.!'
        LDX     #vec_IRQ1                ;F629: CE FF F8       '...'   X=FFF8, loop receives 4x2-byte params
ZF62C:  JSR     sci_transact_2           ;F62C: BD F1 0A       '...'
        STD     $A5,X                    ;F62F: ED A5          '..'
        INX                              ;F631: 08             '.'
        INX                              ;F632: 08             '.'
        BNE     ZF62C                    ;F633: 26 F7          '&.'
        CLC                              ;F635: 0C             '.'
        RTS                              ;F636: 39             '9'
cas1_save_hdr: CLRA                             ;F637: 4F             'O'     save header: leader_ct=0, mode=FF
        CLRB                             ;F638: 5F             '_'
        STD     cas1_leader_ct           ;F639: DD B5          '..'
        LDAA    #$FF                     ;F63B: 86 FF          '..'
        BRA     ZF644                    ;F63D: 20 05          ' .'
cas1_save_crc: LDAA    #$01                     ;F63F: 86 01          '..'    save with CRC: mode=01
        BRA     ZF644                    ;F641: 20 01          ' .'
cas1_save_all: CLRA                             ;F643: 4F             'O'     save all: mode=00
ZF644:  STAA    cas1_mode                ;F644: 97 87          '..'
cas1_save_body: BSR     cas1_setup               ;F646: 8D CB          '..'    setup: motor ON via cas1_setup
        LDAA    cas1_mode                ;F648: 96 87          '..'
        BMI     ZF653                    ;F64A: 2B 07          '+.'
        LDAA    #$21                     ;F64C: 86 21          '.!'
        JSR     sci_transact_2           ;F64E: BD F1 0A       '...'
        STD     cas1_leader_ct           ;F651: DD B5          '..'
ZF653:  LDAA    #$21                     ;F653: 86 21          '.!'
        JSR     sci_transact_2           ;F655: BD F1 0A       '...'
        STD     load_byte_ct             ;F658: DD B7          '..'
        LDAA    TCSR                     ;F65A: 96 08          '..'
        LDD     FRC_H                    ;F65C: DC 09          '..'
        STD     OCR_H                    ;F65E: DD 0B          '..'
cas1_save_leader: LDX     #M0271                   ;F660: CE 02 71       '..q'   leader loop: N 
        LDAA    cas1_leader_ct           ;F663: 96 B5          '..'
        BMI     ZF66F                    ;F665: 2B 08          '+.'
        LDX     fsk_param3_hi            ;F667: DE A3          '..'
        TSTA                             ;F669: 4D             'M'
        BEQ     ZF66F                    ;F66A: 27 03          ''.'
        LDX     #P3CSR                   ;F66C: CE 00 0F       '...'
ZF66F:  LDAA    #$FF                     ;F66F: 86 FF          '..'
        JSR     cas1_fsk_encode_8        ;F671: BD F7 09       '...'
        TIM     #$40,TRCSR               ;F674: 7B 40 11       '{@.'
        BNE     cas1_save_err            ;F677: 26 43          '&C'
        DEX                              ;F679: 09             '.'
        BNE     ZF66F                    ;F67A: 26 F3          '&.'
        LDX     cas1_leader_ct           ;F67C: DE B5          '..'
        LDAA    cas1_mode                ;F67E: 96 87          '..'
        BMI     cas1_save_hdr_exit       ;F680: 2B 6E          '+n'
cas1_save_sync: LDX     #FRC_H                   ;F682: CE 00 09       '...'   sync phase: 9x $00 bytes
ZF685:  CLRA                             ;F685: 4F             'O'
        JSR     cas1_fsk_encode_8        ;F686: BD F7 09       '...'
        DEX                              ;F689: 09             '.'
        BNE     ZF685                    ;F68A: 26 F9          '&.'
        CLRA                             ;F68C: 4F             'O'     sync marker: 00
        BSR     cas1_fsk_encode_9        ;F68D: 8D 7F          '..'
        LDAA    #$FF                     ;F68F: 86 FF          '..'    sync marker: FF
        BSR     cas1_fsk_encode_9        ;F691: 8D 7B          '.{'
        LDAA    #$AA                     ;F693: 86 AA          '..'    sync marker: AA
        BSR     cas1_fsk_encode_9        ;F695: 8D 77          '.w'
        CLRA                             ;F697: 4F             'O'     clear CRC
        CLRB                             ;F698: 5F             '_'
        STD     crc_hi                   ;F699: DD 95          '..'
cas1_save_data: LDAA    TRCSR                    ;F69B: 96 11          '..'    data loop: poll RDRF, ACK $21, FSK-encode
        BMI     ZF6BF                    ;F69D: 2B 20          '+ '
        TIM     #$01,PORT4               ;F69F: 7B 01 07       '{..'   check P40 (cas ctrl motor status)
        BNE     ZF6AA                    ;F6A2: 26 06          '&.'
        LDAA    cas1_mode                ;F6A4: 96 87          '..'    mode!=0: write trailer on motor stop
        BNE     cas1_save_trail          ;F6A6: 26 2A          '&*'
        BRA     ZF6AF                    ;F6A8: 20 05          ' .'
ZF6AA:  TIM     #$40,TCSR                ;F6AA: 7B 40 08       '{@.'   check OCF timeout
        BEQ     cas1_save_data           ;F6AD: 27 EC          ''.'
ZF6AF:  LDAA    #$2F                     ;F6AF: 86 2F          './'
        JSR     sci_send_byte            ;F6B1: BD F1 4B       '..K'
        JSR     ZF4A7                    ;F6B4: BD F4 A7       '...'
        JSR     cas1_motor_off           ;F6B7: BD F6 1D       '...'
        CLC                              ;F6BA: 0C             '.'
        RTS                              ;F6BB: 39             '9'
cas1_save_err: JMP     sci_error_exit           ;F6BC: 7E F0 9D       '~..'
ZF6BF:  LDAA    #$21                     ;F6BF: 86 21          '.!'    RDRF set: ACK $21, read data byte
        STAA    TDR                      ;F6C1: 97 13          '..'
        LDAA    RDR                      ;F6C3: 96 12          '..'
        BSR     cas1_fsk_encode_9        ;F6C5: 8D 47          '.G'
        LDX     load_byte_ct             ;F6C7: DE B7          '..'    decrement byte count
        DEX                              ;F6C9: 09             '.'
        STX     load_byte_ct             ;F6CA: DF B7          '..'
        BNE     cas1_save_data           ;F6CC: 26 CD          '&.'
        LDAA    cas1_mode                ;F6CE: 96 87          '..'    mode!=0: done (no trailer)
        BNE     ZF6AF                    ;F6D0: 26 DD          '&.'
cas1_save_trail: LDAA    crc_lo                   ;F6D2: 96 96          '..'    trailer: CRC_lo x2, AA, 00
        BSR     cas1_fsk_encode_9        ;F6D4: 8D 38          '.8'
        LDAA    crc_lo                   ;F6D6: 96 96          '..'
        BSR     cas1_fsk_encode_9        ;F6D8: 8D 34          '.4'
        LDAA    #$AA                     ;F6DA: 86 AA          '..'
        BSR     cas1_fsk_encode_9        ;F6DC: 8D 30          '.0'
        CLRA                             ;F6DE: 4F             'O'
        BSR     cas1_fsk_encode_9        ;F6DF: 8D 2D          '.-'
        LDX     #M0271                   ;F6E1: CE 02 71       '..q'
        LDAB    cas1_trailer_ct          ;F6E4: D6 B6          '..'    check trailer_ct for leader count
        BMI     cas1_save_hdr_exit       ;F6E6: 2B 08          '+.'
        LDX     fsk_param3_hi            ;F6E8: DE A3          '..'
        TSTB                             ;F6EA: 5D             ']'
        BEQ     cas1_save_hdr_exit       ;F6EB: 27 03          ''.'
        LDX     #P3CSR                   ;F6ED: CE 00 0F       '...'
cas1_save_hdr_exit: LDAA    #$FF                     ;F6F0: 86 FF          '..'    trailing leader FF bytes
        BSR     cas1_fsk_encode_8        ;F6F2: 8D 15          '..'
        TIM     #$40,TRCSR               ;F6F4: 7B 40 11       '{@.'
        BNE     cas1_save_err            ;F6F7: 26 C3          '&.'
        DEX                              ;F6F9: 09             '.'
        BNE     cas1_save_hdr_exit       ;F6FA: 26 F4          '&.'
        AIM     #$F7,PORT3               ;F6FC: 71 F7 06       'q..'   P33=low after leader
        TST     >cas1_trailer_ct         ;F6FF: 7D 00 B6       '}..'
        BGT     ZF707                    ;F702: 2E 03          '..'
cas1_save_done: JSR     cas1_motor_off           ;F704: BD F6 1D       '...'   done: motor off
ZF707:  CLC                              ;F707: 0C             '.'
        RTS                              ;F708: 39             '9'
cas1_fsk_encode_8: PSHB                             ;F709: 37             '7'     8-bit encode: start bit always 1 (B=FF)
        LDAB    #$FF                     ;F70A: C6 FF          '..'
        BRA     ZF710                    ;F70C: 20 02          ' .'
cas1_fsk_encode_9: PSHB                             ;F70E: 37             '7'     9-bit encode: start bit=0 (B=0)
        CLRB                             ;F70F: 5F             '_'
ZF710:  STAB    param1_hi                ;F710: D7 84          '..'
        STAA    fsk_byte                 ;F712: 97 82          '..'    store byte to encode
        LDAB    #$08                     ;F714: C6 08          '..'    8 data bits
        STAB    bit_counter              ;F716: D7 83          '..'
cas1_fsk_loop: LDAA    fsk_byte                 ;F718: 96 82          '..'    loop: LSR fsk_byte, time via OCR
        PSHA                             ;F71A: 36             '6'
        LDD     cas1_long_hi             ;F71B: DC 9F          '..'
        LSR     >fsk_byte                ;F71D: 74 00 82       't..'   bit=0: long period (cas1_long)
        BCC     ZF724                    ;F720: 24 02          '$.'
        LDD     cas1_short_hi            ;F722: DC 9D          '..'    bit=1: short period (cas1_short)
ZF724:  PSHA                             ;F724: 36             '6'
        PSHB                             ;F725: 37             '7'
        ADDD    OCR_H                    ;F726: D3 0B          '..'    first half: add period to OCR
        STD     OCR_H                    ;F728: DD 0B          '..'
        LDAA    #$40                     ;F72A: 86 40          '.@'    wait OCF
ZF72C:  BITA    TCSR                     ;F72C: 95 08          '..'
        BEQ     ZF72C                    ;F72E: 27 FC          ''.'
        AIM     #$F7,PORT3               ;F730: 71 F7 06       'q..'   P33=low (FSK output low)
        PULB                             ;F733: 33             '3'
        PULA                             ;F734: 32             '2'
        ADDD    OCR_H                    ;F735: D3 0B          '..'    second half: add period to OCR
        STD     OCR_H                    ;F737: DD 0B          '..'
        PULB                             ;F739: 33             '3'
        LDAA    bit_counter              ;F73A: 96 83          '..'    counter==0: done
        BEQ     ZF74D                    ;F73C: 27 0F          ''.'
        ANDB    #$01                     ;F73E: C4 01          '..'    CRC update on data bits
        EORB    crc_lo                   ;F740: D8 96          '..'
        LDAA    crc_hi                   ;F742: 96 95          '..'
        LSRD                             ;F744: 04             '.'
        BCC     ZF74B                    ;F745: 24 04          '$.'
        EORA    crc_poly_hi              ;F747: 98 93          '..'
        EORB    crc_poly_lo              ;F749: D8 94          '..'
ZF74B:  STD     crc_hi                   ;F74B: DD 95          '..'
ZF74D:  TIM     #$40,TCSR                ;F74D: 7B 40 08       '{@.'   wait OCF for second half
        BEQ     ZF74D                    ;F750: 27 FB          ''.'
        OIM     #$08,PORT3               ;F752: 72 08 06       'r..'   P33=high (FSK output high)
        DEC     >bit_counter             ;F755: 7A 00 83       'z..'   dec bit counter
        BMI     ZF763                    ;F758: 2B 09          '+.'
        BNE     cas1_fsk_loop            ;F75A: 26 BC          '&.'
        OIM     #$01,fsk_byte            ;F75C: 72 01 82       'r..'   last bit: set bit 0 for stop bit
        LDAA    param1_hi                ;F75F: 96 84          '..'    check if 8-bit mode: extra stop bit
        BPL     cas1_fsk_loop            ;F761: 2A B5          '*.'
ZF763:  PULB                             ;F763: 33             '3'
        CLC                              ;F764: 0C             '.'
        RTS                              ;F765: 39             '9'
cas1_load_end: LDAA    #$FE                     ;F766: 86 FE          '..'
        BRA     cas1_load_body           ;F768: 20 09          ' .'
cas1_load_hdr: LDAA    #$FF                     ;F76A: 86 FF          '..'
        BRA     cas1_load_body           ;F76C: 20 05          ' .'
cas1_load_skip_crc: LDAA    #$01                     ;F76E: 86 01          '..'
        BRA     cas1_load_body           ;F770: 20 01          ' .'
cas1_load_all: CLRA                             ;F772: 4F             'O'
cas1_load_body: STAA    cas1_mode                ;F773: 97 87          '..'    store mode byte (cas1_mode)
        JSR     cas1_setup               ;F775: BD F6 13       '...'   setup: motor on (P30 low)
        LDAA    #$21                     ;F778: 86 21          '.!'    transact: get leader count
        JSR     sci_transact_2           ;F77A: BD F1 0A       '...'
        STD     cas1_leader_ct           ;F77D: DD B5          '..'
        LDAA    #$21                     ;F77F: 86 21          '.!'
        JSR     sci_transact_2           ;F781: BD F1 0A       '...'   transact: get byte count
        STD     load_byte_ct             ;F784: DD B7          '..'
        CLI                              ;F786: 0E             '.'     CLI: enable interrupts for FSK decode
        TIM     #$02,fsk_flags           ;F787: 7B 02 A5       '{..'   check fsk_flags bit 1
        BNE     cas1_load_leader_search  ;F78A: 26 03          '&.'
        AIM     #$FB,fsk_flags           ;F78C: 71 FB A5       'q..'
cas1_load_leader_search: LDD     FRC_H                    ;F78F: DC 09          '..'    search for 50 consecutive "1" bits
        STD     frc_ref                  ;F791: DD 80          '..'
cas1_load_restart: LDAB    #$32                     ;F793: C6 32          '.2'    restart: 50 "1" bits required
ZF795:  PSHB                             ;F795: 37             '7'
        JSR     fsk_decode_1bit          ;F796: BD F8 94       '...'
        PULB                             ;F799: 33             '3'
        BCS     cas1_load_restart        ;F79A: 25 F7          '%.'
        BNE     cas1_load_restart        ;F79C: 26 F5          '&.'
        DECB                             ;F79E: 5A             'Z'
        BNE     ZF795                    ;F79F: 26 F4          '&.'
cas1_load_scan_zero: LDAB    #$33                     ;F7A1: C6 33          '.3'    search for first "0" bit (max 51 tries)
ZF7A3:  DECB                             ;F7A3: 5A             'Z'
        BEQ     cas1_load_restart        ;F7A4: 27 ED          ''.'
        PSHB                             ;F7A6: 37             '7'
        JSR     fsk_decode_1bit          ;F7A7: BD F8 94       '...'
        PULB                             ;F7AA: 33             '3'
        BCS     cas1_load_restart        ;F7AB: 25 E6          '%.'
        TIM     #$02,fsk_flags           ;F7AD: 7B 02 A5       '{..'   check fsk_flags for edge polarity mode
        BNE     ZF7CF                    ;F7B0: 26 1D          '&.'
        XGDX                             ;F7B2: 18             '.'     get period as D register
        TSTA                             ;F7B3: 4D             'M'
        BPL     ZF7BB                    ;F7B4: 2A 05          '*.'
        COMA                             ;F7B6: 43             'C'
        COMB                             ;F7B7: 53             'S'
        ADDD    #DDR2                    ;F7B8: C3 00 01       '...'
ZF7BB:  SUBD    #M004A                   ;F7BB: 83 00 4A       '..J'   check if period within tolerance
        XGDX                             ;F7BE: 18             '.'
        BCC     ZF7CF                    ;F7BF: 24 0E          '$.'
        OIM     #$04,fsk_flags           ;F7C1: 72 04 A5       'r..'   set fsk_flags bit 2 (polarity found)
ZF7C4:  LDAA    PORT3                    ;F7C4: 96 06          '..'    wait for P32 stable
        CMPA    ZF7C4                    ;F7C6: B1 F7 C4       '...'
        BITA    #$04                     ;F7C9: 85 04          '..'
        BNE     ZF7C4                    ;F7CB: 26 F7          '&.'
        LDAA    #$01                     ;F7CD: 86 01          '..'
ZF7CF:  TSTA                             ;F7CF: 4D             'M'
        BEQ     ZF7A3                    ;F7D0: 27 D1          ''.'
cas1_load_sync_7bit: BSR     fsk_decode_7bit          ;F7D2: 8D 5F          '._'    7-bit sync decode (expect FF)
        BCS     cas1_load_restart        ;F7D4: 25 BD          '%.'
        INCA                             ;F7D6: 4C             'L'     FF + 1 = 00: Z=1 passes
        BNE     cas1_load_restart        ;F7D7: 26 BA          '&.'
cas1_load_sync_8bit: BSR     fsk_decode_8bit          ;F7D9: 8D 5D          '.]'    8-bit sync decode (expect AA)
        BCS     cas1_load_restart        ;F7DB: 25 B6          '%.'
        EORA    #$AA                     ;F7DD: 88 AA          '..'    check: decoded == AA? (EORA #AA)
        BNE     cas1_load_restart        ;F7DF: 26 B2          '&.'
cas1_load_sync_found: CLRB                             ;F7E1: 5F             '_'     sync found: init CRC, load byte count
        STD     crc_hi                   ;F7E2: DD 95          '..'
        LDX     load_byte_ct             ;F7E4: DE B7          '..'
cas1_load_data_loop: BSR     fsk_decode_8bit          ;F7E6: 8D 50          '.P'    data loop: decode 8-bit + send to master
        BCS     cas1_load_restart        ;F7E8: 25 A9          '%.'
        LDAB    cas1_mode                ;F7EA: D6 87          '..'    check mode byte
        CMPA    #$48                     ;F7EC: 81 48          '.H'    looking for 0x48 sync marker
        BEQ     ZF7F4                    ;F7EE: 27 04          ''.'
        CMPA    #$45                     ;F7F0: 81 45          '.E'    looking for 0x45 sync marker
        BNE     ZF7F7                    ;F7F2: 26 03          '&.'
ZF7F4:  LDX     #M0054                   ;F7F4: CE 00 54       '..T'
ZF7F7:  TSTB                             ;F7F7: 5D             ']'
        BPL     ZF80C                    ;F7F8: 2A 12          '*.'
        XGDX                             ;F7FA: 18             '.'
        CPX     #M48FF                   ;F7FB: 8C 48 FF       '.H.'
        BEQ     ZF805                    ;F7FE: 27 05          ''.'
        CPX     #M45FE                   ;F800: 8C 45 FE       '.E.'
        BNE     cas1_load_restart        ;F803: 26 8E          '&.'
ZF805:  XGDX                             ;F805: 18             '.'
        BRA     ZF80C                    ;F806: 20 04          ' .'
ZF808:  BSR     fsk_decode_8bit          ;F808: 8D 2E          '..'    decode next byte in block
        BCS     ZF82E                    ;F80A: 25 22          '%"'
ZF80C:  JSR     sci_send_byte            ;F80C: BD F1 4B       '..K'   send decoded byte to master
        DEX                              ;F80F: 09             '.'
        BNE     ZF808                    ;F810: 26 F6          '&.'
cas1_load_post_data: TST     >cas1_mode               ;F812: 7D 00 87       '}..'   post data: check mode for CRC verify
        BGT     ZF82E                    ;F815: 2E 17          '..'
        BSR     fsk_decode_8bit          ;F817: 8D 1F          '..'    decode CRC byte 1
        BCS     ZF82E                    ;F819: 25 13          '%.'
        BSR     fsk_decode_8bit          ;F81B: 8D 1B          '..'    decode CRC byte 2
        BCS     ZF82E                    ;F81D: 25 0F          '%.'
        SEI                              ;F81F: 0F             '.'     SEI after CRC
        LDAA    #$22                     ;F820: 86 22          '."'    send $22 completion status
        JSR     sci_send_byte            ;F822: BD F1 4B       '..K'
        LDAA    cas1_trailer_ct          ;F825: 96 B6          '..'    check trailer count
        BNE     ZF82C                    ;F827: 26 03          '&.'
        JSR     cas1_motor_off           ;F829: BD F6 1D       '...'   motor off if no trailer
ZF82C:  CLC                              ;F82C: 0C             '.'
        RTS                              ;F82D: 39             '9'
ZF82E:  OIM     #$10,PORT3               ;F82E: 72 10 06       'r..'   error: set P34 high (flag to master)
        CLC                              ;F831: 0C             '.'
        RTS                              ;F832: 39             '9'
fsk_decode_7bit: PSHB                             ;F833: 37             '7'     entry: 7-bit (counter=7, 8 edge reads)
        LDAB    #$07                     ;F834: C6 07          '..'
        BRA     ZF83B                    ;F836: 20 03          ' .'
fsk_decode_8bit: PSHB                             ;F838: 37             '7'     entry: 8-bit (counter=8, 9 edge reads)
        LDAB    #$08                     ;F839: C6 08          '..'
ZF83B:  STAB    bit_counter              ;F83B: D7 83          '..'
        LDD     FRC_H                    ;F83D: DC 09          '..'    read FRC as initial reference
        TST     >TCSR                    ;F83F: 7D 00 08       '}..'
        STD     OCR_H                    ;F842: DD 0B          '..'    arm OCR for timeout
        LDAB    TCSR                     ;F844: D6 08          '..'
        STAA    OCR_H                    ;F846: 97 0B          '..'
ZF848:  CLRB                             ;F848: 5F             '_'     clear edge state
ZF849:  TIM     #$40,TCSR                ;F849: 7B 40 08       '{@.'   check OCF timeout
        BNE     fsk_timeout              ;F84C: 26 42          '&B'
fsk_edge_detect: LDAA    PORT3                    ;F84E: 96 06          '..'    read P32, debounce (read twice)
        CMPA    PORT3                    ;F850: 91 06          '..'
        BNE     fsk_edge_detect          ;F852: 26 FA          '&.'
        EORA    fsk_flags                ;F854: 98 A5          '..'    XOR with fsk_flags for polarity
        ANDA    #$04                     ;F856: 84 04          '..'    mask bit 2 (P32)
        CBA                              ;F858: 11             '.'     compare with previous edge state
        BNE     ZF849                    ;F859: 26 EE          '&.'
        EORB    #$04                     ;F85B: C8 04          '..'    toggle edge state, check for full cycle
        BNE     ZF849                    ;F85D: 26 EA          '&.'
fsk_measure_period: LDD     FRC_H                    ;F85F: DC 09          '..'    D = FRC (current time)
        PSHA                             ;F861: 36             '6'     save FRC high on stack
        PSHB                             ;F862: 37             '7'     save FRC low on stack
        SUBD    frc_ref                  ;F863: 93 80          '..'    D = FRC - prev_ref = period
        SUBD    fsk_thresh_hi            ;F865: 93 A1          '..'    D = period - threshold; C=1 short, C=0 long
        PULB                             ;F867: 33             '3'     restore B (PULB: no flag change)
        PULA                             ;F868: 32             '2'     restore A (PULA: no flag change)
        STD     frc_ref                  ;F869: DD 80          '..'    save current FRC as new reference
fsk_bit_decode: ROLA                             ;F86B: 49             'I'     carry from SUBD -> A[0] via ROLA
        COMA                             ;F86C: 43             'C'     A=~A, C=1 always (COMA)
        TAB                              ;F86D: 16             '.'     B=A (C stays 1 after TAB)
        RORA                             ;F86E: 46             'F'     C(=1)->A[7], old A[0](=~carry_in)->C via RORA
        ROR     >fsk_byte                ;F86F: 76 00 82       'v..'   C(=~carry_in)->fsk_byte[7]: INVERTS bit!
fsk_crc_update: TIM     #$08,bit_counter         ;F872: 7B 08 83       '{..'   CRC update: skip if counter has bit 3
        BNE     fsk_dec_counter          ;F875: 26 0F          '&.'
        ANDB    #$01                     ;F877: C4 01          '..'    XOR bit with CRC[0]
        EORB    crc_lo                   ;F879: D8 96          '..'
        LDAA    crc_hi                   ;F87B: 96 95          '..'
        LSRD                             ;F87D: 04             '.'     LSRD: shift CRC right
        BCC     ZF884                    ;F87E: 24 04          '$.'
        EORA    crc_poly_hi              ;F880: 98 93          '..'    if carry: XOR with polynomial
        EORB    crc_poly_lo              ;F882: D8 94          '..'
ZF884:  STD     crc_hi                   ;F884: DD 95          '..'
fsk_dec_counter: DEC     >bit_counter             ;F886: 7A 00 83       'z..'   dec bit_counter
        BPL     ZF848                    ;F889: 2A BD          '*.'
        CLC                              ;F88B: 0C             '.'     CLC: no error
        LDAA    fsk_byte                 ;F88C: 96 82          '..'    return decoded byte in A
        PULB                             ;F88E: 33             '3'
        RTS                              ;F88F: 39             '9'
fsk_timeout: PULB                             ;F890: 33             '3'     timeout: return C=1 (error)
ZF891:  CLRA                             ;F891: 4F             'O'
        SEC                              ;F892: 0D             '.'
        RTS                              ;F893: 39             '9'
fsk_decode_1bit: LDD     FRC_H                    ;F894: DC 09          '..'    decode single bit: arm timeout OCR
        TST     >TCSR                    ;F896: 7D 00 08       '}..'
        SUBD    #M0200                   ;F899: 83 02 00       '...'
        STD     OCR_H                    ;F89C: DD 0B          '..'
        CLRB                             ;F89E: 5F             '_'
ZF89F:  TIM     #$40,TCSR                ;F89F: 7B 40 08       '{@.'
        BNE     ZF891                    ;F8A2: 26 ED          '&.'
ZF8A4:  LDAA    PORT3                    ;F8A4: 96 06          '..'
        CMPA    PORT3                    ;F8A6: 91 06          '..'
        BNE     ZF8A4                    ;F8A8: 26 FA          '&.'
        EORA    fsk_flags                ;F8AA: 98 A5          '..'
        ANDA    #$04                     ;F8AC: 84 04          '..'
        CBA                              ;F8AE: 11             '.'
        BNE     ZF89F                    ;F8AF: 26 EE          '&.'
        EORB    #$04                     ;F8B1: C8 04          '..'
        BNE     ZF89F                    ;F8B3: 26 EA          '&.'
        LDD     FRC_H                    ;F8B5: DC 09          '..'
        PSHB                             ;F8B7: 37             '7'
        PSHA                             ;F8B8: 36             '6'
        PULX                             ;F8B9: 38             '8'
        SUBD    frc_ref                  ;F8BA: 93 80          '..'
        STX     frc_ref                  ;F8BC: DF 80          '..'
        SUBD    fsk_thresh_hi            ;F8BE: 93 A1          '..'
        PSHB                             ;F8C0: 37             '7'
        PSHA                             ;F8C1: 36             '6'
        PULX                             ;F8C2: 38             '8'
        ROLA                             ;F8C3: 49             'I'
        COMA                             ;F8C4: 43             'C'
        ANDA    #$01                     ;F8C5: 84 01          '..'
        CLC                              ;F8C7: 0C             '.'
        RTS                              ;F8C8: 39             '9'
grp4_subtable: FCB     $0D                      ;F8C9: 0D             '.'
        FDB     cmd_40_p33_low           ;F8CA: F8 FF          '..'
        FDB     cmd_41_p36_low           ;F8CC: F9 07          '..'
        FDB     cmd_42_set_icr           ;F8CE: F9 0D          '..'
        FDB     cmd_43_read_status       ;F8D0: F9 28          '.('
        FDB     cmd_44_clr_status        ;F8D2: F9 2C          '.,'
        FDB     cmd_45_irq_scan          ;F8D4: F9 41          '.A'
        FDB     send_ack                 ;F8D6: F1 48          '.H'
        FDB     cmd_47_4A_read_crc       ;F8D8: F8 F6          '..'
        FDB     cmd_48_set_crc_poly      ;F8DA: F8 E6          '..'
        FDB     cmd_49_set_crc_init      ;F8DC: F8 EE          '..'
        FDB     cmd_47_4A_read_crc       ;F8DE: F8 F6          '..'
        FDB     cmd_4B_read_crc_lo       ;F8E0: F8 FB          '..'
        FDB     cmd_4C_p36_high          ;F8E2: F9 02          '..'
        FDB     cmd_4D_set_p31           ;F8E4: F9 34          '.4'
cmd_48_set_crc_poly: LDAA    #$41                     ;F8E6: 86 41          '.A'    cmd 0x48: set CRC polynomial from master
        JSR     sci_transact_1           ;F8E8: BD F1 06       '...'
        STD     crc_poly_hi              ;F8EB: DD 93          '..'
        RTS                              ;F8ED: 39             '9'
cmd_49_set_crc_init: LDAA    #$41                     ;F8EE: 86 41          '.A'    cmd 0x49: set CRC init value from master
        JSR     sci_transact_1           ;F8F0: BD F1 06       '...'
        STD     crc_hi                   ;F8F3: DD 95          '..'
        RTS                              ;F8F5: 39             '9'
cmd_47_4A_read_crc: LDAA    crc_hi                   ;F8F6: 96 95          '..'    cmd 0x47/0x4A: read CRC high byte
ZF8F8:  JMP     sci_send_byte            ;F8F8: 7E F1 4B       '~.K'
cmd_4B_read_crc_lo: LDAA    crc_lo                   ;F8FB: 96 96          '..'    cmd 0x4B: read CRC low byte
        BRA     ZF8F8                    ;F8FD: 20 F9          ' .'
cmd_40_p33_low: AIM     #$E7,PORT3               ;F8FF: 71 E7 06       'q..'   cmd 0x40: P33=0,P34=0 then P36=high
cmd_4C_p36_high: OIM     #$40,PORT3               ;F902: 72 40 06       'r@.'   cmd 0x4C: P36=high (OIM $40 on PORT3)
        BRA     ZF90A                    ;F905: 20 03          ' .'
cmd_41_p36_low: AIM     #$BF,PORT3               ;F907: 71 BF 06       'q..'   cmd 0x41: P36=low (AIM &BF on PORT3)
ZF90A:  JMP     send_ack                 ;F90A: 7E F1 48       '~.H'
cmd_42_set_icr: LDAA    #$41                     ;F90D: 86 41          '.A'    cmd 0x42: set ICR params (4 bytes)
        JSR     sci_transact_1           ;F90F: BD F1 06       '...'
        STD     icr_period_hi            ;F912: DD 97          '..'
        LDAA    #$41                     ;F914: 86 41          '.A'
        JSR     sci_transact_2           ;F916: BD F1 0A       '...'
        STD     icr_config_hi            ;F919: DD 99          '..'
        ANDB    #$08                     ;F91B: C4 08          '..'    bit 3 of config: P31 control
ZF91D:  TSTB                             ;F91D: 5D             ']'
        BEQ     ZF924                    ;F91E: 27 04          ''.'
        AIM     #$FD,PORT3               ;F920: 71 FD 06       'q..'
        RTS                              ;F923: 39             '9'
ZF924:  OIM     #$02,PORT3               ;F924: 72 02 06       'r..'
        RTS                              ;F927: 39             '9'
cmd_43_read_status: LDAA    key_status               ;F928: 96 9B          '..'    cmd 0x43: read key_status byte
        BRA     ZF8F8                    ;F92A: 20 CC          ' .'
cmd_44_clr_status: AIM     #$EF,PORT3               ;F92C: 71 EF 06       'q..'   cmd 0x44: P34=low, clear key_status
        CLR     >key_status              ;F92F: 7F 00 9B       '...'
        BRA     ZF90A                    ;F932: 20 D6          ' .'
cmd_4D_set_p31: JSR     send_ack                 ;F934: BD F1 48       '..H'   cmd 0x4D: set P31 from master byte bit 0
        LDAA    #$41                     ;F937: 86 41          '.A'
        JSR     sci_recv_byte            ;F939: BD F1 2E       '...'
        TAB                              ;F93C: 16             '.'
        ANDB    #$01                     ;F93D: C4 01          '..'
        BRA     ZF91D                    ;F93F: 20 DC          ' .'
cmd_45_irq_scan: JSR     send_ack                 ;F941: BD F1 48       '..H'   cmd 0x45: IRQ ACK + keyboard/ICR scan loop
        AIM     #$FE,TCSR                ;F944: 71 FE 08       'q..'   clear OLVL in TCSR
        AIM     #$DF,PORT4               ;F947: 71 DF 07       'q..'   clear P45 in PORT4
        CLRA                             ;F94A: 4F             'O'     clear key_status
        STAA    key_status               ;F94B: 97 9B          '..'
        AIM     #$EF,PORT3               ;F94D: 71 EF 06       'q..'   P34=low
        CLI                              ;F950: 0E             '.'     CLI: enable interrupts
ZF951:  CLR     >fsk_byte                ;F951: 7F 00 82       '...'   main scan loop: clear fsk_byte, load config
        LDD     icr_config_hi            ;F954: DC 99          '..'
        STAB    frc_ref                  ;F956: D7 80          '..'
        BMI     ZF95B                    ;F958: 2B 01          '+.'
        INCA                             ;F95A: 4C             'L'
ZF95B:  STAA    bit_counter              ;F95B: 97 83          '..'
        STAA    cas0_mode                ;F95D: 97 81          '..'
        LDAA    TCSR                     ;F95F: 96 08          '..'    read TCSR to arm ICR
        LDAA    ICR_H                    ;F961: 96 0D          '..'    read ICR to clear flag
ZF963:  TIM     #$80,PORT4               ;F963: 7B 80 07       '{..'   check PORT4 bit 7 (key pressed)
        BEQ     ZF975                    ;F966: 27 0D          ''.'
        TIM     #$04,icr_config_lo       ;F968: 7B 04 9A       '{..'
        BNE     ZF975                    ;F96B: 26 08          '&.'
        OIM     #$01,key_status          ;F96D: 72 01 9B       'r..'   set key_status bit 0 (key event)
        OIM     #$10,PORT3               ;F970: 72 10 06       'r..'   P34=high (flag to master)
        BRA     ZF963                    ;F973: 20 EE          ' .'
ZF975:  LDAA    TCSR                     ;F975: 96 08          '..'    wait for ICF (input capture flag)
        BPL     ZF963                    ;F977: 2A EA          '*.'
        LDD     icr_period_hi            ;F979: DC 97          '..'    add half-period offset to ICR
        LSRD                             ;F97B: 04             '.'
        ADDD    ICR_H                    ;F97C: D3 0D          '..'
        STD     OCR_H                    ;F97E: DD 0B          '..'    arm OCR for sampling
        LDAA    #$40                     ;F980: 86 40          '.@'
ZF982:  BITA    TCSR                     ;F982: 95 08          '..'    wait OCF
        BEQ     ZF982                    ;F984: 27 FC          ''.'
        TIM     #$01,PORT2               ;F986: 7B 01 03       '{..'   check P20 (PORT2 bit 0): tape mechanism
        BNE     ZF951                    ;F989: 26 C6          '&.'    P20=1: restart scan (tape inserted)
ZF98B:  LDD     icr_period_hi            ;F98B: DC 97          '..'    ICR-timed data sampling loop
        ADDD    OCR_H                    ;F98D: D3 0B          '..'
        STD     OCR_H                    ;F98F: DD 0B          '..'
        LDAA    #$40                     ;F991: 86 40          '.@'
ZF993:  BITA    TCSR                     ;F993: 95 08          '..'
        BEQ     ZF993                    ;F995: 27 FC          ''.'
        LDAA    PORT2                    ;F997: 96 03          '..'    read PORT2
        TAB                              ;F999: 16             '.'
        ASRA                             ;F99A: 47             'G'     ASRA: shift P20 into carry
        ROR     >fsk_byte                ;F99B: 76 00 82       'v..'   carry -> fsk_byte[7] via ROR
        EORA    frc_ref                  ;F99E: 98 80          '..'    XOR with previous for edge detect
        STAA    frc_ref                  ;F9A0: 97 80          '..'
        ANDB    #$01                     ;F9A2: C4 01          '..'    CRC update (same as FSK decode)
        EORB    crc_lo                   ;F9A4: D8 96          '..'
        LDAA    crc_hi                   ;F9A6: 96 95          '..'
        LSRD                             ;F9A8: 04             '.'
        BCC     ZF9AF                    ;F9A9: 24 04          '$.'
        EORA    crc_poly_hi              ;F9AB: 98 93          '..'
        EORB    crc_poly_lo              ;F9AD: D8 94          '..'
ZF9AF:  STD     crc_hi                   ;F9AF: DD 95          '..'
        DEC     >bit_counter             ;F9B1: 7A 00 83       'z..'   dec bit_counter
        BNE     ZF98B                    ;F9B4: 26 D5          '&.'
        LDAA    #$08                     ;F9B6: 86 08          '..'    adjust fsk_byte alignment
        SUBA    cas0_mode                ;F9B8: 90 81          '..'
        BEQ     ZF9C2                    ;F9BA: 27 06          ''.'
ZF9BC:  ROR     >fsk_byte                ;F9BC: 76 00 82       'v..'
        DECA                             ;F9BF: 4A             'J'
        BNE     ZF9BC                    ;F9C0: 26 FA          '&.'
ZF9C2:  LDAA    fsk_byte                 ;F9C2: 96 82          '..'    send decoded byte to master
        JSR     sci_send_byte            ;F9C4: BD F1 4B       '..K'
        LDD     icr_period_hi            ;F9C7: DC 97          '..'
        ADDD    OCR_H                    ;F9C9: D3 0B          '..'
        STD     OCR_H                    ;F9CB: DD 0B          '..'
        LDAA    icr_config_lo            ;F9CD: 96 9A          '..'    check config flags
        BMI     ZF9D8                    ;F9CF: 2B 07          '+.'
        LDAA    frc_ref                  ;F9D1: 96 80          '..'
        BPL     ZF9D8                    ;F9D3: 2A 03          '*.'
        OIM     #$02,key_status          ;F9D5: 72 02 9B       'r..'   set key_status bit 1 (edge change)
ZF9D8:  TIM     #$40,TCSR                ;F9D8: 7B 40 08       '{@.'   wait OCF
        BEQ     ZF9D8                    ;F9DB: 27 FB          ''.'
        TIM     #$01,PORT2               ;F9DD: 7B 01 03       '{..'   check P20 again
        BNE     ZF9E8                    ;F9E0: 26 06          '&.'
        OIM     #$08,key_status          ;F9E2: 72 08 9B       'r..'   set key_status bit 3 (tape removed)
        OIM     #$10,PORT3               ;F9E5: 72 10 06       'r..'   P34=high (flag to master)
ZF9E8:  JMP     ZF951                    ;F9E8: 7E F9 51       '~.Q'   loop back to scan
grp5_subtable: FCB     $02                      ;F9EB: 02             '.'
        FDB     cmd_50_status            ;F9EC: F9 F2          '..'
        FDB     cmd_51_set_port4         ;F9EE: FA 06          '..'
        FDB     cmd_52_clear_port4       ;F9F0: FA 12          '..'
cmd_50_status: AIM     #$F3,PORT4               ;F9F2: 71 F3 07       'q..'   clear PORT4 bits 2,3; set bit 5
        OIM     #$20,PORT4               ;F9F5: 72 20 07       'r .'
        LDAA    PORT2                    ;F9F8: 96 03          '..'    read PORT2 bit 0 (P20: tape detect)
        ANDA    #$01                     ;F9FA: 84 01          '..'
        ASLA                             ;F9FC: 48             'H'     shift left for status format
        TIM     #$40,PORT4               ;F9FD: 7B 40 07       '{@.'   check PORT4 bit 6 (P46: cas ctrl ack)
        BEQ     ZFA03                    ;FA00: 27 01          ''.'
        INCA                             ;FA02: 4C             'L'     add P46 status to result
ZFA03:  JMP     sci_send_byte            ;FA03: 7E F1 4B       '~.K'
cmd_51_set_port4: OIM     #$18,PORT4               ;FA06: 72 18 07       'r..'   cmd 0x51: set PORT4 bits 3,4; clr bit 2; toggle bits 2,4
        AIM     #$FB,PORT4               ;FA09: 71 FB 07       'q..'
        EIM     #$14,PORT4               ;FA0C: 75 14 07       'u..'
ZFA0F:  JMP     send_ack                 ;FA0F: 7E F1 48       '~.H'
cmd_52_clear_port4: AIM     #$F3,PORT4               ;FA12: 71 F3 07       'q..'   cmd 0x52: clear PORT4 bits 2,3
        BRA     ZFA0F                    ;FA15: 20 F8          ' .'
        STX     M0FFA                    ;FA17: FF 0F FA       '...'
        FDB     22266,23802,28415,23804  ;FA1A: 56 FA 5C FA 6E FF 5C FC 'V.\.n.\.'
        FDB     59644,57598,18686,19710  ;FA22: E8 FC E0 FE 48 FE 4C FE '....H.L.'
        FDB     21758,20732,56573,61947  ;FA2A: 54 FE 50 FC DC FD F1 FB 'T.P.....'
        FDB     25338,33530,35578        ;FA32: 62 FA 82 FA 8A FA 'b.....'
        FDB     36365                    ;FA38: 8E 0D          '..'
        FDB     cmd_70_motor_check       ;FA3A: FA 92          '..'
        FDB     cmd_71_motor_fwd         ;FA3C: FA A0          '..'
        FDB     cmd_72_motor_stop        ;FA3E: FA A4          '..'
        FDB     cmd_73_motor_rew         ;FA40: FB 13          '..'
        FDB     cmd_74_read_cas_status   ;FA42: FA 76          '.v'
        FDB     cmd_75_clear_cas_status  ;FA44: FA 7B          '.{'
        FDB     cmd_76_cas_ctrl_init     ;FA46: FB 2C          '.,'
        FDB     cmd_77_cleanup           ;FA48: FB 31          '.1'
        FDB     cmd_78_search_fwd        ;FA4A: FB 6B          '.k'
        FDB     cmd_79_search_rew        ;FA4C: FB 74          '.t'
        FDB     cmd_7A_search_tape       ;FA4E: FB 79          '.y'
        FDB     cmd_7B_save_begin        ;FA50: FB 62          '.b'
        FDB     cmd_7C_set_mode          ;FA52: FB 3E          '.>'
        FDB     cmd_7D_detect_tape       ;FA54: FB 45          '.E'
cmd_60_ack61: LDAA    #$61                     ;FA56: 86 61          '.a'    cmd 0x60: send ACK byte $61
ZFA58:  CLC                              ;FA58: 0C             '.'
        JMP     sci_send_byte            ;FA59: 7E F1 4B       '~.K'
cmd_61_cas0_fsk_timing: JSR     send_ack                 ;FA5C: BD F1 48       '..H'   cmd 0x61: receive CAS0 FSK timing params
        LDAA    #$61                     ;FA5F: 86 61          '.a'
        LDX     #vec_IRQ1                ;FA61: CE FF F8       '...'   X=FFF8, loop: 4x2-byte params -> $AE+
ZFA64:  JSR     sci_transact_2           ;FA64: BD F1 0A       '...'
        STD     $AE,X                    ;FA67: ED AE          '..'
        INX                              ;FA69: 08             '.'
        INX                              ;FA6A: 08             '.'
        BNE     ZFA64                    ;FA6B: 26 F7          '&.'
        RTS                              ;FA6D: 39             '9'
cmd_62_set_leader: LDAA    #$61                     ;FA6E: 86 61          '.a'    cmd 0x62: set leader count from master
        JSR     sci_transact_1           ;FA70: BD F1 06       '...'
        STD     leader_count             ;FA73: DD AE          '..'
        RTS                              ;FA75: 39             '9'
cmd_74_read_cas_status: LDAA    cas_status               ;FA76: 96 B4          '..'    cmd 0x74: read cas_status byte
        JMP     sci_send_byte            ;FA78: 7E F1 4B       '~.K'
cmd_75_clear_cas_status: JSR     send_ack                 ;FA7B: BD F1 48       '..H'   cmd 0x75: clear cas_status
        CLRA                             ;FA7E: 4F             'O'
        STAA    cas_status               ;FA7F: 97 B4          '..'
        RTS                              ;FA81: 39             '9'
cmd_6D_set_tape_pos: LDAA    #$61                     ;FA82: 86 61          '.a'    cmd 0x6D: set tape position from master
        JSR     sci_transact_1           ;FA84: BD F1 06       '...'
        STD     tape_pos_hi              ;FA87: DD B0          '..'
        RTS                              ;FA89: 39             '9'
cmd_6E_read_pos_hi: LDAA    tape_pos_hi              ;FA8A: 96 B0          '..'    cmd 0x6E: read tape_pos_hi
        BRA     ZFA58                    ;FA8C: 20 CA          ' .'
cmd_6F_read_pos_lo: LDAA    tape_pos_lo              ;FA8E: 96 B1          '..'    cmd 0x6F: read tape_pos_lo
        BRA     ZFA58                    ;FA90: 20 C6          ' .'
cmd_70_motor_check: JSR     cas_ctrl_reset           ;FA92: BD FB E6       '...'   cmd 0x70: init cas ctrl + check P20
        CLRA                             ;FA95: 4F             'O'
        TIM     #$01,PORT2               ;FA96: 7B 01 03       '{..'   P20=0: tape not present -> FF
        BNE     ZFA9D                    ;FA99: 26 02          '&.'
        LDAA    #$FF                     ;FA9B: 86 FF          '..'
ZFA9D:  STAA    TDR                      ;FA9D: 97 13          '..'
        RTS                              ;FA9F: 39             '9'
cmd_71_motor_fwd: LDAA    #$FF                     ;FAA0: 86 FF          '..'    cmd 0x71: motor forward (cas1_mode=FF)
        BRA     ZFAA5                    ;FAA2: 20 01          ' .'
cmd_72_motor_stop: CLRA                             ;FAA4: 4F             'O'     cmd 0x72: motor stop (cas1_mode=0)
ZFAA5:  STAA    cas1_mode                ;FAA5: 97 87          '..'
        JSR     cas_ctrl_check           ;FAA7: BD FC 31       '..1'   cas_ctrl_check
        LDAA    #$61                     ;FAAA: 86 61          '.a'
        JSR     sci_transact_1           ;FAAC: BD F1 06       '...'   transact: get loop count
        XGDX                             ;FAAF: 18             '.'
        STX     frc_ref                  ;FAB0: DF 80          '..'
        BEQ     ZFB2A                    ;FAB2: 27 76          ''v'
        LDAA    cas1_mode                ;FAB4: 96 87          '..'    mode=0: calculate adjusted count
        BNE     ZFAC7                    ;FAB6: 26 0F          '&.'
        XGDX                             ;FAB8: 18             '.'
        SUBD    #M001E                   ;FAB9: 83 00 1E       '...'
        BMI     ZFAF0                    ;FABC: 2B 32          '+2'
        ADDD    #DDR4                    ;FABE: C3 00 05       '...'
        STD     frc_ref                  ;FAC1: DD 80          '..'
        LDAA    #$11                     ;FAC3: 86 11          '..'
        BRA     ZFAC9                    ;FAC5: 20 02          ' .'
ZFAC7:  LDAA    #$0A                     ;FAC7: 86 0A          '..'    mode!=0: use count=10 directly
ZFAC9:  JSR     cas_ctrl_cmd             ;FAC9: BD FB EA       '...'   send cmd to cassette controller
        OIM     #$04,PORT4               ;FACC: 72 04 07       'r..'
ZFACF:  JSR     cas_ctrl_poll_p46        ;FACF: BD FC 87       '...'   polling loop: wait for cas ctrl P46
        BCS     ZFB2A                    ;FAD2: 25 56          '%V'
        LDX     frc_ref                  ;FAD4: DE 80          '..'
        DEX                              ;FAD6: 09             '.'
        STX     frc_ref                  ;FAD7: DF 80          '..'
        BNE     ZFACF                    ;FAD9: 26 F4          '&.'    loop done: read tape position
        LDX     tape_pos_hi              ;FADB: DE B0          '..'
        STX     frc_ref                  ;FADD: DF 80          '..'
        JSR     cas_ctrl_stop            ;FADF: BD FB D3       '...'   JSR cas_ctrl_stop
        LDD     frc_ref                  ;FAE2: DC 80          '..'
        SUBD    tape_pos_hi              ;FAE4: 93 B0          '..'
        TST     >cas1_mode               ;FAE6: 7D 00 87       '}..'   check mode for position adjustment
        BNE     ZFAEE                    ;FAE9: 26 03          '&.'
        ADDD    #M0019                   ;FAEB: C3 00 19       '...'
ZFAEE:  STD     frc_ref                  ;FAEE: DD 80          '..'
ZFAF0:  LDX     frc_ref                  ;FAF0: DE 80          '..'    start recording: init cas ctrl
        BEQ     ZFB69                    ;FAF2: 27 75          ''u'
        JSR     cas_ctrl_init            ;FAF4: BD FC 2D       '..-'
        CLRA                             ;FAF7: 4F             'O'
        STAA    cas1_mode                ;FAF8: 97 87          '..'
        INCA                             ;FAFA: 4C             'L'
        JSR     cas_ctrl_cmd             ;FAFB: BD FB EA       '...'   send cmd 0x01 (play/record)
        OIM     #$04,PORT4               ;FAFE: 72 04 07       'r..'
ZFB01:  JSR     cas_ctrl_poll_p46        ;FB01: BD FC 87       '...'   inner polling loop
        BCS     ZFB69                    ;FB04: 25 63          '%c'
        LDX     frc_ref                  ;FB06: DE 80          '..'
        DEX                              ;FB08: 09             '.'
        STX     frc_ref                  ;FB09: DF 80          '..'
        BNE     ZFB01                    ;FB0B: 26 F4          '&.'
        JSR     cas_ctrl_stop            ;FB0D: BD FB D3       '...'   done: cas_ctrl_stop + check
        JMP     cas_ctrl_check           ;FB10: 7E FC 31       '~.1'
cmd_73_motor_rew: JSR     send_ack                 ;FB13: BD F1 48       '..H'   cmd 0x73: motor rewind
        JSR     cas_ctrl_check           ;FB16: BD FC 31       '..1'
        LDAA    #$0A                     ;FB19: 86 0A          '..'    send rewind cmd ($0A) to cas ctrl
        JSR     cas_ctrl_cmd             ;FB1B: BD FB EA       '...'
        OIM     #$04,PORT4               ;FB1E: 72 04 07       'r..'
        LDAA    #$FF                     ;FB21: 86 FF          '..'    cas1_mode=FF (rewind mode)
        STAA    cas1_mode                ;FB23: 97 87          '..'
ZFB25:  JSR     cas_ctrl_poll_p46        ;FB25: BD FC 87       '...'   poll until cas ctrl signals done
        BCC     ZFB25                    ;FB28: 24 FB          '$.'
ZFB2A:  BRA     ZFB69                    ;FB2A: 20 3D          ' ='
cmd_76_cas_ctrl_init: JSR     cas_ctrl_init            ;FB2C: BD FC 2D       '..-'   cmd 0x76: cas_ctrl_init
        BRA     ZFB34                    ;FB2F: 20 03          ' .'
cmd_77_cleanup: JSR     cas_ctrl_check           ;FB31: BD FC 31       '..1'   cmd 0x77: cleanup (cas_ctrl_check)
ZFB34:  BCC     ZFB3B                    ;FB34: 24 05          '$.'
        LDAA    #$20                     ;FB36: 86 20          '. '
        JMP     cas0_save_no_tape        ;FB38: 7E FD E6       '~..'
ZFB3B:  JMP     send_ack                 ;FB3B: 7E F1 48       '~.H'
cmd_7C_set_mode: BSR     cas_detect_helper        ;FB3E: 8D 0B          '..'    cmd 0x7C: detect tape + send mode byte
        ASLA                             ;FB40: 48             'H'     shift left for status format
        CLC                              ;FB41: 0C             '.'
        JMP     sci_send_byte            ;FB42: 7E F1 4B       '~.K'
cmd_7D_detect_tape: JSR     cas_ctrl_reset           ;FB45: BD FB E6       '...'   cmd 0x7D: init cas ctrl + ACK
        JMP     send_ack                 ;FB48: 7E F1 48       '~.H'
cas_detect_helper: JSR     cas_ctrl_reset           ;FB4B: BD FB E6       '...'   detect helper: init + check P46 state
        OIM     #$04,PORT4               ;FB4E: 72 04 07       'r..'
        AIM     #$EF,PORT4               ;FB51: 71 EF 07       'q..'
        PSHX                             ;FB54: 3C             '<'     delay loop ($0640 iterations)
        LDX     #M0640                   ;FB55: CE 06 40       '..@'
ZFB58:  DEX                              ;FB58: 09             '.'
        BNE     ZFB58                    ;FB59: 26 FD          '&.'
        PULX                             ;FB5B: 38             '8'
        JSR     ZFCD1                    ;FB5C: BD FC D1       '...'   read P46 state for tape detect
        STAA    p46_state                ;FB5F: 97 BE          '..'
        RTS                              ;FB61: 39             '9'
cmd_7B_save_begin: LDAB    save_mode_7b             ;FB62: D6 BF          '..'    cmd 0x7B: start SAVE block
        STAB    cas1_mode                ;FB64: D7 87          '..'    save mode from save_mode_7b
ZFB66:  JSR     send_ack                 ;FB66: BD F1 48       '..H'
ZFB69:  BRA     cas_ctrl_stop            ;FB69: 20 68          ' h'
cmd_78_search_fwd: LDAB    #$78                     ;FB6B: C6 78          '.x'    cmd 0x78: search forward
        STAB    bit_counter              ;FB6D: D7 83          '..'    set expected match byte
        LDD     #M0AFF                   ;FB6F: CC 0A FF       '...'
        BRA     ZFB7F                    ;FB72: 20 0B          ' .'
cmd_79_search_rew: LDD     #M1179                   ;FB74: CC 11 79       '..y'   cmd 0x79: search reverse
        BRA     ZFB7C                    ;FB77: 20 03          ' .'
cmd_7A_search_tape: LDD     #M017A                   ;FB79: CC 01 7A       '..z'   cmd 0x7A: search for tape mark
ZFB7C:  STAB    bit_counter              ;FB7C: D7 83          '..'
        CLRB                             ;FB7E: 5F             '_'
ZFB7F:  PSHA                             ;FB7F: 36             '6'
        STAB    cas1_mode                ;FB80: D7 87          '..'
        JSR     cas_ctrl_check           ;FB82: BD FC 31       '..1'   cas_ctrl_check
        BCC     ZFB8B                    ;FB85: 24 04          '$.'
        PULA                             ;FB87: 32             '2'
        JMP     cas0_load_no_tape        ;FB88: 7E FF 57       '~.W'
ZFB8B:  JSR     send_ack                 ;FB8B: BD F1 48       '..H'
        BSR     cas_detect_helper        ;FB8E: 8D BB          '..'    call detect helper
        PULA                             ;FB90: 32             '2'
        JSR     cas_ctrl_cmd             ;FB91: BD FB EA       '...'   send cmd to cassette controller
        OIM     #$04,PORT4               ;FB94: 72 04 07       'r..'
        LDD     #M2710                   ;FB97: CC 27 10       '.'.'   timeout counter = 10000
        STD     frc_ref                  ;FB9A: DD 80          '..'
ZFB9C:  LDAA    TRCSR                    ;FB9C: 96 11          '..'    poll loop: check RDRF for master cmds
        BPL     ZFBC5                    ;FB9E: 2A 25          '*%'
        LDAB    RDR                      ;FBA0: D6 12          '..'    read master command byte
        LDAA    tape_pos_hi              ;FBA2: 96 B0          '..'
        CMPB    #$6E                     ;FBA4: C1 6E          '.n'    check for 0x6E (read pos hi)
        BEQ     ZFBB4                    ;FBA6: 27 0C          ''.'
        LDAA    tape_pos_lo              ;FBA8: 96 B1          '..'
        CMPB    #$6F                     ;FBAA: C1 6F          '.o'    check for 0x6F (read pos lo)
        BEQ     ZFBB4                    ;FBAC: 27 06          ''.'
        LDAA    #$01                     ;FBAE: 86 01          '..'
        CMPB    bit_counter              ;FBB0: D1 83          '..'    check for expected match byte
        BNE     ZFBB9                    ;FBB2: 26 05          '&.'
ZFBB4:  JSR     sci_send_byte            ;FBB4: BD F1 4B       '..K'
        BRA     ZFB9C                    ;FBB7: 20 E3          ' .'
ZFBB9:  CMPB    #$7B                     ;FBB9: C1 7B          '.{'    check for 0x7B (save begin: loop back)
        BEQ     ZFB66                    ;FBBB: 27 A9          ''.'
        STAB    queued_cmd               ;FBBD: D7 91          '..'    not expected: queue as pending cmd
        LDAA    #$02                     ;FBBF: 86 02          '..'
        STAA    cmd_state                ;FBC1: 97 92          '..'
        BRA     cas_ctrl_stop            ;FBC3: 20 0E          ' .'
ZFBC5:  LDX     frc_ref                  ;FBC5: DE 80          '..'    no RDRF: decrement timeout
        DEX                              ;FBC7: 09             '.'
        STX     frc_ref                  ;FBC8: DF 80          '..'
        BEQ     cas_ctrl_stop            ;FBCA: 27 07          ''.'
        JSR     cas_ctrl_poll_p46        ;FBCC: BD FC 87       '...'   poll cas ctrl P46
        BCC     ZFB9C                    ;FBCF: 24 CB          '$.'
        BRA     cas_ctrl_reset           ;FBD1: 20 13          ' .'
cas_ctrl_stop: LDAA    #$18                     ;FBD3: 86 18          '..'    stop: send $18 cmd to cas ctrl
        BSR     cas_ctrl_cmd             ;FBD5: 8D 13          '..'
        OIM     #$04,PORT4               ;FBD7: 72 04 07       'r..'   wait for P46 transitions (21 ticks)
        LDAB    #$15                     ;FBDA: C6 15          '..'
ZFBDC:  PSHB                             ;FBDC: 37             '7'
        JSR     cas_ctrl_poll_p46        ;FBDD: BD FC 87       '...'
        PULB                             ;FBE0: 33             '3'
        BCS     cas_ctrl_reset           ;FBE1: 25 03          '%.'
        DECB                             ;FBE3: 5A             'Z'
        BNE     ZFBDC                    ;FBE4: 26 F6          '&.'
cas_ctrl_reset: CLRA                             ;FBE6: 4F             'O'     reset: clear A, clear B5 bit 7
        AIM     #$7F,cas1_leader_ct      ;FBE7: 71 7F B5       'q..'
cas_ctrl_cmd: OIM     #$01,TCSR                ;FBEA: 72 01 08       'r..'   bit-bang 8 bits on P43(data)/P44(clock)
        PSHA                             ;FBED: 36             '6'     save cmd byte
        LDAA    TCSR                     ;FBEE: 96 08          '..'
        LDD     FRC_H                    ;FBF0: DC 09          '..'    arm OCR for first clock edge
        ADDD    #ICR_H                   ;FBF2: C3 00 0D       '...'
        STD     OCR_H                    ;FBF5: DD 0B          '..'
        PULA                             ;FBF7: 32             '2'
        LDAB    #$08                     ;FBF8: C6 08          '..'    8-bit loop
ZFBFA:  AIM     #$E3,PORT4               ;FBFA: 71 E3 07       'q..'   clear P43+P44 (data=0, clock=0)
        ASLA                             ;FBFD: 48             'H'     shift bit into carry
        BCC     ZFC03                    ;FBFE: 24 03          '$.'
        OIM     #$08,PORT4               ;FC00: 72 08 07       'r..'   bit=1: set P43 (data=1)
ZFC03:  OIM     #$10,PORT4               ;FC03: 72 10 07       'r..'   set P44 (clock high)
        DECB                             ;FC06: 5A             'Z'
        BNE     ZFBFA                    ;FC07: 26 F1          '&.'
        CLC                              ;FC09: 0C             '.'     CLC: success
        RTS                              ;FC0A: 39             '9'
cas_ctrl_arm_ocr: LDAA    TCSR                     ;FC0B: 96 08          '..'    arm OCR from current FRC
        LDD     FRC_H                    ;FC0D: DC 09          '..'
        STD     OCR_H                    ;FC0F: DD 0B          '..'
        LDAB    TCSR                     ;FC11: D6 08          '..'
        STAA    OCR_H                    ;FC13: 97 0B          '..'
        BSR     ZFC21                    ;FC15: 8D 0A          '..'
cas_ctrl_wait: TIM     #$40,TCSR                ;FC17: 7B 40 08       '{@.'   wait P46: check OCF timeout
        BEQ     ZFC2A                    ;FC1A: 27 0E          ''.'    timeout: advance OCR, DEX, SEC, RTS
        BSR     ZFC21                    ;FC1C: 8D 03          '..'
        DEX                              ;FC1E: 09             '.'
        SEC                              ;FC1F: 0D             '.'
        RTS                              ;FC20: 39             '9'
ZFC21:  LDAA    TCSR                     ;FC21: 96 08          '..'    advance OCR by $0266 cycles
        LDD     OCR_H                    ;FC23: DC 0B          '..'
        ADDD    #M0266                   ;FC25: C3 02 66       '..f'
        STD     OCR_H                    ;FC28: DD 0B          '..'
ZFC2A:  CLRA                             ;FC2A: 4F             'O'
        INCA                             ;FC2B: 4C             'L'
        RTS                              ;FC2C: 39             '9'
cas_ctrl_init: LDAA    #$40                     ;FC2D: 86 40          '.@'    cas_ctrl_init: check P46 matches expected
        BRA     ZFC32                    ;FC2F: 20 01          ' .'
cas_ctrl_check: CLRA                             ;FC31: 4F             'O'     cas_ctrl_check: expected P46=0
ZFC32:  STAA    ctrl_state               ;FC32: 97 86          '..'
        AIM     #$DF,cas_status          ;FC34: 71 DF B4       'q..'   clear B4 bit 5
        OIM     #$10,PORT4               ;FC37: 72 10 07       'r..'   set P44 high
ZFC3A:  LDAA    PORT4                    ;FC3A: 96 07          '..'    debounce: read PORT4 twice
        CMPA    PORT4                    ;FC3C: 91 07          '..'
        BNE     ZFC3A                    ;FC3E: 26 FA          '&.'
        ANDA    #$40                     ;FC40: 84 40          '.@'    mask P46 (bit 6)
        EORA    ctrl_state               ;FC42: 98 86          '..'    compare with expected state
        BEQ     ZFC7B                    ;FC44: 27 35          ''5'
        LDAA    #$20                     ;FC46: 86 20          '. '    send $20 cmd (query status)
        BSR     cas_ctrl_cmd             ;FC48: 8D A0          '..'
        OIM     #$04,PORT4               ;FC4A: 72 04 07       'r..'
        LDX     #M0640                   ;FC4D: CE 06 40       '..@'
        BSR     cas_ctrl_arm_ocr         ;FC50: 8D B9          '..'    arm OCR + wait initial delay
ZFC52:  LDAA    #$04                     ;FC52: 86 04          '..'    check P46 transitions (4 expected)
        STAA    fsk_byte                 ;FC54: 97 82          '..'
ZFC56:  BSR     cas_ctrl_wait            ;FC56: 8D BF          '..'    wait P46 with OCR timeout
        BEQ     ZFC7D                    ;FC58: 27 23          ''#'
        BCC     ZFC56                    ;FC5A: 24 FA          '$.'
ZFC5C:  LDAA    PORT4                    ;FC5C: 96 07          '..'    debounce PORT4 for P46
        CMPA    PORT4                    ;FC5E: 91 07          '..'
        BNE     ZFC5C                    ;FC60: 26 FA          '&.'
        ANDA    #$40                     ;FC62: 84 40          '.@'
        EORA    ctrl_state               ;FC64: 98 86          '..'
        BNE     ZFC52                    ;FC66: 26 EA          '&.'    P46 changed: count down
        DEC     >fsk_byte                ;FC68: 7A 00 82       'z..'
        BNE     ZFC56                    ;FC6B: 26 E9          '&.'
        LDAA    #$40                     ;FC6D: 86 40          '.@'    send $40 cmd (confirm)
        JSR     cas_ctrl_cmd             ;FC6F: BD FB EA       '...'
        BSR     cas_ctrl_arm_ocr         ;FC72: 8D 97          '..'
        LDX     #M0258                   ;FC74: CE 02 58       '..X'   wait for $0258 P46 ticks
ZFC77:  BSR     cas_ctrl_wait            ;FC77: 8D 9E          '..'
        BNE     ZFC77                    ;FC79: 26 FC          '&.'
ZFC7B:  CLC                              ;FC7B: 0C             '.'
        RTS                              ;FC7C: 39             '9'
ZFC7D:  OIM     #$20,cas_status          ;FC7D: 72 20 B4       'r .'   timeout: set B4 bit 5, send $40, SEC
        LDAA    #$40                     ;FC80: 86 40          '.@'
        JSR     cas_ctrl_cmd             ;FC82: BD FB EA       '...'
        SEC                              ;FC85: 0D             '.'
        RTS                              ;FC86: 39             '9'
cas_ctrl_poll_p46: JSR     cas_ctrl_arm_ocr         ;FC87: BD FC 0B       '...'   poll: wait for P46 transitions after cmd
        LDX     #DDR4                    ;FC8A: CE 00 05       '...'
ZFC8D:  BSR     cas_ctrl_wait            ;FC8D: 8D 88          '..'    wait 5 P46 ticks
        BNE     ZFC8D                    ;FC8F: 26 FC          '&.'
        AIM     #$EF,PORT4               ;FC91: 71 EF 07       'q..'   clear P44
        LDAA    #$0B                     ;FC94: 86 0B          '..'    read 11 data bits from P46
        STAA    fsk_byte                 ;FC96: 97 82          '..'
ZFC98:  TIM     #$40,TRCSR               ;FC98: 7B 40 11       '{@.'   check SCI overrun
        BEQ     ZFCA0                    ;FC9B: 27 03          ''.'
        JMP     sci_error_exit           ;FC9D: 7E F0 9D       '~..'
ZFCA0:  TIM     #$20,TCSR                ;FCA0: 7B 20 08       '{ .'   check TOF (timer overflow)
        BEQ     ZFCAD                    ;FCA3: 27 08          ''.'
        DEC     >fsk_byte                ;FCA5: 7A 00 82       'z..'   dec counter, done when 0
        SEC                              ;FCA8: 0D             '.'
        BEQ     ZFCD0                    ;FCA9: 27 25          ''%'
        LDD     FRC_H                    ;FCAB: DC 09          '..'
ZFCAD:  LDAB    #$04                     ;FCAD: C6 04          '..'    debounce + read P46
ZFCAF:  LDAA    #$3F                     ;FCAF: 86 3F          '.?'
ZFCB1:  DECA                             ;FCB1: 4A             'J'
        BNE     ZFCB1                    ;FCB2: 26 FD          '&.'
        PSHB                             ;FCB4: 37             '7'
        BSR     ZFCD1                    ;FCB5: 8D 1A          '..'
        PULB                             ;FCB7: 33             '3'
        EORA    p46_state                ;FCB8: 98 BE          '..'    compare with prev state
        ANDA    #$40                     ;FCBA: 84 40          '.@'    mask P46
        BEQ     ZFC98                    ;FCBC: 27 DA          ''.'
        DECB                             ;FCBE: 5A             'Z'
        BNE     ZFCAF                    ;FCBF: 26 EE          '&.'
        EIM     #$40,p46_state           ;FCC1: 75 40 BE       'u@.'   toggle expected P46 state
        LDX     tape_pos_hi              ;FCC4: DE B0          '..'    update tape position (B0/B1)
        INX                              ;FCC6: 08             '.'
        LDAA    cas1_mode                ;FCC7: 96 87          '..'
        BPL     ZFCCD                    ;FCC9: 2A 02          '*.'
        DEX                              ;FCCB: 09             '.'
        DEX                              ;FCCC: 09             '.'
ZFCCD:  STX     tape_pos_hi              ;FCCD: DF B0          '..'
        CLC                              ;FCCF: 0C             '.'
ZFCD0:  RTS                              ;FCD0: 39             '9'
ZFCD1:  LDAA    #$FF                     ;FCD1: 86 FF          '..'
ZFCD3:  TAB                              ;FCD3: 16             '.'
        LDAA    PORT4                    ;FCD4: 96 07          '..'
        ANDA    #$40                     ;FCD6: 84 40          '.@'
        CBA                              ;FCD8: 11             '.'
        BNE     ZFCD3                    ;FCD9: 26 F8          '&.'
        RTS                              ;FCDB: 39             '9'
cas0_save_mode1: LDAA    #$01                     ;FCDC: 86 01          '..'    mode 81=1 (CAS1: external via CAS0 path)
        BRA     cas0_save_set_mode       ;FCDE: 20 09          ' .'
cmd_65_save: CLRA                             ;FCE0: 4F             'O'     cmd 0x65: header-only save
        CLRB                             ;FCE1: 5F             '_'
        STD     param1_hi                ;FCE2: DD 84          '..'
        LDAA    #$FF                     ;FCE4: 86 FF          '..'
        BRA     cas0_save_set_mode       ;FCE6: 20 01          ' .'
cas0_save: CLRA                             ;FCE8: 4F             'O'     mode 81=0 (CAS0: internal)
cas0_save_set_mode: STAA    cas0_mode                ;FCE9: 97 81          '..'
        OIM     #$30,PORT4               ;FCEB: 72 30 07       'r0.'   set P44,P45 high
        LDAB    #$10                     ;FCEE: C6 10          '..'
        TIM     #$01,PORT2               ;FCF0: 7B 01 03       '{..'   check P20 (tape present)
        BNE     ZFCF8                    ;FCF3: 26 03          '&.'    present: continue
ZFCF5:  JMP     cas0_save_no_tape        ;FCF5: 7E FD E6       '~..'   not present: error
ZFCF8:  JSR     cas_ctrl_init            ;FCF8: BD FC 2D       '..-'   init cassette controller
        LDAB    #$20                     ;FCFB: C6 20          '. '
        BCS     ZFCF5                    ;FCFD: 25 F6          '%.'
        JSR     send_ack                 ;FCFF: BD F1 48       '..H'   ACK to master
        LDAA    cas0_mode                ;FD02: 96 81          '..'    check mode: FF=skip param recv
        TSTA                             ;FD04: 4D             'M'
        BMI     ZFD0E                    ;FD05: 2B 07          '+.'
cas0_save_params: LDAA    #$61                     ;FD07: 86 61          '.a'    transact: get 2 param bytes -> $84,$85
        JSR     sci_transact_2           ;FD09: BD F1 0A       '...'
        STD     param1_hi                ;FD0C: DD 84          '..'
ZFD0E:  LDAA    #$61                     ;FD0E: 86 61          '.a'    transact: get 2 bytes -> byte count $B8,$B9
        JSR     sci_transact_2           ;FD10: BD F1 0A       '...'
        STD     save_byte_ct_hi          ;FD13: DD B8          '..'
cas0_save_motor: LDAA    #$81                     ;FD15: 86 81          '..'    motor RECORD cmd ($81)
        JSR     cas_ctrl_cmd             ;FD17: BD FB EA       '...'
        OIM     #$04,PORT4               ;FD1A: 72 04 07       'r..'   set P44=high, cas1_leader_ct bit 7
        OIM     #$80,cas1_leader_ct      ;FD1D: 72 80 B5       'r..'
        OIM     #$01,TCSR                ;FD20: 72 01 08       'r..'   set OLVL=1, arm OC from FRC
        LDD     FRC_H                    ;FD23: DC 09          '..'
        INCA                             ;FD25: 4C             'L'
        TST     >TCSR                    ;FD26: 7D 00 08       '}..'
        STD     OCR_H                    ;FD29: DD 0B          '..'
cas0_save_leader: LDX     #M0271                   ;FD2B: CE 02 71       '..q'   leader: 625x FF via cas0_fsk_encode_7
        LDD     param1_hi                ;FD2E: DC 84          '..'
        TSTA                             ;FD30: 4D             'M'
        BMI     ZFD3B                    ;FD31: 2B 08          '+.'
        LDX     leader_count             ;FD33: DE AE          '..'
        TSTA                             ;FD35: 4D             'M'
        BEQ     ZFD3B                    ;FD36: 27 03          ''.'
        LDX     #P3CSR                   ;FD38: CE 00 0F       '...'
ZFD3B:  LDAA    #$FF                     ;FD3B: 86 FF          '..'    FF byte for leader
        JSR     cas0_fsk_encode_7        ;FD3D: BD FD F6       '...'
        TIM     #$40,TRCSR               ;FD40: 7B 40 11       '{@.'   check SCI overrun during leader
        BNE     cas0_save_overrun        ;FD43: 26 37          '&7'
        DEX                              ;FD45: 09             '.'
        BNE     ZFD3B                    ;FD46: 26 F3          '&.'
cas0_save_sync: LDX     save_byte_ct_hi          ;FD48: DE B8          '..'    sync: 9x00, then 00/FF/AA markers
        LDAA    cas0_mode                ;FD4A: 96 81          '..'
        BMI     cas0_save_hdr_only       ;FD4C: 2B 67          '+g'
        LDX     #FRC_H                   ;FD4E: CE 00 09       '...'
ZFD51:  CLRA                             ;FD51: 4F             'O'
        JSR     cas0_fsk_encode_7        ;FD52: BD FD F6       '...'
        DEX                              ;FD55: 09             '.'
        BNE     ZFD51                    ;FD56: 26 F9          '&.'
        CLRA                             ;FD58: 4F             'O'     sync marker: 00
        JSR     cas0_fsk_encode_8        ;FD59: BD FD FB       '...'
        LDAA    #$FF                     ;FD5C: 86 FF          '..'    sync marker: FF
        JSR     cas0_fsk_encode_8        ;FD5E: BD FD FB       '...'
        LDAA    #$AA                     ;FD61: 86 AA          '..'    sync marker: AA
        JSR     cas0_fsk_encode_8        ;FD63: BD FD FB       '...'
        CLRA                             ;FD66: 4F             'O'     clear CRC
        CLRB                             ;FD67: 5F             '_'
        STD     crc_hi                   ;FD68: DD 95          '..'
        LDX     save_byte_ct_hi          ;FD6A: DE B8          '..'    reload byte count
cas0_save_data: TIM     #$01,PORT4               ;FD6C: 7B 01 07       '{..'   data loop: poll P40+RDRF+OCF
        BEQ     cas0_save_p40_exit       ;FD6F: 27 61          ''a'    P40=0: motor stopped
        LDAA    TRCSR                    ;FD71: 96 11          '..'    read TRCSR for RDRF
        BMI     ZFD85                    ;FD73: 2B 10          '+.'    RDRF: data byte ready
        TIM     #$40,TCSR                ;FD75: 7B 40 08       '{@.'   check OCF timeout
        BNE     cas0_save_ocf_err        ;FD78: 26 4C          '&L'    OCF: timeout error
        BRA     cas0_save_data           ;FD7A: 20 F0          ' .'
cas0_save_overrun: JSR     cas_ctrl_stop            ;FD7C: BD FB D3       '...'   SCI overrun: stop + reset + error
        JSR     cas_ctrl_check           ;FD7F: BD FC 31       '..1'
        JMP     sci_error_exit           ;FD82: 7E F0 9D       '~..'
ZFD85:  LDAB    #$61                     ;FD85: C6 61          '.a'    ACK with $61, read data byte
        STAB    TDR                      ;FD87: D7 13          '..'
        LDAA    RDR                      ;FD89: 96 12          '..'
        BSR     cas0_fsk_encode_8        ;FD8B: 8D 6E          '.n'    FSK encode the data byte
        DEX                              ;FD8D: 09             '.'     DEX byte counter
        BNE     cas0_save_data           ;FD8E: 26 DC          '&.'
cas0_save_exit: LDAA    cas0_mode                ;FD90: 96 81          '..'    all bytes sent: check mode
        LDAB    #$02                     ;FD92: C6 02          '..'    B=2 for error exit check
        TSTA                             ;FD94: 4D             'M'
        BGT     cas0_save_no_tape        ;FD95: 2E 4F          '.O'    mode>0: cas0_save_no_tape (CAS1 mode)
ZFD97:  LDAA    crc_lo                   ;FD97: 96 96          '..'    write trailer: CRC_lo, CRC_lo, AA, 00
        BSR     cas0_fsk_encode_8        ;FD99: 8D 60          '.`'
        LDAA    crc_lo                   ;FD9B: 96 96          '..'
        BSR     cas0_fsk_encode_8        ;FD9D: 8D 5C          '.\'
        LDAA    #$AA                     ;FD9F: 86 AA          '..'
        BSR     cas0_fsk_encode_8        ;FDA1: 8D 58          '.X'
        CLRA                             ;FDA3: 4F             'O'
        BSR     cas0_fsk_encode_8        ;FDA4: 8D 55          '.U'
        LDX     #M0271                   ;FDA6: CE 02 71       '..q'   trailing leader
        LDAB    param1_lo                ;FDA9: D6 85          '..'
        BMI     cas0_save_hdr_only       ;FDAB: 2B 08          '+.'
        LDX     leader_count             ;FDAD: DE AE          '..'
        TSTB                             ;FDAF: 5D             ']'
        BEQ     cas0_save_hdr_only       ;FDB0: 27 03          ''.'
        LDX     #P3CSR                   ;FDB2: CE 00 0F       '...'
cas0_save_hdr_only: LDAA    #$FF                     ;FDB5: 86 FF          '..'    leader FF byte loop
        BSR     cas0_fsk_encode_7        ;FDB7: 8D 3D          '.='
        TIM     #$40,TRCSR               ;FDB9: 7B 40 11       '{@.'   check SCI overrun during trailer
        BNE     cas0_save_overrun        ;FDBC: 26 BE          '&.'
        DEX                              ;FDBE: 09             '.'
        BNE     cas0_save_hdr_only       ;FDBF: 26 F4          '&.'
        TSTB                             ;FDC1: 5D             ']'     TSTB: check if more blocks
        BLE     ZFDD0                    ;FDC2: 2F 0C          '/.'
cas0_save_success: CLC                              ;FDC4: 0C             '.'     CLC + RTS: SAVE success
        RTS                              ;FDC5: 39             '9'
cas0_save_ocf_err: JSR     ZF4AC                    ;FDC6: BD F4 AC       '...'   OCF timeout during data: send error
        OIM     #$08,cas_status          ;FDC9: 72 08 B4       'r..'
        LDAA    #$6F                     ;FDCC: 86 6F          '.o'    send $6F error code
        STAA    TDR                      ;FDCE: 97 13          '..'
ZFDD0:  BRA     ZFDE1                    ;FDD0: 20 0F          ' .'
cas0_save_p40_exit: LDAA    cas0_mode                ;FDD2: 96 81          '..'    P40=low exit: check mode
        CMPA    #$01                     ;FDD4: 81 01          '..'    mode==1: CAS1 external, send ACK
        BNE     ZFDDE                    ;FDD6: 26 06          '&.'
        LDAA    #$61                     ;FDD8: 86 61          '.a'    ACK $61 for CAS1 mode
        STAA    TDR                      ;FDDA: 97 13          '..'
        BRA     ZFD97                    ;FDDC: 20 B9          ' .'    jump to trailer
ZFDDE:  JSR     ZF4AC                    ;FDDE: BD F4 AC       '...'   non-CAS1: error report
ZFDE1:  JSR     cas_ctrl_stop            ;FDE1: BD FB D3       '...'   stop cassette controller
        CLC                              ;FDE4: 0C             '.'
        RTS                              ;FDE5: 39             '9'
cas0_save_no_tape: ORAB    cas_status               ;FDE6: DA B4          '..'    no tape: OR B into cas_status
        STAB    cas_status               ;FDE8: D7 B4          '..'
        LDAA    #$6F                     ;FDEA: 86 6F          '.o'
        JSR     sci_send_byte            ;FDEC: BD F1 4B       '..K'
        BRA     ZFDDE                    ;FDEF: 20 ED          ' .'
cmd_6B_handler: JSR     send_ack                 ;FDF1: BD F1 48       '..H'   cmd 0x6B: ACK + stop cas ctrl
        BRA     ZFDE1                    ;FDF4: 20 EB          ' .'
cas0_fsk_encode_7: PSHB                             ;FDF6: 37             '7'     7-bit entry: 8 FSK half-cycles
        LDAB    #$07                     ;FDF7: C6 07          '..'
        BRA     ZFDFE                    ;FDF9: 20 03          ' .'
cas0_fsk_encode_8: PSHB                             ;FDFB: 37             '7'     8-bit entry: 9 FSK half-cycles
        LDAB    #$08                     ;FDFC: C6 08          '..'
ZFDFE:  STD     fsk_byte                 ;FDFE: DD 82          '..'    store byte + counter
cas0_fsk_loop: TIM     #$40,TCSR                ;FE00: 7B 40 08       '{@.'   wait OCF (output compare match)
        BEQ     cas0_fsk_loop            ;FE03: 27 FB          ''.'
        AIM     #$FE,TCSR                ;FE05: 71 FE 08       'q..'   toggle OLVL (P21 output level)
        LDD     cas0_1bit_ph1_hi         ;FE08: DC A8          '..'    bit=1: phase 1 timing
        TIM     #$01,fsk_byte            ;FE0A: 7B 01 82       '{..'   check LSB of fsk_byte
        BNE     ZFE11                    ;FE0D: 26 02          '&.'
        LDD     cas0_0bit_hi             ;FE0F: DC AA          '..'    bit=0: zero-bit timing
ZFE11:  ADDD    OCR_H                    ;FE11: D3 0B          '..'    add period to OCR
        STD     OCR_H                    ;FE13: DD 0B          '..'
        LDAB    bit_counter              ;FE15: D6 83          '..'    check bit counter
        BEQ     ZFE2A                    ;FE17: 27 11          ''.'    counter=0: skip CRC on stop bit
        LDAB    fsk_byte                 ;FE19: D6 82          '..'    CRC update
        ANDB    #$01                     ;FE1B: C4 01          '..'
        EORB    crc_lo                   ;FE1D: D8 96          '..'
        LDAA    crc_hi                   ;FE1F: 96 95          '..'
        LSRD                             ;FE21: 04             '.'
        BCC     ZFE28                    ;FE22: 24 04          '$.'
        EORA    crc_poly_hi              ;FE24: 98 93          '..'
        EORB    crc_poly_lo              ;FE26: D8 94          '..'
ZFE28:  STD     crc_hi                   ;FE28: DD 95          '..'
ZFE2A:  TIM     #$40,TCSR                ;FE2A: 7B 40 08       '{@.'   wait OCF for second half-cycle
        BEQ     ZFE2A                    ;FE2D: 27 FB          ''.'
        OIM     #$01,TCSR                ;FE2F: 72 01 08       'r..'   set OLVL=1 (OIM $01)
        SEC                              ;FE32: 0D             '.'     SEC + ROR: shift 1 into fsk_byte[7]
        ROR     >fsk_byte                ;FE33: 76 00 82       'v..'
        LDD     cas0_1bit_ph2_hi         ;FE36: DC A6          '..'    bit was 1: phase 2 timing
        BCS     ZFE3C                    ;FE38: 25 02          '%.'
        LDD     cas0_0bit_hi             ;FE3A: DC AA          '..'    bit was 0: zero-bit timing
ZFE3C:  ADDD    OCR_H                    ;FE3C: D3 0B          '..'    add period to OCR
        STD     OCR_H                    ;FE3E: DD 0B          '..'
        DEC     >bit_counter             ;FE40: 7A 00 83       'z..'   dec bit counter
        BPL     cas0_fsk_loop            ;FE43: 2A BB          '*.'    loop if >= 0
        PULB                             ;FE45: 33             '3'
        CLC                              ;FE46: 0C             '.'
        RTS                              ;FE47: 39             '9'
cas0_load_hdr: LDAA    #$FF                     ;FE48: 86 FF          '..'    mode=FF (header only)
        BRA     ZFE55                    ;FE4A: 20 09          ' .'
cas0_load_end: LDAA    #$FE                     ;FE4C: 86 FE          '..'    mode=FE (end only)
        BRA     ZFE55                    ;FE4E: 20 05          ' .'
cas0_load_skip_crc: LDAA    #$01                     ;FE50: 86 01          '..'    mode=01 (skip CRC)
        BRA     ZFE55                    ;FE52: 20 01          ' .'
cas0_load_all: CLRA                             ;FE54: 4F             'O'     mode=00 (all + CRC check)
ZFE55:  STAA    cas0_mode                ;FE55: 97 81          '..'    store mode in cas0_mode
        JSR     cas_ctrl_init            ;FE57: BD FC 2D       '..-'   cassette controller init
        BCC     cas0_load_setup          ;FE5A: 24 03          '$.'
        JMP     cas0_load_no_tape        ;FE5C: 7E FF 57       '~.W'
cas0_load_setup: JSR     send_ack                 ;FE5F: BD F1 48       '..H'   ACK to master
        LDAA    #$01                     ;FE62: 86 01          '..'    motor PLAY cmd ($01)
        JSR     cas_ctrl_cmd             ;FE64: BD FB EA       '...'
        OIM     #$80,cas1_leader_ct      ;FE67: 72 80 B5       'r..'   set cas1_leader_ct bit 7
        OIM     #$24,PORT4               ;FE6A: 72 24 07       'r$.'   set PORT4 bits 2,5
        AIM     #$EF,PORT4               ;FE6D: 71 EF 07       'q..'   clear PORT4 bit 4
        AIM     #$FD,TCSR                ;FE70: 71 FD 08       'q..'   clear IEDG in TCSR (falling edge)
        AIM     #$FE,fsk_flags           ;FE73: 71 FE A5       'q..'   clear fsk_flags bit 0
        TIM     #$08,fsk_flags           ;FE76: 7B 08 A5       '{..'   check fsk_flags bit 3
        BEQ     ZFE86                    ;FE79: 27 0B          ''.'
        TIM     #$10,fsk_flags           ;FE7B: 7B 10 A5       '{..'
        BNE     ZFE86                    ;FE7E: 26 06          '&.'
        OIM     #$02,TCSR                ;FE80: 72 02 08       'r..'   set IEDG=1 (rising edge capture)
        OIM     #$01,fsk_flags           ;FE83: 72 01 A5       'r..'   set fsk_flags bit 0
ZFE86:  LDAA    #$61                     ;FE86: 86 61          '.a'    transact: get 2 param bytes
        JSR     sci_transact_2           ;FE88: BD F1 0A       '...'
        STD     param1_hi                ;FE8B: DD 84          '..'
        LDAA    #$FB                     ;FE8D: 86 FB          '..'    DDR3=FB: P32 input
        STAA    DDR3                     ;FE8F: 97 04          '..'
        AIM     #$EF,PORT3               ;FE91: 71 EF 06       'q..'   P34=low
        LDAA    #$61                     ;FE94: 86 61          '.a'    transact: get byte count
        JSR     sci_transact_2           ;FE96: BD F1 0A       '...'
        STD     save_byte_ct_hi          ;FE99: DD B8          '..'    store byte count
        LDX     #cas0_save_overrun       ;FE9B: CE FD 7C       '..|'   set error recovery vector
        STX     return_addr              ;FE9E: DF 89          '..'
        CLI                              ;FEA0: 0E             '.'     CLI: enable interrupts
cas0_load_leader: LDX     #M0028                   ;FEA1: CE 00 28       '..('   outer leader search loop
ZFEA4:  LDAA    TCSR                     ;FEA4: 96 08          '..'    wait for ICF (input capture flag)
        BPL     ZFEA4                    ;FEA6: 2A FC          '*.'
ZFEA8:  LDD     icr_prev_hi              ;FEA8: DC BA          '..'    D = prev ICR value
ZFEAA:  TST     >TCSR                    ;FEAA: 7D 00 08       '}..'   wait for next ICF
        BPL     ZFEAA                    ;FEAD: 2A FB          '*.'
        SUBD    ICR_H                    ;FEAF: 93 0D          '..'    D = prev - current ICR (period)
        PSHA                             ;FEB1: 36             '6'
        LDAA    PORT2                    ;FEB2: 96 03          '..'    read PORT2 for edge polarity
        EORA    fsk_flags                ;FEB4: 98 A5          '..'    XOR with flags for expected polarity
        ASRA                             ;FEB6: 47             'G'     ASRA: polarity bit into carry
        PULA                             ;FEB7: 32             '2'
        BCS     ZFEA8                    ;FEB8: 25 EE          '%.'    wrong polarity: wait again
        ADDD    cas0_icr_adj_hi          ;FEBA: D3 AC          '..'    add ICR adjustment offset
        ASLA                             ;FEBC: 48             'H'     ASLA: shift sign into carry
        LDD     ICR_H                    ;FEBD: DC 0D          '..'    save ICR for next iteration
        STD     icr_prev_hi              ;FEBF: DD BA          '..'
        BCS     cas0_load_leader         ;FEC1: 25 DE          '%.'    carry set: restart leader search
        DEX                              ;FEC3: 09             '.'     DEX leader counter
        BNE     ZFEA8                    ;FEC4: 26 E2          '&.'
        LDX     #M0033                   ;FEC6: CE 00 33       '..3'   leader found: enter sync phase
ZFEC9:  DEX                              ;FEC9: 09             '.'     sync: look for short periods
        BEQ     cas0_load_leader         ;FECA: 27 D5          ''.'
        LDD     icr_prev_hi              ;FECC: DC BA          '..'
ZFECE:  TST     >TCSR                    ;FECE: 7D 00 08       '}..'   wait for ICF
        BPL     ZFECE                    ;FED1: 2A FB          '*.'
        SUBD    ICR_H                    ;FED3: 93 0D          '..'    same period measurement
        PSHA                             ;FED5: 36             '6'
        LDAA    PORT2                    ;FED6: 96 03          '..'
        EORA    fsk_flags                ;FED8: 98 A5          '..'
        ASRA                             ;FEDA: 47             'G'
        PULA                             ;FEDB: 32             '2'
        BCS     ZFECE                    ;FEDC: 25 F0          '%.'
        ADDD    cas0_icr_adj_hi          ;FEDE: D3 AC          '..'
        ASLA                             ;FEE0: 48             'H'     ASLA: check period threshold
        LDD     ICR_H                    ;FEE1: DC 0D          '..'
        STD     icr_prev_hi              ;FEE3: DD BA          '..'
        BCC     ZFEC9                    ;FEE5: 24 E2          '$.'
        JSR     cas0_fsk_decode_7        ;FEE7: BD FF 8D       '...'   7-bit decode (leader byte = FF?)
        BCS     cas0_load_leader         ;FEEA: 25 B5          '%.'
        INCA                             ;FEEC: 4C             'L'     INCA: FF+1=0 means leader byte
        BNE     cas0_load_leader         ;FEED: 26 B2          '&.'    not FF: back to leader search
        JSR     cas0_fsk_decode_8        ;FEEF: BD FF 92       '...'   8-bit decode (sync marker = AA?)
        BCS     cas0_load_leader         ;FEF2: 25 AD          '%.'
        EORA    #$AA                     ;FEF4: 88 AA          '..'    EORA #AA: should be zero
        BNE     cas0_load_leader         ;FEF6: 26 A9          '&.'
        CLRB                             ;FEF8: 5F             '_'     init CRC
        STD     crc_hi                   ;FEF9: DD 95          '..'
        LDX     save_byte_ct_hi          ;FEFB: DE B8          '..'    load byte count into X
        JSR     cas0_fsk_decode_8        ;FEFD: BD FF 92       '...'   decode first data byte
        BCS     cas0_load_leader         ;FF00: 25 9F          '%.'
        LDAB    cas0_mode                ;FF02: D6 81          '..'    check mode
        CMPA    #$48                     ;FF04: 81 48          '.H'    check for $48 marker
        BEQ     ZFF0C                    ;FF06: 27 04          ''.'
        CMPA    #$45                     ;FF08: 81 45          '.E'    check for $45 marker
        BNE     cas0_load_data_loop      ;FF0A: 26 03          '&.'
ZFF0C:  LDX     #M0054                   ;FF0C: CE 00 54       '..T'   set short count ($54)
cas0_load_data_loop: TSTB                             ;FF0F: 5D             ']'     TSTB: check mode for header search
        BPL     ZFF24                    ;FF10: 2A 12          '*.'
        XGDX                             ;FF12: 18             '.'
        CPX     #M48FF                   ;FF13: 8C 48 FF       '.H.'
        BEQ     ZFF1D                    ;FF16: 27 05          ''.'
        CPX     #M45FE                   ;FF18: 8C 45 FE       '.E.'
        BNE     cas0_load_leader         ;FF1B: 26 84          '&.'
ZFF1D:  XGDX                             ;FF1D: 18             '.'
        BRA     ZFF24                    ;FF1E: 20 04          ' .'
cas0_load_data_next: BSR     cas0_fsk_decode_8        ;FF20: 8D 70          '.p'    decode next data byte
        BCS     cas0_load_err_timeout    ;FF22: 25 2B          '%+'
ZFF24:  TIM     #$20,TRCSR               ;FF24: 7B 20 11       '{ .'   wait TDRE
        BEQ     ZFF24                    ;FF27: 27 FB          ''.'
        STAA    TDR                      ;FF29: 97 13          '..'    send byte to master
        DEX                              ;FF2B: 09             '.'     DEX byte counter
        BNE     cas0_load_data_next      ;FF2C: 26 F2          '&.'
        TST     >cas0_mode               ;FF2E: 7D 00 81       '}..'   check mode for CRC verify
        BGT     cas0_load_err_timeout    ;FF31: 2E 1C          '..'
        BSR     cas0_fsk_decode_8        ;FF33: 8D 5D          '.]'    decode CRC byte 1
        BCS     cas0_load_err_crc        ;FF35: 25 13          '%.'
        BSR     cas0_fsk_decode_8        ;FF37: 8D 59          '.Y'    decode CRC byte 2
        BCS     cas0_load_err_crc        ;FF39: 25 0F          '%.'
        LDAA    #$62                     ;FF3B: 86 62          '.b'    send $62 (block complete, CRC OK)
        JSR     sci_send_byte            ;FF3D: BD F1 4B       '..K'
cas0_load_exit: SEI                              ;FF40: 0F             '.'     SEI, check param for cleanup
        LDAA    param1_lo                ;FF41: 96 85          '..'
        BNE     ZFF48                    ;FF43: 26 03          '&.'
ZFF45:  JSR     cas_ctrl_stop            ;FF45: BD FB D3       '...'   stop cassette controller
ZFF48:  CLC                              ;FF48: 0C             '.'
        RTS                              ;FF49: 39             '9'
cas0_load_err_crc: OIM     #$01,cas_status          ;FF4A: 72 01 B4       'r..'   CRC error: set cas_status bit 0
        BRA     ZFF52                    ;FF4D: 20 03          ' .'
cas0_load_err_timeout: OIM     #$02,cas_status          ;FF4F: 72 02 B4       'r..'   timeout error: set cas_status bit 1
ZFF52:  OIM     #$10,PORT3               ;FF52: 72 10 06       'r..'   P34=high (error flag to master)
        BRA     cas0_load_exit           ;FF55: 20 E9          ' .'
cas0_load_no_tape: LDAA    #$20                     ;FF57: 86 20          '. '    no tape: send $20 error
        JMP     cas0_save_no_tape        ;FF59: 7E FD E6       '~..'
cas0_load_cmd63: JSR     cas_ctrl_init            ;FF5C: BD FC 2D       '..-'   cas_ctrl_init + motor play
        BCS     cas0_load_no_tape        ;FF5F: 25 F6          '%.'
        LDAA    #$01                     ;FF61: 86 01          '..'
        JSR     cas_ctrl_cmd             ;FF63: BD FB EA       '...'
        LDAA    #$61                     ;FF66: 86 61          '.a'    transact: get delay count
        JSR     sci_transact_2           ;FF68: BD F1 0A       '...'
        XGDX                             ;FF6B: 18             '.'
        LDAA    TCSR                     ;FF6C: 96 08          '..'    read TCSR for timer state
        LDD     FRC_H                    ;FF6E: DC 09          '..'    arm OCR with initial period
        ADDD    cas0_icr_adj_hi          ;FF70: D3 AC          '..'
        STD     OCR_H                    ;FF72: DD 0B          '..'
ZFF74:  LDAA    #$09                     ;FF74: 86 09          '..'    outer loop: 9 ticks per iteration
        STAA    cas0_mode                ;FF76: 97 81          '..'
ZFF78:  LDD     OCR_H                    ;FF78: DC 0B          '..'    inner loop: add period to OCR
        ADDD    cas0_icr_adj_hi          ;FF7A: D3 AC          '..'
        STD     OCR_H                    ;FF7C: DD 0B          '..'
ZFF7E:  TIM     #$40,TCSR                ;FF7E: 7B 40 08       '{@.'   wait OCF
        BEQ     ZFF7E                    ;FF81: 27 FB          ''.'
        DEC     >cas0_mode               ;FF83: 7A 00 81       'z..'   dec inner counter
        BNE     ZFF78                    ;FF86: 26 F0          '&.'
        DEX                              ;FF88: 09             '.'     DEX outer counter
        BNE     ZFF74                    ;FF89: 26 E9          '&.'
        BRA     ZFF45                    ;FF8B: 20 B8          ' .'    done: stop cassette controller
cas0_fsk_decode_7: PSHB                             ;FF8D: 37             '7'     7-bit decode: 8 edge measurements
        LDAB    #$07                     ;FF8E: C6 07          '..'
        BRA     cas0_fsk_decode_body     ;FF90: 20 03          ' .'
cas0_fsk_decode_8: PSHB                             ;FF92: 37             '7'     8-bit decode: 9 edge measurements
        LDAB    #$08                     ;FF93: C6 08          '..'
cas0_fsk_decode_body: STAB    bit_counter              ;FF95: D7 83          '..'    init bit_counter, arm OCR timeout
        LDD     FRC_H                    ;FF97: DC 09          '..'
        TST     >TCSR                    ;FF99: 7D 00 08       '}..'
        STD     OCR_H                    ;FF9C: DD 0B          '..'    read TCSR for timer
        LDAB    TCSR                     ;FF9E: D6 08          '..'
        STAA    OCR_H                    ;FFA0: 97 0B          '..'    write OCR_H to arm
cas0_fsk_edge_loop: LDD     icr_prev_hi              ;FFA2: DC BA          '..'    D = prev ICR value
ZFFA4:  TIM     #$C0,TCSR                ;FFA4: 7B C0 08       '{..'   check both ICF and OCF
        BMI     cas0_fsk_period_meas     ;FFA7: 2B 05          '+.'    ICF set (bit 7): process edge
        BEQ     ZFFA4                    ;FFA9: 27 F9          ''.'    neither: wait
        PULB                             ;FFAB: 33             '3'     OCF only: timeout, SEC+RTS
        SEC                              ;FFAC: 0D             '.'
        RTS                              ;FFAD: 39             '9'
cas0_fsk_period_meas: SUBD    ICR_H                    ;FFAE: 93 0D          '..'    D = prev - current (period)
        PSHA                             ;FFB0: 36             '6'
        LDAA    PORT2                    ;FFB1: 96 03          '..'    read PORT2 for polarity
        EORA    fsk_flags                ;FFB3: 98 A5          '..'    XOR with fsk_flags
        ASRA                             ;FFB5: 47             'G'     ASRA: polarity into carry
        PULA                             ;FFB6: 32             '2'
        BCS     cas0_fsk_edge_loop       ;FFB7: 25 E9          '%.'    wrong polarity: measure again
        ADDD    cas0_icr_adj_hi          ;FFB9: D3 AC          '..'    add ICR adjustment
        ASLA                             ;FFBB: 48             'H'     ASLA: threshold comparison
        LDD     ICR_H                    ;FFBC: DC 0D          '..'    save ICR for next
        STD     icr_prev_hi              ;FFBE: DD BA          '..'
cas0_fsk_bit_rotate: TIM     #$08,bit_counter         ;FFC0: 7B 08 83       '{..'   check bit 3 of counter (skip CRC first)
        BNE     cas0_fsk_dec_counter     ;FFC3: 26 14          '&.'
cas0_fsk_bit_tpa: TPA                              ;FFC5: 07             '.'     TPA: carry(=threshold result)->CCR
        ROR     >fsk_byte                ;FFC6: 76 00 82       'v..'   ROR: C -> fsk_byte[7] DIRECTLY (no invert!)
        CLRB                             ;FFC9: 5F             '_'     CLRB: clear B
        TAP                              ;FFCA: 06             '.'     TAP: restore CCR (with original carry)
        ROLB                             ;FFCB: 59             'Y'     ROLB: carry -> B[0] for CRC
        EORB    crc_lo                   ;FFCC: D8 96          '..'    CRC update
        LDAA    crc_hi                   ;FFCE: 96 95          '..'
        LSRD                             ;FFD0: 04             '.'
        BCC     ZFFD7                    ;FFD1: 24 04          '$.'
        EORA    crc_poly_hi              ;FFD3: 98 93          '..'
        EORB    crc_poly_lo              ;FFD5: D8 94          '..'
ZFFD7:  STD     crc_hi                   ;FFD7: DD 95          '..'    store CRC
cas0_fsk_dec_counter: DEC     >bit_counter             ;FFD9: 7A 00 83       'z..'   dec bit_counter
        BPL     cas0_fsk_edge_loop       ;FFDC: 2A C4          '*.'    loop if >= 0
        CLC                              ;FFDE: 0C             '.'     CLC: success
        LDAA    fsk_byte                 ;FFDF: 96 82          '..'    return decoded byte in A
        PULB                             ;FFE1: 33             '3'
        RTS                              ;FFE2: 39             '9'
; padding/version: "5722KA" + data
        FCB     $FF,$FF,$FF              ;FFE3: FF FF FF       '...'
        FCC     "5722KA#"                ;FFE6: 35 37 32 32 4B 41 23 '5722KA#'
        FCB     $1E,$F0,$00              ;FFED: 1E F0 00       '...'
vec_SCI: FDB     sci_vec_ram              ;FFF0: 00 88          '..'
vec_TOF: FDB     slave_reset              ;FFF2: F0 00          '..'
vec_OCF: FDB     slave_reset              ;FFF4: F0 00          '..'
vec_ICF: FDB     slave_reset              ;FFF6: F0 00          '..'
vec_IRQ1: FDB     slave_reset              ;FFF8: F0 00          '..'
vec_SWI: FDB     slave_reset              ;FFFA: F0 00          '..'
vec_NMI: FDB     slave_reset              ;FFFC: F0 00          '..'
vec_RESET: FDB     slave_reset              ;FFFE: F0 00          '..'

        END
