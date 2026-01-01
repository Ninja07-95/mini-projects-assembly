global _start

section .data
    prompt      db "Enter password: ", 0
    prompt_len  equ $ - prompt

    success     db "Access granted", 10
    success_len equ $ - success

    failure     db "Access denied", 10
    failure_len equ $ - failure

    password    db "secret123", 0

section .bss
    input resb 32

section .text
_start:
    ; write(prompt)
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, prompt
    mov rdx, prompt_len
    syscall

    ; read(input)
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rsi, input
    mov rdx, 32
    syscall

    ; compare input with password
    mov rsi, input
    mov rdi, password

compare_loop:
    mov al, [rsi]
    mov bl, [rdi]

    cmp al, 10          ; newline ?
    je success_check

    cmp al, bl
    jne denied

    inc rsi
    inc rdi
    jmp compare_loop

success_check:
    cmp byte [rdi], 0
    jne denied

granted:
    mov rax, 1
    mov rdi, 1
    mov rsi, success
    mov rdx, success_len
    syscall
    jmp exit

denied:
    mov rax, 1
    mov rdi, 1
    mov rsi, failure
    mov rdx, failure_len
    syscall

exit:
    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall
