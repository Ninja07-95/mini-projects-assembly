global _start

; =========================
; DATA
; =========================
section .data
    prompt      db "my-shell> ", 0
    prompt_len  equ $ - prompt

    help_msg    db "Commands: help | exit | system commands", 10
    help_len    equ $ - help_msg

    exit_cmd    db "exit", 0
    help_cmd    db "help", 0

; =========================
; BSS
; =========================
section .bss
    cmd     resb 64
    argv    resq 2          ; argv[0], NULL
    pathbuf resb 64
; =========================
; TEXT
; =========================
section .text

_start:
shell_loop:
    ; write(prompt)
    mov rax, 1
    mov rdi, 1
    mov rsi, prompt
    mov rdx, prompt_len
    syscall

    ; read(cmd)
    mov rax, 0
    mov rdi, 0
    mov rsi, cmd
    mov rdx, 64
    syscall

    ; remove newline
    mov rcx, cmd
.clean:
    cmp byte [rcx], 10
    je .done_clean
    cmp byte [rcx], 0
    je .done_clean
    inc rcx
    jmp .clean
.done_clean:
    mov byte [rcx], 0

    ; if exit
    mov rsi, cmd
    mov rdi, exit_cmd
    call strcmp
    test rax, rax
    je exit_shell

    ; if help
    mov rsi, cmd
    mov rdi, help_cmd
    call strcmp
    test rax, rax
    je show_help

    ; fork
    mov rax, 57             ; sys_fork
    syscall
    test rax, rax
    jz child

    ; parent: wait
    mov rax, 61             ; sys_wait4
    mov rdi, -1
    xor rsi, rsi
    xor rdx, rdx
    xor r10, r10
    syscall
    jmp shell_loop
;========================
; CHILD
; =======================

child:
    call parse_args

    ; try execve(argv[0])
    mov rax, 59
    mov rdi, [argv]
    mov rsi, argv
    xor rdx, rdx
    syscall

    ; fallback: /bin/argv[0]
    call build_path

    mov rax, 59
    mov rdi, pathbuf
    mov rsi, argv
    xor rdx, rdx
    syscall

    mov rax, 60
    mov rdi, 1
    syscall


; =========================
; HELP
; =========================
show_help:
    mov rax, 1
    mov rdi, 1
    mov rsi, help_msg
    mov rdx, help_len
    syscall
    jmp shell_loop

; =========================
; EXIT
; =========================
exit_shell:
    mov rax, 60
    xor rdi, rdi
    syscall

; =========================
; strcmp(rsi, rdi)
; return rax = 0 if equal
; =========================
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

; =========================
; concat
; cmd = "/bin/" + cmd
; =========================
concat:
    ; find end of cmd
    mov rsi, cmd
.find_end:
    cmp byte [rsi], 0
    je .shift
    inc rsi
    jmp .find_end

.shift:
    mov rcx, rsi
    add rcx, 5              ; space for "/bin/"

.shift_loop:
    mov al, [rsi]
    mov [rcx], al
    dec rsi
    dec rcx
    cmp rsi, cmd
    jl .write_prefix
    jmp .shift_loop

.write_prefix:
    mov byte [cmd], '/'
    mov byte [cmd+1], 'b'
    mov byte [cmd+2], 'i'
    mov byte [cmd+3], 'n'
    mov byte [cmd+4], '/'
    ret

; =========================
; parse_args
; builds argv[] from cmd
; =========================
parse_args:
    mov rsi, cmd          ; scan pointer
    mov rdi, argv         ; argv pointer
    xor rcx, rcx          ; arg count

    ; argv[0] = cmd
    mov qword [rdi], cmd
    add rdi, 8
    inc rcx

.scan:
    mov al, [rsi]
    test al, al
    je .done

    cmp al, ' '
    jne .next

    mov byte [rsi], 0     ; terminate word

.skip_spaces:
    inc rsi
    cmp byte [rsi], ' '
    je .skip_spaces

    cmp byte [rsi], 0
    je .done

    mov qword [rdi], rsi  ; argv[n] = &word
    add rdi, 8
    inc rcx
    cmp rcx, 7
    je .done

.next:
    inc rsi
    jmp .scan

.done:
    mov qword [rdi], 0    ; NULL
    ret
; =========================
; build_path
; pathbuf = "/bin/" + argv[0]
; =========================
build_path:
    mov rsi, [argv]        ; argv[0]
    mov rdi, pathbuf

    ; write "/bin/"
    mov byte [rdi], '/'
    mov byte [rdi+1], 'b'
    mov byte [rdi+2], 'i'
    mov byte [rdi+3], 'n'
    mov byte [rdi+4], '/'
    add rdi, 5

.copy:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    je .done
    inc rsi
    inc rdi
    jmp .copy

.done:
    ret
