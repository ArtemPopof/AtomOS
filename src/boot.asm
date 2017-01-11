; boot.asm
;
; DESCRIPTION: Simple OS boot loader. Might don't work
; on your computer.
; LICENSE: Who need this s 
; PROJECT: AtomOS (it's protected by local laws)
; 
; Arch: x86
; Assembler: FASM
; 
; Version: 0.02 

;======Change history======
;
; New in 0.02:
; -sector loading routines added 
; 
; New in 0.01:
;
; -Inital boot loader added
; -some hello message print message added
;
;==========================

org	0x7C00

jmp	word boot

;===============DATA===============

align 4

label sector_per_track word at $$ 
label head_count byte at $$ + 2 
label	disk_id byte at $$ + 3
boot_msg db "AtomOS boot loader. Version 0.02", 13, 10, 0
reboot_msg db "Press any key...", 13, 10, 0

;==================================


;=============ROUTINES=============

;------------------------
; write_str
;
; Print string from DS:SI 
; on the screen
;------------------------

write_str: 
		
		push	ax si 

		mov 	ah, 0x0E		; put symbol on the screen
@@:
		lodsb                   ; put byte from DS:SI in al 
		test 	al, al 
		jz 		@f 
		int 	0x10
		jmp 	@b 

@@:
		pop 	si ax 
		ret 

;------------------------
; error
;
; Print error message and 
; then reboot 
;------------------------

error: 
		pop		si 
		call	write_str 

;------------------------
; reboot
;
; Jump to 0xFFFF:0 equals 
; to reboot 
;------------------------

reboot:

		mov 	si, reboot_msg 
		call 	write_str
		xor 	ah, ah 
		int 	0x16 
		jmp 	0xFFFF:0

;------------------------
; load_sector
;
; load sector in DX:AX to ES:DI 
;
;------------------------

load_sector:

		; check extended disk service support 

		cmp 	byte[sector_per_track], 0xFF 
		je 		.use_EDD

		push 	ax bx cx dx si 

		; devide dx:ax by sector per track count (ax - result, dx - reminder)
		div 	[sector_per_track] 		; ax - track number and dx - sector on track 
		mov 	cl, dl 
		inc 	cl 						; sectors starts from 1
		div 	[head_count]
		mov 	dh, ah 
		mov 	ch, al
		mov 	dl, [disk_id]
		mov 	bx, di 
	
		mov 	al, 1					; how many sectors will be read 
		mov 	si, 3					; read attempts 

@@:

		mov 	ah, 2 
		int 	0x13
		jnc 	@f 						; read ok 
		xor 	ah, ah 
		int 	0x13 					; reset disk state 
		dec 	si 						; next attempt 
		jnz 	@b 						

.error:

		call 	error
		db 		"DISK ERROR", 13, 10, 0 

@@:

		pop 	si dx cx bx ax 		
		ret 							; exit from rotine 

.use_EDD: 

		push 	ax dx si 

		; make up struct for 0x42 func of int 13

		mov 	byte[0x600], 0x10 
		mov 	byte[0x601], 0 
		mov 	word[0x602], 1 			; read 1 sector 
		mov 	[0x604], di 
		push 	es
		pop 	word[0x606]
		mov 	[0x608], ax 
		mov 	[0x60A], dx 
		mov 	word[0x60c], 0 
		mov 	word[0x60e], 0 

		mov 	ah, 0x42
		mov 	dl, [disk_id]
		mov 	si, 0x600 
		int 	0x13

		jc 		.error 

		pop 	si dx ax 
		ret 		

;==================================


;===========ENTRY POINT============

boot:

		; Set up segment registers 
		jmp 	0:@f

	@@:
		mov 	ax, cs
		mov 	ds, ax 
		mov 	es, ax 

		; Set up stack 
		mov 	ss, ax 
		mov 	sp, $$

		; allow interruptions 
		sti 

		; save load disk id 
		mov 	[disk_id], dl

		; get disk params with extended service
		mov 	ah, 0x41 
		mov 	bx, 0x55AA
		int 	0x13 
		jc 		@f 					; extended service is not supported 
		mov 	byte[sector_per_track], 0xFF ; means that service is not supported 
		jmp 	.disk_detected 

@@:
		; get disk params (old method)
		mov 	ah, 0x08	
		xor 	di, di
		push 	es 	
		int 	0x13 

		pop 	es 
		jc 		load_sector.error 	; some error occured 
		inc 	dh					; head count starts from 1
		mov 	[head_count], dh 
		and 	cx, 111111b			; cx now is sector per track count
		mov 	[sector_per_track], cx 

.disk_detected:

		; load next sector to next 512 bytes
		xor 	dx, dx 
		mov 	ax, 1 
		mov 	di, 0x7E00 
		call 	load_sector

		; print hello mesage 
		mov 	si, boot_msg 
		call 	write_str


		; Reboot now 
		jmp 	reboot 

;==================================

; Empty space and sign 
rb 	510 - ($ - $$) 
db 	0x55, 0xAA 
