; RCX = CCommandBar*
; EDX = first lookup key
; R8D = command/order ID

FindVisibleButton:
    mov     [rsp+08h], rbx
    mov     [rsp+10h], rbp
    mov     [rsp+18h], rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 20h

    xor     r12d, r12d           ; column index = 0
    mov     ebp, r8d             ; requested command ID
    xor     r14d, r14d           ; column byte offset = 0
    mov     r15d, edx            ; requested first key
    mov     r13, rcx             ; command bar

next_column:
    xor     ebx, ebx            ; row index = 0
    xor     esi, esi            ; row byte offset = 0

check_slot:
    mov     rax, [r13+210h]      ; row descriptors
    mov     rcx, [rax+rsi+08h]   ; row's button-pointer array
    mov     rdi, [r14+rcx]       ; button at this column

    test    rdi, rdi
    je      next_row            ; skip null button

    lea     rcx, [rdi+0C0h]     ; button's IVisible subobject
    mov     rax, [rcx]          ; IVisible vtable
    call    qword ptr [rax+10h] ; visibility getter

    test    al, al
    je      next_row            ; skip invisible button

    mov     rax, [rdi+2E8h]     ; associated command-data pointer

    ; NO NULL CHECK FOR RAX HERE

    cmp     dword ptr [rax+08h], r15d
                                ; RVA 0xFB432D: CRASH
                                ; RAX = 0, reads address 0x8
    jne     next_row

    cmp     dword ptr [rax+10h], ebp
    je      found

next_row:
    inc     ebx
    add     rsi, 18h            ; next row descriptor
    cmp     ebx, 3
    jb      check_slot

    inc     r12d
    add     r14, 8              ; next column pointer
    cmp     r12d, 4
    jb      next_column

    xor     eax, eax            ; return nullptr

return_result:
    mov     rbx, [rsp+50h]
    mov     rbp, [rsp+58h]
    mov     rsi, [rsp+60h]
    add     rsp, 20h
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    ret

found:
    mov     rax, rdi            ; return matching button
    jmp     return_result
