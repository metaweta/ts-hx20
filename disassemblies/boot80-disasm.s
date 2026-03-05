; f9dasm: M6800/1/2/3/8/9 / H6309 Binary/OS9/FLEX9 Disassembler V1.83
; Loaded binary file /tmp/boot80.bin

;****************************************************
;* Used Labels                                      *
;****************************************************

fp_work EQU     $008F
bas_string_pool_size EQU     $009E
bas_code_ptr EQU     $00C4
bas_var_base EQU     $00C6
bas_array_base EQU     $00C8
bas_free_mem EQU     $00CA
bas_load_flag EQU     $00D5
bas_data_ptr EQU     $00D9
M0273   EQU     $0273
bas_ext_base EQU     $05A2
tf20_ctrl_block EQU     $0921
tf20_status EQU     $0926
tf20_saved_ptr EQU     $0927
tf20_data_buf EQU     $0928
saved_mem_size EQU     $0932
tf20_data_end EQU     $09A8
bas_print_error_msg EQU     $917E
bas_warm_start EQU     $B383
tf20_setup_load_request EQU     $B3A4
bas_clear_variables EQU     $B74F
bas_adjust_memory EQU     $BCB1
api_tf20_io EQU     $FF70

;****************************************************
;* Program Code / Data Areas                        *
;****************************************************

        ORG     $0400

boot_entry LDX     mem_size                 ;0400: FE 04 B2       '...'
        STX     saved_mem_size           ;0403: FF 09 32       '..2'
        LDX     #filename_data           ;0406: CE 04 35       '..5'
        LDAB    #$11                     ;0409: C6 11          '..'
        JSR     load_file_sub            ;040B: BD 04 1E       '...'
        INC     $05,X                    ;040E: 6C 05          'l.'
        BEQ     load_error               ;0410: 27 69          ''i'
        LDD     mem_size                 ;0412: FC 04 B2       '...'
        SUBD    $06,X                    ;0415: A3 06          '..'
        BCS     check_mem_error          ;0417: 25 11          '%.'
        CLRB                             ;0419: 5F             '_'
        PSHB                             ;041A: 37             '7'
        PSHA                             ;041B: 36             '6'
        SUBD    bas_ext_size             ;041C: B3 04 FE       '...'
        BCS     check_mem_error          ;041F: 25 09          '%.'
        STD     fp_work                  ;0421: DD 8F          '..'
        SUBD    #M0273                   ;0423: 83 02 73       '..s'
        BCS     check_mem_error          ;0426: 25 02          '%.'
        SUBD    bas_string_pool_size     ;0428: 93 9E          '..'
check_mem_error BCS     mem_error                ;042A: 25 6B          '%k'
        LDD     bas_ext_base             ;042C: FC 05 A2       '...'
        STD     bas_free_mem             ;042F: DD CA          '..'
        ADDD    bas_ext_size             ;0431: F3 04 FE       '...'
        STD     bas_var_base             ;0434: DD C6          '..'
        LDD     fp_work                  ;0436: DC 8F          '..'
        STD     bas_ext_base             ;0438: FD 05 A2       '...'
        JSR     bas_adjust_memory        ;043B: BD BC B1       '...'
        DEC     >bas_load_flag           ;043E: 7A 00 D5       'z..'
        LDX     bas_code_ptr             ;0441: DE C4          '..'
        STX     bas_data_ptr             ;0443: DF D9          '..'
        LDD     tf20_saved_ptr           ;0445: FC 09 27       '..''
        PSHB                             ;0448: 37             '7'
        PSHA                             ;0449: 36             '6'
str_out_of_mem_id CLRA                             ;044A: 4F             'O'
        CLRB                             ;044B: 5F             '_'
        STD     tf20_status              ;044C: FD 09 26       '..&'
request_next_block LDX     #load_block_cfg          ;044F: CE 04 46       '..F'
        LDAB    #$05                     ;0452: C6 05          '..'
        BSR     tf20_load_request        ;0454: 8D 4A          '.J'
        LDAA    $87,X                    ;0456: A6 87          '..'
        BNE     load_error               ;0458: 26 21          '&!'
        LDX     #tf20_data_buf           ;045A: CE 09 28       '..('
        STX     fp_work                  ;045D: DF 8F          '..'
