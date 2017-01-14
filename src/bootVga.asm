; boot.asm
;
; DESCRIPTION: Simple vga gui for AtomOS boot loader 
; LICENSE: Who need this s 
; PROJECT: AtomOS (it's protected by local laws)
; 
; Arch: x86
; Assembler: FASM
; 
; Version: 0.03 

org 0x8200

;===============DATA===============


;==================================



;===============ROUTINES===========

;------------------------
; init_boot_vga
;
; Init boot vga system
;------------------------

init_boot_vga:

		push	ax bx cx es di 

		; set 640x480 16 VGA video mode 

		mov 	ax, 0x0012
		int 	10h 

		mov 	ax, 0x00
		mov 	cx, 640*100

		mov 	bx, 0xA000
		mov 	es, bx 
		xor 	di, di 

next_pixel:

		inc 	ax 
		mov 	word[es:di], ax 
		add 	di, 2

		loop 	next_pixel

		pop 	di es cx bx ax 

		ret 	

;==================================
