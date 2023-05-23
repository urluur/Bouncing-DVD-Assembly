JMP main
JMP isr

dvd: DB "DVC"
   DB 0

disc: DB "(o)"
   DB 0

up: DW 1
left: DW 1

d1: DB "\x00\x00\x1F\xFF\x1F\xFF\x1F\xFF\x00\x07\x0F\x03\x1E\x03\x1E\x07\x1C\x0F\x3C\x3F\x3F\xFF\x3F\xFC\x3F\xF0\x00\x00\x00\x00\x00\x00";hvala
v: DB "\x00\x00\xFC\x01\xFC\x03\xFC\x07\xDE\x0F\xDE\x1F\xCE\x3E\xCF\x7C\x8F\xF8\x87\xF0\x07\xE0\x07\xC0\x03\x81\x03\x00\x02\x00\x00\x00";mihu
d2: DB "\x00\x00\xFF\xE0\xFF\xF8\xFF\xFC\x80\x3E\x78\x1E\x78\x1E\x78\x1E\x70\x3E\xF0\x7C\xFF\xF8\xFF\xF0\xFF\xC0\x00\x00\x00\x00\x00\x00";stih
disc1: DB "\x00\x3F\x0F\xFF\x7F\xFF\x7F\xFF\x1F\xFF\x00\x1F\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";za
disc2: DB "\xFF\xFF\xFF\xFF\xC0\x7F\xC0\x7F\xFF\xFF\xFF\xFF\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";big
disc3: DB "\xC0\x00\xFF\x80\xFF\xF0\xFF\xF0\xFF\xC0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";help

bounces: DB "bounces:"
  DB 0
corners: DB "corners:"
  DB 0

bounces_count: DW 0
corners_count: DW 0

color: DB 255

;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; ISR ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

isr:
  PUSH a
  
  IN 1
  CMP A, 4
  JE serve_gpu

    
  ; umaknemo zahtevo po prekinitvi tipkovnice
  
  IN 5					; kbdstatus
  CMP A, 2				; preverimo keyup
  JNE no_keyup
  IN 6					; preberemo kbddata
  CMPB AL, ' '			; a je presledek?
  JNE no_keyup
  IN 10 ; Get a random color.
  AND A, 0x00FF
  MOVB [color], AL
  CALL show_logo
  
no_keyup:
  IN 6					; pobrise status
  MOV a, 1				; irq kbd
  OUT 2					; umaknemo zahtevo
  JMP isr_return
  
serve_gpu:
  MOV C, 0				; steje spremembe strani
  
  ; premaknemo okno horizontal
  MOV a, 0xa302			; naslov za horizontalni odmik
  OUT 8					; aktiviramo naslov
  IN 9					; preberemo trenutni odmik -> a
  
  MOV b, [left]
  CMP b, 1				; ali se premikamo gor
  JNE dec_to_right
  INC a					; dvd se premakne gor
  JMP end_h_move
dec_to_right:
  DEC a					; dvd se premakne dol
  
end_h_move:
  CMP a, 206			; ali smo na levem robu
  JBE skip_toggle_h
  CMP a, 0
  JE skip_toggle_h		; ali smo na desnem robu
  CALL toggle_y
  
skip_toggle_h:
  OUT 9					; in ga zapisemo nazaj
  
  ; enako za vertical
  MOV a, 0xa304
  OUT 8
  IN 9
  
  MOV b, [up]
  CMP b, 1
  JNE dec_downwards
  INC a
  JMP end_v_move
dec_downwards:
  DEC a
  
end_v_move:
  CMP a, 222
  JBE skip_toggle_v
  CMP a, 0
  JE skip_toggle_v
  CALL toggle_x
  
skip_toggle_v:
  OUT 9
  
  CMP C, 1				; ce smo se odbili samo od ene stene
  JNE skip_normal_inc
  CALL inc_bounces
  JMP skip_inc_corners
skip_normal_inc:
  CMP C, 2				; ce smo se odbili od kota
  JNE skip_inc_corners
  CALL inc_bounces
  CALL inc_corners
