global _start

section .data
    prompt      db "my-shell> ", 0
    prompt_len  equ $ - prompt

    help_msg    db "Commands: help | exit | system commands", 10
    help_len    equ $ - help_msg

    exit_cmd    db "exit", 0
    help_cmd    db "help", 0

    bin_prefix  db "/bin/", 0

section .bss
    cmd     resb 64
    argv    resq 2          ; argv[0], NULL

section .text
_start:
shell_loop:
    ; print prompt
    mov rax, 1
    mov rdi, 1
    mov rsi, prompt
    mov rdx, prompt_len
    syscall

    ; read command
    mov rax, 0
    mov rdi, 0
    mov rsi, cmd
    mov rdx, 64
    syscall

    ; remove newline
    mov rcx, cmd
clean:
    cmp byte [rcx], 10
    je done_clean
    cmp byte [rcx], 0
    je done_clean
    inc rcx
    jmp clean
done_clean:
    mov byte [rcx], 0

    ; check "exit"
    mov rsi, cmd
    mov rdi, exit_cmd
    call strcmp
    test rax, rax
    je exit_shell

    ; check "help"
    mov rsi, cmd
    mov rdi, help_cmd
    call strcmp
    test rax, rax
    je show_help

    ; fork
    mov rax, 57         ; sys_fork
    syscall
    test rax, rax
    jz child

    ; parent
    mov rax, 61         ; sys_wait4
    mov rdi, -1
    xor rsi, rsi
    xor rdx, rdx
    xor r10, r10
    syscall
    jmp shell_loop

child:
    ; argv[0] = cmd
    mov qword [argv], cmd
    mov qword [argv+8], 0

    ; execve(cmd, argv, NULL)
    mov rax, 59
    mov rdi, cmd
    mov rsi, argv
    xor rdx, rdx
    syscall

    ; fallback: try /bin/cmd
    mov rdi, bin_prefix
;    call concat

    mov rax, 59
    mov rdi, cmd
    mov rsi, argv
    xor rdx, rdx
    syscall

    ; if exec fails
    mov rax, 60
    mov rdi, 1
    syscall

show_help:
    mov rax, 1
    mov rdi, 1
    mov rsi, help_msg
    mov rdx, help_len
    syscall
    jmp shell_loop

exit_shell:
    mov rax, 60
    xor rdi, rdi
    syscall

; -------------------------
; strcmp(rsi, rdi)
; return rax = 0 if equal
strcmp:
.loop:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .ne
    test al, al
    je .eq
    inc rsi
    inc rdi
    jmp .loop
.eq:
    xor rax, rax
    ret
.ne:
    mov rax, 1
    ret
