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

jmp boot

;===============DATA===============

align 4

; ListFS header 

fs_magic 		dd 	?
fs_version		dd 	?
fs_flags		dd 	?
fs_base 		dq 	?
fs_size 		dq	?
fs_map_base 	dq 	?
fs_map_size		dq 	?
fs_first_file	dq 	?
fs_uid			dq 	?
fs_block_size	dd 	?

; File header 
virtual at 0x800 
f_info: 
	
	f_name 		rb 	256
	f_next 		dq 	?
	f_prev		dq 	?
	f_parent	dq 	?
	f_flags 	dq 	?
	f_data 		dq	?
	f_size 		dq 	? 
	f_ctime		dq 	? 
	f_mtime 	dq 	?
	f_atime 	dq 	?

end virtual 

sector_per_track	dw ?
head_count 			db ? 
disk_id				db ?
reboot_msg db "Rebooting. Press any key...", 13, 10, 0

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

		xor 	dx, dx 
		mov 	ax, 1
		mov 	di, 0x7E00 			; load next sector 
		call 	load_sector

		; go to next segment of boot loader 
		jmp 	0x7E00

;==================================

; Empty space and sign 
rb 	510 - ($ - $$) 
db 	0x55, 0xAA 

jmp 	next_entry


;===============DATA===============

boot_msg 	db	"AtomOS version 0.03 boot loader...", 13, 10, 0
boot_file_name db "boot.bin", 0
load_msg_preffix db "Loading '", 0
load_msg_suffix db 	"'...", 0
ok_msg	db 	"OK", 13, 10, 0

;==================================

;=============ROUTINES=============

;------------------------
; find_file:
;
; Search file with name DS:SI 
; in cat DX:AX 
;
;------------------------

find_file:

		push 	cx dx di 

.find:	
		cmp 	ax, -1 					; end of list check 
		jne 	@f 
		cmp 	dx, -1 
		jne 	@f 

.not_found: ; EOL reached, it's very bad 

		call 	error 
		db 		"NOT FOUND", 13, 10, 0

@@:

		mov 	di, f_info 
		call 	load_sector				; load file info in buffer 

		; calc file name length 
		push 	di

		mov 	cx, 0xFFFF
		xor 	al, al 
		repne 	scasb 
		neg 	cx 
		dec 	cx						; now cx contains file name length

		pop	 	di 
		push 	si 	
		repe 	cmpsb 
		pop 	si 
		je 		.found 					

		mov 	ax, word[f_next]		; load next file number
		mov 	dx, word[f_next + 2]
		jmp 	.find

.found:

		pop 	di dx cx 
		ret 		

;------------------------
; load_file_data
;
; Load current file data to 
; BX:0. 
;
; ret: ax - loaded sectors count 
;------------------------ 

load_file_data:

		push 	bx cx dx si di 

		mov 	ax, word[f_data]
		mov 	dx, word[f_data + 2] 	; load in DX:AX sector with first list 

	.load_list:

		cmp 	ax, -1
		jne 	@f
		cmp 	dx, -1 
		jne 	@f 

	.file_end:

		pop 	di si dx cx 

		mov 	ax, bx 
		pop 	bx 
		sub 	ax, bx 					; ax - loaded sectors count
		shr 	ax, 9 - 4 				; actuall conversion to sectors 
		ret 

	@@:

		mov 	di, f_info 
		call 	load_sector 
		mov 	si, di 
		mov 	cx, 512 / 8 - 1 		; sectors in list

	.load_sector:

		lodsw 							; load next sector number 
		mov 	dx, [si] 
		add 	si, 6 
		cmp 	ax, -1 
		jne 	@f 
		cmp 	dx, -1
		je 		.file_end				; end of file

	@@:

		push 	es 
		mov 	es, bx 
		xor 	di, di 
		call 	load_sector 
		add 	bx, 0x200 / 16 			; offset for next segment

		pop 	es 
		loop	.load_sector 

		lodsw 							; DX:AX - next list number 
		mov 	dx, [si]
		jmp 	.load_list  


;------------------------
; split_file_name
;
; split file name with / 
;	
; arg: DS:SI - file name 
; ret: ax - offset of end 
;------------------------

split_file_name:

		push 	si 

@@:
		lodsb 
		cmp 	al, "/"
		je 		@f 
		test 	al, al 
		jz 		@f 
		jmp 	@b 

@@:
		mov 	byte[si - 1], 0
		mov 	ax, si 
		pop 	si 
		ret  

;------------------------
; load_file
;
; Load file with name DS:SI 
; in DI:0 buffer 
; 
; ret: ax - number of loaded 
; sectors 
;------------------------

load_file:

		push 	si 

		mov 	si, load_msg_preffix 
		call 	write_str

		pop 	si 
		call 	write_str 

		push 	si 
		mov 	si, load_msg_suffix
		call 	write_str

		pop 	si 

		push 	bx si bp 

		mov 	dx, word[fs_first_file + 2]
		mov 	ax, word[fs_first_file] 		; start searching in root folder