skip_inc_corners:
  
  ; umaknemo zahtevo po prekinitvi grafike
  MOV a, 4				; irq graficne
  OUT 2					; umaknemo zahtevo
  
isr_return:
  POP a
  IRET

;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; INC COUNTERS ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

inc_bounces:
  MOV D, 0x100F			; pointer na zadnjo cifro
inc_b_loop:
  CMP D, 0x1007			; preverimo ce smo cez tisocico stevilke
  JE inc_b_ret
  MOVB AL, [D]			; prebere kaj je na trenutni celici na displayu
  CMPB AL, '9'
  JNE b_not_carry
  MOVB [D], '0'
  DEC D
  JMP inc_b_loop
b_not_carry:
  INCB AL
  MOVB [D], AL
inc_b_ret:

  IN 10 ; Get a random color.
  AND A, 0x00FF
  MOVB [color], AL
  CALL show_logo
  RET
  
  
inc_corners:
  MOV D, 0x101F			; pointer na zadnjo cifro
inc_c_loop:
  CMP D, 0x1017			; preverimo ce smo cez tisocico stevilke
  JE inc_c_ret
  MOVB AL, [D]			; prebere kaj je na trenutni celici na displayu
  CMPB AL, '9'
  JNE c_not_carry
  MOVB [D], '0'
  DEC D
  JMP inc_c_loop
c_not_carry:
  INCB AL
  MOVB [D], AL
inc_c_ret:
  RET

;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; TOGGLE DIRECTION ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;


toggle_x:
  POP d
  INC C
  MOV b, [up]
  CMP b, 0
  JNE down
  MOV [up], 1
  JMP toggle_x_end
down:
  MOV [up], 0
toggle_x_end:  
  PUSH d
  RET
  
toggle_y:
  POP d
  INC C
  MOV b, [left]
  CMP b, 0
  JNE right
  MOV [left], 1
  JMP toggle_y_end
right:
  MOV [left], 0
toggle_y_end:  
  PUSH d
  RET

;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; INIT COUNTERS ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

init_counters:
  MOVB [0x1008], 0x30
  MOVB [0x1009], 0x30
  MOVB [0x100A], 0x30
  MOVB [0x100B], 0x30
  MOVB [0x100C], 0x30
  MOVB [0x100D], 0x30
  MOVB [0x100E], 0x30
  MOVB [0x100F], 0x30
  
  MOVB [0x1018], 0x30
  MOVB [0x1019], 0x30
  MOVB [0x101A], 0x30
  MOVB [0x101B], 0x30
  MOVB [0x101C], 0x30
  MOVB [0x101D], 0x30
  MOVB [0x101E], 0x30
  MOVB [0x101F], 0x30
  
  ; izpisemo konstantno besedilo "bounces"
  MOV D, 0x1000			; celica za "bounces" text
  MOV C, bounces		; naslov prve crke
bounces_loop:
  MOVB BL, [C]			; premaknemo prvi character
  CMPB BL, 0			; ali smo na koncu stringa
  JE bounces_return
  MOVB [D], BL			; izpisemo crko
  INC C					; naslov naslednje črko
  INC D					; nalsov naslednje celice
  JMP bounces_loop
bounces_return:

  ; izpisemo konstantno besedilo "corners"
  MOV D, 0x1010			; celica za "corners" text
  MOV C, corners		; naslov prve crke
corners_loop:
  MOVB BL, [C]			; premaknemo prvi character
  CMPB BL, 0			; ali smo na koncu stringa
  JE corners_return
  MOVB [D], BL			; izpisemo crko
  INC C					; naslov naslednje črko
  INC D					; nalsov naslednje celice
  JMP corners_loop
corners_return:
  RET


;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; MAIN ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

main:
  MOV sp, 0x0fff
  MOV a, 1				; graficna v nacin 1
  OUT 7					; besedilni nacin

  ; napisemo initial nule
  CALL init_counters
  
  CALL show_logo
  
  