copy_block_loop LDX     fp_work                  ;045F: DE 8F          '..'
        CPX     #tf20_data_end           ;0461: 8C 09 A8       '...'
        BEQ     request_next_block       ;0464: 27 E9          ''.'
        LDAA    ,X                       ;0466: A6 00          '..'
        INX                              ;0468: 08             '.'
        STX     fp_work                  ;0469: DF 8F          '..'
        LDX     bas_code_ptr             ;046B: DE C4          '..'
        STAA    ,X                       ;046D: A7 00          '..'
        INX                              ;046F: 08             '.'
        STX     bas_code_ptr             ;0470: DF C4          '..'
        PULX                             ;0472: 38             '8'
        DEX                              ;0473: 09             '.'
        PSHX                             ;0474: 3C             '<'
        BNE     copy_block_loop          ;0475: 26 E8          '&.'
        PULX                             ;0477: 38             '8'
        PULX                             ;0478: 38             '8'
        JMP     ,X                       ;0479: 6E 00          'n.'
load_error LDAA    bas_load_flag            ;047B: 96 D5          '..'
        BEQ     exit_to_basic            ;047D: 27 1E          ''.'
        LDD     bas_free_mem             ;047F: DC CA          '..'
        STD     bas_ext_base             ;0481: FD 05 A2       '...'
        LDX     bas_array_base           ;0484: DE C8          '..'
        STX     bas_free_mem             ;0486: DF CA          '..'
        LDX     bas_data_ptr             ;0488: DE D9          '..'
        STX     bas_var_base             ;048A: DF C6          '..'
        JSR     bas_adjust_memory        ;048C: BD BC B1       '...'
        JSR     bas_clear_variables      ;048F: BD B7 4F       '..O'
        LDX     #str_cannot_load_id      ;0492: CE 04 59       '..Y'
        BRA     print_error              ;0495: 20 03          ' .'
mem_error LDX     #str_out_of_mem_id       ;0497: CE 04 4A       '..J'
print_error JSR     bas_print_error_msg      ;049A: BD 91 7E       '..~'
exit_to_basic JMP     bas_warm_start           ;049D: 7E B3 83       '~..'
tf20_load_request PSHX                             ;04A0: 3C             '<'
        LDX     #tf20_ctrl_block         ;04A1: CE 09 21       '..!'
        STX     fp_work                  ;04A4: DF 8F          '..'
        PULX                             ;04A6: 38             '8'
        JSR     tf20_setup_load_request  ;04A7: BD B3 A4       '...'
        LDX     #tf20_ctrl_block         ;04AA: CE 09 21       '..!'
        LDAA    #$01                     ;04AD: 86 01          '..'
        JSR     api_tf20_io              ;04AF: BD FF 70       '..p'
mem_size BCS     load_error               ;04B2: 25 C7          '%.'
        BNE     load_error               ;04B4: 26 C5          '&.'
        RTS                              ;04B6: 39             '9'
boot_config_data FCB     $00                      ;04B7: 00             '.'
        FCC     "1 "                     ;04B8: 31 20          '1 '
        FCB     $81,$0D                  ;04BA: 81 0D          '..'
str_dbasic_sys FCC     "DBASIC  SYS"            ;04BC: 44 42 41 53 49 43 20 20 53 59 53 'DBASIC  SYS'
        FCB     $02,$00                  ;04C7: 02 00          '..'
        FCC     "1 "                     ;04C9: 31 20          '1 '
        FCB     $83,$01                  ;04CB: 83 01          '..'
str_out_of_memory FCC     "OUT OF MEMORY"          ;04CD: 4F 55 54 20 4F 46 20 4D 45 4D 4F 52 59 'OUT OF MEMORY'
        FCB     $0D,$0A                  ;04DA: 0D 0A          '..'
str_cannot_load FCC     "CAN NOT LOAD"           ;04DC: 43 41 4E 20 4E 4F 54 20 4C 4F 41 44 'CAN NOT LOAD'
        FCB     $0D,$0A,$00,$1E,$EB,$0E  ;04E8: 0D 0A 00 1E EB 0E '......'
        FCB     $16,$CD,$05,$00,$80,$C4  ;04EE: 16 CD 05 00 80 C4 '......'
        FCB     $AC,$ED,$A0,$A3,$00,$94  ;04F4: AC ED A0 A3 00 94 '......'
        FCC     "T"                      ;04FA: 54             'T'
        FCB     $00                      ;04FB: 00             '.'
        FCC     "y"                      ;04FC: 79             'y'
        FCB     $01                      ;04FD: 01             '.'
bas_ext_size FCB     $B4,$13                  ;04FE: B4 13          '..'

        END
