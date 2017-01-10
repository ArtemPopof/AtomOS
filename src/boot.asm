; boot.asm
;
; DESCRIPTION: Simple OS boot loader. Might don't work
; on your computer.
; LICENSE: Who need this s 
; PROJECT: AtomOS (it's protected by local laws)
; 
; Arch: x86
; Assembler: FASM

org	0x7C00

jmp	word boot

;===============DATA===============

label	disk_id byte at $$
boot_msg db "AtomOS boot loader. Version 0.01", 13, 10, 0
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

		; print hello mesage 
		mov 	si, boot_msg 
		call 	write_str

		; Reboot now 
		jmp 	reboot 

;==================================

; Empty space and sign 
rb 	510 - ($ - $$) 
db 	0x55, 0xAA 