; set custom char D1
  MOV C, d1 ; Pointer to ghost definition data
  MOV D, 0x8880 ; Pointer to VRAM address for character
  MOV B, 16
d1_set_loop:
  CMP B, 0
  JE d1_set_break
  MOV A, D
  OUT 8
  MOV A, [C]
  OUT 9
  DEC B
  ADD C, 2
  ADD D, 2
  JMP d1_set_loop
d1_set_break:

; set custom char V
  MOV C, v ; Pointer to ghost definition data
  MOV D, 0x8AC0 ; Pointer to VRAM address for character
  MOV B, 16
v_set_loop:
  CMP B, 0
  JE v_set_break
  MOV A, D
  OUT 8
  MOV A, [C]
  OUT 9
  DEC B
  ADD C, 2
  ADD D, 2
  JMP v_set_loop
v_set_break:

; set custom char D2
  MOV C, d2 ; Pointer to ghost definition data
  MOV D, 0x8860 ; Pointer to VRAM address for character
  MOV B, 16
d2_set_loop:
  CMP B, 0
  JE d2_set_break
  MOV A, D
  OUT 8
  MOV A, [C]
  OUT 9
  DEC B
  ADD C, 2
  ADD D, 2
  JMP d2_set_loop
d2_set_break:

; set custom char disc1
  MOV C, disc1 ; Pointer to ghost definition data
  MOV D, 0x8500 ; Pointer to VRAM address for character
  MOV B, 16
disc1_set_loop:
  CMP B, 0
  JE disc1_set_break
  MOV A, D
  OUT 8
  MOV A, [C]
  OUT 9
  DEC B
  ADD C, 2
  ADD D, 2
  JMP disc1_set_loop
disc1_set_break:


; set custom char disc2
  MOV C, disc2 ; Pointer to ghost definition data
  MOV D, 0x8DE0 ; Pointer to VRAM address for character
  MOV B, 16
disc2_set_loop:
  CMP B, 0
  JE disc2_set_break
  MOV A, D
  OUT 8
  MOV A, [C]
  OUT 9
  DEC B
  ADD C, 2
  ADD D, 2
  JMP disc2_set_loop
disc2_set_break:

; set custom char disc3
  MOV C, disc3 ; Pointer to ghost definition data
  MOV D, 0x8520 ; Pointer to VRAM address for character
  MOV B, 16
disc3_set_loop:
  CMP B, 0
  JE disc3_set_break
  MOV A, D
  OUT 8
  MOV A, [C]
  OUT 9
  DEC B
  ADD C, 2
  ADD D, 2
  JMP disc3_set_loop
disc3_set_break:

  MOV a, 5				; irq grafika (prekinitve za gpu)
  OUT 0 
  STI
  
  HLT
  
;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; SHOW LOGO ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

show_logo:
; izpisemo niz dvd
  MOV c, dvd			; kazalec na crke
  MOV d, 3610			; kazalec na celice

print_dvd_loop:
  MOV a, d
  OUT 8					; aktiviramo naslov celice
  MOVB ah, [c]			; trenutna crka
  CMPB ah, 0			; ali smo ze pri terminalni 0
  JE print_dvd_break
  MOVB al, [color]		; bela barva
  OUT 9					; izpisemo crko
  INC c					; naslednja crka
  ADD d, 2				; naslednja celica
  JMP print_dvd_loop
print_dvd_break:
  MOV c, disc			; kazalec na crke
  MOV d, 3866			; kazalec na celice
print_disc_loop:
  MOV a, d
  OUT 8					; aktiviramo naslov celice
  MOVB ah, [c]			; trenutna crka
  CMPB ah, 0			; ali smo ze pri terminalni 0
  JE print_disc_break
  MOVB al, [color]		; bela barva
  OUT 9					; izpisemo crko
  INC c					; naslednja crka
  ADD d, 2				; naslednja celica
  JMP print_disc_loop
print_disc_break:
  RET