@@:
		push 	ax 
		call 	split_file_name 
		mov 	bp, ax 
		pop 	ax 
		call 	find_file 
		test 	byte[f_flags], 1				; dir?
		jz 		@f 
		mov 	si, bp 
		mov 	dx, word[f_data + 2]
		mov 	ax, word[f_data]
		jmp 	@b 

@@:	; file found, so load it 

		mov 	bx, di 
		call 	load_file_data 
		mov 	si, ok_msg 
		call 	write_str

		pop	 	bp si bx 
		ret 

;==================================

;==================================


;===============ENTRY==============

next_entry: 

		; print hello mesage 
		mov 	si, boot_msg 
		call 	write_str

		mov 	si, boot_file_name 
		mov 	di, 0x8000 / 16
		call 	load_file


		jmp 	0x8000


		; Reboot now 
		jmp 	reboot 

		db 		0, 0, 0, 0

	
;==================================

;=========NOT PART OF THIS IMAGE, MUST BE CUT OUT=======

org 	0x8000

jmp 	another_entry

new_message 	db 	'This is next file that loaded right into memory and being executed', 13, 10, 0
boot_vga_file_name db 'bootVga.bin', 0 
config_file_name db "boot.cfg", 0
start64_msg db 'Starting 64-bit kernel!...', 13, 10, 0
start16_msg db 'Starting 16-bit kernel!...', 13, 10, 0

;============routines==================

;------------------------
; parse_config
;
; Parse config file and 
; start kernel 
;------------------------

parse_config: 

		mov 	dx, 0x1000
		mov 	di, 0x9000 / 16				; all modules will be loaded here 
		mov 	bp, 0x6000					; module list will be here 		


.parse_line:

		mov 	si, dx 

.parse_char:

		lodsb 								;load from ds:si to al 
		test 	al, al 
		jz 		.config_end 
		cmp 	al, 10 
		je 		.run_command 
		cmp 	al, 13 
		je 		.run_command 
		jmp 	.parse_char 

.run_command:

		mov 	byte[si - 1], 0 
		xchg 	dx, si 						
		cmp 	byte[si], 0
		je 		.parse_line					; empty string 
		cmp 	byte[si], '#'				; comment
		je 		.parse_line 
		cmp 	byte[si], 'L'
		je 		.load_file 					; load module
		cmp 	byte[si], 'S'
		je 		.start_kernel				

		; unknown command 
		mov 	al, [si]
		mov 	[.cmd], al 
		call 	error 
		db 		"Configuration script: unknown command '"
		.cmd 	db ?
		db 		"'!", 13, 10, 0

.config_end: 	; if configuration script is valid, we don't get in here 

		; rebooting 
		jmp 	reboot 

.load_file: 

		push	dx 
		inc 	si 

		call 	load_file 

		push	ax 
		mov 	cx, 512 
		mul 	cx 							 ; dx:ax - how much was loaded 
		mov 	word[bp + 8], ax 
		mov 	word[bp + 10], dx 
		mov 	word[bp + 12], 0 
		mov 	word[bp + 14], 0 
		mov 	ax, di  
		mov 	cx, 16 
		mul 	cx 							  ; dx:ax - offset of loaded module 
		mov 	word[bp], ax 
		mov 	word[bp + 2], dx 
		mov 	word[bp + 4], 0
		mov 	word[bp + 6], 0 
		pop 	ax 

		shl 	ax, 9 - 4 				
		add 	di, ax 
		add 	bp, 16 
		pop 	dx 
		jmp 	.parse_line 

; Start kernel 

.start_kernel:

		; check for at least one file loaded 
		cmp 	di, 0x9000 / 16
		ja 		@f 
		call 	error 
		db 		"NO KERNEL LOADED", 13, 10, 0

@@:
		; store last element of file list 
		xor 	ax, ax 
		mov 	cx, 16 
		mov 	di, bp 
		rep 	stosw 

		; start initialization of kernel 
		inc 	si 
		cmp 	word[si], '16'
		je 		.start16 
		cmp 	word[si], '32'
		je 		.start32
		cmp 	word[si], '64'
		je 		.start64

		; unknown kernel type 
		call 	error 
		db 		"invalid kernel type argument", 13, 10, 0

; Start of 16-bit kernel 

.start16:

		mov 	si, start16_msg
		mov 	bx, 0x6000
		mov 	dl, [disk_id]

		jmp 	0x9000

; Start of 32-bit kernel 
.start32:
		call 	error 
		db 		"Starting 32 bit kernels is not impelemented yet", 13, 10, 0

; Start of 64-bit kernel 

.start64:

		mov 	si, start64_msg
		call 	write_str 

		; need to implement 
		jmp 	reboot 






;============================================

another_entry:

		mov 	si, boot_vga_file_name
		mov 	di, 0x8500 / 16
		call 	load_file 

		;init vga system 
		call 	0x8500

		mov 	si, new_message
		call 	write_str

		; Load boot loader config file 
		mov 	si, config_file_name
		mov 	di, 0x1000 / 16
		call 	load_file 

		; Parse config file 


		call	parse_config



		call 	reboot
