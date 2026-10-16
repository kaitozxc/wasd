; nasm -f elf32 calculator.asm -o calculator.o
; ld -m elf_i386 calculator.o -o calculator
; ./calculator

section .data
    clearText db 27, '[2J', 27, '[H', 0
    menu db '----------------------------------', 10
         db 'MENU', 10, '[A]dd', 10, '[S]ubtract', 10
         db '[M]ultiply', 10, '[D]ivide', 10
         db '----------------------------------', 10
         db 'Enter your choice: ', 0

    firstPrompt  db 'Enter first number: ', 0
    secondPrompt db 'Enter second number: ', 0
    sumText      db 'The sum is ', 0
    diffText     db 'The difference is ', 0
    productText  db 'The product is ', 0
    quotientText db 'The quotient is ', 0
    remainderText db 'The remainder is ', 0
    againText db 10, 'Do you want to try again (Y/N): ', 0

    choiceError db 'Invalid choice. Enter A, S, M or D.', 10, 0
    numberError db 'Enter one or two digits only (0-99).', 10, 0
    againError  db 'Please enter Y or N.', 10, 0
    zeroError   db 'Cannot divide by zero.', 10, 0
    goodbye     db 'Program terminated.', 10, 0
    eofText db 10, 'Input ended. Program terminated.', 10, 0
    readError db 10, 'Unable to read input.', 10, 0
    minus db '-', 0
    newline db 10, 0

    letters db 'ASMD'
    procedures dd add_numbers, subtract_numbers
               dd multiply_numbers, divide_numbers

section .bss
    choice resd 1
    num1 resd 1
    num2 resd 1
    buffer resb 3
    character resb 1
    output resb 12

section .text
    global _start

; Short form for calling the printing procedure.
%macro print 1
    mov ecx, %1
    call print_string
%endmacro

_start:
.menu:
    call clear_screen
    print menu
.choose:
    call read_line
    cmp eax, 1
    jne .invalid

    mov al, [buffer]
    and al, 0DFh
    xor esi, esi
.find:
    cmp al, [letters + esi]
    je .numbers
    inc esi
    cmp esi, 4
    jb .find

.invalid:
    print choiceError
    print menu
    jmp .choose

.numbers:
    mov [choice], esi
    mov ecx, firstPrompt
    call read_number
    mov [num1], eax

    mov ecx, secondPrompt
    call read_number
    mov [num2], eax

    mov eax, [choice]
    call [procedures + eax * 4]

.again:
    print againText
    call read_line
    cmp eax, 1
    jne .bad_again

    mov al, [buffer]
    and al, 0DFh
    cmp al, 'Y'
    je .menu
    cmp al, 'N'
    je .quit
.bad_again:
    print againError
    jmp .again
.quit:
    print goodbye
    jmp exit_program

; Arithmetic procedures
add_numbers:
    mov eax, [num1]
    add eax, [num2]
    mov ecx, sumText
    jmp show_result

subtract_numbers:
    mov eax, [num1]
    sub eax, [num2]
    mov ecx, diffText
    jmp show_result

multiply_numbers:
    mov eax, [num1]
    imul eax, [num2]
    mov ecx, productText
    jmp show_result

divide_numbers:
    cmp dword [num2], 0
    je .zero
    mov eax, [num1]
    xor edx, edx
    div dword [num2]

    push edx
    mov ecx, quotientText
    call show_result
    pop eax
    mov ecx, remainderText
    jmp show_result
.zero:
    print zeroError
    ret

show_result:
    call print_string
    call print_number
    print newline
    ret

clear_screen:
    print clearText
    ret

; Print the zero-terminated string at ECX.
print_string:
    pushad
    xor edx, edx
.count:
    cmp byte [ecx + edx], 0
    je .write
    inc edx
    jmp .count
.write:
    mov eax, 4
    mov ebx, 1
    int 0x80
    popad
    ret

; Read through Enter. Return length, or -1 for long input.
read_line:
    xor esi, esi
    xor edi, edi
.read:
    mov eax, 3
    xor ebx, ebx
    mov ecx, character
    mov edx, 1
    int 0x80

    cmp eax, -4
    je .read
    test eax, eax
    jz input_ended
    js input_error

    mov al, [character]
    cmp al, 10
    je .done
    cmp al, 13
    je .read
    cmp esi, 2
    jae .long

    mov [buffer + esi], al
    inc esi
    jmp .read
.long:
    mov edi, 1
    jmp .read
.done:
    mov byte [buffer + esi], 0
    mov eax, esi
    test edi, edi
    jz .return
    mov eax, -1
.return:
    ret

; Ask for a number and convert its digits to an integer.
read_number:
    push ecx
.retry:
    mov ecx, [esp]
    call print_string
    call read_line
    cmp eax, 1
    jl .invalid

    mov ecx, eax
    xor eax, eax
    xor ebx, ebx
.convert:
    movzx edx, byte [buffer + ebx]
    sub edx, '0'
    cmp edx, 9
    ja .invalid
    imul eax, eax, 10
    add eax, edx
    inc ebx
    loop .convert

    pop ecx
    ret
.invalid:
    print numberError
    jmp .retry

; Convert EAX to printable digits.
print_number:
    pushad
    test eax, eax
    jns .positive
    print minus
    neg eax
.positive:
    mov edi, output + 11
    mov byte [edi], 0
    mov ebx, 10
.convert:
    xor edx, edx
    div ebx
    add dl, '0'
    dec edi
    mov [edi], dl
    test eax, eax
    jnz .convert
    print edi
    popad
    ret

input_ended:
    print eofText

exit_program:
    mov eax, 1
    xor ebx, ebx
    int 0x80

input_error:
    print readError
    mov eax, 1
    mov ebx, 1
    int 0x80